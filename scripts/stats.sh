#!/usr/bin/env bash
set -euo pipefail
PROG=${1:?"usage: $0 ./bench_O0"}
NAME=$(basename "$PROG")
mkdir -p out

echo "== 2.1 gtime -v"
gtime -v "$PROG" 2> "out/${NAME}.gtime.txt" > /dev/null
cat "out/${NAME}.gtime.txt"

echo
echo "== 2.2 /usr/bin/time -l"
/usr/bin/time -l "$PROG" 2> "out/${NAME}.time_l.txt" > /dev/null
cat "out/${NAME}.time_l.txt"
awk '/instructions retired/{i=$1} /cycles elapsed/{c=$1}
     END{if(c>0) printf "IPC = %.2f\n", i/c}' "out/${NAME}.time_l.txt"

echo
echo "== 2.2 5 runs"
for i in 1 2 3 4 5; do
  /usr/bin/time -p "$PROG" 2>&1 >/dev/null | awk '/^real/{print $2}'
done | tr ',' '.' | awk '{s+=$1; ss+=$1*$1; n++} END{m=s/n; printf "mean=%.3f s  stddev=%.3f s\n", m, sqrt(ss/n-m*m)}'

if xcrun -f xctrace >/dev/null 2>&1; then
  echo
  echo "== 2.3 xctrace Time Profiler -> out/${NAME}.trace"
  rm -rf "out/${NAME}.trace"
  xcrun xctrace record --template 'Time Profiler' --output "out/${NAME}.trace" --launch -- "$PROG" > /dev/null
else
  echo "xctrace not found (install Xcode)"
fi
