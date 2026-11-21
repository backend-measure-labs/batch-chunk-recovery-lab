#!/usr/bin/env bash
# 남은 실행 단계를 같은 모양의 명령 하나로 부른다: queue.sh <단계>
# 회차마다 with-deadline.sh 로 시간 상한을 건다. 단계는 백그라운드 상한(2시간) 안에 끝나게 나눴다.
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
source "$R/scripts/env.sh"
W=${Q3_WINDOW:-6}
q1() { "$R/scripts/with-deadline.sh" "$1" "$R/scripts/run-q1.sh" "${@:2}" > /dev/null 2>&1; }
case $1 in
  q2-rest2) "$R/scripts/q2-limit-rest.sh" 2 ;;
  q2-fill) "$R/scripts/with-deadline.sh" 1200 "$R/scripts/run-q2.sh" limit 448 4 long 1 768 0 > /dev/null 2>&1 ;;
  q2-boundary) "$R/scripts/q2-boundary.sh" ;;
  # ③ 창 24 · 6 · 1시간: 작은 칸 묶음, 그리고 S896 · 7일 회차 하나씩
  q3-24-small) for c in "224 1" "224 7" "896 1"; do "$R/scripts/q3-run.sh" 24 $c all; done ;;
  q3-6-small)  for c in "224 1" "224 7" "896 1"; do "$R/scripts/q3-run.sh" 6 $c all; done ;;
  q3-1-small)  for c in "224 1" "224 7" "896 1"; do "$R/scripts/q3-run.sh" 1 $c all; done ;;
  q3-24-big-*) "$R/scripts/q3-run.sh" 24 896 7 "${1##*-}" ;;
  q3-6-big-*)  "$R/scripts/q3-run.sh" 6 896 7 "${1##*-}" ;;
  q3-1-big-*)  "$R/scripts/q3-run.sh" 1 896 7 "${1##*-}" ;;
  # ③ B 재시작: SIGKILL · 쓰기 중 × 3 (S224 · 1일, 창 = Q3_WINDOW)
  q3-kill) for rep in 1 2 3; do q1 1500 KILL write $rep jobrunr windowed $W 224 1; done ;;
  # ① A 종료 시험
  q1-a) for rep in 1 2 3; do q1 1500 none - $rep jobrunr full 24 224 1; q1 1500 KILL fetch $rep jobrunr full 24 224 1; done ;;
  q1-b) for rep in 1 2 3; do q1 1500 KILL write $rep jobrunr full 24 224 1; q1 1500 KILL between $rep jobrunr full 24 224 1; done ;;
  q1-c) for rep in 1 2 3; do q1 1500 TERM write $rep jobrunr full 24 224 1; done ;;
  *) echo "unknown step: $1"; exit 2 ;;
esac
echo "done $1"
