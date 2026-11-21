# 회차 스크립트 공통 함수. env.sh 다음에 source 한다.

# 수집 테이블 · 잡 저장소 초기화 후 T0 − d일 시각에 행 하나를 시드한다.
# 커밋된 MAX(수집 시각)가 재개 지점이 되므로 원 코드 그대로 d일 복구가 된다.
reset_db() {
  local days=$1
  local seed=$((LAB_T0 - days * 86400))
  sql "TRUNCATE source.gpu_usage; TRUNCATE source.collect_status; UPDATE source.gpu_usage_seq SET next_val = 1;"
  sql "DELETE FROM jobrunr.jobrunr_jobs;" || true
  sql "DELETE FROM source.BATCH_STEP_EXECUTION_CONTEXT; DELETE FROM source.BATCH_STEP_EXECUTION; DELETE FROM source.BATCH_JOB_EXECUTION_CONTEXT; DELETE FROM source.BATCH_JOB_EXECUTION_PARAMS; DELETE FROM source.BATCH_JOB_EXECUTION; DELETE FROM source.BATCH_JOB_INSTANCE;"
  sql "INSERT INTO source.gpu_usage (id, cluster, namespace, pod_name, gpu_uuid, interval_seconds, collected_at) VALUES (0, 'lab-cluster-1', 'seed', 'seed', 'seed', 60, FROM_UNIXTIME($seed));"
}

# 기대 쌍 수 · 행 수 · 중복 · 누락 → verify.csv
verify_db() {
  local series=$1 days=$2 out=$3
  local start=$((LAB_T0 - days * 86400))
  local expected=$((series * (1440 * days + 1)))
  local r
  r=$(sql "SELECT COUNT(*), COUNT(DISTINCT pod_name, gpu_uuid, collected_at), SUM(pod_name = 'seed') FROM source.gpu_usage WHERE collected_at BETWEEN FROM_UNIXTIME($start) AND FROM_UNIXTIME($LAB_T0);")
  local rows distinct seedleft
  read -r rows distinct seedleft <<<"$r"
  echo "expected_pairs,rows,distinct_pairs,duplicates,missing,seed_rows_left" > "$out"
  echo "$expected,$rows,$distinct,$((rows - distinct)),$((expected - distinct + ${seedleft:-0})),${seedleft:-0}" >> "$out"
}

# JobRunr 잡 JSON 의 상태 이력 → jobrunr-states.csv
dump_jobrunr() {
  local out=$1
  sql "SELECT jobAsJson FROM jobrunr.jobrunr_jobs ORDER BY createdAt;" > "$out.raw" || true
  python3 "$LAB_ROOT/scripts/dump_jobrunr_history.py" "$out.raw" > "$out"
  rm -f "$out.raw"
}

# Spring Batch 메타 → batch-meta.csv
dump_batch_meta() {
  local out=$1
  sqlt "SELECT e.JOB_EXECUTION_ID, e.STATUS, e.EXIT_CODE, e.START_TIME, e.END_TIME, s.STEP_NAME, s.STATUS AS STEP_STATUS, s.COMMIT_COUNT, s.READ_COUNT, s.WRITE_COUNT, c.SHORT_CONTEXT FROM source.BATCH_JOB_EXECUTION e LEFT JOIN source.BATCH_STEP_EXECUTION s ON s.JOB_EXECUTION_ID = e.JOB_EXECUTION_ID LEFT JOIN source.BATCH_STEP_EXECUTION_CONTEXT c ON c.STEP_EXECUTION_ID = s.STEP_EXECUTION_ID ORDER BY e.JOB_EXECUTION_ID;" | tr '\t' ',' > "$out"
}

# 앱 환경 (호스트 · 컨테이너 공통). 호출 전에 LAB_SERIES · LAB_DIGITS · LAB_MODE · LAB_WINDOW_HOURS · LAB_CHECKPOINTS · LAB_SAVE 를 정한다.
export LAB_T0

start_host_app() {   # $1 jar  $2 outdir
  local jar=$1 out=$2
  export APP_URL=http://localhost:18081
  DB_HOST=localhost DB_PORT=$HOST_DB_PORT LAB_PROMETHEUS_URL=http://localhost:$HOST_PROM_PORT LAB_OUT_DIR="$out" SERVER_PORT=18081 \
    java -Xmx6g $GC_FLAGS $TZ_FLAG "-Xlog:gc:file=$out/gc.log:time,uptime" -jar "$jar" > "$out/app.log" 2>&1 &
  echo $! > "$out/app.pid"
}

stop_host_app() {    # $1 outdir
  local pid; pid=$(cat "$1/app.pid")
  kill "$pid" 2>/dev/null || true
  for _ in $(seq 1 90); do kill -0 "$pid" 2>/dev/null || return 0; sleep 1; done
  kill -9 "$pid" 2>/dev/null || true
}

start_container_app() {  # $1 jar(레포 상대)  $2 outdir  $3 추가 JVM 옵션
  local jar=$1 out=$2 extra=$3
  export APP_URL=http://localhost:$HOST_APP_PORT
  APP_JAR="$jar" OUT_DIR="$out" \
    JAVA_OPTS="$GC_FLAGS $TZ_FLAG $extra -Xlog:gc:file=/out/gc.log:time,uptime" \
    docker compose --profile app up -d --force-recreate app >/dev/null 2>&1
  (docker compose logs -f --no-log-prefix app > "$out/app.log" 2>&1 &)
}

container_state() { docker inspect -f '{{.State.Status}} {{.State.ExitCode}} {{.State.OOMKilled}}' bcrl-app-1 2>/dev/null; }

stop_container_app() { docker compose --profile app stop app >/dev/null 2>&1 || true; docker compose --profile app rm -f app >/dev/null 2>&1 || true; }

wait_health() {
  for _ in $(seq 1 180); do
    curl -sf -m5 $APP_URL/actuator/health >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

trigger() { curl -sf -m10 -X POST $APP_URL/lab/trigger; echo; }

count_log() { grep -c "$1" "$2" 2>/dev/null || true; }
