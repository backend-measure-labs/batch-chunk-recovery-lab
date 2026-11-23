#!/usr/bin/env bash
# 공개 전 정리: reports 의 텍스트 결과에서 로컬 홈 경로를 ~ 로, 「started by <실행 사용자>」를 「started by user」로 바꾼다.
# 사용: scrub.sh [대상 디렉터리, 기본 reports]
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
T=${1:-$R/reports}
U=$(id -un)
n=0
while IFS= read -r -d '' f; do
  if grep -qF -e "$HOME" -e "started by $U " "$f" 2>/dev/null; then
    sed -i '' -e "s|$HOME|~|g" -e "s|started by $U |started by user |g" "$f"
    n=$((n + 1))
  fi
done < <(find "$T" -type f \( -name '*.log' -o -name '*.txt' -o -name '*.csv' -o -name '*.md' \) ! -name 'histogram-*' -print0)
echo "scrubbed files: $n"
left=$(grep -rlF -e "$HOME" -e "started by $U " "$T" --include='*.log' --include='*.txt' --include='*.csv' --include='*.md' 2>/dev/null | grep -v histogram- | wc -l | tr -d ' ')
echo "files still matching: $left"
