/*
===============================================================================
Step 01 - Database Exploration
===============================================================================
Goal:
    Get to know the database before analysing anything: which objects exist,
    which schemas they belong to, and what the gold layer (the star schema we
    will analyse) looks like column by column.

Gold layer recap (built in the data warehouse project):
    gold.dim_customers  - 1 row per customer      (key: customer_key)
    gold.dim_products   - 1 row per current product (key: product_key)
    gold.fact_sales     - 1 row per order line, linked to both dimensions
                          through customer_key and product_key

Techniques: INFORMATION_SCHEMA views, sys catalog views
===============================================================================
*/

USE DataWarehouse;
GO

-- 1. All tables and views, grouped by schema (bronze / silver / gold)
SELECT
    TABLE_SCHEMA AS schema_name,
    TABLE_NAME   AS object_name,
    TABLE_TYPE   AS object_type
FROM INFORMATION_SCHEMA.TABLES
ORDER BY schema_name, object_name;

-- 2. How many objects each layer contains
SELECT
    TABLE_SCHEMA AS schema_name,
    SUM(CASE WHEN TABLE_TYPE = 'BASE TABLE' THEN 1 ELSE 0 END) AS tables,
    SUM(CASE WHEN TABLE_TYPE = 'VIEW'       THEN 1 ELSE 0 END) AS views
FROM INFORMATION_SCHEMA.TABLES
GROUP BY TABLE_SCHEMA
ORDER BY schema_name;

-- 3. Full column list of the gold layer (the model used in every later step)
SELECT
    TABLE_NAME               AS object_name,
    ORDINAL_POSITION         AS position,
    COLUMN_NAME              AS column_name,
    DATA_TYPE                AS data_type,
    CHARACTER_MAXIMUM_LENGTH AS max_length,
    IS_NULLABLE              AS is_nullable
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold'
ORDER BY object_name, position;

-- 4. Spot the keys that connect the star schema:
--    columns ending in "_key" appear in both a dimension and the fact
SELECT
    COLUMN_NAME                                 AS key_column,
    STRING_AGG(TABLE_NAME, ', ')                AS found_in,
    COUNT(*)                                    AS nb_objects
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold'
  AND COLUMN_NAME LIKE '%[_]key'
GROUP BY COLUMN_NAME;

-- 5. The gold objects are views: show the definition behind each one
SELECT
    v.name               AS view_name,
    m.definition         AS view_definition
FROM sys.views v
JOIN sys.schemas s     ON s.schema_id = v.schema_id
JOIN sys.sql_modules m ON m.object_id = v.object_id
WHERE s.name = 'gold';
