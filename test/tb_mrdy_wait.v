// MRDY=0 wait-state test. Simple program; drive MRDY low for a short time during early fetch. Verify completion.
// When MRDY=0 the shim freezes E, so the test uses a time-based MRDY release. Watchdog kills run if we hang.
`timescale 1ns / 1ps

module tb_mrdy_wait;
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
        mem[16'hE000] = 8'h86;   // LDA #imm
        mem[16'hE001] = 8'h55;
        mem[16'hE002] = 8'h97;   // STA direct
        mem[16'hE003] = 8'h00;   // addr 0x0000
        mem[16'hE004] = 8'h12;   // NOP
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
    parameter WATCHDOG_NS = 10_000_000;  // 10ms; kill only if we're truly stuck (E never resumes after MRDY=0)

    // Watchdog: if we haven't reached 200 E cycles within 10ms, assume hang (e.g. E frozen and never resuming)
    initial begin
        #1;  // let main block start
        #(WATCHDOG_NS);
        if (cycle_count < 200) begin
            $display("WATCHDOG: possible hang at t=%0t (cycle_count=%0d/200, MRDY=%b). E may be frozen when MRDY=0.",
                $time, cycle_count, MRDY);
            $display("  -> Release MRDY so shim can advance E; or increase WATCHDOG_NS.");
            $finish(2);
        end
    end

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

        $display("[MRDY test] Start: wait up to 200 negedge E (watchdog 50us).");

        repeat (200) begin
            @(negedge E);
            cycle_count = cycle_count + 1;

            // Debug: first 15 cycles and every 25th, or when we touch MRDY
            if (cycle_count <= 15 || cycle_count % 25 == 0)
                $display("  E#%0d t=%0t MRDY=%b", cycle_count, $time, MRDY);

            // Hold MRDY low for a short time during early execution, then release (time-based so E can resume)
            if (cycle_count == 8) begin
                $display("  E#8: drive MRDY=0 for 80ns...");
                MRDY = 0;
                #80;   // hold for 80ns; E will not tick during this (shim gates on MRDY)
                MRDY = 1;
                $display("  E#8: MRDY=1 at t=%0t (E should resume).", $time);
            end
        end

        $display("[MRDY test] Done 200 E cycles at t=%0t.", $time);

        if (mem[0] == 8'h55)
            $display("MRDY wait-state test PASS: mem[0x0000]=0x55 (CPU completed despite MRDY=0).");
        else
            $display("MRDY wait-state test FAIL: mem[0]=0x%02X (expected 0x55).", mem[0]);
        $finish(0);
    end
endmodule
