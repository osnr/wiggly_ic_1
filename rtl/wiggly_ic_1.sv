`default_nettype none
`timescale 1ns / 1ps
`ifdef COCOTB_SIM
 `define SIM
`endif
`ifdef VERILATOR
 `define SIM
`endif

module wiggly_ic_1 (
  input logic        clk, rst,
                     
  input wire         logic vga_clk_pix, // pixel clock
  output logic       vga_hsync, vga_vsync,
  output logic [1:0] vga_r, vga_g, vga_b, // 2-bit VGA r/g/b
  // used by Verilator:
  output logic [9:0] vga_sx, vga_sy, // horiz/vert screen position
  output logic       vga_de,

  output logic [7:0] most_recent_kbd_data,
  
  inout logic        kbd_clk, kbd_data,
  inout logic        mouse_clk, mouse_data
  );

`ifdef COCOTB_SIM
    initial begin
        $dumpfile ("cocotb.vcd");
        $dumpvars (0, wiggly_ic_1);
        #1;
    end
`endif

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
    always_ff @(posedge clk)
      if (kbd_rx_done_tick)
        most_recent_kbd_data <= kbd_dout;

    // PS/2 mouse
    logic [7:0] mouse_dout;
    logic       mouse_rx_done_tick;
    logic       mouse_rx_idle, mouse_tx_idle;
    ps2rx mouse_rx (
      .clk(clk), .reset(rst),
      .ps2d(mouse_data), .ps2c(mouse_clk),
      .rx_en(mouse_tx_idle),

      .rx_idle(mouse_rx_idle), .rx_done_tick(mouse_rx_done_tick),
      .dout(mouse_dout)
      );
    logic       mouse_tx_done_tick;
    // outputs of the fsm
    logic       mouse_wr_ps2;
    logic [7:0] mouse_din;

`ifdef SIM
    assign mouse_tx_idle = '1;
`else
    ps2tx mouse_tx (
      .clk(clk), .reset(rst),
      .wr_ps2(mouse_wr_ps2), .rx_idle(mouse_rx_idle),
      .din(mouse_din),
      .ps2d(mouse_data), .ps2c(mouse_clk),
      .tx_idle(mouse_tx_idle), .tx_done_tick(mouse_tx_done_tick)
      );
`endif

    typedef enum {READ_EXPECT, WRITE,
                  READ_PACKET0, READ_PACKET1, READ_PACKET2, DONE_PACKET} mouse_opcode_t;
    typedef logic [4:0] mouse_ops_idx_t;
    typedef struct packed {
        mouse_opcode_t op;
        logic [7:0] code;
    } mouse_op_t;

    mouse_ops_idx_t mouse_ops_idx;
    mouse_ops_idx_t mouse_ops_idx_next;
    always_ff @(posedge clk)
        if (rst)
          `ifdef SIM
            mouse_ops_idx <= 5'd06; // skip to reading packets
          `else
            mouse_ops_idx <= '0;
          `endif    
        else mouse_ops_idx <= mouse_ops_idx_next;

    mouse_op_t mouse_op;
    always_comb
      case (mouse_ops_idx)
        5'd00: mouse_op = {WRITE, 8'hFF};
        5'd01: mouse_op = {READ_EXPECT, 8'hFA};
        5'd02: mouse_op = {READ_EXPECT, 8'hAA};
        5'd03: mouse_op = {READ_EXPECT, 8'h00};
        5'd04: mouse_op = {WRITE, 8'hF4};
        5'd05: mouse_op = {READ_EXPECT, 8'hFA};

        5'd06: mouse_op = {READ_PACKET0, 8'h00};
        5'd07: mouse_op = {READ_PACKET1, 8'h00};
        5'd08: mouse_op = {READ_PACKET2, 8'h00};

        5'd09: mouse_op = {DONE_PACKET, 8'h00};

        default: mouse_op = {WRITE, 8'hFF}; // bad
      endcase

    typedef struct packed {
        logic        y_overflow, x_overflow;
        logic        y_sign_bit, x_sign_bit;
        logic        always_1;
        logic        middle_btn, right_btn, left_btn;
        logic [7:0]  x_movement, y_movement;
    } mouse_packet_t;
    mouse_packet_t mouse_packet;
    mouse_packet_t mouse_packet_next;
    always_ff @(posedge clk)
      if (rst) mouse_packet <= '0;
      else mouse_packet <= mouse_packet_next;

    always_comb begin
        mouse_ops_idx_next = mouse_ops_idx;
        mouse_packet_next = mouse_packet;
        mouse_wr_ps2 = '0;
        mouse_din = '0;
        case (mouse_op.op)
          WRITE: begin
              mouse_wr_ps2 = '1;
              mouse_din = mouse_op.code;
              if (mouse_tx_done_tick)
                mouse_ops_idx_next = mouse_ops_idx + 1;
          end
          READ_EXPECT:
            if (mouse_rx_done_tick && mouse_dout == mouse_op.code)
              mouse_ops_idx_next = mouse_ops_idx + 1;
          READ_PACKET0:
            if (mouse_rx_done_tick) begin
                mouse_packet_next = {mouse_dout, 8'h00, 8'h00};
                mouse_ops_idx_next = mouse_ops_idx + 1;
            end
          READ_PACKET1:
            if (mouse_rx_done_tick) begin
                mouse_packet_next = {mouse_packet[23:16], mouse_dout, 8'h00};
                mouse_ops_idx_next = mouse_ops_idx + 1;
            end
          READ_PACKET2:
            if (mouse_rx_done_tick) begin
                mouse_packet_next = {mouse_packet[23:16], mouse_packet[15:8], mouse_dout};
                mouse_ops_idx_next = mouse_ops_idx + 1;
            end
          DONE_PACKET:
            mouse_ops_idx_next = 5'd06; // HACK
        endcase
    end

    logic [9:0] mouse_x, mouse_y;
    always_ff @(posedge clk)
      if (rst) begin
          mouse_x <= 10'd100;
          mouse_y <= 10'd100;
      end else if (mouse_op.op == DONE_PACKET) begin
          mouse_x <= mouse_packet.x_sign_bit ?
                     (mouse_x + ({'0, mouse_packet.x_movement} - (10'b100000000))) :
                     (mouse_x + {'0, mouse_packet.x_movement});
          mouse_y <= mouse_packet.y_sign_bit ?
                     (mouse_y - ({'0, mouse_packet.y_movement} - (10'b100000000))) :
                     (mouse_y - {'0, mouse_packet.y_movement});
      end

    // VGA
    simple_display_timings_480p display_timings_inst (
        .clk_pix(vga_clk_pix), .rst(rst),
        .sx(vga_sx), .sy(vga_sy),
        .hsync(vga_hsync), .vsync(vga_vsync), .de(vga_de)
    );
    always_comb begin
        vga_r = '0; vga_g = '0; vga_b = '0;
        if (vga_de) begin
            if ((mouse_x <= vga_sx && vga_sx <= mouse_x + 10 &&
                 mouse_y <= vga_sy && vga_sy <= mouse_y + 10)) begin

                if (mouse_op.op == READ_PACKET0) begin
                  vga_r = 2'h0; vga_g = 2'h0; vga_b = 2'h3;
                end else begin
                  vga_r = 2'h3; vga_g = 2'h0; vga_b = 2'h0;
                end
            end
        end
    end
endmodule
