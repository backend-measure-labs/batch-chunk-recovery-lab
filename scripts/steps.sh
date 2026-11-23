#!/usr/bin/env bash
# queue.sh 단계 여러 개를 순서대로 부른다. 사용: steps.sh <단계> [<단계> ...]
R="$(cd "$(dirname "$0")/.." && pwd)"
for s in "$@"; do echo "$(date +%H:%M:%S) start $s"; bash "$R/scripts/queue.sh" "$s"; done
echo "$(date +%H:%M:%S) all done"
