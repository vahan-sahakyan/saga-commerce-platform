package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Inventory struct {
	ID        string    `gorm:"primaryKey;type:uuid" json:"id"`
	ProductID string    `gorm:"not null;uniqueIndex" json:"productId"`
	Quantity  int       `gorm:"not null" json:"quantity"`
	Reserved  int       `gorm:"not null;default:0" json:"reserved"`
	Price     float64   `gorm:"not null" json:"price"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

func (i *Inventory) BeforeCreate(tx *gorm.DB) error {
	if i.ID == "" {
		i.ID = uuid.New().String()
	}
	return nil
}

type Reservation struct {
	ID        string    `gorm:"primaryKey;type:uuid" json:"id"`
	OrderID   string    `gorm:"not null;index" json:"orderId"`
	ProductID string    `gorm:"not null" json:"productId"`
	Quantity  int       `gorm:"not null" json:"quantity"`
	Status    string    `gorm:"not null" json:"status"` // ACTIVE, RELEASED
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

func (r *Reservation) BeforeCreate(tx *gorm.DB) error {
	if r.ID == "" {
		r.ID = uuid.New().String()
	}
	return nil
}

type OutboxEvent struct {
	ID          string     `gorm:"primaryKey;type:uuid" json:"id"`
	EventID     string     `gorm:"not null" json:"eventId"`
	SagaID      string     `gorm:"not null" json:"sagaId"`
	EventType   string     `gorm:"not null" json:"eventType"`
	Producer    string     `gorm:"not null" json:"producer"`
	Payload     string     `gorm:"type:text;not null" json:"payload"`
	Timestamp   time.Time  `gorm:"not null" json:"timestamp"`
	Published   bool       `gorm:"not null;default:false" json:"published"`
	PublishedAt *time.Time `json:"publishedAt,omitempty"`
}

func (o *OutboxEvent) BeforeCreate(tx *gorm.DB) error {
	if o.ID == "" {
		o.ID = uuid.New().String()
	}
	if o.Timestamp.IsZero() {
		o.Timestamp = time.Now()
	}
	return nil
}

type ProcessedEvent struct {
	EventID     string    `gorm:"primaryKey" json:"eventId"`
	EventType   string    `gorm:"not null" json:"eventType"`
	ProcessedAt time.Time `gorm:"not null" json:"processedAt"`
}

func (p *ProcessedEvent) BeforeCreate(tx *gorm.DB) error {
	if p.ProcessedAt.IsZero() {
		p.ProcessedAt = time.Now()
	}
	return nil
}
