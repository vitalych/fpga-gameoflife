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
-- Grid RAM Double buffer management
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gol2_lib.all;

--There are 2 buffers: the first is used by
--to display the grid and to write the new state
--of the cells, while the second contains the
--previous state of the grid. It is read by
--the gol2_computeline module. This bank
--is also updated by the downloader module when
--a new grid is uploaded by the user.

--The trick is that the vga controller gets the
--data of the bank following the one used by
--gol2_computeline to write the new state.
--In others words, as soon as a line is finished to be
--displayed, it is discarded by the new state.

--The controller must take care of the scheduling:
--it is not possible to display and write to a bank
--at the same time.

entity ram_grid_doublebuf is
	generic (
		block_address_width : natural := 11;
		file1, file2, file3 : string
	);

	port (
		clk : in std_logic;
		ram_select : in std_logic;

		-- the ram being read (original grid) 
		-- The write signals are only used by the grid download module
		read1_address : in unsigned(block_address_width - 1 downto 0);
		read1_data : out std_logic;
		read1_wen : in std_logic;
		read1_wdata : in std_logic;

		read2_address : in unsigned(block_address_width - 1 downto 0);
		read2_data : out std_logic;
		read2_wen : in std_logic;
		read2_wdata : in std_logic;

		read3_address : in unsigned(block_address_width - 1 downto 0);
		read3_data : out std_logic;
		read3_wen : in std_logic;
		read3_wdata : in std_logic;

		--the ram being displayed (and written)
		disp1_address : in unsigned(block_address_width - 1 downto 0);
		disp1_data : out std_logic;
		disp1_wen : in std_logic;
		disp1_wdata : in std_logic;

		disp2_address : in unsigned(block_address_width - 1 downto 0);
		disp2_data : out std_logic;
		disp2_wen : in std_logic;
		disp2_wdata : in std_logic;

		disp3_address : in unsigned(block_address_width - 1 downto 0);
		disp3_data : out std_logic;
		disp3_wen : in std_logic;
		disp3_wdata : in std_logic
	);

end ram_grid_doublebuf;

architecture a1 of ram_grid_doublebuf is
	--signals for the first buffer
	signal a1, a2, a3 : unsigned(block_address_width - 1 downto 0);
	signal we1, we2, we3 : std_logic;
	signal rd1, rd2, rd3 : std_logic;
	signal wd1, wd2, wd3 : std_logic;

	--signals for the second buffer
	signal da1, da2, da3 : unsigned(block_address_width - 1 downto 0);
	signal dwe1, dwe2, dwe3 : std_logic;
	signal drd1, drd2, drd3 : std_logic;
	signal dwd1, dwd2, dwd3 : std_logic;
begin
	a1 <= read1_address when ram_select = '0' else
		disp1_address;
	a2 <= read2_address when ram_select = '0' else
		disp2_address;
	a3 <= read3_address when ram_select = '0' else
		disp3_address;

	read1_data <= rd1 when ram_select = '0' else
		drd1;
	read2_data <= rd2 when ram_select = '0' else
		drd2;
	read3_data <= rd3 when ram_select = '0' else
		drd3;

	we1 <= read1_wen when ram_select = '0' else
		disp1_wen;
	we2 <= read2_wen when ram_select = '0' else
		disp2_wen;
	we3 <= read3_wen when ram_select = '0' else
		disp3_wen;

	wd1 <= read1_wdata when ram_select = '0' else
		disp1_wdata;
	wd2 <= read2_wdata when ram_select = '0' else
		disp2_wdata;
	wd3 <= read3_wdata when ram_select = '0' else
		disp3_wdata;

	-------------------------------

	da1 <= read1_address when ram_select = '1' else
		disp1_address;
	da2 <= read2_address when ram_select = '1' else
		disp2_address;
	da3 <= read3_address when ram_select = '1' else
		disp3_address;

	disp1_data <= rd1 when ram_select = '1' else
		drd1;
	disp2_data <= rd2 when ram_select = '1' else
		drd2;
	disp3_data <= rd3 when ram_select = '1' else
		drd3;

	dwe1 <= read1_wen when ram_select = '1' else
		disp1_wen;
	dwe2 <= read2_wen when ram_select = '1' else
		disp2_wen;
	dwe3 <= read3_wen when ram_select = '1' else
		disp3_wen;

	dwd1 <= read1_wdata when ram_select = '1' else
		disp1_wdata;
	dwd2 <= read2_wdata when ram_select = '1' else
		disp2_wdata;
	dwd3 <= read3_wdata when ram_select = '1' else
		disp3_wdata;

	-------------------------------

	rg1 : ram_grid generic map(
		block_address_width => block_address_width,
		file1 => file1, file2 => file2, file3 => file3
	)
	port map(
		clk => clk,
		address1 => a1,
		address2 => a2,
		address3 => a3,

		read1_data => rd1,
		read2_data => rd2,
		read3_data => rd3,

		write1_en => we1,
		write2_en => we2,
		write3_en => we3,

		write1_data => wd1,
		write2_data => wd2,
		write3_data => wd3
	);
	rg2 : ram_grid generic map(
		block_address_width => block_address_width,
		file1 => file1, file2 => file2, file3 => file3
	)
	port map(
		clk => clk,
		address1 => da1,
		address2 => da2,
		address3 => da3,

		read1_data => drd1,
		read2_data => drd2,
		read3_data => drd3,

		write1_en => dwe1,
		write2_en => dwe2,
		write3_en => dwe3,

		write1_data => dwd1,
		write2_data => dwd2,
		write3_data => dwd3);
end;