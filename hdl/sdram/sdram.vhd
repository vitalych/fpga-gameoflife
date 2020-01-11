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
--SDRAM controller
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sdram_lib.all;
use work.functions.all;
--This is a simple SDRAM controller. It supports only
--full page bursts and automatical refresh when idle.
--It uses generic parameters to accomodate for various
--clock frequencies. See the SDRAM specification for more
--information about the meaning of the signals.
--This controller was based on the ISSI IS42S32800B chip.
--
--Description of user IO pins
--***************************
--address: the address of the IO request (read or write)
--data_read: outputs the data when it is ready
--data_write: data to be written to the sdram
--op_begin: signals to the controller the beginning of
--          an IO operation
--do_write: has to be asserted together with op_begin if
--          the requested operation is a write
--read_valid: the word corresponding to the requested address
--is ready on the data_read port. read_valid will be asserted
--as long as op_begin is high. This enables burst reads. The
--length of the burst is one page of the SDRAM (col_width).
--When the end of the page is read the chip restarts from the
--first word of the column.
--
--write_valid: signals that the input word is being written
--to the SDRAM. It is asserted at the same time the write command
--is issued to the SDRAM chip. The user has to provide the next
--word of data on the next cycle or drop op_begin to stop the
--write operation.
--
--bank_activated: signals the activation of the bank. The actual
--IO operation will begin on the next cycle. This signal allows
--the user to prepare data for a write for instance (on-chip ram
--of the Altera Cyclone II has one cycle delay for reads).
--
--Note about the address: it is used to select the bank and the
--row. It also gives the first column of the IO operation to
--start the burst. It is unused during the rest of the burst
--operation.
--
--Note about refresh. The controller takes care of the refreshes
--only during the idle state. It is up to the user to interrupt
--bursts after at most the length equivalent to one page size
--has been read or written. The user may issue another operation
--immediately: the operation will begin as soon as the refresh
--is done.
--
entity sdram is
	generic (
		clock_speed : natural := 33000000;
		row_width : natural := 12;
		col_width : natural := 9;
		bank_width : natural := 2;
		data_width : natural := 32;
		dqm_size : natural := 4;
		cas_latency_cycles : natural := 2;
		init_refresh_cycles : natural := 2
	);

	port (
		clk, reset : std_logic;
		cke, cs, ras_n, cas_n, we_n : out std_logic;
		sdram_address : out unsigned(row_width - 1 downto 0);
		bank_select : out unsigned(bank_width - 1 downto 0);
		dqm : out unsigned(dqm_size - 1 downto 0);
		data : inout unsigned(data_width - 1 downto 0);
		--user ports
		address : in unsigned(row_width + col_width + bank_width - 1 downto 0);
		data_read : out unsigned(data_width - 1 downto 0);
		op_begin : in boolean;
		read_valid, write_valid, bank_activated : out boolean;
		data_write : in unsigned(data_width - 1 downto 0);
		do_write : in boolean;

		controller_ready : out boolean
	);
end sdram;

architecture a1 of sdram is
	constant refresh_interval : time := 15.625 us;
	constant powerup_delay : time := 200 us;
	constant t_rfc : time := 70 ns; --Duration of refresh command
	constant t_rp : time := 20 ns; -- Duration of precharge command
	constant t_rcd : time := 20 ns; -- ACTIVE to READ or WRITE delay
	constant t_ac : time := 5.5 ns; -- Access time
	constant t_wr : time := 14 ns; -- Write recovery time (no auto precharge)

	--Command codes used by the SDRAM
	subtype crcw is unsigned (3 downto 0);
	constant crcw_cs_high : crcw := "1XXX";
	constant crcw_nop : crcw := "0111";
	constant crcw_precharge_all : crcw := "0010";
	constant crcw_mode_init : crcw := "0000";
	constant crcw_autorefresh : crcw := "0001";
	constant crcw_bank_activate : crcw := "0011";
	constant crcw_read : crcw := "0101";
	constant crcw_write : crcw := "0100";
	constant crcw_burst_terminate : crcw := "0110";

	signal cs_ras_cas_we : unsigned(3 downto 0);

	type powerup_state is (pw_init, pw_pause,
		pw_precharge1, pw_modeinit1, pw_modeinit2,
		pw_autorefresh1, pw_autorefresh2,
		pw_loop,
		pw_autorefresh_normal1, pw_autorefresh_normal2,
		pw_precharge_all,
		pw_bank_activate1, pw_bank_activate2,
		pw_read1, pw_read1a, pw_read2, pw_read3,
		pw_write1, pw_write2, pw_read_end, pw_write_end);
	signal pw_current_state, pw_next_state : powerup_state;

	constant counter_max_count : natural := 2 ** 30;
	signal counter_start, counter_done, counter_pause : boolean;
	signal counter_max : natural range 0 to counter_max_count - 1;

	signal counter_refresh_reset : boolean;
	signal counter_refresh_needed : boolean;

	signal in_address : unsigned(data_width - 1 downto 0);
	signal in_do_write : boolean;

	signal data_write_i : unsigned(31 downto 0);
	signal data_read_i : unsigned(31 downto 0);
begin

	cs <= cs_ras_cas_we(3);
	ras_n <= cs_ras_cas_we(2);
	cas_n <= cs_ras_cas_we(1);
	we_n <= cs_ras_cas_we(0);

	--This process controls the data INOUT port.
	--By default it is in tristate mode.
	process (pw_current_state, data, data_write)
	begin
		data_read <= (others => '0');
		data <= (others => 'Z');
		if (pw_current_state = pw_write1 or pw_current_state = pw_write2) then
			data <= data_write;
		elsif (pw_current_state = pw_read3) then
			data_read <= data;
		end if;
	end process;
	process (pw_current_state, counter_done,
		counter_refresh_needed, op_begin, do_write, address)
	begin
		pw_next_state <= pw_current_state;

		controller_ready <= false;
		write_valid <= false;
		bank_activated <= false;

		cs_ras_cas_we <= crcw_nop;
		cke <= '1';
		dqm <= (others => '1'); --Data is masked by default
		bank_select <= (others => '0');
		sdram_address <= (others => '0');

		read_valid <= false;
		counter_start <= false;
		counter_pause <= false;
		counter_max <= 2 ** 30 - 1;
		counter_refresh_reset <= true;
		case pw_current_state is
				--SDRAM initialisation cycle.
				--See ISSI documentation for more information.
			when pw_init =>
				pw_next_state <= pw_pause;

				--There must be a pause before any operation afer
				--a power up.
			when pw_pause =>
				counter_start <= true;
				counter_max <= delay2cycles(clock_speed, powerup_delay);
				if (counter_done) then
					pw_next_state <= pw_precharge1;
				end if;

				--The next step is to precharge all banks.
			when pw_precharge1 =>
				cs_ras_cas_we <= crcw_precharge_all;
				sdram_address(10) <= '1';
				counter_start <= true;
				counter_max <= delay2cycles(clock_speed, t_rp);

				if (counter_done) then
					pw_next_state <= pw_modeinit1;
				end if;

				--set mode requires minimum 2 clock cycles to complete
			when pw_modeinit1 =>
				cs_ras_cas_we <= crcw_mode_init;
				bank_select <= (others => '0');
				sdram_address(2 downto 0) <= "111"; -- full page
				sdram_address(3) <= '0';
				sdram_address(6 downto 4) <= to_unsigned(cas_latency_cycles, 3);
				sdram_address(8 downto 7) <= (others => '0');
				sdram_address(9) <= '0';
				sdram_address(11 downto 10) <= (others => '0');
				--pw_next_state <= pw_modeinit2;

				counter_start <= true;
				counter_max <= 2;
				if (counter_done) then
					pw_next_state <= pw_autorefresh1;
				end if;

				--				when pw_modeinit2 =>
				--					cs_ras_cas_we <= crcw_mode_init;
				--					bank_select <= (others=>'0');
				--					sdram_address(2 downto 0) <= "111"; -- burst length is full page
				--					sdram_address(3) <= '0';
				--					sdram_address(6 downto 4) <= to_unsigned(cas_latency_cycles, 3);
				--					sdram_address(8 downto 7) <= (others=>'0');
				--					sdram_address(9) <= '0';
				--					sdram_address(11 downto 10) <= (others=>'0');
				--					pw_next_state <= pw_autorefresh1;

				--first auto refresh cycle
			when pw_autorefresh1 =>
				counter_start <= true;
				counter_max <= delay2cycles(clock_speed, t_rfc);
				cs_ras_cas_we <= crcw_autorefresh;
				pw_next_state <= pw_autorefresh2;

				--second autorefresh cycle
			when pw_autorefresh2 =>
				counter_start <= true;
				counter_max <= delay2cycles(clock_speed, t_rfc);
				cs_ras_cas_we <= crcw_cs_high; --cs high for auto refresh
				if (counter_done) then
					pw_next_state <= pw_autorefresh_normal1;
				end if;

				----------------------------------	
				----------------------------------					
				--Idle state of the controller
			when pw_loop =>
				controller_ready <= true;
				counter_refresh_reset <= false;
				if (counter_refresh_needed) then
					pw_next_state <= pw_autorefresh_normal1;
				elsif (op_begin) then
					pw_next_state <= pw_bank_activate1;
				end if;

				--This is autorefresh done during normal operation
			when pw_autorefresh_normal1 =>
				counter_refresh_reset <= true;
				counter_start <= true;
				counter_max <= delay2cycles(clock_speed, t_rfc);
				cs_ras_cas_we <= crcw_autorefresh;

				pw_next_state <= pw_autorefresh_normal2;

			when pw_autorefresh_normal2 =>
				counter_start <= true;
				counter_max <= delay2cycles(clock_speed, t_rfc);
				cs_ras_cas_we <= crcw_cs_high;

				if (counter_done) then
					pw_next_state <= pw_loop;
				end if;

			when pw_precharge_all =>
				cs_ras_cas_we <= crcw_precharge_all;
				sdram_address(10) <= '1';
				counter_start <= true;
				counter_max <= delay2cycles(clock_speed, t_rp);

				if (counter_done) then
					pw_next_state <= pw_loop;
				end if;
				--activate bank command
			when pw_bank_activate1 =>
				cs_ras_cas_we <= crcw_bank_activate;
				bank_select <= (others => '0');
				sdram_address <= address(row_width - 1 + col_width downto col_width);

				counter_start <= true;
				counter_max <= delay2cycles(clock_speed, t_rcd);
				pw_next_state <= pw_bank_activate2;

			when pw_bank_activate2 =>
				cs_ras_cas_we <= crcw_cs_high;
				counter_start <= true;
				counter_max <= delay2cycles(clock_speed, t_rcd);
				if (counter_done) then
					bank_activated <= true;
					if (op_begin and not do_write) then
						pw_next_state <= pw_read1;
					elsif (op_begin and do_write) then
						pw_next_state <= pw_write1;
					else
						pw_next_state <= pw_loop;
					end if;
				end if;

				--read command
			when pw_read1 =>
				cs_ras_cas_we <= crcw_read;
				bank_select <= (others => '0');
				sdram_address(col_width - 1 downto 0) <= address(col_width - 1 downto 0);
				dqm <= (others => '0');

				if (cas_latency_cycles = 2)
					then
					pw_next_state <= pw_read2;
				else
					pw_next_state <= pw_read1a;
				end if;

			when pw_read1a =>
				cs_ras_cas_we <= crcw_cs_high;
				dqm <= (others => '0');
				cs_ras_cas_we <= crcw_nop;
				pw_next_state <= pw_read2;

			when pw_read2 =>
				cs_ras_cas_we <= crcw_cs_high;
				dqm <= (others => '0');
				pw_next_state <= pw_read3;
				cs_ras_cas_we <= crcw_nop;

			when pw_read3 =>
				cs_ras_cas_we <= crcw_cs_high;
				dqm <= (others => '0');
				read_valid <= true;
				cs_ras_cas_we <= crcw_nop;
				--if (counter_refresh_needed) then
				--	pw_next_state <= pw_autorefresh_normal1;
				if (op_begin = false) then
					pw_next_state <= pw_read_end;
				end if;

			when pw_read_end =>
				cs_ras_cas_we <= crcw_burst_terminate;
				pw_next_state <= pw_precharge_all;

				--write command
			when pw_write1 =>
				cs_ras_cas_we <= crcw_write;
				bank_select <= (others => '0');
				sdram_address(col_width - 1 downto 0) <= address(col_width - 1 downto 0);
				write_valid <= true;
				dqm <= (others => '0');

				if (do_write = false) then
					pw_next_state <= pw_loop;
				else
					pw_next_state <= pw_write2;
				end if;

			when pw_write2 =>
				cs_ras_cas_we <= crcw_cs_high;
				dqm <= (others => '0');
				write_valid <= true;
				if (do_write = false) then
					pw_next_state <= pw_write_end;
				end if;

			when pw_write_end =>
				cs_ras_cas_we <= crcw_burst_terminate;
				pw_next_state <= pw_precharge_all;
			when others => null;
		end case;
	end process;

	process (clk, reset)
	begin
		if (reset = '1') then
			pw_current_state <= pw_init;
		elsif (rising_edge(clk)) then
			pw_current_state <= pw_next_state;
		end if;
	end process;
	--This module contains various counters to
	--compute refresh delays and operation durations.
	s1 : sdram_dp generic map(
		clock_speed => clock_speed,
		row_width => row_width,
		col_width => col_width,
		bank_width => bank_width,
		data_width => data_width,

		cas_latency_cycles => cas_latency_cycles,
		init_refresh_cycles => init_refresh_cycles,
		refresh_interval => refresh_interval,
		powerup_delay => powerup_delay,
		t_rfc => t_rfc,
		t_rp => t_rp,
		t_rcd => t_rcd,
		t_ac => t_ac,
		t_wr => t_wr,

		counter_max_count => counter_max_count
	)
	port map(
		clk => clk, reset => reset,
		counter_start => counter_start,
		counter_pause => counter_pause,
		counter_done => counter_done,
		counter_max => counter_max,

		counter_refresh_reset => counter_refresh_reset,
		counter_refresh_needed => counter_refresh_needed
	);
end a1;