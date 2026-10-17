#!/usr/bin/env bash
# docker run --rm -it --privileged -v "$PWD":/lab -w /lab ubuntu:24.04 bash scripts/linux-perf.sh
set -euo pipefail

apt-get update -qq
apt-get install -y -qq clang git linux-tools-generic linux-tools-common > /dev/null
PERF=$(ls /usr/lib/linux-tools/*/perf | head -1)
echo -1 > /proc/sys/kernel/perf_event_paranoid || true

mkdir -p out/linux
clang -O0 -g -fno-omit-frame-pointer -o out/linux/bench_O0 bench.c -lm
clang -O3 -march=native -g -fno-omit-frame-pointer -o out/linux/bench_O3 bench.c -lm
[ -d /tmp/FlameGraph ] || git clone -q --depth 1 https://github.com/brendangregg/FlameGraph /tmp/FlameGraph

for b in bench_O0 bench_O3; do
  $PERF stat -d ./out/linux/$b 2>&1 | tee out/linux/$b.perfstat.txt
  $PERF record -F 999 -e cpu-clock -g -o out/linux/$b.perf.data ./out/linux/$b > /dev/null
  $PERF report -i out/linux/$b.perf.data --stdio --sort comm,dso,symbol 2>/dev/null \
    | head -60 | tee out/linux/$b.report.txt
  $PERF script -i out/linux/$b.perf.data | /tmp/FlameGraph/stackcollapse-perf.pl \
    | /tmp/FlameGraph/flamegraph.pl > out/linux/$b.svg
done
