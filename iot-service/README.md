# Krishi Mantra IoT Service

A comprehensive IoT service for collecting, processing, and storing sensor data from agricultural IoT devices. Similar to Fasal IoT device, this service supports soil, weather, and humidity sensors.

## Architecture

```
IoT Device Simulator → MQTT (Mosquitto) → Parser Service → Soil/Weather Services → ClickHouse DB
```

### Components

1. **IoT Device Simulator** (`APP_TYPE=device`)
   - Simulates soil and weather sensors
   - Sends data every 10 seconds (configurable)
   - Publishes to `krishi/sensors/raw` MQTT topic

2. **Parser Service** (`APP_TYPE=parser`)
   - Subscribes to `krishi/sensors/raw` topic
   - Parses sensor data
   - Routes to appropriate topics:
     - `krishi/sensors/soil` for soil data
     - `krishi/sensors/weather` for weather data

3. **Soil Consumer** (`APP_TYPE=soil`)
   - Subscribes to `krishi/sensors/soil` topic
   - Validates soil sensor data
   - Saves to ClickHouse `soil_data` table

4. **Weather Consumer** (`APP_TYPE=weather`)
   - Subscribes to `krishi/sensors/weather` topic
   - Validates weather sensor data
   - Saves to ClickHouse `weather_data` table

## Sensor Data

### Soil Sensors
- **Moisture**: 0-100%
- **Temperature**: -50 to 100°C
- **pH**: 0-14
- **Nitrogen**: 0+ mg/kg
- **Phosphorus**: 0+ mg/kg
- **Potassium**: 0+ mg/kg

### Weather Sensors
- **Air Temperature**: -50 to 60°C
- **Humidity**: 0-100%
- **Pressure**: 900-1100 hPa
- **Wind Speed**: 0+ m/s
- **Rainfall**: 0+ mm
- **Light Level**: 0+ lux

## Configuration

Create a `.env` file based on `.env.example`:

```bash
# Application type - determines which service to run
APP_TYPE=parser

# MQTT Configuration
MQTT_BROKER_URL=tcp://localhost:1883
MQTT_CLIENT_ID=krishi-mantra-iot

# ClickHouse Configuration
CLICKHOUSE_ADDR=localhost:9000
CLICKHOUSE_DB=krishi_mantra
CLICKHOUSE_USER=default
CLICKHOUSE_PASS=

# Device Simulator Configuration
DEVICE_ID=device-001
SENSOR_INTERVAL=10
```

## Running Locally

### Prerequisites
- Go 1.21+
- Docker and Docker Compose
- MQTT Broker (Mosquitto)
- ClickHouse

### Using Docker Compose

Start all infrastructure and IoT services:

```bash
docker-compose -f docker-compose.iot.yml up -d
```

This will start:
- Mosquitto MQTT broker
- ClickHouse database
- IoT Device Simulator
- Parser Service
- Soil Consumer
- Weather Consumer

### Building from Source

```bash
cd iot-service
go mod download
go build -o iot-service ./cmd/main
```

### Running Different Service Types

**Device Simulator:**
```bash
export APP_TYPE=device
export DEVICE_ID=device-001
export MQTT_BROKER_URL=tcp://localhost:1883
export SENSOR_INTERVAL=10
./iot-service
```

**Parser Service:**
```bash
export APP_TYPE=parser
export MQTT_BROKER_URL=tcp://localhost:1883
./iot-service
```

**Soil Consumer:**
```bash
export APP_TYPE=soil
export MQTT_BROKER_URL=tcp://localhost:1883
export CLICKHOUSE_ADDR=localhost:9000
./iot-service
```

**Weather Consumer:**
```bash
export APP_TYPE=weather
export MQTT_BROKER_URL=tcp://localhost:1883
export CLICKHOUSE_ADDR=localhost:9000
./iot-service
```

## Deployment

### Kubernetes

Deploy all IoT services to Kubernetes:

```bash
kubectl apply -f deployment/IoT-Service/
```

This will create:
- ConfigMap with common configuration
- Secret for sensitive data
- 4 Deployments (device, parser, soil, weather)
- HPA for auto-scaling
- Service for potential HTTP endpoints

### Helm Chart

When using Helm, set the `app_type` parameter:

```yaml
# For parser service
env:
  - name: APP_TYPE
    value: "parser"

# For soil service
env:
  - name: APP_TYPE
    value: "soil"

# For weather service
env:
  - name: APP_TYPE
    value: "weather"

# For device simulator
env:
  - name: APP_TYPE
    value: "device"
  - name: DEVICE_ID
    value: "device-001"
```

## Database Schema

### Soil Data Table

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
ORDER BY (device_id, timestamp)
```

### Weather Data Table

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
ORDER BY (device_id, timestamp)
```

## MQTT Topics

- `krishi/sensors/raw` - Raw sensor data from IoT devices
- `krishi/sensors/soil` - Parsed soil sensor data
- `krishi/sensors/weather` - Parsed weather sensor data

## Data Flow

1. IoT device generates sensor readings
2. Device publishes JSON data to `krishi/sensors/raw`
3. Parser service receives, validates, and routes data
4. Soil/Weather consumers receive typed data
5. Consumers validate data ranges
6. Validated data is saved to ClickHouse

## Monitoring

The service logs important events:
- MQTT connection status
- Data reception and processing
- Validation errors
- Database operations

Future enhancements may include:
- Prometheus metrics
- Health check endpoints
- Grafana dashboards

## Development

### Project Structure

```
iot-service/
├── cmd/
│   └── main/
│       └── main.go           # Application entry point
├── pkg/
│   ├── config/
│   │   └── config.go         # Configuration management
│   ├── models/
│   │   └── sensor.go         # Data models
│   ├── mqtt/
│   │   └── client.go         # MQTT client wrapper
│   ├── database/
│   │   └── clickhouse.go     # ClickHouse operations
│   ├── device/
│   │   └── simulator.go      # IoT device simulator
│   └── consumers/
│       ├── parser.go         # Parser consumer
│       ├── soil.go           # Soil consumer
│       └── weather.go        # Weather consumer
├── Dockerfile
├── go.mod
└── go.sum
```

### Adding New Sensors

1. Update `models.DataPoint` in `pkg/models/sensor.go`
2. Create new consumer in `pkg/consumers/`
3. Add validation logic
4. Create ClickHouse table
5. Update device simulator to generate data
6. Add new APP_TYPE case in `cmd/main/main.go`

## License

Part of the Krishi Mantra platform.
