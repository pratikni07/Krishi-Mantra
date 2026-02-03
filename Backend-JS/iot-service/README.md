# Krishi Mantra IoT Service (Go)

This service runs multiple IoT workloads (device publisher, parser, soil consumer, weather consumer) based on the `APP_TYPE` value supplied via deployment configuration/Helm chart.

## App Types

| APP_TYPE | Role |
| --- | --- |
| `device` | Publishes simulated sensor payloads every `DEVICE_INTERVAL_SECONDS` to MQTT. |
| `parser` | Subscribes to raw MQTT messages, splits into soil and weather payloads, and publishes them to the respective topics. |
| `soil` | Subscribes to the soil topic, validates readings, and stores them in ClickHouse. |
| `weather` | Subscribes to the weather topic, validates readings, and stores them in ClickHouse. |

## Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `APP_TYPE` | (required) | `device`, `parser`, `soil`, or `weather`. |
| `DEVICE_INTERVAL_SECONDS` | `10` | Interval for device payloads. |
| `DEVICE_ID` | `krishi-device-001` | Device identifier used by the simulator. |
| `MQTT_BROKER_URL` | `tcp://localhost:1883` | MQTT broker URL (Mosca or compatible). |
| `MQTT_USERNAME` | | MQTT username. |
| `MQTT_PASSWORD` | | MQTT password. |
| `MQTT_CLIENT_ID` | `krishi-iot` | MQTT client ID. |
| `MQTT_RAW_TOPIC` | `krishi/iot/raw` | Raw payload topic. |
| `MQTT_SOIL_TOPIC` | `krishi/iot/soil` | Soil payload topic. |
| `MQTT_WEATHER_TOPIC` | `krishi/iot/weather` | Weather payload topic. |
| `CLICKHOUSE_ADDR` | `localhost:9000` | ClickHouse host:port. |
| `CLICKHOUSE_DATABASE` | `krishi_iot` | Database name. |
| `CLICKHOUSE_USERNAME` | `default` | ClickHouse user. |
| `CLICKHOUSE_PASSWORD` | | ClickHouse password. |

## Local Run

```bash
cd Backend-JS/iot-service
export APP_TYPE=parser
export MQTT_BROKER_URL=tcp://localhost:1883
export CLICKHOUSE_ADDR=localhost:9000

go run ./cmd/iot-service
```

## Notes

- Mosca can be used as the MQTT broker.
- The soil and weather consumers create ClickHouse tables automatically.
