
BASE_NAME = zcu104_rtcl_p3s7_hs

ELF_NAME   = $(BASE_NAME)
ACCEL_NAME = $(BASE_NAME)
BIT_FILE   = ../$(BASE_NAME).bit
BIN_FILE   = $(BIT_FILE).bin
DTBO_FILE  = ../$(BASE_NAME).dtbo

TARGET_ARCH = aarch64-unknown-linux-gnu

ZCU104_SERVER_ADDRESS ?= 127.0.0.1:8051
ZCU104_SSH_ADDRESS    ?= zcu104


.PHONY: all
all: build

.PHONY: build
build:
	cargo build --release

.PHONY: clean
clean:
	cargo clean

.PHONY: run
run: load
	cargo run --release -- $(RUN_OPT)

.PHONY: load
load:
	make -C ..
	jelly-fpga-loader unload --ip $(ZCU104_SERVER_ADDRESS)
	jelly-fpga-loader register-accel $(ACCEL_NAME) $(DTBO_FILE) $(BIN_FILE) --ip $(ZCU104_SERVER_ADDRESS)
	jelly-fpga-loader load $(ACCEL_NAME) --ip $(ZCU104_SERVER_ADDRESS)

.PHONY: cross_build
cross_build:
	cross build --target=$(TARGET_ARCH) --release

.PHONY: remote_run
remote_run: cross_build load remote_scp remote_exec

.PHONY: remote_run_existing
remote_run_existing : load remote_scp remote_exec

.PHONY: remote_scp
remote_scp:
	scp target/$(TARGET_ARCH)/release/$(ELF_NAME) $(ZCU104_SSH_ADDRESS):/tmp/

.PHONY: remote_exec
remote_exec:
	ssh -Y -t $(ZCU104_SSH_ADDRESS) /tmp/$(ELF_NAME) $(RUN_OPT)
