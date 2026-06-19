CREATE DATABASE autogenai_db;

USE autogenai_db;

-- =====================================================
-- DATA OVERVIEW
-- Understanding the dataset scope and total activity volume
-- =====================================================

SELECT
COUNT(*) AS total_rows
FROM analytics_task_data;




-- =====================================================
-- DAILY ACTIVE USERS (DAU)
-- Understanding overall platform activity trends
-- =====================================================

SELECT
date,
COUNT(DISTINCT userid) AS daily_active_users
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY date
ORDER BY daily_active_users DESC;




-- =====================================================
-- DAILY ACTIVE USER SUMMARY
-- Average, maximum, and minimum DAU
-- =====================================================

WITH dau AS (
SELECT
date,
COUNT(DISTINCT userid) AS daily_active_users
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY date
)

SELECT
AVG(daily_active_users) AS avg_dau,
MAX(daily_active_users) AS max_dau,
MIN(daily_active_users) AS min_dau
FROM dau;




-- =====================================================
-- DAILY ACTIVITY FLUCTUATIONS
-- Exploring why certain days had unusually high or low DAU
-- =====================================================

SELECT
date,
COUNT(DISTINCT userid) AS daily_active_users
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY date
ORDER BY daily_active_users DESC;




-- =====================================================
-- USER ENGAGEMENT FREQUENCY
-- Days online per user per month
-- =====================================================

SELECT
userid,
MONTH(date) AS month_num,
MONTHNAME(date) AS month_name,
COUNT(DISTINCT date) AS days_online
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY
userid,
MONTH(date),
MONTHNAME(date)
ORDER BY
days_online DESC,
month_num;




-- =====================================================
-- 6. AVERAGE DAYS ONLINE PER MONTH
-- Measuring consistency of user engagement over time
-- =====================================================

WITH monthly_days_online AS (
SELECT
userid,
MONTH(date) AS month_num,
MONTHNAME(date) AS month_name,
COUNT(DISTINCT date) AS days_online
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY
userid,
MONTH(date),
MONTHNAME(date)
)

SELECT
month_name,
month_num,
AVG(days_online) AS avg_days_online
FROM monthly_days_online
GROUP BY
month_name,
month_num
ORDER BY month_num;




-- =====================================================
-- USER ENGAGEMENT DEPTH
-- Transformations per user per month
-- =====================================================

SELECT
userid,
MONTH(date) AS month_num,
MONTHNAME(date) AS month_name,
SUM(transformations) AS total_transformations
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY
userid,
MONTH(date),
MONTHNAME(date)
ORDER BY month_num;




-- =====================================================
-- TRANSFORMATION SUMMARY
-- Average, maximum, and minimum transformations per user
-- =====================================================

WITH monthly_transformations AS (
SELECT
userid,
MONTH(date) AS month_num,
MONTHNAME(date) AS month_name,
SUM(transformations) AS total_transformations
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY
userid,
MONTH(date),
MONTHNAME(date)
)

SELECT
AVG(total_transformations) AS avg_transformations_per_month,
MAX(total_transformations) AS max_transformations_per_month,
MIN(total_transformations) AS min_transformations_per_month
FROM monthly_transformations;




-- =====================================================
-- MONTH-OVER-MONTH RETENTION
-- Users active in month N and also active in month N+1
-- =====================================================

WITH monthly_activity AS (
SELECT DISTINCT
userid,
DATE_FORMAT(date, '%Y-%m-01') AS activity_month
FROM analytics_task_data
WHERE is_internal_staff = FALSE
),

next_month_activity AS (
SELECT
userid,
activity_month,
LEAD(activity_month) OVER (
PARTITION BY userid
ORDER BY activity_month
) AS next_month
FROM monthly_activity
),

user_activity AS (
SELECT
userid,
activity_month,
next_month,
CASE
WHEN next_month = DATE_ADD(activity_month, INTERVAL 1 MONTH)
THEN 1
ELSE 0
END AS retained_test
FROM next_month_activity
)

SELECT
activity_month,
COUNT(*) AS active_users,

SUM(
    CASE
        WHEN next_month = DATE_ADD(activity_month, INTERVAL 1 MONTH)
            THEN 1
        ELSE 0
    END
) AS retained_users,

ROUND(
    SUM(
        CASE
            WHEN next_month = DATE_ADD(activity_month, INTERVAL 1 MONTH)
                THEN 1
            ELSE 0
        END
    ) * 100.0 / COUNT(*),
    2
) AS retention_rate

FROM user_activity
GROUP BY activity_month
ORDER BY activity_month;




-- =====================================================
-- FEATURE ADOPTION SEGMENTATION
-- Grouping users by breadth of feature adoption
-- =====================================================

WITH feature_usage AS (
SELECT
userid,
COUNT(DISTINCT feature_type) AS feature_count
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY userid
)

SELECT
userid,
feature_count,

CASE
    WHEN feature_count = 1 THEN 'single feature user'
    WHEN feature_count = 2 THEN '2 feature user'
    ELSE 'multi feature user'
END AS segment

FROM feature_usage;




-- =====================================================
-- SEGMENT DISTRIBUTION
-- Understanding segment sizes and user composition
-- =====================================================

WITH feature_usage AS (
SELECT
userid,
COUNT(DISTINCT feature_type) AS feature_count
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY userid
),

segmentation AS (
SELECT
userid,
feature_count,

    CASE
        WHEN feature_count = 1 THEN 'single feature user'
        WHEN feature_count = 2 THEN '2 feature user'
        ELSE 'multi feature user'
    END AS segment

FROM feature_usage

),

segment_count AS (
SELECT
segment,
COUNT(*) AS total_users
FROM segmentation
GROUP BY segment
)

SELECT
*,
(total_users / SUM(total_users) OVER()) * 100 AS segment_percentage
FROM segment_count;

-- =====================================================
-- DAYS ONLINE BY SEGMENT
-- Comparing engagement frequency across user segments
-- =====================================================

WITH feature_usage AS (
SELECT
userid,
COUNT(DISTINCT feature_type) AS feature_count
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY userid
),

segmented_users AS (
SELECT
userid,
feature_count,

CASE
    WHEN feature_count = 1 THEN 'single feature user'
    WHEN feature_count = 2 THEN '2 feature user'
    ELSE 'multi feature user'
END AS segment

FROM feature_usage

),

user_days_online AS (
SELECT
userid,
COUNT(DISTINCT date) AS days_online
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY userid
)

SELECT
su.segment,
AVG(u.days_online) AS avg_days_online
FROM segmented_users su
LEFT JOIN user_days_online u
ON su.userid = u.userid
GROUP BY su.segment;

-- =====================================================
-- TRANSFORMATIONS PER MONTH BY SEGMENT
-- Comparing engagement depth across user segments
-- =====================================================

WITH feature_usage AS (
SELECT
userid,
COUNT(DISTINCT feature_type) AS feature_count
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY userid
),

segmentation AS (
SELECT
userid,

CASE 
    WHEN feature_count = 1 THEN '1 feature user'
    WHEN feature_count = 2 THEN '2 feature user'
    ELSE 'multi feature user'
END AS segment

FROM feature_usage

),

monthly_transformations AS (
SELECT
userid,
MONTH(date) AS month_num,
SUM(transformations) AS total_transformations_per_month
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY- userid, MONTH(date)
)

SELECT
s.segment,
AVG(t.total_transformations_per_month) AS avg_transformations_per_month
FROM segmentation s
LEFT JOIN monthly_transformations t
ON s.userid = t.userid
GROUP BY s.segment;

-- =====================================================
-- RETENTION RATE BY SEGMENT
-- Comparing long-term retention across feature adoption segments
-- =====================================================

WITH feature_usage AS (
SELECT
userid,
COUNT(DISTINCT feature_type) AS feature_count
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY userid
),

segmented_users AS (
SELECT
userid,
feature_count,

CASE
    WHEN feature_count = 1 THEN 'single feature user'
    WHEN feature_count = 2 THEN '2 feature user'
    ELSE 'multi feature user'
END AS segment

FROM feature_usage

),

monthly_activity AS (
SELECT 
DISTINCTuserid,
DATE_FORMAT(date, '%Y-%m-01') AS activity_month
FROM analytics_task_data
WHERE is_internal_staff = FALSE
),

next_month_activity AS (
SELECT
userid,
activity_month,

LEAD(activity_month) OVER (
    PARTITION BY userid
    ORDER BY activity_month
) AS next_month

FROM monthly_activity

),

user_activity AS (
SELECT
userid,
activity_month,
next_month,

CASE 
    WHEN next_month = DATE_ADD(activity_month, INTERVAL 1 MONTH)
        THEN 1
    ELSE 0
END AS retained_test

FROM next_month_activity

),

segment_retention AS (
SELECT
s.userid,
s.segment,
a.activity_month,
a.retained_test

FROM segmented_users s
LEFT JOIN user_activity a
ON s.userid = a.userid

)

SELECT
segment,
AVG(retained_test) AS avg_retention_rate
FROM segment_retention
GROUP BY segment;

-- =====================================================
-- RETENTION RATE BY ORG TIER
-- Comparing retention across customer account tiers
-- =====================================================

WITH monthly_activity AS (
SELECT 
DISTINCT
userid,
DATE_FORMAT(date, '%Y-%m-01') AS activity_month
FROM analytics_task_data
WHERE is_internal_staff = FALSE
),

next_month_activity AS (
SELECT
userid,
activity_month,
LEAD(activity_month) OVER (PARTITION BY userid ORDER BY activity_month) AS next_month
FROM monthly_activity
),

user_activity AS (
SELECT
userid,
activity_month,
next_month,
CASE
WHEN 
next_month = DATE_ADD(activity_month, INTERVAL 1 MONTH)THEN 1
ELSE 0
END AS retained_test
FROM next_month_activity
),

org_segmentation AS (
SELECT a.org_tier AS org_tier,
u.retained_test AS retained_test
FROM analytics_task_data AS a
LEFT JOIN user_activity AS u
ON a.userid = u.userid
)

SELECT
org_tier,
AVG(retained_test) AS avg_retention
FROM org_segmentation
GROUP BY org_tier
ORDER BY avg_retention DESC;

-- OVERALL FEATURE USAGE DISTRIBUTION
-- Identifying the platform’s most frequently used features

SELECT
feature_type,
COUNT(feature_type) AS feature_usage_frequency
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY feature_type
ORDER BY feature_usage_frequency DESC;

-- =====================================================
-- FEATURE PREFERENCE AMONG MULTI-FEATURE USERS
-- Understanding dominant workflows among highly engaged users
-- =====================================================

WITH feature_usage AS (
SELECT
userid,
COUNT(DISTINCT feature_type) AS feature_count
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY userid
),

multiusers AS (
SELECT
userid,
feature_count
FROM feature_usage
WHERE feature_count > 2
)

SELECT
a.feature_type,
COUNT(*) AS usage_count
FROM analytics_task_data AS a
JOIN multiusers AS m
ON a.userid = m.userid
WHERE is_internal_staff = FALSE
GROUP BY a.feature_type;

-- =====================================================
-- FEATURE DOMINANCE BY ORG TIER
-- Understanding how different customer segments prioritize features
WITH feature_usage AS (
SELECT
org_tier,
feature_type,
COUNT(*) AS feature_count
FROM analytics_task_data
WHERE is_internal_staff = FALSE
GROUP BY org_tier, feature_type
),

feature_usage_percentage AS (
SELECT 
*,
ROUND(
(feature_count / SUM(feature_count) OVER( PARTITION BY org_tier ORDER BY org_tier)) * 100, 2)AS usage_percentage
FROM feature_usage
)

SELECT
*,
RANK() OVER(PARTITION BY org_tier ORDER BY usage_percentage DESC) AS rank_of_usage
FROM feature_usage_percentage;