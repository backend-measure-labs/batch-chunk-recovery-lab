#!/usr/bin/env bash
# Docker 데몬이 응답할 때까지 기다린다(최대 10분). 사용: wait-docker.sh
for i in $(seq 1 300); do
  docker info >/dev/null 2>&1 && { echo "docker ready after $((i * 2))s"; exit 0; }
  sleep 2
done
echo "docker not ready after 600s"; exit 1
