#!/usr/bin/env python3
"""② 분석: 측정 모드 피크 라이브셋 회귀 · 셀 판정 · 안전한 최대 복구 일수.

사용: analyze_q2.py reports/q2/summary.csv > docs/results/q2.md
판정 기준은 README 1.3 (실행 전 고정)을 그대로 쓴다.
"""
import csv
import sys
from collections import defaultdict

rows = list(csv.DictReader(open(sys.argv[1])))
MB = 1048576


def fit(points):
    n = len(points)
    mx = sum(x for x, _ in points) / n
    my = sum(y for _, y in points) / n
    sxx = sum((x - mx) ** 2 for x, _ in points)
    sxy = sum((x - mx) * (y - my) for x, y in points)
    b = sxy / sxx
    a = my - b * mx
    ss_tot = sum((y - my) ** 2 for _, y in points)
    ss_res = sum((y - (a + b * x)) ** 2 for x, y in points)
    return b, a, 1 - ss_res / ss_tot


out = []
p = out.append

meas = [r for r in rows if r["kind"] == "meas" and r["save"] == "0"]
for dg in ("long", "short"):
    pts = [(int(r["rows"]), float(r["peak_mb"]) * MB) for r in meas
           if r["digits"] == dg and r["outcome"] == "list_complete"]
    if len(pts) < 2:
        continue
    b, a, r2 = fit(pts)
    p(f"- 회귀({dg}, 회차 {len(pts)}개): 행당 피크 힙 {b:.1f}B, 고정 비용 {a / MB:.1f}MB, R² {r2:.5f}")
    if dg == "long":
        slope_long, icpt_long, r2_long = b, a, r2

c5 = [float(r["c5_minus_c3_per_row_b"]) for r in rows if r["c5_minus_c3_per_row_b"]]
inc = max(0.0, max(c5)) if c5 else 0.0
p(f"- 저장 중 증가분 (c5 − c3) ÷ 행 수: {', '.join(f'{v:.1f}B' for v in c5)} → 더하는 값 {inc:.1f}B")

per_row = slope_long + inc
p("")
p("### 측정 모드 피크 라이브셋 (MB, 회차 평균)")
p("")
p("| 시리즈 \\ 일 | 1 | 2 | 4 | 7 |")
p("|---|---|---|---|---|")
for s in ("50", "224", "448", "896"):
    cells = []
    for d in ("1", "2", "4", "7"):
        v = [float(r["peak_mb"]) for r in meas if r["series"] == s and r["days"] == d and r["digits"] == "long"
             and r["outcome"] == "list_complete"]
        cells.append(f"{sum(v) / len(v):.0f}" if v else "미측정")
    p(f"| {s} | " + " | ".join(cells) + " |")

limit = [r for r in rows if r["kind"] == "limit" and r["save"] == "0"]
p("")
for dg in ("long", "short"):
    for h in ("256", "768"):
        heap = int(h) * MB
        p(f"### 상한 모드 판정: 힙 {h}MB · 값 {dg}")
        p("")
        p("| 시리즈 \\ 일 | 1 | 2 | 4 | 7 |")
        p("|---|---|---|---|---|")
        for s in ("50", "224", "448", "896"):
            if dg == "short" and s != "224":
                continue
            cells = []
            for d in ("1", "2", "4", "7"):
                runs = [r for r in limit if r["heap"] == h and r["series"] == s and r["days"] == d and r["digits"] == dg]
                if not runs:
                    cells.append("미수행")
                    continue
                n = len(runs)
                fails = [r for r in runs if r["outcome"] in ("OOME", "OOME+retry_ok", "137", "error", "none", "timeout")]
                mrows = [float(r["peak_mb"]) for r in meas if r["series"] == s and r["days"] == d
                         and r["digits"] == dg and r["peak_mb"] and r["outcome"] == "list_complete"]
                live = sum(mrows) / len(mrows) * MB if mrows else None
                if live is None:
                    rr = [int(r["rows"]) for r in meas if r["series"] == s and r["days"] == d and r["rows"]]
                    nrows = int(s) * (1440 * int(d) + 1)
                    live = icpt_long + slope_long * nrows
                live += inc * int(s) * (1440 * int(d) + 1)
                gc = max((float(r["gc_pause_ratio"]) for r in runs if r["gc_pause_ratio"]), default=0)
                if fails:
                    kinds = sorted({r["outcome"] for r in fails})
                    cells.append(f"실패 {len(fails)}/{n} ({'·'.join(kinds)})")
                elif live > heap * 0.6 or gc > 0.2:
                    cells.append(f"경계 {n}/{n} 완료 ({live / heap * 100:.0f}%{', GC ' + format(gc * 100, '.0f') + '%' if gc > 0.2 else ''})")
                else:
                    cells.append(f"안전 ({live / heap * 100:.0f}%)")
            p(f"| {s} | " + " | ".join(cells) + " |")
        p("")

p("### 안전한 최대 복구 일수 (계산식)")
p("")
p(f"안전한 최대 복구 일수 = (실효 최대 힙 × 0.6 − 고정 비용 {icpt_long / MB:.1f}MB) ÷ (행당 피크 힙 {per_row:.0f}B × 시리즈 수 × 1,440)")
p("")
p("| 시리즈 | 256MB | 768MB |")
p("|---|---|---|")
for s in (50, 224, 448, 896):
    vals = []
    for h in (256, 768):
        days = (h * MB * 0.6 - icpt_long) / (per_row * s * 1440)
        vals.append(f"{days:.2f}일 ({days * 24:.0f}시간)")
    p(f"| {s} | " + " | ".join(vals) + " |")
print("\n".join(out))
