package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/brojyf/CoLiz/internal/app"
	"github.com/brojyf/CoLiz/internal/config"
)

const defaultWatchInterval = 30 * time.Second

func main() {
	ctx, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer stop()

	cfg, err := config.InitConfig()
	if err != nil {
		log.Fatalf("[main] init config: %v", err)
	}

	a, err := app.NewApp(cfg)
	if err != nil {
		log.Fatalf("[main] init app: %v", err)
	}

	rotationEnvPath := filepath.Join("runtime", "rotation.env")
	a.WatchRotation(ctx, rotationEnvPath, defaultWatchInterval)

	errCh := make(chan error, 1)
	go func() {
		log.Println("[main] http server starting...")
		errCh <- a.Start()
	}()

	select {
	case <-ctx.Done():
		log.Println("[main] shutdown signal received...")
	case err = <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Printf("[main] server error: %v", err)
		}
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err = a.Close(shutdownCtx); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("[main] shutdown server: %v", err)
	}

	time.Sleep(100 * time.Millisecond)
	log.Printf("[main] server closed")
}
