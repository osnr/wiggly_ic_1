.PHONY: sim

# Verilator target
# ----------------

obj_dir/main:
	verilator -Irtl -cc rtl/top.sv --exe verilator/main.cpp -o main
	make -C ./obj_dir -f Vtop.mk

sim: obj_dir/main
	obj_dir/main
