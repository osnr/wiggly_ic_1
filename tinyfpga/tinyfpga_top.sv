`default_nettype none
`timescale 1ns / 1ps

module tinyfpga_top (
    input wire   logic CLK, // 16MHz clock

    inout logic  PIN_10,
    inout logic  PIN_11
  );

    top top_inst (
      .clk(CLK), .rst('1),
      .kbd_clk(PIN_11),
      .kbd_data(PIN_10)
    );

endmodule // tinyfpga_top
