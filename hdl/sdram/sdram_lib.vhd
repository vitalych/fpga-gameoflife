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

package sdram_lib is
    component sdram is
        generic (
            clock_speed : natural := 33000000;
            row_width : natural := 12;
            col_width : natural := 9;
            bank_width : natural := 2;
            data_width : natural := 32;
            dqm_size : natural := 4;
            cas_latency_cycles : natural := 2;
            init_refresh_cycles : natural := 2
        );

        port (
            clk, reset : std_logic;
            cke, cs, ras_n, cas_n, we_n : out std_logic;
            sdram_address : out unsigned(row_width - 1 downto 0);
            bank_select : out unsigned(bank_width - 1 downto 0);
            dqm : out unsigned(dqm_size - 1 downto 0);
            data : inout unsigned(data_width - 1 downto 0);
            --user ports
            address : in unsigned(row_width + col_width + bank_width - 1 downto 0);
            data_read : out unsigned(data_width - 1 downto 0);
            op_begin : in boolean;
            read_valid, write_valid, bank_activated : out boolean;
            data_write : in unsigned(data_width - 1 downto 0);
            do_write : in boolean;

            controller_ready : out boolean

        );
    end component;
    component sdram_dp is
        generic (
            clock_speed : natural := 33000000;
            row_width : natural := 12;
            col_width : natural := 9;
            bank_width : natural := 2;
            data_width : natural := 32;

            cas_latency_cycles : natural := 2;
            init_refresh_cycles : natural := 2;
            refresh_interval : time;--- := 15.625 us;
            powerup_delay : time;-- := 200 us;
            t_rfc : time;--;:= 70 ns; --Duration of refresh command
            t_rp : time; --:= 20 ns; -- Duration of precharge command
            t_rcd : time; --:= 20 ns; -- ACTIVE to READ or WRITE delay
            t_ac : time; --:= 5.5 ns; -- Access time
            t_wr : time; --:= 14 ns; -- Write recovery time (no auto precharge)

            counter_max_count : natural := 2 ** 30
        );
        port (
            clk, reset : in std_logic;
            counter_start : in boolean;
            counter_pause : in boolean;
            counter_done : out boolean;
            counter_max : in natural range 0 to counter_max_count - 1;
            counter_refresh_reset : in boolean;
            counter_refresh_needed : out boolean

        );
    end component;

    component sdram_picture is
        generic (
            clock_speed : natural := 33000000;
            row_width : natural := 12;
            col_width : natural := 9;
            bank_width : natural := 2;
            data_width : natural := 32;
            dqm_size : natural := 4;
            cas_latency_cycles : natural := 3;
            init_refresh_cycles : natural := 2;

            pixel_width : natural := 640;
            vga_line_width : natural := 800;
            vga_hsync_width : natural := 96;
            vga_front_porch : natural := 20;
            vga_back_porch : natural := 44;
            pixel_height : natural := 480;
            vga_line_height : natural := 525;
            vga_vsync_width : natural := 2;
            vga_vfront_porch : natural := 13;
            vga_vback_porch : natural := 30;
            vga_color_depth_bits : natural := 4;

            baud_rate : natural := 115200
        );
        port (
            clk, clk_from_vga, reset : in std_logic;
            sdram_cke, sdram_cs, sdram_ras_n, sdram_cas_n, sdram_we_n : out std_logic;
            sdram_address : out unsigned(row_width - 1 downto 0);
            sdram_bank_select : out unsigned(bank_width - 1 downto 0);
            sdram_dqm : out unsigned(dqm_size - 1 downto 0);
            sdram_data : inout unsigned(data_width - 1 downto 0);

            --vga_r, vga_g, vga_b, vga_hsync, vga_vsync: out std_logic;
            vga_color : out unsigned(vga_color_depth_bits - 1 downto 0);
            vga_col : in unsigned(log2(pixel_width) - 1 downto 0);
            vga_row : in unsigned(log2(pixel_height) - 1 downto 0);
            vga_vretrace_i, vga_hretrace_i : in std_logic;
            uart_rx, update_enable : in std_logic

        );
    end component;

end sdram_lib;