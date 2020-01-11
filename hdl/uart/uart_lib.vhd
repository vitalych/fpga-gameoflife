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
--UART Library
--This library includes a 115kbps emitter/receiver
--and a file downloader used to load grids and 
--pictures into the internal RAM.
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package uart_lib is
  component file_downloader is
    generic (
      clock_speed : natural := 33000000;
      bus_size : natural := 16;
      baud_rate : natural := 115200
    );

    port (
      clk : in std_logic;
      reset : in std_logic;
      rx : in std_logic;

      --The address of the bit. Incremented for each bit
      --or each nibble.
      wr_address : out unsigned(bus_size - 1 downto 0);
      --The cell data
      wr_data_bit : out std_logic;
      --Write enable asserted when data ready.
      wr_enable : out std_logic;

      --Signals a write timeout; the entity using
      --the downloader may use it to signal an error
      wr_timeout : out std_logic
    );

  end component;
  component uart_emitter_dp is
    generic (cc_size : natural := 10);
    port (
      clk : in std_logic;
      reset : in std_logic;

      --shift register control
      sr_ld : in std_logic;
      sr_shift : in std_logic;
      sr_data_in : in unsigned(7 downto 0);

      --shift counter
      sc_start : in std_logic;
      sc_isseven : out std_logic;

      --cycle counter
      cc_start : in std_logic;
      cc_maxval : in unsigned(cc_size - 1 downto 0);
      cc_ismax : out std_logic;

      --which bit do we select?
      tx_sel : in unsigned(1 downto 0);
      tx_out : out std_logic
    );
  end component;

  component uart_emitter_sm is
    generic (
      clock_speed : natural := 33000000;
      baud_rate : natural := 115200;
      cc_size : natural := 10
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
  end component;

  component uart_recv is
    generic (
      clock_speed : natural := 33000000;
      baud_rate : natural := 115200
    );

    port (
      clk : in std_logic;
      reset : in std_logic;
      rx : in std_logic;
      ready : out std_logic;
      data : out unsigned(7 downto 0);
      parity_ok : out std_logic
    );
  end component;

  component uart_recv_dp is
    generic (cc_size : natural := 10);

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
  end component;

  component uart_recv_sm is
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

      sc_iseleven : in std_logic;

      cc_incr : out std_logic;
      cc_reset : out std_logic;
      cc_max : out unsigned(cc_size - 1 downto 0);
      cc_half : out unsigned(cc_size - 1 downto 0)
    );
  end component;

  component uart_emitter is
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
  end component;
end uart_lib;