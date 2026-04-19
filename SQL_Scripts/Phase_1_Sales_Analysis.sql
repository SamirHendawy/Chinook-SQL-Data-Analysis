USE Chinook;
SELECT COUNT(*) FROM customer;
SELECT COUNT(*) FROM employee;
-- ----------------------------------------------------------------------------------------------------------------------------------
-- Phase 1: Sales Analysis (Revenue & Performance)
-- Focus: Measuring financial health and staff efficiency.
-- --------------	--------------------------------------------------------------------------------------------------------------------
-- 1.	Revenue by Country: Rank countries by total revenue to identify high-value markets.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
	C.Country,
    SUM(i.total) AS totalRevenue
FROM Invoice AS I
JOIN customer AS C
	ON I.customerid = C.customerid
GROUP BY C.Country
ORDER BY totalRevenue DESC
LIMIT 5;
-- Using INNER JOIN instead of LEFT JOIN to ensure the results only include
-- customers with existing invoices, eliminating null values and improving
-- ----------------------------------------------------------------------------------------------------------------------------------	
-- 2.	Sales Agent Ranking: Calculate the total sales amount handled by each Sales Support Agent to measure individual performance.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
	CONCAT(e.FirstName, " " ,e.lastName) AS employeeName,
    SUM(i.total) AS totalRevenue
FROM Invoice AS i
JOIN customer AS c
	ON I.customerid = C.customerid
JOIN employee as e
	ON c.SupportRepId = e.employeeid
WHERE e.title = "Sales Support Agent" 
GROUP BY e.employeeid, e.FirstName, e.lastName
ORDER BY totalRevenue DESC;

-- select distinct(title) from employee;
-- Optimized by summing Invoice.Total directly and filtering for Sales Support Agents (General manager.. etc)
-- to ensure an accurate performance audit of the sales team.
-- ----------------------------------------------------------------------------------------------------------------------------------	
-- 3.	High-Value Transactions: Identify all invoices exceeding $5.6 to analyze premium purchasing patterns.
-- Business Case: Defining $5.6 as the Average for 'High-Value Transactions' to segment premium purchasing patterns and analyze top-tier revenue drivers.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
	invoiceid,
    total AS totalRevenue
FROM 
	invoice 
WHERE total > (SELECT AVG(total) FROM invoice)
ORDER BY totalRevenue DESC;
-- Filtering invoices exceeding $5.6 to identify high-spending customer segments.
-- Using the 'Total' column directly for maximum query efficiency.
-- -----------------------------------------
-- Let's Deep Dive -_-
-- Added 'numberOfItems' to distinguish between single high-priced purchases 
-- and bulk purchases of multiple items.
-- -----------------------------------------
SELECT 
    i.InvoiceId, 
    CONCAT(c.FirstName, " ",c.LastName) AS customerName, 
    i.Total AS Total_Amount,
    COUNT(il.Invoiceid) AS numberOfItems
FROM Invoice AS i
JOIN Customer AS c 
	ON i.CustomerId = c.CustomerId
JOIN InvoiceLine AS il 
	ON i.InvoiceId = il.InvoiceId
WHERE i.Total > (SELECT AVG(total) FROM invoice)
GROUP BY i.InvoiceId
ORDER BY Total_Amount DESC;
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 4. Average Order Value (AOV): Determine the average spend per invoice for each customer.
-- ----------------------------------------------------------------------------------------------------------------------------------
-- Provides insights into customer spending power and identifies premium 
-- clients who generate higher revenue per transaction.

SELECT 
    c.CustomerId, 
    CONCAT(c.FirstName, " ",c.LastName) AS customerName, 
    SUM(i.total) AS Total_Amount, 
    COUNT(i.invoiceid) AS NumInvoices, 
	ROUND(AVG(i.total),2) AS averge_order_value 
FROM Customer AS c
JOIN Invoice AS i 
    ON c.CustomerId = i.CustomerId
GROUP BY c.CustomerId, c.FirstName, c.LastName
ORDER BY averge_order_value DESC;	
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 5.	Year-over-Year (YoY) Growth: Compare total sales across different years to identify growth trends.
-- ----------------------------------------------------------------------------------------------------------------------------------
-- select distinct(year(invoicedate)) from invoice;

SELECT 
	YEAR(invoicedate) AS salesYear, 
    SUM(total) AS totalRevenue
FROM invoice
GROUP BY YEAR(invoicedate)
ORDER BY totalRevenue DESC;
-- --------------------------------------------
-- Let's Deep Dive
-- --------------------------------------------
-- Using LAG() to fetch previous year's data for direct comparison.
SELECT 
	YEAR(invoicedate) AS salesYear, 
    SUM(total) AS annualRevenue,
    LAG(SUM(total)) OVER(ORDER BY YEAR(invoicedate)) AS previousYearRevenue
FROM invoice
GROUP BY YEAR(invoicedate)
ORDER BY salesYear;
-- --------------------------------------------
-- Let's Deep Dive
-- --------------------------------------------
-- Utilizing Window Functions (LAG) to calculate the year-on-year growth percentage,
-- providing insights into the company's financial trajectory.
-- Let's Create View ...
-- ------------------------------
START TRANSACTION;
DROP VIEW IF exists YOY_Growth;
CREATE VIEW YOY_Growth AS 
-- ------------------------------
SELECT 
	YEAR(invoicedate) AS salesYear, 
    SUM(total) AS annualRevenue,
    -- Lag(SUM(total)) OVER(ORDER BY YEAR(invoicedate)) AS previousYearRevenue,
    -- (current - previous) / previous
    CONCAT(ROUND(
		(SUM(total) - LAG(SUM(total)) OVER (ORDER BY YEAR(invoicedate))) / -- (current - previous) / previous
        LAG(SUM(total)) OVER (ORDER BY YEAR(invoicedate)) * 100, 2
        ), " %") AS growthPercentage,
		CASE 
	WHEN ROUND(
		(SUM(total) - LAG(SUM(total)) OVER (ORDER BY YEAR(invoicedate))) / -- (current - previous) / previous
        LAG(SUM(total)) OVER (ORDER BY YEAR(invoicedate)) * 100, 2
        ) > 0 THEN "Peak"
        WHEN LAG(SUM(total)) OVER (ORDER BY YEAR(invoicedate)) IS NULL THEN NULL
		ELSE "Warning"
	END AS typeGrowth
FROM invoice
GROUP BY YEAR(invoicedate)
ORDER BY salesYear;
-- ------------------------------------------ 
COMMIT;
-- ------------------------------------------
SELECT * FROM YOY_Growth;

-- ----------------------------------------------------------------------------------------------------------------------------------
-- 6.	Running Revenue: Calculate a cumulative (running) total of sales over time to visualize financial momentum.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
	Invoicedate,
    total,
    SUM(total) OVER(ORDER BY (invoicedate)) AS cumulative_total
FROM invoice;
-- SELECT SUM(total) from invoice ; -- Data Validation 



-- -----------------------------------
-- Phase 1 is Done 🔐🚀
-- -----------------------------------