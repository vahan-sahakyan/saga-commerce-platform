-- Seed initial inventory data with price
INSERT INTO inventories (id, product_id, quantity, reserved, price, created_at, updated_at)
VALUES
    (gen_random_uuid(), 'product-1', 100, 0, 29.99, NOW(), NOW()),
    (gen_random_uuid(), 'product-2', 50, 0, 49.99, NOW(), NOW()),
    (gen_random_uuid(), 'product-3', 75, 0, 19.99, NOW(), NOW()),
    (gen_random_uuid(), 'product-4', 200, 0, 9.99, NOW(), NOW()),
    (gen_random_uuid(), 'product-5', 30, 0, 99.99, NOW(), NOW())
ON CONFLICT (product_id) DO NOTHING;