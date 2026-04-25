read_verilog { "./srcs/cpu.v" "./srcs/main.v" }

read_xdc "./srcs/Arty-S7-25-Master.xdc"

add_files -norecurse {/home/violet/Documents/Projects/RISC-V/c/program.hex}
set_property file_type {Memory Initialization Files} [get_files {program.hex}]
update_compile_order -fileset sources_1

# place and route
puts "Starting synthesis..."
synth_design -top "main" -part "xc7s25csga324-1"

puts "Running opt_design..."
opt_design

puts "Running place_design..."
place_design

puts "Running route_design..."
route_design

report_utilization \
    -file utilization.rpt

set wns [get_property SLACK [get_timing_paths]]
puts "Worst Negative Slack (WNS): $wns"

report_timing -file timing_summary.rpt
