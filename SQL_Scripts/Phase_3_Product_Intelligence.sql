-- =====================================================
-- CHINOOK PRODUCT INTELLIGENCE QUERIES
-- Phase 3: Content Strategy & Catalog Analysis
-- =====================================================
USE chinook;

-- =====================================================
-- PHASE 1: CATALOG OVERVIEW (Big Picture)
-- =====================================================
-- 1️) CATALOG HEALTH DASHBOARD (Start Here)
-- Overall performance metrics


SELECT 
    'Total Tracks' AS Metric,
    COUNT(TrackId) AS Value
FROM Track

UNION ALL

SELECT 
    'Tracks Sold',
    COUNT(InvoiceLineId)
FROM InvoiceLine

UNION ALL

SELECT 
    'Sell-Through Rate (%)',
    ROUND((COUNT(il.InvoiceLineId)*100.0/COUNT(t.TrackId)), 1)
FROM Track t
LEFT JOIN InvoiceLine il ON t.TrackId = il.TrackId

UNION ALL

SELECT 
    'Unique Genres',
    COUNT(DISTINCT GenreId)
FROM Genre

UNION ALL 
SELECT "Total_Media_Types", COUNT(*) FROM MediaType
UNION ALL 
SELECT "Total_Playlists" , COUNT(*) FROM Playlist 
UNION ALL

SELECT 
    'Active Artists',
    COUNT(DISTINCT ar.ArtistId)
FROM Artist ar
JOIN Album al ON ar.ArtistId = al.ArtistId
JOIN Track t ON al.AlbumId = t.AlbumId
LEFT JOIN InvoiceLine il ON t.TrackId = il.TrackId
WHERE il.InvoiceLineId IS NOT NULL

ORDER BY Value DESC;


-- =====================================================
-- 2️) GENRE POPULARITY - Market Leaders
-- Rank genres by tracks sold and revenue
-- =====================================================
WITH TotalRevenue AS (
    SELECT SUM(il.UnitPrice * il.Quantity) AS AllRevenue
    FROM InvoiceLine il
)
SELECT 
    g.Name AS Genre,
    COUNT(distinct il.InvoiceLineId) AS Tracks_Sold,
    -- SUM(il.Quantity) AS Total_Quantity,
    ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS Total_Revenue,
    -- ROUND(AVG(il.UnitPrice), 2) AS Avg_Price_Per_Track,
    -- Market share
    ROUND((SUM(il.UnitPrice * il.Quantity) / max(tr.AllRevenue)) * 100, 1) AS Revenue_Share_Percent
FROM Genre g
JOIN Track t ON g.GenreId = t.GenreId
JOIN InvoiceLine il ON t.TrackId = il.TrackId
CROSS JOIN TotalRevenue tr
GROUP BY g.Name
ORDER BY Total_Revenue DESC;

-- ===============================================================================================================================================================================
-- =====================================================
-- Phase 2: Content Performance (What Sells?)
-- =====================================================
-- ----------------------------------------------------------------------------------------------------------------------------------
-- 14.	Artist Inventory: Count the total number of unique artists to assess catalog diversity.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
    CONCAT(COUNT(DISTINCT ArtistId), " Artists") AS Total_Unique_Artists -- Using DISTINCT to ensure data integrity.
FROM Artist;
-- Total_Unique_Artists = 275
-- =====================================================
-- 1) TOP REVENUE ARTISTS 
-- Artists ranked by sales revenue
-- =====================================================
SELECT 
    ar.Name AS Artist,
    COUNT(DISTINCT al.AlbumId) AS Album_Count,
    COUNT(il.InvoiceLineId) AS Tracks_Sold,
    ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS Artist_Revenue,
    ROUND(AVG(il.UnitPrice), 2) AS Avg_Track_Price
FROM Artist ar
JOIN Album al ON ar.ArtistId = al.ArtistId
JOIN Track t ON al.AlbumId = t.AlbumId
JOIN InvoiceLine il ON t.TrackId = il.TrackId
GROUP BY ar.Name
HAVING COUNT(il.InvoiceLineId) > 0  -- Only artists with sales
ORDER BY Artist_Revenue DESC
LIMIT 10;

-- =====================================================
-- 2) MEDIA FORMAT PRICING 
-- Average price by media type (AAC vs MPEGaudio etc.)
-- =====================================================
SELECT 
    mt.Name AS Media_Type,
    COUNT(DISTINCT t.TrackId) AS Track_Count,
    COUNT(il.InvoiceLineId) AS Number_of_sales,
    ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS Total_Revenue,
    ROUND((COUNT(il.InvoiceLineId)/ COUNT(DISTINCT t.TrackId) * 100), 1) AS Persentage_of_sales
FROM MediaType mt
JOIN Track t ON mt.MediaTypeId = t.MediaTypeId
LEFT JOIN InvoiceLine il ON t.TrackId = il.TrackId
GROUP BY  mt.Name
ORDER BY Total_Revenue DESC;

-- =====================================================
-- 3) ALBUM vs SINGLE TRACK SALES 
-- Full albums vs individual tracks performance
-- =====================================================
WITH AlbumTracks AS (
    SELECT 
        al.Title AS Album_Name,
        ar.Name AS Artist,
        COUNT(t.TrackId) AS Total_Tracks,
        COUNT(il.InvoiceLineId) AS Tracks_Sold,
        -- SUM(CASE WHEN il.InvoiceLineId IS NOT NULL THEN 1 ELSE 0 END) AS Tracks_Sold, 
        ROUND((COUNT(il.InvoiceLineId)*100.0/COUNT(t.TrackId)), 1) AS Completion_Rate_Percent -- c
    FROM Album al
    JOIN Artist ar ON al.ArtistId = ar.ArtistId
    JOIN Track t ON al.AlbumId = t.AlbumId
    LEFT JOIN InvoiceLine il ON t.TrackId = il.TrackId
    GROUP BY al.Title, ar.Name
    HAVING COUNT(t.TrackId) > 1  -- Multi-track albums only
)
SELECT 
    Album_Name,
    Artist,
    Total_Tracks,
    Tracks_Sold,
    Completion_Rate_Percent,
    CASE 
        WHEN Completion_Rate_Percent >= 70 THEN 'High'
        WHEN Completion_Rate_Percent >= 40 THEN 'Medium' 
        ELSE 'Low'
    END AS Performance_Category
FROM AlbumTracks
ORDER BY Tracks_Sold DESC
LIMIT 20;

-- ===============================================================================================================================================================================
-- =====================================================
-- Phase 3: Customer Behavior (Local Tastes)
-- =====================================================

-- =====================================================
-- 1) LOCAL GENRE PREFERENCE 
-- Most popular genre in each country
-- =====================================================
WITH CountryGenreRank AS (
    SELECT 
        i.BillingCountry,
        g.Name AS Genre,
        SUM(il.Quantity) AS Tracks_Sold,
        ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS Revenue,
        ROW_NUMBER() OVER (
            PARTITION BY i.BillingCountry 
            ORDER BY SUM(il.UnitPrice * il.Quantity) DESC
        ) AS Genre_Rank
    FROM Invoice i
    JOIN InvoiceLine il ON i.InvoiceId = il.InvoiceId
    JOIN Track t ON il.TrackId = t.TrackId
    JOIN Genre g ON t.GenreId = g.GenreId
    GROUP BY i.BillingCountry, g.Name
    )
SELECT 
    BillingCountry,
    Genre AS Most_Popular_Genre,
    Tracks_Sold,
    Revenue
FROM CountryGenreRank
WHERE Genre_Rank = 1
ORDER BY Revenue DESC;

-- =====================================================
-- 2) PLAYLIST ENGAGEMENT 
-- Most popular tracks across all playlists
-- =====================================================
SELECT 
    t.Name AS Track_Name,
    al.Title AS Album,
    g.Name AS Genre,
    COUNT(pt.PlaylistId) AS Playlist_Count
FROM Track t
JOIN Album al ON t.AlbumId = al.AlbumId
JOIN Artist ar ON al.ArtistId = ar.ArtistId
JOIN Genre g ON t.GenreId = g.GenreId
LEFT JOIN PlaylistTrack pt ON t.TrackId = pt.TrackId
GROUP BY t.Name, ar.Name, al.Title, g.Name
ORDER BY Playlist_Count DESC
LIMIT 20;

-- =====================================================
-- 3) TRACK DURATION ANALYSIS 
-- Optimal track length for sales
-- =====================================================
SELECT 
    CASE 
        WHEN t.Milliseconds <= 120000 THEN 'Short (<2min)'
        WHEN t.Milliseconds <= 240000 THEN 'Medium (2-4min)'
        WHEN t.Milliseconds <= 360000 THEN 'Long (4-6min)'
        ELSE 'Very Long (>6min)'
    END AS Duration_Bucket,
    COUNT(t.TrackId) AS Total_Tracks,
    COUNT(il.InvoiceLineId) AS Sold_Tracks,
    ROUND((COUNT(il.InvoiceLineId)*100.0/COUNT(t.TrackId)), 1) AS Sell_Through_Rate,
    ROUND(AVG(il.UnitPrice), 2) AS Avg_Price,
    ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS Revenue
FROM Track t
LEFT JOIN InvoiceLine il ON t.TrackId = il.TrackId
GROUP BY 1
ORDER BY Sold_Tracks DESC;

-- ===============================================================================================================================================================================
-- =====================================================
-- Phase 4: Optimization Opportunities
-- =====================================================

-- =====================================================
-- 1) UNDERPERFORMING GENRES 
-- High inventory, low sales opportunity
-- =====================================================
WITH GenrePerformance AS (
    SELECT 
        g.Name AS Genre,
        COUNT(t.TrackId) AS Total_Tracks_Inventory,
        COUNT(il.InvoiceLineId) AS Sold_Tracks,
        COALESCE(SUM(il.Quantity * il.UnitPrice),0) AS Genre_Revenue,
        ROUND((COUNT(il.InvoiceLineId)*100.0/COUNT(t.TrackId)), 1) AS Sell_Through_Rate
    FROM Genre g
    JOIN Track t ON g.GenreId = t.GenreId
    LEFT JOIN InvoiceLine il ON t.TrackId = il.TrackId
    GROUP BY g.GenreId, g.Name
)
SELECT 
    Genre,
    Total_Tracks_Inventory,
    Sold_Tracks,
    Sell_Through_Rate,
    Genre_Revenue,
    CASE 
        WHEN Sell_Through_Rate < 20 AND Total_Tracks_Inventory > 50 THEN '🚨 High Opportunity'
        WHEN Sell_Through_Rate < 40 THEN '⚠️  Monitor'
        ELSE '✅ Good'
    END AS Opportunity_Status
FROM GenrePerformance
ORDER BY Sell_Through_Rate ASC;

-- ----------------------------------------------------------------------------------------------------------------------------------
-- 15.	Rock Genre Deep-Dive: Retrieve all tracks categorized under 'Rock' for a targeted promotional campaign.
-- ----------------------------------------------------------------------------------------------------------------------------------
SELECT 
    g.Name AS GenreName,
    t.Name AS TrackName,
    /* Handling Missing Metadata: 
       Replacing NULLs with 'Anonymous Composer' to maintain report aesthetic 
       and provide a seamless experience for the Marketing Team.
    */
    CASE 
		WHEN t.Composer IS NULL THEN "Anonymous Composer"
        ELSE t.Composer
	END AS Composer,
    t.UnitPrice
FROM Genre AS g 
JOIN Track AS t ON g.GenreId = t.GenreId 
WHERE g.Name = 'Rock' -- Filtering for our #1 revenue-generating genre.
ORDER BY t.Composer;

-- =====================================================
-- BONUS: ROCK GENRE DEEP-DIVE 
-- All Rock tracks for campaign planning
-- =====================================================
SELECT 
	g.Name AS Genre,
    al.Title AS Album,
    t.Name AS Track,
    CONCAT(ROUND(t.Milliseconds/1000/60, 2), ' min') AS Duration_Minutes,
    CONCAT(t.UnitPrice, ' $') AS Unit_Price
FROM Genre g
JOIN Track t ON g.GenreId = t.GenreId
JOIN Album al ON t.AlbumId = al.AlbumId
JOIN Artist ar ON al.ArtistId = ar.ArtistId
WHERE g.Name = 'Rock'
ORDER BY t.UnitPrice DESC
LIMIT 50;

-- =====================================================
-- END REPLACEMENT SECTION
-- =====================================================