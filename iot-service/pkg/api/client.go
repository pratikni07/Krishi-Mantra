package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/pratikni07/Krishi-Mantra/iot-service/pkg/models"
)

// Client represents the internal API client for communicating with main service
type Client struct {
	baseURL    string
	httpClient *http.Client
	apiKey     string
}

// NewClient creates a new internal API client
func NewClient(baseURL, apiKey string) *Client {
	return &Client{
		baseURL: baseURL,
		apiKey:  apiKey,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// ValidateDeviceSubscription validates if a device has an active subscription
func (c *Client) ValidateDeviceSubscription(req *models.SubscriptionValidationRequest) (*models.SubscriptionValidationResponse, error) {
	log.Printf("Validating subscription for device: %s", req.DeviceID)

	// Prepare request
	payload, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Create HTTP request
	url := fmt.Sprintf("%s/api/v1/iot/validate-subscription", c.baseURL)
	httpReq, err := http.NewRequest("POST", url, bytes.NewBuffer(payload))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Set headers
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-API-Key", c.apiKey)
	httpReq.Header.Set("X-Service", "iot-service")

	// Send request
	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	// Handle non-200 responses
	if resp.StatusCode != http.StatusOK {
		log.Printf("Subscription validation failed with status %d: %s", resp.StatusCode, string(body))
		return &models.SubscriptionValidationResponse{
			IsValid: false,
			Reason:  "VALIDATION_FAILED",
			Message: fmt.Sprintf("API returned status %d", resp.StatusCode),
		}, nil
	}

	// Parse response
	var validationResp models.SubscriptionValidationResponse
	if err := json.Unmarshal(body, &validationResp); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	log.Printf("Subscription validation result for device %s: valid=%v, reason=%s",
		req.DeviceID, validationResp.IsValid, validationResp.Reason)

	return &validationResp, nil
}

// GetDeviceSubscription retrieves device subscription details
func (c *Client) GetDeviceSubscription(deviceID string) (*models.DeviceSubscription, error) {
	log.Printf("Fetching subscription details for device: %s", deviceID)

	url := fmt.Sprintf("%s/api/v1/iot/devices/%s/subscription", c.baseURL, deviceID)
	httpReq, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	httpReq.Header.Set("X-API-Key", c.apiKey)
	httpReq.Header.Set("X-Service", "iot-service")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	var subscription models.DeviceSubscription
	if err := json.Unmarshal(body, &subscription); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	return &subscription, nil
}

// UpdateDeviceStatus updates device online/offline status
func (c *Client) UpdateDeviceStatus(deviceID, status string, metadata map[string]interface{}) error {
	log.Printf("Updating device status: %s -> %s", deviceID, status)

	payload := map[string]interface{}{
		"device_id": deviceID,
		"status":    status,
		"metadata":  metadata,
		"timestamp": time.Now(),
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/api/v1/iot/devices/%s/status", c.baseURL, deviceID)
	httpReq, err := http.NewRequest("PUT", url, bytes.NewBuffer(data))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-API-Key", c.apiKey)
	httpReq.Header.Set("X-Service", "iot-service")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	return nil
}

// LogDeviceActivity logs device activity to main service
func (c *Client) LogDeviceActivity(deviceID, activityType string, details map[string]interface{}) error {
	payload := map[string]interface{}{
		"device_id":     deviceID,
		"activity_type": activityType,
		"details":       details,
		"timestamp":     time.Now(),
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/api/v1/iot/devices/activity", c.baseURL)
	httpReq, err := http.NewRequest("POST", url, bytes.NewBuffer(data))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-API-Key", c.apiKey)
	httpReq.Header.Set("X-Service", "iot-service")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		// Log but don't fail on activity logging errors
		log.Printf("Failed to log device activity: %v", err)
		return nil
	}
	defer resp.Body.Close()

	return nil
}

// HealthCheck checks if the main service API is accessible
func (c *Client) HealthCheck() error {
	url := fmt.Sprintf("%s/api/v1/health", c.baseURL)
	httpReq, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	httpReq.Header.Set("X-Service", "iot-service")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return fmt.Errorf("health check failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("health check returned status %d", resp.StatusCode)
	}

	return nil
}
