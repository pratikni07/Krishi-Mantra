package consumers

import (
	"encoding/json"
	"fmt"
	"log"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/api"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/handlers"
	mqttClient "github.com/pratikni07/Krishi-Mantra/iot-service/pkg/mqtt"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/models"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/session"
)

type ParserConsumer struct {
	mqttClient        *mqttClient.Client
	sessionManager    *session.Manager
	handshakeHandler  *handlers.HandshakeHandler
	apiClient         *api.Client
}

// NewParserConsumer creates a new parser consumer
func NewParserConsumer(client *mqttClient.Client, apiClient *api.Client) *ParserConsumer {
	sessionMgr := session.NewManager()
	handshakeHandler := handlers.NewHandshakeHandler(client, sessionMgr, apiClient)
	
	return &ParserConsumer{
		mqttClient:       client,
		sessionManager:   sessionMgr,
		handshakeHandler: handshakeHandler,
		apiClient:        apiClient,
	}
}

// Start starts the parser consumer
func (p *ParserConsumer) Start() error {
	log.Println("Starting Parser Consumer...")

	// Start handshake handler (handles device connections)
	if err := p.handshakeHandler.Start(); err != nil {
		return fmt.Errorf("failed to start handshake handler: %w", err)
	}

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

	// Validate session before processing data
	if err := p.validateSession(&sensorData); err != nil {
		log.Printf("Session validation failed for device %s: %v", sensorData.DeviceID, err)
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

// validateSession validates the device session
func (p *ParserConsumer) validateSession(data *models.SensorData) error {
	if data.DeviceID == "" {
		return fmt.Errorf("device_id is required")
	}
	if data.SessionID == "" {
		return fmt.Errorf("session_id is required")
	}

	// Validate session with session manager
	if err := p.handshakeHandler.ValidateDeviceSession(data.DeviceID, data.SessionID); err != nil {
		return fmt.Errorf("invalid session: %w", err)
	}

	return nil
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
