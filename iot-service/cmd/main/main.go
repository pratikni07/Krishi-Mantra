package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/api"
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
	mqttClient, err := mqtt.NewClient(mqtt.Options{
		BrokerURL:          cfg.MQTTBrokerURL,
		ClientID:           cfg.MQTTClientID,
		Username:           cfg.MQTTUsername,
		Password:           cfg.MQTTPassword,
		CACertPath:         cfg.MQTTCACertPath,
		InsecureSkipVerify: cfg.MQTTInsecureSkipVerify,
	})
	if err != nil {
		log.Fatalf("Failed to create MQTT client: %v", err)
	}
	defer mqttClient.Disconnect()

	// Start the appropriate service based on APP_TYPE
	switch cfg.AppType {
	case "device":
		runDeviceSimulator(cfg, mqttClient)
	case "parser":
		runParserConsumer(cfg, mqttClient)
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

func runParserConsumer(cfg *config.Config, mqttClient *mqtt.Client) {
	log.Println("Running in PARSER mode - Parser Consumer")

	// Fail-closed: the parser exists to gate devices on their main-service
	// subscription. Running without MAIN_SERVICE_URL + MAIN_SERVICE_API_KEY
	// silently admits every device, so we refuse to start unless the
	// operator explicitly opted into IOT_DEV_MODE.
	var apiClient *api.Client
	if cfg.MainServiceURL != "" && cfg.MainServiceAPIKey != "" {
		apiClient = api.NewClient(cfg.MainServiceURL, cfg.MainServiceAPIKey)
		log.Printf("Main service API configured: %s", cfg.MainServiceURL)

		if err := apiClient.HealthCheck(); err != nil {
			log.Printf("Warning: Main service health check failed: %v", err)
			log.Println("Parser will continue but subscription validation may fail")
		} else {
			log.Println("Main service API connection verified")
		}
	} else if cfg.IoTDevMode {
		log.Println("DEV MODE: MAIN_SERVICE_URL or MAIN_SERVICE_API_KEY missing — running without subscription validation")
	} else {
		log.Fatalln("MAIN_SERVICE_URL and MAIN_SERVICE_API_KEY are required in production. Set IOT_DEV_MODE=true to bypass for local development only.")
	}

	parser := consumers.NewParserConsumer(mqttClient, apiClient, cfg.IoTDevMode)
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
