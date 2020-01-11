vsim work.sdram_test
onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /sdram_test/clk
add wave -noupdate -format Logic /sdram_test/reset
add wave -noupdate -format Logic /sdram_test/sdram_cke
add wave -noupdate -format Logic /sdram_test/sdram_cs
add wave -noupdate -format Logic /sdram_test/sdram_ras_n
add wave -noupdate -format Logic /sdram_test/sdram_cas_n
add wave -noupdate -format Logic /sdram_test/sdram_we_n
add wave -noupdate -format Literal -radix hexadecimal /sdram_test/sdram_address
add wave -noupdate -format Literal /sdram_test/sdram_bank_select
add wave -noupdate -format Literal /sdram_test/sdram_dqm
add wave -noupdate -format Literal -radix hexadecimal /sdram_test/sdram_data
add wave -noupdate -format Literal /sdram_test/current_state
add wave -noupdate -format Literal -radix hexadecimal /sdram_test/address
add wave -noupdate -format Literal -radix hexadecimal /sdram_test/data_wr
add wave -noupdate -format Literal -radix hexadecimal /sdram_test/data_rd
add wave -noupdate -format Logic /sdram_test/address_reset
add wave -noupdate -format Logic /sdram_test/address_incr
add wave -noupdate -format Logic /sdram_test/sdram_ready
add wave -noupdate -format Logic /sdram_test/data_ready
add wave -noupdate -format Logic /sdram_test/op_begin
add wave -noupdate -format Logic /sdram_test/do_write

add wave -noupdate -format Literal -radix hexadecimal /sdram_test/sd1/pw_current_state


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

force -freeze sim:/sdram_test/clk 1 0, 0 {50 ns} -r 100
force -freeze sim:/sdram_test/reset 1 0
run
force -freeze sim:/sdram_test/reset 0 0
