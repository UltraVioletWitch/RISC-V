set bitfile   "main.bit"
set mcsfile   "main.mcs"
set flash_size "16"   ;# 16 MByte = 128 Mbit (N25Q128)

open_hw_manager
connect_hw_server
open_hw_target

current_hw_device [get_hw_devices xc7s25_0]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7s25_0] 0]

write_cfgmem \
    -format mcs \
    -interface spix4 \
    -size $flash_size \
    -loadbit "up 0x0 $bitfile" \
    -file $mcsfile \
    -force

create_hw_cfgmem -hw_device [lindex [get_hw_devices xc7s25_0] 0] [lindex [get_cfgmem_parts {s25fl128sxxxxxx0-spi-x1_x2_x4}] 0]
set_property PROGRAM.BLANK_CHECK  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.ERASE  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CFG_PROGRAM  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.VERIFY  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CHECKSUM  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
refresh_hw_device [lindex [get_hw_devices xc7s25_0] 0]

set_property PROGRAM.ADDRESS_RANGE  {use_file} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.FILES [list "/home/violet/Documents/Projects/RISC-V/verilog/main.mcs" ] [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.PRM_FILE {} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.BLANK_CHECK  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.ERASE  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CFG_PROGRAM  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.VERIFY  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CHECKSUM  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
startgroup
create_hw_bitstream -hw_device [lindex [get_hw_devices xc7s25_0] 0] [get_property PROGRAM.HW_CFGMEM_BITFILE [ lindex [get_hw_devices xc7s25_0] 0]]; program_hw_devices [lindex [get_hw_devices xc7s25_0] 0]; refresh_hw_device [lindex [get_hw_devices xc7s25_0] 0];

program_hw_cfgmem -hw_cfgmem [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]

endgroup
