
APP_NAME   = kv260_rtcl_p3s7_flash_rom
ACCEL_NAME = kv260_rtcl_p3s7_flash_rom

ELF_NAME   = $(APP_NAME)
DTBO_FILE  = ../$(ACCEL_NAME).dtbo
BIT_FILE   = ../$(ACCEL_NAME).bit
BIN_FILE   = $(BIT_FILE).bin

TARGET_ARCH = aarch64-unknown-linux-gnu

KV260_SERVER_ADDRESS ?= 127.0.0.1:8051
KV260_SSH_ADDRESS    ?= kria


.PHONY: all
all: build

.PHONY: build
build:
	cargo build --release

.PHONY: clean
clean:
	cargo clean

.PHONY: load
load:
	make -C ..
	jelly-fpga-loader unload --ip $(KV260_SERVER_ADDRESS)
	jelly-fpga-loader register-accel $(ACCEL_NAME) $(DTBO_FILE) $(BIN_FILE) --ip $(KV260_SERVER_ADDRESS)
	jelly-fpga-loader load $(ACCEL_NAME) --ip $(KV260_SERVER_ADDRESS)

.PHONY: cross_build
cross_build:
	cross build --target=$(TARGET_ARCH) --release

.PHONY: remote_run
remote_run: cross_build load
	scp target/$(TARGET_ARCH)/release/$(ELF_NAME) $(KV260_SSH_ADDRESS):/tmp/
	ssh -Y -t $(KV260_SSH_ADDRESS) /tmp/$(ELF_NAME) $(RUN_OPT)

.PHONY: remote_update
remote_update: cross_build load
	make -C ../../../../rtcl_p3s7_mipi/rtcl_p3s7_mipi/syn/tcl
	scp target/$(TARGET_ARCH)/release/$(ELF_NAME) $(KV260_SSH_ADDRESS):/tmp/
	scp ../../../../rtcl_p3s7_mipi/rtcl_p3s7_mipi/syn/tcl/rtcl_p3s7_mipi_tcl.runs/impl_1/rtcl_p3s7_mipi.bin $(KV260_SSH_ADDRESS):/tmp/
	ssh -Y -t $(KV260_SSH_ADDRESS) /tmp/$(ELF_NAME) /tmp/rtcl_p3s7_mipi.bin -w -v
