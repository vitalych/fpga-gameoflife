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

package ram_lib is
	component ram2port2clock is
		generic (
			word_width : natural := 32;
			address_width : natural := 6
		);
		port (
			address_a : in STD_LOGIC_VECTOR (address_width - 1 downto 0);
			address_b : in STD_LOGIC_VECTOR (address_width - 1 downto 0);
			clock_a : in STD_LOGIC;
			clock_b : in STD_LOGIC;
			data_a : in STD_LOGIC_VECTOR (word_width - 1 downto 0);
			data_b : in STD_LOGIC_VECTOR (word_width - 1 downto 0);
			wren_a : in STD_LOGIC := '0';
			wren_b : in STD_LOGIC := '0';
			q_a : out STD_LOGIC_VECTOR (word_width - 1 downto 0);
			q_b : out STD_LOGIC_VECTOR (word_width - 1 downto 0)
		);
	end component;
	component ram is
		generic (
			word_width : natural := 4;
			address_width : natural := 13;
			init_file : string);

		port (
			clk : in std_logic;
			address1 : in unsigned(address_width - 1 downto 0);
			read1_data : out unsigned(word_width - 1 downto 0);
			write1_en : in std_logic;
			write1_data : in unsigned(word_width - 1 downto 0)
		);
	end component;

	component ram2port is
		generic (
			data_width : natural := 3;
			address_width : natural := 16;
			init_file : string
		);
		port (
			clk : in std_logic;
			address1 : in unsigned(address_width - 1 downto 0);
			read1_data : out unsigned(data_width - 1 downto 0);
			write1_en : in std_logic;
			write1_data : in unsigned(data_width - 1 downto 0);

			address2 : in unsigned(address_width - 1 downto 0);
			read2_data : out unsigned(data_width - 1 downto 0);
			write2_en : in std_logic;
			write2_data : in unsigned(data_width - 1 downto 0)
		);
	end component;
end ram_lib;