# 무효 회차

| 회차 | 사유 |
|---|---|
| meas-batch-w1h-S224-D7-long-save-r2-20261121-220112 | 실행 중 Docker 소켓이 끊겨(Rancher Desktop 재시작 필요) 회차가 상한 2,979초에 닿아 중단됨. 같은 칸을 다시 실행 |
| restart-batch-windowed-w1h-KILL-write-S224-D1-r1-20261123-084855 | 신호가 쓰기 중에 걸리지 않음: 쓰기 구간(약 13초) 동안 innodb_trx 폴링 228회가 모두 열린 트랜잭션 0 을 읽어 hit=0. 잡은 신호 약 6분 전에 COMPLETED 로 끝났고, SIGKILL 은 끝난 앱에 갔다. 같은 조건의 수동 확인(2초 간격 6회)에서는 앱 트랜잭션이 5회 보여 원인 미확인. 회차는 20분 상한에도 닿음 |
| meas-batch-w1h-S224-D1-long-save-r1-20261121-214236 | 수정 전 C 리더(윈도우 경계 시각을 두 윈도우에서 모두 내보냄)로 측정. 신호와 무관한 중복 3,584. 리더 수정 뒤 같은 칸을 다시 실행(batch-chunk-recovery-lab#2) |
| meas-batch-w1h-S224-D1-long-save-r2-20261121-214450 | 수정 전 C 리더(윈도우 경계 시각을 두 윈도우에서 모두 내보냄)로 측정. 신호와 무관한 중복 3,584. 리더 수정 뒤 같은 칸을 다시 실행(batch-chunk-recovery-lab#2) |
| meas-batch-w1h-S224-D7-long-save-r1-20261121-214701 | 수정 전 C 리더(윈도우 경계 시각을 두 윈도우에서 모두 내보냄)로 측정. 신호와 무관한 중복 25,088. 리더 수정 뒤 같은 칸을 다시 실행(batch-chunk-recovery-lab#2) |
| meas-batch-w1h-S224-D7-long-save-r2-20261123-083549 | 수정 전 C 리더(윈도우 경계 시각을 두 윈도우에서 모두 내보냄)로 측정. 신호와 무관한 중복 25,088. 리더 수정 뒤 같은 칸을 다시 실행(batch-chunk-recovery-lab#2) |
| restart-batch-windowed-w1h-KILL-write-S224-D1-r2-20261123-091137 | 수정 전 C 리더(윈도우 경계 시각을 두 윈도우에서 모두 내보냄)로 측정. 신호와 무관한 중복 3,584. 리더 수정 뒤 같은 칸을 다시 실행(batch-chunk-recovery-lab#2) |
