package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/VykSI/Devops/app/internal/database"
	"github.com/VykSI/Devops/app/internal/handler"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/VykSI/Devops/app/internal/metrics"
)

func main() {
	logger := slog.New(
		slog.NewJSONHandler(os.Stdout, nil),
	)

	port := getEnv("PORT", "8080")

	dbConfig := database.Config{
		Host:     getEnv("DB_HOST", "localhost"),
		Port:     getEnv("DB_PORT", "5432"),
		User:     getEnv("DB_USER", "app"),
		Password: getEnv("DB_PASSWORD", "app"),
		Name:     getEnv("DB_NAME", "app"),
	}

	ctx := context.Background()

	db, err := database.New(ctx, dbConfig)
	if err != nil {
		logger.Error("database connection failed", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	itemHandler := handler.NewItemHandler(db)

	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	mux.HandleFunc("GET /api/items", itemHandler.List)
	mux.HandleFunc("POST /api/items", itemHandler.Create)

	metrics.Init()

	mux.Handle(
		"GET /metrics",
		promhttp.Handler(),
	)

	server := &http.Server{
		Addr:              ":" + port,
		Handler:           metrics.Middleware(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		logger.Info("server starting", "port", port)

		if err := server.ListenAndServe(); err != nil &&
			err != http.ErrServerClosed {
			logger.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)

	signal.Notify(
		stop,
		os.Interrupt,
		syscall.SIGTERM,
	)

	<-stop

	logger.Info("shutting down server")

	shutdownCtx, cancel := context.WithTimeout(
		context.Background(),
		10*time.Second,
	)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("server shutdown failed", "error", err)
	}
}

func getEnv(key, fallback string) string {
	value := os.Getenv(key)

	if value == "" {
		return fallback
	}

	return value
}
