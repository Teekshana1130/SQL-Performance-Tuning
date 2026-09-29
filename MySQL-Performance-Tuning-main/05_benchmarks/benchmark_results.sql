-- MySQL Performance Tuning - Benchmark Execution Scripts
-- This script runs both original and optimized queries to measure performance.
-- Ideally run this after database is warmed up (run each query once first).

USE ecommerce_perf;

SET profiling = 1;

-- BENCHMARK 1: Monthly Sales Aggregation
SELECT 'BENCHMARK 1 START' AS status;

-- Original Query
SELECT SQL_NO_CACHE *
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN categories cat ON p.category_id = cat.category_id
WHERE YEAR(o.order_date) = 2025 AND MONTH(o.order_date) = 6
ORDER BY o.order_date DESC
LIMIT 1; -- Limit to avoid huge output during benchmark

-- Optimized Query
SELECT SQL_NO_CACHE 
    o.order_id, o.order_date, c.first_name, oi.line_total
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
INNER JOIN categories cat ON p.category_id = cat.category_id
WHERE o.order_date >= '2025-06-01' AND o.order_date < '2025-07-01'
ORDER BY o.order_date DESC
LIMIT 1;

-- BENCHMARK 2: Customer Purchase History
SELECT 'BENCHMARK 2 START' AS status;

-- Original Query
SELECT SQL_NO_CACHE 
    c.customer_id,
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS total_orders
FROM customers c
WHERE c.customer_status = 'active'
ORDER BY total_orders DESC
LIMIT 10;

-- Optimized Query
SELECT SQL_NO_CACHE 
    c.customer_id,
    COUNT(o.order_id) AS total_orders
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE c.customer_status = 'active'
GROUP BY c.customer_id
ORDER BY total_orders DESC
LIMIT 10;

-- BENCHMARK 3: Customer Search
SELECT 'BENCHMARK 3 START' AS status;

-- Original Query (LIKE)
SELECT SQL_NO_CACHE c.customer_id, c.email
FROM customers c
WHERE c.first_name LIKE '%john%' OR c.last_name LIKE '%smith%'
LIMIT 10;

-- Optimized Query (FULLTEXT)
SELECT SQL_NO_CACHE c.customer_id, c.email
FROM customers c
WHERE MATCH(c.first_name, c.last_name, c.email, c.city) 
      AGAINST ('john smith' IN NATURAL LANGUAGE MODE)
LIMIT 10;

-- CAPTURE RESULTS
SHOW PROFILES;

SELECT 
    query_id, 
    ROUND(duration, 4) as duration_sec, 
    source_function 
FROM information_schema.profiling 
ORDER BY query_id DESC 
LIMIT 10;
