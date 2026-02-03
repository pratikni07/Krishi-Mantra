# 🚜 Krishi Doctor: Empowering Farmers with Technology

## 📝 Project Overview

Krishi Doctor is a comprehensive mobile application designed to support and empower farmers by providing essential services and information through a user-friendly interface. The app combines cutting-edge technology with agricultural expertise to deliver real-time insights, guidance, and market information.

## 🌟 Key Features

### 1. 👨‍🌾 Farmer Consulting
- Expert agricultural consultation
- Personalized crop and farming advice
- Direct communication with agricultural experts

### 2. 🌦️ Weather Insights
- Real-time local weather forecasts
- Crop-specific weather predictions
- Agricultural advisory based on weather conditions

### 3. 📰 Knowledge Feeds
- Agricultural news and updates
- Best farming practices
- Crop management tips
- Success stories and case studies

### 4. 🎥 Reels and Educational Content
- Short-form video content
- Farming tutorials
- Expert interviews
- Field demonstrations

### 5. 💰 Market Rates
- Real-time crop pricing
- Local and regional market rates
- Price trend analysis
- Historical price comparisons

### 6. 🏭 Company & Product Information
- Agricultural company profiles
- Product catalogs
- Usage guidelines
- Product comparisons
- Dealer and distributor details

### 7. 🌡️ IoT Farm Monitoring (NEW)
- Real-time soil monitoring (moisture, temperature, pH, NPK)
- Weather station data (temperature, humidity, pressure, wind, rainfall, light)
- Automated data collection every 10 seconds
- Historical data analysis
- Data-driven farming insights

## 🛠 Tech Stack

### Frontend
- Flutter
- Dart
- Provider/Riverpod for state management
- Dio for HTTP requests

### Backend
- Node.js
- Express.js
- MongoDB
- Redis

### IoT Platform (NEW)
- **Go** - IoT service implementation
- **MQTT (Mosquitto)** - Message broker for sensor data
- **ClickHouse** - Time-series database for sensor data storage
- **Docker** - Containerization

### DevOps
- Docker
- AWS
- Nginx
- CI/CD Pipeline

## 🌾 IoT Platform

Krishi Mantra now includes a comprehensive IoT platform for real-time farm monitoring, similar to Fasal IoT devices.

### Features
- **Real-time Sensor Data**: Collects soil and weather data every 10 seconds
- **Multi-Sensor Support**: 
  - Soil sensors (moisture, temperature, pH, NPK)
  - Weather sensors (temperature, humidity, pressure, wind, rainfall, light)
- **Scalable Architecture**: Microservices-based with MQTT messaging
- **Data Validation**: Comprehensive validation before storage
- **Time-Series Storage**: Efficient ClickHouse database for sensor data

### Architecture
```
IoT Device → MQTT → Parser Service → Soil/Weather Services → ClickHouse DB
```

### Quick Start

```bash
# Start all IoT services
docker-compose -f docker-compose.iot.yml up -d

# Or run individual services
cd iot-service
make run-device    # Start device simulator
make run-parser    # Start parser service
make run-soil      # Start soil consumer
make run-weather   # Start weather consumer
```

For detailed documentation, see [IoT Service README](./iot-service/README.md).


