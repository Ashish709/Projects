-- Create database
CREATE DATABASE plantix;

-- set default database
USE plantix;

-- Create table structure to import data from cmd propt
CREATE TABLE login_logs(
login_log_id INT,
user_id INT,
login_time VARCHAR(200));

CREATE TABLE sales_orders(
order_id INT,
fk_buyer_id INT,
fk_depot_id INT,
sales_order_status VARCHAR(50),
creation_time VARCHAR(200));

CREATE TABLE sales_orders_items(
order_item_id INT,
fk_product_id INT,
fk_order_id INT,
ordered_quantity INT,
order_quantity_accepted INT,
rate FLOAT);

-- Uploading data from cmd prompt

-- Checking the uploaded data
SELECT * FROM login_logs;
SELECT * FROM sales_orders;
SELECT * FROM sales_orders_items;

-- Changing tables datatypes
DESC login_logs;
DESC sales_orders;

-- creating view with total price
CREATE VIEW sales_orders_items_price AS
	(SELECT *,round((order_quantity_accepted * rate),2) AS price FROM sales_orders_items);

SELECT * FROM sales_orders_items_price;

-- 1. Which KPIs would you use to measure the performance of our app?

-- A. Retention
-- total users in each year
SELECT year(login_time) year, COUNT(DISTINCT user_id) total_users FROM login_logs GROUP BY year;


-- retained users in 2022
SELECT COUNT(DISTINCT user_id) retained_users FROM login_logs WHERE year(login_time)='2022' AND user_id IN
				(SELECT DISTINCT user_id FROM login_logs WHERE year(login_time)='2021');
                
-- Retention Rate
SELECT round((
(SELECT COUNT(DISTINCT user_id) retained_users FROM login_logs WHERE year(login_time)='2022' AND user_id IN
				(SELECT DISTINCT user_id FROM login_logs WHERE year(login_time)='2021') )/ 
(SELECT COUNT(DISTINCT user_id) total_users FROM login_logs WHERE year(login_time)='2021')),2) as retention_rate;


-- B. Churning						
-- total new uesr in 2022
SELECT COUNT(DISTINCT user_id) new_users FROM login_logs WHERE year(login_time)='2022' AND user_id NOT IN
				(SELECT DISTINCT user_id FROM login_logs WHERE year(login_time)='2021');

-- churned users of 2021
SELECT(
(SELECT COUNT(DISTINCT user_id) total_users FROM login_logs WHERE year(login_time)='2021')-
(SELECT COUNT(DISTINCT user_id) retained_users FROM login_logs WHERE year(login_time)='2022' AND user_id IN
				(SELECT DISTINCT user_id FROM login_logs WHERE year(login_time)='2021'))) AS churned_users;
                
-- churning rate
WITH cte AS(
	SELECT round((
	(SELECT COUNT(DISTINCT user_id) retained_users FROM login_logs WHERE year(login_time)='2022' AND user_id IN
					(SELECT DISTINCT user_id FROM login_logs WHERE year(login_time)='2021') )/ 
	(SELECT COUNT(DISTINCT user_id) total_users FROM login_logs WHERE year(login_time)='2021')),2) as retention_rate)
SELECT 1 - (SELECT retention_rate FROM cte) as churing_rate;


-- C. Daily Active Users
SELECT year(login_time) year, day(login_time) day, COUNT(*) total_users FROM login_logs
GROUP BY year,day;


-- D. Daily no of users who ordered
SELECT year(creation_time) year, day(creation_time) day, COUNT(*) total_users FROM sales_orders
GROUP BY year,day;

-- E. Top 10 buying users (Lifetime Value)
SELECT fk_buyer_id AS user_id,
		round(SUM(price),2) total_sales
FROM sales_orders_items_price sip
JOIN sales_orders so ON sip.fk_order_id = so.order_id
GROUP BY fk_buyer_id
ORDER BY total_sales DESC
LIMIT 10;


-- F. Top 10 visited users (Lifetime)
SELECT user_id, COUNT(*) total_visits FROM login_logs
GROUP BY user_id
ORDER BY total_visits DESC
LIMIT 10;



-- 2. Prepare a report regarding our growth between the 2 years. Please try to answer the following questions:
-- A. Did our business grow?
WITH cte AS (
SELECT year(creation_time) year, round(SUM(price),2) total_revenue FROM sales_orders AS so
JOIN sales_orders_items_price AS sip  ON so.order_id = sip.fk_order_id
GROUP BY year)
SELECT * , total_revenue - LAG(total_revenue,1) OVER() revenue_growth,
round((total_revenue/LAG(total_revenue) OVER() *100)-100,2) 'growth%' FROM cte;


-- b. Does our app perform better now?
-- Sales orders performance optimization 
SELECT x.sales_order_status, 
x.total_orders AS total_orders_2022, 
y.total_orders AS total_orders_2021,
round(((x.total_orders/y.total_orders)*100)-100,2) AS 'growth_%_21_to_22'
FROM
		(SELECT year(creation_time) year, sales_order_status, COUNT(*) AS total_orders FROM sales_orders
		WHERE year(creation_time) = '2022'
		GROUP BY year, sales_order_status) x 
LEFT JOIN
		(SELECT year(creation_time) year, sales_order_status, COUNT(*) AS total_orders FROM sales_orders
		WHERE year(creation_time) = '2021'
		GROUP BY year, sales_order_status) y
ON x.sales_order_status = y.sales_order_status;

-- How many order qunatity accepted out off total ordered quantity
WITH cte AS
	(SELECT year(creation_time) year, 
	SUM(ordered_quantity) total_ordered_items , 
	SUM(order_quantity_accepted) total_accepted_items 
	FROM sales_orders_items soi
	JOIN sales_orders so ON so.order_id = soi.fk_order_id 
	GROUP BY year)
SELECT year,
total_ordered_items as ttl_ord_itms,
round((total_ordered_items/LAG(total_ordered_items) OVER()*100)-100,2) AS 'ord_itms_growth%',
total_accepted_items as ttl_acc_itms,
round((total_accepted_items/LAG(total_accepted_items) OVER()*100)-100,2) AS 'ord_acc_growth%',
round(((total_ordered_items - total_accepted_items)/ 
			LAG(total_ordered_items - total_accepted_items) OVER() *100)-100,2)
			AS total_rejected_items
FROM cte;


-- c. Did our user base grow?
SELECT x.year, 
total_users, 
round((total_users/LAG(total_users)OVER() *100)-100,2)  AS total_users_gain,
ordered_users,
round((ordered_users/LAG(ordered_users)OVER() *100)-100,2) AS ordered_users_gain
FROM
	(SELECT year(login_time) year, COUNT(*) total_users FROM login_logs
	GROUP BY year) AS x,
	(SELECT year(creation_time) year, COUNT(*) ordered_users FROM sales_orders 
	GROUP BY year) y
WHERE x.year = y.year;




-- 3. What are our top-selling products in each of the two years? Can you draw some insight from this?
-- Top 10 sold products 
WITH cte AS(
	SELECT year(creation_time) year, fk_product_id AS product_id, COUNT(*) AS total_sold 
    FROM sales_orders_items_price sip
	JOIN sales_orders so ON so.order_id = fk_order_id
	GROUP BY fk_product_id,year
	ORDER BY total_sold DESC)
SELECT year, product_id, total_sold FROM(
					SELECT *, ROW_NUMBER() OVER(PARTITION BY year) AS rn FROM cte) x
WHERE rn <= 10;


-- Top 10 products which gave highest business
WITH cte AS(
	SELECT year(creation_time) year, fk_product_id AS product_id, round(SUM(price),2) AS total_sale 
    FROM sales_orders_items_price sip
	JOIN sales_orders so ON so.order_id = fk_order_id
	GROUP BY fk_product_id, year
	ORDER BY total_sale DESC)
SELECT year, product_id, total_sale FROM(
					SELECT *, ROW_NUMBER() OVER(PARTITION BY year) AS rn FROM cte) x
WHERE rn <= 10;




-- 4. Looking at July 2021 data, what do you think is our biggest problem and how would you recommend fixing it?
SELECT total_ordered_items,
total_accepted_items, 
round(total_accepted_items/total_ordered_items*100,2) AS 'Acc_%', 
total_ordered_items - total_accepted_items AS total_rejected_items,
round(((total_ordered_items - total_accepted_items)/total_ordered_items)*100,2) AS 'rej_%' 
FROM
	(SELECT year(creation_time) year, 
	SUM(ordered_quantity) total_ordered_items , 
	SUM(order_quantity_accepted) total_accepted_items 
	FROM sales_orders_items soi
	JOIN sales_orders so ON so.order_id = soi.fk_order_id 
	GROUP BY year)x;


-- 5. Does the login frequency affect the number of orders made?
-- A. Out off total users
WITH cte AS (
	SELECT x.year, x.day, total_users, ordered_users FROM
	(SELECT year(login_time) year, day(login_time) day, COUNT(*) total_users FROM login_logs
	GROUP BY year, day) AS x,
	(SELECT year(creation_time) year, day(creation_time) day, COUNT(*) ordered_users FROM sales_orders 
	GROUP BY year, day) y
	WHERE x.day = y.day AND x.year = y.year )
SELECT *, round((ordered_users/total_users)*100,2) AS '%total_ordred_users' FROM cte;

-- B. Out of total users who ordered
WITH cte AS (
	SELECT x.year, x.day, total_users, ordered_users FROM
	(SELECT year(login_time) year, day(login_time) day, COUNT(*) total_users FROM login_logs
    WHERE user_id IN ( SELECT fk_buyer_id FROM sales_orders)
	GROUP BY year, day) AS x,
	(SELECT year(creation_time) year, day(creation_time) day, COUNT(*) ordered_users FROM sales_orders 
	GROUP BY year, day) y
	WHERE x.day = y.day AND x.year = y.year )
SELECT *, round((ordered_users/total_users)*100,2) AS '%total_ordred_users' FROM cte;


SELECT year(creation_time) year, fk_product_id AS product_id, COUNT(*) AS total_sold 
    FROM sales_orders_items_price sip
	JOIN sales_orders so ON so.order_id = fk_order_id
    WHERE year(creation_time) = '2021'
	GROUP BY fk_product_id
	ORDER BY total_sold DESC;

SELECT * FROM login_logs;
SELECT * FROM sales_orders;
SELECT * FROM sales_orders_items;