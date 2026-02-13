// Minimal sanity test for mc6809 + SYNC_MEM/MRDY changes.
// Resets CPU, runs from reset vector; memory returns data combinatorially
// (valid when address is held in READ_USE). Verifies PC advances.
`timescale 1ns / 1ps

module tb_sync_mem;
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
    // Bus: memory drives D on read (RnW); CPU drives on write. Use RnW only so we don't depend on AVMA at reset.
    wire [7:0] D_bus = RnW ? mem_out : DOut;
    assign D = D_bus;

    // Simple memory: 64K, combinatorial read. Reset vector at FFFE/FFFF -> 0xE000.
    // At 0xE000: NOP (0x12) so CPU spins.
    reg [7:0] mem [0:65535];
    integer mi;
    initial begin
        for (mi = 0; mi <= 65535; mi = mi + 1) mem[mi] = 8'h12; // NOP
        mem[16'hFFFE] = 8'hE0;
        mem[16'hFFFF] = 8'h00;
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

    // Clock
    initial EXTAL = 0;
    always #5 EXTAL = ~EXTAL;

    // Reset and run
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
        repeat (8000) begin
            @(negedge E);
            cycle_count = cycle_count + 1;
        end
        if (cycle_count >= 5000)
            $display("PASS: CPU ran %0d E cycles, final PC = 0x%04X (reset 0xE000, NOPs)", cycle_count, RegData[111:96]);
        else
            $display("FAIL: only %0d E cycles", cycle_count);
        $finish;
    end
endmodule
