vsim work.gol2

onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /gol2/clk
add wave -noupdate -format Logic /gol2/reset
add wave -noupdate -format Literal -radix hexadecimal /gol2/vga_row
add wave -noupdate -format Literal -radix hexadecimal /gol2/vga_col
add wave -noupdate -format Literal -radix hexadecimal /gol2/vga_color
#add wave -noupdate -format Logic -radix hexadecimal /gol2/vga_vretrace
#add wave -noupdate -format Logic -radix hexadecimal /gol2/vga_hretrace
#add wave -noupdate -format Literal -radix hexadecimal /gol2/gol/cnt_mod3
add wave -noupdate -format Logic -radix hexadecimal /gol2/ram_select_reg
add wave -noupdate -format Literal -radix hexadecimal /gol2/disp1_address
add wave -noupdate -format Literal -radix hexadecimal /gol2/disp2_address
add wave -noupdate -format Literal -radix hexadecimal /gol2/disp3_address
add wave -noupdate -format Literal -radix hexadecimal /gol2/disp1_data
#add wave -noupdate -format Literal -radix hexadecimal /gol2/gol/grid_row
#add wave -noupdate -format Literal -radix hexadecimal /gol2/gol/grid_col
#add wave -noupdate -format Logic /gol2/gol/dispmem_data
#add wave -noupdate -format Literal -radix hexadecimal /gol2/gol/dispmem_bank
add wave -noupdate -format Literal -radix hexadecimal /gol2/read1_address
add wave -noupdate -format Literal -radix hexadecimal /gol2/read2_address
add wave -noupdate -format Literal -radix hexadecimal /gol2/read3_address
add wave -noupdate -format Logic -radix hexadecimal /gol2/read1_data
add wave -noupdate -format Logic -radix hexadecimal /gol2/read2_data
add wave -noupdate -format Logic -radix hexadecimal /gol2/read3_data
add wave -noupdate -format Logic /gol2/golcg/cl/compute_done
add wave -noupdate -format Logic /gol2/golcg/cl/preload_start
add wave -noupdate -format Logic /gol2/golcg/cl/compute_start
add wave -noupdate -format Literal /gol2/golcg/cl/line1
add wave -noupdate -format Literal /gol2/golcg/cl/line2
add wave -noupdate -format Literal /gol2/golcg/cl/line3
add wave -noupdate -format Literal /gol2/golcg/cl/current_state
add wave -noupdate -format Literal /gol2/golcg/cl/sum
add wave -noupdate -format Logic /gol2/golcg/cl/preload_i
add wave -noupdate -format Logic /gol2/golcg/cl/compute_i
add wave -noupdate -format Logic /gol2/golcg/cl/shift_enable
add wave -noupdate -format Unsigned /gol2/golcg/cl/row_offset
add wave -noupdate -format Unsigned /gol2/golcg/cl/col_offset

add wave -noupdate -format Unsigned /gol2/golcg/cl/col_offset_i
add wave -noupdate -format Unsigned /gol2/golcg/cl/col_offset_j
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {662 ns} 0}
configure wave -namecolwidth 246
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
update
WaveRestoreZoom {0 ns} {1777 ns}

force -freeze sim:/gol2/button_singlestep 0 0
force -freeze sim:/gol2/update_grid 0 0
force -freeze sim:/gol2/clk 1 0, 0 {50 ns} -r 100
force -freeze sim:/gol2/reset 1 0
run
force -freeze sim:/gol2/reset 0 0
