#!/usr/bin/env bash
# ② 상한 모드: 16칸 + 짧은 값 S224 네 칸 × 힙 256 · 768MB 각 1회(c3 까지, 저장 건너뜀).
# 그 뒤 S · 힙 · 자릿수마다 마지막 통과 칸과 처음 실패 칸을 2회 더 (합 3회).
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
for H in 256 768; do
  for S in 50 224 448 896; do
    for D in 1 2 4 7; do "$R/scripts/run-q2.sh" limit $S $D long 1 $H 0 > /dev/null 2>&1; done
  done
  for D in 1 2 4 7; do "$R/scripts/run-q2.sh" limit 224 $D short 1 $H 0 > /dev/null 2>&1; done
done
python3 "$R/scripts/summarize.py" "$R/reports/q2" > "$R/reports/q2/summary.csv"
# 경계 칸 고르기
python3 - "$R/reports/q2/summary.csv" > "$R/build/q2-boundary.txt" <<'EOF'
import csv, sys
rows = [r for r in csv.DictReader(open(sys.argv[1])) if r["kind"] == "limit" and r["save"] == "0"]
cells = {}
for r in rows:
    cells.setdefault((r["heap"], r["series"], r["digits"]), {})[int(r["days"])] = r["outcome"] == "list_complete"
for (h, s, dg), byday in cells.items():
    passed = [d for d, ok in byday.items() if ok]
    failed = [d for d, ok in byday.items() if not ok]
    if passed: print(h, s, dg, max(passed))
    if failed: print(h, s, dg, min(failed))
EOF
while read -r H S DG D; do
  for rep in 2 3; do "$R/scripts/run-q2.sh" limit $S $D $DG $rep $H 0 > /dev/null 2>&1; done
done < "$R/build/q2-boundary.txt"
python3 "$R/scripts/summarize.py" "$R/reports/q2" > "$R/reports/q2/summary.csv"
echo done
