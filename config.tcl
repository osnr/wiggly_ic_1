# User config
set ::env(DESIGN_NAME) wiggly_ic_1

# Change if needed
set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/rtl/*.sv]

# Fill this
set ::env(CLOCK_PERIOD) "10.0"
set ::env(CLOCK_PORT) "clk"

set filename $::env(DESIGN_DIR)/$::env(PDK)_$::env(STD_CELL_LIBRARY)_config.tcl
if { [file exists $filename] == 1} {
	source $filename
}

