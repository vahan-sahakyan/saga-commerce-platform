# Saga Commerce Platform - Operational Runbook

## Table of Contents
1. [System Overview](#system-overview)
2. [Deployment](#deployment)
3. [Monitoring](#monitoring)
4. [Troubleshooting](#troubleshooting)
5. [Common Operations](#common-operations)

---

## System Overview

### Services

| Service | Language | Port | Topics Consumed | Topics Produced |
|---------|----------|------|----------------|-----------------|
| order-service | Java/Spring Boot | 8080 | inventory-events, payment-events, shipping-events | order-events |
| inventory-service | Go | 8080 | order-events, payment-events | inventory-events |
| payment-service | Python/FastAPI | 8080 | inventory-events | payment-events |
| notification-service | TypeScript/Fastify | 8080 | order-events, shipping-events | - |

### Infrastructure

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| Redpanda | infra | Message broker (Kafka-compatible) |
| PostgreSQL | infra | Primary database |
| Redis | infra | Cache and distributed locks |
| ArgoCD | argocd | GitOps controller |
| Prometheus | observability | Metrics collection |
| Grafana | observability | Dashboards |
| Jaeger | observability | Distributed tracing |

---

## Deployment

### Initial Setup

```bash
# 1. Create k3d cluster
make create-cluster

# 2. Install infrastructure
make install-infra

# 3. Wait for infrastructure to be ready
kubectl wait --for=condition=Ready pods --all -n infra --timeout=300s
kubectl wait --for=condition=Ready pods --all -n observability --timeout=300s

# 4. Build and push service images
./scripts/build-all.sh

# 5. Deploy services
make deploy
```

### Update a Service

```bash
# 1. Make code changes
# 2. Build new image
cd services/<service-name>
docker build -t localhost:5000/<service-name>:latest .
docker push localhost:5000/<service-name>:latest

# 3. Restart deployment
kubectl rollout restart deployment/<service-name> -n services

# 4. Watch rollout
kubectl rollout status deployment/<service-name> -n services
```

### Rollback a Service

```bash
# View rollout history
kubectl rollout history deployment/<service-name> -n services

# Rollback to previous version
kubectl rollout undo deployment/<service-name> -n services

# Rollback to specific revision
kubectl rollout undo deployment/<service-name> -n services --to-revision=2
```

---

## Monitoring

### Check Service Health

```bash
# All pods
kubectl get pods -n services

# Specific service
kubectl get pods -n services -l app=order-service

# Detailed pod info
kubectl describe pod <pod-name> -n services
```

### View Logs

```bash
# Stream logs
kubectl logs -f <pod-name> -n services

# Last 100 lines
kubectl logs --tail=100 <pod-name> -n services

# Logs from all replicas
kubectl logs -l app=order-service -n services --all-containers=true

# Logs with timestamps
kubectl logs <pod-name> -n services --timestamps=true
```

### Metrics

```bash
# Access Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090

# Useful queries:
# - Rate of events published: rate(kafka_producer_record_send_total[5m])
# - Event processing errors: sum(rate(kafka_consumer_fetch_errors_total[5m]))
# - Service request rate: rate(http_server_requests_seconds_count[5m])
```

### Distributed Tracing

```bash
# Access Jaeger UI
kubectl port-forward svc/jaeger-query -n observability 16686:16686

# Search traces by:
# - Service name
# - Operation name
# - Tags (sagaId, orderId)
# - Duration
```

### Dashboards

```bash
# Access Grafana
kubectl port-forward svc/prometheus-grafana -n observability 3000:80

# Default credentials: admin/admin
```

---

## Troubleshooting

### Service Won't Start

**Symptoms**: Pod in CrashLoopBackOff state

**Steps**:
```bash
# 1. Check pod events
kubectl describe pod <pod-name> -n services

# 2. Check logs
kubectl logs <pod-name> -n services

# 3. Common issues:
#    - Database connection failed
#    - Kafka connection failed
#    - Configuration missing
#    - Resource limits too low

# 4. Verify dependencies
kubectl get pods -n infra
```

**Solution**: Check environment variables and connection strings in Helm values

### Events Not Being Consumed

**Symptoms**: Events published but not processed by consumer

**Steps**:
```bash
# 1. Check Kafka topics
kubectl exec -it redpanda-0 -n infra -- rpk topic list

# 2. Check messages in topic
kubectl exec -it redpanda-0 -n infra -- rpk topic consume order-events --num 10

# 3. Check consumer group lag
kubectl exec -it redpanda-0 -n infra -- rpk group describe order-service-group

# 4. Check service logs for errors
kubectl logs -l app=inventory-service -n services --tail=50
```

**Common Causes**:
- Consumer not started
- Deserialization errors
- Processing errors (check idempotency)
- Consumer group offset committed too early

### Database Connection Issues

**Symptoms**: Service logs show database connection errors

**Steps**:
```bash
# 1. Check PostgreSQL pod
kubectl get pods -n infra -l app.kubernetes.io/name=postgresql

# 2. Test connection from service pod
kubectl exec -it <service-pod> -n services -- nc -zv postgresql.infra.svc.cluster.local 5432

# 3. Check PostgreSQL logs
kubectl logs postgresql-0 -n infra

# 4. Verify credentials
kubectl get secret -n infra
```

**Solution**: Verify connection string and credentials in service configuration

### Outbox Events Not Publishing

**Symptoms**: Events stored in outbox but not published to Kafka

**Steps**:
```bash
# 1. Check outbox table
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d order_db -c "SELECT * FROM outbox_events WHERE published = false;"

# 2. Check publisher logs
kubectl logs -l app=order-service -n services | grep -i "publish"

# 3. Verify Kafka connection
kubectl logs -l app=order-service -n services | grep -i "kafka"
```

**Common Causes**:
- Scheduler not running
- Kafka connection issues
- Serialization errors

### Saga Not Completing

**Symptoms**: Order stuck in PENDING or INVENTORY_RESERVED status

**Steps**:
```bash
# 1. Check order status
curl http://localhost:8080/api/orders/<order-id>

# 2. Check events in Kafka
kubectl exec -it redpanda-0 -n infra -- rpk topic consume order-events --offset start

# 3. Check each service's processed_events table
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d inventory_db -c "SELECT * FROM processed_events ORDER BY processed_at DESC LIMIT 10;"

# 4. View distributed trace in Jaeger
# Search by sagaId (order ID)
```

**Common Causes**:
- Service down during event processing
- Event processing error (check logs)
- Inventory insufficient (expected behavior)
- Payment declined (expected behavior)

### High Memory/CPU Usage

**Symptoms**: Pod restarting due to OOMKilled or CPU throttling

**Steps**:
```bash
# 1. Check resource usage
kubectl top pods -n services

# 2. Check resource limits
kubectl describe pod <pod-name> -n services | grep -A 5 "Limits:"

# 3. View detailed metrics in Grafana
# Dashboard: Kubernetes / Compute Resources / Pod
```

**Solution**: Adjust resource limits in Helm values

```yaml
resources:
  limits:
    cpu: 1000m      # Increase if needed
    memory: 1Gi     # Increase if needed
  requests:
    cpu: 500m
    memory: 512Mi
```

---

## Common Operations

### Scale a Service

```bash
# Scale up
kubectl scale deployment order-service -n services --replicas=3

# Scale down
kubectl scale deployment order-service -n services --replicas=1

# Auto-scale (requires metrics server)
kubectl autoscale deployment order-service -n services --min=1 --max=5 --cpu-percent=80
```

### Restart a Service

```bash
kubectl rollout restart deployment/<service-name> -n services
```

### View Kafka Topics

```bash
# List topics
kubectl exec -it redpanda-0 -n infra -- rpk topic list

# Describe topic
kubectl exec -it redpanda-0 -n infra -- rpk topic describe order-events

# Create topic (if needed)
kubectl exec -it redpanda-0 -n infra -- rpk topic create test-topic --partitions 3 --replicas 1

# Delete topic
kubectl exec -it redpanda-0 -n infra -- rpk topic delete test-topic
```

### Access Databases

```bash
# Port forward PostgreSQL
kubectl port-forward svc/postgresql -n infra 5432:5432

# Connect with psql
psql -h localhost -U saga -d order_db

# Port forward Redis
kubectl port-forward svc/redis-master -n infra 6379:6379

# Connect with redis-cli
redis-cli -h localhost -a redis-password
```

### View Consumer Groups

```bash
# List consumer groups
kubectl exec -it redpanda-0 -n infra -- rpk group list

# Describe consumer group
kubectl exec -it redpanda-0 -n infra -- rpk group describe order-service-group

# Seek consumer group offset
kubectl exec -it redpanda-0 -n infra -- rpk group seek order-service-group --to start
```

### Backup Database

```bash
# Backup
kubectl exec postgresql-0 -n infra -- pg_dump -U saga order_db > order_db_backup.sql

# Restore
cat order_db_backup.sql | kubectl exec -i postgresql-0 -n infra -- psql -U saga -d order_db
```

### Clean Up Test Data

```bash
# Clear orders
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d order_db -c "TRUNCATE TABLE orders CASCADE;"

# Clear outbox
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d order_db -c "TRUNCATE TABLE outbox_events;"

# Clear processed events
kubectl exec -it postgresql-0 -n infra -- psql -U saga -d order_db -c "TRUNCATE TABLE processed_events;"
```

### Update Configuration

```bash
# Edit Helm values
vi infra/helm/order-service/values.yaml

# Apply changes
helm upgrade order-service infra/helm/order-service -n services

# Or use ArgoCD
kubectl apply -f infra/argocd/applications/order-service.yaml
```

---

## Emergency Procedures

### Full System Restart

```bash
# 1. Scale down all services
kubectl scale deployment --all -n services --replicas=0

# 2. Wait for pods to terminate
kubectl wait --for=delete pods --all -n services --timeout=60s

# 3. Clear Kafka consumer offsets (optional)
kubectl exec -it redpanda-0 -n infra -- rpk group delete order-service-group
kubectl exec -it redpanda-0 -n infra -- rpk group delete inventory-service-group
kubectl exec -it redpanda-0 -n infra -- rpk group delete payment-service-group

# 4. Scale up services
kubectl scale deployment --all -n services --replicas=1

# 5. Verify health
kubectl get pods -n services
```

### Complete Teardown and Rebuild

```bash
# Destroy everything
make destroy

# Rebuild from scratch
make bootstrap
make deploy
```

---

## Alerting Rules

Recommended alerts to set up in Prometheus/AlertManager:

1. **Service Down**
   - Rule: `up{job="<service-name>"} == 0`
   - Severity: Critical

2. **High Error Rate**
   - Rule: `rate(http_requests_total{status=~"5.."}[5m]) > 0.05`
   - Severity: Warning

3. **Event Processing Lag**
   - Rule: `kafka_consumergroup_lag > 1000`
   - Severity: Warning

4. **Database Connection Pool Exhausted**
   - Rule: `hikaricp_connections_active / hikaricp_connections_max > 0.9`
   - Severity: Warning

5. **Pod Restart Loop**
   - Rule: `rate(kube_pod_container_status_restarts_total[15m]) > 0`
   - Severity: Critical
