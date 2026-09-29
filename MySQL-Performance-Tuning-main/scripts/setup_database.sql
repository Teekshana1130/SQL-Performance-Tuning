-- MySQL Performance Tuning - Database Setup Script
-- This script creates a sample e-commerce database with large tables
-- for testing query optimization techniques.

-- Create and select the database
DROP DATABASE IF EXISTS ecommerce_perf;
CREATE DATABASE ecommerce_perf CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_perf;

-- TABLE DEFINITIONS

-- Categories table
CREATE TABLE categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(100) NOT NULL,
    parent_category_id INT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_parent (parent_category_id)
) ENGINE=InnoDB;

-- Customers table (100,000 rows target)
CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    country VARCHAR(50) DEFAULT 'USA',
    zip_code VARCHAR(20),
    registration_date DATE NOT NULL,
    customer_status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Products table (10,000 rows target)
CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(200) NOT NULL,
    sku VARCHAR(50) NOT NULL,
    category_id INT NOT NULL,
    description TEXT,
    unit_price DECIMAL(10, 2) NOT NULL,
    cost_price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    reorder_level INT DEFAULT 10,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
) ENGINE=InnoDB;

-- Orders table (1,000,000 rows target)
CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    order_date DATETIME NOT NULL,
    ship_date DATETIME,
    order_status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    payment_method ENUM('credit_card', 'debit_card', 'paypal', 'bank_transfer', 'cash') NOT NULL,
    shipping_address VARCHAR(255),
    shipping_city VARCHAR(100),
    shipping_state VARCHAR(50),
    shipping_country VARCHAR(50) DEFAULT 'USA',
    shipping_zip VARCHAR(20),
    subtotal DECIMAL(12, 2) NOT NULL,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    shipping_cost DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(12, 2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;

-- Order Items table (5,000,000 rows target)
CREATE TABLE order_items (
    item_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    line_total DECIMAL(12, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;

-- Sales Summary table (for reporting - denormalized)
CREATE TABLE sales_summary (
    summary_id INT PRIMARY KEY AUTO_INCREMENT,
    summary_date DATE NOT NULL,
    category_id INT,
    product_id INT,
    total_orders INT DEFAULT 0,
    total_quantity INT DEFAULT 0,
    total_revenue DECIMAL(15, 2) DEFAULT 0,
    total_cost DECIMAL(15, 2) DEFAULT 0,
    gross_profit DECIMAL(15, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;

-- DATA GENERATION PROCEDURES

DELIMITER //

-- Procedure to generate categories
CREATE PROCEDURE generate_categories()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 100 DO
        INSERT INTO categories (category_name, parent_category_id, description)
        VALUES (
            CONCAT('Category ', i),
            IF(i <= 10, NULL, FLOOR(1 + RAND() * 10)),
            CONCAT('Description for category ', i)
        );
        SET i = i + 1;
    END WHILE;
END //

-- Procedure to generate customers
CREATE PROCEDURE generate_customers(IN num_customers INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE first_names VARCHAR(500) DEFAULT 'John,Jane,Michael,Emily,David,Sarah,James,Emma,Robert,Olivia,William,Sophia,Joseph,Isabella,Charles,Mia,Thomas,Charlotte,Daniel,Amelia';
    DECLARE last_names VARCHAR(500) DEFAULT 'Smith,Johnson,Williams,Brown,Jones,Garcia,Miller,Davis,Rodriguez,Martinez,Hernandez,Lopez,Gonzalez,Wilson,Anderson,Thomas,Taylor,Moore,Jackson,Martin';
    DECLARE cities VARCHAR(500) DEFAULT 'New York,Los Angeles,Chicago,Houston,Phoenix,Philadelphia,San Antonio,San Diego,Dallas,San Jose,Austin,Jacksonville,Fort Worth,Columbus,Charlotte,Seattle,Denver,Boston,Detroit,Portland';
    DECLARE states VARCHAR(200) DEFAULT 'NY,CA,IL,TX,AZ,PA,TX,CA,TX,CA,TX,FL,TX,OH,NC,WA,CO,MA,MI,OR';
    
    WHILE i <= num_customers DO
        INSERT INTO customers (first_name, last_name, email, phone, address, city, state, zip_code, registration_date, customer_status)
        VALUES (
            SUBSTRING_INDEX(SUBSTRING_INDEX(first_names, ',', 1 + FLOOR(RAND() * 20)), ',', -1),
            SUBSTRING_INDEX(SUBSTRING_INDEX(last_names, ',', 1 + FLOOR(RAND() * 20)), ',', -1),
            CONCAT('customer', i, '@example.com'),
            CONCAT('555-', LPAD(FLOOR(RAND() * 10000), 4, '0')),
            CONCAT(FLOOR(100 + RAND() * 9900), ' Main Street'),
            SUBSTRING_INDEX(SUBSTRING_INDEX(cities, ',', 1 + FLOOR(RAND() * 20)), ',', -1),
            SUBSTRING_INDEX(SUBSTRING_INDEX(states, ',', 1 + FLOOR(RAND() * 20)), ',', -1),
            LPAD(FLOOR(10000 + RAND() * 90000), 5, '0'),
            DATE_SUB(CURDATE(), INTERVAL FLOOR(RAND() * 1825) DAY),
            ELT(1 + FLOOR(RAND() * 3), 'active', 'inactive', 'suspended')
        );
        SET i = i + 1;
        
        -- Commit every 10000 rows for better performance
        IF i MOD 10000 = 0 THEN
            COMMIT;
        END IF;
    END WHILE;
END //

-- Procedure to generate products
CREATE PROCEDURE generate_products(IN num_products INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    
    WHILE i <= num_products DO
        INSERT INTO products (product_name, sku, category_id, description, unit_price, cost_price, stock_quantity, reorder_level, is_active)
        VALUES (
            CONCAT('Product ', i, ' - ', SUBSTRING(MD5(RAND()), 1, 8)),
            CONCAT('SKU-', LPAD(i, 6, '0')),
            1 + FLOOR(RAND() * 100),
            CONCAT('Detailed description for product ', i, '. This product offers excellent quality and value.'),
            ROUND(10 + RAND() * 990, 2),
            ROUND(5 + RAND() * 495, 2),
            FLOOR(RAND() * 1000),
            FLOOR(5 + RAND() * 50),
            IF(RAND() > 0.1, TRUE, FALSE)
        );
        SET i = i + 1;
    END WHILE;
END //

-- Procedure to generate orders
CREATE PROCEDURE generate_orders(IN num_orders INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE v_customer_id INT;
    DECLARE v_order_date DATETIME;
    DECLARE v_subtotal DECIMAL(12, 2);
    DECLARE v_tax DECIMAL(10, 2);
    DECLARE v_shipping DECIMAL(10, 2);
    
    WHILE i <= num_orders DO
        SET v_customer_id = 1 + FLOOR(RAND() * 100000);
        SET v_order_date = DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 730) DAY);
        SET v_subtotal = ROUND(50 + RAND() * 950, 2);
        SET v_tax = ROUND(v_subtotal * 0.08, 2);
        SET v_shipping = ROUND(5 + RAND() * 25, 2);
        
        INSERT INTO orders (customer_id, order_date, ship_date, order_status, payment_method, 
                           shipping_address, shipping_city, shipping_state, shipping_country, shipping_zip,
                           subtotal, tax_amount, shipping_cost, total_amount)
        VALUES (
            v_customer_id,
            v_order_date,
            IF(RAND() > 0.2, DATE_ADD(v_order_date, INTERVAL FLOOR(1 + RAND() * 7) DAY), NULL),
            ELT(1 + FLOOR(RAND() * 5), 'pending', 'processing', 'shipped', 'delivered', 'cancelled'),
            ELT(1 + FLOOR(RAND() * 5), 'credit_card', 'debit_card', 'paypal', 'bank_transfer', 'cash'),
            CONCAT(FLOOR(100 + RAND() * 9900), ' Shipping Ave'),
            ELT(1 + FLOOR(RAND() * 10), 'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose'),
            ELT(1 + FLOOR(RAND() * 10), 'NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'TX', 'CA', 'TX', 'CA'),
            'USA',
            LPAD(FLOOR(10000 + RAND() * 90000), 5, '0'),
            v_subtotal,
            v_tax,
            v_shipping,
            v_subtotal + v_tax + v_shipping
        );
        
        SET i = i + 1;
        
        -- Commit every 50000 rows
        IF i MOD 50000 = 0 THEN
            COMMIT;
            SELECT CONCAT('Generated ', i, ' orders...') AS progress;
        END IF;
    END WHILE;
END //

-- Procedure to generate order items
CREATE PROCEDURE generate_order_items()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_order_id INT;
    DECLARE v_num_items INT;
    DECLARE i INT;
    DECLARE v_product_id INT;
    DECLARE v_quantity INT;
    DECLARE v_unit_price DECIMAL(10, 2);
    DECLARE v_discount DECIMAL(5, 2);
    DECLARE counter INT DEFAULT 0;
    
    DECLARE order_cursor CURSOR FOR SELECT order_id FROM orders;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN order_cursor;
    
    order_loop: LOOP
        FETCH order_cursor INTO v_order_id;
        IF done THEN
            LEAVE order_loop;
        END IF;
        
        SET v_num_items = 1 + FLOOR(RAND() * 5);
        SET i = 1;
        
        WHILE i <= v_num_items DO
            SET v_product_id = 1 + FLOOR(RAND() * 10000);
            SET v_quantity = 1 + FLOOR(RAND() * 5);
            SET v_unit_price = ROUND(10 + RAND() * 200, 2);
            SET v_discount = IF(RAND() > 0.7, ROUND(RAND() * 20, 2), 0);
            
            INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_percent, line_total)
            VALUES (
                v_order_id,
                v_product_id,
                v_quantity,
                v_unit_price,
                v_discount,
                ROUND(v_quantity * v_unit_price * (1 - v_discount / 100), 2)
            );
            
            SET i = i + 1;
        END WHILE;
        
        SET counter = counter + 1;
        IF counter MOD 50000 = 0 THEN
            COMMIT;
            SELECT CONCAT('Processed ', counter, ' orders for items...') AS progress;
        END IF;
    END LOOP;
    
    CLOSE order_cursor;
END //

DELIMITER ;

-- GENERATE SAMPLE DATA

-- Note: For testing, you can reduce the numbers below
-- Full dataset: 100k customers, 10k products, 1M orders, ~5M order items

SELECT 'Starting data generation...' AS status;
SELECT NOW() AS start_time;

-- Generate categories
CALL generate_categories();
SELECT 'Categories generated: 100 rows' AS status;

-- Generate customers (reduce for faster testing)
-- Use 100000 for full dataset, 10000 for quick testing
CALL generate_customers(100000);
SELECT 'Customers generated: 100,000 rows' AS status;

-- Generate products
CALL generate_products(10000);
SELECT 'Products generated: 10,000 rows' AS status;

-- Generate orders (reduce for faster testing)
-- Use 1000000 for full dataset, 100000 for quick testing
CALL generate_orders(1000000);
SELECT 'Orders generated: 1,000,000 rows' AS status;

-- Generate order items
CALL generate_order_items();
SELECT 'Order items generated: ~5,000,000 rows' AS status;

SELECT NOW() AS end_time;
SELECT 'Data generation complete!' AS status;

-- VERIFY DATA


SELECT 'Table row counts:' AS info;
SELECT 'categories' AS table_name, COUNT(*) AS row_count FROM categories
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;

-- ANALYZE TABLES

ANALYZE TABLE categories, customers, products, orders, order_items;

SELECT 'Setup complete! Database is ready for query optimization testing.' AS status;
