import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

import png

from collections import namedtuple

H_RES = 640
V_RES = 480

def write_png(filename, screenbuffer):
    f = open(filename, 'wb')
    w = png.Writer(H_RES, V_RES, greyscale=False)
    w.write_array(f, screenbuffer)
    f.close()

@cocotb.test()
async def test_wiggly_ic_1(dut):
    # reset (need to trigger all clocks)
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

    screenbuffer = [0]*(H_RES*V_RES*3)
    frame_num = 0
    while frame_num < 10:
        await RisingEdge(dut.vga_vsync)
        
        print(frame_num)

        while True:
            await FallingEdge(dut.vga_clk_pix)
            if dut.vga_de.value == 1:
                i = (dut.vga_sy.value*H_RES + dut.vga_sx.value) * 3
                screenbuffer[i] = dut.vga_r.value << 6
                screenbuffer[i+1] = dut.vga_g.value << 6
                screenbuffer[i+2] = dut.vga_b.value << 6
            if dut.vga_vsync.value == 0:
                break

        write_png('frame' + str(frame_num) + '.png', screenbuffer)
        frame_num += 1

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
