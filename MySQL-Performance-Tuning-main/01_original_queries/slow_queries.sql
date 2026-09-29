-- MySQL Performance Tuning - Original Slow Queries
-- These are intentionally unoptimized queries typical of reporting workloads.
-- Each query demonstrates common performance anti-patterns.

USE ecommerce_perf;

-- Enable profiling to measure execution times
SET profiling = 1;

-- QUERY 1: Monthly Sales Aggregation with Multiple JOINs
-- Problem: No indexes on join columns, SELECT *, suboptimal date filtering
-- Expected issue: Full table scans on large tables

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


-- QUERY 2: Customer Purchase History with Correlated Subquery
-- Problem: Correlated subquery executes once per row in outer query
-- Expected issue: N+1 query pattern, very slow on large datasets

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


-- QUERY 3: Product Performance Analysis
-- Problem: No index on category_id, expensive aggregation without proper filtering
-- Expected issue: Filesort, temporary tables

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


-- QUERY 4: Customer Search with LIKE Pattern (Leading Wildcard)
-- Problem: Leading wildcard prevents index usage, OR conditions
-- Expected issue: Full table scan, no index utilization

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


-- QUERY 5: Complex Date Range Report with Multiple Aggregations
-- Problem: Function on indexed column (DATE()), no composite index
-- Expected issue: Can't use index, full table scan for date filtering

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


-- ADDITIONAL SLOW QUERY: Inventory Alert Report
-- Problem: Subquery in SELECT, no index on stock_quantity

SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    p.stock_quantity,
    p.reorder_level,
    (SELECT category_name FROM categories WHERE category_id = p.category_id) AS category,
    (SELECT SUM(quantity) FROM order_items WHERE product_id = p.product_id) AS total_sold,
    (SELECT COUNT(*) FROM order_items WHERE product_id = p.product_id) AS order_count
FROM products p
WHERE p.stock_quantity <= p.reorder_level
    AND p.is_active = 1
ORDER BY p.stock_quantity ASC;


-- View profiling results
SHOW PROFILES;

-- Get detailed profile for specific query (use query_id from SHOW PROFILES)
-- SHOW PROFILE FOR QUERY 1;

SELECT 'Original queries executed. Check SHOW PROFILES for execution times.' AS status;
