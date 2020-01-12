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
--UART Receiver Datapath
--This entity is used by uart_receive
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--For the signal description, see the state machine
entity uart_recv_dp is
  generic (
    clock_speed : natural := 33000000;
    baud_rate : natural := 115200;
    cc_size : natural
  );
  port (
    clk : in std_logic;
    reset : in std_logic;
    rx : in std_logic;
    data : out unsigned(7 downto 0);
    parity_ok : out std_logic;
    rx_data_en : in std_logic;

    sc_iseleven : out std_logic;

    cc_incr : in std_logic;
    cc_reset : in std_logic;
    cc_max : in unsigned(cc_size - 1 downto 0);
    cc_half : in unsigned(cc_size - 1 downto 0)
  );
end uart_recv_dp;

architecture rxdp of uart_recv_dp is

  signal sc_incr : std_logic;
  signal sc_shift : std_logic;
  signal sc_iseleven_i : std_logic;
  signal cc_ishalf : std_logic;

  signal hold_reg : unsigned(10 downto 0);
  signal shift_reg : unsigned(10 downto 0);
  signal cc_reg : unsigned(cc_size - 1 downto 0);
  signal sc_reg : unsigned(3 downto 0);

  signal parity_i : std_logic;
  signal parity_ok_hold_reg : std_logic;

begin
  sc_iseleven <= sc_iseleven_i;
  data <= hold_reg(8 downto 1);
  parity_ok <= parity_ok_hold_reg;

  --Data hold register
  --It copies the received data from the
  --shit register when it is received.
  process (clk, reset)
  begin
    if (reset = '1') then
      hold_reg <= (others => '0');
    elsif (clk'event and clk = '1') then
      if (sc_iseleven_i = '1') then
        hold_reg <= shift_reg;
      end if;
    end if;
  end process;

  --Parity hold register
  process (clk, reset)
  begin
    if (reset = '1') then
      parity_ok_hold_reg <= '0';
    elsif (clk'event and clk = '1') then
      if (sc_iseleven_i = '1') then
        parity_ok_hold_reg <= parity_i;
      end if;
    end if;
  end process;

  --Parity register
  --If a one is received, the parity is
  --negated. At the end of the process
  --a one in this register signals no error
  --in the case of the even parity.
  process (clk, reset, cc_reset)
  begin
    if (reset = '1') then
      parity_i <= '0';
    elsif (clk'event and clk = '1') then
      if (cc_reset = '1') then
        parity_i <= '0';
      elsif (sc_shift = '1' and rx = '1') then
        parity_i <= not parity_i;
      end if;
    end if;
  end process;

  --Shift register
  --Rx data is shifted into the register at the
  --half of the count. We use the half because
  --the input signal is stabilized at this stage.
  sc_shift <= rx_data_en and cc_ishalf;
  process (clk, reset, sc_shift)
  begin
    if (reset = '1') then
      shift_reg <= (others => '0');
    elsif (clk'event and clk = '1') then
      if (sc_shift = '1') then
        shift_reg <= rx & shift_reg(10 downto 1);
      end if;
    end if;
  end process;

  --Shift counter
  --Counts to 11 because there are 11 bits to receive
  process (clk, reset, sc_shift, cc_reset)
  begin
    if (reset = '1') then
      sc_reg <= (others => '0');
    elsif (clk'event and clk = '1') then
      if (sc_reg = "1011" or (cc_reset = '1')) then
        sc_reg <= (others => '0');
      elsif (sc_shift = '1') then
        sc_reg <= sc_reg + 1;
      end if;
    end if;
  end process;
  sc_iseleven_i <= '1' when sc_reg = "1011" else
    '0';

  --cycle counter
  --It determines when the bits are received.
  process (clk, reset, cc_incr, cc_reset)
  begin
    if (reset = '1') then
      cc_reg <= (others => '0');
    elsif (clk'event and clk = '1') then
      if (cc_reset = '1') then
        cc_reg <= (others => '0');
      elsif (cc_incr = '1') then
        if (cc_reg = cc_max)
          then
          cc_reg <= (others => '0');
        else
          cc_reg <= cc_reg + 1;
        end if;
      end if;
    end if;
  end process;
  cc_ishalf <= '1' when cc_reg = cc_half else
    '0';

end rxdp;