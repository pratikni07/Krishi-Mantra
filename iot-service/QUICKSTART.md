# Quick Start Guide - Krishi Mantra IoT Service

## 🚀 Quick Commands

### Local Development

```bash
# Clone and navigate
cd /path/to/Krishi-Mantra/iot-service

# Build
make build

# Test
make test

# Run device simulator
make run-device

# Run parser service
make run-parser

# Run soil consumer
make run-soil

# Run weather consumer
make run-weather
```

### Docker Compose (Recommended for Testing)

```bash
# Start all services
docker-compose -f docker-compose.iot.yml up -d

# View logs
docker-compose -f docker-compose.iot.yml logs -f

# Stop all services
docker-compose -f docker-compose.iot.yml down

# Restart specific service
docker-compose -f docker-compose.iot.yml restart iot-parser
```

### Kubernetes (Production)

```bash
# Deploy all services
kubectl apply -f deployment/IoT-Service/

# Check status
kubectl get pods -n microservices | grep iot

# View logs
kubectl logs -n microservices -l app=iot-parser -f

# Scale a service
kubectl scale deployment iot-parser --replicas=3 -n microservices

# Delete all services
kubectl delete -f deployment/IoT-Service/
```

## 📝 Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `APP_TYPE` | Service type (device/parser/soil/weather) | parser | Yes |
| `MQTT_BROKER_URL` | MQTT broker address | tcp://localhost:1883 | Yes |
| `MQTT_CLIENT_ID` | MQTT client identifier | krishi-mantra-iot | No |
| `CLICKHOUSE_ADDR` | ClickHouse address | localhost:9000 | Yes* |
| `CLICKHOUSE_DB` | Database name | krishi_mantra | Yes* |
| `CLICKHOUSE_USER` | Database user | default | No |
| `CLICKHOUSE_PASS` | Database password | (empty) | No |
| `DEVICE_ID` | Device identifier | device-001 | Yes** |
| `SENSOR_INTERVAL` | Data interval (seconds) | 10 | No |

\* Required for soil and weather consumers  
\*\* Required for device simulator

## 🔍 Troubleshooting

### Service won't start

```bash
# Check environment variables
printenv | grep -E "APP_TYPE|MQTT|CLICKHOUSE"

# Verify MQTT broker
telnet localhost 1883

# Verify ClickHouse
curl http://localhost:8123
```

### No data in database

```bash
# Check parser logs
docker-compose logs iot-parser

# Check MQTT topics
mosquitto_sub -h localhost -t "krishi/#" -v

# Check ClickHouse
echo "SELECT count() FROM soil_data" | curl 'http://localhost:8123/' --data-binary @-
```

### High memory usage

```bash
# Check resource usage
docker stats

# Scale down replicas
kubectl scale deployment iot-parser --replicas=1 -n microservices
```

## 📊 Monitoring

### Check MQTT Topics

```bash
# Subscribe to all topics
mosquitto_sub -h localhost -t "krishi/#" -v

# Subscribe to raw data
mosquitto_sub -h localhost -t "krishi/sensors/raw" -v

# Subscribe to soil data
mosquitto_sub -h localhost -t "krishi/sensors/soil" -v
```

### Query ClickHouse

```bash
# Count soil records
echo "SELECT count() FROM soil_data" | curl 'http://localhost:8123/' --data-binary @-

# Latest soil data
echo "SELECT * FROM soil_data ORDER BY timestamp DESC LIMIT 10 FORMAT Pretty" | \
  curl 'http://localhost:8123/' --data-binary @-

# Average soil moisture last hour
echo "SELECT avg(moisture) FROM soil_data WHERE timestamp > now() - INTERVAL 1 HOUR" | \
  curl 'http://localhost:8123/' --data-binary @-
```

## 🏃 Quick Test

### End-to-End Test

```bash
# 1. Start infrastructure
docker-compose -f docker-compose.iot.yml up -d mosquitto clickhouse

# 2. Wait for services to be ready
sleep 10

# 3. Start device simulator
docker-compose -f docker-compose.iot.yml up -d iot-device-simulator

# 4. Start parser
docker-compose -f docker-compose.iot.yml up -d iot-parser

# 5. Start consumers
docker-compose -f docker-compose.iot.yml up -d iot-soil-consumer iot-weather-consumer

# 6. Wait for data
sleep 30

# 7. Check data
echo "SELECT count() FROM soil_data" | curl 'http://localhost:8123/' --data-binary @-
echo "SELECT count() FROM weather_data" | curl 'http://localhost:8123/' --data-binary @-

# 8. View recent data
echo "SELECT * FROM soil_data ORDER BY timestamp DESC LIMIT 5 FORMAT Pretty" | \
  curl 'http://localhost:8123/' --data-binary @-
```

## 🛠️ Development

### Add New Sensor Type

1. Update `pkg/models/sensor.go`
2. Create new consumer in `pkg/consumers/`
3. Add validation logic
4. Create ClickHouse table schema
5. Update device simulator
6. Add new APP_TYPE in `cmd/main/main.go`
7. Update documentation

### Modify Sensor Intervals

```bash
# Change to 5 seconds
export SENSOR_INTERVAL=5
make run-device
```

### Custom Device ID

```bash
# Run with custom device ID
export DEVICE_ID=my-farm-device-01
make run-device
```

## 📦 Deployment Checklist

- [ ] Configure environment variables
- [ ] Set up MQTT broker (Mosquitto)
- [ ] Set up ClickHouse database
- [ ] Deploy parser service
- [ ] Deploy soil consumer
- [ ] Deploy weather consumer
- [ ] Configure monitoring (optional)
- [ ] Set up log aggregation (optional)
- [ ] Configure alerts (optional)
- [ ] Test end-to-end data flow
- [ ] Verify data in ClickHouse

## 🔗 Useful Links

- Main README: [iot-service/README.md](./README.md)
- Architecture: [iot-service/ARCHITECTURE.md](./ARCHITECTURE.md)
- Implementation Details: [iot-service/IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md)
- Mosquitto Docs: https://mosquitto.org/documentation/
- ClickHouse Docs: https://clickhouse.com/docs/

## ⚡ Performance Tips

1. **Batch Inserts**: Modify consumers to batch multiple records
2. **Connection Pooling**: Implement connection pooling for ClickHouse
3. **MQTT QoS**: Adjust QoS levels based on reliability needs
4. **HPA Tuning**: Adjust CPU/memory thresholds for auto-scaling
5. **Database Optimization**: Create materialized views for common queries
