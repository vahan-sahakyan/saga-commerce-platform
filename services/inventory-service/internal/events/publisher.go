package events

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/saga/inventory-service/internal/config"
	"github.com/saga/inventory-service/internal/repository"
	"github.com/segmentio/kafka-go"
)

type Publisher struct {
	writer     *kafka.Writer
	outboxRepo *repository.OutboxRepository
}

func NewPublisher(cfg *config.Config, outboxRepo *repository.OutboxRepository) *Publisher {
	writer := &kafka.Writer{
		Addr:     kafka.TCP(cfg.KafkaBootstrap),
		Topic:    "inventory-events",
		Balancer: &kafka.LeastBytes{},
	}

	return &Publisher{
		writer:     writer,
		outboxRepo: outboxRepo,
	}
}

func (p *Publisher) Start() {
	log.Println("starting event publisher...")

	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		p.publishEvents()
	}
}

func (p *Publisher) publishEvents() {
	events, err := p.outboxRepo.FindUnpublished(10)
	if err != nil {
		log.Printf("error finding unpublished events: %v", err)
		return
	}

	if len(events) == 0 {
		return
	}

	log.Printf("publishing %d events from outbox", len(events))

	for _, event := range events {
		// reconstruct payload
		var payloadMap map[string]interface{}
		if err := json.Unmarshal([]byte(event.Payload), &payloadMap); err != nil {
			log.Printf("error unmarshaling payload: %v", err)
			continue
		}

		tsBytes, _ := json.Marshal(event.Timestamp)
		baseEvent := BaseEvent{
			EventID:   event.EventID,
			SagaID:    event.SagaID,
			EventType: event.EventType,
			Producer:  event.Producer,
			Timestamp: json.RawMessage(tsBytes),
			Payload:   payloadMap,
		}

		msgBytes, err := json.Marshal(baseEvent)
		if err != nil {
			log.Printf("error marshaling event: %v", err)
			continue
		}

		msg := kafka.Message{
			Key:   []byte(event.SagaID),
			Value: msgBytes,
		}

		if err := p.writer.WriteMessages(context.Background(), msg); err != nil {
			log.Printf("error publishing event: %v", err)
			continue
		}

		// mark as published
		now := time.Now()
		event.Published = true
		event.PublishedAt = &now

		if err := p.outboxRepo.MarkAsPublished(&event); err != nil {
			log.Printf("error marking event as published: %v", err)
		}

		log.Printf("published event: %s for saga: %s", event.EventID, event.SagaID)
	}
}
