// ORCC #$10 with SYNC_MEM=1. Program: reset -> 0xE000, ORCC #$10 (set I bit), NOP. Verifies I bit set.
`timescale 1ns / 1ps

module tb_orcc_sync;
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
        mem[16'hE000] = 8'h1A;   // ORCC #imm
        mem[16'hE001] = 8'h10;   // set I bit (bit 4)
        mem[16'hE002] = 8'h12;   // NOP
    end
    always @(*) begin
        if (RnW)
            mem_out = mem[ADDR];
        else
            mem_out = 8'hFF;
    end

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

        repeat (50) @(negedge E);

        if (RegData[84] == 1)
            $display("ORCC test PASS: I bit set.");
        else
            $display("ORCC test FAIL: I bit not set (cc=0x%02X).", RegData[87:80]);
        $finish;
    end
endmodule
