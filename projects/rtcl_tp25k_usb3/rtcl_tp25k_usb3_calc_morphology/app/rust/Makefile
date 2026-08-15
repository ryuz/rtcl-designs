

.PHONY: all
all:
	python3 tile_image.py
	cargo run --release
	python3 bin2pgm.py result.bin resutl_4096x4096.pgm 4096 4096

.PHONY: cpu
cpu:
	python3 morph_open_close.py -i img_4096x4096.pgm

