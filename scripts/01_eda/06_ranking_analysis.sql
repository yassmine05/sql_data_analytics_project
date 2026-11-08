/*
===============================================================================
Step 06 - Ranking Analysis (top & bottom performers)
===============================================================================
Goal:
    Find the best and worst products and customers.

Notes:
    - TOP n is quick but returns a fixed number of rows even when there are
      ties. RANK() / DENSE_RANK() handle ties and work per group (PARTITION BY).
    - Products that were never sold do not appear in fact_sales at all, so
      they are found from the product dimension instead (query 5).

Techniques: TOP, RANK, DENSE_RANK, ROW_NUMBER, PARTITION BY, NOT EXISTS
===============================================================================
*/

USE DataWarehouse;
GO

-- 1. Top 5 products by revenue
SELECT TOP 5
    p.product_name,
    p.category,
    SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.product_name, p.category
ORDER BY total_sales DESC;

-- 2. Bottom 5 products by revenue (among products that sold)
SELECT TOP 5
    p.product_name,
    p.category,
    SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.product_name, p.category
ORDER BY total_sales ASC;

-- 3. Best 3 products inside EACH category (window function, handles ties)
WITH product_sales AS (
    SELECT
        p.category,
        p.product_name,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.category, p.product_name
),
ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY total_sales DESC) AS rank_in_category
    FROM product_sales
)
SELECT category, rank_in_category, product_name, total_sales
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- 4. Top 10 customers by revenue, and the 3 customers with the fewest orders
WITH customer_stats AS (
    SELECT
        c.customer_key,
        c.first_name,
        c.last_name,
        c.country,
        SUM(f.sales_amount)            AS total_sales,
        COUNT(DISTINCT f.order_number) AS total_orders
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    GROUP BY c.customer_key, c.first_name, c.last_name, c.country
)
SELECT *
FROM (
    SELECT
        'Top 10 by revenue' AS list_name,
        RANK() OVER (ORDER BY total_sales DESC) AS position,
        customer_key, first_name, last_name, country, total_sales, total_orders
    FROM customer_stats
) t
WHERE position <= 10
UNION ALL
SELECT *
FROM (
    SELECT
        'Fewest orders' AS list_name,
        ROW_NUMBER() OVER (ORDER BY total_orders ASC, total_sales ASC) AS position,
        customer_key, first_name, last_name, country, total_sales, total_orders
    FROM customer_stats
) b
WHERE position <= 3
ORDER BY list_name DESC, position;

-- 5. Products in the catalog that were never sold
SELECT
    p.product_key,
    p.product_name,
    p.category,
    p.subcategory,
    p.cost
FROM gold.dim_products p
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.fact_sales f
    WHERE f.product_key = p.product_key
)
ORDER BY p.category, p.product_name;
