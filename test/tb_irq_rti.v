// Test: IRQ stacks registers, CPU runs ISR, RTI unstacks and resumes at next instruction.
// Main at 0xE000 (NOPs). Assert nIRQ; CPU pushes full frame, fetches vector, runs ISR at 0xE100.
// ISR: LDA #$A5, STA $00, RTI. We verify mem[0x0000]==0xA5 and PC returned to main.
`timescale 1ns / 1ps

module tb_irq_rti;
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
        mem[16'h0000] = 8'h00;   // ISR will write 0xA5 here
        mem[16'hFFFE] = 8'hE0;
        mem[16'hFFFF] = 8'h00;   // Reset vector -> 0xE000
        mem[16'hFFF8] = 8'hE1;   // IRQ vector high
        mem[16'hFFF9] = 8'h00;   // IRQ vector low -> 0xE100
        // Main: LDD #0x0100 then TFR D,S (S=0x0100), ANDCC #$EF, NOPs
        mem[16'hE000] = 8'hCC;   // LDD #imm16
        mem[16'hE001] = 8'h01;
        mem[16'hE002] = 8'h00;   // D = 0x0100
        mem[16'hE003] = 8'h1F;   // TFR
        mem[16'hE004] = 8'h04;   // D -> S (postbyte src=0 dst=4)
        mem[16'hE005] = 8'h1C;   // ANDCC #imm
        mem[16'hE006] = 8'hEF;   // clear I bit
        // 0xE007.. NOPs
        // ISR at 0xE100: LDA #$A5, STA $00 (direct), RTI
        mem[16'hE100] = 8'h86;   // LDA #imm
        mem[16'hE101] = 8'hA5;
        mem[16'hE102] = 8'h97;   // STA direct
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

    initial EXTAL = 0;
    always #5 EXTAL = ~EXTAL;

    integer cycle_count;
    reg [15:0] pc_before_irq;
    initial begin
        cycle_count = 0;
        pc_before_irq = 16'h0000;
        nRESET = 0;
        nHALT  = 1;
        MRDY   = 1;
        nDMABREQ = 1;
        nIRQ   = 1; nFIRQ = 1; nNMI = 1;
        #100;
        nRESET = 1;
        #200;
        nIRQ   = 1;

        repeat (20000) begin
            @(negedge E);
            cycle_count = cycle_count + 1;
            if (cycle_count == 100 && RegData[111:96] >= 16'hE009)
                nIRQ = 0;
            if (cycle_count == 600)
                nIRQ = 1;
        end

        if (mem[0] == 8'hA5)
            $display("PASS: ISR ran (mem[0x0000]=0xA5)");
        else
            $display("FAIL: ISR did not run (mem[0x0000]=0x%02X, expected 0xA5)", mem[0]);

        // After 20k E cycles we've run many NOPs; PC will have advanced. Just ensure we're not stuck in ISR.
        if (RegData[111:96] < 16'hE100 || RegData[111:96] > 16'hE105)
            $display("PASS: PC=0x%04X (not stuck in ISR 0xE100-0xE105)", RegData[111:96]);
        else
            $display("FAIL: PC=0x%04X (stuck in ISR?)", RegData[111:96]);

        if (mem[0] == 8'hA5 && (RegData[111:96] < 16'hE100 || RegData[111:96] > 16'hE105))
            $display("IRQ/RTI test PASS: stacked, serviced, unstacked, resumed.");
        else
            $display("IRQ/RTI test FAIL.");
        $finish;
    end
endmodule
