/*
===============================================================================
Step 02 - Dimensions Exploration
===============================================================================
Goal:
    List the distinct values of every descriptive column, so we know which
    labels we can group by later and spot anything odd ('n/a', NULLs,
    unexpected spellings).

Dimensions in the gold layer:
    gold.dim_customers : country, gender, marital_status
    gold.dim_products  : category > subcategory > product_name (hierarchy),
                         product_line, maintenance

Techniques: DISTINCT, GROUP BY, COUNT
===============================================================================
*/

USE DataWarehouse;
GO

-- -----------------------------------------------------------------------------
-- Customers
-- -----------------------------------------------------------------------------

-- 1. Countries our customers come from (with how many customers each)
SELECT
    COALESCE(country, '(missing)') AS country,
    COUNT(*)                       AS nb_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY nb_customers DESC;

-- 2. Gender and marital status values side by side
--    ('n/a' means neither the CRM nor the ERP system had the information)
SELECT 'gender'         AS attribute, gender         AS value, COUNT(*) AS nb_customers
FROM gold.dim_customers
GROUP BY gender
UNION ALL
SELECT 'marital_status' AS attribute, marital_status AS value, COUNT(*) AS nb_customers
FROM gold.dim_customers
GROUP BY marital_status
ORDER BY attribute, nb_customers DESC;

-- -----------------------------------------------------------------------------
-- Products
-- -----------------------------------------------------------------------------

-- 3. The product hierarchy: category > subcategory, with number of products
SELECT
    COALESCE(category, '(no category)') AS category,
    COALESCE(subcategory, '(none)')     AS subcategory,
    COUNT(*)                            AS nb_products
FROM gold.dim_products
GROUP BY category, subcategory
ORDER BY category, subcategory;

-- 4. Full hierarchy down to product name
SELECT DISTINCT
    category,
    subcategory,
    product_name
FROM gold.dim_products
ORDER BY category, subcategory, product_name;

-- 5. Other product labels: product line and maintenance flag
SELECT
    product_line,
    maintenance,
    COUNT(*) AS nb_products
FROM gold.dim_products
GROUP BY product_line, maintenance
ORDER BY product_line, maintenance;
