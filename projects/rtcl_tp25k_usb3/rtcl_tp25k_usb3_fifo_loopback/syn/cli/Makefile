


DEVICE_PART_NUMBER=GW5A-LV25MG121NC1/I0
DEVICE_NAME=GW5A-25A

TOP_MODULE = rtcl_tp25k_usb3_fifo_loopback
OUTPUT_BASE_NAME = $(TOP_MODULE)

FS_FILE = impl/pnr/$(OUTPUT_BASE_NAME).fs

JELLY_DIR = ../../../../../jelly
RTL_DIR = ../../rtl
CONSTRAIN_DIR = ../../constrain

# Verilog Source Files
VLOG_SOURCES  = $(RTL_DIR)/rtcl_tp25k_usb3_fifo_loopback.sv
VLOG_SOURCES += $(RTL_DIR)/ft601_mode245_if.sv
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

all: $(FS_FILE)

$(FS_FILE): $(VLOG_SOURCES) $(SDC_SOURCES) $(CST_SOURCES)
	gw_sh $(JELLY_DIR)/scripts/gowin_build.tcl

clean:
	rm -fr impl

run: $(FS_FILE)
	openFPGALoader -c digilent_hs2 $(FS_FILE)

run2:
	programmer_cli --device GW5A-25B --run 2 --fsFile $(TARGET).fs --location `programmer_cli --scan-cable | grep -oP 'USB location:\K\d+'`


rom_write:
#	openFPGALoader -c digilent_hs2 -b tangprimer25k -f $(FS_FILE)
	openFPGALoader -c digilent_hs2 -f $(FS_FILE)
