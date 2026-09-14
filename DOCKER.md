# Docker conventions

Shared Docker patterns for every repo of the Pi stack (ADR-003). Dokploy builds images **on
the Pi** from each repo's `Dockerfile` + `docker-compose.yml`, so build cost is paid on a
4-core ARM board.

## Why builds are usually cold

Dokploy's daily cleanup runs `docker image prune --all`, `docker builder prune --all` and
`docker system prune --all`. The first deploy of the day therefore re-pulls base images and
rebuilds every layer with empty cache mounts. Optimize for the **cold** build:

- install dependencies once, and only what the image needs;
- no compiler toolchain unless a native dependency requires it, and never in the final stage;
- independent stages (`build`, `prod-deps`) so BuildKit runs them in parallel;
- cache mounts (`/root/.npm`, pnpm store, `.next/cache`) only speed up same-day redeploys.

Measure with [`scripts/docker-bench.sh`](scripts/docker-bench.sh) (cold + warm wall time,
CPU-seconds, network, image size), before and after a Dockerfile change:

```sh
scripts/docker-bench.sh ~/projects/pi/<repo> main
scripts/docker-bench.sh ~/projects/pi/<repo> <branch>
```

## Node Dockerfile

```dockerfile
ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-alpine AS base
WORKDIR /app

FROM base AS deps
# RUN apk add --no-cache python3 make g++   # only for native modules without musl prebuilds
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

FROM deps AS build
COPY . .
RUN --mount=type=cache,target=/app/.next/cache \
    npm run build

# Only when the runtime needs node_modules (not for Next.js standalone alone)
FROM deps AS prod-deps
RUN npm prune --omit=dev

FROM base AS runner
ENV NODE_ENV=production
COPY --from=prod-deps --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
USER node
EXPOSE <port>
CMD ["node", "dist/app.js"]
```

- `NODE_VERSION` is the one place to bump Node in a repo.
- No `# syntax=docker/dockerfile:1` line: the Pi's built-in BuildKit frontend supports cache
  mounts and `COPY --chmod`, and the directive would pull a frontend image on every cold build.
- `npm prune --omit=dev` reuses already compiled native modules: no second install.
- Run as the image's built-in `node` user (uid 1000). Set ownership with `COPY --chown`,
  never `RUN chown -R` (it duplicates the whole layer). Scripts: `COPY --chmod=755`.
  If the app creates directories at startup (Strapi creates `database/migrations`), make the
  app root itself writable with a non-recursive `RUN chown node:node /app`. Test a new image
  with `docker run` before deploying: permission errors only show at runtime.
- No `HEALTHCHECK` in the Dockerfile: compose owns it.
- pnpm: `corepack enable` (version from `packageManager`), store as a cache mount,
  `pnpm prune --prod` for `prod-deps`. Start with `node_modules/.bin/<cli>`, so the runtime
  never needs pnpm.
- Next.js: `output: "standalone"`, `ENV NEXT_TELEMETRY_DISABLED=1`, copy `standalone`,
  `.next/static` and `public`. The standalone output already holds the traced runtime
  dependencies: don't copy a full `node_modules` next to it. When the entrypoint needs a CLI
  (e.g. Prisma migrations + `tsx` seed), install only those packages at their lockfile
  versions in a separate stage (see AdventCalendar's `migrate-tools`).
- Build args only for values the build really inlines (`NEXT_PUBLIC_*`). Never pass real
  secrets as build args: they end up in the image history.

### `.dockerignore`

```gitignore
# Tooling and docs
.git
.github
.idea
.vscode
*.md
Dockerfile
.dockerignore
docker-compose*.yml

# Secrets
.env
.env.*

# Rebuilt inside the image
node_modules
.next
dist
build
coverage
*.tsbuildinfo
*.log
.DS_Store
```

## Compose

- No top-level `version:` key (obsolete).
- `restart: unless-stopped` everywhere, `init: true` on Node services (signals, zombie reaping).
- Healthcheck in compose, testing the container itself (its own database is fine), never
  another project's service: Traefik stops routing to an unhealthy container.
  Traefik also skips containers that are still `starting`, so poll quickly during startup:
  ```yaml
  healthcheck:
    test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:<port>/<health> >/dev/null || exit 1"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 60s
    start_interval: 5s
  ```
- Ports: only the service's `APP_PORT` is published. A database or model server port needed
  for local development binds to loopback (`"127.0.0.1:5434:5432"`), never the LAN.
- Service reached from other projects (Traefik, homepage `siteMonitor`): a stable, unique
  `container_name`. Cross-project calls always use `container_name`, never a service name
  (`app`, `postgres`, `db` exist in several projects).

### Networks

The base `docker-compose.yml` has **no network configuration**: locally every service shares
the project's private `default` network, with no dependency on Dokploy.

On the Pi, only **public services** (Traefik-routed or probed by homepage) join
`dokploy-network`, always together with `default`. Databases, Redis and model servers stay on
the private network: their generic names (`postgres`, `db`, `redis`) would otherwise resolve
to several containers across projects.

`docker-compose.prod.yml` (listed in Dokploy's Compose Path as
`docker-compose.yml,docker-compose.prod.yml`) attaches those public services and nothing else:

```yaml
services:
  app:
    networks:
      - default
      - dokploy-network

networks:
  dokploy-network:
    external: true
```

Never override the `default` network itself to `dokploy-network`, and never give a
database a `networks:` key there. Dokploy also attaches a service that has a **Domain** to
`dokploy-network` + `default` on its own, so the override is strictly needed only for a
service without a Domain (e.g. `frisbee-bot`); keeping it for the others makes the network
setup visible in the repo.

### Image versions

- Third-party images pinned to an exact version tag (`vaultwarden/server:1.37.1`), not
  `latest`/`nightly`, and not a digest. Upgrading is a one-line commit.
- Major-only tags are fine where a major bump needs a migration anyway (`postgres:16-alpine`,
  `redis:7-alpine`, `nextcloud:34-apache`).
- Exception: a service already running a pre-release channel stays on it until a stable
  release catches up, since pinning the older stable would downgrade its data
  (`netdata:latest` = nightly, `adguardhome:edge`).
- A version comes from an env variable (always with the pinned default) only when it is
  shared by several services or upgraded as an operation rather than a code change:
  `OLLAMA_VERSION` (dot: `ollama` + `ollama-setup`), `NEXTCLOUD_IMAGE_TAG` (app + cron,
  one major at a time). Never for Postgres/Redis majors.

## New repo checklist

1. Dockerfile + `.dockerignore` from the templates above.
2. Compose: pinned images, `APP_PORT`, healthcheck, `container_name` for the public service.
3. Dokploy: Compose Path `docker-compose.yml,docker-compose.prod.yml`, Domain on the public
   service, `.env` values.
4. Register it in homepage and `ARCHITECTURE.md` (ADR-002).
