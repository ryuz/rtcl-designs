

.PHONY: all
all:
	cargo build --release

.PHONY: run
run:
	python3 tile_image.py
	cargo run --release
	python3 bin2pgm.py result.bin resutl_4096x4096.pgm 4096 4096

.PHONY: load
load:
	make -C ../../syn/cli load
	sleep 1

.PHONY: cpu
cpu:
	python3 morph_open_close.py -i img_4096x4096.pgm

