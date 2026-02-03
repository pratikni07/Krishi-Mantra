package config

import (
	"os"
	"testing"
)

func TestLoadConfig(t *testing.T) {
	// Set some environment variables
	os.Setenv("APP_TYPE", "parser")
	os.Setenv("MQTT_BROKER_URL", "tcp://test-broker:1883")
	os.Setenv("DEVICE_ID", "test-device-123")
	os.Setenv("SENSOR_INTERVAL", "20")

	defer func() {
		os.Unsetenv("APP_TYPE")
		os.Unsetenv("MQTT_BROKER_URL")
		os.Unsetenv("DEVICE_ID")
		os.Unsetenv("SENSOR_INTERVAL")
	}()

	cfg := LoadConfig()

	if cfg.AppType != "parser" {
		t.Errorf("Expected APP_TYPE 'parser', got %s", cfg.AppType)
	}

	if cfg.MQTTBrokerURL != "tcp://test-broker:1883" {
		t.Errorf("Expected MQTT_BROKER_URL 'tcp://test-broker:1883', got %s", cfg.MQTTBrokerURL)
	}

	if cfg.DeviceID != "test-device-123" {
		t.Errorf("Expected DEVICE_ID 'test-device-123', got %s", cfg.DeviceID)
	}

	if cfg.SensorInterval != 20 {
		t.Errorf("Expected SENSOR_INTERVAL 20, got %d", cfg.SensorInterval)
	}
}

func TestLoadConfigDefaults(t *testing.T) {
	// Ensure no env vars are set
	os.Unsetenv("APP_TYPE")
	os.Unsetenv("MQTT_BROKER_URL")
	os.Unsetenv("DEVICE_ID")
	os.Unsetenv("SENSOR_INTERVAL")

	cfg := LoadConfig()

	if cfg.AppType != "parser" {
		t.Errorf("Expected default APP_TYPE 'parser', got %s", cfg.AppType)
	}

	if cfg.MQTTBrokerURL != "tcp://localhost:1883" {
		t.Errorf("Expected default MQTT_BROKER_URL 'tcp://localhost:1883', got %s", cfg.MQTTBrokerURL)
	}

	if cfg.DeviceID != "device-001" {
		t.Errorf("Expected default DEVICE_ID 'device-001', got %s", cfg.DeviceID)
	}

	if cfg.SensorInterval != 10 {
		t.Errorf("Expected default SENSOR_INTERVAL 10, got %d", cfg.SensorInterval)
	}
}
