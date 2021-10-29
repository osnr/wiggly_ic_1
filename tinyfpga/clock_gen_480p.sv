// based on https://github.com/projf/projf-explore/blob/9b6e2c3821cf32b48a10629ed88f21b9a143fa7b/lib/clock/ice40/clock_gen_480p.sv
// modified for TinyFPGA 16MHz clock & for CORE instead of PAD

// Project F Library - 640x480p60 Clock Generation (iCE40)
// (C)2021 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

// $ icepll -i 16 -o 25
//
// F_PLLIN:    16.000 MHz (given)
// F_PLLOUT:   25.000 MHz (requested)
// F_PLLOUT:   25.000 MHz (achieved)
//
// FEEDBACK: SIMPLE
// F_PFD:   16.000 MHz
// F_VCO:  800.000 MHz
//
// DIVR:  0 (4'b0000)
// DIVF: 49 (7'b0110001)
// DIVQ:  5 (3'b101)
//
// FILTER_RANGE: 1 (3'b001)

// iCE40 PLLs are documented in Lattice TN1251 and ICE Technology Library

module clock_gen_480p #(
    parameter FEEDBACK_PATH="SIMPLE",
    parameter DIVR=4'b0000,
    parameter DIVF=7'b0110001,
    parameter DIVQ=3'b101,
    parameter FILTER_RANGE=3'b001
    ) (
    input  wire logic clk,        // board oscillator
    input  wire logic rst,        // reset
    output      logic clk_pix,    // pixel clock
    output      logic clk_locked  // generated clock locked?
    );

    logic locked;
    SB_PLL40_CORE #(
        .FEEDBACK_PATH(FEEDBACK_PATH),
        .DIVR(DIVR),
        .DIVF(DIVF),
        .DIVQ(DIVQ),
        .FILTER_RANGE(FILTER_RANGE)
    ) SB_PLL40_CORE_inst (
        .REFERENCECLK(clk),
        .PLLOUTGLOBAL(clk_pix),  // use global clock network
        .RESETB(rst),
        .BYPASS(1'b0),
        .LOCK(locked)
    );

    // ensure clock lock is synced with pixel clock
    logic locked_sync_0;
    always_ff @(posedge clk_pix) begin
        locked_sync_0 <= locked;
        clk_locked <= locked_sync_0;
    end
endmodule
