package consumers

import (
	"context"
	"encoding/json"
	"log"
	"math/rand"
	"time"

	"krishi-mantra/iot-service/internal/config"
	"krishi-mantra/iot-service/internal/models"
	mqttclient "krishi-mantra/iot-service/internal/mqtt"
)

func RunDevice(ctx context.Context, cfg config.Config) error {
	client, err := mqttclient.New(cfg.MQTT)
	if err != nil {
		return err
	}
	defer client.Disconnect(250)

	ticker := time.NewTicker(cfg.DeviceInterval)
	defer ticker.Stop()

	log.Printf("starting device publisher with interval %s", cfg.DeviceInterval)
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))

	for {
		select {
		case <-ctx.Done():
			return nil
		case tickTime := <-ticker.C:
			payload := models.RawPayload{
				DeviceID:  cfg.DeviceID,
				Timestamp: tickTime.UTC(),
				Soil: models.SoilData{
					Moisture:    randRange(rng, 25, 65),
					Temperature: randRange(rng, 18, 32),
					PH:          randRange(rng, 5.5, 7.5),
					EC:          randRange(rng, 0.5, 2.0),
				},
				Weather: models.WeatherData{
					Temperature: randRange(rng, 20, 38),
					Humidity:    randRange(rng, 40, 85),
					Rainfall:    randRange(rng, 0, 12),
					WindSpeed:   randRange(rng, 0, 15),
					Pressure:    randRange(rng, 980, 1020),
				},
			}

			data, err := json.Marshal(payload)
			if err != nil {
				log.Printf("failed to marshal payload: %v", err)
				continue
			}
			if err := client.Publish(cfg.MQTT.RawTopic, 1, false, data); err != nil {
				log.Printf("failed to publish payload: %v", err)
			} else {
				log.Printf("published device payload to %s", cfg.MQTT.RawTopic)
			}
		}
	}
}

func randRange(rng *rand.Rand, min, max float64) float64 {
	return min + rng.Float64()*(max-min)
}
