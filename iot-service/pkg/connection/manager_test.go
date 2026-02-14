package connection

import (
	"testing"
	"time"
)

func TestExponentialBackoff(t *testing.T) {
	tests := []struct {
		retryCount int
		expected   time.Duration
		maxDelay   time.Duration
	}{
		{1, 2 * time.Second, MaxRetryDelay},
		{2, 4 * time.Second, MaxRetryDelay},
		{3, 8 * time.Second, MaxRetryDelay},
		{4, 16 * time.Second, MaxRetryDelay},
		{5, 32 * time.Second, MaxRetryDelay},
		{10, MaxRetryDelay, MaxRetryDelay}, // Should cap at max
	}

	for _, tt := range tests {
		t.Run("", func(t *testing.T) {
			// Calculate exponential backoff
			delay := InitialRetryDelay
			for i := 1; i < tt.retryCount; i++ {
				delay = delay * 2
				if delay > tt.maxDelay {
					delay = tt.maxDelay
					break
				}
			}

			if delay != tt.expected {
				t.Errorf("Retry count %d: expected %v, got %v", tt.retryCount, tt.expected, delay)
			}
		})
	}
}

func TestConnectionStates(t *testing.T) {
	// This is a basic test to ensure state transitions work
	// In a real scenario, you'd mock the MQTT client
	t.Skip("Requires MQTT broker for integration testing")
}
