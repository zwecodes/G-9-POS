package main

import (
	"log/slog"
	"os"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/internal/server"
	"github.com/zwecodes/g9pos/backend/pkg/db"
)

func main() {
	if os.Getenv("APP_ENV") == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		slog.Error("DATABASE_URL is required")
		os.Exit(1)
	}
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		slog.Error("JWT_SECRET is required")
		os.Exit(1)
	}

	database, err := db.Connect(databaseURL)
	if err != nil {
		slog.Error("database connect failed", "error", err)
		os.Exit(1)
	}
	defer database.Close()

	if err := db.Migrate(databaseURL); err != nil {
		slog.Error("database migrate failed", "error", err)
		os.Exit(1)
	}

	r := server.New(database, jwtSecret, server.Options{})
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	slog.Info("g9pos api listening", "port", port)
	if err := r.Run(":" + port); err != nil {
		slog.Error("server stopped", "error", err)
		os.Exit(1)
	}
}
