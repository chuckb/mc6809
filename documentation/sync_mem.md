You are editing a Verilog 6809 CPU core based on cavnex mc6809i.v plus top-level shims (mc6809.v, mc6809e.v, and mc6809s.v), some that currently “implements MRDY” by only stretching/holding E/Q when MRDY is low.

Goal:
Implement MRDY correctly such that synchronous (registered-read) RAM/ROM works reliably, especially for interrupt vector fetch and RTI stack pulls. The CPU must NOT consume read data (D) in the same microstate/cycle where it first asserts the read address. Instead:
- Q phase (or a “READ_ISSUE” phase): assert/stabilize address and control signals for a read.
- E phase (or a “READ_USE” phase one CPU step later): consume the memory data that is now valid from sync memory.
MRDY must behave like clock stretching / wait-state: when MRDY=0 during a read cycle, the CPU must hold the bus stable and not advance the microstate that consumes data until MRDY returns 1 (or until a data_valid condition is met). Writes can remain synchronous and committed on E-fall as they are.

Constraints:
- Keep the external pin interface compatible (ADDR, D, DOut, RnW, E, Q, AVMA, BA, BS, etc.) as much as possible.
- Prefer minimal surgical changes. Do not redesign the instruction decode. Add a small internal mechanism to pipeline reads and gate state advancement.
- Fix the specific failure points first: instruction fetch, IRQ/FIRQ/NMI vector fetch, stack pull engine (PUL/RTI), and any generic byte-read paths.
- The existing shim that only stretches E/Q is insufficient; implement MRDY at the point where the core transitions from “address valid” to “data consumed”.

Implementation approach (do this):
1) Identify every place in the core where a read is effectively “same-cycle”:
   - FETCH_I1 / instruction fetch: Inst1_nxt assigned from D/MapInstruction in same state that drives addr_nxt=pc.
   - IRQ/FIRQ/NMI vector fetch states: pc_nxt[15:8]=D and pc_nxt[7:0]=D in same states that set addr_nxt to vector addresses.
   - PUL_ACTION and RTI logic: cc_nxt = D[7:0] and decisions based on D (E bit) in the same state.
   - Any other operand/immediate reads that use D directly after setting addr_nxt.

2) Introduce a read pipeline with an explicit latch:
   - Add regs: rd_pending, rd_addr, rd_kind (what the read is for), rd_data (latched input), and optionally rd_dest selector.
   - Add a “read issue” microstate or a per-state two-step mechanism:
     a) READ_ISSUE: drive ADDR/control for the read, set rd_pending=1, do NOT consume D.
     b) READ_USE: when MRDY==1 and after the sync memory has had a cycle, latch D into rd_data and perform the old behavior that used D (Inst1, pc high/low, cc, etc.). Then clear rd_pending and proceed.

3) Tie MRDY to state progression:
   - When rd_pending==1 (or when in READ_USE), if MRDY==0 then hold CPU state, hold address/control stable, do not advance microstate or PC/S/U updates for that read.
   - When MRDY returns 1, complete READ_USE and advance.
   - Ensure E/Q outputs reflect the stretch (they may already, but the critical part is internal data consumption timing).

4) Implement Q/E split semantics:
   - Q phase corresponds to READ_ISSUE; E phase corresponds to READ_USE.
   - If you currently drive E/Q using strobes (CE_*), map READ_ISSUE to happen on one strobe and READ_USE on the next.
   - The address must be stable across the split and across MRDY stretch.

5) Update the top shim (mc6809.v):
   - Do NOT only stretch E/Q. MRDY must be fed into the core and used to stall internal read-completion.
   - If the core doesn’t currently take MRDY, add an input and route it.
   - Keep the shim’s E/Q stretching for observability, but correctness must come from internal stalling + read pipelining.
   - As for the other shims that do not bring out MRDY, tie MRDY high.

6) Make it safe for “always-driven D”:
   - The core should not depend on Z on D; when not reading from memory, treat D as stable input but ignored.
   - The memory system should provide valid data when RD is active; otherwise it can return 0xFF.

7) Prove the fix with targeted tests:
   - IRQ vector fetch: force IRQ, ensure PC loads correct vector with sync memory model (1-cycle read latency).
   - RTI: create an ISR that pushes full frame, modifies regs, then RTI; ensure PC/CC restored.
   - Stack smoke: PSHS/PULS loop and compare values.
   - Add an optional “sync_mem=1” parameter to enable this pipeline if you want to preserve async behavior too.

Deliverables:
- Modified mc6809i.v implementing internal MRDY-aware read pipelining.
- Modified mc6809.v shim to route MRDY and remove any incorrect assumption that stretching E/Q alone makes reads safe.
- Other shims that need MRDY tied high.
- A small sync RAM model (registered read) testbench snippet to demonstrate correctness. When wiring sync memory: clock it from **E** (not Q), using **negedge E** to latch the read address; data is then valid at the next negedge E when the core performs READ_USE.
- Keep changes localized and well-commented (e.g., “READ_ISSUE/READ_USE added to support synchronous memory; MRDY stalls READ_USE completion”).

Focus first on instruction fetch, vector fetch, and PUL_ACTION/RTI since those cause “sporadic stack corruption”. Do not refactor unrelated code. Only add new states/regs and modify the specific read paths that currently consume D same-cycle.

---

**Testing gaps (not covered by current sync-memory test suite):**

- **Page-3 prefix ($11):** Only page-2 ($10) is exercised (sim-page2). Page-3 uses the same FETCH_I1V2 path; add a test if paranoia warrants.
- **Other 16-bit immediates:** LDD #imm16 is tested; LDX/LDY/LDS/LDU #imm16 share the same 16IMM_LO path and are only indirectly covered.
- **Writes:** SYNC_MEM and MRDY apply to reads. STA/STB/etc. are used in tests but no test specifically stresses write timing or write path with sync memory.
