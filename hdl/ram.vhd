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
--Single port RAM
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.all;

entity ram is
    generic (
        word_width : natural := 4;
        address_width : natural := 13;
        init_file : string);

    port (
        clk : in std_logic;
        address1 : in unsigned(address_width - 1 downto 0);
        read1_data : out unsigned(word_width - 1 downto 0);
        write1_en : in std_logic;
        write1_data : in unsigned(word_width - 1 downto 0)
    );
end ram;

architecture ram0 of ram is
    component altsyncram
        generic (
            clock_enable_input_a : string;
            clock_enable_output_a : string;
            intended_device_family : string;
            lpm_hint : string;
            lpm_type : string;
            init_file : string;
            numwords_a : natural;
            operation_mode : string;
            outdata_aclr_a : string;
            outdata_reg_a : string;
            power_up_uninitialized : string;
            widthad_a : natural;
            width_a : natural;
            width_byteena_a : natural
        );
        port (
            wren_a : in STD_LOGIC;
            clock0 : in STD_LOGIC;
            address_a : in std_logic_vector (address_width - 1 downto 0);
            q_a : out std_logic_vector (word_width - 1 downto 0);
            data_a : in std_logic_vector (word_width - 1 downto 0)
        );
    end component;

    signal address_a : std_logic_vector (address_width - 1 downto 0);
    signal q_a : std_logic_vector (word_width - 1 downto 0);
    signal data_a : std_logic_vector (word_width - 1 downto 0);

begin
    address_a <= std_logic_vector(address1);
    read1_data <= unsigned(q_a);
    data_a <= std_logic_vector(write1_data);

    altsyncram_component : altsyncram
    generic map(
        clock_enable_input_a => "BYPASS",
        clock_enable_output_a => "BYPASS",
        init_file => init_file,
        intended_device_family => "Cyclone II",
        lpm_hint => "ENABLE_RUNTIME_MOD = NO",

        lpm_type => "altsyncram",
        numwords_a => 2 ** address_width,
        operation_mode => "SINGLE_PORT",
        outdata_aclr_a => "NONE",
        outdata_reg_a => "UNREGISTERED",
        power_up_uninitialized => "FALSE",
        widthad_a => address_width,
        width_a => word_width,
        width_byteena_a => 1

    )
    port map(
        wren_a => write1_en,
        clock0 => clk,
        address_a => address_a,
        data_a => data_a,
        q_a => q_a
    );

end ram0;