vsim work.sdram 

onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /sdram/clk
add wave -noupdate -format Logic /sdram/reset
add wave -noupdate -format Logic /sdram/cs
add wave -noupdate -format Logic /sdram/ras_n
add wave -noupdate -format Logic /sdram/cas_n
add wave -noupdate -format Logic /sdram/we_n
add wave -noupdate -format Logic /sdram/cke
add wave -noupdate -format Literal -radix hexadecimal /sdram/sdram_address
add wave -noupdate -format Literal -radix hexadecimal /sdram/bank_select
add wave -noupdate -format Literal -radix hexadecimal /sdram/dqm
add wave -noupdate -format Literal -radix hexadecimal /sdram/data
add wave -noupdate -format Literal /sdram/cs_ras_cas_we
add wave -noupdate -format Literal /sdram/pw_current_state
add wave -noupdate -format Logic /sdram/counter_start
add wave -noupdate -format Logic /sdram/counter_done
add wave -noupdate -format Logic /sdram/counter_pause
add wave -noupdate -format Literal /sdram/counter_max
add wave -noupdate -format Literal /sdram/s1/counter
add wave -noupdate -format Literal /sdram/s1/cnt_ref
add wave -noupdate -format Literal /sdram/s1/counter_refresh_needed

add wave -noupdate -format Literal /sdram/address
add wave -noupdate -format Literal /sdram/data_read
add wave -noupdate -format Literal /sdram/op_begin
add wave -noupdate -format Literal /sdram/read_valid



TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
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
WaveRestoreZoom {0 ns} {1 us}

force -freeze sim:/sdram/clk 1 0, 0 {50 ns} -r 100
force -freeze sim:/sdram/reset 1 0
run
force -freeze sim:/sdram/reset 0 0
run
force -freeze sim:/sdram/address 16#0# 0
force -freeze sim:/sdram/op_begin true 0
run
