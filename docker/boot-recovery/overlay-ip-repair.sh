#!/usr/bin/env bash
# Restart containers that Docker refused to start after a reboot because they
# could not rejoin an overlay network (e.g. dokploy-network):
#   - their remembered overlay IP was taken by another container
#     ("attaching to network failed ... context deadline exceeded"), or
#   - dockerd tried to start them before Swarm had set up the network on this
#     node ("network <id> not found"), even though it exists a moment later.
# Docker never retries these, even with restart=always.
#
# For each affected container: reconnect it to its overlay networks without a
# pinned IP (keeping its DNS aliases), then start it.
set -euo pipefail

ERR_PATTERN='attaching to network failed|network [[:alnum:]]+ not found'

log() { echo "overlay-ip-repair: $*"; }

docker ps -aq --filter status=exited --filter status=created | while read -r id; do
  name=$(docker inspect -f '{{.Name}}' "$id" | sed 's#^/##')
  policy=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$id")
  err=$(docker inspect -f '{{.State.Error}}' "$id")

  # Leave containers alone that were stopped on purpose or never meant to restart.
  [[ "$policy" == "always" || "$policy" == "unless-stopped" ]] || continue
  [[ "$err" =~ $ERR_PATTERN ]] || continue

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
