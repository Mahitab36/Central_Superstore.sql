USE [Central Superstore]

CREATE TABLE Customer (
CID NVARCHAR(20) PRIMARY KEY,
Cname NVARCHAR(30) NOT NULL ,
SegmentName NVARCHAR(50),
)

CREATE TABLE Products(
PID NVARCHAR(30) NOT NULL,
Pname NVARCHAR(250) NOT NULL ,
Category NVARCHAR(100) ,
SubCategory NVARCHAR(50),
CONSTRAINT PK_PRODUCT PRIMARY KEY (PID,Pname)
)

CREATE TABLE Locations(
PostalCode INT PRIMARY KEY,
Country NVARCHAR(20),
City NVARCHAR(20),
St NVARCHAR(20),
Region NVARCHAR(10)
)

CREATE TABLE Orders(
OrderID VARCHAR(30) PRIMARY KEY,
ShipMode NVARCHAR(30),
OrderDate DATE ,
ShipDate DATE ,
)

CREATE TABLE fact_Sales (
RawID INT PRIMARY KEY ,
OrderID VARCHAR(30) NOT NULL ,
CID NVARCHAR(20) NOT NULL,
PID NVARCHAR(30) NOT NULL,
Pname NVARCHAR(250) NOT NULL ,
PostalCode INT NOT NULL,
Sales DECIMAL(12,4),
Profit DECIMAL(12,4),
Discount DECIMAL(4,2),
Quantity INT 
CONSTRAINT FK_ORDER_SALES FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
CONSTRAINT FK_CUSTOMER_SALES FOREIGN KEY (CID) REFERENCES Customer(CID),
CONSTRAINT FK_PRODUCT_SALES FOREIGN KEY (PID,Pname) REFERENCES Products(PID,Pname),
CONSTRAINT FK_LOCATION_SALES FOREIGN KEY (PostalCode) REFERENCES Locations(PostalCode)
)



SELECT COUNT(*) 
FROM stg_Central_Superstore

INSERT INTO Customer (CID , Cname , SegmentName)
SELECT DISTINCT [Customer_ID],[Customer_Name], Segment
FROM stg_Central_Superstore

SELECT TOP 1 * FROM stg_Central_Superstore

INSERT INTO Products (PID,Pname,Category,SubCategory)
SELECT DISTINCT Product_ID , Product_Name , Category , Sub_Category
FROM stg_Central_Superstore

INSERT INTO Locations (PostalCode , Country , City , St , Region)
SELECT DISTINCT Postal_Code ,Country , City , State , Region 
FROM stg_Central_Superstore

INSERT INTO Orders (OrderID , ShipMode , OrderDate , ShipDate )
SELECT DISTINCT Order_ID , Ship_Mode , Order_Date , Ship_Date
FROM stg_Central_Superstore

INSERT INTO fact_Sales (RawID , OrderID , CID , PID , Pname , PostalCode , Sales , Profit , Discount , Quantity)
SELECT Row_ID , Order_ID , Customer_ID , Product_ID , Product_Name , Postal_Code , Sales , Profit , Discount , Quantity
FROM stg_Central_Superstore

SELECT COUNT(*) AS fact_rows , 
       SUM(Sales) AS Total_Sales,
       COUNT(DISTINCT OrderID) AS Total_Orders 
FROM fact_Sales

/* KPI Summary
Q1: Display the total sales , total profit , total number of distinct orders , and the overall 
profit margin perecentage for the entire company
*/
SELECT SUM(Sales) AS [Total Sales] , SUM(Profit) AS [Total Profit] ,
      COUNT(DISTINCT OrderID) AS [Total Orders], SUM(Profit) * 100.0 / SUM(Sales) AS [Profit Margin]
FROM fact_Sales

-- Profitablity 
-- Q2
SELECT P.Category , SUM(F.Sales) AS [Total Sales] , SUM(F.Profit) AS [Total Profits]
FROM Products P JOIN fact_Sales F  ON P.PID = F.PID AND P.Pname = F.Pname
GROUP BY P.Category
ORDER BY [Total Profits] DESC

-- Q3
SELECT P.Category , P.SubCategory ,SUM(F.Sales) [Total Sales]  , SUM(F.Profit) AS [Total Profits] ,
       CASE WHEN SUM(F.Profit) < 0 THEN 'Loss-making' 
           ELSE 'Profitable' END AS Status
FROM Products P JOIN fact_Sales F ON P.PID = F.PID AND P.Pname = F.Pname
GROUP BY P.Category , P.SubCategory
ORDER BY [Total Profits] ASC 

-- Q4
WITH Discount_Band AS (
SELECT CASE WHEN Discount  = 0   THEN 'No Discount'
            WHEN Discount <= 0.2 THEN '0:20%'
            WHEN Discount <= 0.4 THEN '21:40%'
            ELSE 'Over 40%'
        END DiscountBand , Sales , Profit 
FROM fact_Sales
)
SELECT DiscountBand , SUM(Sales)[Total Sales] , 
       SUM(Profit) [Total Profit], 
       SUM(Profit)*100.0 / SUM(Sales) [Margin] 
FROM Discount_Band
GROUP BY DiscountBand

-- Q5: Display the top 10 customers by total sales , showing customer name , total sales , total profit , and number of order
SELECT TOP 10 C.Cname [Customer Name] , 
           SUM(F.Sales) [Total Sales] , 
           SUM(F.Profit) [Total Profit] , 
           COUNT(DISTINCT F.OrderID) [Number of order]
FROM Customer C JOIN fact_Sales F ON C.CID = F.CID
GROUP BY C.Cname
ORDER BY [Total Sales] DESC 

-- Q6 : Display Ship Mode , total Sales , total profit , and average dayes Between order and ship Date (as Average Shoping Dayes)
SELECT O.ShipMode [Ship Mode] , 
      SUM(F.Sales) [Total Sales] , 
      SUM(F.Profit) [Total Profit], 
      AVG(DATEDIFF(DAY, O.OrderDate , O.ShipDate)) [Average Days]
FROM Orders O JOIN fact_Sales F ON O.OrderID = F.OrderID
GROUP BY ShipMode

/*Q7 : Display the top 10 products with the biggest total losses (negative profit), showing category 
and total quantity sold
*/
SELECT TOP 10 P.Pname , P.Category , SUM(F.Quantity) [Total Quantity] , SUM(F.Profit) [Total Profits] 
FROM Products P JOIN fact_Sales F ON P.PID = F.PID AND P.Pname = F.Pname
GROUP BY P.Pname ,P.Category
Having SUM(F.Profit) < 0 
ORDER BY [Total Profits] ASC 

-- Customer Behavior Queries 
-- Q8 : 
SELECT TOP 10 C.Cname , C.SegmentName , SUM(F.Sales) [Total Sales] , SUM(F.Profit) [Total Profit]
FROM Customer C JOIN fact_Sales F ON C.CID = F.CID
GROUP BY C.Cname , C.SegmentName 
ORDER BY [Total Sales] DESC

-- Q9: 
WITH Customer_Total AS (
SELECT CID , SUM(Sales) [Total Sales] 
FROM fact_Sales
GROUP BY CID
),
Customer_Tiers AS(
SELECT CID , [Total Sales],
       CASE WHEN [Total Sales] >= 2000 THEN 'VIP'
            WHEN [Total Sales] >= 500  THEN 'Regular'
            ELSE 'Occasional'
        END [Customer Tier]
FROM Customer_Total
)
SELECT [Customer Tier] , COUNT (*) [Number of customer], SUM([Total Sales]) [Sum Of Sales]
FROM Customer_Tiers
GROUP BY [Customer Tier]

-- Q10
WITH Order_Per_Customer AS (
SELECT CID , COUNT(DISTINCT OrderID) AS [Number of orders] 
FROM fact_Sales
GROUP BY CID 
)
SELECT CASE WHEN [Number of orders] = 1 THEN 'One Time'
            ELSE 'Repeat'
       END AS Buyer_Type,
COUNT(*) AS [Number of Customer]
FROM Order_Per_Customer 
GROUP BY CASE WHEN [Number of orders] = 1 THEN 'One Time'
              ELSE 'Repeat'  
              END 

-- Q11:
SELECT C.SegmentName , COUNT(DISTINCT C.CID) [Customers] , SUM(F.Sales) [Total Sales], SUM(F.Profit) [Total Profit] ,
       SUM(F.Profit)*100.0/SUM(F.Sales) [Margin]
FROM Customer C JOIN fact_Sales F ON C.CID = F.CID
GROUP BY C.SegmentName
ORDER BY [Total Sales] DESC 

-- Q12 :
SELECT C.Cname , SUM(F.Sales) [Total Sales]
FROM Customer C JOIN fact_Sales F ON C.CID = F.CID
GROUP BY C.CID , C.Cname
HAVING SUM(F.Sales) > (SELECT AVG(Cust_Sales) FROM (SELECT SUM(Sales) [Cust_Sales] FROM fact_Sales GROUP BY CID) AS T)
ORDER BY [Total Sales] DESC 

-- Sales Trends Queries :
-- Q13:
SELECT YEAR(O.OrderDate) [Order year] , SUM(F.Sales) [Total Sales] , SUM(F.Profit) [Total Profit]
FROM Orders O JOIN fact_Sales F ON O.OrderID = F.OrderID
GROUP BY YEAR(O.OrderDate)
ORDER BY [Order year]

-- Q14:
WITH Monthly AS (
SELECT YEAR(O.OrderDate) [Order Year], MONTH(O.OrderDate) [Order Month] , SUM(F.Sales) [Monthly Sales]
FROM Orders O JOIN fact_Sales F ON O.OrderID = F.OrderID
GROUP BY YEAR(O.OrderDate) , MONTH(o.OrderDate)
)
SELECT [Order Year] , [Order Month] , [Monthly Sales] 
FROM Monthly
ORDER BY [Order Year] , [Order Month]

-- Q15:
SELECT O.ShipMode , COUNT(*) [Line Item] , AVG(DATEDIFF(DAY,O.OrderDate,O.ShipDate)*1.0) [AVG Ship Days],
       SUM(F.Profit) [Total Profit]
FROM Orders O JOIN fact_Sales F ON O.OrderID = F.OrderID
GROUP BY O.ShipMode 
ORDER BY [AVG Ship Days]

-- KPI SUMMARY :
CREATE VIEW KPI_Yearly AS 
SELECT YEAR(O.OrderDate) [Order year] , SUM(F.Sales) [Total Sales] , SUM(F.Profit) [Total Profit],
       SUM(F.Profit)*100.0/SUM(F.Sales) [Margin] , COUNT (DISTINCT F.OrderID) [Total Orders]
FROM Orders O JOIN fact_Sales F ON O.OrderID = F.OrderID
GROUP BY YEAR(O.OrderDate)

SELECT *
FROM KPI_Yearly 
ORDER BY [Order year]

-- TOP CUSTOMER :
CREATE PROCEDURE Top_Customers 
AS BEGIN 
    SELECT TOP 10 C.Cname , C.SegmentName , SUM(F.Sales) [Total Sales]
    FROM Customer C JOIN fact_Sales F ON C.CID = F.CID
    GROUP BY C.Cname , C.SegmentName
    ORDER BY [Total Sales] DESC 
END

-- OPTIMIZATION :

CREATE NONCLUSTERED INDEX Fact_Product ON fact_Sales (PID , Pname) INCLUDE (Sales , Profit , Quantity)
CREATE NONCLUSTERED INDEX Fact_Customer ON fact_Sales (CID) INCLUDE (Sales , Profit)
CREATE NONCLUSTERED INDEX Fact_Order ON fact_Sales (OrderID) INCLUDE (Sales , Profit)
CREATE NONCLUSTERED INDEX Fact_Location ON fact_Sales (PostalCode) INCLUDE (Sales , Profit )

SELECT P.Category , SUM(F.Sales) [Total Sales] 
FROM Products P JOIN fact_Sales F ON P.PID = F.PID AND P.Pname = F.Pname
GROUP BY P.Category 



