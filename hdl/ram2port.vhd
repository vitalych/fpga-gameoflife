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
--Dual port RAM
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.all;

entity ram2port is
    generic (
        data_width : natural;
        address_width : natural;
        init_file : string
    );
    port (
        clk : in std_logic;
        address1 : in unsigned(address_width - 1 downto 0);
        read1_data : out unsigned(data_width - 1 downto 0);
        write1_en : in std_logic;
        write1_data : in unsigned(data_width - 1 downto 0);

        address2 : in unsigned(address_width - 1 downto 0);
        read2_data : out unsigned(data_width - 1 downto 0);
        write2_en : in std_logic;
        write2_data : in unsigned(data_width - 1 downto 0)
    );
end ram2port;
architecture SYN of ram2port is

    component altsyncram
        generic (
            address_reg_b : string;
            clock_enable_input_a : string;
            clock_enable_input_b : string;
            clock_enable_output_a : string;
            clock_enable_output_b : string;
            indata_reg_b : string;
            init_file : string;
            intended_device_family : string;
            lpm_type : string;
            numwords_a : natural;
            numwords_b : natural;
            operation_mode : string;
            outdata_aclr_a : string;
            outdata_aclr_b : string;
            outdata_reg_a : string;
            outdata_reg_b : string;
            power_up_uninitialized : string;
            read_during_write_mode_mixed_ports : string;
            widthad_a : natural;
            widthad_b : natural;
            width_a : natural;
            width_b : natural;
            width_byteena_a : natural;
            width_byteena_b : natural;
            wrcontrol_wraddress_reg_b : string
        );
        port (
            wren_a : in STD_LOGIC;
            clock0 : in STD_LOGIC;
            wren_b : in STD_LOGIC;
            address_a : in STD_LOGIC_VECTOR (address_width - 1 downto 0);
            address_b : in STD_LOGIC_VECTOR (address_width - 1 downto 0);
            q_a : out STD_LOGIC_VECTOR (data_width - 1 downto 0);
            q_b : out STD_LOGIC_VECTOR (data_width - 1 downto 0);
            data_a : in STD_LOGIC_VECTOR (data_width - 1 downto 0);
            data_b : in STD_LOGIC_VECTOR (data_width - 1 downto 0)
        );
    end component;

begin
    altsyncram_component : altsyncram
    generic map(
        address_reg_b => "CLOCK0",
        clock_enable_input_a => "BYPASS",
        clock_enable_input_b => "BYPASS",
        clock_enable_output_a => "BYPASS",
        clock_enable_output_b => "BYPASS",
        indata_reg_b => "CLOCK0",
        init_file => init_file,
        intended_device_family => "Cyclone II",
        lpm_type => "altsyncram",
        numwords_a => 2 ** address_width,
        numwords_b => 2 ** address_width,
        operation_mode => "BIDIR_DUAL_PORT",
        outdata_aclr_a => "NONE",
        outdata_aclr_b => "NONE",
        outdata_reg_a => "UNREGISTERED",
        outdata_reg_b => "UNREGISTERED",
        power_up_uninitialized => "FALSE",
        read_during_write_mode_mixed_ports => "DONT_CARE",
        widthad_a => address_width,
        widthad_b => address_width,
        width_a => data_width,
        width_b => data_width,
        width_byteena_a => 1,
        width_byteena_b => 1,
        wrcontrol_wraddress_reg_b => "CLOCK0"
    )
    port map(
        wren_a => write1_en,
        clock0 => clk,
        wren_b => write2_en,
        address_a => std_logic_vector(address1),
        address_b => std_logic_vector(address2),
        data_a => std_logic_vector(write1_data),
        data_b => std_logic_vector(write2_data),
        unsigned(q_a) => read1_data,
        unsigned(q_b) => read2_data
    );

end SYN;