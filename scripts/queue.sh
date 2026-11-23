#!/usr/bin/env bash
# 남은 실행 단계를 같은 모양의 명령 하나로 부른다: queue.sh <단계>
# 회차마다 with-deadline.sh 로 시간 상한을 건다. 단계는 백그라운드 상한(2시간) 안에 끝나게 나눴다.
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
source "$R/scripts/env.sh"
W=${Q3_WINDOW:-6}
D1=${Q1_DAYS:-1}   # ① 범위(일). 기준 회차 쓰기 소요가 60초 미만이면 늘린다
q1() { "$R/scripts/with-deadline.sh" "$1" "$R/scripts/run-q1.sh" "${@:2}" > /dev/null 2>&1; }
case $1 in
  q2-rest2) "$R/scripts/q2-limit-rest.sh" 2 ;;
  q2-fill) "$R/scripts/with-deadline.sh" 1200 "$R/scripts/run-q2.sh" limit 448 4 long 1 768 0 > /dev/null 2>&1 ;;
  q2-boundary) "$R/scripts/q2-boundary.sh" ;;
  # ③ 윈도우 24 · 6 · 1시간: 작은 칸 묶음, 그리고 S896 · 7일 회차 하나씩
  q3-24-small) for c in "224 1" "224 7" "896 1"; do "$R/scripts/q3-run.sh" 24 $c all; done ;;
  q3-6-small)  for c in "224 1" "224 7" "896 1"; do "$R/scripts/q3-run.sh" 6 $c all; done ;;
  q3-1-small)  for c in "224 1" "224 7" "896 1"; do "$R/scripts/q3-run.sh" 1 $c all; done ;;
  q3-24-big-*) "$R/scripts/q3-run.sh" 24 896 7 "${1##*-}" ;;
  q3-6-big-*)  "$R/scripts/q3-run.sh" 6 896 7 "${1##*-}" ;;
  q3-1-big-*)  "$R/scripts/q3-run.sh" 1 896 7 "${1##*-}" ;;
  q3-24-rest) "$R/scripts/q3-run.sh" 24 896 1 meas2; "$R/scripts/q3-run.sh" 24 896 1 limit ;;
  q3-24-redo) "$R/scripts/q3-run.sh" 24 896 1 meas1 ;;
  # ③ 대가 수용: ② 에서 A 가 완료한 셀(S224 · 1일 · 768MB)을 저장 포함으로 1회
  q3-a-save) "$R/scripts/with-deadline.sh" "$(deadline_for 224 1 1)" "$R/scripts/run-q2.sh" limit 224 1 long 1 768 1 > /dev/null 2>&1 ;;
  # ③ B 재시작: SIGKILL · 쓰기 중 × 3 (S224 · 1일, 윈도우 = Q3_WINDOW)
  q3-kill) for rep in 1 2 3; do q1 1500 KILL write $rep jobrunr windowed $W 224 1; done ;;
  # ④ C(Spring Batch) 측정 모드 2회: 윈도우 = Q3_WINDOW. S896 · 7일은 회차 하나씩
  q4-small) for c in "224 1" "224 7" "896 1"; do for rep in 1 2; do
      "$R/scripts/with-deadline.sh" "$(deadline_for ${c% *} ${c#* } 1)" "$R/scripts/run-q2.sh" meas $c long $rep 256 1 windowed $W batch > /dev/null 2>&1
    done; done ;;
  q4-big-*) "$R/scripts/with-deadline.sh" "$(deadline_for 896 7 1)" "$R/scripts/run-q2.sh" meas 896 7 long "${1##*-}" 256 1 windowed $W batch > /dev/null 2>&1 ;;
  # ④ C 재시작: SIGKILL · SIGTERM(유예 60초) 쓰기 중 × 3 (S224 · 1일)
  q4-kill) for rep in 1 2 3; do q1 2400 KILL write $rep batch windowed $W 224 1; done ;;
  q4-term) for rep in 1 2 3; do q1 2400 TERM write $rep batch windowed $W 224 1; done ;;
  # ① A 종료 시험
  q1-base1) q1 1500 none - 1 jobrunr full 24 224 $D1 ;;
  q1-a) for rep in 1 2 3; do q1 1500 none - $rep jobrunr full 24 224 $D1; q1 1500 KILL fetch $rep jobrunr full 24 224 $D1; done ;;
  q1-b) for rep in 1 2 3; do q1 1500 KILL write $rep jobrunr full 24 224 $D1; q1 1500 KILL between $rep jobrunr full 24 224 $D1; done ;;
  q1-c) for rep in 1 2 3; do q1 1500 TERM write $rep jobrunr full 24 224 $D1; done ;;
  *) echo "unknown step: $1"; exit 2 ;;
esac
echo "done $1"
