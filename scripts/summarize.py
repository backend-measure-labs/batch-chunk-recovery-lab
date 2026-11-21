#!/usr/bin/env python3
"""회차 디렉터리들 → 한 줄씩 요약 CSV.

사용: summarize.py <reports/qN> > summary.csv
열: run, params..., outcome, rows, c0, peak(체크포인트 최대), peak_point, c3, c5, live_per_row(B),
    elapsed_s, gc_pause_ratio, docker_mem_max, verify(dup/missing)
"""
import csv
import os
import re
import sys
from datetime import datetime

root = sys.argv[1]
cols = ["run", "kind", "series", "days", "digits", "rep", "heap", "save", "mode", "window_h", "app",
        "outcome", "rows", "c0_mb", "peak_mb", "peak_point", "c3_mb", "c5_mb", "peak_per_row_b",
        "c5_minus_c3_per_row_b", "run_ms", "gc_pause_ratio", "docker_mem_max_mb", "exit",
        "duplicates", "missing", "lab_frame", "error"]
w = csv.writer(sys.stdout)
w.writerow(cols)


def kv(path):
    d = {}
    if os.path.exists(path):
        for line in open(path):
            line = line.strip()
            if "=" in line:
                for part in line.split(" ") if line.startswith("kind=") else [line]:
                    k, _, v = part.partition("=")
                    d[k] = v
    return d


def gc_ratio(path, start, end):
    """[start, end] (wall clock epoch 초) 안의 GC 일시정지 합 ÷ 구간 길이"""
    if not os.path.exists(path) or not start or not end or end <= start:
        return ""
    total = 0.0
    for line in open(path):
        m = re.match(r"\[(\d{4}-\d\d-\d\dT[\d:.]+)([+-]\d{4})\].*Pause.* ([\d.]+)ms$", line.strip())
        if not m:
            continue
        t = datetime.strptime(m.group(1) + m.group(2), "%Y-%m-%dT%H:%M:%S.%f%z").timestamp()
        if start <= t <= end:
            total += float(m.group(3))
    return f"{total / 1000 / (end - start):.3f}"


def log_time(line):
    m = re.match(r"(\d{4}-\d\d-\d\dT[\d:.]+Z)", line)
    return datetime.strptime(m.group(1), "%Y-%m-%dT%H:%M:%S.%fZ").replace(
        tzinfo=__import__("datetime").timezone.utc).timestamp() if m else None


for name in sorted(os.listdir(root)):
    d = os.path.join(root, name)
    if not os.path.isdir(d) or name in ("invalid",) or not os.path.exists(os.path.join(d, "params.txt")):
        continue
    p = kv(os.path.join(d, "params.txt"))
    o = kv(os.path.join(d, "outcome.txt"))
    cps = []
    cpf = os.path.join(d, "checkpoints.csv")
    if os.path.exists(cpf):
        cps = list(csv.DictReader(open(cpf)))
    c0 = min((int(c["heap_used"]) for c in cps if c["point"] == "c0"), default=None)
    peak = max(cps, key=lambda c: int(c["heap_used"]), default=None)
    c3 = max((int(c["heap_used"]) for c in cps if c["point"] == "c3"), default=None)
    c5 = max((int(c["heap_used"]) for c in cps if c["point"] == "c5"), default=None)
    rows = max((int(c["rows"]) for c in cps if c["point"] == "c3"), default=None)
    run_start = run_end = None
    run_ms = ""
    applog = os.path.join(d, "app.log")
    if os.path.exists(applog):
        for line in open(applog, errors="replace"):
            if "RUN_START" in line and run_start is None:
                run_start = log_time(line)
            if "RUN_END" in line and run_end is None:
                run_end = log_time(line)
                m = re.search(r"ms=(\d+)", line)
                run_ms = m.group(1) if m else ""
                if rows is None:
                    m = re.search(r"rows=(\d+)", line)
                    rows = int(m.group(1)) if m else None
    if o.get("timeout") == "1":
        outcome = "timeout"
    elif o.get("oome_lines", "0") != "0":
        # 재시도가 통과해도 OOME 가 한 번이라도 났으면 실패 (README 1.3)
        outcome = "OOME+retry_ok" if (o.get("run_end_ok", "0") != "0" or o.get("run_end_list_complete", "0") != "0") else "OOME"
    elif o.get("run_end_ok", "0") != "0":
        outcome = "ok"
    elif o.get("run_end_list_complete", "0") != "0":
        outcome = "list_complete"
    elif "137" in o.get("exit", "") or "true" in o.get("exit", ""):
        outcome = "137"
    elif o.get("run_end_error", "0") != "0":
        outcome = "error"
    else:
        outcome = "none"
    if outcome == "none" and "137" in o.get("exit", ""):
        outcome = "137"
    mem_max = ""
    ds = os.path.join(d, "docker-stats.csv")
    if os.path.exists(ds):
        vals = []
        for line in open(ds):
            m = re.match(r"\d+,([\d.]+)(MiB|GiB|KiB)", line)
            if m:
                v = float(m.group(1)) * {"MiB": 1, "GiB": 1024, "KiB": 1 / 1024}[m.group(2)]
                vals.append(v)
        mem_max = f"{max(vals):.0f}" if vals else ""
    dup = miss = ""
    vf = os.path.join(d, "verify.csv")
    if os.path.exists(vf):
        r = list(csv.DictReader(open(vf)))[0]
        dup, miss = r["duplicates"], r["missing"]
    mb = lambda v: f"{v / 1048576:.1f}" if v is not None else ""
    per_row = f"{(int(peak['heap_used']) - c0) / rows:.0f}" if peak and c0 is not None and rows else ""
    c5d = f"{(c5 - c3) / rows:.1f}" if c5 is not None and c3 is not None and rows else ""
    end = run_end
    w.writerow([name, p.get("kind"), p.get("series"), p.get("days"), p.get("digits"), p.get("rep"), p.get("heap"),
                p.get("save"), p.get("mode"), p.get("window_h"), p.get("app"), outcome, rows or "",
                mb(c0), mb(int(peak["heap_used"])) if peak else "", peak["point"] if peak else "", mb(c3), mb(c5),
                per_row, c5d, run_ms, gc_ratio(os.path.join(d, "gc.log"), run_start, end), mem_max,
                o.get("exit", ""), dup, miss, o.get("lab_frame", ""), o.get("first_error", "")[:120]])
