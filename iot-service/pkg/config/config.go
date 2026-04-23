package config

import (
	"log"
	"os"
	"strconv"
)

type Config struct {
	AppType                string
	MQTTBrokerURL          string
	MQTTClientID           string
	MQTTUsername           string
	MQTTPassword           string
	MQTTCACertPath         string
	MQTTInsecureSkipVerify bool
	ClickHouseAddr         string
	ClickHouseDB           string
	ClickHouseUser         string
	ClickHousePass         string
	SensorInterval         int
	DeviceID               string
	MainServiceURL         string
	MainServiceAPIKey      string
	IoTDevMode             bool
}

func LoadConfig() *Config {
	sensorInterval, err := strconv.Atoi(getEnv("SENSOR_INTERVAL", "10"))
	if err != nil {
		log.Printf("Invalid SENSOR_INTERVAL, using default: 10")
		sensorInterval = 10
	}

	return &Config{
		AppType:                getEnv("APP_TYPE", "parser"),
		MQTTBrokerURL:          getEnv("MQTT_BROKER_URL", "tcp://localhost:1883"),
		MQTTClientID:           getEnv("MQTT_CLIENT_ID", "krishi-mantra-iot"),
		MQTTUsername:           getEnv("MQTT_USERNAME", ""),
		MQTTPassword:           getEnv("MQTT_PASSWORD", ""),
		MQTTCACertPath:         getEnv("MQTT_CA_CERT_PATH", ""),
		MQTTInsecureSkipVerify: getEnv("MQTT_INSECURE_SKIP_VERIFY", "false") == "true",
		ClickHouseAddr:         getEnv("CLICKHOUSE_ADDR", "localhost:9000"),
		ClickHouseDB:           getEnv("CLICKHOUSE_DB", "krishi_mantra"),
		ClickHouseUser:         getEnv("CLICKHOUSE_USER", "default"),
		ClickHousePass:         getEnv("CLICKHOUSE_PASS", ""),
		SensorInterval:         sensorInterval,
		DeviceID:               getEnv("DEVICE_ID", "device-001"),
		MainServiceURL:         getEnv("MAIN_SERVICE_URL", "http://localhost:3000"),
		MainServiceAPIKey:      getEnv("MAIN_SERVICE_API_KEY", ""),
		IoTDevMode:             getEnv("IOT_DEV_MODE", "false") == "true",
	}
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
