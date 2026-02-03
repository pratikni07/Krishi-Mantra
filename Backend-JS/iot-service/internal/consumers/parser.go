package consumers

import (
	"context"
	"encoding/json"
	"log"

	"github.com/eclipse/paho.mqtt.golang"

	"krishi-mantra/iot-service/internal/config"
	"krishi-mantra/iot-service/internal/models"
	mqttclient "krishi-mantra/iot-service/internal/mqtt"
)

func RunParser(ctx context.Context, cfg config.Config) error {
	client, err := mqttclient.New(cfg.MQTT)
	if err != nil {
		return err
	}
	defer client.Disconnect(250)

	handler := func(_ mqtt.Client, msg mqtt.Message) {
		var payload models.RawPayload
		if err := json.Unmarshal(msg.Payload(), &payload); err != nil {
			log.Printf("failed to parse raw payload: %v", err)
			return
		}

		soilPayload := models.SoilPayload{
			DeviceID:  payload.DeviceID,
			Timestamp: payload.Timestamp,
			Soil:      payload.Soil,
		}
		weatherPayload := models.WeatherPayload{
			DeviceID:  payload.DeviceID,
			Timestamp: payload.Timestamp,
			Weather:   payload.Weather,
		}

		if err := publishPayload(client, cfg.MQTT.SoilTopic, soilPayload); err != nil {
			log.Printf("failed to publish soil payload: %v", err)
		}
		if err := publishPayload(client, cfg.MQTT.WeatherTopic, weatherPayload); err != nil {
			log.Printf("failed to publish weather payload: %v", err)
		}
	}

	if err := client.Subscribe(cfg.MQTT.RawTopic, 1, handler); err != nil {
		return err
	}
	log.Printf("parser subscribed to %s", cfg.MQTT.RawTopic)

	<-ctx.Done()
	return nil
}

func publishPayload(client *mqttclient.Client, topic string, payload any) error {
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	return client.Publish(topic, 1, false, data)
}
