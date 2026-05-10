# Saga Commerce Platform

A fully local, production-style, polyglot microservice platform implementing Saga Choreography architecture.

## Architecture

This platform demonstrates:
- **Event-driven architecture** using Redpanda (Kafka-compatible)
- **Saga choreography** pattern (no central orchestrator)
- **Polyglot microservices** (Java, Go, Python, TypeScript)
- **GitOps** with ArgoCD
- **Infrastructure as Code** with Terraform
- **Full observability** (Prometheus, Grafana, Jaeger, OpenTelemetry)

## Services

- **order-service** (Java/Spring Boot) - Order creation and saga orchestration
  - REST API for order management
  - Transactional outbox pattern
  - Event publisher and consumer
  - PostgreSQL persistence
  
- **inventory-service** (Go) - Inventory reservation and management
  - Event-driven stock reservation
  - Redis-backed caching
  - Compensation logic (releases on payment failure)
  - PostgreSQL + Redis
  
- **payment-service** (Python/FastAPI) - Payment processing simulation
  - 80% success rate for testing
  - Transactional outbox pattern
  - Redis-based idempotency
  - PostgreSQL persistence
  
- **notification-service** (TypeScript/Fastify) - Customer notifications
  - Terminal service in saga flow
  - Consumes completion/failure events
  - Simulated notifications (console logging)

## Infrastructure

- **Kubernetes**: k3d cluster
- **Message Broker**: Redpanda
- **Databases**: PostgreSQL (per service)
- **Cache**: Redis
- **GitOps**: ArgoCD
- **IaC**: Terraform
- **Observability**: Prometheus, Grafana, Jaeger

## 🚀 Quick Start

### Automated Setup (Recommended)

```bash
./scripts/run-platform.sh
```

This interactive script will guide you through the complete setup process.

### Manual Setup

See [QUICKSTART.md](QUICKSTART.md) for detailed commands.


**Prerequisites:**
- Docker Desktop (running)
- k3d, kubectl, helm, terraform, jq
- Build tools: Java 17, Go 1.21, Python 3.11, Node.js
- **ArgoCD CLI** (for managing GitOps):
  ```bash
  brew install argocd
  ```

**Quick install (macOS):**
```bash
./scripts/install-deps.sh
```

**Setup steps:**
```bash
# 1. Check dependencies
./scripts/preflight-check.sh

# 2. Bootstrap infrastructure (5-10 min)
make bootstrap

# 3. Build services (5-10 min first time)
./scripts/build-all.sh

# 4. Deploy services
make deploy

# 5. Seed test data
make seed

# 6. Start port-forwards (observability + order API)
make pf-all
```

## 🎬 Demo

The demo script runs three isolated scenarios — each creates a fresh order with a unique customer ID so reruns are always consistent regardless of prior data.

**Prerequisites:** `make pf-order` (or `make pf-all`) must be running so the order API is reachable on `localhost:8081`.

### Run all scenarios at once
```bash
make demo
```

### Run individual scenarios
```bash
make demo-happy     # Happy path: inventory reserved + payment succeeds → PAYMENT_COMPLETED
make demo-inv-fail  # Inventory failure: unknown product → saga compensates → FAILED
make demo-pay-fail  # Payment declined: reserved stock released → saga compensates → FAILED
```

Or call the script directly:
```bash
./scripts/demo.sh [happy|inv-fail|pay-fail|all]
```

### How payment failure is simulated
`PAYMENT_SUCCESS_RATE` is an env var on the payment-service pod (default `0.8` — set in [`infra/helm/payment-service/values.yaml`](infra/helm/payment-service/values.yaml)). The demo script temporarily overrides it to `1.0` (happy path) or `0.0` (always fail) via `kubectl set env`, then restores the default when done. You can also set it manually:

```bash
# Force all payments to fail
kubectl set env deployment/payment-service -n services PAYMENT_SUCCESS_RATE=0.0

# Restore default
kubectl set env deployment/payment-service -n services PAYMENT_SUCCESS_RATE=0.8
```

## 📊 Access the Platform

```bash
make pf-all        # start all port-forwards in background (observability + order API)
make pf-obs        # observability only (Grafana, Prometheus, Jaeger, Redpanda Console)
make pf-order      # order-service API only → localhost:8081
```

| Tool | URL | Individual command |
|---|---|---|
| Order API | http://localhost:8081 | `make pf-order` |
| Grafana | http://localhost:3000 | `make pf-grafana` |
| Prometheus | http://localhost:9090 | `make pf-prometheus` |
| Jaeger | http://localhost:16686 | `make pf-jaeger` |
| Redpanda Console | http://localhost:8083 | `make pf-redpanda` |

## 🔄 Event Flow

```
Order Created → Inventory Reserved → Payment Succeeded → Order Completed → Notification Sent
       ↓              ↓                    ↓
    (failure)    (compensation)      (compensation)
```

**Compensation flow:** Payment failure triggers inventory release and order cancellation.

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | Quick reference and common commands |
| [GETTING_STARTED.md](GETTING_STARTED.md) | Comprehensive 5000+ word setup guide |
| [STATUS.md](STATUS.md) | Implementation status (85 files, ~8000 LOC) |
| [IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md) | Achievement summary |
| [docs/architecture/](docs/architecture/) | Saga choreography patterns |
| [docs/events/](docs/events/) | Event schemas and definitions |
| [docs/runbooks/](docs/runbooks/) | Operational procedures |

## ✅ Project Status

- ✅ Phase 1: Local Platform Infrastructure
- ✅ Phase 2: Order Service (Java/Spring Boot)
- ✅ Phase 3: Inventory Service (Go)
- ✅ Phase 4: Payment Service (Python/FastAPI)
- ✅ Phase 5: Notification Service (TypeScript/Fastify)
- ✅ Phase 6: Compensation Logic
- ✅ Phase 7: Observability (Prometheus, Grafana, Jaeger)
- ✅ Complete documentation and helper scripts

**All 85 files complete** - Ready for deployment! 🚀
