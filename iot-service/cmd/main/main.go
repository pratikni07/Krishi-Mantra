package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/config"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/consumers"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/database"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/device"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/mqtt"
)

func main() {
	log.Println("Starting Krishi Mantra IoT Service...")

	// Load configuration
	cfg := config.LoadConfig()
	log.Printf("Configuration loaded - APP_TYPE: %s", cfg.AppType)

	// Create MQTT client
	mqttClient, err := mqtt.NewClient(cfg.MQTTBrokerURL, cfg.MQTTClientID)
	if err != nil {
		log.Fatalf("Failed to create MQTT client: %v", err)
	}
	defer mqttClient.Disconnect()

	// Start the appropriate service based on APP_TYPE
	switch cfg.AppType {
	case "device":
		runDeviceSimulator(cfg, mqttClient)
	case "parser":
		runParserConsumer(mqttClient)
	case "soil":
		runSoilConsumer(cfg, mqttClient)
	case "weather":
		runWeatherConsumer(cfg, mqttClient)
	default:
		log.Fatalf("Unknown APP_TYPE: %s. Valid values are: device, parser, soil, weather", cfg.AppType)
	}

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down Krishi Mantra IoT Service...")
}

func runDeviceSimulator(cfg *config.Config, mqttClient *mqtt.Client) {
	log.Println("Running in DEVICE mode - IoT Device Simulator")

	simulator := device.NewSimulator(cfg.DeviceID, mqttClient, cfg.SensorInterval)
	go simulator.Start()
}

func runParserConsumer(mqttClient *mqtt.Client) {
	log.Println("Running in PARSER mode - Parser Consumer")

	parser := consumers.NewParserConsumer(mqttClient)
	if err := parser.Start(); err != nil {
		log.Fatalf("Failed to start parser consumer: %v", err)
	}
}

func runSoilConsumer(cfg *config.Config, mqttClient *mqtt.Client) {
	log.Println("Running in SOIL mode - Soil Consumer")

	// Connect to ClickHouse
	db, err := database.NewClickHouseDB(
		cfg.ClickHouseAddr,
		cfg.ClickHouseDB,
		cfg.ClickHouseUser,
		cfg.ClickHousePass,
	)
	if err != nil {
		log.Fatalf("Failed to connect to ClickHouse: %v", err)
	}
	defer db.Close()

	soilConsumer := consumers.NewSoilConsumer(mqttClient, db)
	if err := soilConsumer.Start(); err != nil {
		log.Fatalf("Failed to start soil consumer: %v", err)
	}
}

func runWeatherConsumer(cfg *config.Config, mqttClient *mqtt.Client) {
	log.Println("Running in WEATHER mode - Weather Consumer")

	// Connect to ClickHouse
	db, err := database.NewClickHouseDB(
		cfg.ClickHouseAddr,
		cfg.ClickHouseDB,
		cfg.ClickHouseUser,
		cfg.ClickHousePass,
	)
	if err != nil {
		log.Fatalf("Failed to connect to ClickHouse: %v", err)
	}
	defer db.Close()

	weatherConsumer := consumers.NewWeatherConsumer(mqttClient, db)
	if err := weatherConsumer.Start(); err != nil {
		log.Fatalf("Failed to start weather consumer: %v", err)
	}
}
