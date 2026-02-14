# Phase 0: Baseline and Test Coverage

## Regression command

```bash
source /home/chuck/oss-cad-suite/environment && make test
```

Exits 0 if all tests pass, non-zero otherwise.

---

## What the refactor will touch

- **Phase 1:** All state advancement (negedge E / negedge Q → strobes + master clock). Every instruction and interrupt path.
- **Phases 2–3:** All **read** paths that currently use SYNC_MEM two-phase (READ_ISSUE → READ_USE), plus the **data read at effective address** (today combinatorial in `CPUSTATE_ALU_EA`), which will become a one-cycle read:
  - Instruction fetch (I1, I1V2, I2)
  - Reset vector (2 reads)
  - IRQ/FIRQ/NMI vector fetch (2 reads)
  - RTS (2 stack reads)
  - PUL (stack pull, multiple reads)
  - 16-bit immediate (16IMM_LO)
  - **Load from memory at EA** (extended, direct, indexed) — currently no READ_USE; will be added in Phase 3.

---

## Current suite vs read-path coverage

| Test          | Read paths exercised | Instruction categories |
|---------------|------------------------|-------------------------|
| sim           | Fetch I1 (NOP), reset vector | Fetch, reset |
| sim-irq       | Fetch, vector fetch, PUL (full frame), 8-bit imm | IRQ, RTI, LDA #imm, STA direct |
| sim-firq      | Fetch, vector fetch, PUL (short frame) | FIRQ, RTI |
| sim-nmi       | Fetch, vector fetch, PUL (full frame) | NMI, RTI |
| sim-andcc     | Fetch, FETCH_I2 (2nd byte imm) | ANDCC #imm |
| sim-orcc      | Fetch, FETCH_I2 | ORCC #imm |
| sim-ldd       | Fetch, FETCH_I2, 16IMM_LO | LDD #imm16, STD direct |
| sim-pshu      | Fetch, FETCH_I2 (postbyte), PUL (PULS) | PSHS/PULS, LDA #imm, STA direct |
| sim-page2     | Fetch I1, FETCH_I1V2, FETCH_I2, 16IMM (page-2 LDA #imm) | Page-2 prefix, LDA #imm, STA direct |
| sim-mrdy      | All fetch/read paths under MRDY | MRDY stretch |
| sim-rti-mrdy  | Vector fetch, PUL, RTS under MRDY | IRQ, RTI, MRDY |
| sim-irq-async | Same as sim-irq (SYNC_MEM=0) | Async memory path |
| sim-jsr-rts   | Fetch, RTS_HI/LO (stack pull), JSR (push) | JSR extended, RTS, LDA #imm, STA direct |

### Gaps (addressed by new tests)

- **Extended addressing load:** No test loads a byte from an extended address (e.g. `LDA $addr`). The data read at EA (CPUSTATE_ALU_EA) is used by extended, direct, and indexed loads; it is currently combinatorial and will get a one-cycle read in Phase 3. **Filled by:** `tb_lda_ext` (LDA extended, STA direct).
- **Indexed addressing load:** No test loads from an indexed address (e.g. `LDA ,X` or `LDA n,X`). Same EA data-read path. **Filled by:** `tb_lda_idx` (LDX #addr, LDA ,X, STA direct).

We do **not** add tests for: indirect indexed, PC-relative, or every offset type; Phase 3 will refactor the same EA read path for all of them.

---

## Baseline test list (after Phase 0)

1. sim  
2. sim-irq  
3. sim-firq  
4. sim-nmi  
5. sim-andcc  
6. sim-orcc  
7. sim-ldd  
8. sim-pshu  
9. sim-page2  
10. sim-mrdy  
11. sim-rti-mrdy  
12. sim-irq-async  
13. sim-jsr-rts  
14. **sim-lda-ext** (new) — extended load  
15. **sim-lda-idx** (new) — indexed load  

---

## Optional: cycle counts / trace

For Phase 1 gating, you can run a single test (e.g. `make sim-ldd`) and compare cycle counts or a short trace before/after. Not required for Phase 0.
