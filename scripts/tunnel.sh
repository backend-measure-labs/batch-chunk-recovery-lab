#!/usr/bin/env bash
# Rancher Desktop 의 호스트 전달이 끊겼을 때 랩 전용 ssh 터널을 연다(같은 VM 의 Docker API · 포트).
C="$HOME/Library/Application Support/rancher-desktop/lima/0/ssh.config"
exec ssh -F "$C" -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 \
  -L 127.0.0.1:12375:/var/run/docker.sock -L 127.0.0.1:19090:127.0.0.1:9090 \
  -L 127.0.0.1:13306:127.0.0.1:3306 -L 127.0.0.1:18080:127.0.0.1:8080 lima-0
