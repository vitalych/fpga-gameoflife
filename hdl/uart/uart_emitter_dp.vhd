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
--UART Emitter data path
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_emitter_dp is
   generic (cc_size : natural);
   port (
      clk : in std_logic;
      reset : in std_logic;

      --shift register control
      sr_ld : in std_logic;
      sr_shift : in std_logic;
      --The 8 bit word data to be transmitted
      sr_data_in : in unsigned(7 downto 0);

      --shift counter, from 0 to 7
      sc_start : in std_logic;
      sc_isseven : out std_logic;

      --cycle counter
      cc_start : in std_logic;
      cc_maxval : in unsigned(cc_size - 1 downto 0);
      cc_ismax : out std_logic;

      --which bit do we select?
      --start, data, parity or stop bit ?
      tx_sel : in unsigned(1 downto 0);

      --The transmitted data, to the transciever
      tx_out : out std_logic
   );
end uart_emitter_dp;

architecture edp1 of uart_emitter_dp is
   type parity_state is (odd, even);
   signal current_pstate, next_pstate : parity_state;

   signal sr_data : unsigned(7 downto 0);
   signal sr_out : std_logic;
   signal parity : std_logic;

   signal seven_counter : unsigned(2 downto 0);

   signal cycle_counter : unsigned(cc_size - 1 downto 0);
begin
   -- shift register
   process (clk, reset)
   begin
      if (reset = '1') then
         sr_data <= (others => '0');
      elsif (clk'event and clk = '1') then
         if (sr_ld = '1') then
            sr_data <= sr_data_in;
         elsif (sr_shift = '1') then
            sr_data <= '0' & sr_data(7 downto 1);
         end if;
      end if;
   end process;
   sr_out <= sr_data(0);

   --parity
   process (clk, current_pstate, sr_out, sr_shift)
   begin
      parity <= '1';
      case current_pstate is
         when even =>
            parity <= '1';
            if (sr_out = '1' and sr_shift = '1')
               then
               next_pstate <= odd;
            else
               next_pstate <= even;
            end if;

         when odd =>
            parity <= '0';
            if (sr_out = '1' and sr_shift = '1')
               then
               next_pstate <= even;
            else
               next_pstate <= odd;
            end if;

      end case;
   end process;

   process (clk, reset)
   begin
      if (reset = '1') then
         current_pstate <= even;
      elsif (clk'event and clk = '1') then
         current_pstate <= next_pstate;
      end if;
   end process;

   --7 counter
   process (clk, reset)
   begin
      if (reset = '1') then
         seven_counter <= (others => '0');
      elsif (clk'event and clk = '1') then
         if (sc_start = '1') then
            seven_counter <= seven_counter + 1;
         end if;
      end if;
   end process;
   sc_isseven <= '1' when seven_counter = 7 else
      '0';

   --cycle counter
   process (clk, reset)
   begin
      if (reset = '1') then
         cycle_counter <= (others => '0');
      elsif (clk'event and clk = '1') then
         if (cc_start = '1') then
            if (cycle_counter = cc_maxval)
               then
               cycle_counter <= (others => '0');
            else
               cycle_counter <= cycle_counter + 1;
            end if;
         else
            cycle_counter <= (others => '0');
         end if;

      end if;
   end process;
   cc_ismax <= '1' when cycle_counter = cc_maxval else
      '0';

   --Select the right bit for transmission
   --Depending on the state of the transmission, the bit
   --can be the start bit, a data bit, a parity bit or a stop bit.
   tx_out <=
      '0' when tx_sel = "00" else
      sr_out when tx_sel = "01" else
      parity when tx_sel = "10" else
      '1' when tx_sel = "11" else
      '1';

end;