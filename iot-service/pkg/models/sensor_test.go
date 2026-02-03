package models

import (
	"testing"
	"time"
)

func TestSensorDataValidation(t *testing.T) {
	// Test valid sensor data
	moisture := 50.0
	temperature := 25.0
	ph := 7.0
	nitrogen := 30.0
	phosphorus := 15.0
	potassium := 100.0

	sensorData := SensorData{
		DeviceID:  "test-device",
		Timestamp: time.Now(),
		Type:      "soil",
		Data: DataPoint{
			Moisture:    &moisture,
			Temperature: &temperature,
			PH:          &ph,
			Nitrogen:    &nitrogen,
			Phosphorus:  &phosphorus,
			Potassium:   &potassium,
		},
	}

	if sensorData.DeviceID != "test-device" {
		t.Errorf("Expected device ID 'test-device', got %s", sensorData.DeviceID)
	}

	if sensorData.Type != "soil" {
		t.Errorf("Expected type 'soil', got %s", sensorData.Type)
	}

	if *sensorData.Data.Moisture != 50.0 {
		t.Errorf("Expected moisture 50.0, got %.2f", *sensorData.Data.Moisture)
	}
}

func TestWeatherData(t *testing.T) {
	airTemp := 30.0
	humidity := 60.0
	pressure := 1000.0
	windSpeed := 10.0
	rainfall := 5.0
	lightLevel := 50000.0

	weatherData := WeatherData{
		DeviceID:   "test-device",
		Timestamp:  time.Now(),
		AirTemp:    airTemp,
		Humidity:   humidity,
		Pressure:   pressure,
		WindSpeed:  windSpeed,
		Rainfall:   rainfall,
		LightLevel: lightLevel,
	}

	if weatherData.AirTemp != 30.0 {
		t.Errorf("Expected air temp 30.0, got %.2f", weatherData.AirTemp)
	}

	if weatherData.Humidity != 60.0 {
		t.Errorf("Expected humidity 60.0, got %.2f", weatherData.Humidity)
	}
}
