// Indexed addressing load with SYNC_MEM=1. LDX #$F000 (8E F0 00), LDA ,X (A6 84), STA $00.
// Data at 0xF000 = 0x55. Covers data read at EA for indexed (no offset); will be one-cycle in Phase 3.
`timescale 1ns / 1ps

module tb_lda_idx;
    reg         EXTAL;
    wire        XTAL = 0;
    reg         nRESET;
    reg         nHALT;
    reg         MRDY;
    reg         nDMABREQ;
    reg         nIRQ, nFIRQ, nNMI;

    wire [7:0]  D;
    wire [7:0]  DOut;
    wire [15:0] ADDR;
    wire        RnW, E, Q, BS, BA;
    wire [111:0] RegData;

    wire AVMA;
    reg  [7:0] mem_out;
    wire [7:0] D_bus = RnW ? mem_out : DOut;
    assign D = D_bus;

    reg [7:0] mem [0:65535];
    integer mi;
    initial begin
        for (mi = 0; mi <= 65535; mi = mi + 1) mem[mi] = 8'h12; // NOP
        mem[16'hFFFE] = 8'hE0;
        mem[16'hFFFF] = 8'h00;   // Reset vector -> 0xE000
        mem[16'hF000] = 8'h55;   // Data for LDA ,X
        // LDX #$F000 (8E F0 00), LDA ,X (A6 84), STA direct $00 (97 00)
        mem[16'hE000] = 8'h8E;   // LDX #imm16
        mem[16'hE001] = 8'hF0;
        mem[16'hE002] = 8'h00;
        mem[16'hE003] = 8'hA6;   // LDA indexed
        mem[16'hE004] = 8'h84;   // postbyte: ,X (no offset, X)
        mem[16'hE005] = 8'h97;   // STA direct
        mem[16'hE006] = 8'h00;
        mem[16'hE007] = 8'h12;   // NOP
    end
    always @(*) begin
        if (RnW)
            mem_out = mem[ADDR];
        else
            mem_out = 8'hFF;
    end
    always @(posedge E) if (!RnW) mem[ADDR] <= DOut;

    mc6809 uut (
        .D(D_bus),
        .DOut(DOut),
        .ADDR(ADDR),
        .RnW(RnW),
        .E(E),
        .Q(Q),
        .BS(BS),
        .BA(BA),
        .nIRQ(nIRQ),
        .nFIRQ(nFIRQ),
        .nNMI(nNMI),
        .EXTAL(EXTAL),
        .XTAL(XTAL),
        .nHALT(nHALT),
        .nRESET(nRESET),
        .MRDY(MRDY),
        .nDMABREQ(nDMABREQ),
        .RegData(RegData)
    );

    initial EXTAL = 0;
    always #5 EXTAL = ~EXTAL;

    integer cycle_count;
    initial begin
        cycle_count = 0;
        nRESET = 0;
        nHALT  = 1;
        MRDY   = 1;
        nDMABREQ = 1;
        nIRQ = 1; nFIRQ = 1; nNMI = 1;
        #100;
        nRESET = 1;
        #200;

        repeat (300) @(negedge E);

        if (mem[0] == 8'h55)
            $display("LDA indexed (,X) test PASS: mem[0x0000]=0x55 (loaded from 0xF000 via X).");
        else
            $display("LDA indexed test FAIL: mem[0]=0x%02X (expected 0x55).", mem[0]);
        $finish;
    end
endmodule
