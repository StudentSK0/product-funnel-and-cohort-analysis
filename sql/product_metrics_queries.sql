-- Product Funnel and Cohort Analysis
-- Dataset: Retailrocket ecommerce events
-- Expected table: events(timestamp, visitorid, event, itemid, transactionid, event_time)

-- 1. Event counts
SELECT
    event,
    COUNT(*) AS events_count,
    COUNT(DISTINCT visitorid) AS unique_visitors,
    COUNT(DISTINCT itemid) AS unique_items
FROM events
GROUP BY event
ORDER BY events_count DESC;

-- 2. User-level funnel
WITH visitor_flags AS (
    SELECT
        visitorid,
        MAX(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS has_view,
        MAX(CASE WHEN event = 'addtocart' THEN 1 ELSE 0 END) AS has_addtocart,
        MAX(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS has_transaction
    FROM events
    GROUP BY visitorid
)
SELECT
    SUM(has_view) AS users_viewed,
    SUM(CASE WHEN has_view = 1 AND has_addtocart = 1 THEN 1 ELSE 0 END) AS users_added_to_cart,
    SUM(CASE WHEN has_view = 1 AND has_transaction = 1 THEN 1 ELSE 0 END) AS users_purchased
FROM visitor_flags;

-- 3. Monthly cohort retention
WITH first_seen AS (
    SELECT
        visitorid,
        DATE_TRUNC('month', MIN(event_time)) AS cohort_month
    FROM events
    GROUP BY visitorid
),
activity AS (
    SELECT DISTINCT
        visitorid,
        DATE_TRUNC('month', event_time) AS activity_month
    FROM events
),
cohort_activity AS (
    SELECT
        f.cohort_month,
        DATE_DIFF('month', f.cohort_month, a.activity_month) AS cohort_index,
        COUNT(DISTINCT a.visitorid) AS active_users
    FROM first_seen f
    JOIN activity a
        ON f.visitorid = a.visitorid
    WHERE a.activity_month >= f.cohort_month
    GROUP BY f.cohort_month, cohort_index
)
SELECT
    cohort_month,
    cohort_index,
    active_users
FROM cohort_activity
ORDER BY cohort_month, cohort_index;

-- 4. Item-level conversion proxy
WITH item_events AS (
    SELECT
        itemid,
        COUNT(CASE WHEN event = 'view' THEN 1 END) AS views,
        COUNT(CASE WHEN event = 'addtocart' THEN 1 END) AS addtocarts,
        COUNT(CASE WHEN event = 'transaction' THEN 1 END) AS transactions
    FROM events
    GROUP BY itemid
)
SELECT
    itemid,
    views,
    addtocarts,
    transactions,
    addtocarts::DOUBLE / NULLIF(views, 0) AS view_to_cart_rate,
    transactions::DOUBLE / NULLIF(addtocarts, 0) AS cart_to_purchase_rate
FROM item_events
WHERE views >= 100
ORDER BY view_to_cart_rate DESC
LIMIT 20;
