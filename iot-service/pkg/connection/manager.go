package connection

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"sync"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/models"
	mqttClient "github.com/pratikni07/Krishi-Mantra/iot-service/pkg/mqtt"
)

const (
	// Initial retry delay
	InitialRetryDelay = 2 * time.Second
	// Maximum retry delay
	MaxRetryDelay = 5 * time.Minute
	// Maximum retry attempts before giving up temporarily
	MaxRetryAttempts = 10
	// Handshake timeout
	HandshakeTimeout = 30 * time.Second
	// Heartbeat interval
	HeartbeatInterval = 30 * time.Second
)

// Manager manages device connection lifecycle
type Manager struct {
	deviceID          string
	deviceType        string
	firmwareVersion   string
	macAddress        string
	mqttClient        *mqttClient.Client
	
	state             models.ConnectionState
	sessionID         string
	retryCount        int
	retryDelay        time.Duration
	
	mu                sync.RWMutex
	stopChan          chan struct{}
	heartbeatTicker   *time.Ticker
	
	onConnected       func()
	onDisconnected    func()
}

// NewManager creates a new connection manager
func NewManager(deviceID, deviceType, firmwareVersion, macAddress string, mqttClient *mqttClient.Client) *Manager {
	return &Manager{
		deviceID:        deviceID,
		deviceType:      deviceType,
		firmwareVersion: firmwareVersion,
		macAddress:      macAddress,
		mqttClient:      mqttClient,
		state:           models.StateDisconnected,
		retryDelay:      InitialRetryDelay,
		stopChan:        make(chan struct{}),
	}
}

// SetCallbacks sets connection state change callbacks
func (m *Manager) SetCallbacks(onConnected, onDisconnected func()) {
	m.onConnected = onConnected
	m.onDisconnected = onDisconnected
}

// Start starts the connection manager
func (m *Manager) Start() error {
	log.Printf("Starting connection manager for device %s", m.deviceID)
	
	// Subscribe to handshake response topic
	responseTopic := fmt.Sprintf("krishi/handshake/response/%s", m.deviceID)
	if err := m.mqttClient.Subscribe(responseTopic, m.handleHandshakeResponse); err != nil {
		return fmt.Errorf("failed to subscribe to handshake response topic: %w", err)
	}

	// Subscribe to heartbeat response topic
	heartbeatRespTopic := fmt.Sprintf("krishi/heartbeat/response/%s", m.deviceID)
	if err := m.mqttClient.Subscribe(heartbeatRespTopic, m.handleHeartbeatResponse); err != nil {
		return fmt.Errorf("failed to subscribe to heartbeat response topic: %w", err)
	}

	// Start connection attempt
	go m.connectLoop()
	
	return nil
}

// connectLoop continuously attempts to establish and maintain connection
func (m *Manager) connectLoop() {
	for {
		select {
		case <-m.stopChan:
			log.Println("Connection loop stopped")
			return
		default:
			m.mu.RLock()
			currentState := m.state
			m.mu.RUnlock()

			switch currentState {
			case models.StateDisconnected, models.StateReconnecting:
				m.attemptHandshake()
				
			case models.StateConnected:
				// Connection is active, wait
				time.Sleep(5 * time.Second)
			}
		}
	}
}

// attemptHandshake attempts to perform handshake with server
func (m *Manager) attemptHandshake() {
	m.mu.Lock()
	m.state = models.StateHandshaking
	m.retryCount++
	m.mu.Unlock()

	log.Printf("Attempting handshake for device %s (attempt %d)", m.deviceID, m.retryCount)

	// Create handshake request
	req := &models.HandshakeRequest{
		DeviceID:        m.deviceID,
		DeviceType:      m.deviceType,
		FirmwareVersion: m.firmwareVersion,
		MACAddress:      m.macAddress,
		Timestamp:       time.Now(),
	}

	payload, err := json.Marshal(req)
	if err != nil {
		log.Printf("Error marshaling handshake request: %v", err)
		m.handleHandshakeFailure()
		return
	}

	// Publish handshake request
	topic := "krishi/handshake/request"
	if err := m.mqttClient.Publish(topic, payload); err != nil {
		log.Printf("Error publishing handshake request: %v", err)
		m.handleHandshakeFailure()
		return
	}

	log.Printf("Handshake request sent for device %s", m.deviceID)

	// Wait for response with timeout
	m.waitForHandshakeResponse()
}

// waitForHandshakeResponse waits for handshake response with timeout
func (m *Manager) waitForHandshakeResponse() {
	timeout := time.After(HandshakeTimeout)
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-timeout:
			log.Printf("Handshake timeout for device %s", m.deviceID)
			m.handleHandshakeFailure()
			return
			
		case <-ticker.C:
			m.mu.RLock()
			state := m.state
			m.mu.RUnlock()

			if state == models.StateConnected {
				// Handshake successful
				return
			} else if state != models.StateHandshaking {
				// Handshake failed
				return
			}
		}
	}
}

// handleHandshakeResponse handles handshake response from server
func (m *Manager) handleHandshakeResponse(client mqtt.Client, msg mqtt.Message) {
	log.Printf("Received handshake response from topic: %s", msg.Topic())

	var resp models.HandshakeResponse
	if err := json.Unmarshal(msg.Payload(), &resp); err != nil {
		log.Printf("Error parsing handshake response: %v", err)
		m.handleHandshakeFailure()
		return
	}

	if resp.Status == "ACK" {
		m.mu.Lock()
		m.state = models.StateConnected
		m.sessionID = resp.SessionID
		m.retryCount = 0
		m.retryDelay = InitialRetryDelay
		m.mu.Unlock()

		log.Printf("Handshake successful for device %s - Session ID: %s", m.deviceID, resp.SessionID)
		
		// Start heartbeat
		m.startHeartbeat()

		// Call connected callback
		if m.onConnected != nil {
			go m.onConnected()
		}
	} else {
		log.Printf("Handshake rejected for device %s - Reason: %s", m.deviceID, resp.Message)
		m.handleHandshakeFailure()
	}
}

// handleHandshakeFailure handles handshake failure and schedules retry
func (m *Manager) handleHandshakeFailure() {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.retryCount >= MaxRetryAttempts {
		log.Printf("Max retry attempts reached for device %s. Will retry after %v", 
			m.deviceID, MaxRetryDelay)
		m.retryDelay = MaxRetryDelay
		m.retryCount = 0
	} else {
		// Exponential backoff
		m.retryDelay = time.Duration(math.Min(
			float64(InitialRetryDelay)*math.Pow(2, float64(m.retryCount-1)),
			float64(MaxRetryDelay),
		))
	}

	m.state = models.StateDisconnected
	
	log.Printf("Handshake failed for device %s. Retrying in %v", m.deviceID, m.retryDelay)
	
	// Schedule retry
	go func() {
		time.Sleep(m.retryDelay)
		m.mu.Lock()
		if m.state == models.StateDisconnected {
			m.state = models.StateReconnecting
		}
		m.mu.Unlock()
	}()
}

// startHeartbeat starts sending periodic heartbeats
func (m *Manager) startHeartbeat() {
	// Stop existing heartbeat if any
	m.stopHeartbeat()

	m.heartbeatTicker = time.NewTicker(HeartbeatInterval)
	
	go func() {
		for {
			select {
			case <-m.heartbeatTicker.C:
				m.sendHeartbeat()
				
			case <-m.stopChan:
				return
			}
		}
	}()

	log.Printf("Heartbeat started for device %s", m.deviceID)
}

// stopHeartbeat stops sending heartbeats
func (m *Manager) stopHeartbeat() {
	if m.heartbeatTicker != nil {
		m.heartbeatTicker.Stop()
		m.heartbeatTicker = nil
	}
}

// sendHeartbeat sends a heartbeat message to the server
func (m *Manager) sendHeartbeat() {
	m.mu.RLock()
	sessionID := m.sessionID
	state := m.state
	m.mu.RUnlock()

	if state != models.StateConnected {
		return
	}

	heartbeat := &models.HeartbeatMessage{
		DeviceID:  m.deviceID,
		SessionID: sessionID,
		Timestamp: time.Now(),
		Status:    "ALIVE",
	}

	payload, err := json.Marshal(heartbeat)
	if err != nil {
		log.Printf("Error marshaling heartbeat: %v", err)
		return
	}

	topic := "krishi/heartbeat/request"
	if err := m.mqttClient.Publish(topic, payload); err != nil {
		log.Printf("Error publishing heartbeat: %v", err)
		m.handleConnectionLost()
	}
}

// handleHeartbeatResponse handles heartbeat response from server
func (m *Manager) handleHeartbeatResponse(client mqtt.Client, msg mqtt.Message) {
	var resp models.HeartbeatResponse
	if err := json.Unmarshal(msg.Payload(), &resp); err != nil {
		log.Printf("Error parsing heartbeat response: %v", err)
		return
	}

	if resp.Status != "OK" {
		log.Printf("Invalid heartbeat response for device %s", m.deviceID)
		m.handleConnectionLost()
	}
}

// handleConnectionLost handles connection loss
func (m *Manager) handleConnectionLost() {
	m.mu.Lock()
	previousState := m.state
	m.state = models.StateReconnecting
	m.sessionID = ""
	m.mu.Unlock()

	if previousState == models.StateConnected {
		log.Printf("Connection lost for device %s. Attempting to reconnect...", m.deviceID)
		
		m.stopHeartbeat()

		// Call disconnected callback
		if m.onDisconnected != nil {
			go m.onDisconnected()
		}
	}
}

// IsConnected returns true if device is connected
func (m *Manager) IsConnected() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.state == models.StateConnected
}

// GetSessionID returns the current session ID
func (m *Manager) GetSessionID() string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.sessionID
}

// GetState returns the current connection state
func (m *Manager) GetState() models.ConnectionState {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.state
}

// Disconnect gracefully disconnects from server
func (m *Manager) Disconnect() error {
	m.mu.Lock()
	sessionID := m.sessionID
	m.state = models.StateDisconnected
	m.mu.Unlock()

	m.stopHeartbeat()

	if sessionID != "" {
		// Send disconnect message
		disconnect := &models.DisconnectMessage{
			DeviceID:  m.deviceID,
			SessionID: sessionID,
			Reason:    "GRACEFUL_SHUTDOWN",
			Timestamp: time.Now(),
		}

		payload, err := json.Marshal(disconnect)
		if err != nil {
			return fmt.Errorf("error marshaling disconnect message: %w", err)
		}

		topic := "krishi/disconnect"
		if err := m.mqttClient.Publish(topic, payload); err != nil {
			return fmt.Errorf("error publishing disconnect message: %w", err)
		}

		log.Printf("Graceful disconnect sent for device %s", m.deviceID)
	}

	return nil
}

// Stop stops the connection manager
func (m *Manager) Stop() {
	m.Disconnect()
	close(m.stopChan)
	log.Printf("Connection manager stopped for device %s", m.deviceID)
}
