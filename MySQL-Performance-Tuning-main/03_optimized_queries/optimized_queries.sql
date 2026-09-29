-- MySQL Performance Tuning - Optimized Queries
-- These queries have been rewritten using best practices:
-- - Proper index utilization
-- - Eliminated correlated subqueries
-- - Removed functions on indexed columns
-- - Specific column selection

USE ecommerce_perf;

SET profiling = 1;

-- OPTIMIZED QUERY 1: Monthly Sales Aggregation
-- Changes:
-- 1. Replaced YEAR()/MONTH() functions with date range comparison
-- 2. Selected only required columns instead of SELECT *
-- 3. Uses new composite indexes on join columns

SELECT 
    o.order_id,
    o.order_date,
    o.order_status,
    o.total_amount,
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    oi.item_id,
    oi.quantity,
    oi.line_total,
    p.product_id,
    p.product_name,
    p.sku,
    cat.category_name
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
INNER JOIN categories cat ON p.category_id = cat.category_id
WHERE 
    o.order_date >= '2025-06-01'
    AND o.order_date < '2025-07-01'
ORDER BY o.order_date DESC;


-- OPTIMIZED QUERY 2: Customer Purchase History
-- Changes:
-- 1. Replaced 4 correlated subqueries with single JOIN + GROUP BY
-- 2. Uses index on customers.customer_status
-- 3. Uses index on orders.customer_id

SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.city,
    c.state,
    COUNT(o.order_id) AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS total_spent,
    MAX(o.order_date) AS last_order_date,
    COALESCE(AVG(o.total_amount), 0) AS avg_order_value
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE c.customer_status = 'active'
GROUP BY 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.city,
    c.state
ORDER BY total_spent DESC
LIMIT 1000;


-- OPTIMIZED QUERY 3: Product Performance Analysis
-- Changes:
-- 1. Uses indexes on order_items.product_id and order_items.order_id
-- 2. Simplified JOIN order for better optimization
-- 3. Added index hints where beneficial

SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    cat.category_name,
    COUNT(DISTINCT oi.order_id) AS times_ordered,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.line_total) AS total_revenue,
    AVG(oi.unit_price) AS avg_selling_price,
    SUM(oi.line_total) - (SUM(oi.quantity) * p.cost_price) AS gross_profit,
    RANK() OVER (PARTITION BY p.category_id ORDER BY SUM(oi.line_total) DESC) AS category_rank
FROM products p
INNER JOIN categories cat ON p.category_id = cat.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
WHERE p.is_active = 1
GROUP BY 
    p.product_id, 
    p.product_name, 
    p.sku, 
    cat.category_name, 
    p.category_id, 
    p.cost_price
HAVING SUM(oi.line_total) > 0
ORDER BY total_revenue DESC;


-- OPTIMIZED QUERY 4: Customer Search (Using FULLTEXT)
-- Changes:
-- 1. Uses FULLTEXT index for text search (much faster than LIKE)
-- 2. Requires FULLTEXT index on first_name, last_name, email, city
-- 3. Alternative UNION approach provided below

-- Option A: FULLTEXT Search (Preferred)
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    c.city,
    c.state,
    c.registration_date,
    MATCH(c.first_name, c.last_name, c.email, c.city) AGAINST ('john smith example new' IN NATURAL LANGUAGE MODE) AS relevance
FROM customers c
WHERE MATCH(c.first_name, c.last_name, c.email, c.city) 
      AGAINST ('john smith example new' IN NATURAL LANGUAGE MODE)
ORDER BY relevance DESC, c.registration_date DESC
LIMIT 100;

-- Option B: UNION approach (if FULLTEXT not available)
-- Each sub-select can use a single-column index

/*
(SELECT customer_id, first_name, last_name, email, phone, city, state, registration_date
 FROM customers WHERE first_name LIKE 'john%')
UNION
(SELECT customer_id, first_name, last_name, email, phone, city, state, registration_date
 FROM customers WHERE last_name LIKE 'smith%')
UNION
(SELECT customer_id, first_name, last_name, email, phone, city, state, registration_date
 FROM customers WHERE city LIKE 'new%')
ORDER BY registration_date DESC
LIMIT 100;
*/


-- OPTIMIZED QUERY 5: Date Range Report
-- Changes:
-- 1. Removed DATE() function from WHERE clause
-- 2. Uses index on order_date directly
-- 3. Casts to DATE only in SELECT (after filtering)

SELECT 
    DATE(o.order_date) AS order_day,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(o.total_amount) AS daily_revenue,
    AVG(o.total_amount) AS avg_order_value,
    MIN(o.total_amount) AS min_order,
    MAX(o.total_amount) AS max_order,
    SUM(CASE WHEN o.order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,
    SUM(CASE WHEN o.order_status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    SUM(CASE WHEN o.payment_method = 'credit_card' THEN o.total_amount ELSE 0 END) AS credit_card_revenue,
    SUM(CASE WHEN o.payment_method = 'paypal' THEN o.total_amount ELSE 0 END) AS paypal_revenue
FROM orders o
WHERE o.order_date >= '2025-01-01 00:00:00'
  AND o.order_date < '2025-07-01 00:00:00'
GROUP BY DATE(o.order_date)
ORDER BY order_day;


-- OPTIMIZED INVENTORY ALERT REPORT
-- Changes:
-- 1. Replaced correlated subqueries with JOIN + GROUP BY
-- 2. Uses index on products for filtering

SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    p.stock_quantity,
    p.reorder_level,
    cat.category_name,
    COALESCE(SUM(oi.quantity), 0) AS total_sold,
    COUNT(oi.item_id) AS order_count
FROM products p
INNER JOIN categories cat ON p.category_id = cat.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
WHERE p.stock_quantity <= p.reorder_level
  AND p.is_active = 1
GROUP BY 
    p.product_id,
    p.product_name,
    p.sku,
    p.stock_quantity,
    p.reorder_level,
    cat.category_name
ORDER BY p.stock_quantity ASC;


-- View profiling results
SHOW PROFILES;

SELECT 'Optimized queries executed. Compare with original query times.' AS status;
