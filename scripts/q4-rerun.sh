#!/usr/bin/env bash
# #2 리더 수정 뒤 ④ C 재측정. 회차마다 Docker 응답 · 경합을 확인하고, 무효 회차는 invalid 로 옮겨 같은 칸을 다시 돌린다(칸마다 최대 2번 더).
# 사용: q4-rerun.sh
set -uo pipefail
source "$(dirname "$0")/env.sh"
source "$LAB_ROOT/scripts/lib.sh"
W=1
LOG="$LAB_ROOT/reports/q4/rerun-$(date +%Y%m%d-%H%M%S).log"
say() { echo "$(date +%H:%M:%S) $*" | tee -a "$LOG"; }
precheck() {
  "$LAB_ROOT/scripts/wait-docker.sh" >> "$LOG" 2>&1 || return 1
  local others; others=$(docker ps --format '{{.Names}}' | grep -v -E '^(bcrl-(mysql|prometheus)-1|k8s_.*)$' || true)
  [ -n "$others" ] && say "other containers: $others"
  say "load: $(sysctl -n vm.loadavg)"
  return 0
}
invalidate() {  # $1 out  $2 사유
  local d; d=$(basename "$1")
  mv "$1" "$LAB_ROOT/reports/q4/invalid/$d"
  printf '| %s | %s |\n' "$d" "$2" >> "$LAB_ROOT/reports/q4/invalid/README.md"
  say "invalid $d: $2"
}
meas_ok() { grep -q '^run_end_ok=1' "$1/outcome.txt" 2>/dev/null && ! grep -q '^timeout=1' "$1/outcome.txt" && [ -f "$1/verify.csv" ]; }
run_meas() {  # S D rep
  for try in 1 2 3; do
    precheck || { say "docker not ready"; return 1; }
    say "meas S$1 D$2 r$3 try$try"
    "$LAB_ROOT/scripts/with-deadline.sh" "$(deadline_for $1 $2 1)" "$LAB_ROOT/scripts/run-q2.sh" meas $1 $2 long $3 256 1 windowed $W batch >> "$LOG" 2>&1
    local out; out=$(cat "$LAB_ROOT/build/current-run.txt")
    if meas_ok "$out"; then say "ok $(basename "$out") $(tail -1 "$out/verify.csv")"; return 0; fi
    invalidate "$out" "회차 미완료(RUN_END ok 없음 또는 시간 상한). docker: $(docker info >/dev/null 2>&1 && echo 응답 || echo 무응답). 같은 칸을 다시 실행"
  done
  return 1
}
run_kill() {  # rep
  for try in 1 2 3; do
    precheck || { say "docker not ready"; return 1; }
    say "kill r$1 try$try"
    "$LAB_ROOT/scripts/with-deadline.sh" 2400 "$LAB_ROOT/scripts/run-q1.sh" KILL write $1 batch windowed $W 224 1 >> "$LOG" 2>&1
    local rc=$? out; out=$(cat "$LAB_ROOT/build/current-run.txt")
    if [ $rc = 0 ] && grep -q 'hit=1' "$out/params.txt" && grep -q run_end_ok "$out/timeline.csv"; then
      say "ok $(basename "$out") $(tail -1 "$out/verify.csv")"; return 0; fi
    local why="신호 시점 조건(쓰기 중)을 잡지 못해 신호를 보내지 않음"
    [ $rc = 3 ] || why="회차 미완료(rc=$rc). 같은 칸을 다시 실행"
    invalidate "$out" "$why"
  done
  return 1
}
say "start jdk=$(java -version 2>&1 | head -1)"
docker image inspect eclipse-temurin:17-jre-jammy --format 'container image {{.Id}}' >> "$LOG" 2>&1
for rep in 1 2; do run_meas 224 1 $rep; done
for rep in 1 2; do run_meas 224 7 $rep; done
run_kill 3
say "all done"
