-- ----------------------------------------------------------------------------------------------------------------------------------
-- PHASE 0: Data Cleaning & Integrity 
-- ----------------------------------------------------------------------------------------------------------------------------------
-- DATA DICTIONARY (Key Tables):
-- ----------------------------------------------------------------------------------------------------------------------------------
-- - CUSTOMER: Personal info & support rep links.
-- - INVOICE: Sales headers (Total, Billing Address, Date).
-- - INVOICELINE: Transaction details (The actual "Basket" items).
-- - TRACK: Product details (Price, Duration, Media Type).
-- - ALBUM/ARTIST: Catalog hierarchy
-- ----------------------------------------------------------------------------------------------------------------------------------
USE CHINOOK;
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 1. DUPLICATE CHECK: Checking for duplicate customers (Name + Email redundancy)
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
    FirstName, 
    LastName, 
    Email, 
    COUNT(*) as Occurrence
FROM Customer
GROUP BY FirstName, LastName, Email
HAVING COUNT(*) > 1;
-- if return 0 , the customer is prefect..
-- I validated the customer master data, and confirmed zero record duplication.
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 2. NULL AUDIT: Reporting missing values in critical business columns.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
    'Customer' AS Table_Name, 
    'Email' AS Column_Name, 
    COUNT(*) - COUNT(Email) AS Missing_Count, -- count all - count without null values
    ROUND(((COUNT(*) - COUNT(Email)) / COUNT(*)) * 100, 2) AS Missing_Percentage -- 0 null with precentage 0%
FROM Customer
UNION ALL
SELECT 
    'Customer' AS Table_Name, 
    'Phone' AS Column_Name, 
    COUNT(*) - COUNT(Phone) AS Missing_Count,
    ROUND(((COUNT(*) - COUNT(Phone)) / COUNT(*)) * 100, 2) AS Missing_Percentage -- 1 null with precentage 1.69%
FROM Customer
UNION ALL
SELECT 
    'Track' AS Table_Name, 
    'Composer' AS Column_Name, 
    COUNT(*) - COUNT(Composer) AS Missing_Count,
    ROUND(((COUNT(*) - COUNT(Composer)) / COUNT(*)) * 100, 2) AS Missing_Percentage -- 977 null with precentage 27.89%
FROM Track
ORDER BY Missing_Count DESC;
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 3. Identifying invoices with zero or negative totals.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT * FROM Invoice 
WHERE Total <= 0; -- no results
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 4. Validating : Checking for invoices created before the earliest employee hire date
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT i.InvoiceId, i.InvoiceDate, e.HireDate
FROM Invoice i
JOIN Customer c ON i.CustomerId = c.CustomerId
JOIN Employee e ON c.SupportRepId = e.EmployeeId
WHERE i.InvoiceDate < e.HireDate; -- no results
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 5. Checking for Invoice Lines without a parent Invoice
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT il.* FROM InvoiceLine il
LEFT JOIN Invoice i ON il.InvoiceId = i.InvoiceId
WHERE i.InvoiceId IS NULL;
-- no results
-- ----------------------------------------------------------------------------------------------------------------------------------
-- EXPLORATION: Understanding the Shape, Size, and Scope of the Database
-- ----------------------------------------------------------------------------------------------------------------------------------

-- 6. OVERALL DATA SCALE: How big is our business universe? (Volume of records)
-- ----------------------------------------------------------------------------------------------------------------------------------
-- This query provides a quick macro-level snapshot of the database size.
SELECT 'Customers' AS Entity, COUNT(*) AS Total_Count FROM Customer -- 59
UNION ALL
SELECT 'Employees', COUNT(*) FROM Employee -- 8 
UNION ALL
SELECT 'Invoices (Transactions)', COUNT(*) FROM Invoice; -- 412

-- ----------------------------------------------------------------------------------------------------------------------------------
-- 7. BUSINESS LIFESPAN (Time Span): What is the exact period covered by our sales data?
-- ----------------------------------------------------------------------------------------------------------------------------------
-- Essential for understanding the timeframe of our YoY and running revenue analysis.
SELECT 
    MIN(InvoiceDate) AS First_Sale_Date,
    MAX(InvoiceDate) AS Last_Sale_Date,
    ROUND(DATEDIFF(MAX(InvoiceDate), MIN(InvoiceDate)) / 365.25, 2) AS Years_of_Data
FROM Invoice;
-- Approximately 5 years

-- ----------------------------------------------------------------------------------------------------------------------------------
-- 8. PRICE DISTRIBUTION: What is the general pricing structure of our tracks?
-- ----------------------------------------------------------------------------------------------------------------------------------
-- Establishing a baseline for what a "normal" track costs before digging into premium invoices.
SELECT 
    MIN(UnitPrice) AS Minimum_Price, -- 0.99
    MAX(UnitPrice) AS Maximum_Price, -- 1.99
    ROUND(AVG(UnitPrice), 2) AS Average_Price -- 1.05
FROM Track;

-- ----------------------------------------------------------------------------------------------------------------------------------
-- 9. Data Exploration - Employee Hierarchy (Recursive CTE)
-- Focus: Building a visual tree to understand the chain of command.
-- ----------------------------------------------------------------------------------------------------------------------------------

WITH RECURSIVE EmployeeTree AS (
    -- ----------------------------------------------------------------------
    -- 9.1 Anchor Member (CTE): -- general manager
    -- ----------------------------------------------------------------------
    SELECT 
        EmployeeId,
        FirstName,
        LastName,
        Title,
        ReportsTo,
        1 AS HierarchyLevel, -- GENERAL MANAGER IS 01
        CAST(CONCAT(FirstName, ' ', LastName) AS CHAR(255)) AS Management_Chain
    FROM Employee
    WHERE ReportsTo IS NULL -- SELECT GENERAL MANAGER

    UNION ALL
    -- ----------------------------------------------------------------------
    -- 9.2 Recursive Member WITHOUT GENERAL MANAGER (CTE): 
    -- ----------------------------------------------------------------------
    SELECT 
        e.EmployeeId,
        e.FirstName,
        e.LastName,
        e.Title,
        e.ReportsTo,
        et.HierarchyLevel + 1 AS HierarchyLevel,
        CAST(CONCAT(et.Management_Chain, ' -> ', e.FirstName, ' ', e.LastName) AS CHAR(255)) AS Management_Chain
    FROM Employee AS e
    INNER JOIN EmployeeTree AS et 
        ON e.ReportsTo = et.EmployeeId
)
-- ----------------------------------------------------------------------
-- 9.3 Final Query
-- ----------------------------------------------------------------------
SELECT 
    EmployeeId,
    CONCAT(REPEAT('   |-- ', HierarchyLevel - 1), FirstName, ' ', LastName) AS Employee_Name,
    Title,
    HierarchyLevel,
    Management_Chain AS Chain_of_Command 
FROM EmployeeTree
ORDER BY Management_Chain;
-- -----------------------------------
-- Phase 0 is Done 🔐🚀
-- -----------------------------------