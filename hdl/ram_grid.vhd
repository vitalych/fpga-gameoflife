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
-- Grid RAM
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.functions.all;

--This RAM contains the grid of the game of life.
--It is organized into three banks to allow to
--read three cells at the same time and thus
--compute the new state of a cell in only one clock
--cycle.
--There is no 3-port ram so we take three single
--port ram and put 3k lines in the first bank,
--3k+1 lines in the second bank and 3k+2 lines in
--the third bank.
entity ram_grid is
    generic (
        block_address_width : natural := 11;
        file1, file2, file3 : string
    );

    port (
        clk : in std_logic;

        address1 : in unsigned(block_address_width - 1 downto 0);
        read1_data : out std_logic;
        write1_en : in std_logic;
        write1_data : in std_logic;

        address2 : in unsigned(block_address_width - 1 downto 0);
        read2_data : out std_logic;
        write2_en : in std_logic;
        write2_data : in std_logic;

        address3 : in unsigned(block_address_width - 1 downto 0);
        read3_data : out std_logic;
        write3_en : in std_logic;
        write3_data : in std_logic
    );
end ram_grid;

architecture a1 of ram_grid is
    ----------------------------
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
    ----------------------------

begin

    mem1 : ram generic map(init_file => file1, word_width => 1, address_width => block_address_width)
    port map(
        clk => clk, address1 => address1, read1_data(0) => read1_data, write1_en => write1_en,
        write1_data(0) => write1_data);

    mem2 : ram generic map(init_file => file2, word_width => 1, address_width => block_address_width)
    port map(
        clk => clk, address1 => address2, read1_data(0) => read2_data,
        write1_en => write2_en, write1_data(0) => write2_data);

    mem3 : ram generic map(init_file => file3, word_width => 1, address_width => block_address_width)
    port map(
        clk => clk, address1 => address3, read1_data(0) => read3_data,
        write1_en => write3_en, write1_data(0) => write3_data);
end a1;