`default_nettype none
`timescale 1ns / 1ps

module top (
  input logic        clk, rst,

  output logic [7:0] most_recent_kbd_data,
  
  inout logic        kbd_clk, kbd_data
  );
    // PS/2 keyboard input
    logic [7:0]      kbd_dout;
    logic            kbd_rx_done_tick;
    ps2rx kbd (
      .clk(clk), .reset(rst),
      .ps2d(kbd_data), .ps2c(kbd_clk),
      .rx_en(1'b1),

      .rx_idle(), .rx_done_tick(kbd_rx_done_tick),
      .dout(kbd_dout)
      );
    always_ff @(posedge clk) begin
        if (kbd_rx_done_tick) begin
            most_recent_kbd_data <= kbd_dout;
        end
    end
endmodule
