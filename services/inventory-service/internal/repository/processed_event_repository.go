package repository

import (
	"github.com/saga/inventory-service/internal/models"
	"gorm.io/gorm"
)

type ProcessedEventRepository struct {
	db *gorm.DB
}

func NewProcessedEventRepository(db *gorm.DB) *ProcessedEventRepository {
	return &ProcessedEventRepository{db: db}
}

func (r *ProcessedEventRepository) Exists(eventID string) bool {
	var count int64
	r.db.Model(&models.ProcessedEvent{}).Where("event_id = ?", eventID).Count(&count)
	return count > 0
}

func (r *ProcessedEventRepository) Save(event *models.ProcessedEvent) error {
	return r.db.Create(event).Error
}
