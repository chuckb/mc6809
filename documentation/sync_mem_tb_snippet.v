// Snippet: sync (registered-read) BRAM-style RAM + MRDY generation for use with mc6809/mc6809i
// Updated to match: "BRAM clocked by 12MHz root; E/Q are phase markers; MRDY gates CPU progress."
//
// Key idea:
// - Clock RAM on the 12MHz root clock (or whatever your system root is), NOT on E/Q edges.
// - When the CPU issues a READ (AVMA && RnW), latch the address into the RAM port.
// - One root clock later, RAM dout is valid. Latch it into a holding register that drives CPU D.
// - Keep MRDY low while a read is pending, then raise MRDY once D is valid.
// - Writes are committed synchronously on the root clock when AVMA && !RnW.
//
// This makes synchronous BRAM "look" like async to the CPU, using MRDY + the core's SYNC_MEM pipeline, 
// without insane fast clocking, across domains.
// No derived clocks needed for RAM. No negedge-E RAM clocking.
//
// Assumptions:
// - The mc6809 shim/core provides: ADDR, RnW, AVMA, DOut, and consumes D.
// - D should never be Z; drive a defined value (e.g. 8'hFF) before first valid read.
// - If you have external chip selects, gate 'ce' accordingly; here we assume always-selected RAM.
//

`timescale 1ns / 1ps

// Simple sync RAM model: registered-read (1-cycle latency) and synchronous write.
module sync_ram_1c #(
    parameter AW = 16,
    parameter DEPTH = 65536
) (
    input  wire         clk,    // root clock (e.g., 12MHz)
    input  wire         ce,
    input  wire         we,
    input  wire [AW-1:0] addr,
    input  wire [7:0]    din,
    output reg  [7:0]    dout
);
    reg [7:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (ce) begin
            if (we) begin
                mem[addr] <= din;
                // dout can be don't-care on write; keep last value by default
            end else begin
                dout <= mem[addr]; // registered read: valid next clk
            end
        end
    end
endmodule

// Memory adapter that generates MRDY and provides a stable D bus to the CPU.
// This is the piece that aligns a 6809-style bus to 1-cycle-latency synchronous RAM/BRAM.
module mc6809_syncmem_adapter #(
    parameter AW = 16,
    parameter DEPTH = 65536
) (
    input  wire         clk,     // root clock (e.g., 12MHz)
    input  wire         reset_n,

    // From CPU/core/shim
    input  wire [AW-1:0] cpu_addr,
    input  wire         cpu_rnw,
    input  wire         cpu_avma,
    input  wire [7:0]   cpu_dout,

    // To CPU/core/shim
    output reg  [7:0]   cpu_d,    // ALWAYS driven (no Z)
    output reg          mrdy       // active-high "ready" (stall when low)
);

    // --- RAM port signals ---
    reg              ram_ce;
    reg              ram_we;
    reg  [AW-1:0]     ram_addr;
    reg  [7:0]        ram_din;
    wire [7:0]        ram_dout;

    // 1-cycle latency RAM
    sync_ram_1c #(.AW(AW), .DEPTH(DEPTH)) u_ram (
        .clk (clk),
        .ce  (ram_ce),
        .we  (ram_we),
        .addr(ram_addr),
        .din (ram_din),
        .dout(ram_dout)
    );

    // --- Read pipeline / MRDY control ---
    reg rd_pending;

    // Optional: detect new read request to avoid re-issuing while stalled
    // (In a proper MRDY-stretched system, cpu_addr/control shouldn't change while mrdy=0.)
    wire rd_req = cpu_avma &&  cpu_rnw;
    wire wr_req = cpu_avma && !cpu_rnw;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            ram_ce     <= 1'b0;
            ram_we     <= 1'b0;
            ram_addr   <= {AW{1'b0}};
            ram_din    <= 8'h00;

            cpu_d      <= 8'hFF;  // open bus default until first valid read
            mrdy       <= 1'b1;
            rd_pending <= 1'b0;
        end else begin
            // Default: no RAM op unless requested this cycle
            ram_ce <= 1'b0;
            ram_we <= 1'b0;

            // Writes: commit immediately on root clock.
            if (wr_req) begin
                ram_ce   <= 1'b1;
                ram_we   <= 1'b1;
                ram_addr <= cpu_addr;
                ram_din  <= cpu_dout;
                // mrdy generally stays high for writes (unless you want to model slow devices)
            end

            // Reads: issue once, then wait one clk for dout, then release MRDY.
            // If already pending, don't issue another read; just complete it.
            if (!rd_pending) begin
                if (rd_req) begin
                    // Issue read to RAM (address captured at this clk edge)
                    ram_ce     <= 1'b1;
                    ram_we     <= 1'b0;
                    ram_addr   <= cpu_addr;

                    // Stall CPU until data is valid
                    rd_pending <= 1'b1;
                    mrdy       <= 1'b0;
                end else begin
                    // No read in progress
                    mrdy <= 1'b1;
                end
            end else begin
                // rd_pending == 1: RAM dout is valid *now* (1 cycle after issue)
                cpu_d      <= ram_dout; // latch stable data for CPU to sample during READ_USE
                rd_pending <= 1'b0;
                mrdy       <= 1'b1;     // release stall; CPU can proceed
            end
        end
    end
endmodule

/*
Minimal wiring idea (conceptual):

- Keep your clock generator producing E/Q for the CPU/shim as before.
- Clock this adapter + BRAM with the same root clock (12MHz).
- Connect CPU bus to adapter:
    adapter.cpu_addr = cpu.ADDR
    adapter.cpu_rnw  = cpu.RnW
    adapter.cpu_avma = cpu.AVMA
    adapter.cpu_dout = cpu.DOut
    cpu.D            = adapter.cpu_d
    cpu.MRDY         = adapter.mrdy   (or route to shim if shim also stretches E/Q)

- If you have memory-mapped IO/devices, decode chip selects:
    ram_ce = (cpu_addr in RAM/ROM range) && cpu_avma;
  and mux cpu_d from the selected device. Do NOT float cpu_d.

Notes:
- This models 1-cycle sync-read memory. For N-cycle memory, keep mrdy low until data valid.
- For dual-port BRAM (video + CPU), use a second port for video reads; keep CPU port as above.
*/
