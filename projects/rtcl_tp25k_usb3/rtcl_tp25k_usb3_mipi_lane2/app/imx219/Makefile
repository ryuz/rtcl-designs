

.PHONY: all
all:
	cargo build --release

.PHONY: run
run:
	cargo run --release

.PHONY: load
load:
	make -C ../../syn/cli load
	sleep 1

.PHONY: load_run
load_run: load run
