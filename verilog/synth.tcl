read_verilog { "./srcs/cpu.v" "./srcs/main.v" }

read_xdc "./srcs/Arty-S7-25-Master.xdc"

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
