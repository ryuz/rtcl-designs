


DEVICE_PART_NUMBER=GW5A-LV25MG121NC1/I0
DEVICE_NAME=GW5A-25A

TOP_MODULE = rtcl_tp25k_usb3_fifo_loopback
OUTPUT_BASE_NAME = $(TOP_MODULE)

FS_FILE = impl/pnr/$(OUTPUT_BASE_NAME).fs

JELLY_DIR = ../../../../../jelly
PRJ_DIR = ../..
SHARED_DIR = ../../../../shared
CONSTRAIN_DIR = ../../constrain

# Verilog Source Files
VLOG_SOURCES  = $(PRJ_DIR)/rtl/rtcl_tp25k_usb3_fifo_loopback.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/ft601_mode245_transceiver.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_reset_async.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_stream_fifo.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_stream_fifo_sync.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_fifo_sync.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_fifo_fwft_read.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_ram_simple_dualport.sv

# SDC File
SDC_SOURCES = $(CONSTRAIN_DIR)/rtcl_tp25k_usb3_fifo_loopback.sdc

# CST File
CST_SOURCES = $(CONSTRAIN_DIR)/rtcl_tp25k_usb3_fifo_loopback.cst

# for tcl script
export DEVICE_PART_NUMBER
export DEVICE_NAME
export TOP_MODULE
export OUTPUT_BASE_NAME
export VLOG_SOURCES
export SDC_SOURCES
export CST_SOURCES
export USE_CPU_AS_GPIO=1
export USE_I2C_AS_GPIO=1
export USE_DONE_AS_GPIO=1
export USE_READY_AS_GPIO=1
export WSLENV=DEVICE_PART_NUMBER:DEVICE_NAME:TOP_MODULE:OUTPUT_BASE_NAME:VLOG_SOURCES:SDC_SOURCES:CST_SOURCES:USE_CPU_AS_GPIO:USE_I2C_AS_GPIO:USE_DONE_AS_GPIO:USE_READY_AS_GPIO


.PHONY: all
all: build

.PHONY: build
build: $(FS_FILE) timing_check

.PHONY: clean
clean:
	rm -fr impl

$(FS_FILE): $(VLOG_SOURCES) $(SDC_SOURCES) $(CST_SOURCES)
	gw_sh $(JELLY_DIR)/scripts/gowin_build.tcl

.PHONY: timing_check
timing_check:
	-@python3 $(JELLY_DIR)/scripts/gowin_check_timing_report.py impl/pnr/$(TOP_MODULE)_tr_content.html


# openFPGALoader (Digilent HS2) で書き込み
.PHONY: run
run: build
	openFPGALoader -c digilent_hs2 $(FS_FILE)

.PHONY: rom_write
rom_write: build
	openFPGALoader -c digilent_hs2 -f $(FS_FILE)


# WSL から Windows 版 programmer を使う場合
# programmer_cli --scan-cable
# で PROGRAMMER_CLI_OPTIONS に --location を指定しておく
.PHONY: run_wsl
run_wsl: build
	programmer_cli --device GW5A-25B --run 2 --fsFile `wslpath -w $(FS_FILE)` $(PROGRAMMER_CLI_OPTIONS)

.PHONY: rom_write_wsl
rom_write_wsl: build
	programmer_cli --device GW5A-25B --run 54 --fsFile `wslpath -w $(FS_FILE)` $(PROGRAMMER_CLI_OPTIONS)
