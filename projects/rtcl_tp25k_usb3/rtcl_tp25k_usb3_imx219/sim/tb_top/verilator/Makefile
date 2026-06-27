# jelly
JELLY_TOP_DIR = ../../../../../../jelly
-include $(JELLY_TOP_DIR)/include/make/def_simulation.inc

# setting
TOP_MODULE = tb_top

SIM_LIB_DIRS += ..
SIM_LIB_DIRS += ../../stub
SIM_LIB_DIRS += ../../../../../shared/rtl

FLAGS  = --binary -j 0
FLAGS += --assert
FLAGS += --trace-fst --trace-params --trace-structs --trace-underscore
FLAGS += -D__VERILATOR__ -D__SIMULATION__
FLAGS += $(addprefix -y ,$(SIM_LIB_DIRS))
FLAGS += -Wno-SIDEEFFECT

SRCS  = ../$(TOP_MODULE).sv
SRCS += ../../../rtl/rtcl_tp25k_usb3_imx219.sv
SRCS += ../../stub/IOBUF.sv
SRCS += ../../stub/gowin_pll.v
SRCS += ../../stub/gowin_mipi_dphy.v

all: build run

.PHONY : build
build: $(SRCS)
	verilator $(FLAGS) --top $(TOP_MODULE) $(SRCS)

.PHONY : clean
clean:
	rm -rf obj_dir

.PHONY : distclean
distclean: clean
	rm -f *.fst *.vcd
	rm -f *.ppm *.pgm
	rm -f axi*.txt
	rm -f coverage.dat
	rm -fr annotated


.PHONY : run
run:
	./obj_dir/V$(TOP_MODULE)

.PHONY : coverage
coverage:
	verilator_coverage --annotate annotated coverage.dat
