// IRQ/RTI with SYNC_MEM=0 (async path). Same program as tb_irq_rti; regression test for async.
`timescale 1ns / 1ps

module tb_irq_async;
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
        mem[16'h0000] = 8'h00;
        mem[16'hFFFE] = 8'hE0;
        mem[16'hFFFF] = 8'h00;   // Reset -> 0xE000
        mem[16'hFFF8] = 8'hE1;
        mem[16'hFFF9] = 8'h00;   // IRQ -> 0xE100
        mem[16'hE000] = 8'hCC;   // LDD #0x0100
        mem[16'hE001] = 8'h01;
        mem[16'hE002] = 8'h00;
        mem[16'hE003] = 8'h1F;   // TFR D,S
        mem[16'hE004] = 8'h04;
        mem[16'hE005] = 8'h1C;   // ANDCC #$EF
        mem[16'hE006] = 8'hEF;
        mem[16'hE100] = 8'h86;   // LDA #$A5
        mem[16'hE101] = 8'hA5;
        mem[16'hE102] = 8'h97;   // STA $00
        mem[16'hE103] = 8'h00;
        mem[16'hE104] = 8'h3B;   // RTI
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
    defparam uut.cpucore.SYNC_MEM = 0;

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
                nIRQ = 0;
            if (cycle_count == 600)
                nIRQ = 1;
        end

        if (mem[0] == 8'hA5)
            $display("PASS: ISR ran (mem[0x0000]=0xA5) [async SYNC_MEM=0].");
        else
            $display("FAIL: mem[0x0000]=0x%02X [async].", mem[0]);
        if (RegData[111:96] < 16'hE100 || RegData[111:96] > 16'hE105)
            $display("PASS: PC=0x%04X (not stuck in ISR) [async].", RegData[111:96]);
        else
            $display("FAIL: PC stuck in ISR [async].");
        if (mem[0] == 8'hA5 && (RegData[111:96] < 16'hE100 || RegData[111:96] > 16'hE105))
            $display("IRQ async (SYNC_MEM=0) regression test PASS.");
        else
            $display("IRQ async (SYNC_MEM=0) regression test FAIL.");
        $finish;
    end
endmodule
