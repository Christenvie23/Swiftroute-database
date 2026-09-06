-- ============================================================
--  SwiftRoute Logistics (Pty) Ltd
--  ANALYTICAL QUERIES  –  v1.0
--  Techniques demonstrated:
--    JOINs, GROUP BY, aggregations, subqueries,
--    CTEs, window functions (RANK, ROW_NUMBER, LAG, SUM OVER)
-- ============================================================

USE SWIFT_ROUTE;

-- ============================================================
-- QUERY 1 – Basic JOIN + aggregation
-- All clients with their orders and current order status
-- Shows: multi-table join, filtering, ordering
-- ============================================================
SELECT
    C.CLIENT_NAME,
    O.ORDER_REFNUMBER,
    O.ORDER_DATE,
    O.REQUIRED_DELIVERYDATE,
    O.STATUS_   AS ORDER_STATUS,
    O.TOTAL_DISTANCE
FROM CLIENTS  C
JOIN ORDERS   O ON C.CLIENT_ID = O.CLIENT_ID
ORDER BY O.ORDER_DATE DESC;


-- ============================================================
-- QUERY 2 – Aggregation with LEFT JOIN
-- Invoice payment summary: total invoiced vs total paid,
-- and outstanding balance per invoice
-- Shows: LEFT JOIN, SUM, computed column, CASE
-- ============================================================
SELECT
    I.INVOICE_ID,
    I.PAYMENT_STATUS,
    I.TOTAL_AMOUNT                              AS AMOUNT_INVOICED,
    COALESCE(SUM(P.AMOUNT_PAID), 0)            AS TOTAL_PAID,
    I.TOTAL_AMOUNT - COALESCE(SUM(P.AMOUNT_PAID), 0) AS OUTSTANDING_BALANCE,
    CASE
        WHEN I.TOTAL_AMOUNT - COALESCE(SUM(P.AMOUNT_PAID), 0) <= 0 THEN 'Settled'
        WHEN I.PAYMENT_STATUS = 'Overdue'                          THEN 'Action Required'
        ELSE 'Partially Paid'
    END AS SETTLEMENT_FLAG
FROM INVOICES I
LEFT JOIN PAYMENTS P ON I.INVOICE_ID = P.INVOICE_ID
GROUP BY I.INVOICE_ID, I.PAYMENT_STATUS, I.TOTAL_AMOUNT
ORDER BY OUTSTANDING_BALANCE DESC;


-- ============================================================
-- QUERY 3 – Three-table JOIN
-- Delivery detail report: status, route, distance, road conditions
-- Shows: chained JOINs, filtering on delivery status
-- ============================================================
SELECT
    D.DELIVERY_ID,
    D.ACTUAL_DELIVERY_DATE,
    D.DELIVERY_STATUS,
    D.CONFIRMED_BY,
    R.START_LOCATION,
    R.END_LOCATION,
    R.DISTANCE_KM,
    R.ROAD_CONDITIONS,
    R.ESTIMATED_DURATION_MIN
FROM DELIVERIES D
JOIN ROUTES     R ON D.ROUTE_ID = R.ROUTE_ID
JOIN ORDERS     O ON D.ORDER_ID = O.ORDER_ID
ORDER BY D.ACTUAL_DELIVERY_DATE DESC;


-- ============================================================
-- QUERY 4 – Aggregation
-- Total fuel cost per vehicle with average cost per litre
-- Shows: GROUP BY, SUM, AVG, JOIN
-- ============================================================
SELECT
    V.REG_NUMBER,
    V.MAKE,
    V.MODEL,
    V.STATUS                         AS VEHICLE_STATUS,
    COUNT(F.FUEL_EXPENSE_ID)         AS TOTAL_FILLUPS,
    SUM(F.LITERS)                    AS TOTAL_LITERS,
    ROUND(AVG(F.COST_PER_LITRE), 2)  AS AVG_PRICE_PER_LITRE,
    SUM(F.TOTAL_COST)                AS TOTAL_FUEL_COST
FROM VEHICLES     V
JOIN FUEL_EXPENSES F ON V.VEHICLE_ID = F.VEHICLE_ID
GROUP BY V.VEHICLE_ID, V.REG_NUMBER, V.MAKE, V.MODEL, V.STATUS
ORDER BY TOTAL_FUEL_COST DESC;


-- ============================================================
-- QUERY 5 – Aggregation
-- Warehouse stock overview: total items, backordered items,
-- and occupancy rate of storage locations
-- Shows: multi-JOIN, conditional aggregation, ROUND
-- ============================================================
SELECT
    W.WAREHOUSE_NAME,
    B.CITY,
    COUNT(I.INVENTORY_ID)                                           AS TOTAL_LINES,
    SUM(I.QUANTITY)                                                 AS TOTAL_UNITS,
    SUM(CASE WHEN I.STATUS_ = 'Backordered' THEN 1 ELSE 0 END)     AS BACKORDERED_LINES,
    SUM(WL.IS_OCCUPIED)                                             AS OCCUPIED_LOCATIONS,
    COUNT(WL.LOCATION_ID)                                           AS TOTAL_LOCATIONS,
    ROUND(
        100.0 * SUM(WL.IS_OCCUPIED) / NULLIF(COUNT(WL.LOCATION_ID), 0),
    1)                                                              AS OCCUPANCY_PCT
FROM WAREHOUSES        W
JOIN BRANCHES          B  ON W.BRANCH_ID     = B.BRANCH_ID
LEFT JOIN INVENTORIES  I  ON W.WAREHOUSE_ID  = I.WAREHOUSE_ID
LEFT JOIN WAREHOUSE_LOCATIONS WL ON W.WAREHOUSE_ID = WL.WAREHOUSE_ID
GROUP BY W.WAREHOUSE_ID, W.WAREHOUSE_NAME, B.CITY
ORDER BY TOTAL_UNITS DESC;


-- ============================================================
-- QUERY 6 – CTE
-- High-value clients: clients with more than one order
-- and their total invoiced amount across all orders
-- Shows: CTE, multi-step aggregation, HAVING
-- ============================================================
WITH CLIENT_ORDER_TOTALS AS (
    SELECT
        C.CLIENT_ID,
        C.CLIENT_NAME,
        C.EMAIL,
        COUNT(O.ORDER_ID)        AS TOTAL_ORDERS,
        SUM(I.TOTAL_AMOUNT)      AS LIFETIME_INVOICE_VALUE,
        MAX(O.ORDER_DATE)        AS MOST_RECENT_ORDER
    FROM CLIENTS  C
    JOIN ORDERS   O ON C.CLIENT_ID  = O.CLIENT_ID
    JOIN INVOICES I ON O.ORDER_ID   = I.ORDER_ID
    GROUP BY C.CLIENT_ID, C.CLIENT_NAME, C.EMAIL
)
SELECT
    CLIENT_NAME,
    EMAIL,
    TOTAL_ORDERS,
    LIFETIME_INVOICE_VALUE,
    MOST_RECENT_ORDER
FROM CLIENT_ORDER_TOTALS
WHERE TOTAL_ORDERS > 1
ORDER BY LIFETIME_INVOICE_VALUE DESC;


-- ============================================================
-- QUERY 7 – CTE + subquery
-- Overdue invoices where the delivery was already marked Delivered
-- (financial risk report: goods delivered but payment not received)
-- Shows: CTE, subquery filter, JOIN
-- ============================================================
WITH OVERDUE_INVOICES AS (
    SELECT
        I.INVOICE_ID,
        I.INVOICE_DATE,
        I.TOTAL_AMOUNT,
        I.PAYMENT_STATUS,
        O.ORDER_REFNUMBER,
        O.CLIENT_ID
    FROM INVOICES I
    JOIN ORDERS   O ON I.ORDER_ID = O.ORDER_ID
    WHERE I.PAYMENT_STATUS = 'Overdue'
)
SELECT
    OI.INVOICE_ID,
    OI.ORDER_REFNUMBER,
    C.CLIENT_NAME,
    C.EMAIL,
    OI.INVOICE_DATE,
    OI.TOTAL_AMOUNT,
    D.DELIVERY_STATUS,
    D.ACTUAL_DELIVERY_DATE
FROM OVERDUE_INVOICES OI
JOIN CLIENTS    C ON OI.CLIENT_ID  = C.CLIENT_ID
JOIN DELIVERIES D ON D.ORDER_ID    = (
        SELECT ORDER_ID FROM INVOICES WHERE INVOICE_ID = OI.INVOICE_ID
    )
WHERE D.DELIVERY_STATUS = 'Delivered'
ORDER BY OI.TOTAL_AMOUNT DESC;


-- ============================================================
-- QUERY 8 – Window function: RANK
-- Vehicle maintenance cost ranking
-- Which vehicles are costing the most in maintenance?
-- Shows: RANK() OVER, SUM, JOIN, window partition
-- ============================================================
SELECT
    V.REG_NUMBER,
    V.MAKE,
    V.MODEL,
    V.STATUS                                           AS VEHICLE_STATUS,
    COUNT(M.MAINTENANCE_ID)                            AS MAINTENANCE_JOBS,
    SUM(M.COST)                                        AS TOTAL_MAINTENANCE_COST,
    RANK() OVER (ORDER BY SUM(M.COST) DESC)            AS COST_RANK
FROM VEHICLES            V
JOIN MAINTENANCE_RECORDS M ON V.VEHICLE_ID = M.VEHICLE_ID
GROUP BY V.VEHICLE_ID, V.REG_NUMBER, V.MAKE, V.MODEL, V.STATUS
ORDER BY COST_RANK;


-- ============================================================
-- QUERY 9 – Window function: SUM OVER (running total)
-- Monthly revenue trend: cumulative payments received over time
-- Shows: DATE_FORMAT, SUM with OVER + ORDER BY (running total),
--        GROUP BY, window frames
-- ============================================================
WITH MONTHLY_REVENUE AS (
    SELECT
        DATE_FORMAT(PAYMENT_DATE, '%Y-%m') AS PAYMENT_MONTH,
        SUM(AMOUNT_PAID)                   AS MONTHLY_TOTAL
    FROM PAYMENTS
    GROUP BY DATE_FORMAT(PAYMENT_DATE, '%Y-%m')
)
SELECT
    PAYMENT_MONTH,
    MONTHLY_TOTAL,
    SUM(MONTHLY_TOTAL) OVER (
        ORDER BY PAYMENT_MONTH
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS CUMULATIVE_REVENUE
FROM MONTHLY_REVENUE
ORDER BY PAYMENT_MONTH;


-- ============================================================
-- QUERY 10 – Window function: LAG  (month-over-month comparison)
-- How did fuel costs change month over month?
-- Shows: LAG(), ROUND, percentage change, CTE
-- ============================================================
WITH MONTHLY_FUEL AS (
    SELECT
        DATE_FORMAT(FILL_UP_DATE, '%Y-%m') AS FUEL_MONTH,
        SUM(TOTAL_COST)                    AS MONTHLY_FUEL_COST
    FROM FUEL_EXPENSES
    GROUP BY DATE_FORMAT(FILL_UP_DATE, '%Y-%m')
)
SELECT
    FUEL_MONTH,
    MONTHLY_FUEL_COST,
    LAG(MONTHLY_FUEL_COST) OVER (ORDER BY FUEL_MONTH) AS PREV_MONTH_COST,
    ROUND(
        100.0 * (MONTHLY_FUEL_COST - LAG(MONTHLY_FUEL_COST) OVER (ORDER BY FUEL_MONTH))
               / NULLIF(LAG(MONTHLY_FUEL_COST) OVER (ORDER BY FUEL_MONTH), 0),
    2) AS PCT_CHANGE
FROM MONTHLY_FUEL
ORDER BY FUEL_MONTH;


-- ============================================================
-- QUERY 11 – Window function: ROW_NUMBER  (latest maintenance per vehicle)
-- Shows: ROW_NUMBER() OVER PARTITION BY, subquery filter
-- ============================================================
SELECT
    VEHICLE_ID,
    REG_NUMBER,
    MAKE,
    MODEL,
    LAST_MAINTENANCE_DATE,
    LAST_MAINTENANCE_DESC,
    LAST_MAINTENANCE_COST
FROM (
    SELECT
        V.VEHICLE_ID,
        V.REG_NUMBER,
        V.MAKE,
        V.MODEL,
        M.MAINTENANCE_DATE  AS LAST_MAINTENANCE_DATE,
        M.DESCRIPTION_      AS LAST_MAINTENANCE_DESC,
        M.COST              AS LAST_MAINTENANCE_COST,
        ROW_NUMBER() OVER (
            PARTITION BY V.VEHICLE_ID
            ORDER BY M.MAINTENANCE_DATE DESC
        ) AS RN
    FROM VEHICLES            V
    JOIN MAINTENANCE_RECORDS M ON V.VEHICLE_ID = M.VEHICLE_ID
) RANKED
WHERE RN = 1
ORDER BY LAST_MAINTENANCE_DATE DESC;


-- ============================================================
-- QUERY 12 – Subquery + aggregation
-- Delivery performance summary per route:
-- how many deliveries succeeded, failed, or were delayed?
-- Shows: correlated subquery, conditional aggregation, HAVING
-- ============================================================
SELECT
    R.ROUTE_ID,
    R.START_LOCATION,
    R.END_LOCATION,
    R.DISTANCE_KM,
    R.ROAD_CONDITIONS,
    COUNT(D.DELIVERY_ID)                                                AS TOTAL_DELIVERIES,
    SUM(CASE WHEN D.DELIVERY_STATUS = 'Delivered'  THEN 1 ELSE 0 END)  AS SUCCESSFUL,
    SUM(CASE WHEN D.DELIVERY_STATUS = 'Failed'     THEN 1 ELSE 0 END)  AS FAILED,
    SUM(CASE WHEN D.DELIVERY_STATUS = 'Delayed'    THEN 1 ELSE 0 END)  AS DELAYED,
    ROUND(
        100.0 * SUM(CASE WHEN D.DELIVERY_STATUS = 'Delivered' THEN 1 ELSE 0 END)
               / NULLIF(COUNT(D.DELIVERY_ID), 0),
    1)                                                                  AS SUCCESS_RATE_PCT
FROM ROUTES     R
LEFT JOIN DELIVERIES D ON R.ROUTE_ID = D.ROUTE_ID
GROUP BY R.ROUTE_ID, R.START_LOCATION, R.END_LOCATION,
         R.DISTANCE_KM, R.ROAD_CONDITIONS
HAVING COUNT(D.DELIVERY_ID) > 0
ORDER BY SUCCESS_RATE_PCT ASC;   -- worst-performing routes first
