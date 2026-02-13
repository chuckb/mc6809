// Test: NMI with SYNC_MEM. Main: LDD/TFR S=0x100, ANDCC #$EF, NOPs.
// Assert nNMI; CPU stacks full frame, fetches vector, runs ISR at 0xE300.
// ISR: LDA #$C5, STA $02, RTI. Verify mem[0x0002]==0xC5 and PC resumed.
`timescale 1ns / 1ps

module tb_nmi_rti;
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
        mem[16'h0002] = 8'h00;   // ISR will write 0xC5 here
        mem[16'hFFFE] = 8'hE0;
        mem[16'hFFFF] = 8'h00;   // Reset vector -> 0xE000
        mem[16'hFFFC] = 8'hE3;   // NMI vector high
        mem[16'hFFFD] = 8'h00;   // NMI vector low -> 0xE300
        // Main: LDD #0x0100, TFR D,S, ANDCC #$EF (clear I), NOPs
        mem[16'hE000] = 8'hCC;   // LDD #imm16
        mem[16'hE001] = 8'h01;
        mem[16'hE002] = 8'h00;
        mem[16'hE003] = 8'h1F;   // TFR
        mem[16'hE004] = 8'h04;   // D -> S
        mem[16'hE005] = 8'h1C;   // ANDCC #imm
        mem[16'hE006] = 8'hEF;   // clear I bit
        // ISR at 0xE300: LDA #$C5, STA $02 (direct), RTI
        mem[16'hE300] = 8'h86;   // LDA #imm
        mem[16'hE301] = 8'hC5;
        mem[16'hE302] = 8'h97;   // STA direct
        mem[16'hE303] = 8'h02;
        mem[16'hE304] = 8'h3B;   // RTI
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
        nIRQ   = 1; nFIRQ = 1; nNMI = 1;
        #100;
        nRESET = 1;
        #200;

        repeat (20000) begin
            @(negedge E);
            cycle_count = cycle_count + 1;
            if (cycle_count == 100 && RegData[111:96] >= 16'hE009)
                nNMI = 0;
            if (cycle_count == 600)
                nNMI = 1;
        end

        if (mem[2] == 8'hC5)
            $display("PASS: NMI ISR ran (mem[0x0002]=0xC5)");
        else
            $display("FAIL: NMI ISR did not run (mem[0x0002]=0x%02X, expected 0xC5)", mem[2]);

        if (RegData[111:96] < 16'hE300 || RegData[111:96] > 16'hE305)
            $display("PASS: PC=0x%04X (not stuck in ISR 0xE300-0xE305)", RegData[111:96]);
        else
            $display("FAIL: PC=0x%04X (stuck in ISR?)", RegData[111:96]);

        if (mem[2] == 8'hC5 && (RegData[111:96] < 16'hE300 || RegData[111:96] > 16'hE305))
            $display("NMI/RTI test PASS: stacked, serviced, unstacked, resumed.");
        else
            $display("NMI/RTI test FAIL.");
        $finish;
    end
endmodule
