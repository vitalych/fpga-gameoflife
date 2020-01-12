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

package gol2_lib is
    component gol2_m3counter is
        generic (
            width : natural := 80;
            bank_width : natural
        );
        port (
            clk, reset : in std_logic;
            step_col, step_row, reload : in std_logic;
            col_offset : out unsigned(bank_width - 1 downto 0);
            row_offset : out unsigned(bank_width - 1 downto 0);
            m3cnt : out unsigned(1 downto 0)
        );

    end component;
    component gol2_computeline is
        generic (
            bank_width : natural;
            width, height : natural
        );
        port (
            clk, reset : std_logic;
            row_offset, col_offset : in unsigned(bank_width - 1 downto 0);
            bank : in unsigned(1 downto 0);

            compute_done : out std_logic;
            preload_start : in std_logic;
            compute_start : in std_logic;

            -- the addresses of the three cells
            read1_address : out unsigned(bank_width - 1 downto 0);
            read1_data : in std_logic;

            read2_address : out unsigned(bank_width - 1 downto 0);
            read2_data : in std_logic;

            read3_address : out unsigned(bank_width - 1 downto 0);
            read3_data : in std_logic;

            cell_grid_address : out unsigned(bank_width - 1 downto 0);
            cell_grid_wdata : out std_logic;
            cell_grid_we : out std_logic;
            cell_grid_bank : out unsigned(1 downto 0)

        );
    end component;
    component gol2_computegrid is
        generic (
            bank_width : natural;
            gol_cells_per_row : natural := 80;
            gol_cells_per_col : natural := 60
        );
        port (
            clk, reset : in std_logic;

            h_retrace, v_retrace : in std_logic;

            -- the coordinates and the value of the new cell
            cell_grid_address : out unsigned(bank_width - 1 downto 0);
            cell_grid_wdata : out std_logic;
            cell_grid_we : out std_logic;
            cell_grid_bank : out unsigned(1 downto 0);

            -- the addresses of the three cells
            read1_address : out unsigned(bank_width - 1 downto 0);
            read1_data : in std_logic;

            read2_address : out unsigned(bank_width - 1 downto 0);
            read2_data : in std_logic;

            read3_address : out unsigned(bank_width - 1 downto 0);
            read3_data : in std_logic;

            --which buffer do we use?
            ram_select_reg : out std_logic;

            button_nextframe : in std_logic;
            button_singlestep : in std_logic;

            --tells that the next row will be displayed
            next_row_disp : in std_logic;
            --the first row is being displayed
            first_row_disp : in std_logic
        );
    end component;

    component gol2_grid is
        generic (
            screen_width : natural := 640;
            screen_height : natural := 480;
            color_depth : natural := 4;

            --grid width/height settings
            gol_cells_width : natural := 80;
            gol_cells_height : natural := 60;
            cell_size_po2 : natural := 3;
            gol_grid_color : natural := 16#F#;
            bank_width : natural
        );
        port (
            clk, reset : in std_logic;
            vga_row : in unsigned(log2(screen_height) - 1 downto 0);
            vga_col : in unsigned(log2(screen_width) - 1 downto 0);

            bkgr_visible : out std_logic;
            vga_pixel_out : out unsigned(color_depth - 1 downto 0);

            next_row : out std_logic;
            first_row : out std_logic;

            dispmem_address : out unsigned(log2(gol_cells_width * gol_cells_height/3) - 1 downto 0);
            dispmem_bank : out unsigned(1 downto 0);
            dispmem_data : in std_logic;

            h_retrace, v_retrace : in std_logic
        );

    end component;

    component ram_grid is
        generic (
            block_address_width : natural := 11;
            file1, file2, file3 : string := "d:/Vitaly/programmation/fpga/uart/converter/gol1.mif"
        );
        port (
            clk : in std_logic;
            address1 : in unsigned(block_address_width - 1 downto 0);
            read1_data : out std_logic;
            write1_en : in std_logic;
            write1_data : in std_logic;
            address2 : in unsigned(block_address_width - 1 downto 0);
            read2_data : out std_logic;
            write2_en : in std_logic;
            write2_data : in std_logic;
            address3 : in unsigned(block_address_width - 1 downto 0);
            read3_data : out std_logic;
            write3_en : in std_logic;
            write3_data : in std_logic
        );
    end component;
    component ram_grid_doublebuf is
        generic (
            block_address_width : natural := 11;
            file1, file2, file3 : string);

        port (
            clk : in std_logic;
            ram_select : in std_logic;

            -- the ram being read (original grid) 
            -- The write signals are only used by the grid download module
            read1_address : in unsigned(block_address_width - 1 downto 0);
            read1_data : out std_logic;
            read1_wen : in std_logic;
            read1_wdata : in std_logic;

            read2_address : in unsigned(block_address_width - 1 downto 0);
            read2_data : out std_logic;
            read2_wen : in std_logic;
            read2_wdata : in std_logic;

            read3_address : in unsigned(block_address_width - 1 downto 0);
            read3_data : out std_logic;
            read3_wen : in std_logic;
            read3_wdata : in std_logic;

            --the ram being displayed (and written)
            disp1_address : in unsigned(block_address_width - 1 downto 0);
            disp1_data : out std_logic;
            disp1_wen : in std_logic;
            disp1_wdata : in std_logic;

            disp2_address : in unsigned(block_address_width - 1 downto 0);
            disp2_data : out std_logic;
            disp2_wen : in std_logic;
            disp2_wdata : in std_logic;

            disp3_address : in unsigned(block_address_width - 1 downto 0);
            disp3_data : out std_logic;
            disp3_wen : in std_logic;
            disp3_wdata : in std_logic
        );
    end component;
end gol2_lib;