# 🚀 Quick Start - Saga Commerce Platform

## Option 1: Automated Setup (Recommended)

Run the interactive setup script:

```bash
./scripts/run-platform.sh
```

This will guide you through:

1. ✅ Checking dependencies
2. ✅ Bootstrapping infrastructure
3. ✅ Building services
4. ✅ Deploying to Kubernetes
5. ✅ Seeding test data
6. ✅ Testing the saga flow

---

## Option 2: Manual Setup

### 1. Install Dependencies (macOS)

**Quick install:**

```bash
./scripts/install-deps.sh
```

**Or manually:**

```bash
brew install k3d kubectl helm terraform jq
brew install openjdk@17 go python@3.11 node maven
```

**Verify installation:**

```bash
./scripts/preflight-check.sh
```

### 2. Bootstrap Infrastructure (5-10 min)

```bash
make bootstrap
```

This creates the k3d cluster and deploys all infrastructure.

**Check status:**

```bash
make status
# OR
kubectl get pods -A
```

### 3. Build Services (5-10 min first time)

```bash
./scripts/build-all.sh
```

**Or build individually:**

```bash
# Order Service (Java)
cd services/order-service
./mvnw clean package
docker build -t localhost:5000/order-service:latest .
docker push localhost:5000/order-service:latest

# Inventory Service (Go)
cd services/inventory-service
docker build -t localhost:5000/inventory-service:latest .
docker push localhost:5000/inventory-service:latest

# Payment Service (Python)
cd services/payment-service
docker build -t localhost:5000/payment-service:latest .
docker push localhost:5000/payment-service:latest

# Notification Service (TypeScript)
cd services/notification-service
docker build -t localhost:5000/notification-service:latest .
docker push localhost:5000/notification-service:latest
```

### 4. Deploy Services

```bash
make deploy
```

Wait for services to be ready:

```bash
kubectl wait --for=condition=Ready pods -n services --all --timeout=300s
```

### 5. Seed Test Data

```bash
./scripts/seed-data.sh
```

### 6. Test the Platform

**Port forward the order service:**

```bash
kubectl port-forward svc/order-service -n services 8080:8080
```

**In another terminal, create a test order:**

```bash
./scripts/test-saga.sh
```

---

## Access the Platform

### Services

**Order Service API:**

```bash
kubectl port-forward svc/order-service -n services 8080:8080
curl http://localhost:8080/api/orders
```

### Observability

**ArgoCD:**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Get password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
# Access: https://localhost:8080 (admin / <password>)
```

**Grafana:**

```bash
kubectl port-forward svc/prometheus-grafana -n observability 3000:80
# Access: http://localhost:3000 (admin / admin)
```

**Jaeger:**

```bash
kubectl port-forward svc/jaeger-query -n observability 16686:16686
# Access: http://localhost:16686
```

**Prometheus:**

```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090
# Access: http://localhost:9090
```

### View Logs

```bash
# All services
kubectl logs -l app.kubernetes.io/part-of=saga-platform -n services --tail=50

# Specific service
kubectl logs -l app=order-service -n services -f
kubectl logs -l app=inventory-service -n services -f
kubectl logs -l app=payment-service -n services -f
kubectl logs -l app=notification-service -n services -f
```

---

## Common Operations

### Create an Order

```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-123",
    "items": [
      {
        "productId": "product-1",
        "quantity": 2,
        "price": 29.99
      }
    ]
  }'
```

### Check Order Status

```bash
curl http://localhost:8080/api/orders/{orderId} | jq '.'
```

### View Kafka Events

```bash
# Order events
kubectl exec -it redpanda-0 -n infra -- rpk topic consume order-events --num 10

# Inventory events
kubectl exec -it redpanda-0 -n infra -- rpk topic consume inventory-events --num 10

# Payment events
kubectl exec -it redpanda-0 -n infra -- rpk topic consume payment-events --num 10
```

### Check Database

```bash
# Port forward PostgreSQL
kubectl port-forward svc/postgresql -n infra 5432:5432

# Connect with psql
psql -h localhost -U saga -d order_db
# Password: saga-password

# View orders
SELECT id, customer_id, status, total_amount FROM orders ORDER BY created_at DESC LIMIT 10;
```

---

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -A
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Restart Services

```bash
kubectl rollout restart deployment -n services
```

### Clear Test Data

```bash
# Clear orders
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d order_db -c "TRUNCATE TABLE orders CASCADE;"
```

### Destroy Everything

```bash
make destroy
```

---

## Next Steps

📖 **Read the full guides:**

- [GETTING_STARTED.md](GETTING_STARTED.md) - Comprehensive setup guide
- [STATUS.md](STATUS.md) - Implementation details
- [docs/architecture/saga-choreography.md](docs/architecture/saga-choreography.md) - Architecture patterns
- [docs/runbooks/operational-runbook.md](docs/runbooks/operational-runbook.md) - Operations guide

---

## Quick Reference

| Command                         | Description                             |
| ------------------------------- | --------------------------------------- |
| `make bootstrap`                | Create cluster + install infrastructure |
| `make deploy`                   | Deploy all services                     |
| `make status`                   | Check system status                     |
| `make destroy`                  | Tear down everything                    |
| `./scripts/build-all.sh`        | Build all service images                |
| `./scripts/seed-data.sh`        | Add test data                           |
| `./scripts/test-saga.sh`        | Run end-to-end test                     |
| `./scripts/access-endpoints.sh` | Show all access commands                |

---

**Need help?** Check [GETTING_STARTED.md](GETTING_STARTED.md) for detailed instructions!
