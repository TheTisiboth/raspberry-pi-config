#!/usr/bin/env bash
# Restart containers that Docker refused to start because their remembered
# overlay IP (e.g. on dokploy-network) was taken by another container after a
# reboot. Docker never retries these, even with restart=always.
#
# For each affected container: reconnect it to its overlay networks without a
# pinned IP (keeping its DNS aliases), then start it.
set -euo pipefail

ERR_PATTERN='attaching to network failed'

log() { echo "overlay-ip-repair: $*"; }

docker ps -aq --filter status=exited --filter status=created | while read -r id; do
  name=$(docker inspect -f '{{.Name}}' "$id" | sed 's#^/##')
  policy=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$id")
  err=$(docker inspect -f '{{.State.Error}}' "$id")

  # Leave containers alone that were stopped on purpose or never meant to restart.
  [[ "$policy" == "always" || "$policy" == "unless-stopped" ]] || continue
  [[ "$err" == *"$ERR_PATTERN"* ]] || continue

  log "repairing $name ($err)"
  networks=$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$id")
  for net in $networks; do
    [[ "$(docker network inspect -f '{{.Driver}}' "$net" 2>/dev/null)" == "overlay" ]] || continue
    aliases=$(docker inspect -f "{{range (index .NetworkSettings.Networks \"$net\").Aliases}}{{.}} {{end}}" "$id")
    args=()
    for a in $aliases; do [[ "$a" == "$name" ]] || args+=(--alias "$a"); done
    docker network disconnect -f "$net" "$id"
    docker network connect "${args[@]}" "$net" "$id"
    log "  reconnected $name to $net (aliases: ${aliases:-none})"
  done

  if docker start "$id" >/dev/null; then
    log "  started $name"
  else
    log "  failed to start $name"
  fi
done
