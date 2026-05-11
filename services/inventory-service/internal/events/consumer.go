package events

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/saga/inventory-service/internal/config"
	"github.com/saga/inventory-service/internal/models"
	"github.com/saga/inventory-service/internal/repository"
	"github.com/saga/inventory-service/internal/service"
	"github.com/segmentio/kafka-go"
)

type BaseEvent struct {
	EventID   string          `json:"eventId"`
	SagaID    string          `json:"sagaId"`
	EventType string          `json:"eventType"`
	Producer  string          `json:"producer"`
	Timestamp json.RawMessage `json:"timestamp"`
	Payload   map[string]any  `json:"payload"`
}

type Consumer struct {
	reader             *kafka.Reader
	inventoryService   *service.InventoryService
	processedEventRepo *repository.ProcessedEventRepository
}

func NewConsumer(
	cfg *config.Config,
	inventoryService *service.InventoryService,
	processedEventRepo *repository.ProcessedEventRepository,
) *Consumer {
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:  []string{cfg.KafkaBootstrap},
		Topic:    "order-events",
		GroupID:  "inventory-service-group",
		MinBytes: 10e3, // 10KB
		MaxBytes: 10e6, // 10MB
	})

	return &Consumer{
		reader:             reader,
		inventoryService:   inventoryService,
		processedEventRepo: processedEventRepo,
	}
}

func (c *Consumer) Start() {
	log.Println("starting event consumer...")
	ctx := context.Background()

	// Proactive: log Kafka connection info
	log.Printf("Kafka consumer connecting to brokers: %v, topic: %s, group: %s", c.reader.Config().Brokers, c.reader.Config().Topic, c.reader.Config().GroupID)

	for {
		msg, err := c.reader.ReadMessage(ctx)
		if err != nil {
			log.Printf("[KAFKA ERROR] error reading message: %v", err)
			time.Sleep(2 * time.Second)
			continue
		}

		log.Printf("[KAFKA] received raw message: %s", string(msg.Value))

		var event BaseEvent
		if err := json.Unmarshal(msg.Value, &event); err != nil {
			log.Printf("[KAFKA ERROR] error unmarshaling event: %v", err)
			continue
		}

		log.Printf("[KAFKA] received event: %s type: %s", event.EventID, event.EventType)

		// check idempotency
		if c.processedEventRepo.Exists(event.EventID) {
			log.Printf("[KAFKA] event already processed: %s", event.EventID)
			continue
		}

		// handle event
		if err := c.handleEvent(&event); err != nil {
			log.Printf("[KAFKA ERROR] error handling event: %v", err)
			continue
		}

		// mark as processed
		processedEvent := &models.ProcessedEvent{
			EventID:   event.EventID,
			EventType: event.EventType,
		}
		if err := c.processedEventRepo.Save(processedEvent); err != nil {
			log.Printf("[KAFKA ERROR] error saving processed event: %v", err)
		}

		log.Printf("[KAFKA] processed event: %s", event.EventID)
	}
}

func (c *Consumer) handleEvent(event *BaseEvent) error {
	switch event.EventType {
	case "OrderCreated":
		return c.handleOrderCreated(event)
	default:
		log.Printf("unknown event type: %s", event.EventType)
	}
	return nil
}

func (c *Consumer) handleOrderCreated(event *BaseEvent) error {
	orderID := event.Payload["orderId"].(string)

	itemsData := event.Payload["items"].([]any)
	items := make([]service.OrderItem, 0)

	for _, itemData := range itemsData {
		itemMap := itemData.(map[string]any)
		items = append(items, service.OrderItem{
			ProductID: itemMap["productId"].(string),
			Quantity:  int(itemMap["quantity"].(float64)),
			Price:     itemMap["price"].(float64),
		})
	}

	return c.inventoryService.HandleOrderCreated(orderID, items)
}

// consume payment events for compensation
func (c *Consumer) StartPaymentConsumer(cfg *config.Config) {
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:  []string{cfg.KafkaBootstrap},
		Topic:    "payment-events",
		GroupID:  "inventory-service-group",
		MinBytes: 10e3,
		MaxBytes: 10e6,
	})
	defer reader.Close()

	log.Println("starting payment event consumer...")
	ctx := context.Background()

	for {
		msg, err := reader.ReadMessage(ctx)
		if err != nil {
			log.Printf("error reading message: %v", err)
			continue
		}

		var event BaseEvent
		if err := json.Unmarshal(msg.Value, &event); err != nil {
			log.Printf("error unmarshaling event: %v", err)
			continue
		}

		if event.EventType == "PaymentFailed" {
			orderID := event.Payload["orderId"].(string)
			if err := c.inventoryService.HandlePaymentFailed(orderID); err != nil {
				log.Printf("error handling payment failed: %v", err)
			}
		}
	}
}
