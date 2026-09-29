-- MySQL Performance Tuning - Index Definitions
-- These indexes are designed to optimize the slow queries identified
-- in the analysis phase.

USE ecommerce_perf;

-- CUSTOMERS TABLE INDEXES

-- Index for customer status filtering (Query 2)
-- Helps filter active customers efficiently
CREATE INDEX idx_customers_status 
ON customers(customer_status);

-- Index for registration date ordering (Query 4)
CREATE INDEX idx_customers_reg_date 
ON customers(registration_date DESC);

-- Composite index for status + registration date
CREATE INDEX idx_customers_status_regdate 
ON customers(customer_status, registration_date DESC);

-- FULLTEXT index for text search (Query 4)
-- Enables fast text search without leading wildcard issues
ALTER TABLE customers 
ADD FULLTEXT INDEX ft_customers_search (first_name, last_name, email, city);

-- Individual indexes for LIKE prefix searches (alternative to FULLTEXT)
CREATE INDEX idx_customers_firstname 
ON customers(first_name);

CREATE INDEX idx_customers_lastname 
ON customers(last_name);

CREATE INDEX idx_customers_city 
ON customers(city);


-- ORDERS TABLE INDEXES

-- Index for customer_id (JOIN optimization - Query 1, 2)
-- Critical for customer-order joins
CREATE INDEX idx_orders_customer_id 
ON orders(customer_id);

-- Index for order_date (Query 1, 5)
-- Essential for date-based filtering and reporting
CREATE INDEX idx_orders_order_date 
ON orders(order_date);

-- Composite index for order_date range queries (Query 5)
-- Includes commonly selected columns for covering index benefit
CREATE INDEX idx_orders_date_status 
ON orders(order_date, order_status);

-- Composite index for customer + date (customer order history)
CREATE INDEX idx_orders_customer_date 
ON orders(customer_id, order_date DESC);

-- Index for order status filtering
CREATE INDEX idx_orders_status 
ON orders(order_status);

-- Composite covering index for daily reports
CREATE INDEX idx_orders_daily_report 
ON orders(order_date, customer_id, total_amount, order_status, payment_method);


-- ORDER_ITEMS TABLE INDEXES

-- Index for order_id (JOIN optimization - Query 1)
CREATE INDEX idx_orderitems_order_id 
ON order_items(order_id);

-- Index for product_id (JOIN optimization - Query 3)
CREATE INDEX idx_orderitems_product_id 
ON order_items(product_id);

-- Composite index for order-product joins
-- Covers common join patterns
CREATE INDEX idx_orderitems_order_product 
ON order_items(order_id, product_id);

-- Covering index for aggregations
CREATE INDEX idx_orderitems_product_agg 
ON order_items(product_id, quantity, line_total);


-- PRODUCTS TABLE INDEXES

-- Index for category_id (JOIN optimization - Query 3)
CREATE INDEX idx_products_category_id 
ON products(category_id);

-- Composite index for active products by category
CREATE INDEX idx_products_category_active 
ON products(category_id, is_active);

-- Index for inventory alerts (stock monitoring)
CREATE INDEX idx_products_stock 
ON products(stock_quantity, reorder_level);

-- Composite index for active product filtering
CREATE INDEX idx_products_active_category 
ON products(is_active, category_id);

-- Index for SKU lookups
CREATE INDEX idx_products_sku 
ON products(sku);


-- CATEGORIES TABLE INDEXES

-- Index for category hierarchy
CREATE INDEX idx_categories_parent 
ON categories(parent_category_id);


-- SALES_SUMMARY TABLE INDEXES (for denormalized reporting)

-- Composite index for date-based reports
CREATE INDEX idx_sales_summary_date 
ON sales_summary(summary_date);

-- Composite index for category reports
CREATE INDEX idx_sales_summary_category_date 
ON sales_summary(category_id, summary_date);

-- Composite index for product reports
CREATE INDEX idx_sales_summary_product_date 
ON sales_summary(product_id, summary_date);


-- VERIFY INDEXES

SELECT '=== INDEX VERIFICATION ===' AS status;

-- Show all indexes on each table
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns,
    INDEX_TYPE,
    CASE WHEN NON_UNIQUE = 0 THEN 'UNIQUE' ELSE 'NON-UNIQUE' END AS uniqueness
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'ecommerce_perf'
GROUP BY TABLE_NAME, INDEX_NAME, INDEX_TYPE, NON_UNIQUE
ORDER BY TABLE_NAME, INDEX_NAME;


-- ANALYZE TABLES AFTER INDEX CREATION

ANALYZE TABLE customers;
ANALYZE TABLE orders;
ANALYZE TABLE order_items;
ANALYZE TABLE products;
ANALYZE TABLE categories;
ANALYZE TABLE sales_summary;

SELECT 'Index creation complete. Run EXPLAIN on queries to verify index usage.' AS status;


-- INDEX MAINTENANCE NOTES
/*
Index Maintenance Best Practices:

1. ANALYZE TABLE regularly to update statistics
   ANALYZE TABLE table_name;

2. Check for unused indexes periodically:
   SELECT * FROM sys.schema_unused_indexes;

3. Monitor index size:
   SELECT 
       TABLE_NAME,
       INDEX_NAME,
       ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 2) AS size_mb
   FROM mysql.innodb_index_stats
   WHERE stat_name = 'size'
   ORDER BY stat_value DESC;

4. Consider index cardinality:
   SHOW INDEX FROM table_name;

5. For very large tables, consider:
   - Partitioning by date
   - Summary tables for reporting
   - Materialized views (MySQL 8.0+)
*/
