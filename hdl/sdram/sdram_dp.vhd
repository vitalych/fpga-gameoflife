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

entity sdram_dp is
	generic (
		clock_speed : natural := 33000000;
		row_width : natural := 12;
		col_width : natural := 9;
		bank_width : natural := 2;
		data_width : natural := 32;

		cas_latency_cycles : natural := 2;
		init_refresh_cycles : natural := 2;
		refresh_interval : time := 15.625 us;
		powerup_delay : time := 200 us;
		t_rfc : time := 70 ns; --Duration of refresh command
		t_rp : time := 20 ns; -- Duration of precharge command
		t_rcd : time := 20 ns; -- ACTIVE to READ or WRITE delay
		t_ac : time := 5.5 ns; -- Access time
		t_wr : time := 14 ns; -- Write recovery time (no auto precharge)

		counter_max_count : natural := 2 ** 30
	);
	port (
		clk, reset : in std_logic;
		counter_start : in boolean;
		counter_pause : in boolean;
		counter_done : out boolean;
		counter_max : in natural range 0 to counter_max_count - 1;

		counter_refresh_reset : in boolean;
		counter_refresh_needed : out boolean
	);
end sdram_dp;

architecture a1 of sdram_dp is

	signal counter : natural range 0 to counter_max_count - 1;

	signal cnt_rn_i : boolean; --refresh needed
	constant cnt_ref_cc : natural := delay2cycles(clock_speed,
	refresh_interval);
	signal cnt_ref : natural range 0 to cnt_ref_cc - 1;
begin

	--refresh counter
	counter_refresh_needed <= cnt_rn_i or (cnt_ref = cnt_ref_cc - 1);
	process (clk, reset, counter_refresh_reset, cnt_ref)
	begin
		if (reset = '1') then
			cnt_ref <= 0;
			cnt_rn_i <= false;
		elsif (rising_edge(clk)) then
			if (counter_refresh_reset) then
				cnt_rn_i <= false;
			end if;

			if (cnt_ref = cnt_ref_cc - 1) then
				cnt_ref <= 0;
				cnt_rn_i <= true;
			else
				cnt_ref <= cnt_ref + 1;
			end if;

		end if;
	end process;

	--general purpose counter
	counter_done <= true when counter = counter_max - 1 else
		false;
	process (clk, reset, counter_max)
	begin
		if (reset = '1') then
			counter <= 0;
		elsif (rising_edge(clk)) then
			if (counter_start) then
				if (counter_pause = false) then

					if (counter < counter_max - 1)
						then
						counter <= counter + 1;
					else
						counter <= 0;
					end if;

				end if;
			else
				counter <= 0;
			end if;
		end if;
	end process;

	--refresh counter

end a1;