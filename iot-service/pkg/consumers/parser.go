package consumers

import (
	"encoding/json"
	"fmt"
	"log"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	mqttClient "github.com/pratikni07/Krishi-Mantra/iot-service/pkg/mqtt"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/models"
)

type ParserConsumer struct {
	mqttClient *mqttClient.Client
}

// NewParserConsumer creates a new parser consumer
func NewParserConsumer(client *mqttClient.Client) *ParserConsumer {
	return &ParserConsumer{
		mqttClient: client,
	}
}

// Start starts the parser consumer
func (p *ParserConsumer) Start() error {
	log.Println("Starting Parser Consumer...")

	// Subscribe to raw sensor data topic
	err := p.mqttClient.Subscribe("krishi/sensors/raw", p.handleMessage)
	if err != nil {
		return fmt.Errorf("failed to subscribe to raw topic: %w", err)
	}

	log.Println("Parser Consumer started successfully")
	return nil
}

// handleMessage handles incoming sensor data messages
func (p *ParserConsumer) handleMessage(client mqtt.Client, msg mqtt.Message) {
	log.Printf("Parser received message from topic: %s", msg.Topic())

	var sensorData models.SensorData
	if err := json.Unmarshal(msg.Payload(), &sensorData); err != nil {
		log.Printf("Error parsing sensor data: %v", err)
		return
	}

	// Route data based on sensor type
	switch sensorData.Type {
	case "soil":
		if err := p.routeSoilData(&sensorData); err != nil {
			log.Printf("Error routing soil data: %v", err)
		}
	case "weather":
		if err := p.routeWeatherData(&sensorData); err != nil {
			log.Printf("Error routing weather data: %v", err)
		}
	default:
		log.Printf("Unknown sensor type: %s", sensorData.Type)
	}
}

// routeSoilData routes soil sensor data to soil topic
func (p *ParserConsumer) routeSoilData(data *models.SensorData) error {
	payload, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal soil data: %w", err)
	}

	if err := p.mqttClient.Publish("krishi/sensors/soil", payload); err != nil {
		return fmt.Errorf("failed to publish to soil topic: %w", err)
	}

	log.Printf("Routed soil data from device: %s", data.DeviceID)
	return nil
}

// routeWeatherData routes weather sensor data to weather topic
func (p *ParserConsumer) routeWeatherData(data *models.SensorData) error {
	payload, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal weather data: %w", err)
	}

	if err := p.mqttClient.Publish("krishi/sensors/weather", payload); err != nil {
		return fmt.Errorf("failed to publish to weather topic: %w", err)
	}

	log.Printf("Routed weather data from device: %s", data.DeviceID)
	return nil
}
