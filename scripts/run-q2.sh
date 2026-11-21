#!/usr/bin/env bash
# ② · ③ 한 회차.
# 사용: run-q2.sh <meas|limit> <S> <days> <digits> <rep> [heapMB 256|768] [save 0|1] [mode full|windowed] [window_h] [app jobrunr|batch]
#   meas : 호스트 JVM -Xmx6g, 체크포인트 켬
#   limit: 컨테이너 메모리 1Gi · CPU 1, 힙 256MB(옵션 없음 = 25%) 또는 768MB(MaxRAMPercentage=75), 체크포인트 끔
set -uo pipefail
source "$(dirname "$0")/env.sh"
source "$LAB_ROOT/scripts/lib.sh"

KIND=$1 S=$2 D=$3 DIG=$4 REP=$5 HEAP=${6:-256} SAVE=${7:-0} MODE=${8:-full} WIN=${9:-24} APP=${10:-jobrunr}
Q=q2; [ "$MODE" != full ] || [ "$APP" != jobrunr ] && Q=q3
[ "$APP" = batch ] && Q=q4
TAG="$KIND-S$S-D$D-$DIG"
[ "$MODE" = windowed ] && TAG="$KIND-w${WIN}h-S$S-D$D-$DIG"
[ "$APP" = batch ] && TAG="$KIND-batch-w${WIN}h-S$S-D$D-$DIG"
[ "$KIND" = limit ] && TAG="$TAG-h$HEAP"
[ "$SAVE" = 1 ] && TAG="$TAG-save"
OUT="$LAB_ROOT/reports/$Q/$TAG-r$REP-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
echo "$OUT" > "$LAB_ROOT/build/current-run.txt"
JAR_REL="app-$APP/build/libs/app-$APP.jar"

export LAB_SERIES=$S LAB_DIGITS=$DIG LAB_MODE=$MODE LAB_WINDOW_HOURS=$WIN
export LAB_SAVE=$([ "$SAVE" = 1 ] && echo true || echo false)
[ "$APP" = batch ] && export LAB_SAVE=true

reset_db "$D"
echo "kind=$KIND series=$S days=$D digits=$DIG rep=$REP heap=$HEAP save=$SAVE mode=$MODE window_h=$WIN app=$APP t0=$LAB_T0" > "$OUT/params.txt"

START_TS=$(date +%s)
if [ "$KIND" = meas ]; then
  export LAB_CHECKPOINTS=true
  start_host_app "$LAB_ROOT/$JAR_REL" "$OUT"
  wait_health || { echo "health timeout" > "$OUT/outcome.txt"; stop_host_app "$OUT"; exit 1; }
  trigger > "$OUT/trigger.txt"
  # 끝: RUN_END 한 줄, 또는 프로세스 종료, 상한 4시간
  for _ in $(seq 1 14400); do
    grep -q "RUN_END" "$OUT/app.log" && break
    kill -0 "$(cat "$OUT/app.pid")" 2>/dev/null || break
    sleep 1
  done
  sleep 2
  stop_host_app "$OUT"
  EXIT="host"
else
  export LAB_CHECKPOINTS=false
  EXTRA=""; [ "$HEAP" = 768 ] && EXTRA="-XX:MaxRAMPercentage=75"
  APP_MEM=1g APP_CPUS=1 start_container_app "$JAR_REL" "$OUT" "$EXTRA"
  (while docker inspect bcrl-app-1 >/dev/null 2>&1; do
     docker stats --no-stream --format '{{.MemUsage}},{{.CPUPerc}}' bcrl-app-1 2>/dev/null | sed "s/^/$(date +%s),/"
   done > "$OUT/docker-stats.csv" &)
  if wait_health; then
    trigger > "$OUT/trigger.txt"
    FIRST_ERR=0
    for _ in $(seq 1 14400); do
      st=$(container_state); [ "${st%% *}" = running ] || break
      grep -qE "RUN_END status=(ok|list_complete)" "$OUT/app.log" && break
      errs=$(count_log "RUN_END status=error" "$OUT/app.log")
      [ "$errs" -ge 3 ] && break
      if [ "$errs" -ge 1 ] || grep -q OutOfMemoryError "$OUT/app.log"; then
        [ "$FIRST_ERR" = 0 ] && FIRST_ERR=$(date +%s)
        [ $(( $(date +%s) - FIRST_ERR )) -ge 300 ] && break
      fi
      sleep 1
    done
  fi
  sleep 2
  dump_jobrunr "$OUT/jobrunr-states.csv"
  EXIT=$(container_state)
  stop_container_app
fi
END_TS=$(date +%s)

# 결과 요약 (원시 로그를 읽지 않아도 되게)
{
  echo "exit=$EXIT"
  echo "elapsed_s=$((END_TS - START_TS))"
  echo "run_start=$(count_log RUN_START "$OUT/app.log")"
  echo "run_end_ok=$(count_log 'RUN_END status=ok' "$OUT/app.log")"
  echo "run_end_list_complete=$(count_log 'RUN_END status=list_complete' "$OUT/app.log")"
  echo "run_end_error=$(count_log 'RUN_END status=error' "$OUT/app.log")"
  echo "oome_lines=$(count_log OutOfMemoryError "$OUT/app.log")"
  echo "first_error=$(grep -m1 'RUN_END status=error' "$OUT/app.log" | sed 's/.*RUN_END //' | cut -c1-200)"
  echo "oome_top_frames=$(grep -A12 -m1 'java.lang.OutOfMemoryError' "$OUT/app.log" | grep -E '^\s+at ' | head -6 | sed 's/^\s*at //' | tr '\n' '|')"
  echo "lab_frame=$(grep -A80 -m1 'java.lang.OutOfMemoryError' "$OUT/app.log" | grep -m1 -E 'at lab\.' | sed 's/^\s*at //')"
  echo "run_end_line=$(grep -m1 'RUN_END' "$OUT/app.log" | sed 's/.*RUN_END //' | cut -c1-200)"
} > "$OUT/outcome.txt"
grep -E 'QUERY ' "$OUT/app.log" | sed 's/.*QUERY //' > "$OUT/queries.txt"
grep -c CHUNK_COMMIT "$OUT/app.log" > "$OUT/chunks.count" 2>/dev/null || true
if [ "$SAVE" = 1 ] || [ "$APP" = batch ] || [ "$MODE" = windowed ]; then
  grep -q "RUN_END status=ok" "$OUT/app.log" && verify_db "$S" "$D" "$OUT/verify.csv"
fi
echo "$OUT"
