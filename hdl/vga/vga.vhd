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

-- VGA controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.functions.all;

--The use of this module is straightforward.
--The generic timings are those of a 640*480 mode.
--The can be modified to accomodate any resolution.
--
--The controller sends row/col coordinates and expects
--to get the corresponding color on the next cycle.
--This one cycle delay is necessay because the color
--may have to be retrieved from the on-chip memory.

--Vertical and horizontal retrace are set to 1 when
--no color is displayed and vertical or horizontal retrace
--are happening.
entity vga is
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
end vga;

architecture vga1 of vga is
   constant row_bits : natural := log2(pixel_height);
   constant col_bits : natural := log2(pixel_width);

   signal hcnt : unsigned(log2(line_width) - 1 downto 0); --0 to 799
   signal vcnt : unsigned(log2(line_height) - 1 downto 0); --0 to 525
   -- Used to enable / disable color info during sync
   signal hcol, vcol, color : std_logic;

   -- internal sync signals
   signal v_retrace_i, h_retrace_i : std_logic;
begin
   -- Used to handle the vertical and horizontal retrace signal
   --v_retrace_i <= '1' when (vcnt >= pixel_height) else '0';
   v_retrace <= v_retrace_i;
   h_retrace_i <= '1' when v_retrace_i = '0' and (hcnt >= pixel_width) else
      '0';
   h_retrace <= h_retrace_i;

   process (clk, reset, vcnt, hcnt)
   begin
      if (reset = '1') then
         v_retrace_i <= '0';
      elsif (rising_edge(clk)) then
         if (vcnt = pixel_height) then
            v_retrace_i <= '1';
         end if;

         if (vcnt = 0 and hcnt = line_width - 1) then
            v_retrace_i <= '0';
         end if;
      end if;
   end process;

   hcntproc : process (clk, reset)
   begin
      if (reset = '1') then
         hcnt <= (others => '0');
      elsif (clk'event and clk = '1') then
         if (hcnt = line_width - 1)
            then
            hcnt <= (others => '0');
         else
            hcnt <= hcnt + 1;
         end if;
      end if;
   end process;
   -- tells when to increment row
   vcntproc : process (clk, reset)
   begin
      if (reset = '1') then
         vcnt <= (others => '0');
      elsif (clk'event and clk = '1') then
         --if (current_state = get_color) then
         if (hcnt = pixel_width + back_porch + hsync_width/2) then
            if (vcnt = line_height - 1) then
               vcnt <= (others => '0');
            else
               vcnt <= vcnt + 1;
            end if;
            -- end if;
         end if;
      end if;
   end process;

   col <= (others => '0') when (hcnt >= pixel_width) or (v_retrace_i = '1') else
      hcnt(col'length - 1 downto 0);
   row <= (others => '0') when (v_retrace_i = '1') or (hcnt > pixel_width - 1 and vcnt = pixel_height - 1)
      or (h_retrace_i = '1') else
      vcnt(row_bits - 1 downto 0);

   --updates column and register address
   rowcol : process (clk, reset, hcnt, vcnt)
   begin
      hcol <= '1';
      vcol <= '1';

      if ((hcnt >= pixel_width + 1) or (hcnt = 0)) then
         hcol <= '0';
      end if;

      if (vcnt >= pixel_height) then
         vcol <= '0';
      end if;
   end process;

   -- color enable
   color <= hcol and vcol;
   process (clk, reset, hcnt)
   begin
      if (reset = '1') then
         r <= '0';
         g <= '0';
         b <= '0';
      elsif (clk'event and clk = '1') then
         r <= red and color;
         g <= green and color;
         b <= blue and color;
      end if;
   end process;

   --H and V sync signals
   sync : process (clk, vcnt, hcnt, reset)
   begin
      if (reset = '1') then
         hsync <= '1';
         vsync <= '1';
      elsif (clk'event and clk = '1') then
         if (hcnt <= (pixel_width + front_porch + hsync_width - 1)) and (hcnt >= (pixel_width + front_porch - 1))
            then
            hsync <= '0';
         else
            hsync <= '1';
         end if;

         if (vcnt <= (pixel_height + vfront_porch + vsync_width - 1) and vcnt >= (pixel_height + vfront_porch - 1))
            then
            vsync <= '0';
         else
            vsync <= '1';
         end if;
      end if;
   end process;
end;