-- megafunction wizard: %RAM: 1-PORT%
-- GENERATION: STANDARD
-- VERSION: WM1.0
-- MODULE: altsyncram 

-- ============================================================
-- File Name: gol2_ram.vhd
-- Megafunction Name(s):
-- 			altsyncram
--
-- Simulation Library Files(s):
-- 			altera_mf
-- ============================================================
-- ************************************************************
-- THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
--
-- 6.1 Build 201 11/27/2006 SJ Web Edition
-- ************************************************************
--Copyright (C) 1991-2006 Altera Corporation
--Your use of Altera Corporation's design tools, logic functions 
--and other software and tools, and its AMPP partner logic 
--functions, and any output files from any of the foregoing 
--(including device programming or simulation files), and any 
--associated documentation or information are expressly subject 
--to the terms and conditions of the Altera Program License 
--Subscription Agreement, Altera MegaCore Function License 
--Agreement, or other applicable license agreement, including, 
--without limitation, that your use is for the sole purpose of 
--programming logic devices manufactured by Altera and sold by 
--Altera or its authorized distributors.  Please refer to the 
--applicable agreement for further details.
library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.all;

entity gol2_ram is
    port (
        address : in STD_LOGIC_VECTOR (10 downto 0);
        clock : in STD_LOGIC;
        data : in STD_LOGIC_VECTOR (0 downto 0);
        wren : in STD_LOGIC;
        q : out STD_LOGIC_VECTOR (0 downto 0)
    );
end gol2_ram;
architecture SYN of gol2_ram is

    signal sub_wire0 : STD_LOGIC_VECTOR (0 downto 0);

    component altsyncram
        generic (
            clock_enable_input_a : string;
            clock_enable_output_a : string;
            init_file : string;
            intended_device_family : string;
            lpm_hint : string;
            lpm_type : string;
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
            address_a : in STD_LOGIC_VECTOR (10 downto 0);
            q_a : out STD_LOGIC_VECTOR (0 downto 0);
            data_a : in STD_LOGIC_VECTOR (0 downto 0)
        );
    end component;

begin
    q <= sub_wire0(0 downto 0);

    altsyncram_component : altsyncram
    generic map(
        clock_enable_input_a => "BYPASS",
        clock_enable_output_a => "BYPASS",
        init_file => "d:/Vitaly/programmation/fpga/uart/converter/gol1.mif",
        intended_device_family => "Cyclone II",
        lpm_hint => "ENABLE_RUNTIME_MOD=NO",
        lpm_type => "altsyncram",
        numwords_a => 2048,
        operation_mode => "SINGLE_PORT",
        outdata_aclr_a => "NONE",
        outdata_reg_a => "UNREGISTERED",
        power_up_uninitialized => "FALSE",
        widthad_a => 11,
        width_a => 1,
        width_byteena_a => 1
    )
    port map(
        wren_a => wren,
        clock0 => clock,
        address_a => address,
        data_a => data,
        q_a => sub_wire0
    );

end SYN;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: PRIVATE: ADDRESSSTALL_A NUMERIC "0"
-- Retrieval info: PRIVATE: AclrAddr NUMERIC "0"
-- Retrieval info: PRIVATE: AclrByte NUMERIC "0"
-- Retrieval info: PRIVATE: AclrData NUMERIC "0"
-- Retrieval info: PRIVATE: AclrOutput NUMERIC "0"
-- Retrieval info: PRIVATE: BYTE_ENABLE NUMERIC "0"
-- Retrieval info: PRIVATE: BYTE_SIZE NUMERIC "8"
-- Retrieval info: PRIVATE: BlankMemory NUMERIC "0"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_INPUT_A NUMERIC "0"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_OUTPUT_A NUMERIC "0"
-- Retrieval info: PRIVATE: Clken NUMERIC "0"
-- Retrieval info: PRIVATE: DataBusSeparated NUMERIC "1"
-- Retrieval info: PRIVATE: IMPLEMENT_IN_LES NUMERIC "0"
-- Retrieval info: PRIVATE: INIT_FILE_LAYOUT STRING "PORT_A"
-- Retrieval info: PRIVATE: INIT_TO_SIM_X NUMERIC "0"
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone II"
-- Retrieval info: PRIVATE: JTAG_ENABLED NUMERIC "0"
-- Retrieval info: PRIVATE: JTAG_ID STRING "NONE"
-- Retrieval info: PRIVATE: MAXIMUM_DEPTH NUMERIC "0"
-- Retrieval info: PRIVATE: MIFfilename STRING "d:/Vitaly/programmation/fpga/uart/converter/gol1.mif"
-- Retrieval info: PRIVATE: NUMWORDS_A NUMERIC "2048"
-- Retrieval info: PRIVATE: RAM_BLOCK_TYPE NUMERIC "0"
-- Retrieval info: PRIVATE: READ_DURING_WRITE_MODE_PORT_A NUMERIC "3"
-- Retrieval info: PRIVATE: RegAddr NUMERIC "1"
-- Retrieval info: PRIVATE: RegData NUMERIC "1"
-- Retrieval info: PRIVATE: RegOutput NUMERIC "0"
-- Retrieval info: PRIVATE: SingleClock NUMERIC "1"
-- Retrieval info: PRIVATE: UseDQRAM NUMERIC "1"
-- Retrieval info: PRIVATE: WRCONTROL_ACLR_A NUMERIC "0"
-- Retrieval info: PRIVATE: WidthAddr NUMERIC "11"
-- Retrieval info: PRIVATE: WidthData NUMERIC "1"
-- Retrieval info: PRIVATE: rden NUMERIC "0"
-- Retrieval info: CONSTANT: CLOCK_ENABLE_INPUT_A STRING "BYPASS"
-- Retrieval info: CONSTANT: CLOCK_ENABLE_OUTPUT_A STRING "BYPASS"
-- Retrieval info: CONSTANT: INIT_FILE STRING "d:/Vitaly/programmation/fpga/uart/converter/gol1.mif"
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone II"
-- Retrieval info: CONSTANT: LPM_HINT STRING "ENABLE_RUNTIME_MOD=NO"
-- Retrieval info: CONSTANT: LPM_TYPE STRING "altsyncram"
-- Retrieval info: CONSTANT: NUMWORDS_A NUMERIC "2048"
-- Retrieval info: CONSTANT: OPERATION_MODE STRING "SINGLE_PORT"
-- Retrieval info: CONSTANT: OUTDATA_ACLR_A STRING "NONE"
-- Retrieval info: CONSTANT: OUTDATA_REG_A STRING "UNREGISTERED"
-- Retrieval info: CONSTANT: POWER_UP_UNINITIALIZED STRING "FALSE"
-- Retrieval info: CONSTANT: WIDTHAD_A NUMERIC "11"
-- Retrieval info: CONSTANT: WIDTH_A NUMERIC "1"
-- Retrieval info: CONSTANT: WIDTH_BYTEENA_A NUMERIC "1"
-- Retrieval info: USED_PORT: address 0 0 11 0 INPUT NODEFVAL address[10..0]
-- Retrieval info: USED_PORT: clock 0 0 0 0 INPUT NODEFVAL clock
-- Retrieval info: USED_PORT: data 0 0 1 0 INPUT NODEFVAL data[0..0]
-- Retrieval info: USED_PORT: q 0 0 1 0 OUTPUT NODEFVAL q[0..0]
-- Retrieval info: USED_PORT: wren 0 0 0 0 INPUT NODEFVAL wren
-- Retrieval info: CONNECT: @address_a 0 0 11 0 address 0 0 11 0
-- Retrieval info: CONNECT: q 0 0 1 0 @q_a 0 0 1 0
-- Retrieval info: CONNECT: @clock0 0 0 0 0 clock 0 0 0 0
-- Retrieval info: CONNECT: @data_a 0 0 1 0 data 0 0 1 0
-- Retrieval info: CONNECT: @wren_a 0 0 0 0 wren 0 0 0 0
-- Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
-- Retrieval info: GEN_FILE: TYPE_NORMAL gol2_ram.vhd TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL gol2_ram.inc FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL gol2_ram.cmp TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL gol2_ram.bsf TRUE FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL gol2_ram_inst.vhd TRUE
-- Retrieval info: LIB_FILE: altera_mf