package mqtt

import (
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/eclipse/paho.mqtt.golang"

	"krishi-mantra/iot-service/internal/config"
)

type Client struct {
	client mqtt.Client
}

func New(cfg config.MQTTConfig) (*Client, error) {
	if cfg.BrokerURL == "" {
		return nil, errors.New("MQTT_BROKER_URL is required")
	}
	clientID := cfg.ClientID
	if clientID == "" {
		clientID = fmt.Sprintf("krishi-iot-%d", time.Now().UnixNano())
	}

	options := mqtt.NewClientOptions()
	options.AddBroker(cfg.BrokerURL)
	options.SetClientID(clientID)
	if cfg.Username != "" {
		options.SetUsername(cfg.Username)
	}
	if cfg.Password != "" {
		options.SetPassword(cfg.Password)
	}
	options.SetAutoReconnect(true)
	options.SetConnectRetry(true)
	options.SetConnectRetryInterval(5 * time.Second)
	options.OnConnect = func(c mqtt.Client) {
		log.Printf("connected to MQTT broker %s", cfg.BrokerURL)
	}
	options.OnConnectionLost = func(c mqtt.Client, err error) {
		log.Printf("MQTT connection lost: %v", err)
	}

	client := mqtt.NewClient(options)
	token := client.Connect()
	if !token.WaitTimeout(10 * time.Second) {
		return nil, errors.New("MQTT connection timeout")
	}
	if err := token.Error(); err != nil {
		return nil, err
	}

	return &Client{client: client}, nil
}

func (c *Client) Publish(topic string, qos byte, retained bool, payload []byte) error {
	token := c.client.Publish(topic, qos, retained, payload)
	token.Wait()
	return token.Error()
}

func (c *Client) Subscribe(topic string, qos byte, handler mqtt.MessageHandler) error {
	token := c.client.Subscribe(topic, qos, handler)
	token.Wait()
	return token.Error()
}

func (c *Client) Disconnect(quiesce uint) {
	c.client.Disconnect(quiesce)
}
