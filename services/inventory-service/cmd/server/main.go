package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/saga/inventory-service/internal/config"
	"github.com/saga/inventory-service/internal/database"
	"github.com/saga/inventory-service/internal/events"
	"github.com/saga/inventory-service/internal/handlers"
	"github.com/saga/inventory-service/internal/repository"
	"github.com/saga/inventory-service/internal/service"

	"github.com/gin-gonic/gin"
)

func main() {
	// load config
	cfg := config.Load()

	// init database
	db := database.InitDB(cfg)

	// init redis
	redisClient := database.InitRedis(cfg)

	// init repositories
	inventoryRepo := repository.NewInventoryRepository(db)
	outboxRepo := repository.NewOutboxRepository(db)
	processedEventRepo := repository.NewProcessedEventRepository(db)

	// init services
	inventorySvc := service.NewInventoryService(inventoryRepo, outboxRepo, redisClient)

	// init event consumer
	consumer := events.NewConsumer(cfg, inventorySvc, processedEventRepo)
	go consumer.Start()

	// init event publisher
	publisher := events.NewPublisher(cfg, outboxRepo)
	go publisher.Start()

	// init HTTP server
	router := gin.Default()

	// health endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy"})
	})

	// handlers
	h := handlers.NewInventoryHandler(inventorySvc)
	router.POST("/api/inventory/reserve", h.ReserveInventory)
	router.POST("/api/inventory/release", h.ReleaseInventory)
	router.GET("/api/inventory/:productId", h.GetInventory)

	// start server
	srv := &http.Server{
		Addr:    ":" + cfg.Port,
		Handler: router,
	}

	go func() {
		log.Println("starting inventory service on :" + cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("failed to start server: %v", err)
		}
	}()

	// graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("server forced to shutdown:", err)
	}

	log.Println("server exited")
}
