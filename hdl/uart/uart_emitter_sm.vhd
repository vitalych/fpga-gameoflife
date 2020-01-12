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
--UART Emitter state machine
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_emitter_sm is
   generic (
      clock_speed : natural := 33000000;
      baud_rate : natural := 115200;
      cc_size : natural
   );

   port (
      clk : in std_logic;
      reset : in std_logic;

      write : in std_logic;
      tx_rdy : out std_logic;

      --datapath control
      --shift register control
      sr_ld : out std_logic;
      sr_shift : out std_logic;

      --shift counter
      sc_start : out std_logic;
      sc_isseven : in std_logic;

      --cycle counter
      cc_start : out std_logic;
      cc_maxval : out unsigned(cc_size - 1 downto 0);
      cc_ismax : in std_logic;

      --which bit do we select?
      tx_sel : out unsigned(1 downto 0)
   );
end uart_emitter_sm;

architecture em1 of uart_emitter_sm is
   type state is (init, tx_start, tx_start1, tx_data1, tx_data2, tx_parity, tx_parity1, tx_stop);
   signal current_state, next_state : state;
begin

   process (cc_ismax, sc_isseven, write, current_state)
   begin
      --set default values to everything
      sr_ld <= '0';
      sr_shift <= '0';
      sc_start <= '0';
      cc_start <= '1';
      cc_maxval <= to_unsigned(clock_speed/baud_rate, cc_size);
      tx_sel <= "11"; --default state of serial line
      tx_rdy <= '0';
      case current_state is
            --We wait for the write signal.
            --During this period we load the shift register
            --of the transmitter with the provided data word.
         when init =>
            cc_start <= '0';
            tx_rdy <= '1';
            sr_ld <= '1';
            if (write = '1')
               then
               next_state <= tx_start;
            else
               next_state <= init;
            end if;

            --Begin transmission of the start bit.
         when tx_start =>
            tx_sel <= "00";

            if (cc_ismax = '1')
               then
               next_state <= tx_start1;
            else
               next_state <= tx_start;
            end if;

            --Transmission of start bit done, stop cycle counter
         when tx_start1 =>
            tx_sel <= "00";
            cc_start <= '0';
            next_state <= tx_data1;

            --Transmit 8 bits of data
         when tx_data1 =>
            tx_sel <= "01";

            if (cc_ismax = '1')
               then
               next_state <= tx_data2;
            else
               next_state <= tx_data1;
            end if;
            --Each time a bit is transmitted, we shift
            --the transmit register
         when tx_data2 =>
            tx_sel <= "01";
            sc_start <= '1';
            cc_start <= '0';
            --shift the register
            sr_shift <= '1';

            if (sc_isseven = '1')
               then
               next_state <= tx_parity;
            else
               next_state <= tx_data1;
            end if;

         when tx_parity =>
            tx_sel <= "10";
            if (cc_ismax = '1')
               then
               next_state <= tx_stop;
            else
               next_state <= tx_parity1;
            end if;

         when tx_parity1 =>
            next_state <= tx_stop;

         when tx_stop =>
            tx_sel <= "11";
            if (cc_ismax = '1')
               then
               next_state <= init;
            else
               next_state <= tx_stop;

            end if;

      end case;
   end process;

   process (clk, reset)
   begin
      if reset = '1' then
         current_state <= init;
      elsif (clk'event and clk = '1') then
         current_state <= next_state;
      end if;
   end process;
end;