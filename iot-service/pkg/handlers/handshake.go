package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/api"
	mqttClient "github.com/pratikni07/Krishi-Mantra/iot-service/pkg/mqtt"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/models"
	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/session"
)

// HandshakeHandler handles device handshake requests
type HandshakeHandler struct {
	mqttClient     *mqttClient.Client
	sessionManager *session.Manager
	apiClient      *api.Client
	devMode        bool
}

// NewHandshakeHandler creates a new handshake handler. devMode permits
// running without an apiClient; outside dev we fail closed on any
// subscription validation path with a nil client.
func NewHandshakeHandler(mqttClient *mqttClient.Client, sessionManager *session.Manager, apiClient *api.Client, devMode bool) *HandshakeHandler {
	return &HandshakeHandler{
		mqttClient:     mqttClient,
		sessionManager: sessionManager,
		apiClient:      apiClient,
		devMode:        devMode,
	}
}

// Start starts the handshake handler
func (h *HandshakeHandler) Start() error {
	log.Println("Starting Handshake Handler...")

	// Subscribe to handshake requests
	if err := h.mqttClient.Subscribe("krishi/handshake/request", h.handleHandshakeRequest); err != nil {
		return fmt.Errorf("failed to subscribe to handshake requests: %w", err)
	}

	// Subscribe to heartbeat requests
	if err := h.mqttClient.Subscribe("krishi/heartbeat/request", h.handleHeartbeatRequest); err != nil {
		return fmt.Errorf("failed to subscribe to heartbeat requests: %w", err)
	}

	// Subscribe to disconnect messages
	if err := h.mqttClient.Subscribe("krishi/disconnect", h.handleDisconnect); err != nil {
		return fmt.Errorf("failed to subscribe to disconnect messages: %w", err)
	}

	log.Println("Handshake Handler started successfully")
	return nil
}

// handleHandshakeRequest handles incoming handshake requests
func (h *HandshakeHandler) handleHandshakeRequest(client mqtt.Client, msg mqtt.Message) {
	log.Printf("Received handshake request from topic: %s", msg.Topic())

	var req models.HandshakeRequest
	if err := json.Unmarshal(msg.Payload(), &req); err != nil {
		log.Printf("Error parsing handshake request: %v", err)
		h.sendNACK(&req, "INVALID_REQUEST_FORMAT")
		return
	}

	// Validate request format
	if err := h.validateHandshakeRequest(&req); err != nil {
		log.Printf("Invalid handshake request from device %s: %v", req.DeviceID, err)
		h.sendNACK(&req, err.Error())
		return
	}

	// Validate device subscription with main service
	subscriptionValid, reason := h.validateDeviceSubscription(&req)
	if !subscriptionValid {
		log.Printf("Subscription validation failed for device %s: %s", req.DeviceID, reason)
		h.sendNACK(&req, reason)
		
		// Log failed handshake attempt
		if h.apiClient != nil {
			h.apiClient.LogDeviceActivity(req.DeviceID, "HANDSHAKE_REJECTED", map[string]interface{}{
				"reason":           reason,
				"device_type":      req.DeviceType,
				"firmware_version": req.FirmwareVersion,
				"mac_address":      req.MACAddress,
			})
		}
		return
	}

	// Create session
	deviceSession, err := h.sessionManager.CreateSession(&req)
	if err != nil {
		// Concurrent-session spoof attempts get a distinct NACK so operators
		// can alert on them and so legitimate devices don't silently race
		// each other.
		if errors.Is(err, session.ErrSessionConflict) {
			log.Printf("Rejected concurrent handshake for device %s", req.DeviceID)
			h.sendNACK(&req, "SESSION_ACTIVE_ELSEWHERE")
			if h.apiClient != nil {
				go h.apiClient.LogDeviceActivity(req.DeviceID, "HANDSHAKE_CONFLICT", map[string]interface{}{
					"mac_address":      req.MACAddress,
					"firmware_version": req.FirmwareVersion,
				})
			}
			return
		}
		log.Printf("Error creating session for device %s: %v", req.DeviceID, err)
		h.sendNACK(&req, "SESSION_CREATION_FAILED")
		return
	}

	// Update device status in main service
	if h.apiClient != nil {
		go h.apiClient.UpdateDeviceStatus(req.DeviceID, "ONLINE", map[string]interface{}{
			"session_id":       deviceSession.SessionID,
			"firmware_version": req.FirmwareVersion,
			"device_type":      req.DeviceType,
		})
		
		// Log successful handshake
		go h.apiClient.LogDeviceActivity(req.DeviceID, "HANDSHAKE_SUCCESS", map[string]interface{}{
			"session_id":       deviceSession.SessionID,
			"device_type":      req.DeviceType,
			"firmware_version": req.FirmwareVersion,
		})
	}

	// Send ACK response
	h.sendACK(&req, deviceSession)
}

// validateHandshakeRequest validates a handshake request format
func (h *HandshakeHandler) validateHandshakeRequest(req *models.HandshakeRequest) error {
	if req.DeviceID == "" {
		return fmt.Errorf("device_id is required")
	}
	if req.DeviceType == "" {
		return fmt.Errorf("device_type is required")
	}
	if req.DeviceType != "soil" && req.DeviceType != "weather" && req.DeviceType != "combo" {
		return fmt.Errorf("invalid device_type: %s", req.DeviceType)
	}
	if req.FirmwareVersion == "" {
		return fmt.Errorf("firmware_version is required")
	}
	if req.MACAddress == "" {
		return fmt.Errorf("mac_address is required")
	}

	return nil
}

// validateDeviceSubscription validates device subscription with main service.
// Fail-closed: if the API client isn't wired, reject unless the operator
// has explicitly opted into dev mode (IOT_DEV_MODE=true).
func (h *HandshakeHandler) validateDeviceSubscription(req *models.HandshakeRequest) (bool, string) {
	if h.apiClient == nil {
		if h.devMode {
			log.Printf("DEV MODE: API client not configured, allowing device %s without subscription check", req.DeviceID)
			return true, ""
		}
		log.Printf("SECURITY: API client not configured — rejecting device %s", req.DeviceID)
		return false, "SUBSCRIPTION_VALIDATION_UNAVAILABLE"
	}

	// Prepare validation request
	validationReq := &models.SubscriptionValidationRequest{
		DeviceID:   req.DeviceID,
		DeviceType: req.DeviceType,
		MACAddress: req.MACAddress,
	}

	// Call main service API
	validationResp, err := h.apiClient.ValidateDeviceSubscription(validationReq)
	if err != nil {
		log.Printf("Error validating subscription for device %s: %v", req.DeviceID, err)
		// On API error, reject for security (fail closed)
		return false, "SUBSCRIPTION_VALIDATION_ERROR"
	}

	// Check validation result
	if !validationResp.IsValid {
		reason := validationResp.Reason
		if reason == "" {
			reason = "NO_ACTIVE_SUBSCRIPTION"
		}
		log.Printf("Device %s has no active subscription: %s - %s", 
			req.DeviceID, reason, validationResp.Message)
		return false, reason
	}

	// Additional checks on subscription
	if validationResp.Subscription != nil {
		if !validationResp.Subscription.IsSubscriptionActive() {
			log.Printf("Device %s subscription is not active: status=%s", 
				req.DeviceID, validationResp.Subscription.Status)
			return false, "SUBSCRIPTION_INACTIVE"
		}

		log.Printf("Device %s subscription validated successfully: user=%s, plan=%s, expires=%s",
			req.DeviceID,
			validationResp.Subscription.UserID,
			validationResp.Subscription.PlanName,
			validationResp.Subscription.EndDate.Format("2006-01-02"))
	}

	return true, ""
}

// sendACK sends an ACK response to the device
func (h *HandshakeHandler) sendACK(req *models.HandshakeRequest, session *models.DeviceSession) {
	resp := &models.HandshakeResponse{
		DeviceID:       req.DeviceID,
		Status:         "ACK",
		SessionID:      session.SessionID,
		Message:        "Connection established successfully",
		Timestamp:      time.Now(),
		ServerTime:     time.Now(),
		SensorInterval: 30, // Default sensor interval in seconds
	}

	h.sendHandshakeResponse(req.DeviceID, resp)
}

// sendNACK sends a NACK response to the device
func (h *HandshakeHandler) sendNACK(req *models.HandshakeRequest, reason string) {
	resp := &models.HandshakeResponse{
		DeviceID:   req.DeviceID,
		Status:     "NACK",
		Message:    reason,
		Timestamp:  time.Now(),
		ServerTime: time.Now(),
	}

	h.sendHandshakeResponse(req.DeviceID, resp)
}

// sendHandshakeResponse sends a handshake response to the device
func (h *HandshakeHandler) sendHandshakeResponse(deviceID string, resp *models.HandshakeResponse) {
	payload, err := json.Marshal(resp)
	if err != nil {
		log.Printf("Error marshaling handshake response: %v", err)
		return
	}

	topic := fmt.Sprintf("krishi/handshake/response/%s", deviceID)
	if err := h.mqttClient.Publish(topic, payload); err != nil {
		log.Printf("Error publishing handshake response: %v", err)
		return
	}

	log.Printf("Sent %s response to device %s", resp.Status, deviceID)
}

// handleHeartbeatRequest handles heartbeat requests from devices
func (h *HandshakeHandler) handleHeartbeatRequest(client mqtt.Client, msg mqtt.Message) {
	var heartbeat models.HeartbeatMessage
	if err := json.Unmarshal(msg.Payload(), &heartbeat); err != nil {
		log.Printf("Error parsing heartbeat message: %v", err)
		return
	}

	// Validate session
	if err := h.sessionManager.ValidateSession(heartbeat.DeviceID, heartbeat.SessionID); err != nil {
		log.Printf("Invalid heartbeat from device %s: %v", heartbeat.DeviceID, err)
		// Send invalid response to trigger reconnection
		h.sendHeartbeatResponse(heartbeat.DeviceID, "INVALID_SESSION")
		return
	}

	// Update heartbeat timestamp
	if err := h.sessionManager.UpdateHeartbeat(heartbeat.DeviceID, heartbeat.SessionID); err != nil {
		log.Printf("Error updating heartbeat for device %s: %v", heartbeat.DeviceID, err)
		return
	}

	// Send OK response
	h.sendHeartbeatResponse(heartbeat.DeviceID, "OK")
}

// sendHeartbeatResponse sends a heartbeat response to the device
func (h *HandshakeHandler) sendHeartbeatResponse(deviceID, status string) {
	resp := &models.HeartbeatResponse{
		DeviceID:  deviceID,
		Status:    status,
		Timestamp: time.Now(),
	}

	payload, err := json.Marshal(resp)
	if err != nil {
		log.Printf("Error marshaling heartbeat response: %v", err)
		return
	}

	topic := fmt.Sprintf("krishi/heartbeat/response/%s", deviceID)
	if err := h.mqttClient.Publish(topic, payload); err != nil {
		log.Printf("Error publishing heartbeat response: %v", err)
	}
}

// handleDisconnect handles disconnect messages from devices
func (h *HandshakeHandler) handleDisconnect(client mqtt.Client, msg mqtt.Message) {
	var disconnect models.DisconnectMessage
	if err := json.Unmarshal(msg.Payload(), &disconnect); err != nil {
		log.Printf("Error parsing disconnect message: %v", err)
		return
	}

	// Terminate session
	if err := h.sessionManager.TerminateSession(disconnect.DeviceID, disconnect.SessionID); err != nil {
		log.Printf("Error terminating session for device %s: %v", disconnect.DeviceID, err)
		return
	}

	// Update device status in main service
	if h.apiClient != nil {
		go h.apiClient.UpdateDeviceStatus(disconnect.DeviceID, "OFFLINE", map[string]interface{}{
			"reason":     disconnect.Reason,
			"session_id": disconnect.SessionID,
		})
		
		// Log disconnect
		go h.apiClient.LogDeviceActivity(disconnect.DeviceID, "DISCONNECT", map[string]interface{}{
			"reason":     disconnect.Reason,
			"session_id": disconnect.SessionID,
		})
	}

	log.Printf("Device %s disconnected gracefully: %s", disconnect.DeviceID, disconnect.Reason)
}

// ValidateDeviceSession validates if a device has an active session
func (h *HandshakeHandler) ValidateDeviceSession(deviceID, sessionID string) error {
	return h.sessionManager.ValidateSession(deviceID, sessionID)
}
