#!/usr/bin/env bash
# Hold dockerd's start until /etc/resolv.conf lists a usable nameserver.
#
# Docker copies the host's nameservers into each container when it starts it.
# If eth0 is still coming up at boot, NetworkManager has no DNS written yet,
# and every container started then can resolve other containers but nothing
# on the internet ("DNS resolver has no external nameservers") until it is
# restarted. Loopback entries don't count: 127.0.0.1 is AdGuard Home, which
# itself runs in Docker.
#
# Gives up after TIMEOUT seconds so Docker never stays down because of this.
TIMEOUT=${TIMEOUT:-120}

for ((i = 0; i < TIMEOUT; i++)); do
  if grep -E '^nameserver' /etc/resolv.conf 2>/dev/null | grep -vqE ' (127\.|::1$)'; then
    echo "wait-for-dns: nameserver ready after ${i}s"
    exit 0
  fi
  sleep 1
done
echo "wait-for-dns: no nameserver after ${TIMEOUT}s, starting Docker anyway"
exit 0
