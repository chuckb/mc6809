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

// MRDY is handled inside the core (stalls READ_USE until MRDY=1). E/Q run from EXTAL. CLK_ROOT = EXTAL for Phase 1.
mc6809i cpucore(.D(D), .DOut(DOut), .ADDR(ADDR), .RnW(RnW), .CLK_ROOT(EXTAL), .E(E), .Q(Q), .BS(BS), .BA(BA), .nIRQ(nIRQ), .nFIRQ(nFIRQ),
                .nNMI(nNMI), .AVMA(AVMA), .BUSY(BUSY), .LIC(LIC), .nHALT(nHALT), .nRESET(nRESET), .nDMABREQ(nDMABREQ),
                .MRDY(MRDY), .RegData(RegData));

always @(negedge CLK)
begin
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


endmodule
