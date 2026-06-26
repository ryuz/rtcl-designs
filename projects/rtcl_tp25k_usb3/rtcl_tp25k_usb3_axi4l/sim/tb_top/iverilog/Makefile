# jelly
JELLY_TOP_DIR = ../../../../../../jelly
-include $(JELLY_TOP_DIR)/include/make/def_simulation.inc

# setting
TOP_MODULE = tb_top

SIM_LIB_DIRS += ..
SIM_LIB_DIRS += ../../stub
SIM_LIB_DIRS += ../../../../../shared/rtl

# Source files (SystemVerilog)
SRCS  = ../tb_top.sv
SRCS += ../tb_main.sv
SRCS += ../../stub/IOBUF.sv
SRCS += ../../../rtl/rtcl_tp25k_usb3_axi4l.sv
SRCS += ../../../../../shared/rtl/ft601_multi_ch_mode.sv
SRCS += ../../../../../shared/rtl/ft601_multi_ch_mode_transceiver.sv
SRCS += ../../../../../shared/rtl/fifo32_cmd_axi4l.sv
SRCS += ../../../../../../jelly/rtl/v3/bus/jelly3_axi4l_if.sv
SRCS += ../../../../../../jelly/rtl/v3/bus/jelly3_axi4s_if.sv
SRCS += ../../../../../../jelly/rtl/v3/bus/jelly3_axi4l_addr_decoder.sv
SRCS += ../../../../../../jelly/rtl/v3/peripheral/jelly3_system_control.sv
SRCS += ../../../../../../jelly/rtl/v3/peripheral/jelly3_i2c.sv
SRCS += ../../../../../../jelly/rtl/v1/peripheral/jelly_i2c_core.v
SRCS += ../../../../../../jelly/rtl/v3/library/jelly3_reset_async.sv
SRCS += ../../../../../../jelly/rtl/v3/library/jelly3_stream_fifo.sv
SRCS += ../../../../../../jelly/rtl/v3/library/jelly3_stream_fifo_sync.sv
SRCS += ../../../../../../jelly/rtl/v3/library/jelly3_stream_fifo_async.sv
SRCS += ../../../../../../jelly/rtl/v3/library/jelly3_fifo_sync.sv
SRCS += ../../../../../../jelly/rtl/v3/library/jelly3_fifo_async.sv
SRCS += ../../../../../../jelly/rtl/v3/library/jelly3_fifo_fwft_read.sv
SRCS += ../../../../../../jelly/rtl/v3/library/jelly3_ram_simple_dualport.sv
SRCS += ../../../../../../jelly/rtl/v3/primitive/jelly3_cdc_gray.sv
SRCS += ../../../../../../jelly/rtl/v3/primitive/jelly3_cdc_array_single.sv

# Output files
OUTPUT_DIR = objs
VVP_FILE   = $(OUTPUT_DIR)/$(TOP_MODULE).vvp

.PHONY : all
all: build run

.PHONY : build
build: $(VVP_FILE)

# Compile Verilog with iverilog
$(VVP_FILE): $(SRCS)
	mkdir -p $(OUTPUT_DIR)
	sv2v --exclude Always --top tb_top $(SRCS) > $(OUTPUT_DIR)/tb_all.sv
	iverilog -o $(VVP_FILE) -s $(TOP_MODULE) -g2012 $(OUTPUT_DIR)/tb_all.sv -D__IVERILOG__

.PHONY : run
run: $(VVP_FILE)
	vvp -n $(VVP_FILE)

.PHONY : clean
clean:
	rm -fr $(OUTPUT_DIR)

.PHONY : distclean
distclean: clean
	rm -f $(TOP_MODULE).vcd

