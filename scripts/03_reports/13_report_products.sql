/*
===============================================================================
Step 13 - Product Report (view: gold.report_products)
===============================================================================
Goal:
    One row per product that has been sold, with:
      - descriptive fields: name, category, subcategory, product line, cost
      - metrics: orders, sales, quantity, unique customers, lifespan
      - KPIs: recency, average order revenue, average monthly revenue,
              average selling price, gross margin (sales - cost x quantity)
      - performance segment: High / Mid / Low performer

Design choices:
    - Reference date = last order date in the data (see step 03).
    - Performance segment is RELATIVE: products are split into three equal
      groups by revenue with NTILE(3), instead of fixed money thresholds.
    - Margin uses the current product cost from dim_products, so it is an
      estimate (historical costs are not kept in the gold layer).
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER VIEW gold.report_products AS
WITH ref_date AS (
    SELECT MAX(order_date) AS ref_date
    FROM gold.fact_sales
),
base AS (
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        f.price,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.product_line,
        p.cost
    FROM gold.fact_sales f
    INNER JOIN gold.dim_products p
        ON p.product_key = f.product_key
    WHERE f.order_date IS NOT NULL
),
product_agg AS (
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        product_line,
        cost,
        COUNT(DISTINCT order_number)                      AS total_orders,
        COUNT(DISTINCT customer_key)                      AS total_customers,
        SUM(sales_amount)                                 AS total_sales,
        SUM(quantity)                                     AS total_quantity,
        AVG(CAST(price AS DECIMAL(10,2)))                 AS avg_selling_price,
        MIN(order_date)                                   AS first_sale_date,
        MAX(order_date)                                   AS last_sale_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months
    FROM base
    GROUP BY product_key, product_name, category, subcategory, product_line, cost
)
SELECT
    a.product_key,
    a.product_name,
    a.category,
    a.subcategory,
    a.product_line,
    a.cost,
    a.first_sale_date,
    a.last_sale_date,
    DATEDIFF(MONTH, a.last_sale_date, r.ref_date)            AS recency_months,
    CASE NTILE(3) OVER (ORDER BY a.total_sales DESC)
        WHEN 1 THEN 'High performer'
        WHEN 2 THEN 'Mid performer'
        ELSE        'Low performer'
    END                                                      AS performance_segment,
    a.lifespan_months,
    a.total_orders,
    a.total_customers,
    a.total_sales,
    a.total_quantity,
    a.avg_selling_price,
    a.total_sales - a.cost * a.total_quantity                AS estimated_margin,
    CAST(100.0 * (a.total_sales - a.cost * a.total_quantity)
         / NULLIF(a.total_sales, 0) AS DECIMAL(5,1))         AS estimated_margin_pct,
    -- average order revenue: revenue per order containing the product
    CAST(1.0 * a.total_sales / NULLIF(a.total_orders, 0) AS DECIMAL(10,2)) AS avg_order_revenue,
    -- average monthly revenue over the product's selling life
    CAST(CASE WHEN a.lifespan_months = 0 THEN a.total_sales
              ELSE 1.0 * a.total_sales / a.lifespan_months END AS DECIMAL(12,2)) AS avg_monthly_revenue
FROM product_agg a
CROSS JOIN ref_date r;
GO

-- Quick checks
SELECT * FROM gold.report_products ORDER BY total_sales DESC;

SELECT
    category,
    performance_segment,
    COUNT(*)              AS nb_products,
    SUM(total_sales)      AS total_sales,
    SUM(estimated_margin) AS estimated_margin
FROM gold.report_products
GROUP BY category, performance_segment
ORDER BY category, performance_segment;
