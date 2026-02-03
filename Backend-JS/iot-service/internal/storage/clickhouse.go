package storage

import (
	"context"
	"fmt"

	"github.com/ClickHouse/clickhouse-go/v2"

	"krishi-mantra/iot-service/internal/config"
	"krishi-mantra/iot-service/internal/models"
)

type ClickHouseStore struct {
	conn     clickhouse.Conn
	database string
}

func NewClickHouse(cfg config.ClickHouseConfig) (*ClickHouseStore, error) {
	conn, err := clickhouse.Open(&clickhouse.Options{
		Addr: []string{cfg.Addr},
		Auth: clickhouse.Auth{
			Database: cfg.Database,
			Username: cfg.Username,
			Password: cfg.Password,
		},
	})
	if err != nil {
		return nil, err
	}

	return &ClickHouseStore{conn: conn, database: cfg.Database}, nil
}

func (s *ClickHouseStore) Init(ctx context.Context) error {
	if err := s.conn.Exec(ctx, "CREATE DATABASE IF NOT EXISTS "+escapeIdent(s.database)); err != nil {
		return err
	}

	if err := s.conn.Exec(ctx, fmt.Sprintf(soilTableDDLTemplate, escapeIdent(s.database))); err != nil {
		return err
	}
	if err := s.conn.Exec(ctx, fmt.Sprintf(weatherTableDDLTemplate, escapeIdent(s.database))); err != nil {
		return err
	}
	return nil
}

func (s *ClickHouseStore) InsertSoil(ctx context.Context, payload models.SoilPayload) error {
	return s.conn.Exec(
		ctx,
		fmt.Sprintf(`INSERT INTO %s.soil_readings (device_id, timestamp, moisture, temperature, ph, ec)
         VALUES (?, ?, ?, ?, ?, ?)`,
			escapeIdent(s.database),
		),
		payload.DeviceID,
		payload.Timestamp,
		payload.Soil.Moisture,
		payload.Soil.Temperature,
		payload.Soil.PH,
		payload.Soil.EC,
	)
}

func (s *ClickHouseStore) InsertWeather(ctx context.Context, payload models.WeatherPayload) error {
	return s.conn.Exec(
		ctx,
		fmt.Sprintf(`INSERT INTO %s.weather_readings (device_id, timestamp, temperature, humidity, rainfall, wind_speed, pressure)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
			escapeIdent(s.database),
		),
		payload.DeviceID,
		payload.Timestamp,
		payload.Weather.Temperature,
		payload.Weather.Humidity,
		payload.Weather.Rainfall,
		payload.Weather.WindSpeed,
		payload.Weather.Pressure,
	)
}

func escapeIdent(ident string) string {
	return fmt.Sprintf("`%s`", ident)
}

const soilTableDDLTemplate = `
CREATE TABLE IF NOT EXISTS %s.soil_readings (
    device_id String,
    timestamp DateTime,
    moisture Float32,
    temperature Float32,
    ph Float32,
    ec Float32
) ENGINE = MergeTree()
ORDER BY (device_id, timestamp)
`

const weatherTableDDLTemplate = `
CREATE TABLE IF NOT EXISTS %s.weather_readings (
    device_id String,
    timestamp DateTime,
    temperature Float32,
    humidity Float32,
    rainfall Float32,
    wind_speed Float32,
    pressure Float32
) ENGINE = MergeTree()
ORDER BY (device_id, timestamp)
`
