package consumers

import (
	"fmt"
	"strings"

	"krishi-mantra/iot-service/internal/models"
)

func validateSoil(payload models.SoilPayload) error {
	if strings.TrimSpace(payload.DeviceID) == "" {
		return fmt.Errorf("device_id is required")
	}
	if payload.Timestamp.IsZero() {
		return fmt.Errorf("timestamp is required")
	}
	soil := payload.Soil
	if soil.Moisture < 0 || soil.Moisture > 100 {
		return fmt.Errorf("moisture out of range: %.2f", soil.Moisture)
	}
	if soil.Temperature < -10 || soil.Temperature > 80 {
		return fmt.Errorf("soil temperature out of range: %.2f", soil.Temperature)
	}
	if soil.PH < 3 || soil.PH > 10 {
		return fmt.Errorf("soil pH out of range: %.2f", soil.PH)
	}
	if soil.EC < 0 || soil.EC > 20 {
		return fmt.Errorf("soil EC out of range: %.2f", soil.EC)
	}
	return nil
}

func validateWeather(payload models.WeatherPayload) error {
	if strings.TrimSpace(payload.DeviceID) == "" {
		return fmt.Errorf("device_id is required")
	}
	if payload.Timestamp.IsZero() {
		return fmt.Errorf("timestamp is required")
	}
	weather := payload.Weather
	if weather.Temperature < -40 || weather.Temperature > 80 {
		return fmt.Errorf("temperature out of range: %.2f", weather.Temperature)
	}
	if weather.Humidity < 0 || weather.Humidity > 100 {
		return fmt.Errorf("humidity out of range: %.2f", weather.Humidity)
	}
	if weather.Rainfall < 0 || weather.Rainfall > 500 {
		return fmt.Errorf("rainfall out of range: %.2f", weather.Rainfall)
	}
	if weather.WindSpeed < 0 || weather.WindSpeed > 200 {
		return fmt.Errorf("wind speed out of range: %.2f", weather.WindSpeed)
	}
	if weather.Pressure < 800 || weather.Pressure > 1200 {
		return fmt.Errorf("pressure out of range: %.2f", weather.Pressure)
	}
	return nil
}
