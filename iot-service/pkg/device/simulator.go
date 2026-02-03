package device

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"time"

	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/models"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/mqtt"
)

type Simulator struct {
	deviceID       string
	mqttClient     *mqtt.Client
	sensorInterval int
	stopChan       chan struct{}
}

// NewSimulator creates a new IoT device simulator
func NewSimulator(deviceID string, mqttClient *mqtt.Client, sensorInterval int) *Simulator {
	return &Simulator{
		deviceID:       deviceID,
		mqttClient:     mqttClient,
		sensorInterval: sensorInterval,
		stopChan:       make(chan struct{}),
	}
}

// Start starts the device simulator
func (s *Simulator) Start() {
	log.Printf("Starting IoT device simulator for device: %s", s.deviceID)
	ticker := time.NewTicker(time.Duration(s.sensorInterval) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			s.sendSensorData()
		case <-s.stopChan:
			log.Println("Stopping IoT device simulator")
			return
		}
	}
}

// Stop stops the device simulator
func (s *Simulator) Stop() {
	close(s.stopChan)
}

// sendSensorData generates and sends sensor data
func (s *Simulator) sendSensorData() {
	// Send soil sensor data
	if err := s.sendSoilData(); err != nil {
		log.Printf("Error sending soil data: %v", err)
	}

	// Send weather sensor data
	if err := s.sendWeatherData(); err != nil {
		log.Printf("Error sending weather data: %v", err)
	}
}

// sendSoilData generates and sends soil sensor data
func (s *Simulator) sendSoilData() error {
	moisture := 20.0 + rand.Float64()*60.0          // 20-80%
	temperature := 15.0 + rand.Float64()*20.0       // 15-35°C
	ph := 5.5 + rand.Float64()*2.5                  // 5.5-8.0
	nitrogen := 10.0 + rand.Float64()*40.0          // 10-50 mg/kg
	phosphorus := 5.0 + rand.Float64()*25.0         // 5-30 mg/kg
	potassium := 50.0 + rand.Float64()*150.0        // 50-200 mg/kg

	data := models.SensorData{
		DeviceID:  s.deviceID,
		Timestamp: time.Now(),
		Type:      "soil",
		Data: models.DataPoint{
			Moisture:    &moisture,
			Temperature: &temperature,
			PH:          &ph,
			Nitrogen:    &nitrogen,
			Phosphorus:  &phosphorus,
			Potassium:   &potassium,
		},
	}

	payload, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal soil data: %w", err)
	}

	if err := s.mqttClient.Publish("krishi/sensors/raw", payload); err != nil {
		return fmt.Errorf("failed to publish soil data: %w", err)
	}

	log.Printf("Sent soil data: moisture=%.2f%%, temp=%.2f°C, pH=%.2f", moisture, temperature, ph)
	return nil
}

// sendWeatherData generates and sends weather sensor data
func (s *Simulator) sendWeatherData() error {
	airTemp := 20.0 + rand.Float64()*20.0           // 20-40°C
	humidity := 30.0 + rand.Float64()*50.0          // 30-80%
	pressure := 980.0 + rand.Float64()*40.0         // 980-1020 hPa
	windSpeed := rand.Float64() * 20.0              // 0-20 m/s
	rainfall := rand.Float64() * 10.0               // 0-10 mm
	lightLevel := rand.Float64() * 100000.0         // 0-100000 lux

	data := models.SensorData{
		DeviceID:  s.deviceID,
		Timestamp: time.Now(),
		Type:      "weather",
		Data: models.DataPoint{
			AirTemp:    &airTemp,
			Humidity:   &humidity,
			Pressure:   &pressure,
			WindSpeed:  &windSpeed,
			Rainfall:   &rainfall,
			LightLevel: &lightLevel,
		},
	}

	payload, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal weather data: %w", err)
	}

	if err := s.mqttClient.Publish("krishi/sensors/raw", payload); err != nil {
		return fmt.Errorf("failed to publish weather data: %w", err)
	}

	log.Printf("Sent weather data: temp=%.2f°C, humidity=%.2f%%, pressure=%.2f hPa", airTemp, humidity, pressure)
	return nil
}
