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
-- SDRAM controller
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sdram_lib.all;
use work.ram_lib.all;
use work.vga_lib.all;
use work.functions.all;
use work.uart_lib.all;


--This module is responsible for reading a picture
--from the SDRAM and displaying it on the screen.
--During the horizontal refresh a line is copied from
--the SDRAM to the internal on-chip memory.

--There is also a module which is responsible for
--receiving picture data from the UART. When it receives
--a 32 bits word (8 pixels), it stores it in the on-chip
--memory (different from the SDRAM read buffer).
--When an entire pixel line has been downloaded, the module
--tells to the SDRAM module to write this memory block
--back to SDRAM. The SDRAM module copies this line to the SDRAM
--during horizontal retraces, after the line to be displayed
--next has been transfered from the SDRAM. It also transfers
--the ready line during vertical refreshed.
--
--Potential issues: when the SDRAM module copies new data
--to memory, the receiver module does not poll the UART controller.
--If the baud rate is to rate and the clock speed is too low
--this may result in data loss.
--The maximum delay may be calculated as follows:
--clock_speed/baud_rate * bits_per_word. For a clock operating at 33Mhz,
--115200 baud rate, 11 data bits, copy operation must not last more than 3151
--clock cycles. If the vga line width is 800 (640 pixel width),
--the delay will be of at most 640+80+sdram_delay.

entity sdram_picture is
    generic(
        clock_speed: natural := 33000000;
        row_width: natural := 12;
        col_width: natural := 9;
        bank_width: natural:= 2;
        data_width: natural := 32;
        dqm_size: natural := 4;
        cas_latency_cycles: natural := 3;
        init_refresh_cycles: natural := 2;

        pixel_width: 			natural := 640;
        vga_line_width: 	natural := 800;
        vga_hsync_width: 	natural := 96;
        vga_front_porch: 	natural := 20;
        vga_back_porch: 	natural := 44;
        pixel_height: 		natural := 480;
        vga_line_height:	natural := 525;
        vga_vsync_width: 	natural := 2;
        vga_vfront_porch: natural := 13;
        vga_vback_porch: 	natural := 30;
        vga_color_depth_bits: natural := 4;

        baud_rate: natural := 115200
    );
    port(
        clk, clk_from_vga, reset: in std_logic;
        sdram_cke, sdram_cs, sdram_ras_n, sdram_cas_n, sdram_we_n: out std_logic;
        sdram_address: out unsigned(row_width-1	downto 0);
        sdram_bank_select: out unsigned(bank_width-1 downto 0);
        sdram_dqm: out unsigned(dqm_size-1 downto 0);
        sdram_data: inout unsigned(data_width-1 downto 0);

        --vga_r, vga_g, vga_b, vga_hsync, vga_vsync: out std_logic;
        vga_color: out unsigned(vga_color_depth_bits-1 downto 0);
        vga_col: in unsigned(log2(pixel_width)-1 downto 0);
        vga_row: in unsigned(log2(pixel_height)-1 downto 0);
        vga_vretrace_i, vga_hretrace_i: in std_logic;
      uart_rx, update_enable: in std_logic
    );
end sdram_picture;

architecture a1 of sdram_picture is
    type stest_state is (cs_wait_sdram, write1, write1a, write2,
    cs_read1, cs_read2, cs_read3,
    cs_wait_vretrace, cs_wait_hretrace,	cs_wait_hretrace_a,
    cs_uart1, cs_uart2, cs_uart2a, cs_uart3, cs_check_row);

    signal current_state, next_state: stest_state;

    signal address: unsigned(22 downto 0);
    signal data_wr, data_rd: unsigned(31 downto 0);
    signal sdram_ready: boolean;
    signal data_ready, write_ready, op_begin, do_write,bank_activated: boolean;

    constant rowpo2: natural := log2(pixel_height);
    constant colpo2: natural := log2(pixel_width);

    constant  read_ram_addrwidth: natural := log2(pixel_width/8);

    signal read_ram_address: unsigned(read_ram_addrwidth-1 downto 0);
    signal read_ram_address_vga: unsigned(read_ram_addrwidth-1 downto 0);
    signal read_ram_waddress: unsigned(read_ram_addrwidth-1 downto 0);
    signal read_ram_output: unsigned(31 downto 0);
    signal read_ram_we: std_logic;
    signal read_ram_input: unsigned(31 downto 0);

    signal read_ram_selectvga: boolean;

    --UART stuff
    signal uart_ready: std_logic;
    signal uart_data: unsigned(7 downto 0);
    signal uart_parity_ok: std_logic;

    -----------------------------
    --From/To Uart memory/SDRAM
    signal recv2sdram_ram_address: unsigned(read_ram_addrwidth-1 downto 0);
    signal recv2sdram_ram_output: unsigned(31 downto 0);
    signal recv2sdram_addr_incr: boolean;
    signal recv2sdram_data_avl: boolean;
    signal recv2sdram_storing: boolean;
    signal recv2sdram_set_data_avl: boolean;
    signal recv2sdram_reset_data_avl: boolean;

    signal uart2recv_ram_address: unsigned(read_ram_addrwidth-1 downto 0);
    signal uart2recv_addr_incr: boolean;
    signal uart2recv_ram_we: std_logic;
    signal uart2recv_ram_input: unsigned(31 downto 0);


    --signal vga_row: unsigned(rowpo2-1 downto 0);
    --signal vga_col: unsigned(colpo2-1 downto 0);
    --signal vga_color: unsigned(vga_color_depth_bits-1 downto 0);
    --signal vga_vretrace, vga_hretrace: std_logic;

    signal sdram_row: unsigned(row_width-1 downto 0);
    signal sdram_col: unsigned(colpo2-4 downto 0);
    signal sdram_col_incr, sdram_row_incr: boolean;
    signal sdram_col_reset, sdram_row_reset: boolean;

    signal uart_timeout: unsigned(log2(clock_speed)-1 downto 0);
    signal uart_address: unsigned(read_ram_addrwidth-1 downto 0);
    signal uart_row, uart_sdram_row: unsigned(rowpo2-1 downto 0);
    signal uart_save_row: boolean;
    signal uart_row_incr, uart_row_reset: boolean;
    signal uart_timeout_reset, uart_address_incr, uart_address_reset: boolean;

    signal uart_bytes: unsigned(31 downto 0);
    signal uart_byte2write: unsigned(1 downto 0);
    signal uart_byte2write_en: boolean;
    signal uart_store2sdram, uart_store2sdram_finished: boolean;

    signal uart_from_sdram_wordwritten: boolean;
    signal uart_from_sdram_addrincr:boolean;
    type uart_state is (us_init, us_recv,  us_store, us_store2ram,
    us_store2sdram, us_store2sdram_addrincr, us_uart_next_row, us_uart_row_reset,
    us_uartaddr_reset);
    signal uart_cs, uart_ns : uart_state;

    --buffering input signals
    signal vga_vretrace, vga_hretrace: std_logic;
begin

    process(clk, vga_vretrace, vga_hretrace, reset)
    begin
        if (reset='1') then
            vga_hretrace <= '0';
            vga_vretrace <= '0';
        elsif(rising_edge(clk)) then
            vga_vretrace <= vga_vretrace_i;
            vga_hretrace <= vga_hretrace_i;
        end if;
    end process;


    sd1: sdram generic map(
        clock_speed => clock_speed,
        row_width  => row_width,
        col_width  => col_width,
        bank_width  => bank_width,
        data_width  => data_width,
        dqm_size  => dqm_size,
        cas_latency_cycles => cas_latency_cycles,
        init_refresh_cycles => init_refresh_cycles
    )
    port map(
        clk=>clk, reset=>reset,
        cke=>sdram_cke, cs=>sdram_cs, ras_n=>sdram_ras_n,
        cas_n=>sdram_cas_n, we_n=>sdram_we_n,
        sdram_address => sdram_address,
        bank_select=>sdram_bank_select,
        dqm => sdram_dqm,
        data =>sdram_data,
        --user ports
        address =>  address,
        data_read =>read_ram_input,
        op_begin => op_begin,
        read_valid => data_ready,
        write_valid => write_ready,
        bank_activated => bank_activated,
        data_write => data_wr,
        do_write => do_write,

        controller_ready => sdram_ready
    );



    --mapping for RAM controller -------------------------------------
    ram_read: ram2port2clock generic map(
        word_width => 32,
        address_width => read_ram_addrwidth
    )
    port map(
        address_a		=> std_logic_vector(read_ram_address_vga),
        address_b		=> std_logic_vector(read_ram_address),
        clock_a		=> clk_from_vga,
        clock_b		=> clk,
        data_a		=> (others=>'0'),
        data_b		=> std_logic_vector(read_ram_input),
        wren_a		=> '0',
        wren_b		=> read_ram_we,
        unsigned(q_a)		 => read_ram_output,
        q_b		 => open
    );

    --Extracts the right nibble for the color.
    --Note the order of the nibbles and the fact
    --that the color will be displayed on the
    --next clock cycle.
    vga_color <= read_ram_output(3 downto 0) when vga_col(2 downto 0) = 2
        else read_ram_output(7 downto 4) when vga_col(2 downto 0) = 1
        else read_ram_output(11 downto 8) when vga_col(2 downto 0) = 4
        else read_ram_output(15 downto 12) when vga_col(2 downto 0) = 3
        else read_ram_output(19 downto 16) when vga_col(2 downto 0) = 6
        else read_ram_output(23 downto 20) when vga_col(2 downto 0) = 5
        else read_ram_output(27 downto 24) when vga_col(2 downto 0) = 0
        else read_ram_output(31 downto 28) when vga_col(2 downto 0) = 7
        else (others=>'0');

    process(sdram_col, vga_col, sdram_row, recv2sdram_storing, uart_sdram_row)
    begin
        read_ram_address <= (others=>'0');
        read_ram_address_vga <= (others => '0');

        read_ram_address_vga(colpo2-4 downto 0) <= vga_col(colpo2-1 downto 3);
        read_ram_address(colpo2-4 downto 0) <= sdram_col;

        address <= (others=>'0');

        --generate the sdram read/write address
        if (recv2sdram_storing=false) then
            address(colpo2-4 downto 0) <= sdram_col;
            address(row_width+col_width-1 downto col_width) <= sdram_row;
        else
            address(uart_address'length-1 downto 0) <= sdram_col;
            address(col_width+uart_row'length-1 downto col_width) <= uart_sdram_row;
        end if;
    end process;



    --increment row and column.
    --It is used to fetch the right pixel from the sdram
    process(clk, reset, address)
    begin
        if (reset='1') then
            sdram_col <= (others=>'0');
            sdram_row <= (others=>'0');
            recv2sdram_ram_address <= (others=>'0');
        elsif(rising_edge(clk)) then
            if(sdram_col_reset) then
                    sdram_col <= (others=>'0');
            elsif (sdram_col_incr) then
                    sdram_col <= sdram_col + 1;
            end if;

            if(sdram_row_reset) then
                    sdram_row <= (others=>'0');
            elsif (sdram_row_incr) then
                    if (sdram_row = pixel_height-1)
                        then sdram_row <= (others=>'0');
                        else sdram_row <= sdram_row + 1;
                    end if;
            end if;

            --Uart buffer address (uart=>SDRAM)
            if (recv2sdram_addr_incr) then
                if (recv2sdram_ram_address = pixel_width/8-1)
                    then recv2sdram_ram_address <= (others=>'0');
                    else recv2sdram_ram_address <= recv2sdram_ram_address+1;
                end if;
            end if;
        end if;
    end process;

    --Generates the data to be sent to the sdram.
    --During the initialization, we write
    --a constant value to it, otherwise the
    --data from the UART buffer.
    process(recv2sdram_storing, address, recv2sdram_ram_output)
    begin
        data_wr <= (others=>'0');
        if (recv2sdram_storing) then
            data_wr <= recv2sdram_ram_output;
        else
            if (address(0)='0')
                then data_wr <= x"44444444";
                else data_wr <= x"00000000";
            end if;
        end if;
    end process;


    process(current_state, sdram_ready, sdram_col, sdram_row,
    data_ready, vga_vretrace, vga_hretrace, write_ready,
    bank_activated, recv2sdram_data_avl, recv2sdram_ram_address)
    begin
        next_state <= current_state;
        read_ram_selectvga <= true;
        op_begin <= false;
        do_write <= false;

        sdram_row_incr <= false;
        sdram_col_incr <= false;
        sdram_row_reset <= false;
        sdram_col_reset <= false;

        read_ram_we <= '0';

        recv2sdram_addr_incr <= false;
        recv2sdram_reset_data_avl <= false;
        recv2sdram_storing <= false;

        case current_state is

            --Wait for the SDRAM to complete its initialization
            when cs_wait_sdram=>
                if (sdram_ready) then
                    next_state <= write1a;
                end if;

            ------------------------------------
            --reset the content of the sdram
            when write1a =>
                op_begin <= true;
                do_write <= true;
                if (write_ready) then
                    next_state <= write2;
                    sdram_col_incr <= true;
                end if;

            when write2 =>
                op_begin <= true;
                do_write <= true;
                sdram_col_incr <= true;

                if (sdram_col=pixel_width/8-1) then
                    next_state <= write1;
                    do_write <= false;
                    op_begin <= false;
                    sdram_col_reset <= true;
                end if;

            when write1 =>
                sdram_col_reset <= true;
                sdram_row_incr <= true;
                next_state <= write1a;
                if (sdram_row=pixel_height-1) then
                    next_state <= cs_wait_vretrace;
                end if;



            ------------------------------------
            --Wait for the vertical retrace before
            --we load the first line
            when cs_wait_vretrace =>
                sdram_col_reset <= true;
                sdram_row_reset <= true;

                if (vga_vretrace='1') then
                    next_state <= cs_read1;
                end if;

            --Wait retrace began. Load the line.
            --Issue read command to SDRAM
            when cs_read1 =>
                op_begin <= true;
                read_ram_selectvga <= false;
                if (data_ready) then
                    next_state <= cs_read2;
                    --op_begin <= true;
                    sdram_col_incr <= true;
                    read_ram_we <= '1';
                end if;

            --Burst read the rest of the line
            --Warning: The loops assumes that the
            --sdram controller does not interrupt bursts
            --with auto refreshes!
            --Otherwise it would need to check for data_ready.
            when cs_read2 =>
                read_ram_selectvga <= false;
                sdram_col_incr <= true;
                read_ram_we <= '1';
                op_begin <= true;

                if (sdram_col=pixel_width/8-1) then
                    next_state <= cs_read3;
                end if;

            --Now copy downloaded data if necessary.
            --Else go to check row
            when cs_read3=>
                sdram_row_incr <= true;
                sdram_col_reset <= true;
                next_state <= cs_check_row;
                if (recv2sdram_data_avl) then
                     next_state <= cs_uart1;
                end if;

            ------------------------------------
            --Store the content of the UART buffer
            --in the SDRAM
            when cs_uart1 =>
                op_begin <= true;
                do_write <= true;
                recv2sdram_storing <= true;

                if (write_ready or bank_activated) then
                    recv2sdram_addr_incr <= true;
                end if;

                if (write_ready) then
                    next_state <= cs_uart2;
                end if;

            --!!!Warning!!! The loop assumes that the
            --sdram controller does not interrupt bursts
            --with auto refreshes!
            --Otherwise it would need to check for it.
            when cs_uart2 =>
                op_begin <= true;
                do_write <= true;
                recv2sdram_addr_incr <= true;
                recv2sdram_storing <= true;

                if (recv2sdram_ram_address = pixel_width/8-1) then
                    next_state <= cs_uart2a;
                end if;

            when cs_uart2a =>
                recv2sdram_storing <= true;
                op_begin <= true;
                do_write <= true;
                next_state <= cs_uart3;

            when cs_uart3 =>
                next_state <= cs_check_row;
                recv2sdram_reset_data_avl <= true;

            -------------------------
            --if we reached the first row again,
            --go to wait vretrace before loading it
            when cs_check_row =>
                if (sdram_row = 0)
                    then next_state <= cs_wait_vretrace;
                    else next_state <= cs_wait_hretrace_a;
                end if;

            --wait hretrace to draw the line.
            --if it is already the last, line,
            --wait for the vretrace to load the
            --first line.
            when cs_wait_hretrace_a =>
                if (vga_hretrace='0') then
                    next_state <= cs_wait_hretrace;
                end if;

            when cs_wait_hretrace =>
                if (vga_vretrace='1' and recv2sdram_data_avl) then
                    next_state <= cs_uart1;
                elsif (vga_hretrace='1') then
                    next_state <= cs_read1;
                end if;

            when others=> null;
        end case;
    end process;

    process(clk, reset)
    begin
        if (reset='1') then
            current_state <= cs_wait_sdram;
        elsif(rising_edge(clk)) then
            current_state <= next_state;
        end if;
    end process;


    --mapping for RAM controller, download a line from the serial port
    ram_write: ram2port generic map(
        data_width => 32,
        address_width => read_ram_addrwidth,
        init_file => ""
    )
    port map(
        clk=>clk,
        address1 => recv2sdram_ram_address,
        read1_data => recv2sdram_ram_output,
        write1_en => '0',
        write1_data => (others=>'0'),

        address2 => uart2recv_ram_address,
        read2_data => open,
        write2_en => uart2recv_ram_we,
        write2_data => uart2recv_ram_input
    );


    --mapping the uart receiver
    uart1: uart_recv generic map(
        clock_speed => clock_speed,
    baud_rate => baud_rate
    )
    port map(
        clk => clk,
    reset => reset,
    rx => uart_rx,
    ready => uart_ready,
    data => uart_data,
    parity_ok => uart_parity_ok
    );

    --UART process
    --Timeout counter, resets the write address
    --if nothing was received for a significant amount
    --of time. It is controlled by the length of the
    --timeout vector.
    --The process also increments the read/write address
    process(clk, reset,uart_timeout_reset,
    uart_address, uart_row_incr, uart_row_reset,
    uart_from_sdram_addrincr, bank_activated, write_ready)
    begin
        if (reset='1') then
            uart_timeout <= (others=>'1');
            uart2recv_ram_address <= (others =>'0');
            uart_row <= (others =>'0');
            uart_sdram_row <= (others =>'0');
        elsif(clk'event and clk='1') then
            --Handles timeout
            if (uart_timeout_reset)
                then uart_timeout <= (others=>'1');
                else uart_timeout <= uart_timeout - 1;
            end if;

            --Saves the row so that sdram can use it
            --independently from the uart receiver.
            if (uart_save_row) then
                uart_sdram_row <= uart_row;
            end if;

            --If there is a timeout, zero out everything
            if (uart_timeout = 0) then
                    uart2recv_ram_address <= (others =>'0');
                    uart_row <= (others =>'0');
            else
                --Uart buffer address (uart=>receiver)
                if (uart2recv_addr_incr) then
                    if (uart2recv_ram_address = pixel_width/8-1)
                        then uart2recv_ram_address <= (others=>'0');
                        else uart2recv_ram_address <= uart2recv_ram_address+1;
                    end if;
                end if;

                --The row being currently downloaded
                if (uart_row_incr) then
                    if (uart_row = pixel_height-1)
                        then uart_row <= (others=>'0');
                        else uart_row <= uart_row+1;
                    end if;
                end if;
            end if;

        end if;
    end process;


    uart2recv_ram_input <= uart_bytes;

    --writes the received byte to the right place
    --in the buffer.
    process(clk, reset, uart_data, uart_byte2write,
        uart_byte2write_en,	uart_parity_ok)
    begin
        if (reset='1') then
            uart_bytes <= (others=>'0');
            uart_byte2write <= (others=>'0');
        elsif(rising_edge(clk)) then
            --Shift the received byte
            if (uart_byte2write_en) then
                uart_bytes <= uart_data & uart_bytes(31 downto 8);
                uart_byte2write <= uart_byte2write + 1;
            end if;

            if (uart_byte2write = 3 and uart_byte2write_en) then
                uart_byte2write <= (others=>'0');
            end if;

        end if;
    end process;

    --coordination between sdram process and uart process
    process(clk, reset, recv2sdram_set_data_avl, recv2sdram_reset_data_avl)
    begin
        if (reset='1') then
            recv2sdram_data_avl <= false;
        elsif(rising_edge(clk)) then
            if (recv2sdram_set_data_avl) then
                recv2sdram_data_avl <= true;
            end if;

            if (recv2sdram_reset_data_avl) then
                recv2sdram_data_avl <= false;
            end if;
        end if;
    end process;

    ------------------------------------
    --UART state machine, control download process
    process(uart_cs, uart_ready, uart_byte2write,
    uart_row, uart_timeout, uart2recv_ram_address,
    update_enable)
    begin
        uart_ns <= uart_cs;

        uart_timeout_reset <= true;


        uart_byte2write_en <= false;
        uart_row_incr <= false;
        uart_save_row <= false;

        recv2sdram_set_data_avl <= false;
        uart2recv_addr_incr <= false;
        uart2recv_ram_we <= '0';

        case uart_cs is
            --Wait for the UART to be ready
            when us_init=>
                uart_timeout_reset<=false;
                if (uart_timeout = 0) then
                    uart_ns <= us_recv;
                end if;

            when us_recv =>
                uart_timeout_reset <= false;

                if (uart_ready='1' and update_enable='1') then
                    uart_ns <= us_store;
                end if;

            --Store the received byte
            when us_store =>
                uart_timeout_reset <= false;
                uart_byte2write_en <= true;

                if (uart_byte2write = 3)
                    then uart_ns <= us_store2ram;
                    else uart_ns <= us_recv;
                end if;

            --As soon as 32bits are received, put
            --them into UART ram.
            when us_store2ram =>
                uart2recv_ram_we <= '1';
                uart2recv_addr_incr <= true;

                if (uart2recv_ram_address = pixel_width/8-1)
                    then uart_ns <= us_uart_next_row;
                    else uart_ns <= us_recv;
                end if;

            when us_uart_next_row =>
                recv2sdram_set_data_avl <= true;
                uart_row_incr <= true;
                uart_save_row <= true;
                uart_ns <= us_recv;

            when others=>null;
        end case;

    end process;

    process(clk, reset, uart_ns)
    begin
        if (reset='1') then
            uart_cs <= us_init;
        elsif(rising_edge(clk)) then
            uart_cs <= uart_ns;
        end if;
    end process;
end a1;
