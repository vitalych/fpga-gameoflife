vsim work.vga 
onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /vga/clk
add wave -noupdate -format Logic /vga/reset
add wave -noupdate -format Logic /vga/v_retrace
add wave -noupdate -format Logic /vga/h_retrace
add wave -noupdate -format Literal -radix unsigned /vga/row
add wave -noupdate -format Literal -radix unsigned /vga/col
add wave -noupdate -format Literal -radix unsigned /vga/hcnt
add wave -noupdate -format Literal -radix unsigned /vga/vcnt
add wave -noupdate -format Logic /vga/v_retrace_i
add wave -noupdate -format Logic /vga/h_retrace
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {80580000 ns} 0}
configure wave -namecolwidth 150
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
WaveRestoreZoom {80579712 ns} {80580712 ns}

force -freeze sim:/vga/clk 1 0, 0 {50 ns} -r 100
force -freeze sim:/vga/reset 1 0
run
force -freeze sim:/vga/reset 0 0
