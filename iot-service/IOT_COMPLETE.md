# Krishi Mantra IoT Service - Complete Documentation

> **Production-ready IoT platform for agricultural sensor data collection and processing**

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Quick Start](#quick-start)
4. [Handshake Protocol](#handshake-protocol)
5. [Configuration](#configuration)
6. [Deployment](#deployment)
7. [API Reference](#api-reference)
8. [Development](#development)
9. [Monitoring](#monitoring)

---

## Overview

The Krishi Mantra IoT Service is a comprehensive, production-grade platform for collecting, processing, and storing sensor data from agricultural IoT devices. It features:

✅ **Production-Ready Handshake Protocol** - Secure device authentication and session management  
✅ **Automatic Reconnection** - Exponential backoff with infinite retries  
✅ **Horizontal Scalability** - Microservices architecture with MQTT and ClickHouse  
✅ **Real-time Processing** - Sub-second data ingestion and validation  
✅ **Enterprise Security** - API key authentication, session validation, data encryption  

### Supported Sensors

| Sensor Type | Metrics | Range |
|-------------|---------|-------|
| **Soil** | Moisture, Temperature, pH, NPK | 0-100%, -50-100°C, 0-14 pH |
| **Weather** | Air Temp, Humidity, Pressure, Wind, Rain, Light | -50-60°C, 0-100%, 900-1100 hPa |

---

## Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                    KRISHI MANTRA IOT PLATFORM                        │
└──────────────────────────────────────────────────────────────────────┘

IoT Device                Main Service           IoT Service (Go)
──────────               ──────────────          ────────────────
    │                          │                        │
    ├──1. Handshake Request───────────────────────────►│
    │   {device_id, mac}       │                        │
    │                          │◄──2. Validate Sub──────┤
    │                          │   POST /validate       │
    │                          ├──3. {is_valid}────────►│
    │◄─4. ACK + session_id────────────────────────────┤
    │                          │                        │
    ├──5. Sensor Data─────────────────────────────────►│
    │   {session_id, data}     │                        │
    │                          │                   ┌────┴────┐
    │                          │                   │ Validate│
    │                          │                   │ Session │
    │                          │                   └────┬────┘
    │                          │                        │
    │                          │                   ┌────▼────┐
    │                          │                   │ Route to│
    │                          │                   │Consumer │
    │                          │                   └────┬────┘
    │                          │                        │
    │                          │                   ┌────▼────┐
    │                          │                   │ Store in│
    │                          │                   │ClickHouse│
    │                          │                   └─────────┘
```

### Components

#### 1. **Device Simulator** (`APP_TYPE=device`)
- Simulates soil and weather sensors
- Implements handshake protocol
- Automatic reconnection with exponential backoff
- Heartbeat every 30 seconds

#### 2. **Parser Service** (`APP_TYPE=parser`)
- Handles device handshake and authentication
- Validates sessions via main service API
- Routes data to appropriate consumers
- Manages device connection lifecycle

#### 3. **Soil Consumer** (`APP_TYPE=soil`)
- Validates soil sensor data ranges
- Stores in ClickHouse `soil_data` table
- Rejects invalid data

#### 4. **Weather Consumer** (`APP_TYPE=weather`)
- Validates weather sensor data ranges
- Stores in ClickHouse `weather_data` table
- Rejects invalid data

#### 5. **Main Service** (Node.js)
- Device subscription validation
- User IoT add-on management
- Device linking/unlinking
- Activity logging

---

## Quick Start

### Prerequisites
- Go 1.21+
- Docker & Docker Compose
- Node.js 18+ (for main service)

### 1. Start Infrastructure

```bash
cd /Users/pratik/Desktop/development/Krishi-Mantra
docker-compose -f docker-compose.iot.yml up -d mosquitto clickhouse
```

### 2. Configure Environment

**Main Service (.env):**
```bash
IOT_SERVICE_API_KEY=your-secret-key-here
MONGODB_URL=mongodb://localhost:27017/krishi_mantra
REDIS_HOST=localhost
```

**IoT Service (.env):**
```bash
MAIN_SERVICE_URL=http://localhost:3002
MAIN_SERVICE_API_KEY=your-secret-key-here
MQTT_BROKER_URL=tcp://localhost:1883
CLICKHOUSE_ADDR=localhost:9000
```

### 3. Start Services

```bash
# Terminal 1: Main Service
cd Backend-JS/main-service
npm run dev

# Terminal 2: IoT Parser
cd iot-service
APP_TYPE=parser ./iot-service

# Terminal 3: Soil Consumer
APP_TYPE=soil ./iot-service

# Terminal 4: Weather Consumer
APP_TYPE=weather ./iot-service

# Terminal 5: Device Simulator
APP_TYPE=device DEVICE_ID=test-device-001 ./iot-service
```

### 4. Verify

Check logs for successful handshake:
```
[INFO] Handshake successful - Session ID: 550e8400...
[INFO] Device test-device-001 connected successfully
[INFO] Sent soil data (session: 550e8400...)
```

---

## Handshake Protocol

### Connection States

```
DISCONNECTED → HANDSHAKING → CONNECTED → RECONNECTING
```

### Handshake Flow

**1. Device → Parser: Handshake Request**
```json
{
  "device_id": "device-001",
  "device_type": "soil",
  "mac_address": "AA:BB:CC:DD:EE:FF",
  "firmware_version": "1.0.0"
}
```

**2. Parser → Main Service: Validate Subscription**
```http
POST /api/v1/iot/validate-subscription
X-API-Key: your-secret-key
X-Service: iot-service

{
  "device_id": "device-001",
  "device_type": "soil",
  "mac_address": "AA:BB:CC:DD:EE:FF"
}
```

**3. Main Service → Parser: Validation Response**
```json
{
  "is_valid": true,
  "reason": "ACTIVE",
  "subscription": {
    "device_id": "device-001",
    "user_id": "user123",
    "status": "active",
    "end_date": "2026-12-31T23:59:59Z"
  }
}
```

**4. Parser → Device: ACK Response**
```json
{
  "status": "ACK",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Handshake successful"
}
```

### Heartbeat Mechanism

- **Interval**: 30 seconds
- **Timeout**: 5 minutes (no heartbeat = session expired)
- **Format**:
```json
{
  "device_id": "device-001",
  "session_id": "550e8400...",
  "timestamp": "2026-02-07T01:00:00Z"
}
```

### Retry Logic

- **Initial Delay**: 2 seconds
- **Backoff**: Exponential (2s → 4s → 8s → 16s → 32s → ...)
- **Max Delay**: 5 minutes
- **Max Attempts**: 10 consecutive failures before long delay
- **Total Retries**: Infinite (never gives up)

---

## Configuration

### Environment Variables

#### IoT Service (Go)

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `APP_TYPE` | Service type: `device`, `parser`, `soil`, `weather` | - | ✅ |
| `MQTT_BROKER_URL` | MQTT broker address | `tcp://localhost:1883` | ✅ |
| `CLICKHOUSE_ADDR` | ClickHouse address | `localhost:9000` | ✅ |
| `CLICKHOUSE_DB` | Database name | `krishi_mantra` | ❌ |
| `CLICKHOUSE_USER` | Username | `default` | ❌ |
| `CLICKHOUSE_PASS` | Password | - | ❌ |
| `MAIN_SERVICE_URL` | Main service URL | `http://localhost:3002` | ✅ |
| `MAIN_SERVICE_API_KEY` | API key for auth | - | ✅ |
| `DEVICE_ID` | Device identifier (for simulator) | - | ✅ (device mode) |
| `SENSOR_INTERVAL` | Data send interval (seconds) | `10` | ❌ |

#### Main Service (Node.js)

| Variable | Description | Required |
|----------|-------------|----------|
| `IOT_SERVICE_API_KEY` | API key for IoT service auth | ✅ |
| `MONGODB_URL` | MongoDB connection string | ✅ |
| `REDIS_HOST` | Redis host | ✅ |
| `JWT_SECRET` | JWT signing secret | ✅ |

---

## Deployment

### Docker Compose (Development)

```bash
docker-compose -f docker-compose.iot.yml up -d
```

Services started:
- Mosquitto MQTT (port 1883)
- ClickHouse (port 9000, 8123)
- IoT Device Simulator
- Parser Service
- Soil Consumer
- Weather Consumer

### Kubernetes (Production)

```bash
# Apply configurations
kubectl apply -f deployment/IoT-Service/

# Verify deployments
kubectl get pods -l app=iot-service

# Check logs
kubectl logs -f deployment/iot-parser
```

**Deployments:**
- `iot-parser` (replicas: 2)
- `iot-soil-consumer` (replicas: 2)
- `iot-weather-consumer` (replicas: 2)
- `iot-device-simulator` (replicas: 1)

**Auto-scaling:**
- HPA enabled (CPU: 70%, Memory: 80%)
- Min replicas: 2
- Max replicas: 10

---

## API Reference

### Main Service IoT Endpoints

Base URL: `http://localhost:3002/api/v1/iot`

#### 1. Health Check
```http
GET /health
```

**Response:**
```json
{
  "success": true,
  "message": "IoT API is healthy",
  "timestamp": "2026-02-07T01:00:00Z"
}
```

#### 2. Validate Device Subscription
```http
POST /validate-subscription
X-API-Key: your-secret-key
X-Service: iot-service

{
  "device_id": "device-001",
  "device_type": "soil",
  "mac_address": "AA:BB:CC:DD:EE:FF"
}
```

**Response:**
```json
{
  "is_valid": true,
  "reason": "ACTIVE",
  "subscription": {
    "device_id": "device-001",
    "user_id": "user123",
    "subscription_id": "sub456",
    "status": "active",
    "plan_name": "IoT Basic",
    "end_date": "2026-12-31T23:59:59Z"
  }
}
```

#### 3. Get Device Subscription
```http
GET /devices/:deviceId/subscription
X-API-Key: your-secret-key
X-Service: iot-service
```

#### 4. Update Device Status
```http
PUT /devices/:deviceId/status
X-API-Key: your-secret-key
X-Service: iot-service

{
  "status": "ONLINE",
  "timestamp": "2026-02-07T01:00:00Z",
  "metadata": {
    "session_id": "550e8400..."
  }
}
```

#### 5. Log Device Activity
```http
POST /devices/activity
X-API-Key: your-secret-key
X-Service: iot-service

{
  "device_id": "device-001",
  "activity_type": "DATA_SENT",
  "details": {
    "sensor_type": "soil",
    "data_points": 6
  },
  "timestamp": "2026-02-07T01:00:00Z"
}
```

### MQTT Topics

| Topic | Direction | Purpose |
|-------|-----------|---------|
| `krishi/handshake/request` | Device → Parser | Handshake initiation |
| `krishi/handshake/response/{device_id}` | Parser → Device | ACK/NACK response |
| `krishi/heartbeat/request` | Device → Parser | Heartbeat ping |
| `krishi/heartbeat/response/{device_id}` | Parser → Device | Heartbeat ACK |
| `krishi/sensors/raw` | Device → Parser | Raw sensor data |
| `krishi/sensors/soil` | Parser → Consumer | Validated soil data |
| `krishi/sensors/weather` | Parser → Consumer | Validated weather data |
| `krishi/disconnect` | Device → Parser | Graceful disconnect |

---

## Development

### Project Structure

```
iot-service/
├── cmd/main/main.go              # Entry point
├── pkg/
│   ├── api/client.go              # Main service API client
│   ├── config/config.go           # Configuration
│   ├── connection/manager.go      # Connection lifecycle
│   ├── consumers/
│   │   ├── parser.go              # Parser consumer
│   │   ├── soil.go                # Soil consumer
│   │   └── weather.go             # Weather consumer
│   ├── database/clickhouse.go     # ClickHouse operations
│   ├── device/simulator.go        # Device simulator
│   ├── handlers/handshake.go      # Handshake handler
│   ├── metrics/metrics.go         # Metrics collection
│   ├── models/
│   │   ├── sensor.go              # Sensor data models
│   │   ├── handshake.go           # Handshake models
│   │   └── subscription.go        # Subscription models
│   ├── mqtt/client.go             # MQTT client wrapper
│   └── session/manager.go         # Session management
└── Dockerfile
```

### Building

```bash
# Build binary
make build

# Run tests
make test

# Test coverage
make test-coverage

# Clean build artifacts
make clean
```

### Running Tests

```bash
# All tests
go test ./... -v

# With coverage
go test ./... -cover

# Specific package
go test ./pkg/session -v
```

**Test Results:**
```
✅ pkg/config: 2/2 tests pass
✅ pkg/connection: 2/2 tests pass
✅ pkg/models: 2/2 tests pass
✅ pkg/session: 6/6 tests pass
```

### Adding New Sensor Types

1. **Update Models** (`pkg/models/sensor.go`):
```go
type HumidityData struct {
    DeviceID  string    `json:"device_id"`
    Timestamp time.Time `json:"timestamp"`
    Humidity  float64   `json:"humidity"`
}
```

2. **Create Consumer** (`pkg/consumers/humidity.go`):
```go
func StartHumidityConsumer(cfg *config.Config) error {
    // Subscribe to krishi/sensors/humidity
    // Validate data
    // Save to ClickHouse
}
```

3. **Create ClickHouse Table**:
```sql
CREATE TABLE humidity_data (
    device_id String,
    timestamp DateTime,
    humidity Float64
) ENGINE = MergeTree()
ORDER BY (device_id, timestamp);
```

4. **Update Main** (`cmd/main/main.go`):
```go
case "humidity":
    err = consumers.StartHumidityConsumer(cfg)
```

---

## Monitoring

### Metrics Tracked

**Handshake Metrics:**
- Total attempts
- Success/failure count
- Success rate percentage

**Session Metrics:**
- Active sessions
- Total sessions created
- Expired sessions
- Average session duration

**Data Metrics:**
- Messages received
- Messages processed
- Messages rejected
- Processing success rate

**Connection Metrics:**
- Reconnection attempts
- Heartbeats sent/received
- Connection uptime

### Logging

All services use structured logging:

```
[INFO] 2026-02-07 01:00:00 - Handshake successful - Session ID: 550e8400...
[INFO] 2026-02-07 01:00:30 - Sent soil data (session: 550e8400...)
[WARN] 2026-02-07 01:01:00 - Connection lost, attempting reconnection
[INFO] 2026-02-07 01:01:02 - Reconnected successfully
```

### Health Checks

**IoT Service:**
- MQTT connection status
- ClickHouse connection status
- Active sessions count

**Main Service:**
```bash
curl http://localhost:3002/api/v1/iot/health
```

---

## Database Schema

### ClickHouse Tables

**soil_data:**
```sql
CREATE TABLE soil_data (
    device_id String,
    timestamp DateTime,
    moisture Float64,
    temperature Float64,
    ph Float64,
    nitrogen Float64,
    phosphorus Float64,
    potassium Float64
) ENGINE = MergeTree()
ORDER BY (device_id, timestamp);
```

**weather_data:**
```sql
CREATE TABLE weather_data (
    device_id String,
    timestamp DateTime,
    air_temp Float64,
    humidity Float64,
    pressure Float64,
    wind_speed Float64,
    rainfall Float64,
    light_level Float64
) ENGINE = MergeTree()
ORDER BY (device_id, timestamp);
```

### MongoDB Collections (Main Service)

**UserIotAddon:**
- User IoT subscriptions
- Linked devices
- Device status and metadata

---

## Security

### Authentication
- **API Key**: X-API-Key header for service-to-service
- **Service Identifier**: X-Service header validation
- **Session IDs**: UUID-based, 5-minute timeout

### Data Validation
- Sensor value range checks
- MAC address verification
- Firmware version tracking
- Timestamp freshness validation

### Network Security
- TLS/SSL for MQTT (production)
- Encrypted ClickHouse connections
- Rate limiting on API endpoints

---

## Troubleshooting

### Device Won't Connect

**Check:**
1. MQTT broker is running: `docker ps | grep mosquitto`
2. Device has valid subscription in main service
3. API key matches in both services
4. Check logs: `tail -f logs/iot-service.log`

### Data Not Appearing in ClickHouse

**Check:**
1. Consumer is running: `ps aux | grep iot-service`
2. ClickHouse is accessible: `clickhouse-client --query "SELECT 1"`
3. Tables exist: `SHOW TABLES FROM krishi_mantra`
4. Check validation errors in logs

### Session Expired Errors

**Causes:**
- No heartbeat for 5+ minutes
- Device reconnected with new session
- Parser service restarted

**Solution:**
- Device will auto-reconnect
- Check network connectivity
- Verify heartbeat interval (30s)

---

## Production Checklist

- [ ] Set strong `IOT_SERVICE_API_KEY`
- [ ] Enable TLS for MQTT broker
- [ ] Configure ClickHouse authentication
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure log aggregation
- [ ] Set up alerting for device disconnections
- [ ] Enable HPA for auto-scaling
- [ ] Configure backup for ClickHouse
- [ ] Set up Redis for session storage (multi-instance)
- [ ] Review and adjust rate limits

---

## License

Part of the Krishi Mantra platform.

**Version:** 1.0.0  
**Last Updated:** February 7, 2026  
**Status:** Production Ready ✅
