# Refactor Plan: Four-Phase E/Q, One-Cycle Reads

The point of this refactor is to get the part closer to its silicon rendition described in the programmers manual (https://www.maddes.net/m6809pm/sections.htm), particularaly as it relates to effeciently reading from synchrnous memories, which is very relevant to using FPGA BRAM, while simultaneously making the part more friendly to single clock domains, meaning that E and Q rise and fall clock enable strobes should be introduced along with a master clock (that would presumably drive the whole FPGA fabric). Shims can abstract that away (as some currently do), but the internal part will take those strobes as inputs. This plan is designed to be incremental and test-gated so there is no big-bang validation at the end.

---

## Principles

- E/Q (rise and fall), and master clock are **inputs** to the mc6809i.v
- One logical change per phase; tests must pass after each phase before moving on.
- Roll out one-cycle reads incrementally, then MRDY, then cleanup.

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

**Goal:** Every read uses one cycle (issue on one phase, use on the next within same E period); remove redundant READ_USE states.

- Apply the same pattern to all read paths (fetch, immediates, stack pull, vectors, RTS, etc.). After each path or small batch, run the tests that hit it.
- **Gate:** Full test suite passes.

---

## Phase 4: MRDY as clock stretch (E high, Q low)

**Goal:** MRDY extends the “E high, Q low” phase in quarter-cycle steps per the manual; DUT still only sees E/Q (and strobes) as inputs.

- **Outside the DUT:** The **clock/strobe driver** that generates E and Q takes **MRDY** as an input. When MRDY=0, it stretches the E-high / Q-low phase (in quarter-cycle steps, up to the manual’s limit). E and Q remain inputs to the DUT; the driver holds them in that phase longer when MRDY is low.
- Core may keep internal “don’t complete READ_USE until MRDY=1” as a safety net; primary behavior is driven by the stretched E/Q.
- **Gate:** sim-mrdy and sim-rti-mrdy pass; optionally one test that holds MRDY low for N quarter cycles.

---

## Phase 5: Cleanup and documentation

**Goal:** No leftover two-cycle read scaffolding; docs describe input clocking and MRDY.

- Remove dead READ_USE states and outdated comments.
- Document: master clock and E/Q (and strobes/levels) as **inputs**; driver responsibility; one-cycle reads (address at Q phase, data at E fall); MRDY stretch in the driver.
- **Gate:** Full suite passes; docs and code aligned.

## Resources

- Tools to elaborate verilog and run sim are located in /home/chuck/oss-cad-suite/environment