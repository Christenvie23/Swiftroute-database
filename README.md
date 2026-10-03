# SwiftRoute Logistics Database System

A fully normalised (3NF) relational database designed for a South African
third-party logistics (3PL) company, covering fleet management, warehousing,
HR, finance, and delivery operations.

## Overview

SwiftRoute models the core operations of a logistics business end-to-end —
from client orders and route planning through to delivery confirmation,
invoicing, and vehicle maintenance. The schema contains 26 tables and is
backed by a set of analytical SQL queries demonstrating joins, subqueries,
CTEs, and window functions.

## Repository Contents

| File | Description |
|---|---|
| `schema.sql` | Full database schema — tables, primary/foreign keys, constraints, views, stored procedures, and triggers |
| `analytical_queries.sql` | 12 analytical queries covering JOINs, aggregation, CTEs, and window functions (RANK, ROW_NUMBER, LAG, running totals) |
| `data_dictionary.xlsx` | Table-by-table breakdown of every column, data type, and constraint |

## Key Design Features

- **3NF normalisation** across all 26 tables to eliminate redundancy
- **Referential integrity** enforced through foreign key constraints
- **Automated business logic** via triggers (e.g. vehicle status updates)
- **Stored procedures** with input validation for common operations
- **Views** for simplified access to frequently joined data

## Sample Analytical Queries

A few highlights from `analytical_queries.sql`:

- **High-value clients** — CTE + `HAVING` to surface repeat clients ranked by lifetime invoice value
- **Vehicle maintenance ranking** — `RANK() OVER` to identify the most expensive vehicles to maintain
- **Month-over-month fuel cost trend** — `LAG()` to calculate percentage change between months
- **Route performance** — conditional aggregation to calculate delivery success rate per route

## Tech Stack

`MySQL` · `SQL` · `ERD Design` · `Stored Procedures` · `Triggers` · `Views`

## Author

**Christenvie Nlolo**
[GitHub](https://github.com/christenvie23) · [LinkedIn](https://www.linkedin.com/in/christenvie-nlolo-204b2b304/)
