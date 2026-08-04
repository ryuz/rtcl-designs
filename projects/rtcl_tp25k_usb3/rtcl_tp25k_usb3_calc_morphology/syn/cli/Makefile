


DEVICE_PART_NUMBER=GW5A-LV25MG121NC1/I0
DEVICE_NAME=GW5A-25A

TOP_MODULE = rtcl_tp25k_usb3_calc_morphology
OUTPUT_BASE_NAME = $(TOP_MODULE)

FS_FILE = impl/pnr/$(OUTPUT_BASE_NAME).fs

JELLY_DIR = ../../../../../jelly
PRJ_DIR = ../..
SHARED_DIR = ../../../../shared
CONSTRAIN_DIR = ../../constrain

# Verilog Source Files
VLOG_SOURCES  = $(PRJ_DIR)/rtl/rtcl_tp25k_usb3_calc_morphology.sv
VLOG_SOURCES += $(PRJ_DIR)/rtl/image_processing.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/ft601_multi_ch_mode.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/ft601_multi_ch_mode_transceiver.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/fifo32_cmd_axi4l.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/fifo32_cmd_arbiter.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/fifo32_cmd_axi4s_rx.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/fifo32_cmd_axi4s_tx.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/gowin_dphy_lane2_to_fifo32.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/frame_controller.sv
VLOG_SOURCES += $(SHARED_DIR)/rtl/fifo32_cmd_axi4s_checker.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_reset_async.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_reset_sync.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_stream_fifo.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_stream_fifo_sync.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_stream_fifo_async.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_fifo_sync.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_fifo_async.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_fifo_fwft_read.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_ram_simple_dualport.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_pulse_async.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_data_async.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_histry_buffer_mem.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_histry_buffer_mem_sdp.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_stream_delay.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_data_delay.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/library/jelly3_skid_buffer.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_mat_if.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_axi4s_mat.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_axi4s_to_mat.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_mat_to_axi4s.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_mat_delay.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_mat_buf_blk.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_mat_buf_row.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_mat_buf_col.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_img_morphology_filter.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_img_morphology_filter_core.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/image/jelly3_img_morphology_filter_calc.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/bus/jelly3_axi4l_if.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/bus/jelly3_axi4s_if.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/bus/jelly3_axi4l_addr_decoder.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/primitive/jelly3_cdc_gray.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/primitive/jelly3_cdc_array_single.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/primitive/jelly3_cdc_single.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/primitive/jelly3_shift_register.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/misc/jelly3_axi4s_debug_monitor.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/peripheral/jelly3_i2c.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v3/peripheral/jelly3_system_control.sv
VLOG_SOURCES += $(JELLY_DIR)/rtl/v1/peripheral/jelly_i2c_core.v
VLOG_SOURCES += $(JELLY_DIR)/rtl/v1/library/jelly_param_update_master.v
VLOG_SOURCES += $(JELLY_DIR)/rtl/v1/library/jelly_param_update_slave.v
VLOG_SOURCES += $(PRJ_DIR)/ip/pll_init.v
VLOG_SOURCES += $(PRJ_DIR)/ip/gowin_pll/gowin_pll.v
VLOG_SOURCES += $(PRJ_DIR)/ip/gowin_pll/gowin_pll_mod.v
VLOG_SOURCES += $(PRJ_DIR)/ip/gowin_pll/gowin_pll_ft601.v
VLOG_SOURCES += $(PRJ_DIR)/ip/gowin_pll/gowin_pll_ft601_mod.v

# SDC File
SDC_SOURCES = $(CONSTRAIN_DIR)/rtcl_tp25k_usb3_calc_morphology.sdc

# CST File
CST_SOURCES = $(CONSTRAIN_DIR)/rtcl_tp25k_usb3_calc_morphology.cst

# for tcl script
export DEVICE_PART_NUMBER
export DEVICE_NAME
export PLACE_OPTION
export ROUTE_OPTION
export TOP_MODULE
export OUTPUT_BASE_NAME
export VLOG_SOURCES
export SDC_SOURCES
export CST_SOURCES
export USE_CPU_AS_GPIO=1
export USE_I2C_AS_GPIO=1
export USE_DONE_AS_GPIO=1
export USE_READY_AS_GPIO=1
export PLACE_OPTION=1
export ROUTE_OPTION=1
export WSLENV=DEVICE_PART_NUMBER:DEVICE_NAME:PLACE_OPTION:ROUTE_OPTION:TOP_MODULE:OUTPUT_BASE_NAME:VLOG_SOURCES:SDC_SOURCES:CST_SOURCES:USE_CPU_AS_GPIO:USE_I2C_AS_GPIO:USE_DONE_AS_GPIO:USE_READY_AS_GPIO

all: $(FS_FILE)

$(FS_FILE): $(VLOG_SOURCES) $(SDC_SOURCES) $(CST_SOURCES)
	gw_sh $(JELLY_DIR)/scripts/gowin_build.tcl

clean:
	rm -fr impl


run: $(FS_FILE)
	openFPGALoader -c digilent_hs2 $(FS_FILE)

rom_write:
	openFPGALoader -c digilent_hs2 -f $(FS_FILE)


run_wsl: $(FS_FILE)
	programmer_cli --device GW5A-25B --run 2 --fsFile `wslpath -w $(FS_FILE)` $(PROGRAMMER_CLI_OPTIONS)

rom_write_wsl: $(FS_FILE)
	programmer_cli --device GW5A-25B --run 54 --fsFile `wslpath -w $(FS_FILE)` $(PROGRAMMER_CLI_OPTIONS)
