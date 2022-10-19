-- Create database
CREATE DATABASE final_assgn;

-- set default database
USE final_assgn;

-- Create table structure to import data from cmd propt
CREATE TABLE events(
event_time VARCHAR(150),
event_type VARCHAR(150),
product_id VARCHAR(150),
category_id VARCHAR(150),
category_code VARCHAR(150),
brand VARCHAR(150),
price VARCHAR(150),
user_id VARCHAR(150),
user_session VARCHAR(150));

-- Uploading data from cmd prompt

-- Checking the uploaded data
SELECT * FROM events;

					-- Data Wrangling --
-- disabling safe update mode
SET SQL_SAFE_UPDATES =0;

-- removing UTC from event_time 
UPDATE events 
SET event_time = trim('UTC' from event_time);

-- Checking the updated data
SELECT * FROM events LIMIT 20;


-- updating UTC to IST
UPDATE events
SET event_time = convert_tz(event_time, '+00:00', '+05:30');


-- Checking the updated data
SELECT * FROM events LIMIT 20;


-- Altering the datatype of some columns


-- CHECK TABLE schema
DESC events;


-- This is how our recors look like

-- Creating a small view to check data
CREATE VIEW eve AS
(SELECT * FROM events LIMIT 1000);

-- checking view
SELECT * FROM eve;

-- event_type
-- cheking total counts of event_type and its total_price
SELECT event_type, COUNT(*) total_count, round(SUM(price),2) total_price 
FROM events GROUP BY event_type;

-- product_id
SELECT COUNT(DISTINCT product_id) as total_product_ids FROM events;

-- category_id
SELECT DISTINCT category_id, COUNT(*) category_count,round(SUM(price),2) total_price 
FROM events GROUP BY category_id;

-- category id and event type
SELECT DISTINCT category_id, event_type, COUNT(*) category_count, round(SUM(price),2) total_price 
FROM events GROUP BY category_id, event_type;

-- category_code
SELECT COUNT( DISTINCT category_code) total_category_code FROM events;

-- brand
SELECT COUNT(DISTINCT brand) total_brands FROM events;

-- user_id
SELECT COUNT( DISTINCT user_id) users FROM events;

-- user_sessions
SELECT COUNT( DISTINCT user_session) user_sessions FROM events;


			-- 1) Month of Sales --
-- Top Months in DESC order by all events
SELECT year(event_time) year, month(event_time) month, round(SUM(price),2)  total_price
FROM events
GROUP BY year, month
ORDER BY total_price DESC;

-- Top months total sales i.e. where event is 'Purchase'
SELECT year(event_time) year, month(event_time) month, round(SUM(price),2)  total_price
FROM events
WHERE event_type = 'purchase'
GROUP BY year, month
ORDER BY total_price DESC;


-- 2)Top Time of Visit: --
/* Creating time bins:
			12am - 4am --> 'Late Night'
            4am - 8am --> 'Early Morning'
            8am - 12pm --> 'Morning'
            12pm - 4pm --> 'Aftenoon'
            4pm - 8pm --> 'Evening'
            8pm - 12am --> 'Night'            
*/
-- Checking total visit by event_time category
WITH cte AS
(SELECT *, CASE
			WHEN TIME(event_time) BETWEEN '00:00:00' AND '04:00:00' THEN 'Late Night'
            WHEN TIME(event_time) BETWEEN '04:00:00' AND '08:00:00' THEN 'Early Morning'
            WHEN TIME(event_time) BETWEEN '08:00:00' AND '12:00:00' THEN 'Morning'
            WHEN TIME(event_time) BETWEEN '12:00:00' AND '16:00:00' THEN 'Afternoon'
            WHEN TIME(event_time) BETWEEN '16:00:00' AND '20:00:00' THEN 'Evening'
            WHEN TIME(event_time) BETWEEN '20:00:00' AND '24:00:00' THEN 'Night'
            END event_time_category
            FROM events)
SELECT *, RANK() OVER(PARTITION BY event_type ORDER BY total_visits DESC) as rn FROM 
	(SELECT event_time_category, event_type, COUNT(*) as total_visits
	FROM cte
	GROUP BY event_time_category, event_type
	ORDER BY total_visits DESC)x;


-- Checking top 2 times to visit in each caterory
WITH cte AS
(SELECT *, CASE
			WHEN TIME(event_time) BETWEEN '00:00:00' AND '04:00:00' THEN 'Late Night'
            WHEN TIME(event_time) BETWEEN '04:00:00' AND '08:00:00' THEN 'Early Morning'
            WHEN TIME(event_time) BETWEEN '08:00:00' AND '12:00:00' THEN 'Morning'
            WHEN TIME(event_time) BETWEEN '12:00:00' AND '16:00:00' THEN 'Afternoon'
            WHEN TIME(event_time) BETWEEN '16:00:00' AND '20:00:00' THEN 'Evening'
            WHEN TIME(event_time) BETWEEN '20:00:00' AND '24:00:00' THEN 'Night'
            END event_time_category
            FROM events),
cte2 AS
(SELECT event_time_category, event_type, COUNT(*) as total_visits, 
			ROW_NUMBER() OVER(PARTITION BY event_type) rnk
FROM cte
GROUP BY event_time_category, event_type
ORDER BY total_visits DESC)
SELECT * from cte2 WHERE rnk<=2;



-- 3) Top brands by Sale: 
-- Checking top 10 brands sales i.e. purchased
SELECT brand, round(SUM(price),2) total_price FROM events
WHERE event_type = 'purchase'
GROUP BY brand
ORDER BY total_price DESC
LIMIT 10;


-- 4)Demand for Items: 
-- Checking most demanded categpries which were sold i.e. 'purchase' event_type
SELECT category_code AS category, COUNT(*) total_sold_time FROM events
WHERE event_type = 'purchase'
GROUP BY category_code
ORDER BY total_sold_time DESC
LIMIT 6;


-- 5)Frequency of Purchase:
-- We only have data of one user so we'll check how many time user has purchased in every month
SELECT year(event_time) year, month(event_time) month, COUNT(*) times_sold  FROM events
WHERE event_type = 'purchase'
GROUP BY year,month
ORDER BY times_sold DESC;


-- 6)Actual Time purchased:
WITH 
	cte AS
		(	SELECT event_type, COUNT(*) total_events FROM events
			GROUP BY event_type),
	view_purchase AS
    (	SELECT (        
				((SELECT total_events FROM cte WHERE event_type = 'purchase')/
					(SELECT total_events FROM cte WHERE event_type = 'view'))*100 ) 
				AS "%_view_purchase"),
	view_cart AS
		(	SELECT (        
					((SELECT total_events FROM cte WHERE event_type = 'cart')/
						(SELECT total_events FROM cte WHERE event_type = 'view'))*100 ) 
					AS "%_view_cart"),
	cart_purchase AS
		(	SELECT (        
					((SELECT total_events FROM cte WHERE event_type = 'purchase')/
						(SELECT total_events FROM cte WHERE event_type = 'cart'))*100 ) 
					AS "%_cart_purchase")
SELECT * from view_cart,cart_purchase,view_purchase;


