# Pi5 self-hosted stack — architecture

Overview of everything deployed on the Raspberry Pi 5 (`leopi`, LAN
`192.168.178.13`). Each service is its own repo under
`github.com/TheTisiboth`; locally they sit side by side in `~/projects/pi`.

## Services

| Repo | Service | Prod URL | Notes |
|---|---|---|---|
| `homepage` | Dashboard (gethomepage) | https://dashboard.leojan.fr | Landing page + system metrics |
| `adguard-home` | AdGuard Home | https://adguard.leojan.fr | Network DNS + ad blocking (port 53) |
| `vaultwarden` | Vaultwarden | https://vault.leojan.fr | Bitwarden-compatible password manager |
| `WebCV` | Web CV (Next.js front) | https://leojan.fr | Personal CV site |
| `WebCV_backend` | Strapi CMS | https://admin.leojan.fr | CV content backend for WebCV |
| `AdventCalendar` | Advent Calendar (Next.js) | https://calendar.leojan.fr | + Postgres |
| `dot` | Frisbee Bot | _(no web UI)_ | Telegram bot, `/health` only; + Ollama |
| `raspberry-pi-config` | Host config (this repo) | — | DuckDNS, DNS split-horizon, NetworkManager |

## Deployment

- **Dokploy** orchestrates every service from its repo's `docker-compose.yml`.
  Compose projects join the external `dokploy-network`; each
  `docker-compose.prod.yml` override exists only to attach that network.
- **Traefik** (inside Dokploy) terminates TLS and routes `*.leojan.fr` subdomains to
  containers. `APP_PORT` in each `.env` sets the external port; containers keep a
  fixed internal port.
- **DNS**: `leojan.fr` is managed at Squarespace; `dokploy.home.leojan.fr` → DuckDNS
  (`leojan.duckdns.org`, updated by the Fritzbox router). The Pi resolves its own
  subdomains via AdGuard DNS rewrites → `192.168.178.13` to avoid hairpin-NAT. See
  `README.md`.
- **Monitoring**: Netdata (`:19999`) + Glances (`:61208`) run alongside homepage;
  Uptime Kuma (`status.leojan.fr`) probes each service (badges embedded in repo READMEs).

## Conventions

- Every repo pins its external port through `APP_PORT` (see each `.env.example`).
- Secrets live only in each service's `.env` on the Pi — never committed.

## ADR: homepage dashboard uses a curated service list

**Decision:** the homepage dashboard lists services **statically** in
`homepage/config/services.yaml`. gethomepage Docker auto-discovery is **intentionally
disabled** — there is no `homepage/config/docker.yaml`, and the app repos carry **no
`homepage.*` labels**.

**Why:** central control over naming, grouping, icons and ordering, and no clutter from
internal containers (Postgres, Ollama, init jobs). Adding a service is a one-file edit
in the homepage repo.

**Consequence:** when a Pi service is added or renamed, update
`homepage/config/services.yaml` by hand (groups/columns live in
`config/settings.yaml`). Do **not** add `homepage.*` labels to the app repos — they are
ignored while discovery is off. To switch to auto-discovery later, create
`config/docker.yaml` with a `socket: /var/run/docker.sock` instance and label each
container.
