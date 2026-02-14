# Refactor Plan: Four-Phase E/Q, One-Cycle Reads

The point of this refactor is to get the part closer to its silicon rendition described in the programmers manual (https://www.maddes.net/m6809pm/sections.htm), particularly as it relates to efficiently reading from synchronous memories, which is very relevant to using FPGA BRAM, while simultaneously making the part more friendly to single clock domains, meaning that E and Q rise and fall clock enable strobes should be introduced along with a master clock (that would presumably drive the whole FPGA fabric). Shims can abstract that away (as some currently do), but the internal part (mc6809i) takes those strobes as inputs. This plan is designed to be incremental and test-gated so there is no big-bang validation at the end.

---

## Principles

- E/Q (rise and fall), and master clock are **inputs** to mc6809i.v (the core).
- One logical change per phase; tests must pass after each phase before moving on.
- Roll out one-cycle reads incrementally, then MRDY stretch in the driver, then cleanup.

---

## Wrapper / module roles

- **mc6809.v (XTAL-driven):** This is the crystal-driven top-level. It takes **EXTAL** (and XTAL) as the only clock input. **E and Q are derived inside mc6809.v** from the crystal (e.g. by dividing EXTAL into four phases); they are **outputs** of the wrapper and **inputs** to the core. The core is clocked by CLK_ROOT (= EXTAL) and receives E, Q, and MRDY. Today the wrapper **does not** use MRDY: it simply divides the crystal into four fixed phases to generate E and Q. Phase 4 adds **MRDY-based stretching** to this driver: when MRDY=0, the phase that drives E high / Q low is extended (in quarter-cycle steps) so that E and Q are held in that state until MRDY returns high or the manual’s limit is reached.

- **mc6809e.v (external E/Q):** This wrapper takes **CLK_ROOT, E, and Q as inputs** (no crystal). The board or FPGA supplies the master clock and E/Q; the core just runs from them. MRDY is tied high. No E/Q generation or stretching in this shim.

---

## Phase 0: Baseline and harness

**Goal:** Lock current behavior and make regression a single command.

- Run a full test suite with reasonable coverage across a sampling of important instructions (instruction categories); record that everything passes (optionally cycle counts or a short trace).
- Add or use a single Make/test script that runs the suite and exits 0/1. Note that a Makefile script already exists.
- **Gate:** Full suite passes; baseline documented.
- Baseline coverage and added tests are documented in **documentation/phase0_baseline.md** (read-path vs refactor touch points; extended and indexed load tests added to fill EA-read gaps).

---

## Phase 1: Introduce master clock and change E/Q to strobes (behavior unchanged)

**Goal:** Core is clocked by the master clock and uses E/Q (strobes and/or levels) only to decide *when* to act; effective behavior matches current “negedge E / negedge Q” semantics. Rename E and Q to CE_x_FALL and add CE_x_RISE signals.

- In **mc6809i**:
  - Introduce **master clock** (call it CLK_ROOT) as the single clock for state and data registers (e.g. `always @(posedge CLK_ROOT)`).
  - Replace `always @(negedge E)` and `always @(negedge Q)` with logic that updates state (and samples interrupts) only when the **appropriate strobe** is true (e.g. E_fall) or when E/Q levels cross in the right direction. Same “advance on E fall” and “sample on Q fall” as today.
- Ensure all state and read-completion timing is unchanged (same number of advances per E period).
- Rise signals will go unused at this time.
- **Gate:** Full test suite passes; optional check that cycle counts or a short trace match Phase 0.

---

## Phase 2: One read path in one cycle (pilot)

**Goal:** Prove one-cycle read using “address phase” vs “data phase” within the same E period.

- Use **E/Q strobes (and levels if required to be added...I prefer not if possible)** to know “we’re in address phase” (e.g. Q high or Q_rise) vs “we’re in data phase” (e.g. E_fall).
- Refactor **one** path (e.g. first-byte instruction fetch): issue address on the address phase, latch D and advance on the data phase of the **same** E cycle. All other reads stay on the current two-cycle READ_ISSUE → READ_USE.
- **Gate:** sync_mem and fetch-heavy tests pass; one or two others still pass to confirm no collateral damage.

---

## Phase 3: Roll out one-cycle reads to all read paths

**Goal:** Every read uses one cycle (issue on one phase (Q rise), use on the next within same E period (at E fall)); remove redundant READ_USE states.

- Apply the same pattern to all read paths (fetch, immediates, stack pull, vectors, RTS, etc.). After each path or small batch, run the tests that hit it.
- **Gate:** Full test suite passes.

**Done:** One-cycle applied to RESET0/RESET2, FETCH_I1V2, FETCH_I2, RTS_HI/LO, PUL_ACTION, IRQ_VECTOR_HI/LO. For SYNC_MEM, **16IMM_LO** remains two-cycle (16IMM_LO → 16IMM_LO_READ_USE) so LDD #imm16 and indexed tests pass; other READ_USE states are no longer entered. Full suite (15 tests) passes. Phase 5 can remove dead READ_USE blocks and optionally convert 16IMM_LO to one-cycle if desired.

---

## Phase 4: MRDY as clock stretch (E high, Q low) in mc6809.v

**Goal:** The **XTAL-driven wrapper (mc6809.v)** derives E and Q from the crystal and **stretches** the “E high, Q low” phase when MRDY=0 (quarter-cycle steps per the manual). The core (mc6809i) still only sees E, Q, and MRDY as inputs; it does not generate E/Q.

- **Current state:** mc6809.v divides EXTAL into four fixed phases (2’b00 → 01 → 10 → 11) and drives E/Q from that divider. It does **not** use MRDY; E and Q never stretch.
- **Phase 4 change:** In **mc6809.v**, the logic that derives E and Q from EXTAL must take **MRDY** as an input. When MRDY=0 during the phase where E is high and Q is low, the divider (or phase generator) must **hold** E and Q in that state for additional quarter-cycle steps (up to the manual’s limit), instead of advancing. When MRDY returns to 1 (or the limit is reached), the phase sequence resumes. Thus the core sees E and Q as inputs that are stretched by the wrapper when memory is not ready.
- Core may keep internal “don’t complete read until MRDY=1” as a safety net; primary behavior is driven by the stretched E/Q from the wrapper.
- **Gate:** sim-mrdy and sim-rti-mrdy pass; optionally one test that holds MRDY low for N quarter cycles.

**Done:** In mc6809.v, when phase is 11 (E high, Q low) and MRDY=0, the phase generator holds E and Q in that state for additional negedge-EXTAL cycles (up to MRDY_STRETCH_LIMIT, default 16). When MRDY=1 or the limit is reached, the four-phase sequence resumes. No test harness changes were required; sim-mrdy and sim-rti-mrdy already drive MRDY and pass. Full suite (15 tests) passes.

---

## Phase 5: Cleanup and documentation

**Goal:** No leftover two-cycle read scaffolding; docs describe input clocking and MRDY.

- Remove dead READ_USE states and outdated comments.
- Document: master clock and E/Q (and strobes/levels) as **inputs**; driver responsibility; one-cycle reads (address at Q phase, data at E fall); MRDY stretch in the driver.
- **Gate:** Full suite passes; docs and code aligned.

## Resources

- Tools to elaborate verilog and run sim are located in /home/chuck/oss-cad-suite/environment
- The full test suite can take some time to run. Run with a 5-minute time out so you do not waste time by cutting the test off early.