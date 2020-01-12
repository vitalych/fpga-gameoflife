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
--Bouncer
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.functions.all;

--The module reads a picture from the memory
--and displays it on the screen.
--Each time the screen is refreshed, it increments
--its x,y coordinates. When one of them reaches the
--edge of the screen, its direction is inverted.
--
--The effect is a bouncing image moving on the screen.
entity gfx_bouncer is
    generic (
        screen_width : natural := 640;
        screen_height : natural := 480;

        pic_width : natural := 256;
        pic_height : natural := 256;
        color_depth : natural := 4
    );

    port (
        clk : in std_logic;
        reset : in std_logic;

        --The current row/column being displayed by the vga
        --controller. It expects to get the cooresponding 
        --color on the next cycle.
        row : in unsigned(log2(screen_height) - 1 downto 0);
        col : in unsigned(log2(screen_width) - 1 downto 0);
        rgb_out : out unsigned(color_depth - 1 downto 0);

        --Memory address of the pixel requested by the
        --vga controller
        mem_offset : out unsigned(log2(pic_width * pic_height) - 1 downto 0);
        --The value of the pixel, available on the next cycle
        rgb_in : in unsigned(color_depth - 1 downto 0);

        v_retrace, h_retrace : in std_logic;

        --When the current row/col coordinates are out
        --of the texture area, the background is visible.
        bkgr_visible : out std_logic
    );

end gfx_bouncer;

architecture a1 of gfx_bouncer is
    --We use a multiply component from altera.
    component mult1 is
        generic (operand_width : natural);
        port (
            dataa : in STD_LOGIC_VECTOR (operand_width - 1 downto 0);
            datab : in STD_LOGIC_VECTOR (operand_width - 1 downto 0);
            result : out STD_LOGIC_VECTOR (operand_width * 2 - 1 downto 0)
        );
    end component;

    signal memx, x : unsigned(log2(screen_width) - 1 downto 0);
    signal memy, y : unsigned(log2(screen_height) - 1 downto 0);

    constant tex_mem_width : natural := log2(pic_width * pic_height);

    signal mem_offset_row : unsigned(tex_mem_width - 1 downto 0);

    --1: increment, 0: decrement
    signal dirx, diry : std_logic;

    signal need_swap_x, need_swap_y, bkgr_visible_i, bkgr_visible_reg : std_logic;

    signal rgb_out_i : unsigned(color_depth - 1 downto 0);

    type state is (draw, move, vr_wait, vr_swap);
    signal current_state, next_state : state;

    signal honline : boolean;

begin
    --State machine.
    process (current_state, next_state, v_retrace)
    begin
        next_state <= current_state;

        case current_state is
                --Wait for vertical retrace. The image
                --is displayed during the wait.
            when draw =>
                if (v_retrace = '1') then
                    next_state <= move;
                end if;

                --Move the image
            when move =>
                next_state <= vr_swap;

                --If one coordinate (x and/or y) reach
                --the edge of the screen, inverse the
                --moving direction.
            when vr_swap =>
                next_state <= vr_wait;

                --The wait retrace is not finished yet.
                --Wait fot its completion.
            when vr_wait =>
                if (v_retrace = '0') then
                    next_state <= draw;
                end if;
        end case;
    end process;

    process (clk, reset)
    begin
        if (reset = '1') then
            current_state <= draw;
        elsif (clk'event and clk = '1') then
            current_state <= next_state;
        end if;
    end process;

    -----------------------------------
    -- Update the counters.
    -- This process increments/or decrements them
    -- when the state is move.
    process (clk, reset, dirx, diry, current_state)
    begin
        if (reset = '1') then
            x <= (others => '0');
            y <= (others => '0');
        elsif (rising_edge(clk)) then
            if (current_state = move) then
                if dirx = '1'
                    then
                    x <= x + 1;
                else
                    x <= x - 1;
                end if;

                if diry = '1'
                    then
                    y <= y + 1;
                else
                    y <= y - 1;
                end if;
            end if;
        end if;
    end process;

    --This process changes the direction of the
    --counters when they reach the edge of the screen.
    process (clk, reset, current_state)
    begin
        if (reset = '1') then
            dirx <= '1';
            diry <= '1';
        elsif (clk'event and clk = '1') then
            if (current_state = vr_swap) then
                if (x = (screen_width - pic_width - 1)) then
                    dirx <= not dirx;
                end if;

                if (y = screen_height - pic_height - 1) then
                    diry <= not diry;
                end if;

                if (y = 0) then
                    diry <= not diry;
                end if;
                if (x = 0) then
                    dirx <= not dirx;
                end if;
            end if;
        end if;
    end process;

    --The background is visible when the coordinates
    --are outside of the picture.
    bkgr_visible_i <= '0' when ((col >= x) and (col < x + pic_width)) and
        ((row >= y) and (row < y + pic_height)) else
        '1';

    honline <= (row >= y) and (row < y + pic_height);
    -- Compute the color
    bkgr_visible <= bkgr_visible_reg;
    rgb_out <= rgb_in when bkgr_visible_reg = '0' else
        (others => '0');

    --The bkgr_visible has to be delayed by one cycle
    --because of the vga controller specs.	
    process (clk, reset, bkgr_visible_i)
    begin
        if (reset = '1') then
            bkgr_visible_reg <= '1';
        elsif (clk'event and clk = '1') then
            bkgr_visible_reg <= bkgr_visible_i;
        end if;
    end process;
    -- Generate the read/write offsets
    memx <= col - x;
    memy <= row - y;

    process (clk, reset, honline, col, mem_offset_row)
    begin
        if (reset = '1') then
            mem_offset_row <= (others => '0');
        elsif (rising_edge(clk)) then
            if honline and col = screen_width - 1 then
                if (mem_offset_row >= pic_width * (pic_height - 1)) then
                    mem_offset_row <= (others => '0');
                else
                    mem_offset_row <= mem_offset_row + pic_width;
                end if;
            end if;
        end if;
    end process;

    mem_offset <= mem_offset_row + memx;

end a1;