# `CLAUDE.md` — Local Polyglot Saga Choreography Platform

# Project: saga-commerce-platform

Goal:
Build a fully local, production-style, polyglot microservice platform implementing Saga Choreography architecture.

The system should:
- run completely locally
- be free of paid services
- use Kubernetes + GitOps
- include observability
- use event-driven communication
- support multiple languages
- mimic real production engineering patterns

---

# High-Level Architecture

User/API
    ↓
Order Service (Java)
    ↓ publishes event
Redpanda/Kafka
    ↓
Inventory Service (Go)
    ↓ publishes event
Payment Service (Python)
    ↓ publishes event
Shipping Service (Go or Java)
    ↓ publishes event
Notification Service (TypeScript)

Shared infrastructure:
- Kubernetes (k3d)
- ArgoCD
- Helm
- Terraform
- PostgreSQL
- Redis
- Prometheus
- Grafana
- Jaeger
- OpenTelemetry

---

# Core Architectural Rules

## 1. Choreography only

Do NOT implement a central orchestrator service.

Each service:
- listens to events
- performs business logic
- emits new events

Communication between services MUST happen through events.

No direct synchronous service-to-service calls for business workflow.

---

## 2. Database per service

Every service owns its own database/schema.

Allowed:
- own DB reads/writes
- event communication

Forbidden:
- cross-service DB access

---

## 3. Event-driven architecture

Use:
- Redpanda (Kafka-compatible)

Topics:
- order-events
- inventory-events
- payment-events
- shipping-events
- notification-events

---

## 4. Idempotency required

Consumers must be idempotent.

Requirements:
- processed_events table
- ignore duplicate events
- eventId tracking

---

## 5. Outbox pattern

Every service must implement transactional outbox pattern.

Flow:
1. business transaction commits
2. outbox event stored
3. background publisher publishes event
4. event marked as published

Never publish directly from business logic.

---

## 6. Correlation IDs

Every event must contain:
- eventId
- sagaId
- timestamp
- eventType
- producer
- payload

Example:

```json
{
  "eventId": "uuid",
  "sagaId": "order-123",
  "eventType": "InventoryReserved",
  "producer": "inventory-service",
  "timestamp": "2026-01-01T00:00:00Z",
  "payload": {}
}
```

---

# Languages

## Services

### order-service
Language:
- Java

Framework:
- Spring Boot

Responsibilities:
- create orders
- persist orders
- emit OrderCreated
- react to saga completion/failure

---

### inventory-service
Language:
- Go

Responsibilities:
- reserve inventory
- release inventory on compensation
- emit InventoryReserved
- emit InventoryFailed

Use Redis for:
- stock cache
- reservation locks

---

### payment-service
Language:
- Python

Framework:
- FastAPI

Responsibilities:
- simulate payments
- emit PaymentSucceeded
- emit PaymentFailed

Use Redis for:
- idempotency cache

---

### notification-service
Language:
- TypeScript

Framework:
- Node.js + Fastify

Responsibilities:
- consume saga completion/failure
- simulate emails/logging

---

# Infrastructure

## Kubernetes

Use:
- k3d

Cluster name:
- saga-platform

---

## GitOps

Use:
- ArgoCD

Requirements:
- apps managed through GitOps
- no manual kubectl deployments except bootstrap

---

## Terraform

Terraform responsibilities:
- namespaces
- ArgoCD install
- Helm releases
- infrastructure provisioning

Providers:
- kubernetes
- helm

Do NOT provision cloud resources.

---

## Helm

Every service must have:
- its own Helm chart

Charts should support:
- image
- replicas
- resources
- env vars
- probes

---

# Observability

## Metrics

Use:
- Prometheus

Every service should expose:
- request count
- error count
- event consumption count
- event publish count

---

## Dashboards

Use:
- Grafana

Required dashboards:
- service health
- Kafka metrics
- saga flow metrics

---

## Tracing

Use:
- OpenTelemetry
- Jaeger

Requirements:
- propagate trace IDs through events
- trace complete saga lifecycle

---

# Logging

Requirements:
- structured JSON logs
- include:
  - traceId
  - sagaId
  - eventId
  - service name

---

# Local Development

## Deployment

Everything must run locally through:
- Kubernetes
- Docker

No cloud dependencies allowed.

---

## Bootstrap

Main commands should be:

```bash
make bootstrap
make deploy
make destroy
```

---

# Repository Structure

```text
repo/
├── infra/
│   ├── terraform/
│   ├── argocd/
│   ├── helm/
│   └── bootstrap/
│
├── services/
│   ├── order-service/
│   ├── inventory-service/
│   ├── payment-service/
│   └── notification-service/
│
├── docs/
│   ├── architecture/
│   ├── events/
│   └── runbooks/
│
└── Makefile
```

---

# Initial Development Order

## Phase 1 — Local Platform

Implement:
- k3d cluster
- ingress
- ArgoCD
- Redpanda
- PostgreSQL
- Redis
- Prometheus
- Grafana
- Jaeger

Success criteria:
- all infra healthy in cluster

---

## Phase 2 — Order Service

Implement:
- REST API
- PostgreSQL persistence
- outbox table
- event publisher
- OrderCreated event

Success criteria:
- order creation emits event

---

## Phase 3 — Inventory Service

Implement:
- consume OrderCreated
- reserve stock
- emit InventoryReserved

Success criteria:
- inventory reacts automatically

---

## Phase 4 — Payment Service

Implement:
- consume InventoryReserved
- simulate payment
- emit PaymentSucceeded or PaymentFailed

Success criteria:
- payment flow works

---

## Phase 5 — Compensation

Implement failure handling:
- release inventory
- cancel order

Success criteria:
- saga rollback works

---

## Phase 6 — Observability

Implement:
- traces
- metrics
- dashboards

Success criteria:
- entire saga visible in Jaeger

---

# Engineering Standards

Requirements:
- health endpoints
- readiness/liveness probes
- graceful shutdown
- retries
- dead-letter topics
- resource limits
- structured logs

---

# Important Constraints

Avoid initially:
- service mesh
- Istio
- Vault
- Crossplane
- Kafka operators
- advanced autoscaling

Keep the platform understandable.

---

# Deliverable Goal

The final platform should demonstrate:
- microservices
- event-driven architecture
- saga choreography
- GitOps
- Terraform
- Kubernetes
- observability
- polyglot backend engineering
- production-style patterns

while running entirely locally.
