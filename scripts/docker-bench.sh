#!/usr/bin/env bash
# Benchmark a repo's Docker build the way Dokploy sees it after its daily cleanup:
# cold (no layer cache, no cache mounts, base images re-pulled), then warm (one source file changed).
#
# Usage: docker-bench.sh <repo path or git url> <ref> [extra docker buildx build args...]
#   e.g. docker-bench.sh ~/projects/pi/WebCV master --build-arg NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME=demo
#
# Metrics are read from the Docker host's /proc (works on the Pi and inside Colima/Docker Desktop VMs),
# so CPU and network include anything else running on that host: run on an idle machine.
set -euo pipefail

src=${1:?repo path or url}
ref=${2:?git ref}
shift 2

builder=${BENCH_BUILDER:-pi-bench}
name=$(basename "$src" .git | tr '[:upper:]' '[:lower:]')
tag="bench/$name:${ref//\//-}"
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

git clone -q "$src" "$workdir/repo"
git -C "$workdir/repo" checkout -q "$ref"
cd "$workdir/repo"

docker buildx inspect --bootstrap "$builder" >/dev/null 2>&1 \
  || docker buildx create --bootstrap --name "$builder" --driver docker-container >/dev/null

host_proc() {
  docker run --rm --network host alpine:3 sh -c "$1"
}

cpu_jiffies() {
  host_proc "head -1 /proc/stat" | awk '{ print $2 + $3 + $4 + $7 + $8 }'
}

rx_bytes() {
  host_proc "cat /proc/net/dev" | awk -F'[: ]+' 'NR > 2 && $2 !~ /^(lo|docker|veth|br-)/ { sum += $3 } END { print sum }'
}

measure() {
  local label=$1
  shift
  local cpu0 rx0 t0 cpu1 rx1 t1
  cpu0=$(cpu_jiffies); rx0=$(rx_bytes); t0=$(date +%s)
  docker buildx build --builder "$builder" --load -t "$tag" "$@" . >"$workdir/$label.log" 2>&1 \
    || { tail -40 "$workdir/$label.log" >&2; exit 1; }
  t1=$(date +%s); cpu1=$(cpu_jiffies); rx1=$(rx_bytes)
  # /proc/stat counts USER_HZ ticks, 100/s on Linux
  printf '%s|%ss|%ss|%sMB\n' "$label" "$((t1 - t0))" "$(((cpu1 - cpu0) / 100))" "$(((rx1 - rx0) / 1024 / 1024))"
}

docker pull -q alpine:3 >/dev/null
docker buildx prune --builder "$builder" -af >/dev/null

echo "| run | wall | cpu | network rx |"
echo "|---|---|---|---|"
cold=$(measure cold --pull "$@")
touch_file=${BENCH_TOUCH:-$(git ls-files | grep -E '^(src|app)/.*\.(ts|tsx)$' | head -1)}
echo "// bench $(date +%s)" >>"$touch_file"
warm=$(measure warm "$@")
for row in "$cold" "$warm"; do
  echo "| ${row//|/ | } |"
done
echo
echo "image size: $(docker image ls "$tag" --format '{{.Size}}') on disk, $(docker image inspect "$tag" --format '{{.Size}}' | awk '{ printf "%.0fMB", $1 / 1024 / 1024 }') content ($tag)"
