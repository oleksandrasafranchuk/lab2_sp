#!/usr/bin/env bash
set -euo pipefail

PROG=${1:?"usage: $0 ./bench_O0 [sample|dtrace]"}
MODE=${2:-sample}
NAME=$(basename "$PROG")
FG=${FLAMEGRAPH_DIR:-$HOME/FlameGraph}
mkdir -p out

if [ ! -d "$FG" ]; then
  git clone --depth 1 https://github.com/brendangregg/FlameGraph "$FG"
fi

if [ "$MODE" = "sample" ]; then
  "$PROG" > /dev/null &
  PID=$!
  sample "$PID" 60 1 -mayDie -file "out/${NAME}.sample.txt" || true
  wait "$PID" || true
  awk -f "$FG/stackcollapse-sample.awk" "out/${NAME}.sample.txt" > "out/${NAME}.folded"
else
  sudo dtrace -x ustackframes=100 \
    -n 'profile-997 /pid == $target/ { @[ustack()] = count(); }' \
    -o "out/${NAME}.dtrace.txt" -c "$PROG"
  sudo chown "$USER" "out/${NAME}.dtrace.txt"
  "$FG/stackcollapse.pl" "out/${NAME}.dtrace.txt" > "out/${NAME}.folded"
fi

sed -E 's/bench_[A-Za-z0-9]+`//g; s/Thread_[0-9]+[^;]*/Thread/' "out/${NAME}.folded" > "out/${NAME}.norm.folded"

"$FG/flamegraph.pl" --title "CPU FlameGraph: $NAME ($MODE)" \
  "out/${NAME}.folded" > "out/${NAME}.svg"

echo "Saved: out/${NAME}.svg"
echo "Top functions by samples:"
awk '{n=$NF; $NF=""; split($0,f,";"); leaf=f[length(f)]; sub(/ +$/,"",leaf); s[leaf]+=n; t+=n}
     END{for(k in s) printf "%6.1f%%  %s\n", 100*s[k]/t, k}' "out/${NAME}.folded" \
  | sort -rn | head -10
