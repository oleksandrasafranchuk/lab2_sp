CC   ?= clang
ARCH := $(shell uname -m)

ifeq ($(ARCH),arm64)
  NATIVE := -mcpu=apple-m1
else
  NATIVE := -march=native
endif

COMMON := -g -fno-omit-frame-pointer

all: bench_O0 bench_O3 asm

bench_O0: bench.c
	$(CC) -O0 $(COMMON) -o $@ $< -lm

bench_O3: bench.c
	$(CC) -O3 $(NATIVE) $(COMMON) -o $@ $< -lm

asm: bench.c
	mkdir -p asm
	$(CC) -O0 -S -o asm/bench_O0_native.s $<
	$(CC) -O3 $(NATIVE) -S -o asm/bench_O3_native.s $<
	$(CC) -arch x86_64 -O0 -S -o asm/bench_O0_x86.s $<
	$(CC) -arch x86_64 -O3 -mavx2 -mfma -S -o asm/bench_O3_x86_avx2.s $<

clean:
	rm -rf bench_O0 bench_O3 *.dSYM asm out

.PHONY: all asm clean
