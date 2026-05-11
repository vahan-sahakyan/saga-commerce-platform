-- Create inventories table (fresh, with price)
CREATE TABLE IF NOT EXISTS inventories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id VARCHAR NOT NULL UNIQUE,
    quantity INTEGER NOT NULL,
    reserved INTEGER NOT NULL DEFAULT 0,
    price DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_inventories_product_id ON inventories(product_id);