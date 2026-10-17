#!/usr/bin/env bash
set -euo pipefail
PROG=${1:?"usage: sudo $0 ./bench_O0"}
NAME=$(basename "$PROG")
IDLE_SEC=${IDLE_SEC:-15}
mkdir -p out
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }

SAMPLERS="cpu_power,gpu_power,tasks"
OPTS="-i 500 --show-process-energy"

echo "Measuring idle for ${IDLE_SEC} s..."
powermetrics --samplers $SAMPLERS $OPTS -n $((IDLE_SEC*2)) > "out/${NAME}.power_idle.txt"

powermetrics --samplers $SAMPLERS $OPTS > "out/${NAME}.power_load.txt" &
PM=$!
sleep 1
T0=$(python3 -c 'import time;print(time.time())')
"$PROG" > /dev/null
T1=$(python3 -c 'import time;print(time.time())')
kill -INT $PM; wait $PM 2>/dev/null || true

avg_mw() {
  awk '/^CPU Power:/{s+=$3; n++}
       /package power/{v=$NF; gsub("W","",v); s+=v*1000; n++}
       END{if(n) printf "%.0f", s/n; else print 0}' "$1"
}
P_IDLE=$(avg_mw "out/${NAME}.power_idle.txt")
P_LOAD=$(avg_mw "out/${NAME}.power_load.txt")
T=$(python3 -c "print(round($T1-$T0,3))")

python3 - "$NAME" "$P_IDLE" "$P_LOAD" "$T" <<'PY'
import sys
name, pi, pl, t = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
print(f"program      : {name}")
print(f"time         : {t:.2f} s")
print(f"P_idle       : {pi:.0f} mW")
print(f"P_load       : {pl:.0f} mW")
print(f"E_system     : {pl*t/1000:.2f} J")
print(f"E_program    : {(pl-pi)*t/1000:.2f} J")
PY

echo
echo "per-process energy impact:"
grep -E "^Name|$NAME" "out/${NAME}.power_load.txt" | head -5
