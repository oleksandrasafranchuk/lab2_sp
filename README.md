# Profiling, energy and optimization (macOS)

Benchmark `bench.c`: matrix multiplication 1024x1024, SAXPY, sum of square roots, sorting 3M integers.

## Requirements

```
xcode-select --install
brew install gnu-time
git clone https://github.com/brendangregg/FlameGraph ~/FlameGraph
```

## Usage

```
make
scripts/run_all.sh
```

| Task | Command |
| --- | --- |
| FlameGraph | `scripts/flamegraph.sh ./bench_O0` |
| Statistics | `scripts/stats.sh ./bench_O0` |
| Energy | `sudo scripts/energy.sh ./bench_O0` |
| Linux perf (Docker) | `docker run --rm -it --privileged -v "$PWD":/lab -w /lab ubuntu:24.04 bash scripts/linux-perf.sh` |

Results are written to `results/`.
# lab2_sp
