#!/usr/bin/env bash
# ② 상한 모드 경계 칸: (힙, 시리즈, 자릿수)마다 마지막 통과 칸 · 처음 실패 칸을 2회 더 (합 3회).
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$R/scripts/summarize.py" "$R/reports/q2" > "$R/reports/q2/summary.csv"
python3 - "$R/reports/q2/summary.csv" > "$R/build/q2-boundary.txt" <<'PY'
import csv, sys
rows = [r for r in csv.DictReader(open(sys.argv[1])) if r["kind"] == "limit" and r["save"] == "0" and r["rep"] == "1"]
cells = {}
for r in rows:
    cells.setdefault((r["heap"], r["series"], r["digits"]), {})[int(r["days"])] = r["outcome"] == "list_complete"
for (h, s, dg), byday in sorted(cells.items()):
    passed = [d for d, ok in byday.items() if ok]
    failed = [d for d, ok in byday.items() if not ok]
    if passed: print(h, s, dg, max(passed))
    if failed: print(h, s, dg, min(failed))
PY
while read -r H S DG D; do
  for rep in 2 3; do "$R/scripts/with-deadline.sh" 1200 "$R/scripts/run-q2.sh" limit $S $D $DG $rep $H 0 > /dev/null 2>&1; done
done < "$R/build/q2-boundary.txt"
python3 "$R/scripts/summarize.py" "$R/reports/q2" > "$R/reports/q2/summary.csv"
echo done
