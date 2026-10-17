#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
FG=${FLAMEGRAPH_DIR:-$HOME/FlameGraph}
mkdir -p results out
LOG=results/all_results.txt
: > "$LOG"
h() { echo; echo "################ $* ################"; }

{
h "0. environment"
date; sw_vers; uname -m; sysctl -n machdep.cpu.brand_string; clang --version | head -1
sysctl hw.memsize hw.perflevel0.physicalcpu hw.perflevel1.physicalcpu 2>/dev/null

h "0. build"
make clean >/dev/null; make

h "0. stage timings"
echo "--- bench_O0"; ./bench_O0
echo "--- bench_O3"; ./bench_O3

h "1. flamegraph bench_O0"; scripts/flamegraph.sh ./bench_O0
h "1. flamegraph bench_O3"; scripts/flamegraph.sh ./bench_O3
"$FG/difffolded.pl" out/bench_O0.norm.folded out/bench_O3.norm.folded \
  | "$FG/flamegraph.pl" --title "Differential: O0 -> O3 (widths = O3)" > out/diff_after.svg
"$FG/difffolded.pl" out/bench_O3.norm.folded out/bench_O0.norm.folded \
  | "$FG/flamegraph.pl" --negate --title "Differential: O0 -> O3 (widths = O0)" > out/diff_before.svg
echo "samples O0: $(awk '{s+=$NF}END{print s}' out/bench_O0.folded), O3: $(awk '{s+=$NF}END{print s}' out/bench_O3.folded)"

h "2. stats bench_O0"; scripts/stats.sh ./bench_O0
h "2. stats bench_O3"; scripts/stats.sh ./bench_O3

h "2.3 top of stack bench_O0"
sed -n '/Sort by top of stack/,/Binary Images/p' out/bench_O0.sample.txt | head -20
h "2.3 top of stack bench_O3"
sed -n '/Sort by top of stack/,/Binary Images/p' out/bench_O3.sample.txt | head -20

h "4.1 saxpy -O0 arm64"
awk '/^_saxpy:/,/\.cfi_endproc/' asm/bench_O0_native.s | grep -vE '^\s*\.(cfi|loh)'
h "4.1 saxpy -O3 arm64 neon"
awk '/^_saxpy:/,/\.cfi_endproc/' asm/bench_O3_native.s | grep -vE '^\s*\.(cfi|loh|p2align)'
h "4.1 saxpy -O3 x86-64 avx2"
awk '/^_saxpy:/,/\.cfi_endproc/' asm/bench_O3_x86_avx2.s | grep -vE '^\s*\.(cfi|p2align)'
h "4.1 sum_sqrt -O3 arm64"
awk '/^_sum_sqrt:/,/\.cfi_endproc/' asm/bench_O3_native.s | grep -vE '^\s*\.(cfi|loh|p2align)'
h "4.1 matmul -O3 arm64"
awk '/^_matmul:/,/\.cfi_endproc/' asm/bench_O3_native.s | grep -vE '^\s*\.(cfi|loh|p2align)'

h "3. energy bench_O0"; sudo scripts/energy.sh ./bench_O0
h "3. energy bench_O3"; sudo scripts/energy.sh ./bench_O3
} 2>&1 | tee -a "$LOG"

sudo chown -R "$(id -un)" out results
cp out/*.svg results/ 2>/dev/null
cp out/*.gtime.txt out/*.time_l.txt results/ 2>/dev/null
echo
echo "Done: results/"
