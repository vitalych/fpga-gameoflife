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
--UART Emitter
--------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.uart_lib.all;
use work.functions.all;

--This is the emitter. It works like the receiver.
--Emission is done with even parity.
entity uart_emitter is
  generic (
    clock_speed : natural := 33000000;
    baud_rate : natural := 115200
  );

  port (
    clk : in std_logic;
    reset : in std_logic;

    data_in : in unsigned(7 downto 0);
    write : in std_logic;
    tx_rdy : out std_logic;
    tx : out std_logic
  );

end uart_emitter;

architecture arch1 of uart_emitter is
  constant cc_size : natural := log2(clock_speed/baud_rate);

  --shift register control
  signal sr_ld : std_logic;
  signal sr_shift : std_logic;

  --shift counter
  signal sc_start : std_logic;
  signal sc_isseven : std_logic;

  --cycle counter
  signal cc_start : std_logic;
  signal cc_maxval : unsigned(cc_size - 1 downto 0);
  signal cc_ismax : std_logic;

  --which bit do we select?
  signal tx_sel : unsigned(1 downto 0);
begin
  dp : uart_emitter_dp
  generic map(cc_size => cc_size)
  port map(
    clk => clk, reset => reset,
    sr_ld => sr_ld, sr_shift => sr_shift, sr_data_in => data_in,
    sc_start => sc_start, sc_isseven => sc_isseven,
    cc_start => cc_start, cc_maxval => cc_maxval, cc_ismax => cc_ismax,
    tx_sel => tx_sel, tx_out => tx);

  sm : uart_emitter_sm
  generic map(clock_speed => clock_speed, baud_rate => baud_rate, cc_size => cc_size)
  port map(
    clk => clk, reset => reset,
    write => write, tx_rdy => tx_rdy, sr_ld => sr_ld, sr_shift => sr_shift,
    sc_start => sc_start, sc_isseven => sc_isseven, cc_start => cc_start,
    cc_maxval => cc_maxval, cc_ismax => cc_ismax, tx_sel => tx_sel);
end;