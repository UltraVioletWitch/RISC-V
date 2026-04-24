read_verilog -sv { "./srcs/top.sv" }

read_xdc "./srcs/Arty-S7-25-Master.xdc"

synth_design -top "top" -part "xc7s25csga324-1"

# place and route
opt_design
place_design
route_design

# write bitstream
write_bitstream -force "main.bit"
