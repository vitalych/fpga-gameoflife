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
--Game Of Life: compute the state of the grid
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gol2_lib.all;
use work.functions.all;

--This module computes the new state of the grid.
--The process begins when the first line of the grid
--has been displayed.
--It uses the computeline module to do the actual
--computation.
entity gol2_computegrid is
	generic (
		bank_width : natural;
		gol_cells_per_row : natural := 80;
		gol_cells_per_col : natural := 60
	);
	port (
		clk, reset : in std_logic;

		h_retrace, v_retrace : in std_logic;

		-- the coordinates and the value of the new cell
		cell_grid_address : out unsigned(bank_width - 1 downto 0);
		cell_grid_wdata : out std_logic;
		cell_grid_we : out std_logic;
		cell_grid_bank : out unsigned(1 downto 0);

		-- the addresses of the three cells
		read1_address : out unsigned(bank_width - 1 downto 0);
		read1_data : in std_logic;

		read2_address : out unsigned(bank_width - 1 downto 0);
		read2_data : in std_logic;

		read3_address : out unsigned(bank_width - 1 downto 0);
		read3_data : in std_logic;

		--which buffer do we use?
		ram_select_reg : out std_logic;

		button_nextframe : in std_logic;
		button_singlestep : in std_logic;

		--tells that the next row will be displayed
		next_row_disp : in std_logic;
		--the first row is being displayed
		first_row_disp : in std_logic
	);
end gol2_computegrid;

architecture a1 of gol2_computegrid is
	type state is (init, ss1, ssv, wait_firstrow, wait_rowdisp,
		wait_rowdisp_clear, preload, preload1, compute, wait_compute_done, swap);
	signal current_state, next_state : state;
	signal reload, step_row, step_col, grid_finished, do_swap, line_end : std_logic;
	signal ram_select_reg_i : std_logic;

	signal next_row_disp_i, nrd_reset : std_logic;

	--signal we_i: std_logic;
	signal m3_counter, m3_counter2 : unsigned(1 downto 0);
	signal col_offset, col_offset2, sum : unsigned(bank_width - 1 downto 0);
	signal row_offset, row_offset2 : unsigned(bank_width - 1 downto 0);

	signal preload_start, compute_start, compute_done : std_logic;
begin
	process (clk, next_row_disp, reset)
	begin
		if (reset = '1') then
			next_row_disp_i <= '0';
		elsif (rising_edge(clk)) then
			if (nrd_reset = '1') then
				next_row_disp_i <= '0';
			else
				next_row_disp_i <= next_row_disp;
			end if;
		end if;
	end process;

	--This signal selects the part of the buffer
	--being displayed. It is swapped when the new
	--grid is computed.
	ram_select_reg <= ram_select_reg_i;
	process (clk, do_swap, reset)
	begin
		if (reset = '1') then
			ram_select_reg_i <= '0';
		elsif (rising_edge(clk)) then
			if (do_swap = '1') then
				ram_select_reg_i <= not ram_select_reg_i;
			end if;
		end if;
	end process;

	--modulo 3 counter, used to select the right read bank for vga
	m3c : gol2_m3counter
	generic map(
		width => gol_cells_per_row,
		bank_width => bank_width
	)
	port map(
		clk => clk, reset => reset,
		step_col => step_col,
		step_row => step_row,
		reload => reload,
		col_offset => col_offset,
		row_offset => row_offset,
		m3cnt => m3_counter
	);
	line_end <= '1' when col_offset = gol_cells_per_row - 1 else
		'0';

	--The module responsible for the actual computation
	cl : gol2_computeline generic map(
		bank_width => bank_width,
		height => gol_cells_per_col,
		width => gol_cells_per_row
	)
	port map(
		clk => clk, reset => reset,
		preload_start => preload_start,
		compute_start => compute_start,
		compute_done => compute_done,
		row_offset => row_offset,
		col_offset => col_offset,
		bank => m3_counter,
		read1_address => read1_address,
		read1_data => read1_data,
		read2_address => read2_address,
		read2_data => read2_data,
		read3_address => read3_address,
		read3_data => read3_data,
		cell_grid_address => cell_grid_address,
		cell_grid_wdata => cell_grid_wdata,
		cell_grid_we => cell_grid_we,
		cell_grid_bank => cell_grid_bank
	);

	sum <= col_offset + row_offset;
	grid_finished <= '1' when sum = gol_cells_per_row * gol_cells_per_col/3 - 1 and (m3_counter = 2)else
		'0';

	------------------------------------------------------------------
	--The state machine controlling the computation.
	------------------------------------------------------------------
	process (h_retrace, v_retrace, grid_finished,
		button_nextframe, button_singlestep, current_state,
		next_row_disp_i, line_end, first_row_disp,
		compute_done)
	begin
		next_state <= current_state;
		step_col <= '0';
		step_row <= '1';
		do_swap <= '0';
		reload <= '0';
		nrd_reset <= '0';
		preload_start <= '0';
		compute_start <= '0';

		case current_state is
				--Init state: check the state of the
				--single step mode.
			when init =>
				reload <= '1';
				if (button_singlestep = '1') then
					if (button_nextframe = '0') then
						next_state <= ss1;
					end if;
				else
					next_state <= ssv;
				end if;

				--Wait until the single step button is pressed
			when ss1 =>
				if (button_nextframe = '1') then
					next_state <= ssv;
				end if;

				--we wait for the beginning of the first line
			when ssv =>
				if (first_row_disp = '1') then
					next_state <= preload;
				end if;

				--preload the line
			when preload =>
				preload_start <= '1';
				next_state <= wait_firstrow;

				--we wait until the first row is finished to
				--be displayed.
			when wait_firstrow =>
				if (first_row_disp = '0') then
					next_state <= compute;
				end if;

				--start computation of the line (previously displayed)
			when compute =>
				compute_start <= '1';
				step_col <= '1';

				--if grid finished, swap buffers, otherwise
				--when line end, wait for the end of the line
				--computation.
				if (grid_finished = '1') then
					next_state <= swap;
				elsif (line_end = '1') then
					next_state <= wait_compute_done;
				end if;

				--This state waits for the computeline module.
			when wait_compute_done =>
				if (compute_done = '1') then
					next_state <= preload1;
				end if;

				--Preload the next line
			when preload1 =>
				preload_start <= '1';
				next_state <= wait_rowdisp;

				--we finished computing the line, wait until
				--the next is finished to be displayed
			when wait_rowdisp =>
				if (next_row_disp_i = '1') then
					next_state <= wait_rowdisp_clear;
				end if;

			when wait_rowdisp_clear =>
				nrd_reset <= '1';
				next_state <= compute;

				--exchange the memories
			when swap =>
				do_swap <= '1';
				next_state <= init;

			when others => next_state <= init;
		end case;
	end process;

	process (clk, reset, next_state)
	begin
		if (reset = '1') then
			current_state <= init;
		elsif (clk'event and clk = '1') then
			current_state <= next_state;
		end if;
	end process;

end;