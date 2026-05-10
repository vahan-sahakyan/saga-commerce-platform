package repository

import (
	"github.com/saga/inventory-service/internal/models"
	"gorm.io/gorm"
)

type InventoryRepository struct {
	db *gorm.DB
}

func NewInventoryRepository(db *gorm.DB) *InventoryRepository {
	return &InventoryRepository{db: db}
}

func (r *InventoryRepository) FindByProductID(productID string) (*models.Inventory, error) {
	var inventory models.Inventory
	err := r.db.Where("product_id = ?", productID).First(&inventory).Error
	if err != nil {
		return nil, err
	}
	return &inventory, nil
}

func (r *InventoryRepository) Save(inventory *models.Inventory) error {
	return r.db.Save(inventory).Error
}

func (r *InventoryRepository) CreateReservation(reservation *models.Reservation) error {
	return r.db.Create(reservation).Error
}

func (r *InventoryRepository) FindReservationsByOrderID(orderID string) ([]models.Reservation, error) {
	var reservations []models.Reservation
	err := r.db.Where("order_id = ? AND status = ?", orderID, "ACTIVE").Find(&reservations).Error
	return reservations, err
}

func (r *InventoryRepository) UpdateReservation(reservation *models.Reservation) error {
	return r.db.Save(reservation).Error
}
