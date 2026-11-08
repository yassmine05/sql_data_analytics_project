/*
===============================================================================
Step 09 - Performance Analysis (vs. average, vs. previous period)
===============================================================================
Goal:
    Judge each product's yearly sales against two benchmarks:
      1) its own average over all years
      2) the previous year (year-over-year change, in value and %)
    Then do the same month-over-month for the whole business.

Notes:
    Window calculations are done once in a CTE and reused, instead of
    repeating the same OVER() expression several times.

Techniques: LAG, AVG() OVER, PARTITION BY, CASE, NULLIF
===============================================================================
*/

USE DataWarehouse;
GO

-- 1. Yearly product performance
WITH yearly_product_sales AS (
    SELECT
        YEAR(f.order_date)  AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY YEAR(f.order_date), p.product_name
),
with_benchmarks AS (
    SELECT
        order_year,
        product_name,
        current_sales,
        AVG(current_sales) OVER (PARTITION BY product_name)                     AS avg_sales,
        LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS previous_year_sales
    FROM yearly_product_sales
)
SELECT
    order_year,
    product_name,
    current_sales,
    avg_sales,
    current_sales - avg_sales AS diff_vs_avg,
    CASE
        WHEN current_sales > avg_sales THEN 'Above average'
        WHEN current_sales < avg_sales THEN 'Below average'
        ELSE 'Average'
    END                       AS vs_avg,
    previous_year_sales,
    current_sales - previous_year_sales AS diff_vs_previous_year,
    CAST(100.0 * (current_sales - previous_year_sales)
         / NULLIF(previous_year_sales, 0) AS DECIMAL(10,1)) AS yoy_growth_pct,
    CASE
        WHEN previous_year_sales IS NULL          THEN 'First year'
        WHEN current_sales > previous_year_sales  THEN 'Increase'
        WHEN current_sales < previous_year_sales  THEN 'Decrease'
        ELSE 'No change'
    END                       AS vs_previous_year
FROM with_benchmarks
ORDER BY product_name, order_year;

-- 2. Year-over-year performance per category
WITH yearly_category AS (
    SELECT
        p.category,
        YEAR(f.order_date)  AS order_year,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY p.category, YEAR(f.order_date)
)
SELECT
    category,
    order_year,
    current_sales,
    LAG(current_sales) OVER (PARTITION BY category ORDER BY order_year) AS previous_year_sales,
    CAST(100.0 * (current_sales - LAG(current_sales) OVER (PARTITION BY category ORDER BY order_year))
         / NULLIF(LAG(current_sales) OVER (PARTITION BY category ORDER BY order_year), 0)
         AS DECIMAL(10,1))                                              AS yoy_growth_pct
FROM yearly_category
ORDER BY category, order_year;

-- 3. Month-over-month change for the whole business
WITH monthly AS (
    SELECT
        DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS order_month,
        SUM(sales_amount)                                     AS month_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
),
with_previous AS (
    SELECT
        order_month,
        month_sales,
        LAG(month_sales)     OVER (ORDER BY order_month) AS previous_month_sales,
        LAG(month_sales, 12) OVER (ORDER BY order_month) AS same_month_last_year
    FROM monthly
)
SELECT
    order_month,
    month_sales,
    previous_month_sales,
    CAST(100.0 * (month_sales - previous_month_sales)
         / NULLIF(previous_month_sales, 0) AS DECIMAL(10,1)) AS mom_growth_pct,
    same_month_last_year,
    CAST(100.0 * (month_sales - same_month_last_year)
         / NULLIF(same_month_last_year, 0) AS DECIMAL(10,1)) AS vs_same_month_last_year_pct
FROM with_previous
ORDER BY order_month;
