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
--Game Of Life: compute the state of a line
--------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.gol2_lib.all;
use work.functions.all;

--This module computes the new state of a single line.
--The old state is read from the second buffer (see
--ram_grid_doublebuf) and the new state is written
--to the memory being displayed. The new line overwrites
--the one which has just been displayed. The currently
--displayed line is located in the adjacent bank to the one
--being written to.
--
--General operation mode:
--***********************
--To compute the state of a cell, we need to know the
--state of the 9 cells surrounding it, including itself.
--These cells are stored in line1, line2 and line3 (3*3 buffer).
--When the state of the first cell is computed, the second
--adjacent cell may be computed using the same princip. It
--also requires 9 cells and it shares 6 cells of the previous
--one. That's why the content of the 3*3 buffer may be shifted
--to the left, with the state of the three new cells comming
--on the right.
--These 3 cells may be read at the same time from the three
--separate banks of memory. Thus, we achieve one new cell state
--per clock.
--
--At the beginning it is necessary to fill the 3*3 buffer to
--initiate the continuous computation.
--
--

entity gol2_computeline is
	generic (
		bank_width : natural;
		width, height : natural
	);
	port (
		clk, reset : std_logic;

		--The coordinates of the line to update
		row_offset, col_offset : in unsigned(bank_width - 1 downto 0);
		bank : in unsigned(1 downto 0);

		--The module finished computing the line
		compute_done : out std_logic;
		--Begin to preload the 3*3 buffer
		preload_start : in std_logic;
		--Start computation @1cell/clock
		compute_start : in std_logic;

		--the addresses of the three cells being loaded in
		--the 3*3 buffer.
		read1_address : out unsigned(bank_width - 1 downto 0);
		read1_data : in std_logic;

		read2_address : out unsigned(bank_width - 1 downto 0);
		read2_data : in std_logic;

		read3_address : out unsigned(bank_width - 1 downto 0);
		read3_data : in std_logic;

		--The coordinates of the new cell to write
		cell_grid_address : out unsigned(bank_width - 1 downto 0);
		cell_grid_wdata : out std_logic;
		cell_grid_we : out std_logic;
		cell_grid_bank : out unsigned(1 downto 0)

	);
end gol2_computeline;

architecture a0 of gol2_computeline is
	type state is (s_init, s_preload,
		s_preload1, s_preload2, s_preload3, s_compute_wait,
		s_compute0, s_compute1);
	signal current_state, next_state : state;

	-- 3*3 window
	signal line1 : unsigned(2 downto 0);
	signal line2 : unsigned(2 downto 0);
	signal line3 : unsigned(2 downto 0);

	signal r1, r2, r3 : std_logic;
	signal ra1, ra2, ra3 : unsigned(bank_width - 1 downto 0);

	--the state of the 9 cells and the sum of cells
	--whose state is 1.
	signal nw, n, ne, w, c, e, sw, s, se : std_logic;
	signal sum1, sum2, sum3, sum4 : unsigned(1 downto 0);
	signal sum1a, sum2a : unsigned (2 downto 0);
	signal sum : unsigned(3 downto 0);

	signal preload_i, shift_enable : std_logic;

	signal col_offset_i, col_offset_j : unsigned(bank_width - 1 downto 0);

	signal line1_offset, line2_offset, line3_offset : unsigned(bank_width - 1 downto 0);

	--delayed coordinates for write
	signal row_offset_s, col_offset_s : unsigned(bank_width - 1 downto 0);
	signal grid_bank_s : unsigned(1 downto 0);
	signal we_s, w_data_i : std_logic;
begin

	--delayed write coordinates update.
	--These coordinates have to be saved because
	--the requested line/column in row_offset and col_offset
	--will arrive at the next clock cycle.
	--The new state will be available to be written only
	--on this next cycle.
	cell_grid_address <= row_offset_s + col_offset_s;
	cell_grid_we <= we_s;
	cell_grid_bank <= grid_bank_s;
	cell_grid_wdata <= w_data_i;
	process (clk, reset)
	begin
		if (reset = '1') then
			row_offset_s <= (others => '0');
			col_offset_s <= (others => '0');
			grid_bank_s <= (others => '0');
		elsif (rising_edge(clk)) then
			row_offset_s <= row_offset;
			col_offset_s <= col_offset;
			grid_bank_s <= bank;
		end if;
	end process;

	process (current_state, preload_start, compute_start, col_offset_i,
		row_offset, col_offset, bank)
	begin
		next_state <= current_state;
		preload_i <= '0';
		shift_enable <= '0';
		we_s <= '0';
		compute_done <= '0';

		case current_state is
				--Initial state, wait for the preload signal
			when s_init =>
				compute_done <= '1';
				if (preload_start = '1') then
					next_state <= s_preload;
				end if;

				--First preload state.
			when s_preload =>
				preload_i <= '1';
				shift_enable <= '0';
				next_state <= s_preload1;

				--Here comes the first 3 bits
				--requested in s_preload. Enable shifting
			when s_preload1 =>
				preload_i <= '1';
				shift_enable <= '1';
				next_state <= s_preload2;

				--Load the 3 subsequent bits
			when s_preload2 =>
				preload_i <= '1';
				shift_enable <= '1';
				next_state <= s_preload3;

				--The last 3 bits come in this state.
				--At the end the 3*3 buffer is full.
			when s_preload3 =>
				preload_i <= '1';
				shift_enable <= '1';
				next_state <= s_compute_wait;

				--When the buffer is full, disable shift
				--register and wait for the compute signal
			when s_compute_wait =>
				if (compute_start = '1') then
					next_state <= s_compute0;
				end if;

				--Compute loop.	
			when s_compute0 =>
				shift_enable <= '1';
				we_s <= '1';

				--compute_start must be asserted during
				--the whole process
				if (compute_start = '0') then
					next_state <= s_init;
				elsif (col_offset = width - 1) then
					next_state <= s_compute1;
				end if;

				--When the last bit has been loaded, we
				--still need on cycle more to write it to memory.
			when s_compute1 =>
				shift_enable <= '1';
				we_s <= '1';
				compute_done <= '1';
				next_state <= s_init;

			when others => null;
		end case;
	end process;

	process (clk, reset)
	begin
		if (reset = '1') then
			current_state <= s_init;
		elsif (rising_edge(clk)) then
			current_state <= next_state;
		end if;

	end process;

	--Compute the new cell state
	nw <= line1(2);
	n <= line1(1);
	ne <= line1(0);
	w <= line2(2);
	c <= line2(1);
	e <= line2(0);
	sw <= line3(2);
	s <= line3(1);
	se <= line3(0);

	sum1 <= ('0' & nw) + ('0' & n);
	sum2 <= ('0' & ne) + ('0' & w);
	sum3 <= ('0' & e) + ('0' & sw);
	sum4 <= ('0' & s) + ('0' & se);

	sum1a <= ('0' & sum1) + ('0' & sum2);
	sum2a <= ('0' & sum3) + ('0' & sum4);

	sum <= ('0' & sum1a) + ('0' & sum2a);

	process (sum, c)
	begin
		w_data_i <= '0';
		if (c = '0') then
			if (sum = 3) then
				w_data_i <= '1';
			end if;
		else
			if (sum = 2 or sum = 3) then
				w_data_i <= '1';
			end if;
		end if;
	end process;

	--shift register handling
	process (clk, reset)
	begin
		if (reset = '1') then
			line1 <= (others => '0');
			line2 <= (others => '0');
			line3 <= (others => '0');
		elsif (rising_edge(clk)) then
			if (shift_enable = '1') then
				line1 <= line1(1 downto 0) & r1;
				line2 <= line2(1 downto 0) & r2;
				line3 <= line3(1 downto 0) & r3;
			end if;
		end if;
	end process;

	--computes the preload column offset
	process (clk, reset)
	begin
		if (reset = '1') then
			col_offset_i <= (others => '0');
		elsif (rising_edge(clk)) then
			if (preload_i = '1')
				then
				col_offset_i <= col_offset_i + 1;
			else
				col_offset_i <= (others => '0');
			end if;
		end if;
	end process;

	--select the right column
	col_offset_j <= unsigned(col_offset) when (preload_i = '0') else
		col_offset_i;

	--compute the addresses.
	--This is the trickiest part.
	--The grid is toroidal: the address has to wrap around.
	--We also have to play with bank addresses.
	process (col_offset_j, row_offset, read1_data,
		read2_data, read3_data, bank, ra1, ra2, ra3, preload_i,
		line1_offset, line2_offset, line3_offset)

	begin
		--default values
		ra1 <= row_offset;
		ra2 <= row_offset;
		ra3 <= row_offset;
		line1_offset <= to_unsigned(0, bank_width);
		line2_offset <= to_unsigned(0, bank_width);
		line3_offset <= to_unsigned(0, bank_width);

		--Depending on the current bank (the one of the 
		--line being computed), the line above or below
		--the current one may be located in different banks.

		--We have to add a special offset if the current
		--bank is not the bank 1 (ie: 0 or 2). See the report
		--for diagramms explaining it.
		if (bank = 0) then
			line1_offset <= not(to_unsigned(width, bank_width)) + 1;
			r1 <= read3_data;
			read3_address <= (ra1);
			r2 <= read1_data;
			read1_address <= (ra2);
			r3 <= read2_data;
			read2_address <= (ra3);
		elsif (bank = 1) then
			r1 <= read1_data;
			read1_address <= (ra1);
			r2 <= read2_data;
			read2_address <= (ra2);
			r3 <= read3_data;
			read3_address <= (ra3);
		else
			line3_offset <= to_unsigned(+width, bank_width);
			r1 <= read2_data;
			read2_address <= (ra1);
			r2 <= read3_data;
			read3_address <= (ra2);
			r3 <= read1_data;
			read1_address <= (ra3);
		end if;

		--We distinguish preload state from the normal compute state
		if (preload_i = '1') then
			-- top line
			if (row_offset = 0 and bank = 0) then
				if (col_offset_j = 0) then
					ra1 <= to_unsigned((height) * width/3 - 1, ra1'length);
					ra2 <= to_unsigned(width - 1, ra2'length);
					ra3 <= to_unsigned(width - 1, ra3'length);
				elsif (col_offset_j = 1) then
					ra1 <= to_unsigned((height) * width/3 - width, ra1'length);
					ra2 <= to_unsigned(0, ra2'length);
					ra3 <= to_unsigned(0, ra3'length);
				elsif (col_offset_j = 2) then
					ra1 <= to_unsigned((height) * width/3 - width + 1, ra1'length);
					ra2 <= to_unsigned(1, ra2'length);
					ra3 <= to_unsigned(1, ra3'length);
				end if;
				--bottom line
			elsif (row_offset = (height) * width/3 - width and bank = 2) then
				if (col_offset_j = 0) then
					ra1 <= to_unsigned(height * width/3 - 1, ra1'length);
					ra2 <= to_unsigned(height * width/3 - 1, ra2'length);
					ra3 <= to_unsigned(width - 1, ra3'length);
				elsif (col_offset_j = 1) then
					ra1 <= to_unsigned((height) * width/3 - width, ra1'length);
					ra2 <= to_unsigned((height) * width/3 - width, ra2'length);
					ra3 <= to_unsigned(0, ra3'length);
				elsif (col_offset_j = 2) then
					ra1 <= to_unsigned((height) * width/3 - width + 1, ra1'length);
					ra2 <= to_unsigned((height) * width/3 - width + 1, ra2'length);
					ra3 <= to_unsigned(1, ra3'length);
				end if;
				--middle lines
			else
				if (col_offset_j = 0) then
					ra1 <= row_offset + width - 1 + line1_offset;
					ra2 <= row_offset + width - 1 + line2_offset;
					ra3 <= row_offset + width - 1 + line3_offset;
				elsif (col_offset_j = 1) then
					ra1 <= row_offset + line1_offset;
					ra2 <= row_offset + line2_offset;
					ra3 <= row_offset + line3_offset;
				elsif (col_offset_j = 2) then
					ra1 <= row_offset + 1 + line1_offset;
					ra2 <= row_offset + 1 + line2_offset;
					ra3 <= row_offset + 1 + line3_offset;
				end if;
			end if;
			--when processing the rest of the line
		else
			--top line
			if (row_offset = 0 and bank = 0) then
				if (col_offset_j < width - 2) then
					ra1 <= to_unsigned((height) * width/3 - width + 2, ra1'length) + col_offset_j;
					ra2 <= row_offset + col_offset_j + 2;
					ra3 <= row_offset + col_offset_j + 2;
				else
					ra1 <= to_unsigned(height * width/3 - width, ra1'length);
					ra2 <= row_offset;
					ra3 <= row_offset;
				end if;
				--bottom line
			elsif (row_offset = height * width /3 - width and bank = 2) then
				if (col_offset_j < width - 2) then
					ra1 <= row_offset + col_offset_j + 2;
					ra2 <= row_offset + col_offset_j + 2;
					ra3 <= col_offset_j + 2;
				else
					ra1 <= row_offset;
					ra2 <= row_offset;
					ra3 <= to_unsigned(0, ra3'length);
				end if;
				--middle lines
			else
				if (col_offset_j < width - 2) then
					ra1 <= row_offset + col_offset_j + 2 + line1_offset;
					ra2 <= row_offset + col_offset_j + 2 + line2_offset;
					ra3 <= row_offset + col_offset_j + 2 + line3_offset;
				else
					ra1 <= row_offset + line1_offset;
					ra2 <= row_offset + line2_offset;
					ra3 <= row_offset + line3_offset;
				end if;
			end if;
		end if;
	end process;

end a0;