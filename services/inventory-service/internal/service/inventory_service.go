package service

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/saga/inventory-service/internal/models"
	"github.com/saga/inventory-service/internal/repository"
)

type InventoryService struct {
	inventoryRepo *repository.InventoryRepository
	outboxRepo    *repository.OutboxRepository
	redisClient   *redis.Client
}

func NewInventoryService(
	inventoryRepo *repository.InventoryRepository,
	outboxRepo *repository.OutboxRepository,
	redisClient *redis.Client,
) *InventoryService {
	return &InventoryService{
		inventoryRepo: inventoryRepo,
		outboxRepo:    outboxRepo,
		redisClient:   redisClient,
	}
}

func (s *InventoryService) HandleOrderCreated(orderID string, items []OrderItem) error {
	log.Printf("handling order created: %s", orderID)

	// check inventory availability
	for _, item := range items {
		inventory, err := s.inventoryRepo.FindByProductID(item.ProductID)
		if err != nil {
			log.Printf("product not found: %s", item.ProductID)
			return s.publishInventoryFailed(orderID, fmt.Sprintf("product not found: %s", item.ProductID))
		}

		available := inventory.Quantity - inventory.Reserved
		if available < item.Quantity {
			log.Printf("insufficient stock for product %s: available=%d, requested=%d",
				item.ProductID, available, item.Quantity)
			return s.publishInventoryFailed(orderID, fmt.Sprintf("insufficient stock for product: %s", item.ProductID))
		}
	}

	// reserve inventory and collect reserved items with price
	reservationID := uuid.New().String()
	reservedItems := make([]map[string]any, 0, len(items))
	for _, item := range items {
		inventory, _ := s.inventoryRepo.FindByProductID(item.ProductID)
		inventory.Reserved += item.Quantity
		if err := s.inventoryRepo.Save(inventory); err != nil {
			return err
		}

		// create reservation record
		reservation := &models.Reservation{
			OrderID:   orderID,
			ProductID: item.ProductID,
			Quantity:  item.Quantity,
			Status:    "ACTIVE",
		}
		if err := s.inventoryRepo.CreateReservation(reservation); err != nil {
			return err
		}

		reservedItems = append(reservedItems, map[string]any{
			"productId": item.ProductID,
			"quantity":  item.Quantity,
			"price":     inventory.Price,
		})
	}

	log.Printf("inventory reserved for order: %s", orderID)
	return s.publishInventoryReservedWithItems(orderID, reservationID, reservedItems)
}

func (s *InventoryService) HandlePaymentFailed(orderID string) error {
	log.Printf("handling payment failed for order: %s", orderID)

	// find reservations
	reservations, err := s.inventoryRepo.FindReservationsByOrderID(orderID)
	if err != nil {
		return err
	}

	// release inventory
	for _, reservation := range reservations {
		inventory, err := s.inventoryRepo.FindByProductID(reservation.ProductID)
		if err != nil {
			continue
		}

		inventory.Reserved -= reservation.Quantity
		if err := s.inventoryRepo.Save(inventory); err != nil {
			log.Printf("failed to release inventory: %v", err)
			continue
		}

		reservation.Status = "RELEASED"
		if err := s.inventoryRepo.UpdateReservation(&reservation); err != nil {
			log.Printf("failed to update reservation: %v", err)
		}
	}

	log.Printf("inventory released for order: %s", orderID)
	return s.publishInventoryReleased(orderID)
}

// publishInventoryReservedWithItems emits InventoryReserved event with items including price
func (s *InventoryService) publishInventoryReservedWithItems(orderID, reservationID string, items []map[string]any) error {
	payload := map[string]any{
		"orderId":       orderID,
		"reservationId": reservationID,
		"items":         items,
	}
	return s.publishEvent(orderID, "InventoryReserved", payload)
}

func (s *InventoryService) publishInventoryFailed(orderID, reason string) error {
	payload := map[string]any{
		"orderId": orderID,
		"reason":  reason,
	}

	return s.publishEvent(orderID, "InventoryFailed", payload)
}

func (s *InventoryService) publishInventoryReleased(orderID string) error {
	payload := map[string]any{
		"orderId": orderID,
	}

	return s.publishEvent(orderID, "InventoryReleased", payload)
}

func (s *InventoryService) publishEvent(sagaID, eventType string, payload any) error {
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	event := &models.OutboxEvent{
		EventID:   uuid.New().String(),
		SagaID:    sagaID,
		EventType: eventType,
		Producer:  "inventory-service",
		Payload:   string(payloadJSON),
		Timestamp: time.Now(),
		Published: false,
	}

	return s.outboxRepo.Save(event)
}

type OrderItem struct {
	ProductID string  `json:"productId"`
	Quantity  int     `json:"quantity"`
	Price     float64 `json:"price"`
}
