#!/usr/bin/env bash
# ① A 실행 중 종료: 기준 3 · SIGKILL × (조회 중 · 쓰기 중 · 청크 사이) 3회씩 · SIGTERM × 쓰기 중 3회 (유예 60초)
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
D=${1:-1}
for rep in 1 2 3; do
  "$R/scripts/run-q1.sh" none - $rep jobrunr full 24 224 $D > /dev/null 2>&1
  for ph in fetch write between; do "$R/scripts/run-q1.sh" KILL $ph $rep jobrunr full 24 224 $D > /dev/null 2>&1; done
  "$R/scripts/run-q1.sh" TERM write $rep jobrunr full 24 224 $D > /dev/null 2>&1
done
echo done
