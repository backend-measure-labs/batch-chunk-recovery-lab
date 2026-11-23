#!/usr/bin/env python3
"""③ · ④ 분석: 윈도우 방식 B 와 Spring Batch C 의 피크 · 상한 결과 · 소요 · 정확성.

사용: analyze_q34.py <reports/q3/summary.csv> [<reports/q4/summary.csv>] [<reports/q2/summary.csv>] > docs/results/q34.md
판정 기준은 README 1.3 (실행 전 고정)을 그대로 쓴다. 이 스크립트는 표만 만든다.
"""
import csv
import sys
from collections import defaultdict


def load(path):
    try:
        return [r for r in csv.DictReader(open(path)) if r["kind"] in ("meas", "limit")]
    except (FileNotFoundError, IndexError):
        return []


q3 = load(sys.argv[1])
q4 = load(sys.argv[2]) if len(sys.argv) > 2 else []
q2 = load(sys.argv[3]) if len(sys.argv) > 3 else []
out = []
p = out.append
avg = lambda xs: sum(xs) / len(xs) if xs else None
f0 = lambda v: f"{v:.0f}" if v is not None else "미측정"

windows = sorted({int(r["window_h"]) for r in q3}, reverse=True)
cells = [(224, 1), (224, 7), (896, 1), (896, 7)]


def meas_peak(rows, w, s, d):
    v = [float(r["peak_mb"]) for r in rows if r["kind"] == "meas" and r["window_h"] == str(w)
         and r["series"] == str(s) and r["days"] == str(d) and r["outcome"] == "ok" and r["peak_mb"]]
    return avg(v), len(v)


def meas_secs(rows, w, s, d):
    v = [int(r["run_ms"]) / 1000 for r in rows if r["kind"] == "meas" and r["window_h"] == str(w)
         and r["series"] == str(s) and r["days"] == str(d) and r["outcome"] == "ok" and r["run_ms"]]
    return avg(v)


p("### ③ 측정 모드 피크 라이브셋 (MB, 회차 평균 · 회차 수)\n")
p("| 윈도우 | S224 · 1일 | S224 · 7일 | 7일 ÷ 1일 | S896 · 1일 | S896 · 7일 | 7일 ÷ 1일 |")
p("|---|---|---|---|---|---|---|")
for w in windows:
    row = [f"{w}시간"]
    for s in (224, 896):
        a, na = meas_peak(q3, w, s, 1)
        b, nb = meas_peak(q3, w, s, 7)
        row += [f"{f0(a)} ({na})", f"{f0(b)} ({nb})", f"{b / a:.3f}" if a and b else "-"]
    p("| " + " | ".join(row) + " |")

p("\n### ③ 상한 모드 결과 (힙 256MB → 실패 시 768MB, 1회)\n")
p("| 윈도우 | " + " | ".join(f"S{s} · {d}일" for s, d in cells) + " |")
p("|---|" + "---|" * len(cells))
for w in windows:
    row = [f"{w}시간"]
    for s, d in cells:
        rs = [r for r in q3 if r["kind"] == "limit" and r["window_h"] == str(w) and r["series"] == str(s)
              and r["days"] == str(d)]
        parts = []
        for h in ("256", "768"):
            for r in rs:
                if r["heap"] == h:
                    t = f" {int(r['run_ms']) / 1000:.0f}초" if r["outcome"] == "ok" and r["run_ms"] else ""
                    parts.append(f"{h}MB {r['outcome']}{t}")
        row.append(" → ".join(parts) or "미수행")
    p("| " + " | ".join(row) + " |")

p("\n### ③ 측정 모드 총 소요 (초, 회차 평균, 저장 포함, 호스트 JVM)\n")
p("| 윈도우 | " + " | ".join(f"S{s} · {d}일" for s, d in cells) + " |")
p("|---|" + "---|" * len(cells))
a_meas = {}
for s, d in cells:
    v = [int(r["run_ms"]) / 1000 for r in q2 if r["kind"] == "meas" and r["save"] == "1" and r["series"] == str(s)
         and r["days"] == str(d) and r["digits"] == "long" and r["run_ms"]]
    a_meas[(s, d)] = avg(v)
p("| A (② 측정 모드 · 저장) | " + " | ".join(f0(a_meas[c]) if a_meas[c] else "-" for c in cells) + " |")
for w in windows:
    p(f"| B {w}시간 | " + " | ".join(f0(meas_secs(q3, w, s, d)) for s, d in cells) + " |")

a_lim = [r for r in q2 if r["kind"] == "limit" and r["save"] == "1" and r["outcome"] == "ok"]
if a_lim:
    p("\n### ③ 대가 수용: ② 에서 A 가 완료한 셀의 상한 모드 총 소요 (초)\n")
    p("| 셀 | A | " + " | ".join(f"B {w}시간" for w in windows) + " |")
    p("|---|---|" + "---|" * len(windows))
    for r in a_lim:
        s, d, h = r["series"], r["days"], r["heap"]
        bs = []
        for w in windows:
            b = [int(x["run_ms"]) / 1000 for x in q3 if x["kind"] == "limit" and x["window_h"] == str(w)
                 and x["series"] == s and x["days"] == d and x["outcome"] == "ok" and x["run_ms"]]
            bs.append(f"{b[0]:.0f} (×{b[0] / (int(r['run_ms']) / 1000):.2f}, {[x['heap'] for x in q3 if x['kind'] == 'limit' and x['window_h'] == str(w) and x['series'] == s and x['days'] == d and x['outcome'] == 'ok'][0]}MB)" if b else "-")
        p(f"| S{s} · {d}일 · {h}MB | {int(r['run_ms']) / 1000:.0f} | " + " | ".join(bs) + " |")

allr = q3 + q4
dup = sum(int(r["duplicates"]) for r in allr if r["duplicates"])
miss = sum(int(r["missing"]) for r in allr if r["missing"])
nver = sum(1 for r in allr if r["duplicates"])
p(f"\n- 정확성(완료 회차의 검증): 회차 {nver}개, 중복 합 {dup}, 누락 합 {miss}")

if q4:
    p("\n### ④ C ↔ B 측정 모드 피크 라이브셋 (MB, 회차 평균 · 회차 수)\n")
    w4 = sorted({int(r["window_h"]) for r in q4})
    p("| 윈도우 | 셀 | B | C | C ÷ B | B 소요(초) | C 소요(초) |")
    p("|---|---|---|---|---|---|---|")
    for w in w4:
        for s, d in cells:
            b, nb = meas_peak(q3, w, s, d)
            c, nc = meas_peak(q4, w, s, d)
            if c is None and b is None:
                continue
            ratio = f"{c / b:.3f}" if b and c else "-"
            p(f"| {w}시간 | S{s} · {d}일 | {f0(b)} ({nb}) | {f0(c)} ({nc}) | {ratio} | "
              f"{f0(meas_secs(q3, w, s, d))} | {f0(meas_secs(q4, w, s, d))} |")

print("\n".join(out))
