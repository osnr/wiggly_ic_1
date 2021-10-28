`default_nettype none
`timescale 1ns / 1ps

module tinyfpga_top (
    input wire   logic CLK, // 16MHz clock

    inout logic  PIN_10, PIN_11, // keyboard
    inout logic  PIN_12, PIN_13, // mouse

    output logic PIN_14, PIN_15, // vga_r
                 PIN_16, PIN_17, // vga_g
                 PIN_18, PIN_19, // vga_b
                 PIN_20, PIN_21, // vga_hsync, vga_vsync
                     
    // logic analyzer pins 0 - 3
    output logic PIN_1,
    output logic PIN_2,
    output logic PIN_3,
    output logic PIN_4
  );

    // logic        rst;
    // logic [3:0]    rst_state = 0;
    // assign rst = !&rst_state;
    // always_ff @(posedge CLK) begin
    //     rst_state <= rst_state + rst;
    // end
    
    logic [7:0]  most_recent_kbd_data;

    // generate pixel clock
    logic clk_pix;
    logic clk_locked;
    clock_gen_480p clock_pix_inst (
       .clk(CLK),
       .rst(1'b1),
       .clk_pix,
       .clk_locked
    );

    top top_inst (
      .clk(CLK), .rst(!clk_locked),

      .kbd_clk(PIN_11),
      .kbd_data(PIN_10),
      .most_recent_kbd_data,

      .mouse_clk(PIN_13),
      .mouse_data(PIN_12),

      .vga_clk_pix(clk_pix),
      .vga_r({PIN_14, PIN_15}),
      .vga_g({PIN_16, PIN_17}),
      .vga_b({PIN_18, PIN_19}),
      .vga_hsync(PIN_20),
      .vga_vsync(PIN_21),
      .vga_sx(),
      .vga_sy(),
      .vga_de(),
    );

    assign {PIN_1, PIN_2, PIN_3, PIN_4} = {most_recent_kbd_data[0], most_recent_kbd_data[1], most_recent_kbd_data[2], most_recent_kbd_data[3]};

endmodule // tinyfpga_top
