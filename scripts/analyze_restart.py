#!/usr/bin/env python3
"""① · ③ · ④ 재시작 회차(restart-*) → 한 줄씩 타임라인 CSV.

사용: analyze_restart.py <reports/qN> > restart-summary.csv
시각은 모두 신호 시각 기준 초(신호 없음 회차는 트리거 기준), VM 시계로 맞춘 값.
열:
  run, app, mode, signal, phase, rep, hit(신호 조건 충족), signal_trx(신호 순간 열린 트랜잭션 · 수정 행 수),
  chunks_before(신호 전 커밋 로그 수), rows_beyond_last_commit(신호 직후 DB 에 마지막 커밋 뒤 행이 남았나),
  rows_within_committed, stopped_s, exit, restarted_s, failed_s(JobRunr FAILED 상태 시각), failed_reason,
  scheduled_s, rerun_start_s(재기동 뒤 첫 RUN_START), rerun_from(그 재개 지점 epoch), manual_s(사람 조치),
  skip_running(재기동 뒤 SKIP_RUNNING 수), done_s, interrupted_commits, expected, rows, duplicates, missing
"""
import csv
import os
import re
import sys
from datetime import datetime, timezone

root = sys.argv[1]
cols = ["run", "app", "mode", "signal", "phase", "rep", "hit", "signal_trx", "chunks_before",
        "rows_beyond_last_commit", "rows_within_committed", "stopped_s", "exit", "restarted_s", "failed_s",
        "failed_reason", "scheduled_s", "rerun_start_s", "rerun_from", "manual_s", "skip_running", "done_s",
        "interrupted_commits", "clock_offset_s", "expected", "rows", "duplicates", "missing"]
w = csv.writer(sys.stdout)
w.writerow(cols)


def kv(path):
    d = {}
    if os.path.exists(path):
        for line in open(path):
            for part in line.strip().split(" "):
                k, _, v = part.partition("=")
                if k:
                    d[k] = v
    return d


def iso(s):
    s = s.strip().rstrip("Z")
    if "." in s:
        head, frac = s.split(".", 1)
        s = head + "." + frac[:6]
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%S.%f").replace(tzinfo=timezone.utc).timestamp()
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone.utc).timestamp()


def log_t(line):
    m = re.match(r"(\d{4}-\d\d-\d\dT[\d:.]+)Z", line)
    return iso(m.group(1)) if m else None


for name in sorted(os.listdir(root)):
    d = os.path.join(root, name)
    if not name.startswith("restart-") or not os.path.isdir(d):
        continue
    p = kv(os.path.join(d, "params.txt"))
    tl = {}
    tlf = os.path.join(d, "timeline.csv")
    if os.path.exists(tlf):
        for r in csv.DictReader(open(tlf)):
            tl.setdefault(r["event"], int(r["epoch_ms"]) / 1000)
    # 앱 · DB 는 VM 시계, timeline 은 호스트 시계다. 트리거 직후의 첫 RUN_START 로 오프셋을 잡아 VM 시계로 옮긴다.
    off = 0.0
    al = os.path.join(d, "app.log")
    if os.path.exists(al) and "triggered" in tl:
        for line in open(al, errors="replace"):
            if "RUN_START" in line:
                off = tl["triggered"] - log_t(line)
                break
    tl = {k: v - off for k, v in tl.items()}
    sig_ev = [k for k in tl if k.startswith("signal_")]
    t0 = tl[sig_ev[0]] if sig_ev else tl.get("triggered")
    rel = lambda t: f"{t - t0:.1f}" if t is not None and t0 is not None else ""
    stopped = [k for k in tl if k.startswith("stopped_")]
    a = kv(os.path.join(d, "after-signal.txt"))
    # 신호 순간의 innodb_trx 행 (poll_ms,open_trx,max_rows_modified,...)
    sl = p.get("signal_line", "")
    trx = ""
    if sl:
        parts = sl.split(",")
        trx = f"open={parts[1]} mod={parts[2]}" if len(parts) > 2 else sl
    # JobRunr 상태
    failed_s = failed_reason = scheduled_s = ""
    jf = os.path.join(d, "jobrunr-states.csv")
    if os.path.exists(jf) and t0:
        for r in csv.DictReader(open(jf)):
            if not r["at"]:
                continue
            t = iso(r["at"])
            if t < t0:
                continue
            if r["state"] == "FAILED" and not failed_s:
                failed_s, failed_reason = rel(t), r["reason"][:80]
            if r["state"] == "SCHEDULED" and failed_s and not scheduled_s:
                scheduled_s = rel(t)
    # 재기동 뒤 로그
    rerun_start = rerun_from = ""
    skip = 0
    done = tl.get("run_end_ok")
    rl = os.path.join(d, "app-restart.log")
    if os.path.exists(rl):
        for line in open(rl, errors="replace"):
            if "RUN_START" in line and not rerun_start:
                t = log_t(line)
                rerun_start = rel(t) if t else ""
                m = re.search(r"start=(\d+)", line)
                rerun_from = m.group(1) if m else ""
            if "SKIP_RUNNING" in line:
                skip += 1
    ic = os.path.join(d, "interrupted-commits.count")
    v = {}
    vf = os.path.join(d, "verify.csv")
    if os.path.exists(vf):
        rows = list(csv.DictReader(open(vf)))
        v = rows[0] if rows else {}
    w.writerow([name, p.get("app"), p.get("mode"), p.get("signal"), p.get("phase"), p.get("rep"), p.get("hit", ""),
                trx, a.get("committed_chunks_logged", ""), a.get("rows_beyond_last_commit", ""),
                a.get("rows_within_committed", ""), rel(tl[stopped[0]]) if stopped else "",
                stopped[0].replace("stopped_", "") if stopped else "", rel(tl.get("restarted")), failed_s,
                failed_reason, scheduled_s, rerun_start, rerun_from, rel(tl.get("manual_fail_marking")), skip,
                rel(done), open(ic).read().strip() if os.path.exists(ic) else "", f"{off:.1f}",
                v.get("expected_pairs", ""), v.get("rows", ""), v.get("duplicates", ""), v.get("missing", "")])
