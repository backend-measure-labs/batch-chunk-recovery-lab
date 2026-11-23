#!/usr/bin/env bash
# 호스트 → VM 경로 점검: Docker API · MySQL · Prometheus. 사용: check-path.sh (LAB_TUNNEL 은 env.sh 기본값 또는 인자 1)
[ "${1:-}" = tunnel ] && export LAB_TUNNEL=1
source "$(dirname "$0")/env.sh"
for i in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 2; done
docker info --format 'docker ok: {{.ServerVersion}} mem={{.MemTotal}} cpus={{.NCPU}}' 2>&1 | head -2
docker compose ps --format '{{.Name}} {{.Status}}' 2>&1
echo "mysql: $(sql 'SELECT 1')"
echo "prom: $(curl -s -m5 -o /dev/null -w '%{http_code}' http://localhost:$HOST_PROM_PORT/-/ready)"
