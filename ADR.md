# Pi5 stack — architecture decision records

Decisions that span several repos of the Pi stack (`~/projects/pi`). Stack overview:
[`ARCHITECTURE.md`](ARCHITECTURE.md).

Add a new ADR at the bottom with the next number. Don't rewrite an accepted one: mark it
**Superseded by ADR-XXX** and add a new one.

---

## ADR-001: homepage dashboard uses a curated service list

**Status:** Accepted

**Decision:** the homepage dashboard lists services **statically** in
`homepage/config/services.yaml`. gethomepage Docker auto-discovery is **intentionally
disabled**: the app repos carry **no `homepage.*` labels**. `homepage/config/docker.yaml`
only exposes the Docker socket (`my-docker`), so a hand-listed service can reference
`server` + `container` to get a status dot. It does not discover anything.

**Why:** central control over naming, grouping, icons and ordering, and no clutter from
internal containers (Postgres, Ollama, init jobs). Adding a service is a one-file edit
in the homepage repo.

**Consequence:** do **not** add `homepage.*` labels to the app repos, they are ignored.
To switch to auto-discovery later, label each container and drop the hand-written entries.

---

## ADR-002: every new Pi service must be registered in homepage

**Status:** Accepted

**Context:** because of ADR-001, a new service does not show up on the dashboard by itself.
A new repo deployed through Dokploy runs fine but stays invisible on
https://dashboard.leojan.fr, and nothing warns about it.

**Decision:** creating (or renaming, or removing) a service repo deployed on the Pi is
not done until the homepage repo references it. The checklist:

1. **`homepage/config/services.yaml`**: add an entry to the right group (groups and
   columns live in `config/settings.yaml`, apps go under `Applications`):
   ```yaml
   - My Service:
       icon: my-service.png          # dashboard-icons name, or mdi-* / si-*
       href: https://my-service.leojan.fr   # omit if there is no web UI
       description: One-line purpose
       siteMonitor: http://<container_name>:<internal_port>   # health dot, over dokploy-network
   ```
   Use the container's **internal** port (not `APP_PORT`), and a health endpoint when
   the root URL isn't one (e.g. `http://frisbee-bot:3004/health`).
2. **`raspberry-pi-config/ARCHITECTURE.md`**: add a row to the Services table.
3. Push both repos. Dokploy redeploys homepage on push, so the entry is not live before.

**Why:** the dashboard is the single entry point to the stack. A service missing from it
gets forgotten, and its health dot is the quickest way to spot it being down.

**Consequence:** one extra commit in `homepage` per new service. Internal-only
containers (databases, model servers, one-shot jobs) are not services and are not listed.
