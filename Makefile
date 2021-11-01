.PHONY: sim test prog harden summary

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
	verilator --trace -Irtl -cc rtl/wiggly_ic_1.sv --exe verilator/main.cpp -o main \
		-CFLAGS "$(VERILATOR_CFLAGS)" \
		-LDFLAGS "$(shell sdl2-config --libs)"
	make -C ./obj_dir -f Vwiggly_ic_1.mk CXX=$(CXX)

sim: obj_dir/main
	obj_dir/main

test: obj_dir/main
	obj_dir/main test

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
