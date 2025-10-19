
BASE_NAME = kv260_rtcl_p3s7_hs

ACCEL_NAME = $(BASE_NAME)
BIT_FILE   = ../$(BASE_NAME).bit
BIN_FILE   = $(BIT_FILE).bin
DTBO_FILE  = ../$(BASE_NAME).dtbo

KV260_SERVER_ADDRESS ?= 127.0.0.1:8051
KV260_SSH_ADDRESS    ?= kria


.PHONY: all
all: build

.PHONY: build
build:
	cargo build --release

.PHONY: load
load:
	make -C ..
	jelly-fpga-loader unload --ip $(KV260_SERVER_ADDRESS)
	jelly-fpga-loader register-accel $(ACCEL_NAME) $(DTBO_FILE) $(BIN_FILE) --ip $(KV260_SERVER_ADDRESS)
	jelly-fpga-loader load $(ACCEL_NAME) --ip $(KV260_SERVER_ADDRESS)

.PHONY: cross_build
cross_build:
	cross build --target=aarch64-unknown-linux-gnu --release

.PHONY: remote_run
remote_run: cross_build load
	scp target/aarch64-unknown-linux-gnu/release/kv260_rtcl_p3s7_hs $(KV260_BOARD_ADDRESS):/tmp/
	ssh -Y -t $(KV260_BOARD_ADDRESS) /tmp/kv260_rtcl_p3s7_hs

