# ============================
# Vivado Flash Detection Script
# ============================

# Open hardware server and target
open_hw_manager
connect_hw_server
open_hw_target

# Get first detected device
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev

puts "Detected FPGA device: [get_property PART $dev]"

# Create a cfgmem object tied to the FPGA
set cfgmems [get_property CFGMEM_PART $dev]
if {$cfgmems eq ""} {
    puts "No CFGMEM_PART detected in device properties."
    puts "This usually means Vivado cannot identify the flash automatically."
} else {
    puts "Detected flash configuration memory:"
    puts "$cfgmems"
}

# Dump all relevant properties for debugging
puts "\nRelevant hardware properties:"
foreach p [list CFGMEM_PART CONFIG_MODE CONFIG_MEMORY_VOLTAGE] {
    if {[lsearch [list_property $dev] $p] >= 0} {
        puts "$p : [get_property $p $dev]"
    }
}
