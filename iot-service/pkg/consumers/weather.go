package consumers

import (
	"encoding/json"
	"fmt"
	"log"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/database"
	mqttClient "github.com/pratikni07/Krishi-Mantra/iot-service/pkg/mqtt"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/models"
)

type WeatherConsumer struct {
	mqttClient *mqttClient.Client
	db         *database.ClickHouseDB
}

// NewWeatherConsumer creates a new weather consumer
func NewWeatherConsumer(client *mqttClient.Client, db *database.ClickHouseDB) *WeatherConsumer {
	return &WeatherConsumer{
		mqttClient: client,
		db:         db,
	}
}

// Start starts the weather consumer
func (w *WeatherConsumer) Start() error {
	log.Println("Starting Weather Consumer...")

	// Subscribe to weather sensor data topic
	err := w.mqttClient.Subscribe("krishi/sensors/weather", w.handleMessage)
	if err != nil {
		return fmt.Errorf("failed to subscribe to weather topic: %w", err)
	}

	log.Println("Weather Consumer started successfully")
	return nil
}

// handleMessage handles incoming weather sensor data messages
func (w *WeatherConsumer) handleMessage(client mqtt.Client, msg mqtt.Message) {
	log.Printf("Weather consumer received message from topic: %s", msg.Topic())

	var sensorData models.SensorData
	if err := json.Unmarshal(msg.Payload(), &sensorData); err != nil {
		log.Printf("Error parsing weather sensor data: %v", err)
		return
	}

	// Validate and convert to WeatherData
	weatherData, err := w.validateAndConvert(&sensorData)
	if err != nil {
		log.Printf("Error validating weather data: %v", err)
		return
	}

	// Save to ClickHouse
	if err := w.db.SaveWeatherData(weatherData); err != nil {
		log.Printf("Error saving weather data to ClickHouse: %v", err)
		return
	}

	log.Printf("Successfully processed and saved weather data from device: %s", sensorData.DeviceID)
}

// validateAndConvert validates sensor data and converts to WeatherData
func (w *WeatherConsumer) validateAndConvert(data *models.SensorData) (*models.WeatherData, error) {
	// Validate required fields
	if data.Data.AirTemp == nil {
		return nil, fmt.Errorf("air temperature data is required")
	}
	if data.Data.Humidity == nil {
		return nil, fmt.Errorf("humidity data is required")
	}
	if data.Data.Pressure == nil {
		return nil, fmt.Errorf("pressure data is required")
	}
	if data.Data.WindSpeed == nil {
		return nil, fmt.Errorf("wind speed data is required")
	}
	if data.Data.Rainfall == nil {
		return nil, fmt.Errorf("rainfall data is required")
	}
	if data.Data.LightLevel == nil {
		return nil, fmt.Errorf("light level data is required")
	}

	// Validate ranges
	if *data.Data.AirTemp < -50 || *data.Data.AirTemp > 60 {
		return nil, fmt.Errorf("air temperature value out of range: %.2f", *data.Data.AirTemp)
	}
	if *data.Data.Humidity < 0 || *data.Data.Humidity > 100 {
		return nil, fmt.Errorf("humidity value out of range: %.2f", *data.Data.Humidity)
	}
	if *data.Data.Pressure < 900 || *data.Data.Pressure > 1100 {
		return nil, fmt.Errorf("pressure value out of range: %.2f", *data.Data.Pressure)
	}
	if *data.Data.WindSpeed < 0 {
		return nil, fmt.Errorf("wind speed value cannot be negative: %.2f", *data.Data.WindSpeed)
	}
	if *data.Data.Rainfall < 0 {
		return nil, fmt.Errorf("rainfall value cannot be negative: %.2f", *data.Data.Rainfall)
	}
	if *data.Data.LightLevel < 0 {
		return nil, fmt.Errorf("light level value cannot be negative: %.2f", *data.Data.LightLevel)
	}

	// Convert to WeatherData
	weatherData := &models.WeatherData{
		DeviceID:   data.DeviceID,
		Timestamp:  data.Timestamp,
		AirTemp:    *data.Data.AirTemp,
		Humidity:   *data.Data.Humidity,
		Pressure:   *data.Data.Pressure,
		WindSpeed:  *data.Data.WindSpeed,
		Rainfall:   *data.Data.Rainfall,
		LightLevel: *data.Data.LightLevel,
	}

	return weatherData, nil
}
