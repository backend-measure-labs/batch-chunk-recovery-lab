#!/usr/bin/env bash
# ② 측정 모드 전체: 16칸 × 2회(c3 까지, 저장 건너뜀) + 짧은 값 S224 네 칸 × 2회 + 대표 칸(S224 · 7일) 저장 포함 2회.
# 작은 칸부터. 끝나면 reports/q2/summary-meas.csv
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
for rep in 1 2; do
  for S in 50 224 448 896; do
    for D in 1 2 4 7; do
      "$R/scripts/run-q2.sh" meas $S $D long $rep 256 0 > /dev/null 2>&1
    done
  done
  for D in 1 2 4 7; do
    "$R/scripts/run-q2.sh" meas 224 $D short $rep 256 0 > /dev/null 2>&1
  done
  "$R/scripts/run-q2.sh" meas 224 7 long $rep 256 1 > /dev/null 2>&1
done
python3 "$R/scripts/summarize.py" "$R/reports/q2" > "$R/reports/q2/summary.csv"
echo done
