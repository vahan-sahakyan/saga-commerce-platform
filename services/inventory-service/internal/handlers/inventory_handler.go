package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/saga/inventory-service/internal/service"
)

type InventoryHandler struct {
	inventoryService *service.InventoryService
}

func NewInventoryHandler(inventoryService *service.InventoryService) *InventoryHandler {
	return &InventoryHandler{inventoryService: inventoryService}
}

type ReserveRequest struct {
	OrderID string              `json:"orderId"`
	Items   []service.OrderItem `json:"items"`
}

func (h *InventoryHandler) ReserveInventory(c *gin.Context) {
	var req ReserveRequest
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.inventoryService.HandleOrderCreated(req.OrderID, req.Items); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "inventory reserved"})
}

func (h *InventoryHandler) ReleaseInventory(c *gin.Context) {
	orderID := c.Query("orderId")
	if orderID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "orderId required"})
		return
	}

	if err := h.inventoryService.HandlePaymentFailed(orderID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "inventory released"})
}

func (h *InventoryHandler) GetInventory(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "not implemented"})
}
