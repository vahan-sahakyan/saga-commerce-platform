#!/bin/bash

set -e

echo "🌱 Seeding test data..."

# wait for postgresql to be ready
echo "⏳ Waiting for PostgreSQL..."
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=postgresql -n infra --timeout=120s

# seed inventory data
echo "📦 Seeding inventory data..."

kubectl exec -it postgresql-0 -n infra -- psql -U saga -d inventory_db <<EOF
-- create some products in inventory
INSERT INTO inventories (id, product_id, quantity, reserved, price, created_at, updated_at)
VALUES
    (gen_random_uuid(), 'product-1', 100, 0, 29.99, NOW(), NOW()),
    (gen_random_uuid(), 'product-2', 50, 0, 49.99, NOW(), NOW()),
    (gen_random_uuid(), 'product-3', 75, 0, 19.99, NOW(), NOW()),
    (gen_random_uuid(), 'product-4', 200, 0, 9.99, NOW(), NOW()),
    (gen_random_uuid(), 'product-5', 30, 0, 99.99, NOW(), NOW())
ON CONFLICT (product_id) DO NOTHING;
EOF

echo "✅ Test data seeded successfully!"
echo ""
echo "Available products:"
echo "  - product-1: 100 units"
echo "  - product-2: 50 units"
echo "  - product-3: 75 units"
echo "  - product-4: 200 units"
echo "  - product-5: 30 units"
