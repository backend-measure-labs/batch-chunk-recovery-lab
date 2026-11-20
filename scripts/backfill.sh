#!/usr/bin/env bash
# 백필: [T0 − 8일, T0] 을 12시간 구간으로 생성 → promtool 로 블록 생성 → 다음 구간.
set -euo pipefail
source "$(dirname "$0")/env.sh"
WORK="$LAB_ROOT/build/backfill"; mkdir -p "$WORK"
docker compose stop prometheus >/dev/null 2>&1 || true
docker compose create prometheus >/dev/null
START=$((LAB_T0 - 8 * 86400))
for ((s = START; s < LAB_T0; s += 43200)); do
  e=$((s + 43200))
  python3 "$LAB_ROOT/infra/prometheus/backfill/gen_openmetrics.py" --start $s --end $e --t0 $LAB_T0 --out "$WORK/seg.om"
  docker run --rm --entrypoint promtool -v bcrl_promdata:/prometheus -v "$WORK":/in:ro prom/prometheus:v3.5.0 \
    tsdb create-blocks-from openmetrics /in/seg.om /prometheus 2>&1 | tail -1
  echo "segment $s-$e done"
done
rm -f "$WORK/seg.om"
docker compose up -d prometheus
