read_verilog { "./srcs/rv32.v" "./srcs/main.v" "./srcs/gpio_module.v" }

read_xdc "./srcs/Arty-S7-25-Master.xdc"


add_files -norecurse {/home/violet/Documents/Projects/RISC-V/c/program.hex}
set_property file_type {Memory Initialization Files} [get_files {program.hex}]
update_compile_order -fileset sources_1

# place and route
puts "Starting synthesis..."
synth_design -top "main" -part "xc7s25csga324-1"

set_false_path -from [get_ports gpio*]
set_false_path -to   [get_ports gpio*]

puts "Running opt_design..."
opt_design

puts "Running place_design..."
place_design

puts "Running route_design..."
route_design

report_utilization -file util.txt
report_timing_summary -file timing.txt

# then check specifically
report_methodology -file method.txt

# most useful for IO specifically
report_io -file io.txt

write_checkpoint -force test.dcp

puts "Writing bitstream..."
write_bitstream -force "main.bit"

puts "Done!"
exit
