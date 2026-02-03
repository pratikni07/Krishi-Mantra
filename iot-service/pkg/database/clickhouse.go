package database

import (
	"context"
	"fmt"
	"log"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/models"
)

type ClickHouseDB struct {
	conn driver.Conn
}

// NewClickHouseDB creates a new ClickHouse database connection
func NewClickHouseDB(addr, database, username, password string) (*ClickHouseDB, error) {
	conn, err := clickhouse.Open(&clickhouse.Options{
		Addr: []string{addr},
		Auth: clickhouse.Auth{
			Database: database,
			Username: username,
			Password: password,
		},
	})

	if err != nil {
		return nil, fmt.Errorf("failed to connect to ClickHouse: %w", err)
	}

	if err := conn.Ping(context.Background()); err != nil {
		return nil, fmt.Errorf("failed to ping ClickHouse: %w", err)
	}

	log.Printf("Connected to ClickHouse: %s/%s", addr, database)

	db := &ClickHouseDB{conn: conn}
	if err := db.createTables(); err != nil {
		return nil, err
	}

	return db, nil
}

// createTables creates the necessary tables if they don't exist
func (db *ClickHouseDB) createTables() error {
	ctx := context.Background()

	// Create soil_data table
	soilTableQuery := `
		CREATE TABLE IF NOT EXISTS soil_data (
			device_id String,
			timestamp DateTime,
			moisture Float64,
			temperature Float64,
			ph Float64,
			nitrogen Float64,
			phosphorus Float64,
			potassium Float64
		) ENGINE = MergeTree()
		ORDER BY (device_id, timestamp)
	`

	if err := db.conn.Exec(ctx, soilTableQuery); err != nil {
		return fmt.Errorf("failed to create soil_data table: %w", err)
	}

	// Create weather_data table
	weatherTableQuery := `
		CREATE TABLE IF NOT EXISTS weather_data (
			device_id String,
			timestamp DateTime,
			air_temp Float64,
			humidity Float64,
			pressure Float64,
			wind_speed Float64,
			rainfall Float64,
			light_level Float64
		) ENGINE = MergeTree()
		ORDER BY (device_id, timestamp)
	`

	if err := db.conn.Exec(ctx, weatherTableQuery); err != nil {
		return fmt.Errorf("failed to create weather_data table: %w", err)
	}

	log.Println("Database tables created/verified successfully")
	return nil
}

// SaveSoilData saves soil sensor data to ClickHouse
func (db *ClickHouseDB) SaveSoilData(data *models.SoilData) error {
	ctx := context.Background()

	query := `
		INSERT INTO soil_data (device_id, timestamp, moisture, temperature, ph, nitrogen, phosphorus, potassium)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`

	err := db.conn.Exec(ctx, query,
		data.DeviceID,
		data.Timestamp,
		data.Moisture,
		data.Temperature,
		data.PH,
		data.Nitrogen,
		data.Phosphorus,
		data.Potassium,
	)

	if err != nil {
		return fmt.Errorf("failed to save soil data: %w", err)
	}

	log.Printf("Saved soil data for device: %s", data.DeviceID)
	return nil
}

// SaveWeatherData saves weather sensor data to ClickHouse
func (db *ClickHouseDB) SaveWeatherData(data *models.WeatherData) error {
	ctx := context.Background()

	query := `
		INSERT INTO weather_data (device_id, timestamp, air_temp, humidity, pressure, wind_speed, rainfall, light_level)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`

	err := db.conn.Exec(ctx, query,
		data.DeviceID,
		data.Timestamp,
		data.AirTemp,
		data.Humidity,
		data.Pressure,
		data.WindSpeed,
		data.Rainfall,
		data.LightLevel,
	)

	if err != nil {
		return fmt.Errorf("failed to save weather data: %w", err)
	}

	log.Printf("Saved weather data for device: %s", data.DeviceID)
	return nil
}

// Close closes the database connection
func (db *ClickHouseDB) Close() error {
	if db.conn != nil {
		return db.conn.Close()
	}
	return nil
}
