# Saga Choreography Architecture

## Overview

This platform implements the Saga Choreography pattern for distributed transactions across microservices.

## Key Principles

### 1. No Central Orchestrator
- Each service is autonomous
- Services communicate only through events
- No single point of failure

### 2. Event-Driven Communication
- All inter-service communication via Redpanda/Kafka
- Services react to events and emit new events
- Asynchronous by design

### 3. Compensation Logic
- Each service implements compensation for failure scenarios
- Rollback through compensating events
- Eventual consistency

## Happy Path Flow

```
User → POST /orders
    ↓
Order Service
    ├─ Persist order (status: PENDING)
    ├─ Store event in outbox
    └─ Publish: OrderCreated
         ↓
Inventory Service
    ├─ Consume: OrderCreated
    ├─ Check stock availability
    ├─ Reserve inventory
    ├─ Store event in outbox
    └─ Publish: InventoryReserved
         ↓
Payment Service
    ├─ Consume: InventoryReserved
    ├─ Process payment
    ├─ Store event in outbox
    └─ Publish: PaymentSucceeded
         ↓
Shipping Service
    ├─ Consume: PaymentSucceeded
    ├─ Create shipping order
    ├─ Store event in outbox
    └─ Publish: ShippingInitiated
         ↓
Order Service
    ├─ Consume: ShippingInitiated
    └─ Update order status: COMPLETED
         ↓
Notification Service
    ├─ Consume: OrderCompleted
    └─ Send notification
```

## Compensation Flow

```
Inventory Service
    ├─ Consume: OrderCreated
    ├─ Check stock
    └─ Insufficient stock
         ↓
    Publish: InventoryFailed
         ↓
Order Service
    ├─ Consume: InventoryFailed
    └─ Update order status: FAILED

OR

Payment Service
    ├─ Consume: InventoryReserved
    ├─ Process payment
    └─ Payment declined
         ↓
    Publish: PaymentFailed
         ↓
Inventory Service
    ├─ Consume: PaymentFailed
    ├─ Find reservation by orderId
    ├─ Release reserved inventory
    └─ Publish: InventoryReleased
         ↓
Order Service
    ├─ Consume: PaymentFailed
    └─ Update order status: FAILED
```

## Database per Service

Each service owns its database/schema:

- **order-service**: `order_db`
  - `orders` table
  - `outbox_events` table
  - `processed_events` table

- **inventory-service**: `inventory_db`
  - `products` table
  - `inventory` table
  - `reservations` table
  - `outbox_events` table
  - `processed_events` table

- **payment-service**: `payment_db`
  - `payments` table
  - `outbox_events` table
  - `processed_events` table

- **shipping-service**: `shipping_db`
  - `shipments` table
  - `outbox_events` table
  - `processed_events` table

## Outbox Pattern

Every service implements transactional outbox:

1. Business transaction + outbox insert (single DB transaction)
2. Background publisher polls outbox
3. Publish event to Kafka
4. Mark as published

This ensures:
- At-least-once delivery
- No event loss on failure
- Transaction integrity

## Idempotency

All event consumers are idempotent:

1. Check `processed_events` table
2. If eventId exists, skip processing
3. Process event + insert eventId (single transaction)

This ensures:
- Duplicate events are ignored
- Exactly-once processing semantics
- Safe retry logic

## Observability

### Tracing
- OpenTelemetry instrumentation
- Trace ID propagated through events
- Complete saga lifecycle visible in Jaeger

### Metrics
- Event consumption count
- Event publish count
- Processing duration
- Error rates

### Logging
- Structured JSON logs
- Include: traceId, sagaId, eventId, service
- Correlation across services
