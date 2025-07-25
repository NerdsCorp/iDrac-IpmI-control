# Dell iDRAC Fan Control 🌡️

[![Docker Build](https://github.com/NerdsCorp/iDrac-IpmI-control/actions/workflows/docker-build.yml/badge.svg)](https://github.com/NerdsCorp/iDrac-IpmI-control/actions/workflows/docker-build.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/ghcr.io/nerdscorp/idrac-ipmi-control)](https://github.com/NerdsCorp/iDrac-IpmI-control/pkgs/container/idrac-ipmi-control)
[![License](https://img.shields.io/github/license/NerdsCorp/iDrac-IpmI-control)](LICENSE)

A Docker-based solution for intelligent fan control on Dell PowerEdge servers using iDRAC IPMI commands. This script provides fine-grained temperature-based fan speed control to keep your servers cool while minimizing noise.

## ✨ Features

- **Fine-Grained Control**: 14 temperature thresholds with fan speeds from 5% to 60%
- **Safety First**: Emergency failsafe switches to dynamic control at high temperatures
- **Hysteresis Prevention**: Prevents fan speed oscillation with intelligent temperature buffering
- **Docker Ready**: Containerized for easy deployment and management
- **Multi-Architecture**: Supports both AMD64 and ARM64 platforms
- **Comprehensive Logging**: Multiple log levels with timestamps for monitoring
- **Health Monitoring**: Built-in health checks and error handling

## 🎯 Temperature Response Curve

| Temperature Range | Fan Speed | Description |
|-------------------|-----------|-------------|
| 0-12°C | 5% | Ultra-quiet for cold environments |
| 13-15°C | 10% | Very quiet |
| 16-18°C | 15% | Quiet operation |
| 19-20°C | 18% | Low noise |
| 21-22°C | 20% | Balanced |
| 23-24°C | 22% | Slightly increased |
| 25-26°C | 25% | Moderate |
| 27-28°C | 28% | Increased cooling |
| 29-30°C | 30% | Higher cooling |
| 31-32°C | 35% | Strong cooling |
| 33-34°C | 40% | High cooling |
| 35-36°C | 45% | Very high cooling |
| 37-38°C | 50% | Maximum normal operation |
| 39°C+ | 60% | High-performance cooling |
| 40°C+ | Dynamic | Emergency failsafe mode |

## 🚀 Quick Start

### Using Docker Compose (Recommended)

1. **Download the docker-compose.yml**:
   ```bash
   curl -o docker-compose.yml https://raw.githubusercontent.com/NerdsCorp/iDrac-IpmI-control/main/docker-compose.yml
   ```

2. **Edit your iDRAC credentials**:
   ```yaml
   environment:
     IDRAC_HOST: "192.168.1.100"    # Your iDRAC IP
     IDRAC_USER: "root"             # Your iDRAC username
     IDRAC_PASS: "your-password"    # Your iDRAC password
   ```

3. **Start the container**:
   ```bash
   docker-compose up -d
   ```

### Using Docker Run

```bash
docker run -d \
  --name dell-fan-control \
  --network host \
  --restart unless-stopped \
  -e IDRAC_HOST="192.168.1.100" \
  -e IDRAC_USER="root" \
  -e IDRAC_PASS="your-password" \
  ghcr.io/nerdscorp/idrac-ipmi-control:latest
```

## ⚙️ Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `IDRAC_HOST` | ✅ | - | iDRAC IP address |
| `IDRAC_USER` | ✅ | - | iDRAC username |
| `IDRAC_PASS` | ✅ | - | iDRAC password |
| `LOG_LEVEL` | ❌ | `info` | Logging level: `debug`, `info`, `warn`, `error` |
| `CHECK_INTERVAL` | ❌ | `30` | Seconds between temperature checks |
| `TEMP_SENSOR` | ❌ | `04h` | Temperature sensor ID |
| `MAX_TEMP_THRESHOLD` | ❌ | `40` | Emergency temperature threshold (°C) |
| `HYSTERESIS` | ❌ | `2` | Temperature change required for speed reduction |

### Temperature Sensors

| Sensor ID | Description |
|-----------|-------------|
| `04h` | Inlet Temperature (default) |
| `01h` | Exhaust Temperature |
| `0Eh` | CPU 1 Temperature |
| `0Fh` | CPU 2 Temperature |

## 📊 Monitoring

### View Real-Time Logs
```bash
docker logs -f dell-fan-control
```

### Check Container Health
```bash
docker ps
docker stats dell-fan-control
```

### Manual Temperature Check
```bash
docker exec dell-fan-control ipmitool -I lanplus \
  -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PASS \
  sensor reading "Ambient Temp"
```

## 🔧 Compatible Hardware

This script is designed for **Dell PowerEdge Generation 12+ servers** including:

### Rack Servers
- R320, R420, R520, R620, R720, R820
- R330, R430, R530, R630, R730, R830
- R340, R440, R540, R640, R740, R840
- R350, R450, R550, R650, R750, R850
- And newer generations

### Tower Servers  
- T320, T420, T620
- T330, T430, T630
- T340, T440, T640
- T350, T450, T650

### Notes
- **Tower servers** (T-series) may show higher inlet temperatures as the sensor is positioned after the hard drives
- **Older generation** servers may have different IPMI command structures
- **Some servers** may enforce hardware minimum fan speeds regardless of software commands

## 🛠️ Development

### Building Locally

```bash
git clone https://github.com/NerdsCorp/iDrac-IpmI-control.git
cd iDrac-IpmI-control
docker build -t dell-fan-control .
```

### Testing

```bash
# Test with debug logging
docker run --rm -it \
  --network host \
  -e IDRAC_HOST="your-idrac-ip" \
  -e IDRAC_USER="root" \
  -e IDRAC_PASS="your-password" \
  -e LOG_LEVEL="debug" \
  dell-fan-control
```

## 🚨 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **Connection refused** | Verify iDRAC IP, username, and password |
| **Permission denied** | Check network connectivity to iDRAC |
| **Invalid temperature** | Verify temperature sensor ID is correct |
| **Fan speed not changing** | Some Dell servers have hardware minimum speeds |
| **Script stops unexpectedly** | Check logs with `docker logs dell-fan-control` |

### Debug Mode

Enable detailed logging to diagnose issues:

```bash
docker run -d \
  --name dell-fan-control-debug \
  --network host \
  -e IDRAC_HOST="your-idrac-ip" \
  -e IDRAC_USER="root" \
  -e IDRAC_PASS="your-password" \
  -e LOG_LEVEL="debug" \
  -e CHECK_INTERVAL="10" \
  ghcr.io/nerdscorp/idrac-ipmi-control:latest
```

### Manual IPMI Commands

Test IPMI connectivity manually:

```bash
# Check temperature sensors
ipmitool -I lanplus -H <idrac-ip> -U <username> -P <password> sdr type temperature

# Enable manual fan control
ipmitool -I lanplus -H <idrac-ip> -U <username> -P <password> raw 0x30 0x30 0x01 0x00

# Set fan speed to 20%
ipmitool -I lanplus -H <idrac-ip> -U <username> -P <password> raw 0x30 0x30 0x02 0xff 0x14

# Restore automatic control
ipmitool -I lanplus -H <idrac-ip> -U <username> -P <password> raw 0x30 0x30 0x01 0x01
```

## ⚠️ Safety & Disclaimers

- **Use at your own risk**: Improper fan control can cause hardware damage
- **Monitor temperatures**: Always ensure adequate cooling for your hardware
- **Emergency failsafe**: Script automatically enables dynamic control at 40°C+ (configurable)
- **Graceful shutdown**: Container restores automatic fan control when stopped
- **Hardware limits**: Some servers enforce minimum fan speeds regardless of commands

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original script inspiration from [brezlord/iDRAC7_fan_control](https://github.com/brezlord/iDRAC7_fan_control)
- Dell community for IPMI command documentation
- Contributors and testers who helped improve this project

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/NerdsCorp/iDrac-IpmI-control/issues)
- **Discussions**: [GitHub Discussions](https://github.com/NerdsCorp/iDrac-IpmI-control/discussions)
- **Wiki**: [Project Wiki](https://github.com/NerdsCorp/iDrac-IpmI-control/wiki)

---

⭐ **Star this repository** if it helped you keep your servers cool and quiet!
