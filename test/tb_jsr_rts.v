// JSR/RTS with SYNC_MEM=1. Exercises RTS_HI_READ_USE and RTS_LO_READ_USE (stack pull for return address).
// Main at 0xE000: JSR $E100 (extended). Sub at 0xE100: LDA #$99, STA $00, RTS. Back: LDA #$77, STA $01. Verify mem.
`timescale 1ns / 1ps

module tb_jsr_rts;
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
        mem[16'hFFFF] = 8'h00;   // Reset -> 0xE000
        // Main: JSR $E100 (BD E1 00), then LDA #$77 STA $01
        mem[16'hE000] = 8'hBD;   // JSR extended
        mem[16'hE001] = 8'hE1;
        mem[16'hE002] = 8'h00;   // -> 0xE100
        mem[16'hE003] = 8'h86;   // LDA #$77 (return addr)
        mem[16'hE004] = 8'h77;
        mem[16'hE005] = 8'h97;   // STA direct
        mem[16'hE006] = 8'h01;   // addr 0x0001
        mem[16'hE007] = 8'h12;   // NOP
        // Subroutine at 0xE100: LDA #$99, STA $00, RTS
        mem[16'hE100] = 8'h86;   // LDA #imm
        mem[16'hE101] = 8'h99;
        mem[16'hE102] = 8'h97;   // STA direct
        mem[16'hE103] = 8'h00;   // addr 0x0000
        mem[16'hE104] = 8'h39;   // RTS
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

        repeat (500) @(negedge E);

        if (mem[0] == 8'h99 && mem[1] == 8'h77)
            $display("JSR/RTS test PASS: mem[0]=0x99 (sub ran), mem[1]=0x77 (returned to main).");
        else
            $display("JSR/RTS test FAIL: mem[0]=0x%02X mem[1]=0x%02X (expected 0x99 0x77).", mem[0], mem[1]);
        if (RegData[111:96] < 16'hE100 || RegData[111:96] > 16'hE108)
            $display("  PC=0x%04X (not stuck in sub 0xE100-0xE104).", RegData[111:96]);
        else
            $display("  PC=0x%04X (may be stuck in sub?).", RegData[111:96]);
        $finish;
    end
endmodule
