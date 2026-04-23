package mqtt

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"
	"os"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
)

type Client struct {
	client mqtt.Client
}

// Options configures the MQTT client. BrokerURL should use `ssl://` or
// `tls://` to trigger TLS; CACertPath is optional (for a private CA).
type Options struct {
	BrokerURL  string
	ClientID   string
	Username   string
	Password   string
	CACertPath string
	// InsecureSkipVerify disables hostname/CA verification. Dev only.
	InsecureSkipVerify bool
}

// NewClient creates a new MQTT client using the given options.
func NewClient(opts Options) (*Client, error) {
	if opts.BrokerURL == "" {
		return nil, fmt.Errorf("mqtt: broker URL required")
	}

	mqttOpts := mqtt.NewClientOptions()
	mqttOpts.AddBroker(opts.BrokerURL)
	mqttOpts.SetClientID(opts.ClientID)
	mqttOpts.SetDefaultPublishHandler(messagePubHandler)
	mqttOpts.OnConnect = connectHandler
	mqttOpts.OnConnectionLost = connectLostHandler
	mqttOpts.SetAutoReconnect(true)
	mqttOpts.SetConnectRetry(true)
	mqttOpts.SetConnectRetryInterval(5 * time.Second)

	if opts.Username != "" {
		mqttOpts.SetUsername(opts.Username)
		mqttOpts.SetPassword(opts.Password)
	} else {
		log.Printf("WARNING: MQTT connecting without credentials — set MQTT_USERNAME/MQTT_PASSWORD for production")
	}

	if tlsCfg, err := buildTLSConfig(opts); err != nil {
		return nil, err
	} else if tlsCfg != nil {
		mqttOpts.SetTLSConfig(tlsCfg)
	}

	client := mqtt.NewClient(mqttOpts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		return nil, fmt.Errorf("failed to connect to MQTT broker: %w", token.Error())
	}

	log.Printf("Connected to MQTT broker: %s", opts.BrokerURL)
	return &Client{client: client}, nil
}

func buildTLSConfig(opts Options) (*tls.Config, error) {
	needsTLS := opts.CACertPath != "" || opts.InsecureSkipVerify ||
		startsWithAny(opts.BrokerURL, "ssl://", "tls://", "mqtts://", "wss://")
	if !needsTLS {
		return nil, nil
	}

	cfg := &tls.Config{
		MinVersion:         tls.VersionTLS12,
		InsecureSkipVerify: opts.InsecureSkipVerify,
	}

	if opts.CACertPath != "" {
		pem, err := os.ReadFile(opts.CACertPath)
		if err != nil {
			return nil, fmt.Errorf("mqtt: read CA cert %s: %w", opts.CACertPath, err)
		}
		pool := x509.NewCertPool()
		if !pool.AppendCertsFromPEM(pem) {
			return nil, fmt.Errorf("mqtt: CA cert %s contains no valid PEM", opts.CACertPath)
		}
		cfg.RootCAs = pool
	}
	return cfg, nil
}

func startsWithAny(s string, prefixes ...string) bool {
	for _, p := range prefixes {
		if len(s) >= len(p) && s[:len(p)] == p {
			return true
		}
	}
	return false
}

// Publish publishes a message to a topic
func (c *Client) Publish(topic string, payload []byte) error {
	token := c.client.Publish(topic, 0, false, payload)
	token.Wait()
	if token.Error() != nil {
		return fmt.Errorf("failed to publish message: %w", token.Error())
	}
	return nil
}

// Subscribe subscribes to a topic with a message handler
func (c *Client) Subscribe(topic string, handler mqtt.MessageHandler) error {
	token := c.client.Subscribe(topic, 0, handler)
	token.Wait()
	if token.Error() != nil {
		return fmt.Errorf("failed to subscribe to topic %s: %w", topic, token.Error())
	}
	log.Printf("Subscribed to topic: %s", topic)
	return nil
}

// Disconnect disconnects from the MQTT broker
func (c *Client) Disconnect() {
	c.client.Disconnect(250)
	log.Println("Disconnected from MQTT broker")
}

var messagePubHandler mqtt.MessageHandler = func(client mqtt.Client, msg mqtt.Message) {
	log.Printf("Received message: %s from topic: %s\n", msg.Payload(), msg.Topic())
}

var connectHandler mqtt.OnConnectHandler = func(client mqtt.Client) {
	log.Println("Connected to MQTT broker")
}

var connectLostHandler mqtt.ConnectionLostHandler = func(client mqtt.Client, err error) {
	log.Printf("Connection lost: %v", err)
}
