/*
===============================================================================
Step 12 - Customer Report (view: gold.report_customers)
===============================================================================
Goal:
    One row per customer with everything needed for reporting / BI tools:
      - who they are: name, country, gender, age, age group
      - what they did: orders, sales, quantity, distinct products, lifespan
      - KPIs: recency, average order value, average monthly spend
      - segment: VIP / Regular / New (same rules as step 11)

Design choices:
    - Reference date = last order date in the data (January 2014), so
      recency and age are meaningful for this historical dataset.
    - Only customers who placed at least one order are included.
    - CREATE OR ALTER replaces the view if it already exists
      (requires SQL Server 2016 SP1 or later).

Structure:
    ref_date     -> the reference date
    base         -> fact lines joined to the customer dimension
    customer_agg -> one row per customer with the aggregated metrics
    final SELECT -> segments and KPIs
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER VIEW gold.report_customers AS
WITH ref_date AS (
    SELECT MAX(order_date) AS ref_date
    FROM gold.fact_sales
),
base AS (
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.country,
        c.gender,
        c.birthdate
    FROM gold.fact_sales f
    INNER JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL
),
customer_agg AS (
    SELECT
        customer_key,
        customer_number,
        customer_name,
        country,
        gender,
        birthdate,
        COUNT(DISTINCT order_number)                      AS total_orders,
        SUM(sales_amount)                                 AS total_sales,
        SUM(quantity)                                     AS total_quantity,
        COUNT(DISTINCT product_key)                       AS total_products,
        MIN(order_date)                                   AS first_order_date,
        MAX(order_date)                                   AS last_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months
    FROM base
    GROUP BY customer_key, customer_number, customer_name, country, gender, birthdate
),
with_age AS (
    SELECT
        a.*,
        r.ref_date,
        DATEDIFF(YEAR, a.birthdate, r.ref_date)
          - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, a.birthdate, r.ref_date), a.birthdate) > r.ref_date
                 THEN 1 ELSE 0 END AS age
    FROM customer_agg a
    CROSS JOIN ref_date r
)
SELECT
    customer_key,
    customer_number,
    customer_name,
    country,
    gender,
    age,
    CASE
        WHEN age IS NULL THEN 'Unknown'
        WHEN age < 30    THEN 'Under 30'
        WHEN age < 40    THEN '30-39'
        WHEN age < 50    THEN '40-49'
        WHEN age < 60    THEN '50-59'
        ELSE                  '60 and over'
    END                                                     AS age_group,
    CASE
        WHEN lifespan_months >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan_months >= 12                        THEN 'Regular'
        ELSE                                                   'New'
    END                                                     AS customer_segment,
    first_order_date,
    last_order_date,
    DATEDIFF(MONTH, last_order_date, ref_date)              AS recency_months,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan_months,
    -- average order value: revenue per order
    CAST(1.0 * total_sales / NULLIF(total_orders, 0) AS DECIMAL(10,2)) AS avg_order_value,
    -- average monthly spend: a one-month customer spends everything in that month
    CAST(CASE WHEN lifespan_months = 0 THEN total_sales
              ELSE 1.0 * total_sales / lifespan_months END AS DECIMAL(10,2)) AS avg_monthly_spend
FROM with_age;
GO

-- Quick checks
SELECT TOP 20 * FROM gold.report_customers ORDER BY total_sales DESC;

SELECT
    customer_segment,
    age_group,
    COUNT(*)         AS nb_customers,
    SUM(total_sales) AS total_sales
FROM gold.report_customers
GROUP BY customer_segment, age_group
ORDER BY customer_segment, age_group;
