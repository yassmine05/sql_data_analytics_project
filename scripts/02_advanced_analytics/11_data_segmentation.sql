/*
===============================================================================
Step 11 - Data Segmentation
===============================================================================
Goal:
    Turn measures into groups (buckets) to describe the business:
      - products by cost range
      - customers by age group (age at the last order date)
      - customers by value: VIP / Regular / New

Reference date:
    The sales history ends in January 2014, so ages and customer lifespans
    are measured against the LAST ORDER DATE in the data, not GETDATE().
    Otherwise every customer would look 10+ years older and "inactive".

Segment rules (customers):
    lifespan = months between a customer's first and last order
    - VIP     : lifespan >= 12 months and total spending >  5,000
    - Regular : lifespan >= 12 months and total spending <= 5,000
    - New     : lifespan <  12 months

Techniques: CASE buckets, CTEs, DATEDIFF, GROUP BY on derived columns
===============================================================================
*/

USE DataWarehouse;
GO

-- 1. Products by cost range
--    (each range is a half-open interval so no product is counted twice)
WITH product_cost_ranges AS (
    SELECT
        product_key,
        cost,
        CASE
            WHEN cost < 100   THEN '1. Under 100'
            WHEN cost < 500   THEN '2. 100 - 499'
            WHEN cost < 1000  THEN '3. 500 - 999'
            ELSE                   '4. 1000 and more'
        END AS cost_range
    FROM gold.dim_products
)
SELECT
    cost_range,
    COUNT(*)  AS nb_products,
    MIN(cost) AS min_cost,
    MAX(cost) AS max_cost
FROM product_cost_ranges
GROUP BY cost_range
ORDER BY cost_range;

-- 2. Customers by age group, with their revenue
WITH ref AS (
    SELECT MAX(order_date) AS ref_date FROM gold.fact_sales
),
customer_age AS (
    SELECT
        c.customer_key,
        DATEDIFF(YEAR, c.birthdate, r.ref_date)
          - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, c.birthdate, r.ref_date), c.birthdate) > r.ref_date
                 THEN 1 ELSE 0 END AS age
    FROM gold.dim_customers c
    CROSS JOIN ref r
),
customer_age_group AS (
    SELECT
        customer_key,
        CASE
            WHEN age IS NULL THEN '6. Unknown'
            WHEN age < 30    THEN '1. Under 30'
            WHEN age < 40    THEN '2. 30 - 39'
            WHEN age < 50    THEN '3. 40 - 49'
            WHEN age < 60    THEN '4. 50 - 59'
            ELSE                  '5. 60 and over'
        END AS age_group
    FROM customer_age
)
SELECT
    g.age_group,
    COUNT(DISTINCT g.customer_key) AS nb_customers,
    COALESCE(SUM(f.sales_amount), 0) AS total_sales
FROM customer_age_group g
LEFT JOIN gold.fact_sales f
    ON f.customer_key = g.customer_key
GROUP BY g.age_group
ORDER BY g.age_group;

-- 3. Customers by value segment (VIP / Regular / New)
WITH customer_spending AS (
    SELECT
        customer_key,
        SUM(sales_amount)                               AS total_spending,
        MIN(order_date)                                 AS first_order,
        MAX(order_date)                                 AS last_order,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY customer_key
),
segmented AS (
    SELECT
        customer_key,
        total_spending,
        lifespan_months,
        CASE
            WHEN lifespan_months >= 12 AND total_spending >  5000 THEN 'VIP'
            WHEN lifespan_months >= 12                            THEN 'Regular'
            ELSE                                                       'New'
        END AS customer_segment
    FROM customer_spending
)
SELECT
    customer_segment,
    COUNT(*)                                                         AS nb_customers,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))   AS pct_of_customers,
    SUM(total_spending)                                              AS total_sales,
    CAST(100.0 * SUM(total_spending) / SUM(SUM(total_spending)) OVER () AS DECIMAL(5,2)) AS pct_of_sales,
    AVG(total_spending)                                              AS avg_spending
FROM segmented
GROUP BY customer_segment
ORDER BY total_sales DESC;

-- 4. Segment x country: where are the VIP customers?
WITH customer_spending AS (
    SELECT
        customer_key,
        SUM(sales_amount)                                 AS total_spending,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY customer_key
)
SELECT
    c.country,
    SUM(CASE WHEN s.lifespan_months >= 12 AND s.total_spending > 5000 THEN 1 ELSE 0 END)  AS vip_customers,
    SUM(CASE WHEN s.lifespan_months >= 12 AND s.total_spending <= 5000 THEN 1 ELSE 0 END) AS regular_customers,
    SUM(CASE WHEN s.lifespan_months < 12 THEN 1 ELSE 0 END)                               AS new_customers
FROM customer_spending s
LEFT JOIN gold.dim_customers c
    ON c.customer_key = s.customer_key
GROUP BY c.country
ORDER BY vip_customers DESC;
