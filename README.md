# Raspberry Pi 5 Configuration

## DuckDNS Setup

**Purpose:** Keep home IP updated for external access to Pi services

**Setup:**
- Service: DuckDNS (duckdns.org)
- Domain: `leojan.duckdns.org`
- Configured in: Fritzbox 7530 AX router
- Location: Internet → Permit Access → DynDNS

**Fritzbox config:**
```
Update URL: https://www.duckdns.org/update?domains=leojan&token=<token>&ip=<ipaddr>
Domain names: leojan.duckdns.org
Username: <dummy>
Password: <dummy>
```

**DNS:**
- Squarespace manages leojan.fr
- CNAME: dokploy.home.leojan.fr → leojan.duckdns.org

**Port forwarding:**
- Ports 80, 443 → Pi local IP

**No scripts needed on Pi** - Fritzbox handles DynDNS updates

## DNS Configuration (Split-horizon)                                                 
                                                                                       
Services hosted on the Pi are monitored by Uptime Kuma (also on the Pi). By default, 
domain names like `dot.leojan.fr` resolve to the public IP, causing hairpin NAT      
failures when the Pi tries to reach itself through the router.

**Fix:** The Pi uses AdGuard Home (running locally on port 53) as its primary DNS
resolver, with the Fritzbox as fallback.

**NetworkManager config** (`/etc/NetworkManager/system-connections/Wired connection
1.nmconnection`):
- `dns=127.0.0.1;192.168.178.1;` — AdGuard first, Fritzbox as fallback
- `ignore-auto-dns=true` — prevents DHCP from overriding the DNS setting

**AdGuard DNS rewrites** (at `adguard.leojan.fr` → Filters → DNS rewrites):
- Per-service rewrites only (e.g. `dot.leojan.fr` → `192.168.178.13`) — not a
wildcard, since other `leojan.fr` subdomains are hosted on a separate VPS

The config file is tracked at `network/NetworkManager/system-connections/Wired
connection 1.nmconnection`.
