#!/usr/bin/env bash
# ③ 창 방식 B 한 칸: 사용 q3-run.sh <window_h> <S> <days> [meas1|meas2|limit|all]
#   all = 측정 모드 2회 + 상한 모드(256MB) 1회, 256MB 에서 실패하면 768MB 1회. 모두 저장 포함.
#   백그라운드 상한(2시간)에 맞추려고 큰 칸(S896 · 7일)은 회차 하나씩 부른다.
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
W=$1 S=$2 D=$3 WHAT=${4:-all}
source "$R/scripts/env.sh"
DL=$(deadline_for $S $D 1)
q2() { "$R/scripts/with-deadline.sh" $DL "$R/scripts/run-q2.sh" "$@" > /dev/null 2>&1; cat "$R/build/current-run.txt"; }
case $WHAT in
  meas1) q2 meas $S $D long 1 256 1 windowed $W ;;
  meas2) q2 meas $S $D long 2 256 1 windowed $W ;;
  limit|all)
    if [ "$WHAT" = all ]; then q2 meas $S $D long 1 256 1 windowed $W; q2 meas $S $D long 2 256 1 windowed $W; fi
    out=$(q2 limit $S $D long 1 256 1 windowed $W)
    grep -q "run_end_ok=0" "$out/outcome.txt" && q2 limit $S $D long 1 768 1 windowed $W ;;
esac
