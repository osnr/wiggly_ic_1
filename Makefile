.PHONY: sim prog

SV_SRCS := $(shell find rtl -name '*.sv')

# Verilator target
# ----------------

obj_dir/main: verilator/main.cpp $(SV_SRCS)
	verilator -Irtl -cc rtl/top.sv --exe verilator/main.cpp -o main \
		-CFLAGS "$(shell sdl2-config --cflags) -g" \
		-LDFLAGS "$(shell sdl2-config --libs)"
	make -C ./obj_dir -f Vtop.mk

sim: obj_dir/main
	obj_dir/main

# TinyFPGA BX (iCE40) target
# --------------------------

%.json: tinyfpga/tinyfpga_top.sv $(SV_SRCS)
	yosys -p 'synth_ice40 -top tinyfpga_top -json $@' $^
%.asc: %.json
	nextpnr-ice40 --lp8k --package cm81 --json $< --pcf tinyfpga/pins.pcf --asc $@ --ignore-loops
%.bin: %.asc
	icepack $< $@

prog: top.bin
	tinyprog -p $<
