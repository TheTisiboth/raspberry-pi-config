# Electricity cost estimate

Rough monthly cost of running the Pi 5 + the external HDD enclosure, 24/7.
Numbers below are **estimates from published specs and benchmarks, not
measured** — the Pi's onboard PMIC only exposes internal SoC rail currents,
not total wall-socket draw, and the HDD enclosure has its own separate power
supply the Pi has no visibility into at all. For an exact figure, put an
inline power meter ("Energiekostenmessgerät") on each plug for a few days.

## Services running (Dokploy, 21 containers)

| Service | Container(s) | Role | Power profile |
|---|---|---|---|
| Dokploy | `dokploy`, `dokploy-traefik`, `dokploy-postgres`, `dokploy-redis` | Orchestration + reverse proxy | Always-on, light |
| Nextcloud | `nextcloud-app-*` (app, cron, redis, db) | Cloud storage, reads/writes the HDD | Always-on, moderate |
| Frisbee Bot | `frisbee-bot`, `frisbee-ollama` | Telegram bot + local LLM (llama3.2 1b/3b) | Idle low; CPU spikes hard during inference |
| WebCV | `webcv_backend`, `webcv-front`, `webcv_postgres` | Personal CV site + Strapi CMS | Always-on, light |
| Advent Calendar | `adventcalendar-app-*`, postgres | Seasonal app | Always-on, light |
| Vaultwarden | `vaultwarden` | Password manager | Always-on, very light |
| AdGuard Home | `adguardhome` | Network DNS + ad-block | Always-on, very light |
| Homepage | `homepage` | Dashboard | Always-on, very light |
| Uptime Kuma | `uptime-kuma` | Status monitoring | Always-on, very light |
| Netdata | `netdata` | System monitoring | Always-on, light (polls sensors continuously) |
| Glances | `glances` | System monitoring | Always-on, very light |

None of these draw meaningfully different power at the CPU level except
Ollama, which is the only container that pushes the Pi's 4 cores hard (LLM
inference is CPU-bound here — no GPU/NPU on the Pi 5). Everything else is
mostly idle I/O-bound work.

## Hardware

- **Raspberry Pi 5**, official PSU, active PWM fan, 4 cores.
- **OWC Mercury Elite Pro Dual** (USB 3.1 + eSATA, 2×3.5" bays, RAID
  0/1/JBOD). Currently **1 HDD installed** (bay 2 empty). Ships with a
  12V/3A (36W) power adapter — that rating is a *ceiling* sized for two
  drives spinning up simultaneously, not typical running draw.

## Reasoning

**Pi 5:** published wall-power benchmarks put it at roughly 3-4W idle and up
to 10-13W under sustained CPU load. With 21 containers but only Ollama
capable of real load spikes, a reasonable running average is **~6-8W**.

**HDD enclosure:** a single 3.5" 7200RPM drive typically draws ~6-8W idle /
~8-10W active, plus ~1-2W for the enclosure's own bridge/controller chip.
With one drive installed, that's roughly **~7-10W** average — well under the
36W PSU ceiling, which is sized for two drives.

**Combined average: ~13-18W.**

```
kWh/month ≈ (watts / 1000) × 24h × 30.44 days
cost/month ≈ kWh/month × 0.348 €/kWh   (Verbrauchspreis)
```

| Avg watts | kWh/month | Variable cost/month |
|---|---|---|
| 13W | ~9.5 | ~3.30€ |
| 18W | ~13.2 | ~4.59€ |

**Note on the Grundpreis:** the 11.90€/month Grundpreis is a fixed charge on
the whole household electricity contract, paid whether or not the Pi runs
(unless it's on its own dedicated meter). It isn't an incremental cost of
this setup, so it's excluded from the conclusion below — it's the cost of
having electricity at all, not the cost of the server.

## Conclusion

Running the Pi 5 + OWC HDD enclosure 24/7 adds roughly **3-4 €/month** to
the electricity bill (the Grundpreis is unaffected either way). This is an
estimate from spec sheets and published benchmarks, not a measurement — a
plug-in power meter would tighten this range.
