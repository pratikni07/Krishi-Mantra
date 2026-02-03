package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"krishi-mantra/iot-service/internal/config"
	"krishi-mantra/iot-service/internal/consumers"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	appType := strings.ToLower(strings.TrimSpace(cfg.AppType))
	log.Printf("starting iot-service with app type: %s", appType)

	var runErr error
	switch appType {
	case "device":
		runErr = consumers.RunDevice(ctx, cfg)
	case "parser":
		runErr = consumers.RunParser(ctx, cfg)
	case "soil":
		runErr = consumers.RunSoil(ctx, cfg)
	case "weather":
		runErr = consumers.RunWeather(ctx, cfg)
	default:
		log.Fatalf("unknown APP_TYPE: %s", cfg.AppType)
	}

	if runErr != nil {
		log.Fatalf("service stopped with error: %v", runErr)
	}
}
