# Getting Started with Saga Commerce Platform

This guide will walk you through setting up and running the complete Saga Commerce Platform locally.

## Prerequisites

### Required Tools

Install the following tools before proceeding:

```bash
# macOS (using Homebrew)
brew install docker
brew install k3d
brew install kubectl
brew install helm
brew install terraform
brew install jq  # for JSON parsing in scripts

# Verify installations
docker --version
k3d --version
kubectl version --client
helm version
terraform version
```

### Development Tools (for building services)

```bash
# Java (for order-service)
brew install openjdk@17

# Go (for inventory-service)
brew install go

# Python (for payment-service)
brew install python@3.11

# Node.js (for notification-service)
brew install node
```

## Step-by-Step Setup

### Step 1: Bootstrap Infrastructure

This will create the k3d cluster and deploy all infrastructure components.

```bash
# From project root
make bootstrap
```

This command:
1. Creates a k3d cluster named `saga-platform`
2. Installs ArgoCD
3. Deploys Redpanda (Kafka)
4. Deploys PostgreSQL
5. Deploys Redis
6. Deploys Prometheus, Grafana, and Jaeger

**Expected time**: 5-10 minutes

Check status:
```bash
make status
```

All pods should be in `Running` or `Completed` state.

### Step 2: Build Services

Build Docker images for all services:

```bash
./scripts/build-all.sh
```

This will:
- Build order-service (Java/Maven)
- Build inventory-service (Go)
- Build payment-service (Python)
- Build notification-service (TypeScript/npm)
- Push images to local registry

**Expected time**: 5-10 minutes (first build)

### Step 3: Deploy Services

Deploy services via ArgoCD:

```bash
make deploy
```

Wait for services to be healthy:
```bash
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/part-of=saga-platform -n services --timeout=300s
```

### Step 4: Seed Test Data

Add test products to the inventory:

```bash
./scripts/seed-data.sh
```

This creates 5 test products with varying stock levels.

### Step 5: Test the Saga Flow

Create a test order and watch it flow through the system:

```bash
# Port forward the order service
kubectl port-forward svc/order-service -n services 8080:8080 &

# Run the test
./scripts/test-saga.sh
```

## Accessing the Platform

### Services

**Order Service API**:
```bash
kubectl port-forward svc/order-service -n services 8080:8080
# Access at http://localhost:8080
```

### Observability

**ArgoCD**:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Access at https://localhost:8080
# Username: admin
```

**Grafana**:
```bash
kubectl port-forward svc/prometheus-grafana -n observability 3000:80

# Access at http://localhost:3000
# Username: admin
# Password: admin
```

**Jaeger (Distributed Tracing)**:
```bash
kubectl port-forward svc/jaeger-query -n observability 16686:16686

# Access at http://localhost:16686
```

**Prometheus**:
```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090

# Access at http://localhost:9090
```

### Infrastructure

**PostgreSQL**:
```bash
kubectl port-forward svc/postgresql -n infra 5432:5432

# Connect with psql
psql -h localhost -U saga -d order_db
# Password: saga-password
```

**Redis**:
```bash
kubectl port-forward svc/redis-master -n infra 6379:6379

# Connect with redis-cli
redis-cli -h localhost -a redis-password
```

**Redpanda Console** (Kafka UI):
```bash
kubectl port-forward svc/redpanda-0 -n infra 8080:8080

# Access at http://localhost:8080
```

## Using the Platform

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

### Get Order Status

```bash
# Replace {orderId} with the ID from create response
curl http://localhost:8080/api/orders/{orderId} | jq '.'
```

### List All Orders

```bash
curl http://localhost:8080/api/orders | jq '.'
```

### Order Flow States

An order progresses through these states:

1. **PENDING** - Order created, waiting for inventory reservation
2. **INVENTORY_RESERVED** - Inventory reserved, waiting for payment
3. **PAYMENT_COMPLETED** - Payment succeeded, shipping initiated
4. **COMPLETED** - Saga completed successfully
5. **FAILED** - Saga failed (inventory unavailable or payment declined)

## Viewing Logs

### Service Logs

```bash
# Order Service
kubectl logs -l app=order-service -n services -f

# Inventory Service
kubectl logs -l app=inventory-service -n services -f

# Payment Service
kubectl logs -l app=payment-service -n services -f

# Notification Service
kubectl logs -l app=notification-service -n services -f
```

### View All Service Logs

```bash
stern -n services .
# (requires stern: brew install stern)
```

## Monitoring the Saga Flow

### In Jaeger

1. Access Jaeger UI: http://localhost:16686
2. Select service: `order-service`
3. Search by tag: `sagaId={orderId}`
4. View the complete trace across all services

### In Kafka

View events flowing through the system:

```bash
# Order events
kubectl exec -it redpanda-0 -n infra -- rpk topic consume order-events

# Inventory events
kubectl exec -it redpanda-0 -n infra -- rpk topic consume inventory-events

# Payment events
kubectl exec -it redpanda-0 -n infra -- rpk topic consume payment-events
```

### In Database

Check order status:
```bash
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d order_db -c "SELECT id, customer_id, status, total_amount FROM orders ORDER BY created_at DESC LIMIT 10;"
```

Check inventory reservations:
```bash
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d inventory_db -c "SELECT * FROM reservations ORDER BY created_at DESC LIMIT 10;"
```

Check payments:
```bash
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d payment_db -c "SELECT * FROM payments ORDER BY created_at DESC LIMIT 10;"
```

## Testing Failure Scenarios

### Test Insufficient Inventory

Create an order with quantity exceeding available stock:

```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-456",
    "items": [
      {
        "productId": "product-1",
        "quantity": 200,
        "price": 29.99
      }
    ]
  }'
```

Expected result: Order status = FAILED (InventoryFailed event)

### Test Payment Failure

The payment service has an 80% success rate, so approximately 20% of orders will fail at the payment stage. The inventory will be automatically released (compensation logic).

Create multiple orders and observe some failing at payment:

```bash
for i in {1..5}; do
  curl -X POST http://localhost:8080/api/orders \
    -H "Content-Type: application/json" \
    -d "{
      \"customerId\": \"customer-$i\",
      \"items\": [{
        \"productId\": \"product-1\",
        \"quantity\": 1,
        \"price\": 29.99
      }]
    }"
  echo ""
  sleep 2
done
```

Check which orders failed:
```bash
curl http://localhost:8080/api/orders | jq '.[] | select(.status == "FAILED")'
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -A

# Describe problematic pod
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>
```

### Services Not Connecting

```bash
# Check service endpoints
kubectl get endpoints -n services

# Check network policies
kubectl get networkpolicies -A

# Test connectivity from pod
kubectl exec -it <pod-name> -n services -- wget -O- http://postgresql.infra.svc.cluster.local:5432
```

### Events Not Flowing

```bash
# Check Redpanda status
kubectl get pods -n infra -l app=redpanda

# Check topics
kubectl exec -it redpanda-0 -n infra -- rpk topic list

# Check consumer groups
kubectl exec -it redpanda-0 -n infra -- rpk group list

# View consumer group lag
kubectl exec -it redpanda-0 -n infra -- rpk group describe order-service-group
```

### Database Connection Issues

```bash
# Check PostgreSQL
kubectl get pods -n infra -l app.kubernetes.io/name=postgresql

# Test connection
kubectl exec -it postgresql-0 -n infra -- psql -U saga -l

# Check logs
kubectl logs postgresql-0 -n infra
```

## Cleanup

### Restart Services

```bash
kubectl rollout restart deployment -n services
```

### Clear Test Data

```bash
# Clear orders
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d order_db -c "TRUNCATE TABLE orders CASCADE;"

# Clear inventory reservations
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d inventory_db -c "TRUNCATE TABLE reservations;"

# Clear payments
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d payment_db -c "TRUNCATE TABLE payments;"
```

### Reset Kafka Offsets

```bash
kubectl exec -it redpanda-0 -n infra -- rpk group delete order-service-group
kubectl exec -it redpanda-0 -n infra -- rpk group delete inventory-service-group
kubectl exec -it redpanda-0 -n infra -- rpk group delete payment-service-group
```

### Destroy Everything

```bash
make destroy
```

This removes the k3d cluster and all resources.

## Next Steps

- **Add Custom Products**: Modify seed-data.sh to add your own products
- **Create Dashboards**: Import Grafana dashboards for service metrics
- **Add Authentication**: Implement JWT authentication for APIs
- **Add Shipping Service**: Extend the saga with a shipping service
- **Add API Gateway**: Use Kong or similar for API management
- **Implement CQRS**: Add read models for order queries
- **Add Event Sourcing**: Store complete event history

## Architecture Highlights

This platform demonstrates:

✅ **Saga Choreography** - No central orchestrator  
✅ **Transactional Outbox** - At-least-once delivery  
✅ **Idempotency** - Exactly-once processing  
✅ **Compensation** - Automatic rollback on failures  
✅ **Polyglot** - Java, Go, Python, TypeScript  
✅ **GitOps** - Infrastructure as Code  
✅ **Observability** - Complete tracing and monitoring  

## Support

For issues or questions:
- Check [STATUS.md](STATUS.md) for implementation status
- Review [docs/architecture/saga-choreography.md](docs/architecture/saga-choreography.md) for patterns
- See [docs/runbooks/operational-runbook.md](docs/runbooks/operational-runbook.md) for operations

---

**Happy Learning!** 🚀
