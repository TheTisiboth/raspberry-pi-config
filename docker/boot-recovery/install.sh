#!/usr/bin/env bash
# Install (or update) the Docker boot-recovery pieces. Run as root.
#   - wait-for-dns: docker.service waits for a real nameserver at boot
#   - overlay-ip-repair.timer: restarts containers whose overlay IP was taken
set -euo pipefail
cd "$(dirname "$0")"

install -m 755 wait-for-dns.sh overlay-ip-repair.sh /usr/local/bin/
install -d /etc/systemd/system/docker.service.d
install -m 644 docker-wait-for-dns.conf /etc/systemd/system/docker.service.d/wait-for-dns.conf
install -m 644 overlay-ip-repair.service overlay-ip-repair.timer /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now overlay-ip-repair.timer
