.PHONY: verilator iverilog prog harden summary

SV_SRCS := $(shell find rtl -name '*.sv')

# Verilator target
# ----------------

VERILATOR_CFLAGS := $(shell sdl2-config --cflags) -g
ifeq ($(CXX),g++)
	VERILATOR_CFLAGS += -fcoroutines
	CXX := g++-10
else ifeq ($(shell uname -s),Darwin) # hack to detect Clang++
	VERILATOR_CFLAGS += -fcoroutines-ts
endif
obj_dir/main: verilator/main.cpp $(SV_SRCS)
	verilator -DSIM --trace -Irtl -cc rtl/wiggly_ic_1.sv --exe verilator/main.cpp -o main \
		-CFLAGS "$(VERILATOR_CFLAGS)" \
		-LDFLAGS "$(shell sdl2-config --libs)"
	make -C ./obj_dir -f Vwiggly_ic_1.mk CXX=$(CXX)

verilator: obj_dir/main
	obj_dir/main

# Icarus Verilog target
# ---------------------

# iverilog:
# 	iverilog -g2009 -o sim.vvp -s wiggly_ic_1 $(SV_SRCS)
# 	vvp sim.vvp

cocotb:
	rm -rf sim_build
	make --file=$(shell cocotb-config --makefiles)/Makefile.sim \
		SIM=icarus TOPLEVEL_LANG=verilog \
		VERILOG_SOURCES="$(SV_SRCS)" \
		TOPLEVEL=wiggly_ic_1 MODULE=test.test_wiggly_ic_1

# TinyFPGA BX (iCE40) target
# --------------------------

TINYFPGA_SV_SRCS := $(shell find tinyfpga -name '*.sv')

%.json: $(TINYFPGA_SV_SRCS) $(SV_SRCS)
	yosys -p 'synth_ice40 -top tinyfpga_top -json $@' $^
%.asc: %.json
	nextpnr-ice40 --lp8k --package cm81 --json $< --pcf tinyfpga/pins.pcf --asc $@ --ignore-loops
%.bin: %.asc
	icepack $< $@

prog: top.bin
	tinyprog -p $<

# efabless MPW3 shuttle (OpenLane) target
# ---------------------------------------

# parsing `ls` output... I guess will break if spaces in path?
LATEST_RUN := runs/$(shell ls -t runs | head -n1)

# _horrible_ hack to get ENV_COMMAND out of OpenLane Makefile
harden: $(SV_SRCS)
	$(shell make -s -C $$OPENLANE_ROOT __wiggly_harden \
		--eval '__wiggly_harden:; echo $$(ENV_COMMAND)') \
		./flow.tcl -design wiggly_ic_1

print-summary:
	summary.py --design wiggly_ic_1 --summary
print-timing:
	cat $(LATEST_RUN)/reports/synthesis/opensta.min_max.rpt
open-magic:
	cd $(LATEST_RUN)/results/magic/ && DISPLAY=:0 magic wiggly_ic_1.gds

# gate-level simulation (need to harden first)
VERILOG = $$PDK_PATH/libs.ref/sky130_fd_sc_hd/verilog
obj_dir_gate_level/main_gate_level: $(LATEST_RUN)/results/lvs/wiggly_ic_1.lvs.powered.v verilator/main.cpp
	verilator --trace -I$(VERILOG) -cc $< --exe verilator/main.cpp --Mdir obj_dir_gate_level -o main_gate_level \
		-CFLAGS "$(VERILATOR_CFLAGS)" \
		-LDFLAGS "$(shell sdl2-config --libs)"
	make -C ./obj_dir_gate_level -f Vwiggly_ic_1.mk CXX=$(CXX)
