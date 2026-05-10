package repository

import (
	"github.com/saga/inventory-service/internal/models"
	"gorm.io/gorm"
)

type OutboxRepository struct {
	db *gorm.DB
}

func NewOutboxRepository(db *gorm.DB) *OutboxRepository {
	return &OutboxRepository{db: db}
}

func (r *OutboxRepository) Save(event *models.OutboxEvent) error {
	return r.db.Create(event).Error
}

func (r *OutboxRepository) FindUnpublished(limit int) ([]models.OutboxEvent, error) {
	var events []models.OutboxEvent
	err := r.db.Where("published = ?", false).Order("timestamp ASC").Limit(limit).Find(&events).Error
	return events, err
}

func (r *OutboxRepository) MarkAsPublished(event *models.OutboxEvent) error {
	return r.db.Save(event).Error
}
