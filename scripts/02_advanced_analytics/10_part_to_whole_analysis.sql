/*
===============================================================================
Step 10 - Part-to-Whole Analysis (proportions)
===============================================================================
Goal:
    Find out how much each group contributes to the total, e.g. which
    categories or countries make up most of the revenue.

Notes:
    SUM(...) OVER () with an empty window gives the grand total on every row,
    so the percentage can be calculated without a second query.
    Multiply by 100.0 (not 100) to avoid integer division.

Techniques: SUM() OVER (), percentage of total, cumulative share (Pareto)
===============================================================================
*/

USE DataWarehouse;
GO

-- 1. Share of revenue by category
WITH category_sales AS (
    SELECT
        p.category,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.category
)
SELECT
    category,
    total_sales,
    SUM(total_sales) OVER ()                                         AS overall_sales,
    CAST(100.0 * total_sales / SUM(total_sales) OVER () AS DECIMAL(5,2)) AS pct_of_total
FROM category_sales
ORDER BY total_sales DESC;

-- 2. Share of revenue and of customers by country
--    (does a country bring more revenue than its share of customers?)
WITH country_stats AS (
    SELECT
        c.country,
        SUM(f.sales_amount)            AS total_sales,
        COUNT(DISTINCT f.customer_key) AS buying_customers
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    GROUP BY c.country
)
SELECT
    country,
    total_sales,
    CAST(100.0 * total_sales      / SUM(total_sales)      OVER () AS DECIMAL(5,2)) AS pct_of_sales,
    buying_customers,
    CAST(100.0 * buying_customers / SUM(buying_customers) OVER () AS DECIMAL(5,2)) AS pct_of_customers
FROM country_stats
ORDER BY total_sales DESC;

-- 3. Subcategory share inside its own category
WITH subcategory_sales AS (
    SELECT
        p.category,
        p.subcategory,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.category, p.subcategory
)
SELECT
    category,
    subcategory,
    total_sales,
    CAST(100.0 * total_sales / SUM(total_sales) OVER (PARTITION BY category) AS DECIMAL(5,2)) AS pct_of_category,
    CAST(100.0 * total_sales / SUM(total_sales) OVER ()                      AS DECIMAL(5,2)) AS pct_of_total
FROM subcategory_sales
ORDER BY category, total_sales DESC;

-- 4. Pareto check: how many products make up 80% of revenue?
WITH product_sales AS (
    SELECT
        f.product_key,
        p.product_name,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY f.product_key, p.product_name
),
cumulative AS (
    SELECT
        product_name,
        total_sales,
        ROW_NUMBER() OVER (ORDER BY total_sales DESC, product_key) AS sales_rank,
        CAST(100.0 * SUM(total_sales) OVER (ORDER BY total_sales DESC, product_key
                                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(total_sales) OVER () AS DECIMAL(5,2)) AS cumulative_pct
    FROM product_sales
)
SELECT
    sales_rank,
    product_name,
    total_sales,
    cumulative_pct,
    CASE WHEN cumulative_pct <= 80 THEN 'Top 80% of revenue' ELSE 'Remaining 20%' END AS pareto_group
FROM cumulative
ORDER BY sales_rank;
