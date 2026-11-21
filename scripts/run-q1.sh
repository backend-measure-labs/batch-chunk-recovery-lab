#!/usr/bin/env bash
# ① (· ③ · ④ 의 재시작 칸) 한 회차: 실행 중 종료 신호 → 재기동 → 이어서 완료되는지.
# 사용: run-q1.sh <KILL|TERM|none> <fetch|write|between|-> <rep> [app jobrunr|batch] [mode full|windowed] [window_h] [S] [days]
#   write  : 커밋 로그가 전체 청크의 50% 에 닿은 뒤, 앱 연결의 트랜잭션이 trx_rows_modified > 0 인 순간
#   between: 같은 시점 뒤, 앱 연결의 열린 트랜잭션이 0개인 순간
#   fetch  : 첫 조회(GPU) 응답 로그 직후 (나머지 조회가 진행 중)
# 컨테이너: 메모리 1Gi · CPU 1 · 힙 768MB(넉넉히) · 종료 유예 60초
set -uo pipefail
source "$(dirname "$0")/env.sh"
source "$LAB_ROOT/scripts/lib.sh"

SIG=$1 PHASE=$2 REP=$3 APP=${4:-jobrunr} MODE=${5:-full} WIN=${6:-24} S=${7:-224} D=${8:-1}
Q=q1; [ "$MODE" = windowed ] && Q=q3; [ "$APP" = batch ] && Q=q4
OUT="$LAB_ROOT/reports/$Q/restart-$APP-$MODE-w${WIN}h-$SIG-$PHASE-S$S-D$D-r$REP-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
echo "$OUT" > "$LAB_ROOT/build/current-run.txt"
JAR_REL="app-$APP/build/libs/app-$APP.jar"
export LAB_SERIES=$S LAB_DIGITS=long LAB_MODE=$MODE LAB_WINDOW_HOURS=$WIN LAB_SAVE=true LAB_CHECKPOINTS=false
echo "signal=$SIG phase=$PHASE rep=$REP app=$APP mode=$MODE window_h=$WIN series=$S days=$D grace=60" > "$OUT/params.txt"
reset_db "$D"

(docker events --filter container=bcrl-app-1 --format '{{.Time}},{{.Action}},{{index .Actor.Attributes "exitCode"}}' > "$OUT/events.csv" 2>/dev/null &)
EVPID=$!
ms() { python3 -c 'import time;print(int(time.time()*1000))'; }
log_t() { echo "$(ms),$1" >> "$OUT/timeline.csv"; }
echo "epoch_ms,event" > "$OUT/timeline.csv"

GRACE=60s APP_MEM=1g APP_CPUS=1 start_container_app "$JAR_REL" "$OUT" "-XX:MaxRAMPercentage=75"
wait_health || { echo "health timeout" > "$OUT/outcome.txt"; exit 1; }
log_t started
trigger > "$OUT/trigger.txt"; log_t triggered

send_signal() {
  log_t "signal_$SIG"
  if [ "$SIG" = KILL ]; then docker kill -s KILL bcrl-app-1 >/dev/null 2>&1
  else (docker stop -t 60 bcrl-app-1 >/dev/null 2>&1 &); fi
}

if [ "$SIG" != none ]; then
  if [ "$PHASE" = fetch ]; then
    until grep -q "QUERY name=gpu" "$OUT/app.log" 2>/dev/null; do sleep 0.05; done
    send_signal
  else
    # 목표 청크: 전체의 50%
    until grep -q "CHUNK_COMMIT" "$OUT/app.log" 2>/dev/null; do sleep 0.2; done
    TOTAL=$(grep -m1 CHUNK_COMMIT "$OUT/app.log" | sed -E 's/.* of=([0-9?]+).*/\1/')
    { [ "$TOTAL" = "?" ] || [ "$MODE" = windowed ]; } && TOTAL=$(( S * (1440 * D + 1) / ((500 + S - 1) / S * S) ))
    TARGET=$((TOTAL / 2))
    echo "total_chunks=$TOTAL target=$TARGET" >> "$OUT/params.txt"
    until [ "$(count_log CHUNK_COMMIT "$OUT/app.log")" -ge "$TARGET" ]; do sleep 0.1; done
    log_t target_reached
    # 한 mysql 세션에 50ms 간격으로 조회를 흘려 넣고 한 줄씩 판정한다
    POLL="SELECT CONCAT(ROUND(UNIX_TIMESTAMP(NOW(3))*1000), ',', COUNT(t.trx_id), ',', COALESCE(MAX(t.trx_rows_modified),0), ',', COALESCE(MIN(t.trx_started),'')) FROM information_schema.processlist p LEFT JOIN information_schema.innodb_trx t ON t.trx_mysql_thread_id = p.id WHERE p.user = 'lab' AND p.db = 'source';"
    echo "poll_ms,open_trx,max_rows_modified,trx_started" > "$OUT/innodb_trx.csv"
    coproc POLLER { while :; do echo "$POLL"; sleep 0.05; done | docker compose exec -T mysql mysql -uroot -proot -N -B 2>/dev/null; }
    HIT=0
    for _ in $(seq 1 6000); do
      read -r line <&"${POLLER[0]}" || break
      echo "$line" >> "$OUT/innodb_trx.csv"
      IFS=, read -r _ntrx_t ntrx nmod _ <<<"$line"
      if [ "$PHASE" = write ] && [ "${nmod:-0}" -gt 0 ]; then HIT=1; break; fi
      if [ "$PHASE" = between ] && [ "${ntrx:-1}" -eq 0 ]; then HIT=1; break; fi
    done
    send_signal
    echo "signal_line=$line hit=$HIT" >> "$OUT/params.txt"
    kill "$POLLER_PID" 2>/dev/null || true
  fi
  # 컨테이너가 멈출 때까지
  for _ in $(seq 1 120); do st=$(container_state); [ "${st%% *}" = running ] || break; sleep 1; done
  log_t "stopped_$(container_state | tr ' ' '_')"
  COMMITTED_BEFORE=$(count_log CHUNK_COMMIT "$OUT/app.log")
  LAST_TO=$(grep CHUNK_COMMIT "$OUT/app.log" | tail -1 | sed -E 's/.* to=([0-9]+).*/\1/')
  # 재기동 직전 DB: 마지막 커밋 로그의 to 이후 행(= 진행 중 청크가 남았는가), 커밋 로그 범위의 행 수
  START=$((LAB_T0 - D * 86400))
  sql "SELECT COUNT(*), SUM(collected_at > FROM_UNIXTIME(${LAST_TO:-0})), SUM(collected_at <= FROM_UNIXTIME(${LAST_TO:-0})) FROM source.gpu_usage WHERE pod_name <> 'seed';" \
    | awk -v c="$COMMITTED_BEFORE" -v t="${LAST_TO:-}" '{print "committed_chunks_logged="c"\nlast_committed_to="t"\nrows_after_signal="$1"\nrows_beyond_last_commit="$2"\nrows_within_committed="$3}' > "$OUT/after-signal.txt"
  [ "$APP" = batch ] && dump_batch_meta "$OUT/batch-meta-after-signal.csv"
  [ "$APP" = jobrunr ] && dump_jobrunr "$OUT/jobrunr-states-after-signal.csv"
  docker start bcrl-app-1 >/dev/null 2>&1
  (docker compose logs -f --no-log-prefix --since 1s app > "$OUT/app-restart.log" 2>&1 &)
  wait_health; log_t restarted
fi

# 완료 대기: JobRunr 는 스스로 이어가야 한다(최대 15분). Spring Batch 는 다음 주기 2번(최대 11분)을 보고,
# 이어가지 않으면 사람의 조치(STARTED → FAILED)를 한 번 한 뒤 다음 주기를 기다린다.
LOGS="$OUT/app.log"; [ -f "$OUT/app-restart.log" ] && LOGS="$OUT/app-restart.log"
done_ok() { grep -qE "RUN_END status=ok" "$LOGS"; }
LIMIT=900; [ "$APP" = batch ] && [ "$SIG" != none ] && LIMIT=660
for _ in $(seq 1 $LIMIT); do done_ok && break; sleep 1; done
if ! done_ok && [ "$APP" = batch ]; then
  log_t manual_fail_marking
  dump_batch_meta "$OUT/batch-meta-before-manual.csv"
  sql "UPDATE source.BATCH_STEP_EXECUTION SET STATUS = 'FAILED', EXIT_CODE = 'FAILED', END_TIME = NOW() WHERE STATUS IN ('STARTED','STOPPING'); UPDATE source.BATCH_JOB_EXECUTION SET STATUS = 'FAILED', EXIT_CODE = 'FAILED', END_TIME = NOW() WHERE STATUS IN ('STARTED','STOPPING');"
  for _ in $(seq 1 900); do done_ok && break; sleep 1; done
fi
done_ok && log_t run_end_ok || log_t run_end_timeout
sleep 2
[ "$APP" = jobrunr ] && dump_jobrunr "$OUT/jobrunr-states.csv"
[ "$APP" = batch ] && dump_batch_meta "$OUT/batch-meta.csv"
verify_db "$S" "$D" "$OUT/verify.csv"
stop_container_app
kill "$EVPID" 2>/dev/null || pkill -f "docker events --filter container=bcrl-app-1" || true

{
  grep -h -E "RUN_START|READER_OPEN|RUN_END|SKIP_RUNNING|LAUNCH_|Orphan|stopped|interrupt" "$OUT/app.log" "$OUT/app-restart.log" 2>/dev/null | cut -c1-260
} > "$OUT/key-lines.txt"
grep -h CHUNK_COMMIT "$OUT/app.log" 2>/dev/null | tail -3 | cut -c1-220 > "$OUT/last-chunks-before.txt"
grep -h "interrupted=true" "$OUT/app.log" 2>/dev/null | wc -l | tr -d ' ' > "$OUT/interrupted-commits.count"
echo "$OUT"
