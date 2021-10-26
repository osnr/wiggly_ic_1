`default_nettype none
`timescale 1ns / 1ps

module tinyfpga_top (
    input wire   logic CLK, // 16MHz clock

    inout logic  PIN_10,
    inout logic  PIN_11,

    // logic analyzer pins 0 - 3
    output logic PIN_1,
    output logic PIN_2,
    output logic PIN_3,
    output logic PIN_4
  );

    logic        rst;
    logic [3:0]    rst_state = 0;
    assign rst = !&rst_state;
    always_ff @(posedge CLK) begin
        rst_state <= rst_state + rst;
    end
    
    logic [7:0]  most_recent_kbd_data;

    top top_inst (
      .clk(CLK), .rst,
      .kbd_clk(PIN_11),
      .kbd_data(PIN_10),
      .most_recent_kbd_data
    );

    assign {PIN_1, PIN_2, PIN_3, PIN_4} = {most_recent_kbd_data[0], most_recent_kbd_data[1], most_recent_kbd_data[2], most_recent_kbd_data[3]};

endmodule // tinyfpga_top
