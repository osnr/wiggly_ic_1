.PHONY: sim

# Verilator target
# ----------------

SV_SRCS := $(shell find rtl -name '*.sv')

obj_dir/main: verilator/main.cpp $(SV_SRCS)
	verilator -Irtl -cc rtl/top.sv --exe verilator/main.cpp -o main
	make -C ./obj_dir -f Vtop.mk

sim: obj_dir/main
	obj_dir/main
