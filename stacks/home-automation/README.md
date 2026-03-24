# Home Automation Stack

Complete home automation solution with Home Assistant, Node-RED, MQTT broker, and Zigbee2MQTT.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Home Assistant | 2024.11.3 | `ha.<DOMAIN>` | Central home automation hub |
| Node-RED | 3.1.14 | `nodered.<DOMAIN>` | Visual flow-based programming |
| Mosquitto | 2.0.20 | — | MQTT message broker |
| Zigbee2MQTT | 1.41.0 | `zigbee.<DOMAIN>` | Zigbee to MQTT bridge |

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │           Home Automation Stack             │
                    │                                             │
Internet ──► Traefik │  ha.<DOMAIN>     → Home Assistant          │
                    │  nodered.<DOMAIN> → Node-RED                │
                    │  zigbee.<DOMAIN>  → Zigbee2MQTT UI          │
                    │                                             │
                    │  ┌─────────────┐    ┌──────────────────┐   │
                    │  │ Mosquitto   │◄───│ Zigbee2MQTT      │   │
                    │  │ (MQTT 1883) │    │ (Zigbee Dongle)  │   │
                    │  └──────┬──────┘    └──────────────────┘   │
                    │         │                                  │
                    │         ├──────────► Home Assistant        │
                    │         └──────────► Node-RED              │
                    └─────────────────────────────────────────────┘
```

## Prerequisites

- Base stack deployed (Traefik + proxy network)
- Docker >= 24.0 with Compose v2 plugin
- **Zigbee USB dongle** (CC2652, CC2531, or Sonoff Zigbee 3.0)
- `./scripts/setup-env.sh` completed (creates `.env`)

## Quick Start

```bash
# From repo root
cd stacks/home-automation
ln -sf ../../.env .env       # share root .env
docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `TZ` | ✅ | Timezone, e.g. `Asia/Shanghai` |
| `CN_MODE` | — | `true` to use CN Docker mirrors |

### Zigbee Adapter Configuration

Edit `docker-compose.yml` to add your Zigbee USB dongle:

```yaml
zigbee2mqtt:
  devices:
    - /dev/ttyACM0:/dev/ttyACM0  # Change to your device path
```

Find your device path:
```bash
ls -l /dev/ttyACM* /dev/ttyUSB*
```

### MQTT Configuration

The default `mosquitto.conf` allows anonymous access. For production:

1. Create password file:
```bash
docker exec mosquitto mosquitto_passwd -c /mosquitto/config/pwfile username
```

2. Update `mosquitto.conf`:
```
listener 1883
allow_anonymous false
password_file /mosquitto/config/pwfile
```

3. Restart Mosquitto:
```bash
docker compose restart mosquitto
```

### Home Assistant Initial Setup

1. Visit `https://ha.<DOMAIN>`
2. Create admin account
3. Add integrations:
   - **MQTT**: Server `mosquitto`, port `1883`
   - **Zigbee2MQTT**: Auto-discovered via MQTT

### Node-RED Initial Setup

1. Visit `https://nodered.<DOMAIN>`
2. Set up admin password on first login
3. Install additional nodes via Palette Manager:
   - `node-red-contrib-home-assistant-websocket`
   - `node-red-contrib-mqtt-broker`

## Common Use Cases

### Connect Home Assistant to MQTT

```yaml
# configuration.yaml
mqtt:
  broker: mosquitto
  port: 1883
  username: your_user
  password: your_password
```

### Node-RED Flow Example

Import this flow to toggle a light via MQTT:

```json
[
  {
    "id": "mqtt-trigger",
    "type": "mqtt in",
    "topic": "home/living-room/light/state",
    "broker": "mosquitto"
  },
  {
    "id": "ha-call",
    "type": "ha-call-service",
    "service": "light.toggle",
    "data": "{\"entity_id\": \"light.living_room\"}"
  }
]
```

## Health Checks

```bash
# Check all services
docker compose ps

# View logs
docker compose logs -f homeassistant
docker compose logs -f node-red
docker compose logs -f mosquitto
docker compose logs -f zigbee2mqtt

# Test MQTT
docker exec mosquitto mosquitto_sub -t 'test/topic' -v
docker exec mosquitto mosquitto_pub -t 'test/topic' -m 'hello'
```

## Troubleshooting

### Zigbee2MQTT Cannot Find Adapter

```bash
# Check device permissions
ls -l /dev/ttyACM0

# Add user to dialout group
sudo usermod -a -G dialout $USER

# Or run privileged (not recommended for production)
```

### Home Assistant Cannot Connect to MQTT

- Ensure both containers are on the same Docker network (`proxy`)
- Use container name `mosquitto` as broker hostname
- Check MQTT credentials if authentication is enabled

### TLS Certificate Issues

```bash
# Check Traefik logs
docker compose logs traefik | grep -i acme

# Force certificate renewal
docker exec traefik traefik healthcheck
```

## Volumes

| Volume | Purpose |
|--------|---------|
| `ha-config` | Home Assistant configuration |
| `node-red-data` | Node-RED flows and credentials |
| `mosquitto-data` | MQTT message persistence |
| `mosquitto-logs` | Mosquitto logs |
| `zigbee2mqtt-data` | Zigbee2MQTT configuration and state |

## Security Notes

- **Privileged mode**: Home Assistant runs in privileged mode for hardware access. Consider using specific device mappings instead.
- **MQTT authentication**: Enable authentication for production deployments.
- **Network isolation**: All services are on the `proxy` network. Consider creating a separate `automation` network for internal communication.

## Resources

- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [Node-RED Documentation](https://nodered.org/docs/)
- [Zigbee2MQTT Documentation](https://www.zigbee2mqtt.io/)
- [Mosquitto Documentation](https://mosquitto.org/documentation/)
