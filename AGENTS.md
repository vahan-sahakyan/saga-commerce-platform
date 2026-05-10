# AGENTS.md — AI Coding Agent Instructions

This file provides essential guidance for AI coding agents working in the saga-commerce-platform repository. It summarizes key conventions, architecture, and links to detailed documentation. Follow these instructions to be immediately productive and avoid common pitfalls.

---

## Project Overview

- **Polyglot microservice platform** implementing Saga Choreography
- Runs fully locally (no cloud dependencies)
- Uses Kubernetes (k3d), ArgoCD (GitOps), Terraform, Helm
- Event-driven communication via Redpanda (Kafka-compatible)
- Full observability: Prometheus, Grafana, Jaeger, OpenTelemetry
- Each service owns its own DB/schema (PostgreSQL/Redis)

---

## Key Conventions & Rules

- **Choreography only:** No central orchestrator. All business logic flows via events.
- **Event-driven:** All inter-service communication is asynchronous via Kafka topics. No direct service-to-service calls for business logic.
- **Idempotency:** Consumers must track processed events and ignore duplicates (see `processed_events` table in each service).
- **Transactional Outbox:** All event publishing uses the outbox pattern (see `outbox` table and publisher logic in each service).
- **Event Schema:** All events must include `eventId`, `sagaId`, `eventType`, `producer`, `timestamp`, and `payload`. See [docs/events/event-schemas.md](docs/events/event-schemas.md).
- **Observability:** All services must expose metrics and traces. See [docs/runbooks/operational-runbook.md](docs/runbooks/operational-runbook.md).
- **Structured Logging:** Logs must include `traceId`, `sagaId`, `eventId`, and service name.

---

## Services

| Service               | Language      | Responsibilities                                   |
|-----------------------|--------------|----------------------------------------------------|
| order-service         | Java         | Order creation, saga flow, emits OrderCreated       |
| inventory-service     | Go           | Inventory reservation, emits InventoryReserved      |
| payment-service       | Python       | Payment simulation, emits PaymentSucceeded/Failed   |
| notification-service  | TypeScript   | Notification/logging, consumes saga completion      |

See [docs/architecture/saga-choreography.md](docs/architecture/saga-choreography.md) for full flow and compensation logic.

---

## Build, Deploy, Operate

- **Bootstrap everything:** `make bootstrap`
- **Deploy all services:** `make deploy`
- **Destroy everything:** `make destroy`
- **Check status:** `make status`
- **Run tests:** See [scripts/test-saga.sh](scripts/test-saga.sh)
- **Access endpoints:** See [scripts/access-endpoints.sh](scripts/access-endpoints.sh)

---

## Documentation Links

- [README.md](README.md) — Project summary
- [CLAUDE.md](CLAUDE.md) — Full architecture, rules, and standards
- [docs/architecture/saga-choreography.md](docs/architecture/saga-choreography.md) — Saga choreography details
- [docs/events/event-schemas.md](docs/events/event-schemas.md) — Event schemas and payloads
- [docs/runbooks/operational-runbook.md](docs/runbooks/operational-runbook.md) — Operations, monitoring, troubleshooting

---

## Agent Guidance

- **Link, don’t duplicate:** Reference the above docs for details.
- **Minimal by default:** Only add instructions that are not easily discoverable.
- **Update this file** if new conventions or patterns are introduced.

---

For further customization, see [CLAUDE.md](CLAUDE.md) and the `infra/` and `services/` directories for implementation details.
