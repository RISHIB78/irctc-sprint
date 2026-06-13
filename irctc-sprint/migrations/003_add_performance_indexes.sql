-- 003_add_performance_indexes.sql

-- Justification: The `orders.user_id` column is filtered in order history queries; this index converts a sequential scan on `orders` into an index scan for user-specific lookups.
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);

-- Justification: The `orders` table is frequently ordered by `created_at` when listing recent orders per user; this composite index on `(user_id, created_at DESC)` covers the WHERE and ORDER BY to avoid an explicit sort.
CREATE INDEX IF NOT EXISTS idx_orders_user_created ON orders(user_id, created_at DESC);

-- Justification: `order_items.order_id` is used to fetch items for each order; indexing this foreign key converts repeated sequential scans into fast index lookups.
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);

-- Justification: `menu_items.restaurant_id` is filtered when retrieving a restaurant's menu; indexing this column removes full-table scans on `menu_items`.
CREATE INDEX IF NOT EXISTS idx_menu_items_restaurant ON menu_items(restaurant_id);

-- Justification: Browsing restaurants filters by `city` and `active=true`; a partial composite index on `(city, active)` with `WHERE active = true` speeds up these filtered queries.
CREATE INDEX IF NOT EXISTS idx_restaurants_city_active ON restaurants(city, active) WHERE active = true;
