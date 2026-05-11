# Bootstrap Process - Detailed Guide

This document explains the complete bootstrap process, why each step is necessary, and how to troubleshoot common issues.

## Bootstrap Flow

The correct bootstrap sequence is:

```
make bootstrap
    ↓
make init-data
    ↓
./scripts/build-all.sh
    ↓
make deploy
    ↓
./scripts/seed-data.sh (optional)
```

**CRITICAL**: Do NOT skip the `make init-data` step. Services will crash without it.

---

## Step 1: `make bootstrap`

### What It Does

Creates and configures the Kubernetes cluster and deploys infrastructure services:

1. **Creates k3d cluster** (`saga-platform`)
   - 1 control-plane node
   - 2 worker nodes
   - Local Docker registry at `localhost:5000`

2. **Installs Terraform infrastructure** via `infra/terraform/`
   - ArgoCD (GitOps controller)
   - Redpanda/Kafka (message broker)
   - PostgreSQL (database)
   - Redis (cache)
   - Prometheus (metrics)
   - Grafana (dashboards)
   - Jaeger (distributed tracing)

3. **Creates Kubernetes namespaces**
   - `infra` - infrastructure services
   - `argocd` - GitOps
   - `services` - microservices
   - `observability` - monitoring

### Expected Output

```bash
$ make bootstrap
...
Terraform apply successful
✓ All infrastructure deployed
✓ PostgreSQL ready
✓ Redpanda ready
✓ ArgoCD ready
```

### Check Status

```bash
kubectl get pods -A
```

All pods in `infra` and `observability` namespaces should be `Running` or `Completed`.

**Troubleshooting:**

```bash
# Check cluster health
k3d cluster list
k3d node list

# Check infrastructure pod status
kubectl get pods -n infra
kubectl get pods -n observability

# Check pod logs if any are failing
kubectl logs <pod-name> -n infra -f
```

---

## Step 2: `make init-data` ⚠️ CRITICAL

### Why This Step Is Required

Services fail on startup without this step because:

1. **PostgreSQL deployed but no service databases exist**
   - PostgreSQL container is running
   - Only the system `postgres` database exists
   - Services expect: `order_db`, `inventory_db`, `payment_db`
   - Error: `FATAL: database "order_db" does not exist`

2. **Redpanda deployed but no topics exist**
   - Kafka broker is running
   - Topics don't auto-create
   - Services subscribe to: `order-events`, `inventory-events`, `payment-events`, etc.
   - Error: `KafkaJSProtocolError: This server does not host this topic-partition`

### What It Does

```bash
make init-data
```

This runs `scripts/init-data.sh` which:

1. **Creates PostgreSQL databases**
   ```bash
   CREATE DATABASE order_db;
   CREATE DATABASE inventory_db;
   CREATE DATABASE payment_db;
   ```

2. **Creates Kafka topics**
   ```bash
   rpk topic create order-events
   rpk topic create inventory-events
   rpk topic create payment-events
   rpk topic create notification-events
   rpk topic create shipping-events
   ```

3. **Idempotent** - Safe to run multiple times
   - If databases already exist, CREATE IF NOT EXISTS
   - If topics already exist, command fails gracefully

### Expected Output

```bash
$ make init-data
Creating databases...
✓ order_db
✓ inventory_db
✓ payment_db

Creating Kafka topics...
✓ order-events
✓ inventory-events
✓ payment-events
✓ notification-events
✓ shipping-events
```

### Verify

```bash
# Check databases
kubectl exec -it postgresql-0 -n infra -- psql -U saga -c "\l"
# Should show: order_db, inventory_db, payment_db

# Check Kafka topics
kubectl exec -it redpanda-0 -n infra -- rpk topic list
# Should show: order-events, inventory-events, payment-events, notification-events, shipping-events
```

### Troubleshooting

```bash
# If init-data fails, check PostgreSQL connectivity
kubectl exec -it postgresql-0 -n infra -- psql -U saga -c "SELECT 1"

# Check Redpanda connectivity
kubectl exec -it redpanda-0 -n infra -- rpk cluster info

# View init script logs (if issues)
kubectl logs deployment/init-databases -n infra
```

---

## Step 3: `./scripts/build-all.sh`

### What It Does

Builds Docker images for all 4 services and pushes to local registry:

1. **order-service** (Java/Spring Boot)
   - Maven build: `mvn clean package`
   - Docker build: `docker build -t localhost:5000/order-service:latest`

2. **inventory-service** (Go)
   - Docker build: `docker build -t localhost:5000/inventory-service:latest`

3. **payment-service** (Python/FastAPI)
   - Docker build: `docker build -t localhost:5000/payment-service:latest`

4. **notification-service** (TypeScript/Fastify)
   - npm build: `npm run build`
   - Docker build: `docker build -t localhost:5000/notification-service:latest`

All images are pushed to the local k3d registry.

### Expected Time

- First build: 5-10 minutes (Maven downloads dependencies)
- Subsequent builds: 1-2 minutes (cached layers)

### Java Requirements

**MUST use Java 21** - order-service requires it:

```bash
# Check Java version
java -version
# Should output: openjdk version "21.x"

# If wrong version, install Java 21
brew install --cask temurin-jdk

# Set JAVA_HOME if needed
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
```

### Troubleshooting

```bash
# If Java build fails, check Java version
java -version

# If Docker build fails, check registry connectivity
docker tag busybox:latest localhost:5000/test:latest
docker push localhost:5000/test:latest

# View build logs
./scripts/build-all.sh 2>&1 | tail -50
```

---

## Step 4: `make deploy`

### What It Does

1. **Deploys services via ArgoCD** using Helm charts in `infra/helm/*/`
2. **Services initialize with Init Containers** (Kubernetes-native pattern)
3. **Services wait for dependencies** before starting main container

### Init Containers Pattern

Each service deployment includes init containers that wait for dependencies:

```yaml
initContainers:
- name: wait-for-postgres
  image: postgres:16-alpine
  command:
  - sh
  - -c
  - |
    until pg_isready -h postgresql.infra.svc.cluster.local -p 5432; do
      sleep 2
    done

- name: wait-for-kafka
  image: redpandadata/redpanda:v23.3.6
  command:
  - bash
  - -c
  - |
    KAFKA_BROKER="redpanda.infra.svc.cluster.local:9093"
    until rpk cluster info -X brokers="$KAFKA_BROKER" &>/dev/null; do
      sleep 2
    done
```

### Why Init Containers Are Important

**Problem:** Services started immediately but needed databases/Kafka ready
- Services crash with "connection refused" errors
- Race condition: app starts before infrastructure is available

**Solution:** Init containers run BEFORE main container
- Polls dependency health
- Blocks startup until ready
- Observable via `kubectl describe pod`
- No hardcoded sleeps or timeouts

### Expected Output

```bash
$ make deploy
ArgoCD syncing applications...
✓ order-service deployed
✓ inventory-service deployed
✓ payment-service deployed
✓ notification-service deployed

$ kubectl get pods -n services
NAME                              READY   STATUS    RESTARTS   AGE
order-service-xxx                 1/1     Running   0          2m
inventory-service-xxx             1/1     Running   0          2m
payment-service-xxx               1/1     Running   0          2m
notification-service-xxx          1/1     Running   0          2m
```

### Verify Pods Are Ready

```bash
# Check all services are running
kubectl get pods -n services

# Check init containers ran successfully
kubectl describe pod <pod-name> -n services | grep -A 10 "Init Containers"

# Should see: "Initialized: True"
```

### Troubleshooting

```bash
# If services stuck in CrashLoopBackOff
kubectl logs <pod-name> -n services -c wait-for-postgres
kubectl logs <pod-name> -n services -c wait-for-kafka

# If services fail to start main container
kubectl logs <pod-name> -n services

# Check pod events for detailed error info
kubectl describe pod <pod-name> -n services
```

---

## Common Bootstrap Failures & Solutions

### ❌ "Services stuck in CrashLoopBackOff"

**Cause:** Missing databases or Kafka topics

**Solution:**
```bash
# Run init-data
make init-data

# Restart services
kubectl rollout restart deployment -n services
```

---

### ❌ "FATAL: database 'order_db' does not exist"

**Cause:** `make init-data` was skipped

**Solution:**
```bash
make init-data
kubectl rollout restart deployment -n services
```

---

### ❌ "KafkaJSProtocolError: This server does not host this topic-partition"

**Cause:** Kafka topics not created

**Solution:**
```bash
# Check if topics exist
kubectl exec -it redpanda-0 -n infra -- rpk topic list

# Create missing topics
make init-data

# Restart services
kubectl rollout restart deployment -n services
```

---

### ❌ "Connection refused" to PostgreSQL

**Cause:** PostgreSQL not ready or init-data failed

**Solution:**
```bash
# Check PostgreSQL is running
kubectl get pod postgresql-0 -n infra

# Check it's responding
kubectl exec -it postgresql-0 -n infra -- psql -U saga -c "SELECT 1"

# If not responding, restart PostgreSQL
kubectl rollout restart statefulset/postgresql -n infra

# Re-run init-data
make init-data
```

---

### ❌ "Java build fails with 'Unsupported class version'"

**Cause:** Wrong Java version (need Java 21)

**Solution:**
```bash
# Check Java version
java -version

# Install Java 21 if needed
brew install --cask temurin-jdk

# Set JAVA_HOME
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home

# Retry build
./scripts/build-all.sh
```

---

### ❌ "Failed to build services"

**Cause:** Local registry unavailable

**Solution:**
```bash
# Check k3d cluster is running
k3d cluster list

# Check registry is accessible
docker pull alpine:latest
docker tag alpine:latest localhost:5000/test:latest
docker push localhost:5000/test:latest

# If registry push fails, recreate k3d cluster
make destroy
make bootstrap
make init-data
```

---

## Correct Full Bootstrap Sequence

```bash
# 1. Install dependencies (one-time)
./scripts/install-deps.sh

# 2. Check dependencies
./scripts/preflight-check.sh

# 3. Bootstrap infrastructure (5-10 min)
make bootstrap

# 4. Initialize databases and topics (1 min) ⚠️ CRITICAL
make init-data

# 5. Build services (5-10 min first time)
./scripts/build-all.sh

# 6. Deploy services (2 min)
make deploy

# 7. Wait for services to be ready (1-2 min)
kubectl wait --for=condition=Ready pods -n services --all --timeout=300s

# 8. Seed test data (optional)
./scripts/seed-data.sh

# 9. Test the platform
kubectl port-forward svc/order-service -n services 8080:8080 &
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-123",
    "items": [{"productId": "product-1", "quantity": 2, "price": 29.99}]
  }'
```

---

## After Bootstrap Complete

Once all services are running:

### Access the Platform

```bash
# Order Service API
kubectl port-forward svc/order-service -n services 8080:8080

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Grafana
kubectl port-forward svc/prometheus-grafana -n observability 3000:80

# Jaeger
kubectl port-forward svc/jaeger-query -n observability 16686:16686
```

### Monitor Services

```bash
# Watch pod status
watch kubectl get pods -n services

# Stream logs from all services
kubectl logs -n services -l app.kubernetes.io/part-of=saga-platform -f

# Check events
kubectl get events -n services --sort-by='.lastTimestamp'
```

### Troubleshoot Issues

See [operational-runbook.md](runbooks/operational-runbook.md) for detailed troubleshooting and operations guides.
