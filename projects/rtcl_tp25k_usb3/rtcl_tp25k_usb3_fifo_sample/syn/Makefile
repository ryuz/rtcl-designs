


DEVICE_PART_NUMBER=GW5A-LV25MG121NC1/I0
DEVICE_NAME=GW5A-25B

TOP_MODULE = rtcl_tp25k_usb3_fifo_sample
OUTPUT_BASE_NAME = $(TOP_MODULE)

FS_FILE = impl/pnr/$(OUTPUT_BASE_NAME).fs

JELLY_DIR = ../../../../jelly
RTL_DIR = ../rtl
CONSTRAIN_DIR = ../constrain

VLOG_SOURCES = $(RTL_DIR)/rtcl_tp25k_usb3_fifo_sample.sv

CST_SOURCES  = $(CONSTRAIN_DIR)/rtcl_tp25k_usb3_fifo_sample.sdc
CST_SOURCES += $(CONSTRAIN_DIR)/rtcl_tp25k_usb3_fifo_sample.cst

# for tcl script
export DEVICE_PART_NUMBER
export DEVICE_NAME
export DEVICE_VERSION
export TOP_MODULE
export OUTPUT_BASE_NAME
export VLOG_SOURCES
export SDC_SOURCES
export CST_SOURCES
export USE_CPU_AS_GPIO=1
export USE_I2C_AS_GPIO=1
export USE_DONE_AS_GPIO=1
export USE_READY_AS_GPIO=1
export WSLENV=DEVICE_PART_NUMBER:DEVICE_NAME:DEVICE_VERSION:TOP_MODULE:OUTPUT_BASE_NAME:VLOG_SOURCES:SDC_SOURCES:CST_SOURCES:USE_CPU_AS_GPIO:USE_I2C_AS_GPIO:USE_DONE_AS_GPIO:USE_READY_AS_GPIO

all: $(FS_FILE)

$(FS_FILE): $(VLOG_SOURCES) $(CST_SOURCES)
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
