package session

import (
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/models"
)

const (
	// SessionTimeout - duration after which a session expires without heartbeat
	SessionTimeout = 5 * time.Minute
	// HeartbeatInterval - expected interval between heartbeats
	HeartbeatInterval = 30 * time.Second
)

// Manager manages active device sessions
type Manager struct {
	sessions map[string]*models.DeviceSession // sessionID -> DeviceSession
	devices  map[string]string                // deviceID -> sessionID
	mu       sync.RWMutex
	stopChan chan struct{}
}

// NewManager creates a new session manager
func NewManager() *Manager {
	m := &Manager{
		sessions: make(map[string]*models.DeviceSession),
		devices:  make(map[string]string),
		stopChan: make(chan struct{}),
	}
	
	// Start session cleanup routine
	go m.cleanupExpiredSessions()
	
	return m
}

// ErrSessionConflict is returned when a handshake request for a device_id
// collides with an already-active session and the caller did not set
// Takeover=true. Callers should surface this as NACK SESSION_ACTIVE_ELSEWHERE
// to the offending device.
var ErrSessionConflict = fmt.Errorf("device has an active session")

// CreateSession creates a new session for a device. Refuses concurrent
// handshakes (same device_id, still-live session) unless req.Takeover is set
// — previously any second handshake silently displaced the first, letting a
// rogue device spoof a legitimate one.
func (m *Manager) CreateSession(req *models.HandshakeRequest) (*models.DeviceSession, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Check if device already has an active session. A session is only a
	// conflict if it hasn't already timed out — an abandoned session (device
	// lost power, never sent DISCONNECT) should be replaceable freely.
	if existingSessionID, exists := m.devices[req.DeviceID]; exists {
		existing, ok := m.sessions[existingSessionID]
		sessionStillAlive := ok && existing.IsActive && time.Since(existing.LastHeartbeat) <= SessionTimeout
		if sessionStillAlive && !req.Takeover {
			log.Printf("SECURITY: refused concurrent handshake for device %s (active session %s, takeover=false)",
				req.DeviceID, existingSessionID)
			return nil, ErrSessionConflict
		}
		// Either the existing session is stale, or the caller explicitly
		// asked to take over. Displace it.
		delete(m.sessions, existingSessionID)
		if req.Takeover {
			log.Printf("Takeover requested for device %s — displacing session %s", req.DeviceID, existingSessionID)
		} else {
			log.Printf("Replacing stale session %s for device %s", existingSessionID, req.DeviceID)
		}
	}

	// Create new session
	sessionID := uuid.New().String()
	now := time.Now()
	
	session := &models.DeviceSession{
		DeviceID:        req.DeviceID,
		SessionID:       sessionID,
		DeviceType:      req.DeviceType,
		ConnectedAt:     now,
		LastHeartbeat:   now,
		FirmwareVersion: req.FirmwareVersion,
		MACAddress:      req.MACAddress,
		IsActive:        true,
	}

	m.sessions[sessionID] = session
	m.devices[req.DeviceID] = sessionID

	log.Printf("Created session %s for device %s (type: %s, firmware: %s)", 
		sessionID, req.DeviceID, req.DeviceType, req.FirmwareVersion)
	
	return session, nil
}

// ValidateSession checks if a session is valid and active
func (m *Manager) ValidateSession(deviceID, sessionID string) error {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// Check if session exists
	session, exists := m.sessions[sessionID]
	if !exists {
		return fmt.Errorf("session not found: %s", sessionID)
	}

	// Verify deviceID matches
	if session.DeviceID != deviceID {
		return fmt.Errorf("device ID mismatch for session %s", sessionID)
	}

	// Check if session is active
	if !session.IsActive {
		return fmt.Errorf("session is inactive: %s", sessionID)
	}

	// Check if session has expired
	if time.Since(session.LastHeartbeat) > SessionTimeout {
		return fmt.Errorf("session expired: %s", sessionID)
	}

	return nil
}

// UpdateHeartbeat updates the last heartbeat timestamp for a session
func (m *Manager) UpdateHeartbeat(deviceID, sessionID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	session, exists := m.sessions[sessionID]
	if !exists {
		return fmt.Errorf("session not found: %s", sessionID)
	}

	if session.DeviceID != deviceID {
		return fmt.Errorf("device ID mismatch for session %s", sessionID)
	}

	session.LastHeartbeat = time.Now()
	log.Printf("Updated heartbeat for device %s (session: %s)", deviceID, sessionID)
	
	return nil
}

// TerminateSession terminates a device session
func (m *Manager) TerminateSession(deviceID, sessionID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	session, exists := m.sessions[sessionID]
	if !exists {
		return fmt.Errorf("session not found: %s", sessionID)
	}

	if session.DeviceID != deviceID {
		return fmt.Errorf("device ID mismatch for session %s", sessionID)
	}

	session.IsActive = false
	delete(m.sessions, sessionID)
	delete(m.devices, deviceID)

	log.Printf("Terminated session %s for device %s", sessionID, deviceID)
	
	return nil
}

// GetSession retrieves a session by sessionID
func (m *Manager) GetSession(sessionID string) (*models.DeviceSession, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	session, exists := m.sessions[sessionID]
	if !exists {
		return nil, fmt.Errorf("session not found: %s", sessionID)
	}

	return session, nil
}

// GetDeviceSession retrieves a session by deviceID
func (m *Manager) GetDeviceSession(deviceID string) (*models.DeviceSession, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	sessionID, exists := m.devices[deviceID]
	if !exists {
		return nil, fmt.Errorf("no active session for device: %s", deviceID)
	}

	session, exists := m.sessions[sessionID]
	if !exists {
		return nil, fmt.Errorf("session not found: %s", sessionID)
	}

	return session, nil
}

// GetActiveSessions returns the number of active sessions
func (m *Manager) GetActiveSessions() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.sessions)
}

// cleanupExpiredSessions periodically removes expired sessions
func (m *Manager) cleanupExpiredSessions() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			m.performCleanup()
		case <-m.stopChan:
			log.Println("Stopping session cleanup routine")
			return
		}
	}
}

// performCleanup removes expired sessions
func (m *Manager) performCleanup() {
	m.mu.Lock()
	defer m.mu.Unlock()

	now := time.Now()
	expiredSessions := []string{}

	for sessionID, session := range m.sessions {
		if now.Sub(session.LastHeartbeat) > SessionTimeout {
			expiredSessions = append(expiredSessions, sessionID)
		}
	}

	for _, sessionID := range expiredSessions {
		session := m.sessions[sessionID]
		session.IsActive = false
		delete(m.sessions, sessionID)
		delete(m.devices, session.DeviceID)
		log.Printf("Cleaned up expired session %s for device %s", sessionID, session.DeviceID)
	}

	if len(expiredSessions) > 0 {
		log.Printf("Cleaned up %d expired sessions", len(expiredSessions))
	}
}

// Stop stops the session manager
func (m *Manager) Stop() {
	close(m.stopChan)
	log.Println("Session manager stopped")
}
