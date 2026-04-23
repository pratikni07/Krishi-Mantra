package models

import "time"

// ConnectionState represents the current state of the device connection
type ConnectionState int

const (
	// StateDisconnected - device is not connected
	StateDisconnected ConnectionState = iota
	// StateHandshaking - device is attempting to establish connection
	StateHandshaking
	// StateConnected - device is connected and authenticated
	StateConnected
	// StateReconnecting - device lost connection and is attempting to reconnect
	StateReconnecting
)

func (s ConnectionState) String() string {
	return [...]string{"DISCONNECTED", "HANDSHAKING", "CONNECTED", "RECONNECTING"}[s]
}

// HandshakeRequest represents the initial connection request from a device
type HandshakeRequest struct {
	DeviceID        string    `json:"device_id"`
	DeviceType      string    `json:"device_type"`      // "soil", "weather", "combo"
	FirmwareVersion string    `json:"firmware_version"`
	MACAddress      string    `json:"mac_address"`
	Timestamp       time.Time `json:"timestamp"`
	// Optional authentication token
	Token           string    `json:"token,omitempty"`
	// Takeover must be explicitly set to true to displace an active session
	// for the same device_id. Without it, a second device presenting the same
	// ID is rejected — this prevents a rogue device from silently hijacking a
	// legitimate one.
	Takeover        bool      `json:"takeover,omitempty"`
}

// HandshakeResponse represents the server's response to a handshake request
type HandshakeResponse struct {
	DeviceID       string    `json:"device_id"`
	Status         string    `json:"status"`          // "ACK" or "NACK"
	SessionID      string    `json:"session_id,omitempty"`
	Message        string    `json:"message,omitempty"`
	Timestamp      time.Time `json:"timestamp"`
	ServerTime     time.Time `json:"server_time"`
	// Configuration parameters from server
	SensorInterval int       `json:"sensor_interval,omitempty"`
}

// HeartbeatMessage represents periodic heartbeat to maintain connection
type HeartbeatMessage struct {
	DeviceID  string    `json:"device_id"`
	SessionID string    `json:"session_id"`
	Timestamp time.Time `json:"timestamp"`
	Status    string    `json:"status"` // "ALIVE"
}

// HeartbeatResponse represents server's heartbeat acknowledgment
type HeartbeatResponse struct {
	DeviceID  string    `json:"device_id"`
	SessionID string    `json:"session_id"`
	Status    string    `json:"status"` // "OK"
	Timestamp time.Time `json:"timestamp"`
}

// DisconnectMessage represents graceful disconnect request
type DisconnectMessage struct {
	DeviceID  string    `json:"device_id"`
	SessionID string    `json:"session_id"`
	Reason    string    `json:"reason"`
	Timestamp time.Time `json:"timestamp"`
}

// DeviceSession represents an active device session on the server
type DeviceSession struct {
	DeviceID        string
	SessionID       string
	DeviceType      string
	ConnectedAt     time.Time
	LastHeartbeat   time.Time
	FirmwareVersion string
	MACAddress      string
	IsActive        bool
}
