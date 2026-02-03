package config

import (
	"errors"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	AppType        string
	MQTT           MQTTConfig
	ClickHouse     ClickHouseConfig
	DeviceInterval time.Duration
	DeviceID       string
}

type MQTTConfig struct {
	BrokerURL    string
	Username     string
	Password     string
	ClientID     string
	RawTopic     string
	SoilTopic    string
	WeatherTopic string
}

type ClickHouseConfig struct {
	Addr     string
	Database string
	Username string
	Password string
}

func Load() (Config, error) {
	appType := strings.TrimSpace(os.Getenv("APP_TYPE"))
	if appType == "" {
		return Config{}, errors.New("APP_TYPE is required")
	}

	intervalSeconds := 10
	if value := strings.TrimSpace(os.Getenv("DEVICE_INTERVAL_SECONDS")); value != "" {
		parsed, err := strconv.Atoi(value)
		if err == nil && parsed > 0 {
			intervalSeconds = parsed
		}
	}

	cfg := Config{
		AppType: appType,
		MQTT: MQTTConfig{
			BrokerURL:    getEnv("MQTT_BROKER_URL", "tcp://localhost:1883"),
			Username:     os.Getenv("MQTT_USERNAME"),
			Password:     os.Getenv("MQTT_PASSWORD"),
			ClientID:     getEnv("MQTT_CLIENT_ID", "krishi-iot"),
			RawTopic:     getEnv("MQTT_RAW_TOPIC", "krishi/iot/raw"),
			SoilTopic:    getEnv("MQTT_SOIL_TOPIC", "krishi/iot/soil"),
			WeatherTopic: getEnv("MQTT_WEATHER_TOPIC", "krishi/iot/weather"),
		},
		ClickHouse: ClickHouseConfig{
			Addr:     getEnv("CLICKHOUSE_ADDR", "localhost:9000"),
			Database: getEnv("CLICKHOUSE_DATABASE", "krishi_iot"),
			Username: getEnv("CLICKHOUSE_USERNAME", "default"),
			Password: os.Getenv("CLICKHOUSE_PASSWORD"),
		},
		DeviceInterval: time.Duration(intervalSeconds) * time.Second,
		DeviceID:       getEnv("DEVICE_ID", "krishi-device-001"),
	}

	return cfg, nil
}

func getEnv(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}
