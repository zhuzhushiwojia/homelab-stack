# Network Stack

Complete network services stack with AdGuard Home (DNS ad-blocking), WireGuard Easy (VPN), and Nginx Proxy Manager (reverse proxy UI).

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| AdGuard Home | v0.107.55 | `adguard.<DOMAIN>` | Network-wide ad blocking & DNS server |
| WireGuard | 1.0.20210914 | `wg.<DOMAIN>` | VPN server for secure remote access |
| Nginx Proxy Manager | 2.11.3 | `npm.<DOMAIN>` | Reverse proxy management UI |

## Architecture

```
                    ┌─────────────────────────────────────────────────┐
                    │              Network Stack                      │
                    │                                                 │
Internet ──► Traefik │  adguard.<DOMAIN> → AdGuard Home (DNS/AdBlock) │
                    │  wg.<DOMAIN>      → WireGuard Web UI           │
                    │  npm.<DOMAIN>     → Nginx Proxy Manager        │
                    │                                                 │
                    │  ┌──────────────┐  ┌──────────────────────┐   │
                    │  │ AdGuard Home │  │ WireGuard            │   │
                    │  │ Port 53 DNS  │  │ Port 51820 UDP       │   │
                    │  └──────────────┘  └──────────────────────┘   │
                    │                                                 │
                    │  Nginx Proxy Manager (internal proxy mgmt)     │
                    └─────────────────────────────────────────────────┘
```

## Prerequisites

- Base stack deployed (Traefik + proxy network)
- Docker >= 24.0 with Compose v2 plugin
- Root/sudo access for port 53 binding (or use `setcap`)
- `./scripts/setup-env.sh` completed (creates `.env`)

## Quick Start

```bash
# From repo root
cd stacks/network
ln -sf ../../.env .env       # share root .env
docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | ✅ | — | Base domain, e.g. `home.example.com` |
| `TZ` | ✅ | `Asia/Shanghai` | Timezone |
| `CN_MODE` | — | `false` | `true` to use CN Docker mirrors |
| `WG_SERVER_URL` | — | `auto` | WireGuard server URL (auto-detect or set manually) |
| `WG_SERVER_PORT` | — | `51820` | WireGuard UDP port |
| `WG_INTERNAL_SUBNET` | — | `10.13.13.0` | VPN internal subnet |

### Port Requirements

| Port | Protocol | Service | Notes |
|------|----------|---------|-------|
| 53 | TCP/UDP | AdGuard Home | DNS server (requires root or setcap) |
| 67/68 | UDP | AdGuard Home | DHCP server (optional) |
| 51820 | UDP | WireGuard | VPN server |
| 8181 | TCP | Nginx Proxy Manager | Web UI (internal only) |

### DNS Configuration (Important!)

After AdGuard Home starts, configure your network to use it:

**Option 1: Router DNS** (Recommended)
1. Access your router admin panel
2. Set DNS server to your host IP (e.g., `192.168.1.100`)
3. All devices will use AdGuard automatically

**Option 2: Per-Device DNS**
- Configure DNS manually on each device to your host IP

**Option 3: Test First**
```bash
# Test AdGuard DNS resolution
dig @192.168.1.100 google.com
```

### WireGuard Setup

1. Access WireGuard Web UI: `https://wg.<DOMAIN>`
2. Click "Add Peer" to create new client configurations
3. Download `.conf` file for each device
4. Import into WireGuard client app

**WireGuard Client Apps:**
- [iOS/Android](https://www.wireguard.com/install/)
- [Windows](https://www.wireguard.com/install/)
- [macOS](https://www.wireguard.com/install/)
- [Linux](https://www.wireguard.com/install/)

### Nginx Proxy Manager Usage

NPM provides a GUI for managing reverse proxies:

1. Access: `https://npm.<DOMAIN>`
2. Default login: `admin@example.com` / `changeme`
3. Create proxy hosts for services not managed by Traefik

## Common Use Cases

### Block Ads Network-Wide

1. Access AdGuard: `https://adguard.<DOMAIN>`
2. Complete initial setup wizard
3. Enable filter lists:
   - AdGuard DNS filter
   - AdGuard Mobile Ads filter
   - OISD Big (comprehensive)
4. Set as your DNS server (see DNS Configuration above)

### Remote Access via VPN

1. Create peer config in WireGuard UI
2. Import config to your phone/laptop
3. Connect to VPN when outside home network
4. Access all home services securely

### Custom DNS Filters

Add custom block lists in AdGuard:

```
# Example: Block social media
||facebook.com^
||twitter.com^
||instagram.com^
```

### DHCP Server (Optional)

Enable DHCP in AdGuard Home if you want it to manage IP assignments:

1. Settings → DHCP Server
2. Enable DHCP
3. Configure range: `192.168.1.100-192.168.1.200`
4. Gateway: `192.168.1.1`
5. DNS: `192.168.1.1` (AdGuard itself)

## Health Checks

```bash
# Check all services
docker compose ps

# View logs
docker compose logs -f adguardhome
docker compose logs -f wireguard
docker compose logs -f nginx-proxy-manager

# Test DNS resolution
dig @localhost google.com

# Test WireGuard
docker exec wireguard wg show

# Test NPM health
curl http://localhost:3000/api/health
```

## Troubleshooting

### Port 53 Permission Denied

```bash
# Option 1: Run with elevated privileges (not recommended)
sudo docker compose up -d

# Option 2: Grant CAP_NET_BIND_SERVICE
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/docker

# Option 3: Use non-standard port (edit docker-compose.yml)
ports:
  - "5353:53/tcp"
  - "5353:53/udp"
```

### WireGuard Connection Fails

```bash
# Check if module is loaded
lsmod | grep wireguard

# Load module if needed
sudo modprobe wireguard

# Check firewall
sudo ufw allow 51820/udp
```

### AdGuard Dashboard Not Loading

```bash
# Check if port 3000 is accessible
docker exec adguardhome wget -qO- http://localhost:3000

# Restart service
docker compose restart adguardhome
```

### DNS Not Working for Clients

1. Ensure AdGuard container is running
2. Check firewall allows port 53
3. Verify client DNS settings point to host IP
4. Test from host: `dig @127.0.0.1 google.com`

## Volumes

| Volume | Purpose |
|--------|---------|
| `adguard-work` | AdGuard Home working data |
| `adguard-conf` | AdGuard Home configuration |
| `wireguard-config` | WireGuard keys and peer configs |
| `npm-data` | Nginx Proxy Manager data |
| `npm-letsencrypt` | SSL certificates |

## Security Notes

- **Port 53**: Requires elevated privileges. Consider using `setcap` instead of running as root.
- **WireGuard**: Keep peer configs secure. Each peer has unique keys.
- **NPM Default Password**: Change immediately after first login!
- **DNS over HTTPS**: Consider enabling DoH in AdGuard for upstream privacy.

## Advanced Configuration

### Custom Upstream DNS in AdGuard

Edit AdGuard config to use specific upstreams:

```yaml
upstream_dns:
  - tls://1.1.1.1
  - tls://8.8.8.8
  - https://dns.quad9.net/dns-query
```

### WireGuard Split Tunneling

Only route specific traffic through VPN:

```ini
# Client config
[Interface]
PrivateKey = <your-private-key>
Address = 10.13.13.2/24
DNS = 10.13.13.1

# Only route home network through VPN
[Peer]
PublicKey = <server-public-key>
Endpoint = your-home.example.com:51820
AllowedIPs = 192.168.1.0/24, 10.13.13.0/24
```

### Block YouTube Ads

Add to AdGuard DNS blocklist:

```
||youtube.com/pagead/
||googlevideo.com/pagead/
||youtube.com/get_video_info?*adformat=
```

## Resources

- [AdGuard Home Documentation](https://adguard.com/en/adguard-home/overview.html)
- [WireGuard Documentation](https://www.wireguard.com/)
- [Nginx Proxy Manager Documentation](https://nginxproxymanager.com/)
- [DNS-over-HTTPS Providers](https://github.com/curl/curl/wiki/DNS-over-HTTPS)
