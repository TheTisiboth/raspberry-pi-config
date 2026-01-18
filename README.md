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
