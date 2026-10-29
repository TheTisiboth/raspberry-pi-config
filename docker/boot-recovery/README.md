# Docker boot recovery

Two fixes for Dokploy containers that stay broken after the Pi reboots. Both
showed up on 2026-10-14, when a reboot took every public site down.

| Problem | Symptom | Fix |
|---------|---------|-----|
| A container's old overlay IP on `dokploy-network` is taken by another container | Container stays `Exited (255)`, error `attaching to network failed ... context deadline exceeded`. Docker never retries it, even with `restart: always`. If it's `dokploy-traefik`, every site is down. | `overlay-ip-repair.timer`: 90s after boot, then every 2 min, reconnects such containers without a pinned IP and starts them. |
| Docker starts before NetworkManager has written DNS (eth0 link flap at boot) | Containers run but can't resolve internet names (`EAI_AGAIN`, `ENETUNREACH`). Dokploy deploys fail with `getaddrinfo EAI_AGAIN api.github.com`. dockerd logs `DNS resolver has no external nameservers`. | `wait-for-dns.sh` as an `ExecStartPre` of `docker.service`. It waits up to 120s for a non-loopback nameserver. |

## Install / update

```sh
sudo ./install.sh
```

The DNS wait applies from the next Docker start (reboot or
`systemctl restart docker`). The repair timer starts right away.

## Check

```sh
systemctl list-timers overlay-ip-repair.timer
journalctl -u overlay-ip-repair          # repairs it made
journalctl -u docker | grep wait-for-dns # how long Docker waited at boot
```

Containers started without upstream DNS lack an `ExtServers` line in
`/var/lib/docker/containers/<id>/resolv.conf`. Restarting the container
fixes it; for Swarm services (dokploy, dokploy-postgres, dokploy-redis) use
`docker service update --force <name>`.

## Uninstall

```sh
sudo systemctl disable --now overlay-ip-repair.timer
sudo rm /etc/systemd/system/overlay-ip-repair.{service,timer} \
        /etc/systemd/system/docker.service.d/wait-for-dns.conf \
        /usr/local/bin/{overlay-ip-repair,wait-for-dns}.sh
sudo systemctl daemon-reload
```

Shared rules for the app repos: `~/projects/adr/`.
