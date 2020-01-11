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
--UART Receiver state machine
--This entity is used by uart_receive
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_recv_sm is
  generic (
    clock_speed : natural := 33000000;
    baud_rate : natural := 115200;
    cc_size : natural := 10
  );
  port (
    clk : in std_logic;
    reset : in std_logic;
    rx : in std_logic;
    ready : out std_logic;

    rx_data_en : out std_logic;

    --Signaled when 11 bits of a packet a
    --received.    
    sc_iseleven : in std_logic;

    --Cycle counter control.
    --The cycle counter waits for a bit to be received.

    --Increment the counter    
    cc_incr : out std_logic;
    cc_reset : out std_logic;

    --The duration of the bit, set by the state machine
    cc_max : out unsigned(cc_size - 1 downto 0);
    --The duration of a half of a bit.
    cc_half : out unsigned(cc_size - 1 downto 0)
  );
end uart_recv_sm;

architecture sm1 of uart_recv_sm is
  type state is (init, recv, output, err);
  signal current_state, next_state : state;
begin
  process (rx, sc_iseleven, current_state)
  begin
    rx_data_en <= '0';
    cc_incr <= '0';
    cc_reset <= '1';

    --The duration of a bit is specified according to
    --the clock frequency and the baud rate.
    cc_max <= to_unsigned(clock_speed/baud_rate, cc_size);
    cc_half <= to_unsigned(clock_speed/baud_rate/2, cc_size);
    ready <= '0';

    case current_state is
        --As soon as the rx line drops to 
        --zero, begin the receiving process.
        --It is the beginning of the start bit. 
      when init =>
        if (rx = '1')
          then
          next_state <= init;
        else
          next_state <= recv;
        end if;

        --We receive 11 bits of a packet.
        --This include the start bit, data, parity
        --and stop bit. 
      when recv =>
        rx_data_en <= '1';
        cc_incr <= '1';
        cc_reset <= '0';

        if (sc_iseleven = '1')
          then
          next_state <= output;
        else
          next_state <= recv;
        end if;

        --The data is ready. The user can read it.
      when output =>
        ready <= '1';
        if (rx = '1')
          then
          next_state <= init;
        else
          next_state <= err;
        end if;

        --A zero stop bit was received.
        --We wait until the recv line goes to
        --one to restart the process.
      when err =>
        if (rx = '1')
          then
          next_state <= init;
        else
          next_state <= err;
        end if;

    end case;
  end process;
  process (clk, reset)
  begin
    if (reset = '1') then
      current_state <= init;
    elsif (clk'event and clk = '1') then
      current_state <= next_state;
    end if;
  end process;
end;