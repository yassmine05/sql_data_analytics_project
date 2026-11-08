/*
===============================================================================
Step 05 - Magnitude Analysis
===============================================================================
Goal:
    Compare the size of each group: measures (from the fact) broken down by
    dimensions (customers, products).

Star schema joins used here:
    gold.fact_sales.customer_key -> gold.dim_customers.customer_key
    gold.fact_sales.product_key  -> gold.dim_products.product_key
LEFT JOIN from the fact keeps every sale even if a dimension row is missing.

Techniques: GROUP BY, SUM, COUNT, AVG, joins across the star schema
===============================================================================
*/

USE DataWarehouse;
GO

-- -----------------------------------------------------------------------------
-- Dimension-only counts
-- -----------------------------------------------------------------------------

-- 1. Customers by country and by gender in one grid
SELECT
    country,
    COUNT(*)                                                   AS total_customers,
    SUM(CASE WHEN gender = 'Female' THEN 1 ELSE 0 END)         AS female,
    SUM(CASE WHEN gender = 'Male'   THEN 1 ELSE 0 END)         AS male,
    SUM(CASE WHEN gender = 'n/a'    THEN 1 ELSE 0 END)         AS gender_unknown
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;

-- 2. Products per category, with their average and max cost
SELECT
    category,
    COUNT(*)  AS total_products,
    AVG(cost) AS avg_cost,
    MAX(cost) AS max_cost
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;

-- -----------------------------------------------------------------------------
-- Measures by dimension (fact + dimension)
-- -----------------------------------------------------------------------------

-- 3. Revenue, quantity and orders per category
SELECT
    p.category,
    SUM(f.sales_amount)            AS total_sales,
    SUM(f.quantity)                AS total_quantity,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY total_sales DESC;

-- 4. Revenue per subcategory inside each category
SELECT
    p.category,
    p.subcategory,
    SUM(f.sales_amount) AS total_sales,
    SUM(f.quantity)     AS total_quantity
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.category, p.subcategory
ORDER BY p.category, total_sales DESC;

-- 5. Revenue and buyers per country
SELECT
    c.country,
    SUM(f.sales_amount)            AS total_sales,
    COUNT(DISTINCT f.customer_key) AS buying_customers,
    SUM(f.sales_amount) / COUNT(DISTINCT f.customer_key) AS sales_per_customer
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY c.country
ORDER BY total_sales DESC;

-- 6. Items sold by marital status and gender
SELECT
    c.marital_status,
    c.gender,
    SUM(f.quantity)     AS total_quantity,
    SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY c.marital_status, c.gender
ORDER BY c.marital_status, c.gender;

-- 7. Revenue per product line
SELECT
    p.product_line,
    SUM(f.sales_amount) AS total_sales,
    SUM(f.quantity)     AS total_quantity
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.product_line
ORDER BY total_sales DESC;
