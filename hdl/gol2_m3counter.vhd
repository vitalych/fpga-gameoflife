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
-- Modulo 3 counter
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gol2_lib.all;
use work.functions.all;

--This counter is used extensively throughout the
--the project because of the memory organization.
--It is divided into three banks and modulo 3 using
--normal division is very expensive.
entity gol2_m3counter is
    generic (
        width : natural := 80;
        bank_width : natural
    );
    port (
        clk, reset : in std_logic;
        step_col, step_row, reload : in std_logic;
        col_offset : out unsigned(bank_width - 1 downto 0);
        row_offset : out unsigned(bank_width - 1 downto 0);
        m3cnt : out unsigned(1 downto 0)
    );

end gol2_m3counter;

architecture a1 of gol2_m3counter is
    signal row_i : unsigned(bank_width - 1 downto 0);
    signal col_i : unsigned(bank_width - 1 downto 0);
    signal m3cnt_i : unsigned(1 downto 0);
begin
    row_offset <= row_i;
    col_offset <= col_i;
    m3cnt <= m3cnt_i;

    process (clk, reset)
    begin
        if (reset = '1') then
            col_i <= (others => '0');
            row_i <= (others => '0');
            m3cnt_i <= (others => '0');
        elsif (rising_edge(clk)) then
            if (reload = '1') then
                --we don't compute anything, keep all values zeroed
                col_i <= (others => '0');
                row_i <= (others => '0');
                m3cnt_i <= (others => '0');
            elsif (step_col = '1') then
                --if the last column of the row is reached
                if (col_i < (width - 1)) then
                    col_i <= col_i + 1;
                else

                    --restart at the first column
                    col_i <= (others => '0');
                    --switch to the next bank
                    if (step_row = '1') then
                        if (m3cnt_i = 2) then
                            row_i <= row_i + width;
                            m3cnt_i <= (others => '0');
                        else
                            m3cnt_i <= m3cnt_i + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

end a1;