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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.functions.all;

package vga_lib is

    component vga is
        generic (
            pixel_width : natural := 640;
            line_width : natural := 800;
            hsync_width : natural := 96;
            front_porch : natural := 20;
            back_porch : natural := 44;

            pixel_height : natural := 480;
            line_height : natural := 525;
            vsync_width : natural := 2;
            vfront_porch : natural := 13;
            vback_porch : natural := 30
        );

        port (
            clk : in std_logic;
            reset : in std_logic;
            red, green, blue : in std_logic;
            r, g, b, vsync, hsync : out std_logic;
            v_retrace, h_retrace : out std_logic;
            row : out unsigned(log2(pixel_height) - 1 downto 0);
            col : out unsigned(log2(pixel_width) - 1 downto 0)
        );
    end component;

    component gfx_bouncer is
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
    end component;
end package;