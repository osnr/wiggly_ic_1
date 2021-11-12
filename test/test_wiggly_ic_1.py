import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

import png
from datetime import datetime

codes_to_send = []
async def mouse(dut):
    while True:
        while len(codes_to_send) == 0:
            dut.mouse_clk_in = 1
            dut.mouse_data_in = 1
            await Timer(1, units="us")

        code = codes_to_send.pop(0)
        
        start = 0
        parity = 0
        stop = 1

        num_ones = 0

        bits = []
        bits.append(start)
        for i in range(0, 8):
            bit = (code >> i) & 0x01
            bits.append(bit)
            num_ones += bit
        parity = num_ones % 2 == 0
        bits.append(parity)
        bits.append(stop)

        dut.mouse_clk_in = 1
        dut.mouse_data_in = 1
        await Timer(50, units="us")

        i = 0
        for bit in bits:
            dut.mouse_clk_in = 1
            await Timer(20, units="us")
            dut.mouse_data_in = bit
            await Timer(20, units="us")
            dut.mouse_clk_in = 0
            await Timer(20, units="us")
        await Timer(20, units="us")

        dut.mouse_clk_in = 1
        dut.mouse_data_in = 1
        await Timer(200, units="us")
    
async def mouse_tester(dut):
    cocotb.fork(mouse(dut))
    def send(code): codes_to_send.append(code)
    def move_mouse(xrel, yrel):
        yrel = -yrel;
        send(0b00001000 |
                   ((xrel >> 31) << 4) |
                   ((yrel >> 31) << 5));
        send(xrel & 0xFF)
        send(yrel & 0xFF)

    await Timer(50, units="us")
    move_mouse(5, 10)

H_RES = 640
V_RES = 480

def write_png(filename, screenbuffer):
    f = open(filename, 'wb')
    w = png.Writer(H_RES, V_RES, greyscale=False)
    w.write_array(f, screenbuffer)
    f.close()

@cocotb.test()
async def test_wiggly_ic_1(dut):
    def info(fmt, *args):
        dut._log.info("%s\t" + fmt, datetime.now(), *args)

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
    cocotb.fork(clk.start())  # Start the clock

    vga_clk_pix = Clock(dut.vga_clk_pix, 40, units="ns") # 40ns period = 25MHz
    cocotb.fork(vga_clk_pix.start())

    info("hello")

    await Timer(500, units="ns")  # wait a bit

    cocotb.fork(mouse_tester(dut))

    screenbuffer = [0]*(H_RES*V_RES*3)
    def index(x, y): return (y*H_RES + x) * 3

    frame_num = 0
    while frame_num < 2:
        await RisingEdge(dut.vga_vsync)
        
        while True:
            await FallingEdge(dut.vga_clk_pix)
            if dut.vga_de.value == 1:
                i = (dut.vga_sy.value*H_RES + dut.vga_sx.value) * 3
                screenbuffer[i] = dut.vga_r.value << 6
                screenbuffer[i+1] = dut.vga_g.value << 6
                screenbuffer[i+2] = dut.vga_b.value << 6

            if dut.vga_vsync.value == 0:
                break

        info('frame %d', frame_num)
        write_png('frame' + str(frame_num) + '.png', screenbuffer)

        assert screenbuffer[index(0, 0)] == 0b11 << 6

        # blue cursor
        info("mouse_x=%d, mouse_y=%d", dut.mouse_x.value, dut.mouse_y.value)
        cursor = index(dut.mouse_x.value, dut.mouse_y.value)
        assert screenbuffer[cursor] == 0b00 << 6
        assert screenbuffer[cursor + 1] == 0b00 << 6
        assert screenbuffer[cursor + 2] == 0b11 << 6

        frame_num += 1

    # TODO: move the mouse, check for new cursor position
