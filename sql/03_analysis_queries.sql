/* =============================================================
   Porsche Sales Database - Analysis Queries (T-SQL / SQL Server)
   Run after 01_schema.sql and 02_seed_data.sql
   Techniques: CTEs, subqueries (FROM / HAVING), multi-table JOINs,
   CASE, aggregations, UNION / INTERSECT / EXCEPT
   ============================================================= */
USE Porsche;
GO

--cte שמציג את המוכרים עם ממוצע מכירות גבוה ממוצע המכירות הכללי לשנת 2022
WITH Sales2022 AS (
    SELECT Seller_ID, Sold_Price
    FROM Sales
    WHERE YEAR(Sold_Date) = 2022
),
AveragePerSeller AS (
    SELECT Seller_ID, AVG(Sold_Price) AS Average_Sale_Price
    FROM Sales2022
    GROUP BY Seller_ID
),
OverallAverage AS (
    SELECT AVG(Sold_Price) AS Overall_Average_Price
    FROM Sales2022
)

SELECT aps.Seller_ID, aps.Average_Sale_Price
FROM AveragePerSeller aps, OverallAverage oa
WHERE aps.Average_Sale_Price > oa.Overall_Average_Price;




-- תציג לי את כל דגמי הטורבו שהיו רק בידיים פרטיות, לא משנה כמות הידיים והקילומטראג׳ לא גדול מ20000
SELECT *
FROM CARS
WHERE Title LIKE '%Turbo%' and owners LIKE '_Previous owners' 
      AND Mileage BETWEEN 0 and 20000;


--סכום המכירות הרכבים בכל מדינה בצד המערבי של ארצות הברית
SELECT 
    z.State, 
    SUM(Sold_Price) AS Total_Sales_Income
FROM 
    Customers c
JOIN 
    ZipCodes z ON c.ZipCodeID = z.ZipCodeID
JOIN 
    Sales sa ON c.ID_NUMBER = sa.ID_NUMBER
WHERE 
    z.State IN ('California', 'Oregon', 'Washington', 'Nevada', 'Idaho',
                 'Montana', 'Wyoming', 'Utah', 'Colorado', 'Alaska', 'Hawaii')
GROUP BY 
    z.State
order by Total_Sales_Income desc;


--הממשלה הוציאה חוק שרכבים שגילם מעל 20 שנים חייבים בטסט כל חצי שנה,
-- רכבים בני 10-19 חייבים בטסט כל שנה
--רכבים בני3-9 חייבים בטסט כל שנה וחצי
-- רכבים בני 0-2 חייבם בטסט פעם בשנה:
SELECT 
    Chassis, Title, YEAR, (YEAR(GETDATE()) - YEAR) AS Car_Age,
    CASE
        WHEN (YEAR(GETDATE()) - YEAR) >= 20 THEN 'Test every 6 months'
        WHEN (YEAR(GETDATE()) - YEAR) BETWEEN 10 AND 19 THEN 'Test every year'
        WHEN (YEAR(GETDATE()) - YEAR) BETWEEN 3 AND 9 THEN 'Test every 1.5 years'
        ELSE 'Test every 2 years'
    END AS Test_Frequency
FROM 
    CARS
ORDER BY YEAR ASC;--יציג את השנים בסדר עולה



-- חישוב סך עלות השירותים לכל רכב ובחירת אלו שגבוהים מהממוצע בעזרת תת שאילתת having
SELECT Chassis, SUM(Service_Cost) AS Total_Service_Cost
FROM Services
GROUP BY Chassis
HAVING SUM(Service_Cost) > (
    SELECT AVG(Total_Service_Cost)
    FROM (
        SELECT Chassis, SUM(Service_Cost) AS Total_Service_Cost
        FROM Services
        GROUP BY Chassis
    ) AS Service_Avg
);

--עוד פתרון לחישוב  תת שאילתה from:
SELECT s.Chassis, s.Total_Service_Cost
FROM (
    -- תת-שאילתה: חישוב סך כל עלות השירותים לכל רכב
    SELECT Chassis, SUM(Service_Cost) AS Total_Service_Cost
    FROM Services
    GROUP BY Chassis
) AS s
-- השוואה לממוצע הכללי של כל הרכבים
WHERE s.Total_Service_Cost > (
    SELECT AVG(Total_Service_Cost)
    FROM (
        SELECT Chassis, SUM(Service_Cost) AS Total_Service_Cost
        FROM Services
        GROUP BY Chassis
    ) AS avg_services
);



--מציאת השירות היקר ביותר לכל רכב עם תת שאילתה from:
SELECT s.Chassis, s.Service_Type, s.Service_Cost
FROM Services s
INNER JOIN (
    -- תת-שאילתת FROM: מציאת השירות היקר ביותר לכל רכב
    SELECT Chassis, MAX(Service_Cost) AS Max_Service_Cost
    FROM Services
    GROUP BY Chassis
) AS max_services 
ON s.Chassis = max_services.Chassis 
AND s.Service_Cost = max_services.Max_Service_Cost;


-- יציג לנו בסדר יורד  את מספר הלקוחות שביצעו רכישה אחת לפחות מכל מדינה בצד המזרחי של ארצות הברית
SELECT z.State, COUNT(DISTINCT c.ID_NUMBER) AS Customer_Count
FROM Customers c
JOIN ZipCodes z ON c.ZipCodeID = z.ZipCodeID
JOIN Sales s ON c.ID_NUMBER = s.ID_NUMBER
WHERE z.State IN (
    'Maine', 'New Hampshire', 'Vermont', 'Massachusetts', 'Rhode Island', 'Connecticut',
    'New York', 'New Jersey', 'Pennsylvania', 'Delaware', 'Maryland', 'Virginia',
    'West Virginia', 'North Carolina', 'South Carolina', 'Georgia', 'Florida'
)
GROUP BY z.State
ORDER BY Customer_Count DESC;

--תציג את מספר המוכרים שלא ביצעו מכירה בכלל
SELECT Seller_ID FROM Sellers
EXCEPT
SELECT Seller_ID FROM Sales;


-- תציג לי את החברות שמבוטחות בחברת ביטוח מספר 1 או 2
SELECT s.Seller_ID, s.Seller_Name
FROM Sellers s
JOIN DealersWithInsurances dwi ON s.Seller_ID = dwi.Seller_ID
WHERE dwi.InsuranceID = 1

UNION

SELECT s.Seller_ID, s.Seller_Name
FROM Sellers s
JOIN DealersWithInsurances dwi ON s.Seller_ID = dwi.Seller_ID
WHERE dwi.InsuranceID = 2;


--תציג את הרכבים, בעליהם, שנת ייצור ומספר ביטוח שהם בני פחות מ4 שנים ומבוטחים בביטוח מקיף
SELECT p.PolicyID, c.Chassis, c.YEAR AS Car_Year, cu.Customer_FULL_NAME, p.Insurance_Type
FROM Policy p
JOIN Sales s ON p.Chassis = s.Chassis
JOIN Customers cu ON s.ID_NUMBER = cu.ID_NUMBER
JOIN CARS c ON p.Chassis = c.Chassis
WHERE p.Insurance_Type = 'Comprehensive'

INTERSECT

SELECT p.PolicyID, c.Chassis, c.YEAR AS Car_Year, cu.Customer_FULL_NAME, p.Insurance_Type
FROM Policy p
JOIN Sales s ON p.Chassis = s.Chassis
JOIN Customers cu ON s.ID_NUMBER = cu.ID_NUMBER
JOIN CARS c ON p.Chassis = c.Chassis
WHERE (YEAR(GETDATE()) - c.YEAR) < 4;


--מציאת השנה שבה נמכר הכי הרבה בסדר יורד
SELECT YEAR(Sold_Date) AS Sale_Year, SUM(Sold_Price) AS Yearly_Revenue
FROM Sales
GROUP BY YEAR(Sold_Date)
ORDER BY Yearly_Revenue DESC;

--מציאת המוכרים שסך המכירות שלהם מעל מליון דולר
SELECT Seller_ID, SUM(Sold_Price) AS Total_Sales
FROM Sales
GROUP BY Seller_ID
HAVING SUM(Sold_Price) > 1000000;



