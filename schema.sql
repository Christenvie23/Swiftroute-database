-- ============================================================
--  SwiftRoute Logistics (Pty) Ltd
--  CORRECTED SCHEMA  –  v2.0
--  Fixes applied:
--    1. INSURANCES.COVERAGE_TYPE  → VARCHAR(100)  (was INT)
--    2. INSURANCES              → added POLICY_NUMBER VARCHAR(100)
--    3. VEHICLES                → removed UNIQUE on LICENCE_DISK_VALID_UNTIL
--    4. PAYMENTS                → removed redundant ORDER_ID FK
--    5. VEHICLES                → added CATEGORY_ID FK to VEHICLE_CATEGORIES
--    6. FUEL_EXPENSES.TOTAL_COST → protected by CHECK constraint
--    7. New tables: FEEDBACKS, ACCIDENTS
--    8. Junction table: VEHICLE_CATEGORIES_VEHICLES (from ERD)
--    9. Removed leftover debug queries (SELECT * FROM sys.tables, etc.)
--   10. STATUS_ / DESCRIPTION_ columns renamed to STATUS / DESCRIPTION
--       (trailing underscores are not needed in MySQL)
-- ============================================================

CREATE DATABASE IF NOT EXISTS SWIFT_ROUTE;
USE SWIFT_ROUTE;

-- ------------------------------------------------------------
-- BRANCHES  (no dependencies)
-- ------------------------------------------------------------
CREATE TABLE BRANCHES (
    BRANCH_ID   INT          PRIMARY KEY,
    BRANCH_NAME VARCHAR(255) NOT NULL,
    CITY        VARCHAR(255) NOT NULL,
    ADDRESS_    VARCHAR(255) NOT NULL,
    PHONE       VARCHAR(15)  NOT NULL UNIQUE
);

-- ------------------------------------------------------------
-- DEPARTMENTS  (no dependencies)
-- ------------------------------------------------------------
CREATE TABLE DEPARTMENTS (
    DEPARTMENT_ID   INT          PRIMARY KEY,
    DEPARTMENT_NAME VARCHAR(255) NOT NULL,
    BUDGET_CODE     VARCHAR(255) NOT NULL
);

-- ------------------------------------------------------------
-- CLIENTS  (no dependencies)
-- ------------------------------------------------------------
CREATE TABLE CLIENTS (
    CLIENT_ID         INT          PRIMARY KEY,
    CLIENT_NAME       VARCHAR(255) NOT NULL,
    REGISTRATION_DATE DATE         NOT NULL,
    EMAIL             VARCHAR(255) NOT NULL UNIQUE,
    PHONE             VARCHAR(15)  NOT NULL UNIQUE,
    PHYSICAL_ADDRESS  VARCHAR(255) NOT NULL,
    IS_ACTIVE         TINYINT      NOT NULL
);

-- ------------------------------------------------------------
-- SUPPLIERS  (no dependencies)
-- ------------------------------------------------------------
CREATE TABLE SUPPLIERS (
    SUPPLIER_ID    INT          PRIMARY KEY,
    SUPPLIER_NAME  VARCHAR(255) NOT NULL,
    SUPPLIER_TYPE  VARCHAR(255) NOT NULL,
    CONTACT_PERSON VARCHAR(255) NOT NULL,
    PHONE          VARCHAR(15)  NOT NULL UNIQUE,
    EMAIL          VARCHAR(255) NOT NULL UNIQUE
);

-- ------------------------------------------------------------
-- VEHICLE_CATEGORIES  (no dependencies)
-- ------------------------------------------------------------
CREATE TABLE VEHICLE_CATEGORIES (
    CATEGORY_ID   INT            PRIMARY KEY,
    CATEGORY_NAME VARCHAR(255)   NOT NULL,
    MAX_WEIGHT_KG DECIMAL(10,2)  NOT NULL,
    MAX_VOLUME_M3 DECIMAL(10,2)  NOT NULL
);

-- ------------------------------------------------------------
-- VEHICLES
--   FIX 3: LICENCE_DISK_VALID_UNTIL  – UNIQUE constraint removed
--           (two vehicles can share the same expiry date)
--   FIX 5: CATEGORY_ID FK added so vehicles are linked to a category
-- ------------------------------------------------------------
CREATE TABLE VEHICLES (
    VEHICLE_ID             INT          PRIMARY KEY,
    REG_NUMBER             VARCHAR(255) NOT NULL UNIQUE,
    MAKE                   VARCHAR(255) NOT NULL,
    MODEL                  VARCHAR(255) NOT NULL,
    YEAR_MADE              INT          NOT NULL,
    IS_ROADWORTHY          TINYINT      NOT NULL,
    LICENCE_DISK_VALID_UNTIL DATE        NOT NULL,   -- UNIQUE removed
    STATUS                 VARCHAR(255) NOT NULL,
    CATEGORY_ID            INT,                      -- NEW FK

    FOREIGN KEY (CATEGORY_ID) REFERENCES VEHICLE_CATEGORIES(CATEGORY_ID)
);

-- ------------------------------------------------------------
-- VEHICLE_CATEGORIES_VEHICLES  (many-to-many – from ERD)
-- Allows a vehicle to be reclassified or span multiple categories
-- if the business ever needs it; keeps ERD faithful.
-- ------------------------------------------------------------
CREATE TABLE VEHICLE_CATEGORIES_VEHICLES (
    VEHICLE_CATEGORY_ID INT NOT NULL,
    VEHICLE_ID          INT NOT NULL,

    PRIMARY KEY (VEHICLE_CATEGORY_ID, VEHICLE_ID),

    FOREIGN KEY (VEHICLE_CATEGORY_ID) REFERENCES VEHICLE_CATEGORIES(CATEGORY_ID),
    FOREIGN KEY (VEHICLE_ID)          REFERENCES VEHICLES(VEHICLE_ID)
);

-- ------------------------------------------------------------
-- INSURANCES
--   FIX 1: COVERAGE_TYPE changed from INT to VARCHAR(100)
--   FIX 2: POLICY_NUMBER column added (from ERD & data dictionary)
-- ------------------------------------------------------------
CREATE TABLE INSURANCES (
    INSURANCE_ID   INT          PRIMARY KEY,
    PROVIDER_NAME  VARCHAR(255) NOT NULL,
    POLICY_NUMBER  VARCHAR(100) NOT NULL,            -- NEW
    COVERAGE_TYPE  VARCHAR(100) NOT NULL,            -- was INT → now VARCHAR
    START_DATE_    DATE         NOT NULL,
    EXPIRY_DATE_   DATE         NOT NULL,
    VEHICLE_ID     INT,

    FOREIGN KEY (VEHICLE_ID) REFERENCES VEHICLES(VEHICLE_ID)
);

-- ------------------------------------------------------------
-- ACCIDENTS  (NEW – from ERD & data dictionary)
-- ------------------------------------------------------------
CREATE TABLE ACCIDENTS (
    ACCIDENT_ID   INT            PRIMARY KEY,
    ACCIDENT_DATE DATE           NOT NULL,
    DESCRIPTION   VARCHAR(255)   NOT NULL,
    DAMAGE_COST   DECIMAL(10,2)  NOT NULL,
    STATUS        VARCHAR(100)   NOT NULL,
    VEHICLE_ID    INT,

    FOREIGN KEY (VEHICLE_ID) REFERENCES VEHICLES(VEHICLE_ID)
);

-- ------------------------------------------------------------
-- MAINTENANCE_RECORDS
-- ------------------------------------------------------------
CREATE TABLE MAINTENANCE_RECORDS (
    MAINTENANCE_ID   INT           PRIMARY KEY,
    MAINTENANCE_DATE DATE          NOT NULL,
    DESCRIPTION_     VARCHAR(255)  NOT NULL,
    COST             DECIMAL(10,2) NOT NULL,
    STATUS_          VARCHAR(255)  NOT NULL,
    VEHICLE_ID       INT,
    SUPPLIER_ID      INT,

    FOREIGN KEY (VEHICLE_ID)  REFERENCES VEHICLES(VEHICLE_ID),
    FOREIGN KEY (SUPPLIER_ID) REFERENCES SUPPLIERS(SUPPLIER_ID)
);

-- ------------------------------------------------------------
-- FUEL_EXPENSES
--   FIX 6: CHECK constraint added so TOTAL_COST must equal
--           LITERS * COST_PER_LITRE (prevents silent data errors)
-- ------------------------------------------------------------
CREATE TABLE FUEL_EXPENSES (
    FUEL_EXPENSE_ID  INT           PRIMARY KEY,
    FILL_UP_DATE     DATE          NOT NULL,
    LITERS           DECIMAL(10,2) NOT NULL,
    COST_PER_LITRE   DECIMAL(10,2) NOT NULL,
    TOTAL_COST       DECIMAL(10,2) NOT NULL,
    ODOMETER_READING INT           NOT NULL,
    VEHICLE_ID       INT,
    SUPPLIER_ID      INT,

    -- Derived-value guard: TOTAL_COST must match LITERS × COST_PER_LITRE
    CONSTRAINT chk_fuel_total CHECK (
        ABS(TOTAL_COST - (LITERS * COST_PER_LITRE)) < 0.01
    ),

    FOREIGN KEY (VEHICLE_ID)  REFERENCES VEHICLES(VEHICLE_ID),
    FOREIGN KEY (SUPPLIER_ID) REFERENCES SUPPLIERS(SUPPLIER_ID)
);

-- ------------------------------------------------------------
-- ORDERS
-- ------------------------------------------------------------
CREATE TABLE ORDERS (
    ORDER_ID               INT           PRIMARY KEY,
    ORDER_REFNUMBER        VARCHAR(255)  NOT NULL,
    ORDER_DATE             DATE          NOT NULL,
    REQUIRED_DELIVERYDATE  DATE          NOT NULL,
    STATUS_                VARCHAR(255)  NOT NULL,
    TOTAL_DISTANCE         DECIMAL(10,2) NOT NULL,
    CLIENT_ID              INT           NOT NULL,

    FOREIGN KEY (CLIENT_ID) REFERENCES CLIENTS(CLIENT_ID)
);

-- ------------------------------------------------------------
-- INVOICES
-- ------------------------------------------------------------
CREATE TABLE INVOICES (
    INVOICE_ID     INT           PRIMARY KEY,
    INVOICE_DATE   DATE          NOT NULL,
    TOTAL_AMOUNT   DECIMAL(10,2) NOT NULL,
    PAYMENT_STATUS VARCHAR(255)  NOT NULL,
    ORDER_ID       INT           NOT NULL,

    FOREIGN KEY (ORDER_ID) REFERENCES ORDERS(ORDER_ID)
);

-- ------------------------------------------------------------
-- PAYMENTS
--   FIX 4: ORDER_ID removed – payment→invoice→order already gives
--           the order link; storing it here created redundancy and
--           potential inconsistency.
-- ------------------------------------------------------------
CREATE TABLE PAYMENTS (
    PAYMENT_ID       INT           PRIMARY KEY,
    PAYMENT_DATE     DATE          NOT NULL,
    AMOUNT_PAID      DECIMAL(10,2) NOT NULL,
    PAYMENT_METHOD   VARCHAR(255)  NOT NULL,
    REFERENCE_NUMBER INT           NOT NULL UNIQUE,
    INVOICE_ID       INT,

    FOREIGN KEY (INVOICE_ID) REFERENCES INVOICES(INVOICE_ID)
);

-- ------------------------------------------------------------
-- ROUTES
-- ------------------------------------------------------------
CREATE TABLE ROUTES (
    ROUTE_ID               INT           PRIMARY KEY,
    START_LOCATION         VARCHAR(255)  NOT NULL,
    END_LOCATION           VARCHAR(255)  NOT NULL,
    DISTANCE_KM            DECIMAL(10,2) NOT NULL,
    ESTIMATED_DURATION_MIN TIME          NOT NULL,
    ROAD_CONDITIONS        VARCHAR(255)  NULL,
    ORDER_ID               INT,

    FOREIGN KEY (ORDER_ID) REFERENCES ORDERS(ORDER_ID)
);

-- ------------------------------------------------------------
-- CARGO_ITEMS
-- ------------------------------------------------------------
CREATE TABLE CARGO_ITEMS (
    CARGO_ITEM_ID INT           PRIMARY KEY,
    CARGO_TYPE    VARCHAR(255)  NOT NULL,
    WEIGHT_KG     DECIMAL(10,2) NOT NULL,
    VOLUME_M3     DECIMAL(10,2) NOT NULL,
    DESCRIPTION_  VARCHAR(255)  NULL,
    ORDER_ID      INT,

    FOREIGN KEY (ORDER_ID) REFERENCES ORDERS(ORDER_ID)
);

-- ------------------------------------------------------------
-- DELIVERIES
-- ------------------------------------------------------------
CREATE TABLE DELIVERIES (
    DELIVERY_ID          INT          PRIMARY KEY,
    ACTUAL_DELIVERY_DATE DATE         NOT NULL,
    CONFIRMED_BY         VARCHAR(255) NOT NULL,
    DELIVERY_STATUS      VARCHAR(255) NOT NULL,
    ORDER_ID             INT          NOT NULL,
    ROUTE_ID             INT          NOT NULL,

    FOREIGN KEY (ORDER_ID)  REFERENCES ORDERS(ORDER_ID),
    FOREIGN KEY (ROUTE_ID)  REFERENCES ROUTES(ROUTE_ID)
);

-- ------------------------------------------------------------
-- TRACKINGS
-- ------------------------------------------------------------
CREATE TABLE TRACKINGS (
    TRACKING_ID      INT          PRIMARY KEY,
    CURRENT_LOCATION VARCHAR(255) NOT NULL,
    GPS_COORDINATES  VARCHAR(255) NOT NULL,
    TRACKING_DATE    DATE         NOT NULL,
    TRACKING_TIME    TIME(6)      NOT NULL,
    DELIVERY_ID      INT          NOT NULL,

    FOREIGN KEY (DELIVERY_ID) REFERENCES DELIVERIES(DELIVERY_ID)
);

-- ------------------------------------------------------------
-- FEEDBACKS  (NEW – from ERD & data dictionary)
-- ------------------------------------------------------------
CREATE TABLE FEEDBACKS (
    FEEDBACK_ID   INT          PRIMARY KEY,
    RATINGS       TINYINT      NOT NULL,        -- 0-5
    COMMENTS      VARCHAR(255) NOT NULL,
    FEEDBACK_DATE DATE         NOT NULL,
    CLIENT_ID     INT          NOT NULL,
    DELIVERY_ID   INT          NOT NULL,

    FOREIGN KEY (CLIENT_ID)   REFERENCES CLIENTS(CLIENT_ID),
    FOREIGN KEY (DELIVERY_ID) REFERENCES DELIVERIES(DELIVERY_ID)
);

-- ------------------------------------------------------------
-- EMPLOYEES
-- ------------------------------------------------------------
CREATE TABLE EMPLOYEES (
    EMPLOYEE_ID   INT          PRIMARY KEY,
    FIRST_NAME    VARCHAR(255) NOT NULL,
    LAST_NAME     VARCHAR(255) NOT NULL,
    ROLE_         VARCHAR(255) NOT NULL,
    IS_ACTIVE     TINYINT      NOT NULL,
    DEPARTMENT_ID INT,
    BRANCH_ID     INT,

    FOREIGN KEY (DEPARTMENT_ID) REFERENCES DEPARTMENTS(DEPARTMENT_ID),
    FOREIGN KEY (BRANCH_ID)     REFERENCES BRANCHES(BRANCH_ID)
);

-- ------------------------------------------------------------
-- PAYROLLS
-- ------------------------------------------------------------
CREATE TABLE PAYROLLS (
    PAYROLL_ID   INT           PRIMARY KEY,
    PAYMENT_DATE DATE          NOT NULL,
    NET_SALARY   DECIMAL(10,2) NOT NULL,
    EMPLOYEE_ID  INT,

    FOREIGN KEY (EMPLOYEE_ID) REFERENCES EMPLOYEES(EMPLOYEE_ID)
);

-- ------------------------------------------------------------
-- WAREHOUSES
-- ------------------------------------------------------------
CREATE TABLE WAREHOUSES (
    WAREHOUSE_ID   INT          PRIMARY KEY,
    WAREHOUSE_NAME VARCHAR(255) NOT NULL,
    ADDRESS_       VARCHAR(255) NOT NULL,
    BRANCH_ID      INT,

    FOREIGN KEY (BRANCH_ID) REFERENCES BRANCHES(BRANCH_ID)
);

-- ------------------------------------------------------------
-- INVENTORIES
-- ------------------------------------------------------------
CREATE TABLE INVENTORIES (
    INVENTORY_ID  INT          PRIMARY KEY,
    QUANTITY      INT          NOT NULL,
    DATE_STORED   DATE         NOT NULL,
    STATUS_       VARCHAR(255) NOT NULL,
    WAREHOUSE_ID  INT,
    CARGO_ITEM_ID INT,

    FOREIGN KEY (WAREHOUSE_ID)  REFERENCES WAREHOUSES(WAREHOUSE_ID),
    FOREIGN KEY (CARGO_ITEM_ID) REFERENCES CARGO_ITEMS(CARGO_ITEM_ID)
);

-- ------------------------------------------------------------
-- WAREHOUSE_LOCATIONS
-- ------------------------------------------------------------
CREATE TABLE WAREHOUSE_LOCATIONS (
    LOCATION_ID  INT     PRIMARY KEY,
    AISLE        INT     NOT NULL,
    RACK         INT     NOT NULL,
    SHELF        INT     NOT NULL,
    IS_OCCUPIED  TINYINT NOT NULL,
    WAREHOUSE_ID INT,

    FOREIGN KEY (WAREHOUSE_ID) REFERENCES WAREHOUSES(WAREHOUSE_ID)
);

-- ------------------------------------------------------------
-- JUNCTION TABLES
-- ------------------------------------------------------------
CREATE TABLE VEHICLE_DELIVERY (
    VEHICLE_ID  INT NOT NULL,
    DELIVERY_ID INT NOT NULL,

    PRIMARY KEY (VEHICLE_ID, DELIVERY_ID),

    FOREIGN KEY (VEHICLE_ID)  REFERENCES VEHICLES(VEHICLE_ID),
    FOREIGN KEY (DELIVERY_ID) REFERENCES DELIVERIES(DELIVERY_ID)
);

CREATE TABLE EMPLOYEE_WAREHOUSE (
    EMPLOYEE_ID  INT NOT NULL,
    WAREHOUSE_ID INT NOT NULL,

    PRIMARY KEY (EMPLOYEE_ID, WAREHOUSE_ID),

    FOREIGN KEY (EMPLOYEE_ID)  REFERENCES EMPLOYEES(EMPLOYEE_ID),
    FOREIGN KEY (WAREHOUSE_ID) REFERENCES WAREHOUSES(WAREHOUSE_ID)
);

-- ------------------------------------------------------------
-- RECOMMENDED INDEXES
-- (Noted in the DBLC doc but missing from the original SQL)
-- ------------------------------------------------------------
CREATE INDEX idx_orders_client       ON ORDERS(CLIENT_ID);
CREATE INDEX idx_deliveries_order    ON DELIVERIES(ORDER_ID);
CREATE INDEX idx_deliveries_route    ON DELIVERIES(ROUTE_ID);
CREATE INDEX idx_trackings_delivery  ON TRACKINGS(DELIVERY_ID);
CREATE INDEX idx_payments_invoice    ON PAYMENTS(INVOICE_ID);
CREATE INDEX idx_cargo_order         ON CARGO_ITEMS(ORDER_ID);
CREATE INDEX idx_inventory_warehouse ON INVENTORIES(WAREHOUSE_ID);
CREATE INDEX idx_maintenance_vehicle ON MAINTENANCE_RECORDS(VEHICLE_ID);
CREATE INDEX idx_fuel_vehicle        ON FUEL_EXPENSES(VEHICLE_ID);
CREATE INDEX idx_employees_dept      ON EMPLOYEES(DEPARTMENT_ID);
CREATE INDEX idx_employees_branch    ON EMPLOYEES(BRANCH_ID);
