-- Copyright (c) 2007-2020 Vitaly Chipounov
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

--------------------------------------------------
--Game Of Life: display the grid
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.functions.all;
use work.gol2_lib.all;

-- This entity draws the grid: it takes the row
-- and the column from the vga
-- end sends the right color
entity gol2_grid is
    generic (
        screen_width : natural := 640;
        screen_height : natural := 480;
        color_depth : natural := 4;

        --grid width/height settings
        gol_cells_width : natural := 80;
        gol_cells_height : natural := 60;
        cell_size_po2 : natural := 3;
        gol_grid_color : natural := 16#F#;

        bank_width : natural
    );
    port (
        clk, reset : in std_logic;
        --Coordinates from the vga controller
        vga_row : in unsigned(log2(screen_height) - 1 downto 0);
        vga_col : in unsigned(log2(screen_width) - 1 downto 0);

        --The background is visible when vga_row/vga_col is
        --outside of the grid.
        bkgr_visible : out std_logic;

        --The pixel to be displayed
        vga_pixel_out : out unsigned(color_depth - 1 downto 0);

        --**The following two signals are used by computegrid**
        --the next row of the grid will be displayed on the next cycle
        next_row : out std_logic;
        --the first row of the grid is being displayed
        first_row : out std_logic;

        --The memory containing the grid
        dispmem_address : out unsigned(bank_width - 1 downto 0);
        dispmem_bank : out unsigned(1 downto 0);
        dispmem_data : in std_logic;

        h_retrace, v_retrace : in std_logic
    );
end gol2_grid;

architecture a1 of gol2_grid is

    signal next_row_i, first_row_i : std_logic;

    signal cnt_mod3 : unsigned(1 downto 0);
    signal cell_state : std_logic;
    signal cell_state_offset : unsigned(bank_width - 1 downto 0);

    signal vga_color : unsigned(color_depth - 1 downto 0);
    signal onrow, oncol, ingrid : std_logic;
    signal pixel_out_i, pixel_out_reg, tempcol : unsigned(color_depth - 1 downto 0);
    signal step_col, step_row, reload_it, bkgr_visible_i, bkgr_visible_reg, show_grid_i, show_grid_reg : std_logic;
    signal grid_row, grid_col : unsigned(bank_width - 1 downto 0);
begin

    process (clk, cnt_mod3, reset)
    begin
        if (reset = '1') then
            dispmem_bank <= (others => '0');
        elsif (rising_edge(clk)) then
            dispmem_bank <= cnt_mod3;
        end if;
    end process;

    --modulo 3 counter, used to select the right read bank for vga
    m3c : gol2_m3counter generic map
    (
        width => gol_cells_width,
        bank_width => bank_width
    )
    port map(
        clk => clk, reset => reset,
        step_col => step_col,
        step_row => step_row,
        reload => reload_it,
        col_offset => grid_col,
        row_offset => grid_row,
        m3cnt => cnt_mod3
    );

    dispmem_address <= grid_row + grid_col;
    cell_state <= dispmem_data;

    --the row/column is incremented when the cell boundary is reached
    step_col <= '1' when ingrid = '1' and ((signed(vga_col(cell_size_po2 - 1 downto 0)) =- 1) or cell_size_po2 = 0) else
        '0';
    step_row <= '1' when ingrid = '1' and ((signed(vga_row(cell_size_po2 - 1 downto 0)) =- 1) or cell_size_po2 = 0) else
        '0';

    process (clk, reset, grid_col, step_col, step_row, cnt_mod3)
    begin
        if (reset = '1') then
            next_row <= '0';
            first_row <= '0';
        elsif (rising_edge(clk)) then
            next_row <= next_row_i;
            first_row <= first_row_i;
        end if;
    end process;

    --the current row is finished and the next one will start soon.
    next_row_i <= '1' when (grid_col = gol_cells_width - 1) and step_col = '1' and step_row = '1' else
        '0';

    --Asserted while the first row is being displayed.
    first_row_i <= '1' when (grid_row = 0) and (cnt_mod3 = 0) else
        '0';

    --The modulo counter is reloaded during the
    --vertical retrace.
    reload_it <= v_retrace;
    onrow <= '1' when (vga_row(cell_size_po2 - 1 downto 0) = 0) and (cell_size_po2 > 0) else
        '0';
    oncol <= '1' when (vga_col(cell_size_po2 - 1 downto 0) = 0) and (cell_size_po2 > 0) else
        '0';

    --We are in the grid when inside the screen area and there are no retraces
    ingrid <= '1' when (vga_col < (gol_cells_width * (2 ** cell_size_po2)))
        and (vga_row < (gol_cells_height * (2 ** cell_size_po2))) and (h_retrace = '0') and (v_retrace = '0') else
        '0';

    bkgr_visible_i <= '0' when ingrid = '1' and cell_state = '1' else
        '1';
    show_grid_i <= ingrid and (onrow or oncol);

    --select the grid color when on grid
    --pixel_out_i <= grid_color when onrow or oncol else (others=>'0');
    tempcol <= to_unsigned(gol_grid_color, tempcol'length)
        when (cell_state = '1') else
        (others => '0');

    vga_pixel_out <=
        tempcol when (show_grid_reg = '0') and (bkgr_visible_reg = '0') else
        to_unsigned(gol_grid_color, vga_pixel_out'length) when (bkgr_visible_reg = '0') and (show_grid_reg = '1')
        else
        (others => '0');

    process (clk, reset)
    begin
        if (reset = '1') then
            bkgr_visible_reg <= '1';
            show_grid_reg <= '0';
        elsif (clk'event and clk = '1') then
            --By default the pixels of the grid are displayed
            bkgr_visible_reg <= bkgr_visible_i;
            show_grid_reg <= show_grid_i;
        end if;
    end process;

    bkgr_visible <= bkgr_visible_reg;
end;