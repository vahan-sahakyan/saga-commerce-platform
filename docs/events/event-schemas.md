# Event Schemas

## Event Structure

All events follow this base structure:

```json
{
  "eventId": "string (UUID)",
  "sagaId": "string (order ID)",
  "eventType": "string",
  "producer": "string (service name)",
  "timestamp": "string (ISO 8601)",
  "payload": {}
}
```

## Event Types

### OrderCreated

**Topic:** `order-events`

**Producer:** order-service

**Payload:**
```json
{
  "orderId": "string",
  "customerId": "string",
  "items": [
    {
      "productId": "string",
      "quantity": number,
      "price": number // set by order-service, not client-supplied
    }
  ],
  "totalAmount": number
}
```
*Note: The price is determined by the order-service at order creation time, not accepted from the client request.*

### InventoryReserved

**Topic:** `inventory-events`

**Producer:** inventory-service

**Payload:**
```json
{
  "orderId": "string",
  "reservationId": "string",
  "items": [
    {
      "productId": "string",
      "quantity": number,
      "price": number // set by inventory-service, from inventory DB
    }
  ]
}
```

### InventoryFailed

**Topic:** `inventory-events`

**Producer:** inventory-service

**Payload:**
```json
{
  "orderId": "string",
  "reason": "string",
  "failedItems": [
    {
      "productId": "string",
      "requestedQuantity": number,
      "availableQuantity": number
    }
  ]
}
```

### PaymentSucceeded

**Topic:** `payment-events`

**Producer:** payment-service

**Payload:**
```json
{
  "orderId": "string",
  "paymentId": "string",
  "amount": number,
  "currency": "string"
}
```

### PaymentFailed

**Topic:** `payment-events`

**Producer:** payment-service

**Payload:**
```json
{
  "orderId": "string",
  "reason": "string",
  "amount": number
}
```

### ShippingInitiated

**Topic:** `shipping-events`

**Producer:** shipping-service

**Payload:**
```json
{
  "orderId": "string",
  "shippingId": "string",
  "trackingNumber": "string",
  "estimatedDelivery": "string (ISO 8601)"
}
```

### OrderCompleted

**Topic:** `order-events`

**Producer:** order-service

**Payload:**
```json
{
  "orderId": "string",
  "completedAt": "string (ISO 8601)"
}
```

### OrderFailed

**Topic:** `order-events`

**Producer:** order-service

**Payload:**
```json
{
  "orderId": "string",
  "reason": "string",
  "failedAt": "string (ISO 8601)"
}
```

### InventoryReleased

**Topic:** `inventory-events`

**Producer:** inventory-service

**Compensation event**

**Payload:**
```json
{
  "orderId": "string",
  "reservationId": "string",
  "releasedItems": [
    {
      "productId": "string",
      "quantity": number
    }
  ]
}
```
