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
--UART file downloader
--This entity is used by the game of life main
--module to update the grid memory.
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uart_lib.all;

entity file_downloader is
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
end file_downloader;

architecture a1 of file_downloader is
    type state is (recv, store);
    signal current_state, next_state : state;

    signal rx_ready : std_logic;
    signal rx_data : unsigned(7 downto 0);
    --signal rx_parity_ok: std_logic;

    signal cur_address : unsigned(bus_size - 1 downto 0);
    signal incr_address : boolean;
    signal timeout : unsigned(20 downto 0);
    signal reset_timeout : boolean;
    signal reset_address : boolean;
    signal wr_data_select : boolean;
begin
    --We use the UART for the download
    fdr : work.uart_lib.uart_recv
    generic map(clock_speed => clock_speed, baud_rate => baud_rate)
    port map(
        clk => clk, reset => reset, rx => rx,
        ready => rx_ready, data => rx_data, parity_ok => open);

    --The current address of the write.
    wr_address <= cur_address;
    process (clk, reset, reset_timeout, reset_address)
    begin
        if (reset = '1') then
            cur_address <= (others => '0');
        elsif (clk'event and clk = '1') then
            if (reset_address) then
                cur_address <= (others => '0');
            elsif (incr_address) then
                cur_address <= cur_address + 1;
            end if;
        end if;
    end process;

    --Timeout counter, resets the write address
    --if nothing was received for a significant amount
    --of time. It is controlled by the length of the
    --timeout vector.
    process (clk, reset, reset_timeout)
    begin
        if (reset = '1') then
            timeout <= (others => '1');
        elsif (clk'event and clk = '1') then
            if (reset_timeout)
                then
                timeout <= (others => '1');
            else
                timeout <= timeout - 1;
            end if;
        end if;
    end process;
    reset_address <= true when timeout = 0 else
        false;
    wr_timeout <= '1' when reset_address else
        '0';
    wr_data_bit <= rx_data(TO_INTEGER(cur_address(2 downto 0)));

    --The state machine to control the transmission.
    process (current_state, timeout, rx_ready, rx_data, cur_address)
    begin
        wr_enable <= '0';
        incr_address <= false;
        reset_timeout <= true;

        next_state <= current_state;

        case current_state is
                --Step one: receive 8 bits.
            when recv =>
                wr_enable <= '0';
                incr_address <= false;
                reset_timeout <= false;

                if (rx_ready = '1') then
                    next_state <= store;
                end if;

            when store =>
                incr_address <= true;
                wr_enable <= '1';
                if (cur_address(2 downto 0) = 7) then
                    next_state <= recv;
                end if;

        end case;
    end process;

    process (clk, reset)
    begin
        if (reset = '1') then
            current_state <= recv;
        elsif (clk'event and clk = '1') then
            current_state <= next_state;
        end if;
    end process;
end a1;