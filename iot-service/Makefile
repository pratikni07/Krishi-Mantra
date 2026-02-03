.PHONY: build test clean run-device run-parser run-soil run-weather docker-build help

# Build the IoT service binary
build:
	@echo "Building IoT service..."
	go build -o iot-service ./cmd/main

# Run tests
test:
	@echo "Running tests..."
	go test ./... -v

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -f iot-service
	go clean

# Run as device simulator
run-device: build
	@echo "Running as device simulator..."
	APP_TYPE=device DEVICE_ID=device-001 ./iot-service

# Run as parser service
run-parser: build
	@echo "Running as parser service..."
	APP_TYPE=parser ./iot-service

# Run as soil consumer
run-soil: build
	@echo "Running as soil consumer..."
	APP_TYPE=soil ./iot-service

# Run as weather consumer
run-weather: build
	@echo "Running as weather consumer..."
	APP_TYPE=weather ./iot-service

# Build Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t krishi-iot-service:latest .

# Start all services with docker-compose
docker-up:
	@echo "Starting all services with docker-compose..."
	cd .. && docker-compose -f docker-compose.iot.yml up -d

# Stop all services
docker-down:
	@echo "Stopping all services..."
	cd .. && docker-compose -f docker-compose.iot.yml down

# View logs
docker-logs:
	@echo "Viewing logs..."
	cd .. && docker-compose -f docker-compose.iot.yml logs -f

# Format code
fmt:
	@echo "Formatting code..."
	go fmt ./...

# Run linter
lint:
	@echo "Running linter..."
	golangci-lint run || echo "golangci-lint not installed. Install with: curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin"

# Help
help:
	@echo "Available targets:"
	@echo "  build         - Build the IoT service binary"
	@echo "  test          - Run all tests"
	@echo "  clean         - Clean build artifacts"
	@echo "  run-device    - Run as device simulator"
	@echo "  run-parser    - Run as parser service"
	@echo "  run-soil      - Run as soil consumer"
	@echo "  run-weather   - Run as weather consumer"
	@echo "  docker-build  - Build Docker image"
	@echo "  docker-up     - Start all services with docker-compose"
	@echo "  docker-down   - Stop all services"
	@echo "  docker-logs   - View service logs"
	@echo "  fmt           - Format code"
	@echo "  lint          - Run linter"
	@echo "  help          - Show this help message"
