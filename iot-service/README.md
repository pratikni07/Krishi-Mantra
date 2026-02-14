# Krishi Mantra IoT Service

> **Production-ready IoT platform for agricultural sensor data collection and processing**

## 📚 Documentation

**For complete documentation, see [IOT_COMPLETE.md](./IOT_COMPLETE.md)**

This comprehensive guide covers:
- Architecture & System Design
- Handshake Protocol & Security
- Quick Start & Deployment
- API Reference
- Development Guide
- Monitoring & Troubleshooting

## 🚀 Quick Start

### 1. Start Infrastructure
```bash
docker-compose -f docker-compose.iot.yml up -d mosquitto clickhouse
```

### 2. Configure Environment
```bash
# IoT Service
export MAIN_SERVICE_URL=http://localhost:3002
export MAIN_SERVICE_API_KEY=your-secret-key
export MQTT_BROKER_URL=tcp://localhost:1883
export CLICKHOUSE_ADDR=localhost:9000

# Main Service
export IOT_SERVICE_API_KEY=your-secret-key
```

### 3. Run Services
```bash
# Parser
APP_TYPE=parser ./iot-service

# Consumers
APP_TYPE=soil ./iot-service
APP_TYPE=weather ./iot-service

# Device Simulator
APP_TYPE=device DEVICE_ID=test-001 ./iot-service
```

## ✅ Features

- ✅ **Secure Handshake Protocol** - Device authentication & session management
- ✅ **Automatic Reconnection** - Exponential backoff with infinite retries
- ✅ **Horizontal Scalability** - Microservices architecture
- ✅ **Real-time Processing** - Sub-second data ingestion
- ✅ **Enterprise Security** - API key auth, session validation

## 🏗️ Architecture

```
IoT Device → MQTT → Parser → Consumers → ClickHouse
                      ↓
                Main Service (Validation)
```

## 📊 Supported Sensors

| Type | Metrics |
|------|---------|
| **Soil** | Moisture, Temperature, pH, NPK |
| **Weather** | Air Temp, Humidity, Pressure, Wind, Rain, Light |

## 🧪 Testing

```bash
# Build
make build

# Run tests
make test

# Coverage
make test-coverage
```

**Test Results:** ✅ 12/12 tests pass

## 📖 Full Documentation

See [IOT_COMPLETE.md](./IOT_COMPLETE.md) for:
- Detailed architecture diagrams
- Complete API reference
- Deployment guides (Docker, Kubernetes)
- Development workflows
- Monitoring & metrics
- Troubleshooting guide

## 📝 License

Part of the Krishi Mantra platform.
