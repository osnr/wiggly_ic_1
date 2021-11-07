import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer

H_RES = 640
V_RES = 480

@cocotb.test()
async def test_wiggly_ic_1(dut):
    # FIXME: reset
    dut.rst.value = 1
    dut.clk.value = 0
    dut.vga_clk_pix.value = 0
    await Timer(1, units="ns")
    dut.clk.value = 1
    dut.vga_clk_pix.value = 1
    await Timer(1, units="ns")
    dut.clk.value = 0
    dut.vga_clk_pix.value = 0
    await Timer(1, units="ns")
    dut.rst.value = 0

    clk = Clock(dut.clk, 60, units="ns")  # 60ns period = 16.6MHz
    cocotb.start_soon(clk.start())  # Start the clock

    vga_clk_pix = Clock(dut.vga_clk_pix, 40, units="ns") # 40ns period = 25MHz
    cocotb.start_soon(vga_clk_pix.start())

    await Timer(500, units="ns")  # wait a bit

    print(dut.vga_de)
    
    screenbuffer = []
    for i in range(10):
        print(i)
        while True:
            await FallingEdge(dut.vga_clk_pix)
            if dut.vga_de.value == 1: break
    
    # render VGA image
    # wait for vsync
    # walk through... draw a few frames to a folder
    # automatic test where the cursor is
    # move cursor
    # compare to internal cursor pos
    
    # for i in range(10):
    #     val = random.randint(0, 1)
    #     # dut.d.value = val  # Assign the random value val to the input port d
    #     await FallingEdge(dut.clk)
    #     # assert dut.q.value == val, "output q was incorrect on the {}th cycle".format(i)
