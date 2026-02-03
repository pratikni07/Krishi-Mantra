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

type SoilConsumer struct {
	mqttClient *mqttClient.Client
	db         *database.ClickHouseDB
}

// NewSoilConsumer creates a new soil consumer
func NewSoilConsumer(client *mqttClient.Client, db *database.ClickHouseDB) *SoilConsumer {
	return &SoilConsumer{
		mqttClient: client,
		db:         db,
	}
}

// Start starts the soil consumer
func (s *SoilConsumer) Start() error {
	log.Println("Starting Soil Consumer...")

	// Subscribe to soil sensor data topic
	err := s.mqttClient.Subscribe("krishi/sensors/soil", s.handleMessage)
	if err != nil {
		return fmt.Errorf("failed to subscribe to soil topic: %w", err)
	}

	log.Println("Soil Consumer started successfully")
	return nil
}

// handleMessage handles incoming soil sensor data messages
func (s *SoilConsumer) handleMessage(client mqtt.Client, msg mqtt.Message) {
	log.Printf("Soil consumer received message from topic: %s", msg.Topic())

	var sensorData models.SensorData
	if err := json.Unmarshal(msg.Payload(), &sensorData); err != nil {
		log.Printf("Error parsing soil sensor data: %v", err)
		return
	}

	// Validate and convert to SoilData
	soilData, err := s.validateAndConvert(&sensorData)
	if err != nil {
		log.Printf("Error validating soil data: %v", err)
		return
	}

	// Save to ClickHouse
	if err := s.db.SaveSoilData(soilData); err != nil {
		log.Printf("Error saving soil data to ClickHouse: %v", err)
		return
	}

	log.Printf("Successfully processed and saved soil data from device: %s", sensorData.DeviceID)
}

// validateAndConvert validates sensor data and converts to SoilData
func (s *SoilConsumer) validateAndConvert(data *models.SensorData) (*models.SoilData, error) {
	// Validate required fields
	if data.Data.Moisture == nil {
		return nil, fmt.Errorf("moisture data is required")
	}
	if data.Data.Temperature == nil {
		return nil, fmt.Errorf("temperature data is required")
	}
	if data.Data.PH == nil {
		return nil, fmt.Errorf("pH data is required")
	}
	if data.Data.Nitrogen == nil {
		return nil, fmt.Errorf("nitrogen data is required")
	}
	if data.Data.Phosphorus == nil {
		return nil, fmt.Errorf("phosphorus data is required")
	}
	if data.Data.Potassium == nil {
		return nil, fmt.Errorf("potassium data is required")
	}

	// Validate ranges
	if *data.Data.Moisture < 0 || *data.Data.Moisture > 100 {
		return nil, fmt.Errorf("moisture value out of range: %.2f", *data.Data.Moisture)
	}
	if *data.Data.Temperature < -50 || *data.Data.Temperature > 100 {
		return nil, fmt.Errorf("temperature value out of range: %.2f", *data.Data.Temperature)
	}
	if *data.Data.PH < 0 || *data.Data.PH > 14 {
		return nil, fmt.Errorf("pH value out of range: %.2f", *data.Data.PH)
	}
	if *data.Data.Nitrogen < 0 {
		return nil, fmt.Errorf("nitrogen value cannot be negative: %.2f", *data.Data.Nitrogen)
	}
	if *data.Data.Phosphorus < 0 {
		return nil, fmt.Errorf("phosphorus value cannot be negative: %.2f", *data.Data.Phosphorus)
	}
	if *data.Data.Potassium < 0 {
		return nil, fmt.Errorf("potassium value cannot be negative: %.2f", *data.Data.Potassium)
	}

	// Convert to SoilData
	soilData := &models.SoilData{
		DeviceID:    data.DeviceID,
		Timestamp:   data.Timestamp,
		Moisture:    *data.Data.Moisture,
		Temperature: *data.Data.Temperature,
		PH:          *data.Data.PH,
		Nitrogen:    *data.Data.Nitrogen,
		Phosphorus:  *data.Data.Phosphorus,
		Potassium:   *data.Data.Potassium,
	}

	return soilData, nil
}
