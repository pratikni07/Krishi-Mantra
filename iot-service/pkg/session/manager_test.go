package session

import (
	"testing"
	"time"

	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/models"
)

func TestCreateSession(t *testing.T) {
	mgr := NewManager()
	defer mgr.Stop()

	req := &models.HandshakeRequest{
		DeviceID:        "test-device-001",
		DeviceType:      "soil",
		FirmwareVersion: "1.0.0",
		MACAddress:      "AA:BB:CC:DD:EE:FF",
		Timestamp:       time.Now(),
	}

	session, err := mgr.CreateSession(req)
	if err != nil {
		t.Fatalf("Failed to create session: %v", err)
	}

	if session.DeviceID != req.DeviceID {
		t.Errorf("Expected device ID %s, got %s", req.DeviceID, session.DeviceID)
	}

	if session.SessionID == "" {
		t.Error("Session ID should not be empty")
	}

	if !session.IsActive {
		t.Error("Session should be active")
	}
}

func TestValidateSession(t *testing.T) {
	mgr := NewManager()
	defer mgr.Stop()

	req := &models.HandshakeRequest{
		DeviceID:        "test-device-002",
		DeviceType:      "weather",
		FirmwareVersion: "1.0.0",
		MACAddress:      "AA:BB:CC:DD:EE:FF",
		Timestamp:       time.Now(),
	}

	session, err := mgr.CreateSession(req)
	if err != nil {
		t.Fatalf("Failed to create session: %v", err)
	}

	// Test valid session
	err = mgr.ValidateSession(session.DeviceID, session.SessionID)
	if err != nil {
		t.Errorf("Valid session should pass validation: %v", err)
	}

	// Test invalid session ID
	err = mgr.ValidateSession(session.DeviceID, "invalid-session-id")
	if err == nil {
		t.Error("Invalid session ID should fail validation")
	}

	// Test mismatched device ID
	err = mgr.ValidateSession("wrong-device", session.SessionID)
	if err == nil {
		t.Error("Mismatched device ID should fail validation")
	}
}

func TestUpdateHeartbeat(t *testing.T) {
	mgr := NewManager()
	defer mgr.Stop()

	req := &models.HandshakeRequest{
		DeviceID:        "test-device-003",
		DeviceType:      "combo",
		FirmwareVersion: "1.0.0",
		MACAddress:      "AA:BB:CC:DD:EE:FF",
		Timestamp:       time.Now(),
	}

	session, err := mgr.CreateSession(req)
	if err != nil {
		t.Fatalf("Failed to create session: %v", err)
	}

	initialHeartbeat := session.LastHeartbeat
	time.Sleep(10 * time.Millisecond)

	err = mgr.UpdateHeartbeat(session.DeviceID, session.SessionID)
	if err != nil {
		t.Errorf("Failed to update heartbeat: %v", err)
	}

	updatedSession, err := mgr.GetSession(session.SessionID)
	if err != nil {
		t.Fatalf("Failed to get session: %v", err)
	}

	if !updatedSession.LastHeartbeat.After(initialHeartbeat) {
		t.Error("Heartbeat timestamp should be updated")
	}
}

func TestTerminateSession(t *testing.T) {
	mgr := NewManager()
	defer mgr.Stop()

	req := &models.HandshakeRequest{
		DeviceID:        "test-device-004",
		DeviceType:      "soil",
		FirmwareVersion: "1.0.0",
		MACAddress:      "AA:BB:CC:DD:EE:FF",
		Timestamp:       time.Now(),
	}

	session, err := mgr.CreateSession(req)
	if err != nil {
		t.Fatalf("Failed to create session: %v", err)
	}

	err = mgr.TerminateSession(session.DeviceID, session.SessionID)
	if err != nil {
		t.Errorf("Failed to terminate session: %v", err)
	}

	// Session should no longer exist
	_, err = mgr.GetSession(session.SessionID)
	if err == nil {
		t.Error("Terminated session should not be found")
	}

	// Device should not have active session
	_, err = mgr.GetDeviceSession(session.DeviceID)
	if err == nil {
		t.Error("Device should not have active session after termination")
	}
}

func TestGetActiveSessions(t *testing.T) {
	mgr := NewManager()
	defer mgr.Stop()

	initialCount := mgr.GetActiveSessions()
	if initialCount != 0 {
		t.Errorf("Expected 0 active sessions, got %d", initialCount)
	}

	// Create multiple sessions
	for i := 1; i <= 3; i++ {
		req := &models.HandshakeRequest{
			DeviceID:        "test-device-" + string(rune('0'+i)),
			DeviceType:      "soil",
			FirmwareVersion: "1.0.0",
			MACAddress:      "AA:BB:CC:DD:EE:FF",
			Timestamp:       time.Now(),
		}
		_, err := mgr.CreateSession(req)
		if err != nil {
			t.Fatalf("Failed to create session: %v", err)
		}
	}

	count := mgr.GetActiveSessions()
	if count != 3 {
		t.Errorf("Expected 3 active sessions, got %d", count)
	}
}

func TestReplaceExistingSession(t *testing.T) {
	mgr := NewManager()
	defer mgr.Stop()

	req := &models.HandshakeRequest{
		DeviceID:        "test-device-005",
		DeviceType:      "weather",
		FirmwareVersion: "1.0.0",
		MACAddress:      "AA:BB:CC:DD:EE:FF",
		Timestamp:       time.Now(),
	}

	// Create first session
	session1, err := mgr.CreateSession(req)
	if err != nil {
		t.Fatalf("Failed to create first session: %v", err)
	}

	// Create second session for same device
	session2, err := mgr.CreateSession(req)
	if err != nil {
		t.Fatalf("Failed to create second session: %v", err)
	}

	// First session should be invalidated
	_, err = mgr.GetSession(session1.SessionID)
	if err == nil {
		t.Error("Old session should be invalidated")
	}

	// Second session should be active
	err = mgr.ValidateSession(session2.DeviceID, session2.SessionID)
	if err != nil {
		t.Errorf("New session should be valid: %v", err)
	}

	// Should only have 1 active session for this device
	if mgr.GetActiveSessions() != 1 {
		t.Errorf("Should have exactly 1 active session")
	}
}
