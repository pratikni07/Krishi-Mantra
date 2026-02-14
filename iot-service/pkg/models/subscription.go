package models

import "time"

// SubscriptionStatus represents the status of a device subscription
type SubscriptionStatus string

const (
	SubscriptionActive   SubscriptionStatus = "ACTIVE"
	SubscriptionExpired  SubscriptionStatus = "EXPIRED"
	SubscriptionSuspended SubscriptionStatus = "SUSPENDED"
	SubscriptionCancelled SubscriptionStatus = "CANCELLED"
)

// DeviceSubscription represents a device's subscription information
type DeviceSubscription struct {
	DeviceID       string             `json:"device_id"`
	UserID         string             `json:"user_id"`
	SubscriptionID string             `json:"subscription_id"`
	Status         SubscriptionStatus `json:"status"`
	PlanName       string             `json:"plan_name"`
	StartDate      time.Time          `json:"start_date"`
	EndDate        time.Time          `json:"end_date"`
	IsActive       bool               `json:"is_active"`
	Features       []string           `json:"features,omitempty"`
	MaxDevices     int                `json:"max_devices,omitempty"`
}

// SubscriptionValidationRequest represents the request to validate device subscription
type SubscriptionValidationRequest struct {
	DeviceID   string `json:"device_id"`
	DeviceType string `json:"device_type"`
	MACAddress string `json:"mac_address"`
}

// SubscriptionValidationResponse represents the response from subscription validation
type SubscriptionValidationResponse struct {
	IsValid      bool                `json:"is_valid"`
	Subscription *DeviceSubscription `json:"subscription,omitempty"`
	Reason       string              `json:"reason,omitempty"`
	Message      string              `json:"message"`
}

// IsSubscriptionActive checks if the subscription is active
func (s *DeviceSubscription) IsSubscriptionActive() bool {
	if !s.IsActive {
		return false
	}
	
	if s.Status != SubscriptionActive {
		return false
	}
	
	now := time.Now()
	if now.Before(s.StartDate) || now.After(s.EndDate) {
		return false
	}
	
	return true
}
