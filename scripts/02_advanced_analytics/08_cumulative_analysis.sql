/*
===============================================================================
Step 08 - Cumulative Analysis (running totals & moving averages)
===============================================================================
Goal:
    Show how the business grows over time: running total of revenue,
    running total that restarts each year, and a moving average that smooths
    out monthly noise.

Notes:
    Aggregate first (per month) in a CTE, then apply the window functions on
    the monthly results. ROWS BETWEEN makes the window frame explicit.

Techniques: SUM() OVER, AVG() OVER, ROWS BETWEEN, PARTITION BY
===============================================================================
*/

USE DataWarehouse;
GO

-- 1. Monthly sales with:
--    - running total over the whole history
--    - year-to-date running total (restarts every January)
--    - 3-month moving average of sales
WITH monthly_sales AS (
    SELECT
        DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS order_month,
        SUM(sales_amount)                                     AS month_sales,
        SUM(quantity)                                         AS month_quantity
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
)
SELECT
    order_month,
    month_sales,
    SUM(month_sales) OVER (ORDER BY order_month
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_sales,
    SUM(month_sales) OVER (PARTITION BY YEAR(order_month) ORDER BY order_month
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ytd_sales,
    AVG(month_sales) OVER (ORDER BY order_month
                           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)         AS moving_avg_3_months
FROM monthly_sales
ORDER BY order_month;

-- 2. Yearly running total and the average selling price trend
WITH yearly AS (
    SELECT
        YEAR(order_date)                    AS order_year,
        SUM(sales_amount)                   AS year_sales,
        AVG(CAST(price AS DECIMAL(10,2)))   AS avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(order_date)
)
SELECT
    order_year,
    year_sales,
    SUM(year_sales) OVER (ORDER BY order_year) AS running_total_sales,
    avg_price,
    AVG(avg_price)  OVER (ORDER BY order_year) AS running_avg_price
FROM yearly
ORDER BY order_year;

-- 3. Customer base growth: new customers per month (by first order)
--    and the cumulative number of customers acquired
WITH first_orders AS (
    SELECT
        customer_key,
        MIN(order_date) AS first_order_date
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY customer_key
),
new_per_month AS (
    SELECT
        DATEFROMPARTS(YEAR(first_order_date), MONTH(first_order_date), 1) AS first_order_month,
        COUNT(*)                                                          AS new_customers
    FROM first_orders
    GROUP BY DATEFROMPARTS(YEAR(first_order_date), MONTH(first_order_date), 1)
)
SELECT
    first_order_month,
    new_customers,
    SUM(new_customers) OVER (ORDER BY first_order_month) AS cumulative_customers
FROM new_per_month
ORDER BY first_order_month;
