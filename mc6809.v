`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    08:11:34 09/23/2016 
// Design Name: 
// Module Name:    mc6809e 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module mc6809(
    input   [7:0] D,
    output  [7:0] DOut,
    output  [15:0] ADDR,
    output  RnW,
    output  E,
    output  Q,
    output  BS,
    output  BA,
    input   nIRQ,
    input   nFIRQ,
    input   nNMI,
    input   EXTAL,
    input   XTAL,
    input   nHALT,	 
    input   nRESET,
    input   MRDY,
    input   nDMABREQ
    
    , output  [111:0] RegData
    );

reg [1:0] clk_phase=2'b00;

wire CLK;
assign CLK=EXTAL;

wire   LIC;
wire   BUSY;
wire   AVMA;
reg    rE = 0;
reg    rQ = 0;
assign E = rE;
assign Q = rQ;

// E/Q derived from EXTAL; when MRDY=0 during E-high/Q-low (phase 11), hold that phase for extra
// quarter-cycles (stretch) so memory has time to respond. Limit stretch to MRDY_STRETCH_LIMIT quarter-cycles.
parameter MRDY_STRETCH_LIMIT = 10;  // max extra quarter-cycles when MRDY=0 (tuned per manual)
reg [4:0] stretch_count = 5'b0;     // count stretch cycles; saturate at limit

// MRDY is used here for stretch and inside the core (stalls read until MRDY=1). CLK_ROOT = EXTAL.
mc6809i cpucore(.D(D), .DOut(DOut), .ADDR(ADDR), .RnW(RnW), .CLK_ROOT(EXTAL), .E(E), .Q(Q), .BS(BS), .BA(BA), .nIRQ(nIRQ), .nFIRQ(nFIRQ),
                .nNMI(nNMI), .AVMA(AVMA), .BUSY(BUSY), .LIC(LIC), .nHALT(nHALT), .nRESET(nRESET), .nDMABREQ(nDMABREQ),
                .MRDY(MRDY), .RegData(RegData));

always @(negedge CLK)
begin
    if (clk_phase == 2'b11 && MRDY == 1'b0 && stretch_count < MRDY_STRETCH_LIMIT)
    begin
        // E high, Q low: stretch — hold phase 11 (E=1, Q=0) for another quarter-cycle
        stretch_count <= stretch_count + 1'b1;
        rQ <= 1'b0;   // keep Q low (re-assert phase 11 outputs)
        rE <= 1'b1;   // keep E high
        clk_phase <= 2'b11;
    end
    else
    begin
        if (clk_phase != 2'b11 || MRDY == 1'b1)
            stretch_count <= 5'b0;
        case (clk_phase)
            2'b00:
                rE <= 0;
            2'b01:
                rQ <= 1;
            2'b10:
                rE <= 1;
            2'b11:
                rQ <= 0;
        endcase
        clk_phase <= clk_phase + 2'b01;
    end
end


endmodule
