package models

import "time"

type SoilData struct {
	Moisture    float64 `json:"moisture"`
	Temperature float64 `json:"temperature"`
	PH          float64 `json:"ph"`
	EC          float64 `json:"ec"`
}

type WeatherData struct {
	Temperature float64 `json:"temperature"`
	Humidity    float64 `json:"humidity"`
	Rainfall    float64 `json:"rainfall"`
	WindSpeed   float64 `json:"wind_speed"`
	Pressure    float64 `json:"pressure"`
}

type RawPayload struct {
	DeviceID  string      `json:"device_id"`
	Timestamp time.Time   `json:"timestamp"`
	Soil      SoilData    `json:"soil"`
	Weather   WeatherData `json:"weather"`
}

type SoilPayload struct {
	DeviceID  string    `json:"device_id"`
	Timestamp time.Time `json:"timestamp"`
	Soil      SoilData  `json:"soil"`
}

type WeatherPayload struct {
	DeviceID  string      `json:"device_id"`
	Timestamp time.Time   `json:"timestamp"`
	Weather   WeatherData `json:"weather"`
}
