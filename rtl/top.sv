`default_nettype none
`timescale 1ns / 1ps

module top (
  input logic        clk, rst,

  output logic [7:0] most_recent_kbd_data,
  
  inout logic        kbd_clk, kbd_data,
  inout logic        mouse_clk, mouse_data
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
    ps2tx mouse_tx (
      .clk(clk), .reset(rst),
      .wr_ps2(mouse_wr_ps2), .rx_idle(mouse_rx_idle),
      .din(mouse_din),
      .ps2d(mouse_data), .ps2c(mouse_clk),
      .tx_idle(mouse_tx_idle), .tx_done_tick(mouse_tx_done_tick)
      );


    struct      packed {
        enum    {READ, WRITE, DONE} op;
        logic [7:0] code;
        } [5:0] mouse_ops = {
                             {WRITE, 8'hFF},
                             {READ, 8'hFA},
                             {READ, 8'hAA},
                             {READ, 8'h00},
                             {WRITE, 8'hF4},
                             {DONE, 8'h00}
                             };
    typedef logic [$clog2($size(mouse_ops) + 1) - 1:0] mouse_ops_idx_t;
    mouse_ops_idx_t mouse_ops_idx;
    mouse_ops_idx_t mouse_ops_idx_next;

    always_ff @(posedge clk)
        if (rst) mouse_ops_idx <= 0;
        else mouse_ops_idx <= mouse_ops_idx_next;
    // always_comb begin
    //     mouse_state_next = mouse_state;
    //     mouse_wr_ps2 = '0;
    //     mouse_din = '0;
    //     case (mouse_state)
    //       START:
    //         if (mouse_rx_done_tick && mouse_dout == 8'hAA)
    //           mouse_state_next = WILL_ENABLE_DATA_REPORTING;
    //       WILL_ENABLE_DATA_REPORTING: begin
    //           mouse_wr_ps2 = '1;
    //           mouse_din = 8'hF4;
    //           if (mouse_tx_done_tick)
    //             mouse_state_next = SENT_ENABLE_DATA_REPORTING;
    //       end
    //       SENT_ENABLE_DATA_REPORTING:
    //         if (mouse_rx_done_tick && mouse_dout == 8'hFA)
    //           mouse_state_next = ACKNOWLEDGED_ENABLE_DATA_REPORTING;
    //     endcase
    // end // always_comb
    
    always_ff @(posedge clk) begin
        // s[2] = "X";
        // case (mouse_state)
        //   START: s[2] = "0";
        //   WILL_ENABLE_DATA_REPORTING: s[2] = "W";
        //   SENT_ENABLE_DATA_REPORTING: s[2] = "S";
        //   ACKNOWLEDGED_ENABLE_DATA_REPORTING: s[2] = "A";
        // endcase
    end
endmodule
