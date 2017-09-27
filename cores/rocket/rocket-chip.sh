#!/bin/sh

set -ex

export CONFIG=DefaultConfigWithRVFIMonitors
export MAKEFLAGS="-j$(nproc)"
export RISCV=$PWD/riscv-tools

enable_compressed=false

if [ ! -d rocket-chip ]; then
	rm -rf rocket-chip
	git clone https://github.com/freechipsproject/rocket-chip
	cd rocket-chip

	git checkout RVFI
	git submodule update --init

	if $enable_compressed; then
		( cd ../../../monitor && python3 generate.py -i rv32ic -p RVFIMonitor -c 2; ) > vsrc/RVFIMonitor.v
	else
		sed -i -e '/DefaultConfigWithRVFIMonitors/,/^)/ { /WithoutCompressed/ s,//,,; };' src/main/scala/system/Configs.scala
		( cd ../../../monitor && python3 generate.py -i rv32i -p RVFIMonitor -c 2; ) > vsrc/RVFIMonitor.v
	fi

	sed -i '/^module/ s/\([A-Z]\+=\)/parameter &/g' vsrc/plusarg_reader.v
	sed -i 's/--top-module/-Wno-fatal &/' emulator/Makefrag-verilator

	cd ..
fi

if [ ! -d riscv-tools ]; then
	mkdir riscv-tools
	cd rocket-chip/riscv-tools
	git submodule update --init --recursive
	# sed -i 's/rv32ima/rv32i/g' build-rv32ima.sh
	./build.sh
	./build-rv32ima.sh
	cd ../..
fi

rm -rf rocket-syn
make -C rocket-chip/vsim verilog

mkdir -p rocket-syn
yosys -v2 -l rocket-syn/rocket-syn.log rocket-syn.ys

