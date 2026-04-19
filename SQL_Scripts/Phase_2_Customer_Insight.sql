-- ----------------------------------------------------------------------------------------------------------------------------------
-- Phase 2: Customer Insight (Demographics & Behavior)
-- Focus: Understanding the customer base and geographic reach.
-- ----------------------------------------------------------------------------------------------------------------------------------
USE Chinook;
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 1.	Top Spender (VIP): Identify the customer with the highest lifetime value (LTV) in the database.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
	CONCAT(c.FirstName, ' ', c.LastName) AS VIP_CustomerName,
	CONCAT(c.city, ', ', c.country) AS Location,
	c.Email,
	COUNT(i.InvoiceId) AS NumInvoices,
	ROUND(AVG(i.Total), 1) AS AvgInvoiceValue,
	SUM(i.Total) AS TotalRevenue
FROM Customer c
JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY c.CustomerId, c.FirstName, c.LastName, c.city, c.country, c.Email
ORDER BY TotalRevenue DESC;
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 2.	Above-Average Customers: Find customers who have spent more than the average total spend of the entire customer base.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
	CustomerName,
    Country,
    Email,
    TotalSpent
FROM 
(    SELECT 
		   c.CustomerId,
           CONCAT(c.FirstName, " ", c.LastName) AS CustomerName,
           c.Country,
           c.Email,
           SUM(i.Total) AS TotalSpent,
           AVG(SUM(i.Total)) OVER() AS average_spent
    FROM Customer c
    JOIN Invoice i 
		ON c.CustomerId = i.CustomerId
    GROUP BY c.CustomerId ) AS customer_behv
WHERE TotalSpent > average_spent
ORDER BY TotalSpent DESC
LIMIT 20 OFFSET 5;
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 3. Top Billing Cities: Rank cities by the number of invoices generated to identify urban sales hubs.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
    i.BillingCity,
    i.BillingCountry,
    COUNT(i.InvoiceId) AS Invoice_Count,
    ROUND(SUM(i.Total), 2) AS Total_Revenue,
    ROUND(AVG(i.Total), 2) AS Avg_Invoice_Value
FROM Invoice i
GROUP BY i.BillingCity, i.BillingCountry
-- Filtering out "One-Time" locations to focus on reliable markets.
HAVING COUNT(i.InvoiceId) > 1  -- Cities with more than 1 invoice
ORDER BY Total_Revenue DESC
LIMIT 10;
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 4.	International Reach: List all customers located outside the USA to analyze global expansion.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT c.Country,
       COUNT(DISTINCT c.CustomerId) AS Customer_Count,
       COUNT(i.InvoiceId) AS Total_Invoices,
       ROUND(SUM(i.Total), 2) AS Total_Revenue,
       ROUND(AVG(i.Total), 2) AS Avg_Invoice_Value,
       -- Business Case: Revenue Per Customer (LTV)
       -- This helps identify high-value countries even if they have fewer customers.
       ROUND((SUM(i.Total)/COUNT(DISTINCT c.CustomerId)), 2) AS Revenue_Per_Customer
FROM Customer c
LEFT JOIN Invoice i ON c.CustomerId = i.CustomerId 
WHERE c.Country != 'USA' -- OUTSIDE USA
GROUP BY c.Country
ORDER BY Total_Revenue DESC;
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 5. Top Markets per Genre: Identify the top 3 revenue-generating countries for each music genre.
-- ----------------------------------------------------------------------------------------------------------------------------------
WITH GenreSummary AS (
	-- CTE 1: Global Genre Performance
    SELECT 
        g.Name AS Genre,
        COUNT(DISTINCT i.BillingCountry) AS Countries,
        SUM(il.Quantity) AS Total_Tracks_Sold,
        ROUND(SUM(i.total), 2) AS Total_Revenue
    FROM Invoice i
    JOIN InvoiceLine il ON i.InvoiceId = il.InvoiceId
    JOIN Track t ON il.TrackId = t.TrackId
    JOIN Genre g ON t.GenreId = g.GenreId
    GROUP BY g.Name
),
-- -------------------------------------------------------------------------------------------
GenreCountryRank AS (
    SELECT 
    -- CTE 2: Regional Ranking per Genre
        g.Name AS Genre,
        i.BillingCountry,
        SUM(il.Quantity) AS Tracks_Sold,
        ROUND(SUM(i.total), 2) AS Revenue,
        -- Ranking countries within each genre based on spending.
        ROW_NUMBER() OVER (PARTITION BY g.Name ORDER BY SUM(i.total) DESC) AS Country_Rank
    FROM Invoice i
    JOIN InvoiceLine il ON i.InvoiceId = il.InvoiceId
    JOIN Track t ON il.TrackId = t.TrackId
    JOIN Genre g ON t.GenreId = g.GenreId
    GROUP BY g.Name, i.BillingCountry
)
-- -------------------------------------------------------------------------------------------
-- FINAL OUTPUT: Consolidating global stats with a visualized "Top 3 Countries" list.
SELECT 
    gs.Genre,
    gs.Countries,
    gs.Total_Tracks_Sold,
    gs.Total_Revenue,
    -- Data Storytelling: Creating a readable string of the top markets for each genre.
    GROUP_CONCAT(
        CONCAT(gc.BillingCountry, ' ($', gc.Revenue, ')') 
        ORDER BY gc.Country_Rank 
        SEPARATOR ' | '
    ) AS Top_3_Countries
FROM GenreSummary gs
LEFT JOIN GenreCountryRank gc ON gs.Genre = gc.Genre AND gc.Country_Rank <= 3
GROUP BY gs.Genre
ORDER BY gs.Total_Revenue DESC;


-- -----------------------------------
-- Phase 2 is Done 🔐🚀
-- -----------------------------------
