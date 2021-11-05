import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge

@cocotb.test()
async def test_wiggly_ic_1(dut):
    """ Test that d propagates to q """

    print('hi')
    print(dut.clk)
    print('hi2')

    clock = Clock(dut.clk, 10, units="us")  # Create a 10us period clock on port clk
    cocotb.start_soon(clock.start())  # Start the clock

    for i in range(10):
        val = random.randint(0, 1)
        # dut.d.value = val  # Assign the random value val to the input port d
        await FallingEdge(dut.clk)
        # assert dut.q.value == val, "output q was incorrect on the {}th cycle".format(i)