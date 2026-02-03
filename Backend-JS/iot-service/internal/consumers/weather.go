package consumers

import (
	"context"
	"encoding/json"
	"log"

	"github.com/eclipse/paho.mqtt.golang"

	"krishi-mantra/iot-service/internal/config"
	"krishi-mantra/iot-service/internal/models"
	mqttclient "krishi-mantra/iot-service/internal/mqtt"
	"krishi-mantra/iot-service/internal/storage"
)

func RunWeather(ctx context.Context, cfg config.Config) error {
	store, err := storage.NewClickHouse(cfg.ClickHouse)
	if err != nil {
		return err
	}
	if err := store.Init(ctx); err != nil {
		return err
	}

	client, err := mqttclient.New(cfg.MQTT)
	if err != nil {
		return err
	}
	defer client.Disconnect(250)

	handler := func(_ mqtt.Client, msg mqtt.Message) {
		var payload models.WeatherPayload
		if err := json.Unmarshal(msg.Payload(), &payload); err != nil {
			log.Printf("failed to parse weather payload: %v", err)
			return
		}
		if err := validateWeather(payload); err != nil {
			log.Printf("weather payload validation failed: %v", err)
			return
		}
		if err := store.InsertWeather(ctx, payload); err != nil {
			log.Printf("failed to insert weather payload: %v", err)
		}
	}

	if err := client.Subscribe(cfg.MQTT.WeatherTopic, 1, handler); err != nil {
		return err
	}
	log.Printf("weather consumer subscribed to %s", cfg.MQTT.WeatherTopic)

	<-ctx.Done()
	return nil
}
