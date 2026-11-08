/*
===============================================================================
Step 04 - Measures Exploration (key business numbers)
===============================================================================
Goal:
    Calculate the headline KPIs of the business in one place.

Measures live in the fact table (gold.fact_sales):
    sales_amount, quantity, price
Important detail about the grain: one row in fact_sales is one ORDER LINE,
not one order. An order (order_number) can contain several products, so
orders must be counted with COUNT(DISTINCT order_number).

Techniques: SUM, AVG, COUNT, COUNT(DISTINCT), UNION ALL
===============================================================================
*/

USE DataWarehouse;
GO

-- 1. Each KPI on its own
SELECT SUM(sales_amount)            AS total_sales       FROM gold.fact_sales;
SELECT SUM(quantity)                AS total_items_sold  FROM gold.fact_sales;
SELECT AVG(CAST(price AS DECIMAL(10,2))) AS avg_selling_price FROM gold.fact_sales;
SELECT COUNT(DISTINCT order_number) AS total_orders      FROM gold.fact_sales;
SELECT COUNT(*)                     AS total_order_lines FROM gold.fact_sales;

-- 2. One summary report of all key metrics (easy to read or export)
SELECT 'Total sales'                 AS measure, CAST(SUM(sales_amount) AS DECIMAL(18,2)) AS value FROM gold.fact_sales
UNION ALL
SELECT 'Total items sold',            SUM(quantity)                                        FROM gold.fact_sales
UNION ALL
SELECT 'Average selling price',       AVG(CAST(price AS DECIMAL(18,2)))                    FROM gold.fact_sales
UNION ALL
SELECT 'Total orders',                COUNT(DISTINCT order_number)                         FROM gold.fact_sales
UNION ALL
SELECT 'Total order lines',           COUNT(*)                                             FROM gold.fact_sales
UNION ALL
SELECT 'Average order value',         CAST(SUM(sales_amount) AS DECIMAL(18,2)) / COUNT(DISTINCT order_number) FROM gold.fact_sales
UNION ALL
SELECT 'Products in catalog',         COUNT(product_key)                                   FROM gold.dim_products
UNION ALL
SELECT 'Products sold at least once', COUNT(DISTINCT product_key)                          FROM gold.fact_sales
UNION ALL
SELECT 'Customers registered',        COUNT(customer_key)                                  FROM gold.dim_customers
UNION ALL
SELECT 'Customers who ordered',       COUNT(DISTINCT customer_key)                         FROM gold.fact_sales;

-- 3. Sanity check on the measures: sales should equal quantity x price
--    (the silver layer recalculated sales when this rule was broken)
SELECT
    COUNT(*) AS lines_where_sales_not_equal_qty_x_price
FROM gold.fact_sales
WHERE sales_amount <> quantity * price;
