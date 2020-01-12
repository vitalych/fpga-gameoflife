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
--Game Of Life: main module
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gol2_lib.all;
use work.functions.all;
use work.vga_lib.all;
use work.ram_lib.all;
use work.uart_lib.all;
use work.sdram_lib.all;

entity gol2 is
    generic (
        pixel_width : natural := 640;
        vga_line_width : natural := 800;
        vga_hsync_width : natural := 96;
        vga_front_porch : natural := 20;
        vga_back_porch : natural := 44;
        pixel_height : natural := 480;
        vga_line_height : natural := 525;
        vga_vsync_width : natural := 2;
        vga_vfront_porch : natural := 13;
        vga_vback_porch : natural := 30;
        vga_color_depth_bits : natural := 4;

        sdram_row_width : natural := 12;
        sdram_col_width : natural := 9;
        sdram_bank_width : natural := 2;
        sdram_data_width : natural := 32;
        sdram_dqm_size : natural := 4;
        sdram_cas_latency_cycles : natural := 3;
        sdram_init_refresh_cycles : natural := 2;
        gol_cell_size_po2 : natural := 0;

        --grid width/height settings
        gol_cells_per_row : natural := 80;
        gol_cells_per_col : natural := 60;
        gol_grid_color : natural := 16#F#;

        gol_file1 : string := "d:/Vitaly/programmation/fpga/gameoflife/converter/gol1_0.hex";
        gol_file2 : string := "d:/Vitaly/programmation/fpga/gameoflife/converter/gol1_1.hex";
        gol_file3 : string := "d:/Vitaly/programmation/fpga/gameoflife/converter/gol1_2.hex";

        clock_speed : natural := 33000000;
        sdram_clock_speed : natural := 33000000;
        baud_rate : natural := 115200
    );

    port (
        clk, sdram_clk, reset : in std_logic;
        vga_r, vga_g, vga_b, vga_hsync, vga_vsync : out std_logic;
        button_nextframe, button_singlestep : in std_logic;
        leds : out unsigned(95 downto 0);

        --uart data
        uart_rx_grid, uart_rx_pic : in std_logic;
        update_texture : in std_logic;
        update_grid : in std_logic;

        --sdram signals
        sdram_cke, sdram_cs, sdram_ras_n, sdram_cas_n, sdram_we_n : out std_logic;
        sdram_address : out unsigned(sdram_row_width - 1 downto 0);
        sdram_bank_select : out unsigned(sdram_bank_width - 1 downto 0);
        sdram_dqm : out unsigned(sdram_dqm_size - 1 downto 0);
        sdram_data : inout unsigned(sdram_data_width - 1 downto 0)
    );
end gol2;

architecture a1 of gol2 is
    constant rowpo2 : natural := log2(pixel_height);
    constant colpo2 : natural := log2(pixel_width);
    constant bank_width : natural := log2(gol_cells_per_row * gol_cells_per_col/3);

    constant vga_row_bits : natural := log2(pixel_height);
    constant vga_col_bits : natural := log2(pixel_width);
    constant vga_line_width_bits : natural := log2(vga_line_height);
    constant vga_line_height_bits : natural := log2(vga_line_width);
    signal vga_row : unsigned(rowpo2 - 1 downto 0);
    signal vga_col : unsigned(colpo2 - 1 downto 0);
    signal vga_color : unsigned(vga_color_depth_bits - 1 downto 0);
    signal vga_vretrace, vga_hretrace : std_logic;
    signal gol_bkgr_visible : std_logic;

    signal gol_next_row, gol_first_row : std_logic;

    signal gol_grid_rgbout : unsigned(vga_color_depth_bits - 1 downto 0);
    --the address of the cell to be displayed
    signal gol_grid_address : unsigned(bank_width - 1 downto 0);
    signal gol_grid_data : std_logic;
    signal gol_grid_bank : unsigned(1 downto 0);

    --the cell being written to
    signal cell_grid_address : unsigned(bank_width - 1 downto 0);
    signal cell_grid_wdata : std_logic;
    signal cell_grid_we : std_logic;
    signal cell_grid_bank : unsigned(1 downto 0);

    --the ram being displayed (and written)
    signal disp1_address : unsigned(bank_width - 1 downto 0);
    signal disp1_data : std_logic;
    signal disp1_wen : std_logic;
    signal disp1_wdata : std_logic;

    signal disp2_address : unsigned(bank_width - 1 downto 0);
    signal disp2_data : std_logic;
    signal disp2_wen : std_logic;
    signal disp2_wdata : std_logic;

    signal disp3_address : unsigned(bank_width - 1 downto 0);
    signal disp3_data : std_logic;
    signal disp3_wen : std_logic;
    signal disp3_wdata : std_logic;

    --the ram being read.
    --The write signals are used by the file downloader.
    --addresses with the _c suffix are fed to the double buffer
    --those without the suffix are received from the compute_grid module.
    --the actual address in read1_address_c will depend on the
    --grid download being activated or not.
    signal read1_address : unsigned(bank_width - 1 downto 0);
    signal read1_address_c : unsigned(bank_width - 1 downto 0);
    signal read1_data : std_logic;
    signal read1_wen : std_logic;
    signal read1_wdata : std_logic;

    signal read2_address : unsigned(bank_width - 1 downto 0);
    signal read2_address_c : unsigned(bank_width - 1 downto 0);
    signal read2_data : std_logic;
    signal read2_wen : std_logic;
    signal read2_wdata : std_logic;

    signal read3_address : unsigned(bank_width - 1 downto 0);
    signal read3_address_c : unsigned(bank_width - 1 downto 0);
    signal read3_data : std_logic;
    signal read3_wen : std_logic;
    signal read3_wdata : std_logic;

    signal ram_select_reg : std_logic;

    --sdram picture signals
    signal gfxb_rgbout : unsigned(vga_color_depth_bits - 1 downto 0);
    --signal gfxb_rgbin: unsigned(vga_color_depth_bits-1 downto 0);
    --signal gfxb_memoffset: unsigned(gfxb_address_width-1 downto 0);
    --signal gfxb_bkgr_visible: std_logic;
    --grid download signals
    signal grid_update_address, grid_update_row, grid_update_col : unsigned(bank_width - 1 downto 0);
    signal grid_update_wdata : std_logic;
    signal grid_update_we : std_logic;
    signal grid_update_bank : unsigned(1 downto 0);
    signal grid_update_wrtimeout : std_logic;
    signal grid_update_enable : std_logic; --1 when user enabled update
    signal grid_update_cnt_reload : std_logic;

    signal file_dn_we, file_dn_bit, file_dn_type : std_logic;
    signal picture_update_enable : std_logic;
begin

    leds <= (others => '0');

    --Signals for grid download
    process (grid_update_wdata, grid_update_we, read1_address,
        read2_address, read3_address, grid_update_address,
        grid_update_enable, grid_update_bank)
    begin
        read1_wen <= '0';
        read2_wen <= '0';
        read3_wen <= '0';

        read1_wdata <= grid_update_wdata;
        read2_wdata <= grid_update_wdata;
        read3_wdata <= grid_update_wdata;

        read1_address_c <= read1_address;
        read2_address_c <= read2_address;
        read3_address_c <= read3_address;

        if (grid_update_enable = '1') then
            read1_address_c <= grid_update_address;
            read2_address_c <= grid_update_address;
            read3_address_c <= grid_update_address;

            case grid_update_bank is
                when "00" => read1_wen <= grid_update_we;
                when "01" => read2_wen <= grid_update_we;
                when "10" => read3_wen <= grid_update_we;
                when others => null;
            end case;
        end if;
    end process;

    --The display and the write use the same memory buffer, but
    --different banks within it. The following makes the arbitration
    --between the banks of the display memory.
    process (cell_grid_address, cell_grid_wdata, gol_grid_bank, gol_grid_address,
        disp1_data, disp2_data, disp3_data, cell_grid_we,
        cell_grid_bank)
    begin
        --By default, put the address of the cell to be updated;
        disp1_address <= cell_grid_address;
        disp2_address <= cell_grid_address;
        disp3_address <= cell_grid_address;

        disp1_wdata <= cell_grid_wdata;
        disp2_wdata <= cell_grid_wdata;
        disp3_wdata <= cell_grid_wdata;

        disp1_wen <= '0';
        disp2_wen <= '0';
        disp3_wen <= '0';

        gol_grid_data <= '0';
        case gol_grid_bank is
            when "00" =>
                disp1_address <= gol_grid_address;
                gol_grid_data <= disp1_data;
            when "01" =>
                disp2_address <= gol_grid_address;
                gol_grid_data <= disp2_data;
            when "10" =>
                disp3_address <= gol_grid_address;
                gol_grid_data <= disp3_data;
            when others => null;
        end case;

        --We only enable write if the displayed bank
        --and the requested bank for update is different.
        --This should always be the case, because subsequent lines
        --are in different banks and the grid updater always updates
        --the line before the line being displayed.
        if (cell_grid_bank /= gol_grid_bank) then
            case cell_grid_bank is
                when "00" => disp1_wen <= cell_grid_we;
                when "01" => disp2_wen <= cell_grid_we;
                when "10" => disp3_wen <= cell_grid_we;
                when others => null;
            end case;
        end if;
    end process;
    --mapping for VGA controller -------------------------------------
    vga1 : vga generic map(
        pixel_width => pixel_width,
        line_width => vga_line_width,
        hsync_width => vga_hsync_width,
        front_porch => vga_front_porch,
        back_porch => vga_back_porch,
        pixel_height => pixel_height,
        line_height => vga_line_height,
        vsync_width => vga_vsync_width,
        vfront_porch => vga_vfront_porch,
        vback_porch => vga_vback_porch
    )
    port map(
        clk => clk, reset => reset,
        red => vga_color(0), green => vga_color(1), blue => vga_color(2),
        r => vga_r, g => vga_g, b => vga_b, vsync => vga_vsync, hsync => vga_hsync,
        v_retrace => vga_vretrace,
        h_retrace => vga_hretrace,
        row => vga_row, col => vga_col
    );
    -----------------------------------------------------------------
    golcg : gol2_computegrid generic map(
        bank_width => bank_width,
        gol_cells_per_row => gol_cells_per_row,
        gol_cells_per_col => gol_cells_per_col
    )

    port map(
        clk => clk, reset => reset,
        h_retrace => vga_hretrace, v_retrace => vga_vretrace,
        cell_grid_address => cell_grid_address,
        cell_grid_wdata => cell_grid_wdata,
        cell_grid_we => cell_grid_we,
        cell_grid_bank => cell_grid_bank,
        read1_address => read1_address,
        read1_data => read1_data,
        read2_address => read2_address,
        read2_data => read2_data,
        read3_address => read3_address,
        read3_data => read3_data,
        ram_select_reg => ram_select_reg,
        button_nextframe => button_nextframe,
        button_singlestep => button_singlestep,

        next_row_disp => gol_next_row,
        first_row_disp => gol_first_row
    );

    gol : gol2_grid generic map(
        screen_width => pixel_width, screen_height => pixel_height,
        color_depth => vga_color_depth_bits,
        --grid width/height settings
        gol_cells_width => gol_cells_per_row,
        gol_cells_height => gol_cells_per_col,
        cell_size_po2 => gol_cell_size_po2,
        gol_grid_color => gol_grid_color,
        bank_width => bank_width)

    port map(
        clk => clk, reset => reset,
        vga_row => vga_row, vga_col => vga_col,

        bkgr_visible => gol_bkgr_visible,
        vga_pixel_out => gol_grid_rgbout,

        next_row => gol_next_row,
        first_row => gol_first_row,
        dispmem_address => gol_grid_address,
        dispmem_bank => gol_grid_bank,
        dispmem_data => gol_grid_data,
        h_retrace => vga_hretrace,
        v_retrace => vga_vretrace
    );
    db : ram_grid_doublebuf
    generic map(
        block_address_width => bank_width,
        file1 => gol_file1,
        file2 => gol_file2,
        file3 => gol_file3
    )

    port map(
        clk => clk,
        ram_select => ram_select_reg,

        -- the ram being read (original grid)
        read1_address => read1_address_c,
        read1_data => read1_data,
        read1_wen => read1_wen,
        read1_wdata => read1_wdata,

        read2_address => read2_address_c,
        read2_data => read2_data,
        read2_wen => read2_wen,
        read2_wdata => read2_wdata,

        read3_address => read3_address_c,
        read3_data => read3_data,
        read3_wen => read3_wen,
        read3_wdata => read3_wdata,
        --the ram being displayed (and written)
        disp1_address => disp1_address,
        disp1_data => disp1_data,
        disp1_wen => disp1_wen,
        disp1_wdata => disp1_wdata,

        disp2_address => disp2_address,
        disp2_data => disp2_data,
        disp2_wen => disp2_wen,
        disp2_wdata => disp2_wdata,

        disp3_address => disp3_address,
        disp3_data => disp3_data,
        disp3_wen => disp3_wen,
        disp3_wdata => disp3_wdata
    );
    --selecting the right input for vga
    --gol_bkgr_visible <= '1';
    vga_color <= gfxb_rgbout when gol_bkgr_visible = '1' else
        gol_grid_rgbout;
    sdram1 : sdram_picture generic map(
        clock_speed => sdram_clock_speed,
        row_width => sdram_row_width,
        col_width => sdram_col_width,
        bank_width => sdram_bank_width,
        data_width => sdram_data_width,
        dqm_size => sdram_dqm_size,
        cas_latency_cycles => sdram_cas_latency_cycles,
        init_refresh_cycles => sdram_init_refresh_cycles,

        pixel_width => pixel_width,
        vga_line_width => vga_line_width,
        vga_hsync_width => vga_hsync_width,
        vga_front_porch => vga_front_porch,
        vga_back_porch => vga_back_porch,
        pixel_height => pixel_height,
        vga_line_height => vga_line_height,
        vga_vsync_width => vga_vsync_width,
        vga_vfront_porch => vga_vfront_porch,
        vga_vback_porch => vga_vback_porch,
        vga_color_depth_bits => vga_color_depth_bits,

        baud_rate => baud_rate
    )
    port map(
        clk => sdram_clk,
        clk_from_vga => clk,
        reset => reset,
        sdram_cke => sdram_cke, sdram_cs => sdram_cs,
        sdram_ras_n => sdram_ras_n, sdram_cas_n => sdram_cas_n,
        sdram_we_n => sdram_we_n,
        sdram_address => sdram_address,
        sdram_bank_select => sdram_bank_select,
        sdram_dqm => sdram_dqm,
        sdram_data => sdram_data,
        vga_color => gfxb_rgbout,
        vga_col => vga_col,
        vga_row => vga_row,
        vga_vretrace_i => vga_vretrace, vga_hretrace_i => vga_hretrace,
        uart_rx => uart_rx_pic,
        update_enable => picture_update_enable
    );

    picture_update_enable <= not grid_update_enable;

    golupdate : file_downloader generic map(
        clock_speed => clock_speed,
        bus_size => bank_width,
        baud_rate => baud_rate
    )
    port map(
        clk => clk, reset => reset,
        rx => uart_rx_grid,
        wr_address => open,
        --The cell data
        wr_data_bit => grid_update_wdata,
        --Write enable asserted when data ready.
        wr_enable => file_dn_we,

        --Signals a write timeout; the entity using
        --the downloader may use it to signal an error
        wr_timeout => grid_update_wrtimeout
    );
    m3dl : gol2_m3counter generic map(
        width => gol_cells_per_row,
        bank_width => bank_width
    )
    port map(
        clk => clk, reset => reset,
        step_row => '1',
        step_col => grid_update_we,
        reload => grid_update_cnt_reload,
        m3cnt => grid_update_bank,
        col_offset => grid_update_col,
        row_offset => grid_update_row
    );
    grid_update_cnt_reload <= grid_update_wrtimeout or not grid_update_enable;
    grid_update_address <= grid_update_col + grid_update_row;
    grid_update_enable <= update_grid and button_singlestep;
    grid_update_we <= file_dn_we and grid_update_enable;
end a1;
