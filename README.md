# SQL Data Analytics Project

End-to-end SQL analytics on top of my [SQL Data Warehouse](https://github.com/yassmine05/sql_data_warehouse-project): from exploring the data model, to advanced analysis with window functions, to two reusable reporting views for customers and products.

> **Credit:** This project follows the [SQL Data Analytics tutorial](https://github.com/DataWithBaraa/sql-data-analytics-project) by **Baraa Khatib Salkini** ([Data With Baraa](https://www.youtube.com/@datawithbaraa)), released under the MIT License. I followed his analysis roadmap, then wrote my own queries adapted to the gold layer of my warehouse, with extra checks and analyses. Thank you, Baraa!

---

## The data model

All queries run on the **gold layer** (star schema) of the `DataWarehouse` database:

```
                 ┌──────────────────────┐
                 │  gold.dim_customers  │
                 │  customer_key (PK)   │
                 │  country, gender,    │
                 │  marital_status,     │
                 │  birthdate, ...      │
                 └──────────┬───────────┘
                            │ 1
                            │
                            │ n
┌──────────────────┐   ┌────┴────────────────────┐
│ gold.dim_products│ 1 │    gold.fact_sales      │
│ product_key (PK) ├───┤ order_number            │
│ category,        │ n │ product_key  (FK)       │
│ subcategory,     │   │ customer_key (FK)       │
│ product_line,    │   │ order_date, ship_date,  │
│ cost, ...        │   │ due_date                │
└──────────────────┘   │ sales_amount, quantity, │
                       │ price                   │
                       └─────────────────────────┘
```

- **Grain of the fact table:** one row = one order line. An order can contain several products, so orders are counted with `COUNT(DISTINCT order_number)`.
- **Measures:** `sales_amount`, `quantity`, `price` (with `sales_amount = quantity × price`).
- **Time span:** orders from December 2010 to January 2014. Because the data is historical, ages, recency and lifespans are measured against the **last order date** instead of `GETDATE()`.

## Project roadmap

### 1. Exploratory Data Analysis (`scripts/01_eda`)

| Step | Script | Question it answers |
|:--:|:--|:--|
| 01 | `01_database_exploration.sql` | Which tables and views exist, and how is the star schema connected? |
| 02 | `02_dimensions_exploration.sql` | Which countries, genders and product categories can we analyze? |
| 03 | `03_date_range_exploration.sql` | What period does the data cover? How old are customers? How fast are orders shipped? |
| 04 | `04_measures_exploration.sql` | What are the headline KPIs (sales, orders, items, customers)? |
| 05 | `05_magnitude_analysis.sql` | How do sales and customers split across countries, categories and product lines? |
| 06 | `06_ranking_analysis.sql` | Which products and customers perform best or worst, and which products never sold? |

### 2. Advanced Analytics (`scripts/02_advanced_analytics`)

| Step | Script | Question it answers |
|:--:|:--|:--|
| 07 | `07_change_over_time_analysis.sql` | How do sales evolve by year and month? Is there seasonality? |
| 08 | `08_cumulative_analysis.sql` | How does revenue accumulate over time (running totals, YTD, moving average)? How fast does the customer base grow? |
| 09 | `09_performance_analysis.sql` | Is each product doing better than its own average and than last year (YoY, MoM)? |
| 10 | `10_part_to_whole_analysis.sql` | Which categories and countries contribute most? Do 20% of products make 80% of revenue? |
| 11 | `11_data_segmentation.sql` | How do products split by cost range, and customers by age group and value (VIP / Regular / New)? |

### 3. Reports (`scripts/03_reports`)

| Step | Script | Output |
|:--:|:--|:--|
| 12 | `12_report_customers.sql` | View `gold.report_customers`: one row per customer with segment, age group, recency, average order value, average monthly spend |
| 13 | `13_report_products.sql` | View `gold.report_products`: one row per product with performance segment, recency, estimated margin, average order revenue, average monthly revenue |

These two views can be plugged directly into Power BI, Tableau or Excel.

## How to run it

1. Build the `DataWarehouse` database with the scripts from my [data warehouse project](https://github.com/yassmine05/sql_data_warehouse-project), so the gold views exist.
2. Open the scripts in **SQL Server Management Studio** and run them in order (01 to 13). Each file can be run on its own, and each query in a file can be run separately.
3. Steps 12 and 13 use `CREATE OR ALTER VIEW` (SQL Server 2016 SP1 or later) and replace the report views if they already exist.

## Skills practiced

- Exploring a database through `INFORMATION_SCHEMA` and system views
- Aggregations and joins across a star schema
- Window functions: `RANK`, `DENSE_RANK`, `ROW_NUMBER`, `NTILE`, `LAG`, running `SUM() OVER`, moving `AVG() OVER`
- Time-series analysis: YoY, MoM, YTD, seasonality, cohort-style customer growth
- Segmentation with `CASE` and building reporting views with CTEs

## Tools

SQL Server · T-SQL · SQL Server Management Studio · Git & GitHub

## License

This project is shared under the [MIT License](LICENSE). It is based on the tutorial material © 2024 Baraa Khatib Salkini, also under the MIT License.
