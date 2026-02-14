package models

import "time"

// SensorData represents the raw sensor data from IoT device
type SensorData struct {
	DeviceID  string    `json:"device_id"`
	SessionID string    `json:"session_id"` // Required for authenticated transmission
	Timestamp time.Time `json:"timestamp"`
	Type      string    `json:"type"` // "soil" or "weather"
	Data      DataPoint `json:"data"`
}

// DataPoint represents specific sensor readings
type DataPoint struct {
	// Soil sensor data
	Moisture    *float64 `json:"moisture,omitempty"`
	Temperature *float64 `json:"temperature,omitempty"`
	PH          *float64 `json:"ph,omitempty"`
	Nitrogen    *float64 `json:"nitrogen,omitempty"`
	Phosphorus  *float64 `json:"phosphorus,omitempty"`
	Potassium   *float64 `json:"potassium,omitempty"`

	// Weather sensor data
	AirTemp     *float64 `json:"air_temp,omitempty"`
	Humidity    *float64 `json:"humidity,omitempty"`
	Pressure    *float64 `json:"pressure,omitempty"`
	WindSpeed   *float64 `json:"wind_speed,omitempty"`
	Rainfall    *float64 `json:"rainfall,omitempty"`
	LightLevel  *float64 `json:"light_level,omitempty"`
}

// SoilData represents validated soil sensor data
type SoilData struct {
	DeviceID    string    `json:"device_id"`
	Timestamp   time.Time `json:"timestamp"`
	Moisture    float64   `json:"moisture"`
	Temperature float64   `json:"temperature"`
	PH          float64   `json:"ph"`
	Nitrogen    float64   `json:"nitrogen"`
	Phosphorus  float64   `json:"phosphorus"`
	Potassium   float64   `json:"potassium"`
}

// WeatherData represents validated weather sensor data
type WeatherData struct {
	DeviceID   string    `json:"device_id"`
	Timestamp  time.Time `json:"timestamp"`
	AirTemp    float64   `json:"air_temp"`
	Humidity   float64   `json:"humidity"`
	Pressure   float64   `json:"pressure"`
	WindSpeed  float64   `json:"wind_speed"`
	Rainfall   float64   `json:"rainfall"`
	LightLevel float64   `json:"light_level"`
}
