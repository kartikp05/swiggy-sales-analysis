Select *
From Swiggy_Data
-- Data cleaning and Validation
-- Null check
Select
	Sum(Case When State IS NULL Then 1 Else 0 END) AS Null_State,
	Sum(Case When City IS NULL Then 1 Else 0 END) AS Null_City,
	Sum(Case When Order_Date IS NULL Then 1 Else 0 END) AS Null_Order_Date,
	Sum(Case When Restaurant_Name IS NULL Then 1 Else 0 END) AS Null_Restaurant_Name,
	Sum(Case When Location IS NULL Then 1 Else 0 END) AS Null_Location,
	Sum(Case When Category IS NULL Then 1 Else 0 END) AS Null_Category,
	Sum(Case When Dish_Name IS NULL Then 1 Else 0 END) AS Null_DishName,
	Sum(Case When Price_INR IS NULL Then 1 Else 0 END) AS Null_Price,
	Sum(Case When Rating IS NULL Then 1 Else 0 END) AS Null_Rating,
	Sum(Case When Rating_Count IS NULL Then 1 Else 0 END) AS Null_RatingCount
From Swiggy_Data

-- Empty or Blank strings
Select *
From Swiggy_Data
Where
State = '' Or City='' OR Restaurant_Name='' OR Location='' OR Category=''
OR Dish_Name=''

-- Duplicate Detection
Select
State,City,Order_Date,Restaurant_Name, Location, Category, Dish_Name, Price_INR,
Rating,Rating_Count, count(*) as Cnt
From Swiggy_Data
Group By
State,City,Order_Date,Restaurant_Name, Location, Category, Dish_Name, Price_INR,
Rating,Rating_Count
Having count(*)>1

-- Deleting duplicates
WITH CTE AS(
Select *, ROW_NUMBER() Over(
	Partition BY State,City,Order_Date,Restaurant_Name, Location, Category, Dish_Name, Price_INR,
Rating,Rating_Count
ORDER BY(Select Null)
) AS RN
From Swiggy_Data
)
Delete From CTE WHERE rn>1


--NEW TABLES
--Drop table Swiggy_orders;
--Drop table if exists dim_dish;
--drop table if exists dim__category;
--drop table if exists dim_restaurant;
--drop table if exists dim_location;
--drop table if exists dim_date;


-- CREATION OF DIMENSION TABLES AGAIN
--Date Dimension table
Create Table dim_date(
	date_id INT IDENTITY(1,1) PRIMARY KEY,
	Full_Date DATE UNIQUE,
	Year INT,
	Month INT,
	Month_Name varchar(20),
	Quarter INT,
	Day INT,
	Week INT
);

--INSERT
INSERT INTO dim_date(Full_Date,Year,Month,Month_Name,Quarter,Day,Week)
SELECT DISTINCT
	Order_Date,
	Year(Order_Date),
	Month(Order_Date),
	DATENAME(Month,Order_Date),
	DATEPART(Quarter,Order_Date),
	DAY(Order_Date),
	DATEPART(Week,Order_Date)
FROM Swiggy_Data
WHERE Order_Date IS NOT NULL;


--Location Dimension table
Create Table dim_location(
	location_id INT IDENTITY(1,1) PRIMARY KEY,
	State varchar(100),
	City varchar(100),
	Location varchar(200),
	UNIQUE (State,City,Location)
);

INSERT INTO dim_location(State,City,Location)
SELECT DISTINCT
	State,
	City,
	Location
From Swiggy_Data;

--Category Dimension table
Create table dim_category(
	category_id INT IDENTITY(1,1) PRIMARY KEY,
	Category VARCHAR(200) UNIQUE
);
INSERT INTO dim_category(Category)
SELECT DISTINCT
	Category
From Swiggy_Data;

--Restaurant Dimension table
CREATE TABLE dim_restaurant(
	restaurant_id INT IDENTITY(1,1) PRIMARY KEY,
	Restaurant_Name VARCHAR(200),
	location_id INT,
	UNIQUE(Restaurant_Name,location_id),
	Foreign key (location_id) REFERENCES dim_location(location_id)
);
INSERT INTO dim_restaurant(Restaurant_Name,location_id)
SELECT DISTINCT
	s.Restaurant_Name,
	dl.location_id
FROM Swiggy_Data s
JOIN dim_location dl
	ON dl.State = s.State
	AND dl.City = s.City
	AND dl.Location= s.Location;

--Dish Dimension Table
CREATE Table dim_dish(
	dish_id INT IDENTITY(1,1) PRIMARY KEY,
	Dish_Name VARCHAR(200),
	restaurant_id INT,
	category_id INT,
	UNIQUE(Dish_Name, restaurant_id,category_id),
	FOREIGN KEY(restaurant_id) REFERENCES dim_restaurant(restaurant_id),
	FOREIGN KEY (category_id) REFERENCES dim_category(category_id)
);
INSERT INTO dim_dish(Dish_Name,restaurant_id,category_id)
SELECT DISTINCT
	s.Dish_Name,
	dr.restaurant_id,
	dc.category_id
FROM Swiggy_Data s
Join dim_location dl
	ON dl.State=s.State
	AND dl.City = s.City
	AND dl.Location = s.Location
Join dim_restaurant dr
	ON dr.Restaurant_Name=s.Restaurant_Name
	AND dr.location_id = dl.location_id
Join dim_category dc
	ON dc.Category= s.Category;


--Creating Fact Table
CREATE TABLE Swiggy_Orders(
order_id INT IDENTITY(1,1) PRIMARY KEY,

date_id INT,
Price_INR DECIMAL(10,2),
Rating DECIMAL(4,2),
Rating_count INT,

location_id INT,
restaurant_id INT,
category_id INT,
dish_id INT,


FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
FOREIGN KEY (location_id) REFERENCES dim_location(location_id),
FOREIGN KEY (restaurant_id) REFERENCES dim_restaurant(restaurant_id),
FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
FOREIGN KEY (dish_id) REFERENCES dim_dish(dish_id)
);


INSERT INTO Swiggy_orders
(
	date_id,
	Price_INR,
	Rating,
	Rating_count,
	location_id,
	restaurant_id,
	category_id,
	dish_id
)
SELECT
	dd.date_id,
	s.Price_INR,
	s.Rating,
	s.Rating_Count,
	dl.location_id,
	dr.restaurant_id,
	dc.category_id,
	dsh.dish_id
FROM Swiggy_Data s
JOIN dim_date dd
	ON dd.Full_Date = s.Order_Date
JOIN dim_location dl
	ON dl.State = s.State
	AND dl.City= s.City
	AND dl.Location = s.Location
JOIN dim_restaurant dr
	ON dr.Restaurant_Name = s.Restaurant_Name
	AND dr.location_id= dl.location_id
JOIN dim_category dc
	ON dc.Category = s.Category
JOIN dim_dish dsh
	ON dsh.Dish_Name= s.Dish_Name
	AND dsh.restaurant_id= dr.restaurant_id
	AND dsh.category_id = dc.category_id;

	SELECT COUNT(*) FROM Swiggy_Data;
	SELECT COUNT(*) FROM Swiggy_Orders;

	SELECT * FROM Swiggy_Orders
	
	
	-- KPIs
	-- Total Orders
	SELECT COUNT(*) AS Total_Orders FROM Swiggy_Orders;

	--Total Revenue
	SELECT
	FORMAT(SUM(CONVERT(FLOAT,Price_INR))/10000000,'N2')+'INR Crore'
	AS Total_Revenue
	FROM Swiggy_Orders;

	--Avg dish price
	SELECT
	FORMAT(AVG(CONVERT(FLOAT,Price_INR)),'N2')+'INR'
	AS Total_Revenue
	FROM Swiggy_Orders;

	-- AVG RATING
	SELECT
	AVG(Rating) as Avg_Rating
	From Swiggy_Orders;

--Granualar Requirements
--Monthly Orders(YYYY-MM)
SELECT 
d.Year,
d.Month,
d.Month_Name,
count(*) As Total_Orders
From Swiggy_Orders f
Join dim_date d ON f.date_id= d.date_id
GROUP BY d.Year,
d.Month,
d.Month_Name
ORDER BY count(*)


-- Quarterly Trends
SELECT 
d.Year,
d.Quarter,
count(*) As Total_Orders
From Swiggy_Orders f
Join dim_date d ON f.date_id= d.date_id
GROUP BY d.Year,
d.Quarter
ORDER BY count(*) DESC

--Yearly Trends
SELECT 
d.Year,
count(*) As Total_Orders
From Swiggy_Orders f
Join dim_date d ON f.date_id= d.date_id
GROUP BY d.Year
Order By count(*) DESC

--Orders by Day of Week
Select 
	DATENAME(Weekday,d.full_date) AS Day_Name,
	Count(*) AS Total_Orders
FROM Swiggy_Orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY DATENAME(WEEKDAY,d.full_date),DATEPART(WEEKDAY,d.full_date)
ORDER BY DATEPART(WEEKDAY, d.full_date);


--LOCATION BASED ANALYSIS
--TOP 10 CITIES BY ORDER VOLUME
SELECT TOP 10
l.City,
COUNT(*) AS Total_Orders FROM Swiggy_Orders f
JOIN dim_location l ON f.location_id = l.location_id 
GROUP BY l.City 
ORDER BY COUNT(*) DESC 

--REVENUE BY STATES
SELECT
l.State,
SUM(f.Price_INR) AS Total_Revenue FROM Swiggy_Orders f
JOIN dim_location l ON f.location_id = l.location_id 
GROUP BY l.State 
ORDER BY SUM(f.price_INR) DESC 

--Top 10 restaurants by order
SELECT TOP 10
r.restaurant_name,
SUM(f.Price_INR) AS Total_Revenue FROM Swiggy_Orders f
JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_name
ORDER BY SUM(f.price_INR) DESC

-- Top categories by order volume
SELECT 
	c.category,
	Count(*) AS Total_Orders
FROM Swiggy_Orders f
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.Category
ORDER BY Total_Orders DESC;

--Most Orddered Dish
SELECT
	d.Dish_Name, 
	Count(*) AS order_count 
FROM Swiggy_Orders f 
JOIN dim_dish d ON f.dish_id = d.dish_id 
GROUP BY d.Dish_Name 
ORDER BY order_count DESC;


 --Cuisine Performance (ORDER +avg rating)
 SELECT
	c.category, 
	Count(*) AS Total_Orders,
	AVG(CONVERT(FLOAT,f.rating)) AS AVG_Rating
FROM Swiggy_Orders f 
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY Total_Orders DESC;

--Customer Spending Insights

SELECT 
	CASE
		WHEN CONVERT(FLOAT,Price_INR)< 100 THEN 'Under 100'
		WHEN CONVERT(FLOAT,Price_INR) BETWEEN 100 AND 199 THEN '100-199'
		WHEN CONVERT(FLOAT,Price_INR) BETWEEN 200 AND 299 THEN '200-299'
		WHEN CONVERT(FLOAT,Price_INR) BETWEEN 300 AND 499 THEN '300-499'
		ELSE 'Above 500'
	END AS price_range,
	COUNT(*) AS Total_Orders
FROM Swiggy_Orders
GROUP BY 
	CASE
		WHEN CONVERT(FLOAT,Price_INR)< 100 THEN 'Under 100'
		WHEN CONVERT(FLOAT,Price_INR) BETWEEN 100 AND 199 THEN '100-199'
		WHEN CONVERT(FLOAT,Price_INR) BETWEEN 200 AND 299 THEN '200-299'
		WHEN CONVERT(FLOAT,Price_INR) BETWEEN 300 AND 499 THEN '300-499'
		ELSE 'Above 500'
	END
ORDER BY Total_Orders DESC;

--Rating Count Distribution
SELECT 
	rating,
	COUNT(*) AS Rating_count
FROM Swiggy_Orders
Group by rating
Order BY rating;

	


