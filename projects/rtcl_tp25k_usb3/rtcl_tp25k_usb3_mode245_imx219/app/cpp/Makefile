

all: ftdi_test.elf

ftdi_test.elf:
	g++ main.cpp -o ftdi_test.elf -lftd3xx


run: ftdi_test.elf
	./ftdi_test.elf
