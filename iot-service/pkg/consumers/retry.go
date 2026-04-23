package consumers

import "time"

// saveWithRetry invokes fn up to attempts times with exponential backoff
// (100ms, 500ms, 2s, ...). Returns the final error if every attempt fails.
// Shared across sensor consumers so the retry policy stays consistent.
func saveWithRetry(fn func() error, attempts int) error {
	if attempts < 1 {
		attempts = 1
	}
	backoffs := []time.Duration{
		100 * time.Millisecond,
		500 * time.Millisecond,
		2 * time.Second,
		5 * time.Second,
	}
	var lastErr error
	for i := 0; i < attempts; i++ {
		if err := fn(); err == nil {
			return nil
		} else {
			lastErr = err
		}
		if i < attempts-1 {
			sleep := backoffs[len(backoffs)-1]
			if i < len(backoffs) {
				sleep = backoffs[i]
			}
			time.Sleep(sleep)
		}
	}
	return lastErr
}
