# 공통 값. 모든 스크립트가 source 한다. 레포 루트에서 실행한다(compose.yaml 기준).
export LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$LAB_ROOT"
export LAB_T0=1794700800          # 2026-11-15T00:00:00Z, 앱의 「지금」
# 원 파드의 GC 플래그 (README 0절 F1)
export GC_FLAGS="-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:InitiatingHeapOccupancyPercent=45 -XX:ParallelGCThreads=4 -XX:ConcGCThreads=1"
export TZ_FLAG="-Duser.timezone=UTC"

# 랩 로컬 MySQL 컨테이너에만 보낸다. 값은 합성 데이터, 자격은 랩 더미 값.
sql() { docker compose exec -T mysql mysql -uroot -proot -N -B -e "$1" 2>/dev/null; }
sqlt() { docker compose exec -T mysql mysql -uroot -proot -B -e "$1" 2>/dev/null; }
