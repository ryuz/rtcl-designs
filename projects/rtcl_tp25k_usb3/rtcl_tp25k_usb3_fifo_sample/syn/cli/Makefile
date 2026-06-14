


DEVICE_PART_NUMBER=GW5A-LV25MG121NC1/I0
DEVICE_NAME=GW5A-25A

TOP_MODULE = rtcl_tp25k_usb3_fifo_sample
OUTPUT_BASE_NAME = $(TOP_MODULE)

FS_FILE = impl/pnr/$(OUTPUT_BASE_NAME).fs

JELLY_DIR = ../../../../../jelly
PRJ_DIR = ../..
SHARED_DIR = ../../../../shared
CONSTRAIN_DIR = ../../constrain

# Verilog Source Files
VLOG_SOURCES  = $(PRJ_DIR)/rtl/rtcl_tp25k_usb3_fifo_sample.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/ft601_mode245_transceiver.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/fifo32_cmd_axi4l.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_reset_async.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_stream_fifo.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_stream_fifo_sync.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_stream_fifo_async.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_fifo_sync.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_fifo_async.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_fifo_fwft_read.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_ram_simple_dualport.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/bus/jelly3_axi4l_if.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/primitive/jelly3_cdc_gray.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/primitive/jelly3_cdc_array_single.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/peripheral/jelly3_i2c.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v1/peripheral/jelly_i2c_core.v

# SDC File
SDC_SOURCES = $(CONSTRAIN_DIR)/rtcl_tp25k_usb3_fifo_sample.sdc

# CST File
CST_SOURCES = $(CONSTRAIN_DIR)/rtcl_tp25k_usb3_fifo_sample.cst

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
