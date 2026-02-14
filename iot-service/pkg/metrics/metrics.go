package metrics

import (
	"log"
	"sync"
	"time"
)

// Metrics holds various IoT service metrics
type Metrics struct {
	// Handshake metrics
	HandshakeAttempts    int64
	HandshakeSuccesses   int64
	HandshakeFailures    int64
	
	// Session metrics
	ActiveSessions       int64
	TotalSessions        int64
	ExpiredSessions      int64
	
	// Data metrics
	MessagesReceived     int64
	MessagesProcessed    int64
	MessagesRejected     int64
	
	// Heartbeat metrics
	HeartbeatsReceived   int64
	HeartbeatsMissed     int64
	
	// Connection metrics
	ReconnectionAttempts int64
	
	mu                   sync.RWMutex
	startTime            time.Time
}

// NewMetrics creates a new metrics instance
func NewMetrics() *Metrics {
	return &Metrics{
		startTime: time.Now(),
	}
}

// IncrementHandshakeAttempts increments handshake attempt counter
func (m *Metrics) IncrementHandshakeAttempts() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.HandshakeAttempts++
}

// IncrementHandshakeSuccesses increments handshake success counter
func (m *Metrics) IncrementHandshakeSuccesses() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.HandshakeSuccesses++
}

// IncrementHandshakeFailures increments handshake failure counter
func (m *Metrics) IncrementHandshakeFailures() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.HandshakeFailures++
}

// SetActiveSessions sets the active sessions count
func (m *Metrics) SetActiveSessions(count int64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.ActiveSessions = count
}

// IncrementTotalSessions increments total sessions created
func (m *Metrics) IncrementTotalSessions() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.TotalSessions++
}

// IncrementExpiredSessions increments expired sessions counter
func (m *Metrics) IncrementExpiredSessions() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.ExpiredSessions++
}

// IncrementMessagesReceived increments messages received counter
func (m *Metrics) IncrementMessagesReceived() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.MessagesReceived++
}

// IncrementMessagesProcessed increments messages processed counter
func (m *Metrics) IncrementMessagesProcessed() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.MessagesProcessed++
}

// IncrementMessagesRejected increments messages rejected counter
func (m *Metrics) IncrementMessagesRejected() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.MessagesRejected++
}

// IncrementHeartbeatsReceived increments heartbeats received counter
func (m *Metrics) IncrementHeartbeatsReceived() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.HeartbeatsReceived++
}

// IncrementHeartbeatsMissed increments heartbeats missed counter
func (m *Metrics) IncrementHeartbeatsMissed() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.HeartbeatsMissed++
}

// IncrementReconnectionAttempts increments reconnection attempts counter
func (m *Metrics) IncrementReconnectionAttempts() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.ReconnectionAttempts++
}

// GetSnapshot returns a snapshot of current metrics
func (m *Metrics) GetSnapshot() map[string]interface{} {
	m.mu.RLock()
	defer m.mu.RUnlock()
	
	uptime := time.Since(m.startTime)
	
	return map[string]interface{}{
		"uptime_seconds":          uptime.Seconds(),
		"handshake_attempts":      m.HandshakeAttempts,
		"handshake_successes":     m.HandshakeSuccesses,
		"handshake_failures":      m.HandshakeFailures,
		"handshake_success_rate":  m.getSuccessRate(m.HandshakeSuccesses, m.HandshakeAttempts),
		"active_sessions":         m.ActiveSessions,
		"total_sessions":          m.TotalSessions,
		"expired_sessions":        m.ExpiredSessions,
		"messages_received":       m.MessagesReceived,
		"messages_processed":      m.MessagesProcessed,
		"messages_rejected":       m.MessagesRejected,
		"message_success_rate":    m.getSuccessRate(m.MessagesProcessed, m.MessagesReceived),
		"heartbeats_received":     m.HeartbeatsReceived,
		"heartbeats_missed":       m.HeartbeatsMissed,
		"reconnection_attempts":   m.ReconnectionAttempts,
	}
}

// getSuccessRate calculates success rate as percentage
func (m *Metrics) getSuccessRate(success, total int64) float64 {
	if total == 0 {
		return 0.0
	}
	return float64(success) / float64(total) * 100.0
}

// LogMetrics logs current metrics
func (m *Metrics) LogMetrics() {
	snapshot := m.GetSnapshot()
	
	log.Println("=== IoT Service Metrics ===")
	log.Printf("Uptime: %.0f seconds", snapshot["uptime_seconds"])
	log.Printf("Handshake: %d attempts, %d successes, %d failures (%.2f%% success rate)",
		snapshot["handshake_attempts"],
		snapshot["handshake_successes"],
		snapshot["handshake_failures"],
		snapshot["handshake_success_rate"])
	log.Printf("Sessions: %d active, %d total, %d expired",
		snapshot["active_sessions"],
		snapshot["total_sessions"],
		snapshot["expired_sessions"])
	log.Printf("Messages: %d received, %d processed, %d rejected (%.2f%% success rate)",
		snapshot["messages_received"],
		snapshot["messages_processed"],
		snapshot["messages_rejected"],
		snapshot["message_success_rate"])
	log.Printf("Heartbeats: %d received, %d missed",
		snapshot["heartbeats_received"],
		snapshot["heartbeats_missed"])
	log.Printf("Reconnections: %d attempts", snapshot["reconnection_attempts"])
	log.Println("===========================")
}

// StartPeriodicLogging starts periodic metrics logging
func (m *Metrics) StartPeriodicLogging(interval time.Duration) {
	ticker := time.NewTicker(interval)
	go func() {
		for range ticker.C {
			m.LogMetrics()
		}
	}()
}
