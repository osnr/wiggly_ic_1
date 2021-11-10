# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(shell find ../rtl -name '*.sv')

TOPLEVEL = wiggly_ic_1

MODULE = test_wiggly_ic_1

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
