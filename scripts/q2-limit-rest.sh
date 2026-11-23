#!/usr/bin/env bash
# ② 상한 모드 나머지 (백그라운드 상한 2시간에 맞춰 둘로 나눔).
#   part 1: 짧은 값 S224 × 256MB, 768MB × S50 · S224
#   part 2: 768MB × S448 · S896 (A · S896 · 7일은 로컬 VM 에 맞지 않아 제외, README 1.4), 짧은 값 S224 × 768MB
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
run() { "$R/scripts/with-deadline.sh" 1200 "$R/scripts/run-q2.sh" limit "$@" > /dev/null 2>&1; }
done_already() { ls "$R/reports/q2" | grep -q "^limit-S$1-D$2-$3-h$4-r1-"; }
if [ "${1:-1}" = 1 ]; then
  for D in 1 2 4 7; do run 224 $D short 1 256 0; done
  for S in 50 224; do for D in 1 2 4 7; do run $S $D long 1 768 0; done; done
else
  for S in 448 896; do for D in 1 2 4 7; do
    [ $S = 896 ] && [ $D = 7 ] && continue
    done_already $S $D long 768 || run $S $D long 1 768 0
  done; done
  for D in 1 2 4 7; do done_already 224 $D short 768 || run 224 $D short 1 768 0; done
fi
echo done
