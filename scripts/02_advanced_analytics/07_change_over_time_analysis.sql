/*
===============================================================================
Step 07 - Change Over Time (trends)
===============================================================================
Goal:
    See how sales evolve by year and by month, and whether there is
    seasonality.

Notes:
    - Rows with a NULL order_date (invalid dates cleaned in the silver layer)
      are excluded.
    - The first month (Dec 2010) and the last month (Jan 2014) are only
      partially covered, so treat them carefully when comparing.

Techniques: YEAR, MONTH, DATEFROMPARTS, DATENAME, conditional aggregation
===============================================================================
*/

USE DataWarehouse;
GO

-- 1. Yearly trend: revenue, customers and items sold
SELECT
    YEAR(order_date)               AS order_year,
    SUM(sales_amount)              AS total_sales,
    COUNT(DISTINCT customer_key)   AS active_customers,
    COUNT(DISTINCT order_number)   AS total_orders,
    SUM(quantity)                  AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY order_year;

-- 2. Monthly trend over the full history
--    DATEFROMPARTS gives a real DATE (first day of the month), so the result
--    sorts correctly and can be used in charts.
SELECT
    DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS order_month,
    SUM(sales_amount)              AS total_sales,
    COUNT(DISTINCT customer_key)   AS active_customers,
    SUM(quantity)                  AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
ORDER BY order_month;

-- 3. Seasonality: average revenue per calendar month across all years
--    (only complete years 2011-2013 are used so partial months don't bias it)
WITH monthly AS (
    SELECT
        YEAR(order_date)  AS order_year,
        MONTH(order_date) AS month_number,
        SUM(sales_amount) AS month_sales
    FROM gold.fact_sales
    WHERE order_date >= '2011-01-01' AND order_date < '2014-01-01'
    GROUP BY YEAR(order_date), MONTH(order_date)
)
SELECT
    month_number,
    DATENAME(MONTH, DATEFROMPARTS(2000, month_number, 1)) AS month_name,
    AVG(month_sales)                                      AS avg_monthly_sales,
    MIN(month_sales)                                      AS lowest_year,
    MAX(month_sales)                                      AS highest_year
FROM monthly
GROUP BY month_number
ORDER BY month_number;

-- 4. Year x category matrix: which categories drive the growth?
SELECT
    p.category,
    SUM(CASE WHEN YEAR(f.order_date) = 2011 THEN f.sales_amount ELSE 0 END) AS sales_2011,
    SUM(CASE WHEN YEAR(f.order_date) = 2012 THEN f.sales_amount ELSE 0 END) AS sales_2012,
    SUM(CASE WHEN YEAR(f.order_date) = 2013 THEN f.sales_amount ELSE 0 END) AS sales_2013
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY sales_2013 DESC;
