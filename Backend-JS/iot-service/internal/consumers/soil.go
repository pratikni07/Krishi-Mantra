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

func RunSoil(ctx context.Context, cfg config.Config) error {
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
		var payload models.SoilPayload
		if err := json.Unmarshal(msg.Payload(), &payload); err != nil {
			log.Printf("failed to parse soil payload: %v", err)
			return
		}
		if err := validateSoil(payload); err != nil {
			log.Printf("soil payload validation failed: %v", err)
			return
		}
		if err := store.InsertSoil(ctx, payload); err != nil {
			log.Printf("failed to insert soil payload: %v", err)
		}
	}

	if err := client.Subscribe(cfg.MQTT.SoilTopic, 1, handler); err != nil {
		return err
	}
	log.Printf("soil consumer subscribed to %s", cfg.MQTT.SoilTopic)

	<-ctx.Done()
	return nil
}
