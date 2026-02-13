# Sanity sim for mc6809 + SYNC_MEM/MRDY. Source oss-cad-suite first, e.g.:
#   source /home/chuck/oss-cad-suite/environment
# Testbenches live in test/; build artifacts go to build/ (exclude from git).
BUILD_DIR = build

SIM_VVP = $(BUILD_DIR)/tb_sync_mem.vvp
IRQ_VVP = $(BUILD_DIR)/tb_irq_rti.vvp
FIRQ_VVP = $(BUILD_DIR)/tb_firq_rti.vvp
NMI_VVP = $(BUILD_DIR)/tb_nmi_rti.vvp
ANDCC_VVP = $(BUILD_DIR)/tb_andcc_sync.vvp
ORCC_VVP = $(BUILD_DIR)/tb_orcc_sync.vvp
LDD_VVP = $(BUILD_DIR)/tb_ldd_imm.vvp
PSHU_VVP = $(BUILD_DIR)/tb_pshu_pulu.vvp
PAGE2_VVP = $(BUILD_DIR)/tb_page2.vvp
MRDY_WAIT_VVP = $(BUILD_DIR)/tb_mrdy_wait.vvp
RTI_MRDY_VVP = $(BUILD_DIR)/tb_rti_mrdy.vvp
IRQ_ASYNC_VVP = $(BUILD_DIR)/tb_irq_async.vvp
JSR_RTS_VVP = $(BUILD_DIR)/tb_jsr_rts.vvp

CORE = mc6809i.v mc6809.v
SIM_SRC = $(CORE) test/tb_sync_mem.v
IRQ_SRC = $(CORE) test/tb_irq_rti.v
FIRQ_SRC = $(CORE) test/tb_firq_rti.v
NMI_SRC = $(CORE) test/tb_nmi_rti.v
ANDCC_SRC = $(CORE) test/tb_andcc_sync.v
ORCC_SRC = $(CORE) test/tb_orcc_sync.v
LDD_SRC = $(CORE) test/tb_ldd_imm.v
PSHU_SRC = $(CORE) test/tb_pshu_pulu.v
PAGE2_SRC = $(CORE) test/tb_page2.v
MRDY_WAIT_SRC = $(CORE) test/tb_mrdy_wait.v
RTI_MRDY_SRC = $(CORE) test/tb_rti_mrdy.v
IRQ_ASYNC_SRC = $(CORE) test/tb_irq_async.v
JSR_RTS_SRC = $(CORE) test/tb_jsr_rts.v

ALL_VVP = $(SIM_VVP) $(IRQ_VVP) $(FIRQ_VVP) $(NMI_VVP) $(ANDCC_VVP) $(ORCC_VVP) $(LDD_VVP) $(PSHU_VVP) $(PAGE2_VVP) $(MRDY_WAIT_VVP) $(RTI_MRDY_VVP) $(IRQ_ASYNC_VVP) $(JSR_RTS_VVP)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

.PHONY: sim sim-irq sim-firq sim-nmi sim-andcc sim-orcc sim-ldd sim-pshu sim-page2 sim-mrdy sim-rti-mrdy sim-irq-async sim-jsr-rts test
sim: $(SIM_VVP)
	vvp $(SIM_VVP)
sim-irq: $(IRQ_VVP)
	vvp $(IRQ_VVP)
sim-firq: $(FIRQ_VVP)
	vvp $(FIRQ_VVP)
sim-nmi: $(NMI_VVP)
	vvp $(NMI_VVP)
sim-andcc: $(ANDCC_VVP)
	vvp $(ANDCC_VVP)
sim-orcc: $(ORCC_VVP)
	vvp $(ORCC_VVP)
sim-ldd: $(LDD_VVP)
	vvp $(LDD_VVP)
sim-pshu: $(PSHU_VVP)
	vvp $(PSHU_VVP)
sim-page2: $(PAGE2_VVP)
	vvp $(PAGE2_VVP)
sim-mrdy: $(MRDY_WAIT_VVP)
	vvp $(MRDY_WAIT_VVP)
sim-rti-mrdy: $(RTI_MRDY_VVP)
	vvp $(RTI_MRDY_VVP)
sim-irq-async: $(IRQ_ASYNC_VVP)
	vvp $(IRQ_ASYNC_VVP)
sim-jsr-rts: $(JSR_RTS_VVP)
	vvp $(JSR_RTS_VVP)

test: $(ALL_VVP)
	@echo "=== sim ===" && vvp $(SIM_VVP)
	@echo "=== sim-irq ===" && vvp $(IRQ_VVP)
	@echo "=== sim-firq ===" && vvp $(FIRQ_VVP)
	@echo "=== sim-nmi ===" && vvp $(NMI_VVP)
	@echo "=== sim-andcc ===" && vvp $(ANDCC_VVP)
	@echo "=== sim-orcc ===" && vvp $(ORCC_VVP)
	@echo "=== sim-ldd ===" && vvp $(LDD_VVP)
	@echo "=== sim-pshu ===" && vvp $(PSHU_VVP)
	@echo "=== sim-page2 ===" && vvp $(PAGE2_VVP)
	@echo "=== sim-mrdy ===" && vvp $(MRDY_WAIT_VVP)
	@echo "=== sim-rti-mrdy ===" && vvp $(RTI_MRDY_VVP)
	@echo "=== sim-irq-async ===" && vvp $(IRQ_ASYNC_VVP)
	@echo "=== sim-jsr-rts ===" && vvp $(JSR_RTS_VVP)
	@echo "=== All tests passed ==="

$(SIM_VVP): $(SIM_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(SIM_SRC)
$(IRQ_VVP): $(IRQ_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(IRQ_SRC)
$(FIRQ_VVP): $(FIRQ_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(FIRQ_SRC)
$(NMI_VVP): $(NMI_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(NMI_SRC)
$(ANDCC_VVP): $(ANDCC_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(ANDCC_SRC)
$(ORCC_VVP): $(ORCC_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(ORCC_SRC)
$(LDD_VVP): $(LDD_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(LDD_SRC)
$(PSHU_VVP): $(PSHU_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(PSHU_SRC)
$(PAGE2_VVP): $(PAGE2_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(PAGE2_SRC)
$(MRDY_WAIT_VVP): $(MRDY_WAIT_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(MRDY_WAIT_SRC)
$(RTI_MRDY_VVP): $(RTI_MRDY_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(RTI_MRDY_SRC)
$(IRQ_ASYNC_VVP): $(IRQ_ASYNC_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(IRQ_ASYNC_SRC)
$(JSR_RTS_VVP): $(JSR_RTS_SRC) | $(BUILD_DIR)
	iverilog -o $@ $(JSR_RTS_SRC)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
