// LDD #imm16 with SYNC_MEM=1. Program: LDD #$1234, STD $00 (store D to 0x0000/0x0001), NOPs. Verify mem.
`timescale 1ns / 1ps

module tb_ldd_imm;
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
        mem[16'hE000] = 8'hCC;   // LDD #imm16
        mem[16'hE001] = 8'h12;
        mem[16'hE002] = 8'h34;   // D = 0x1234
        mem[16'hE003] = 8'hDD;   // STD direct
        mem[16'hE004] = 8'h00;   // addr 0x0000
        mem[16'hE005] = 8'h12;   // NOP
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

        repeat (200) @(negedge E);

        if (mem[0] == 8'h12 && mem[1] == 8'h34)
            $display("LDD #imm16 test PASS: mem[0x0000]=0x12, mem[0x0001]=0x34.");
        else
            $display("LDD #imm16 test FAIL: mem[0]=0x%02X mem[1]=0x%02X (expected 0x12 0x34).", mem[0], mem[1]);
        $finish;
    end
endmodule
