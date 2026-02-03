# Krishi Mantra IoT Service Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         KRISHI MANTRA IOT PLATFORM                       │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐
│  IoT Device     │  (APP_TYPE=device)
│  Simulator      │
│                 │
│  Sensors:       │
│  • Soil         │  Generates data every 10 seconds
│  • Weather      │
└────────┬────────┘
         │
         │ Publishes sensor data
         ↓
    ┌────────────────────┐
    │   MQTT Broker      │
    │   (Mosquitto)      │
    │                    │
    │   Topic:           │
    │   krishi/sensors/  │
    │   raw              │
    └─────────┬──────────┘
              │
              │ Subscribes to raw data
              ↓
    ┌─────────────────────┐
    │  Parser Service     │  (APP_TYPE=parser)
    │                     │
    │  • Receives data    │
    │  • Validates format │
    │  • Routes by type   │
    └──────┬──────────────┘
           │
           ├──────────────────────┬─────────────────────┐
           │                      │                     │
           │ soil data            │ weather data        │
           ↓                      ↓                     │
    ┌──────────────┐       ┌──────────────┐            │
    │ MQTT Topic:  │       │ MQTT Topic:  │            │
    │ krishi/      │       │ krishi/      │            │
    │ sensors/soil │       │ sensors/     │            │
    └──────┬───────┘       │ weather      │            │
           │               └──────┬───────┘            │
           │                      │                    │
           │ Subscribes           │ Subscribes         │
           ↓                      ↓                    │
    ┌──────────────┐       ┌──────────────┐           │
    │ Soil         │       │ Weather      │           │
    │ Consumer     │       │ Consumer     │           │
    │              │       │              │           │
    │ (APP_TYPE=   │       │ (APP_TYPE=   │           │
    │  soil)       │       │  weather)    │           │
    │              │       │              │           │
    │ • Validates  │       │ • Validates  │           │
    │ • Transforms │       │ • Transforms │           │
    └──────┬───────┘       └──────┬───────┘           │
           │                      │                    │
           │ Stores               │ Stores             │
           ↓                      ↓                    │
    ┌──────────────┐       ┌──────────────┐           │
    │ ClickHouse   │       │ ClickHouse   │           │
    │              │       │              │           │
    │ Table:       │       │ Table:       │           │
    │ soil_data    │       │ weather_data │           │
    └──────────────┘       └──────────────┘           │
                                                       │
                          ┌────────────────────────────┘
                          │
                          ↓
                   [Future: Analytics,
                    API, Dashboards]
```

## Data Flow Example

### Soil Sensor Data Flow

```json
1. Device Generates:
{
  "device_id": "device-001",
  "timestamp": "2026-02-03T20:45:00Z",
  "type": "soil",
  "data": {
    "moisture": 45.5,
    "temperature": 22.3,
    "ph": 6.8,
    "nitrogen": 25.0,
    "phosphorus": 15.0,
    "potassium": 120.0
  }
}

2. Parser Routes to: krishi/sensors/soil

3. Soil Consumer Validates:
   ✓ moisture: 0-100% ✓
   ✓ temperature: -50 to 100°C ✓
   ✓ ph: 0-14 ✓
   ✓ nitrogen: >= 0 ✓
   ✓ phosphorus: >= 0 ✓
   ✓ potassium: >= 0 ✓

4. Stores in ClickHouse:
   INSERT INTO soil_data VALUES (...)
```

## Deployment Architecture

### Kubernetes Deployment

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │          Namespace: microservices                │   │
│  │                                                  │   │
│  │  ┌────────────────┐  ┌────────────────┐         │   │
│  │  │ Deployment:    │  │ Deployment:    │         │   │
│  │  │ iot-device-    │  │ iot-parser     │         │   │
│  │  │ simulator      │  │                │         │   │
│  │  │                │  │ Replicas: 2    │         │   │
│  │  │ Replicas: 1    │  │ HPA: 2-5       │         │   │
│  │  └────────────────┘  └────────────────┘         │   │
│  │                                                  │   │
│  │  ┌────────────────┐  ┌────────────────┐         │   │
│  │  │ Deployment:    │  │ Deployment:    │         │   │
│  │  │ iot-soil-      │  │ iot-weather-   │         │   │
│  │  │ consumer       │  │ consumer       │         │   │
│  │  │                │  │                │         │   │
│  │  │ Replicas: 2    │  │ Replicas: 2    │         │   │
│  │  │ HPA: 2-5       │  │ HPA: 2-5       │         │   │
│  │  └────────────────┘  └────────────────┘         │   │
│  │                                                  │   │
│  │  ┌────────────────┐  ┌────────────────┐         │   │
│  │  │ ConfigMap:     │  │ Secret:        │         │   │
│  │  │ iot-service-   │  │ iot-service-   │         │   │
│  │  │ config         │  │ secret         │         │   │
│  │  └────────────────┘  └────────────────┘         │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  External Services:                                      │
│  • Mosquitto MQTT Broker                                │
│  • ClickHouse Database                                  │
└─────────────────────────────────────────────────────────┘
```

## Technology Stack

```
┌─────────────────────────────────────┐
│         Application Layer           │
│                                     │
│  • Go 1.24                          │
│  • MQTT Client (Paho)               │
│  • ClickHouse Driver                │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│       Messaging Layer               │
│                                     │
│  • Eclipse Mosquitto                │
│  • MQTT Protocol                    │
│  • QoS 0 (at most once)             │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│        Database Layer               │
│                                     │
│  • ClickHouse                       │
│  • MergeTree Engine                 │
│  • Time-series optimization         │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│      Container Platform             │
│                                     │
│  • Docker                           │
│  • Kubernetes                       │
│  • Helm (optional)                  │
└─────────────────────────────────────┘
```

## Scaling Strategy

```
Load Increase → HPA Monitors CPU → Scales Pods

Example: Parser Service
┌──────────┐
│ Pod 1    │  CPU: 75% (above threshold)
└──────────┘
     ↓ HPA Triggered
┌──────────┐
│ Pod 1    │  CPU: 45%
├──────────┤
│ Pod 2    │  CPU: 45%
├──────────┤
│ Pod 3    │  CPU: 45%
└──────────┘

Max Pods: 5
Min Pods: 2
Target CPU: 70%
```

## Monitoring Points

```
┌─────────────────────────────────────┐
│      Future Monitoring Stack        │
│                                     │
│  1. Metrics Collection              │
│     • Prometheus                    │
│     • Custom metrics endpoint       │
│                                     │
│  2. Visualization                   │
│     • Grafana dashboards            │
│     • Real-time sensor data graphs  │
│                                     │
│  3. Alerting                        │
│     • Sensor value anomalies        │
│     • Service health issues         │
│     • Database connection errors    │
│                                     │
│  4. Logging                         │
│     • Centralized logging (ELK)     │
│     • Structured logs               │
└─────────────────────────────────────┘
```
