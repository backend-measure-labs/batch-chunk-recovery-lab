#!/usr/bin/env bash
# 회차 하나에 시간 상한을 건다. 사용: with-deadline.sh <초> <회차 스크립트> [인자...]
# 상한에 닿으면 회차 프로세스 트리를 끝내고, 앱(호스트 JVM · 컨테이너)을 정리하고,
# 그 회차 폴더의 outcome.txt 에 timeout=1 을 남긴 뒤 다음 회차로 넘어간다.
set -uo pipefail
source "$(dirname "$0")/env.sh"
LIMIT=$1; shift
CUR="$LAB_ROOT/build/current-run.txt"
rm -f "$CUR"
"$@" &
PID=$!
START=$(date +%s)
kill_tree() { local p=$1 c; for c in $(pgrep -P "$p"); do kill_tree "$c"; done; kill -9 "$p" 2>/dev/null; }
while kill -0 $PID 2>/dev/null; do
  if [ $(( $(date +%s) - START )) -ge "$LIMIT" ]; then
    kill_tree $PID
    OUT=$(cat "$CUR" 2>/dev/null)
    [ -n "$OUT" ] && [ -f "$OUT/app.pid" ] && kill -9 "$(cat "$OUT/app.pid")" 2>/dev/null
    (docker compose --profile app rm -sf app >/dev/null 2>&1 &)
    sleep 20
    pkill -f "docker compose logs -f --no-log-prefix" 2>/dev/null
    pkill -f "docker stats --no-stream --format" 2>/dev/null
    if [ -n "$OUT" ] && [ -d "$OUT" ]; then
      echo "timeout=1" >> "$OUT/outcome.txt"
      echo "timeout_limit_s=$LIMIT" >> "$OUT/outcome.txt"
    fi
    echo "TIMEOUT $LIMIT s: $* -> ${OUT:-?}"
    exit 124
  fi
  sleep 2
done
wait $PID
