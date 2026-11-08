/*
===============================================================================
Step 03 - Date Range Exploration
===============================================================================
Goal:
    Find the time boundaries of the data. This matters for every later step:
    the sales history stops in early 2014, so "today" (GETDATE()) is NOT a
    good reference date. Later scripts use the last order date instead.

Date columns in the gold layer:
    gold.fact_sales    : order_date, ship_date, due_date
    gold.dim_customers : birthdate, create_date
    gold.dim_products  : start_date

Techniques: MIN, MAX, DATEDIFF
===============================================================================
*/

USE DataWarehouse;
GO

-- 1. First and last order, and how long the sales history covers
SELECT
    MIN(order_date)                                       AS first_order_date,
    MAX(order_date)                                       AS last_order_date,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date))     AS history_months,
    DATEDIFF(YEAR,  MIN(order_date), MAX(order_date))     AS history_years,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END)   AS lines_without_order_date
FROM gold.fact_sales;

-- 2. How long orders take to ship and how far away the due date is (in days)
SELECT
    MIN(DATEDIFF(DAY, order_date, ship_date)) AS min_days_to_ship,
    AVG(DATEDIFF(DAY, order_date, ship_date)) AS avg_days_to_ship,
    MAX(DATEDIFF(DAY, order_date, ship_date)) AS max_days_to_ship,
    MIN(DATEDIFF(DAY, order_date, due_date))  AS min_days_to_due,
    MAX(DATEDIFF(DAY, order_date, due_date))  AS max_days_to_due,
    SUM(CASE WHEN ship_date > due_date THEN 1 ELSE 0 END) AS late_shipments
FROM gold.fact_sales
WHERE order_date IS NOT NULL;

-- 3. Customer ages, measured at the date of the last order
--    (DATEDIFF(YEAR) only counts year boundaries, so we correct it by
--     subtracting 1 when the birthday hasn't happened yet that year)
WITH ref AS (
    SELECT MAX(order_date) AS ref_date FROM gold.fact_sales
),
ages AS (
    SELECT
        c.customer_key,
        DATEDIFF(YEAR, c.birthdate, r.ref_date)
          - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, c.birthdate, r.ref_date), c.birthdate) > r.ref_date
                 THEN 1 ELSE 0 END AS age
    FROM gold.dim_customers c
    CROSS JOIN ref r
    WHERE c.birthdate IS NOT NULL
)
SELECT
    MIN(age)            AS youngest_age,
    MAX(age)            AS oldest_age,
    AVG(age)            AS avg_age,
    (SELECT COUNT(*) FROM gold.dim_customers WHERE birthdate IS NULL) AS customers_without_birthdate
FROM ages;

-- 4. When customers were created and when the current products started
SELECT 'customers.create_date' AS date_column, MIN(create_date) AS min_date, MAX(create_date) AS max_date
FROM gold.dim_customers
UNION ALL
SELECT 'products.start_date', CAST(MIN(start_date) AS DATE), CAST(MAX(start_date) AS DATE)
FROM gold.dim_products;
