
APP_NAME   = zybo_z7_rtcl_p3s7_flash_rom
ACCEL_NAME = zybo_z7_rtcl_p3s7_flash_rom

ELF_NAME   = $(APP_NAME)
DTBO_FILE  = ../$(ACCEL_NAME).dtbo
BIT_FILE   = ../$(ACCEL_NAME).bit
BIN_FILE   = $(BIT_FILE).bin

TARGET_ARCH = arm-unknown-linux-gnueabihf

ZYBO_Z7_SERVER_ADDRESS ?= 127.0.0.1:8051
ZYBO_Z7_SSH_ADDRESS    ?= zybo


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
	-jelly-fpga-loader unload --ip $(ZYBO_Z7_SERVER_ADDRESS)
	jelly-fpga-loader overlay $(DTBO_FILE) --bin $(BIN_FILE) --ip $(ZYBO_Z7_SERVER_ADDRESS)

.PHONY: cross_build
cross_build:
	cross build --target=$(TARGET_ARCH) --release

.PHONY: remote_run
remote_run: cross_build load
	scp target/$(TARGET_ARCH)/release/$(ELF_NAME) $(ZYBO_Z7_SSH_ADDRESS):/tmp/
	ssh -Y -t $(ZYBO_Z7_SSH_ADDRESS) /tmp/$(ELF_NAME) $(RUN_OPT)
