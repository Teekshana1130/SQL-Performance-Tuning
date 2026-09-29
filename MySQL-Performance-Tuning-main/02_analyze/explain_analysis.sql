-- MySQL Performance Tuning - EXPLAIN Analysis
-- This script generates EXPLAIN output for all original slow queries
-- to identify performance bottlenecks.

USE ecommerce_perf;

-- EXPLAIN QUERY 1: Monthly Sales Aggregation
-- Expected issues: type=ALL (full scan), Using temporary, Using filesort

SELECT '=== EXPLAIN QUERY 1: Monthly Sales Aggregation ===' AS analysis;

EXPLAIN 
SELECT 
    *
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN categories cat ON p.category_id = cat.category_id
WHERE 
    YEAR(o.order_date) = 2025
    AND MONTH(o.order_date) = 6
ORDER BY o.order_date DESC;

-- JSON format for detailed analysis
EXPLAIN FORMAT=JSON
SELECT 
    *
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN categories cat ON p.category_id = cat.category_id
WHERE 
    YEAR(o.order_date) = 2025
    AND MONTH(o.order_date) = 6
ORDER BY o.order_date DESC;


-- EXPLAIN QUERY 2: Customer Purchase History (Correlated Subquery)
-- Expected issues: DEPENDENT SUBQUERY, executed for each row

SELECT '=== EXPLAIN QUERY 2: Customer Purchase History ===' AS analysis;

EXPLAIN 
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.city,
    c.state,
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS total_orders,
    (SELECT SUM(total_amount) FROM orders o WHERE o.customer_id = c.customer_id) AS total_spent,
    (SELECT MAX(order_date) FROM orders o WHERE o.customer_id = c.customer_id) AS last_order_date,
    (SELECT AVG(total_amount) FROM orders o WHERE o.customer_id = c.customer_id) AS avg_order_value
FROM customers c
WHERE c.customer_status = 'active'
ORDER BY total_spent DESC
LIMIT 1000;

EXPLAIN FORMAT=JSON
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.city,
    c.state,
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS total_orders,
    (SELECT SUM(total_amount) FROM orders o WHERE o.customer_id = c.customer_id) AS total_spent,
    (SELECT MAX(order_date) FROM orders o WHERE o.customer_id = c.customer_id) AS last_order_date,
    (SELECT AVG(total_amount) FROM orders o WHERE o.customer_id = c.customer_id) AS avg_order_value
FROM customers c
WHERE c.customer_status = 'active'
ORDER BY total_spent DESC
LIMIT 1000;


-- EXPLAIN QUERY 3: Product Performance Analysis
-- Expected issues: filesort, temporary table, full scans

SELECT '=== EXPLAIN QUERY 3: Product Performance Analysis ===' AS analysis;

EXPLAIN
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
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN categories cat ON p.category_id = cat.category_id
WHERE p.is_active = 1
GROUP BY p.product_id, p.product_name, p.sku, cat.category_name, p.category_id, p.cost_price
HAVING total_revenue > 0
ORDER BY total_revenue DESC;


-- EXPLAIN QUERY 4: Customer Search (Leading Wildcard)
-- Expected issues: type=ALL, no index possible with leading wildcard

SELECT '=== EXPLAIN QUERY 4: Customer Search ===' AS analysis;

EXPLAIN
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    c.city,
    c.state,
    c.registration_date
FROM customers c
WHERE 
    c.first_name LIKE '%john%'
    OR c.last_name LIKE '%smith%'
    OR c.email LIKE '%example%'
    OR c.city LIKE '%new%'
ORDER BY c.registration_date DESC
LIMIT 100;


-- EXPLAIN QUERY 5: Date Range Report
-- Expected issues: Function on column prevents index usage

SELECT '=== EXPLAIN QUERY 5: Date Range Report ===' AS analysis;

EXPLAIN
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
WHERE DATE(o.order_date) BETWEEN '2025-01-01' AND '2025-06-30'
GROUP BY DATE(o.order_date)
ORDER BY order_day;


-- STATUS CHECK

-- Check current indexes on tables
SELECT '=== CURRENT INDEXES ===' AS info;

SHOW INDEX FROM customers;
SHOW INDEX FROM orders;
SHOW INDEX FROM order_items;
SHOW INDEX FROM products;

-- Check table statistics
SELECT '=== TABLE STATISTICS ===' AS info;

SELECT 
    table_name,
    table_rows,
    ROUND(data_length / 1024 / 1024, 2) AS data_size_mb,
    ROUND(index_length / 1024 / 1024, 2) AS index_size_mb
FROM information_schema.tables
WHERE table_schema = 'ecommerce_perf'
ORDER BY table_rows DESC;

SELECT 'EXPLAIN analysis complete. Review output to identify optimization opportunities.' AS status;
