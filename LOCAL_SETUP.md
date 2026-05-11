# Local Development Setup (Services Only, Infra in Docker)

This guide runs the 4 microservices **locally as native processes** while keeping PostgreSQL, Redis, and Kafka in Docker.

## Prerequisites

- Docker and Docker Compose
- Java 21 (for order-service)
- Go 1.21+ (for inventory-service)
- Python 3.11+ (for payment-service)
- Node.js 18+ (for notification-service)
- Maven (for Java)

## Quick Start

### 1. Start Infrastructure (PostgreSQL, Redis, Kafka)

```bash
# Start all infra services in the background
docker-compose up -d

# Verify all are healthy
docker-compose ps
```

Output should show all services as `healthy` or `running`.

### 2. Initialize Databases and Kafka Topics

```bash
# Make script executable
chmod +x scripts/init-local.sh

# Initialize databases and topics
./scripts/init-local.sh
```

This creates:
- PostgreSQL databases: `order_db`, `inventory_db`, `payment_db`
- Kafka topics: `order-events`, `inventory-events`, `payment-events`, `notification-events`, `shipping-events`

### 3. Build and Run Services

Open **4 separate terminals** (one for each service):

#### Terminal 1: Order Service (Java)
```bash
cd services/order-service
mvn spring-boot:run
```
Runs on `http://localhost:8080`

#### Terminal 2: Inventory Service (Go)
```bash
cd services/inventory-service
PORT=8881 go run ./cmd/server/main.go
```
Runs on `http://localhost:8881`

#### Terminal 3: Payment Service (Python)
```bash
cd services/payment-service
# create and activate virtual environment (recommended)
python3 -m venv .venv
source .venv/bin/activate
# install dependencies
pip install -r requirements.txt
# run the service
make dev
```
Runs on `http://localhost:8882` (using the .venv virtual environment)

#### Terminal 4: Notification Service (TypeScript)
```bash
cd services/notification-service
PORT=8883 npm run dev
```
Runs on `http://localhost:8883`

## Testing the Saga Flow

Once all 4 services are running, create an order:

```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-1",
    "items": [
      {"productId": "product-1", "quantity": 2, "price": 10.0}
    ]
  }'
```

The saga will automatically flow through:
1. **Order Service** - Creates order
2. **Inventory Service** - Reserves inventory
3. **Payment Service** - Processes payment (80% success rate)
4. **Notification Service** - Logs completion/failure

Check the logs in each terminal to see the saga unfold.

## Configuration

Services use these defaults (can be overridden with environment variables):

```bash
# PostgreSQL
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=saga
POSTGRES_PASSWORD=saga-password

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis-password

# Kafka
KAFKA_BOOTSTRAP_SERVERS=localhost:9092

# Jaeger (optional, services work without it)
JAEGER_ENDPOINT=http://localhost:14268/api/traces
```

### Custom Configuration (Optional)

To override defaults, set environment variables:

```bash
# Example: Change Kafka bootstrap servers
export KAFKA_BOOTSTRAP_SERVERS=localhost:9092

# Then run the service
cd services/order-service
mvn clean spring-boot:run
```

Or create a `.env` file in each service directory and source it before running.

## Stopping Services

### Stop Infra (Docker)
```bash
docker-compose down

# To keep volumes for next session:
docker-compose down -v  # removes volumes

# Or just pause containers:
docker-compose stop
```

### Stop Services
Simply press `Ctrl+C` in each terminal.

## Troubleshooting

### "Connection refused" errors
- Ensure `docker-compose up -d` succeeded
- Check health: `docker-compose ps`
- Verify ports aren't in use: `lsof -i :5432` (postgres), `lsof -i :6379` (redis), `lsof -i :9092` (kafka)

### Services can't connect to Kafka
- Wait a bit longer for Redpanda to fully start
- Re-run `./scripts/init-local.sh` to check connectivity
- Check container logs: `docker-compose logs redpanda`

### PostgreSQL password errors
- Ensure databases were initialized: `./scripts/init-local.sh`
- Check POSTGRES_PASSWORD env var matches docker-compose.yml (default: `saga-password`)

### Port conflicts
If ports are already in use, edit `docker-compose.yml`:
```yaml
postgresql:
  ports:
    - "5433:5432"  # change host port from 5432 to 5433
```
Then update service env vars accordingly.

## Next Steps

- Create more test orders to see saga patterns (success, failure, compensation)
- Add observability: See [QUICKSTART.md](QUICKSTART.md) for full stack with Prometheus/Grafana/Jaeger
- Modify services and rebuild locally (no Docker rebuild needed)
- Review [docs/events/event-schemas.md](../docs/events/event-schemas.md) for event structure
