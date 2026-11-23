# 공통 값. 모든 스크립트가 source 한다. 레포 루트에서 실행한다(compose.yaml 기준).
export LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$LAB_ROOT"
mkdir -p "$LAB_ROOT/build"   # 회차 경로(build/current-run.txt)를 쓰는 자리. 새 워크트리에는 없다
export LAB_T0=1794700800          # 2026-11-15T00:00:00Z, 앱의 「지금」
# 원 파드의 GC 플래그 (README 0절 F1)
export GC_FLAGS="-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:InitiatingHeapOccupancyPercent=45 -XX:ParallelGCThreads=4 -XX:ConcGCThreads=1"
export TZ_FLAG="-Duser.timezone=UTC"

# 랩 로컬 MySQL 컨테이너에만 보낸다. 값은 합성 데이터, 자격은 랩 더미 값.
sql() { docker compose exec -T mysql mysql -uroot -proot -N -B -e "$1" 2>/dev/null; }
sqlt() { docker compose exec -T mysql mysql -uroot -proot -B -e "$1" 2>/dev/null; }

# 호스트에서 VM 으로 가는 경로. 기본은 Rancher Desktop 의 전달(9090 · 3306 · 8080).
# 전달이 끊겼을 때는 scripts/tunnel.sh 를 열고 LAB_TUNNEL=1 로 실행한다 (docs/details.md 부록 C).
if [ "${LAB_TUNNEL:-0}" = 1 ]; then
  export DOCKER_HOST=tcp://127.0.0.1:12375 HOST_PROM_PORT=19090 HOST_DB_PORT=13306 HOST_APP_PORT=18080
else
  export HOST_PROM_PORT=9090 HOST_DB_PORT=3306 HOST_APP_PORT=8080
fi

# 회차 시간 상한(초). 저장 없는 회차는 20분, 저장 있는 회차는 예상 소요(90초 + 행 수 ÷ 2,500행/초)의 3배, 최대 7,000초.
deadline_for() {  # $1 S  $2 days  $3 save(0|1)
  local rows=$(( $1 * (1440 * $2 + 1) ))
  if [ "$3" = 0 ]; then echo 1200; return; fi
  local d=$(( 3 * (90 + rows / 2500) )); [ $d -gt 7000 ] && d=7000; echo $d
}
