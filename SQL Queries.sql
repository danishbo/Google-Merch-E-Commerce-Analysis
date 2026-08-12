/* ============================================================================
   E-COMMERCE FUNNEL & REVENUE ANALYSIS SCRIPT
   Target Dataset: `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`
   Timeframe: Last 30 Days (Relative to Lastest Event Date)
   ============================================================================ */


-- ----------------------------------------------------------------------------
-- 1. OVERALL FUNNEL VOLUMES
-- ----------------------------------------------------------------------------
WITH funnel_stages AS (
  SELECT
    COUNT(DISTINCT IF(event_type = 'page_view', user_id, NULL)) AS stage_1_views,
    COUNT(DISTINCT IF(event_type = 'add_to_cart', user_id, NULL)) AS stage_2_cart,
    COUNT(DISTINCT IF(event_type = 'checkout_start', user_id, NULL)) AS stage_3_checkout,
    COUNT(DISTINCT IF(event_type = 'payment_info', user_id, NULL)) AS stage_4_payment,
    COUNT(DISTINCT IF(event_type = 'purchase', user_id, NULL)) AS stage_5_purchase
  FROM `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`
  WHERE event_date >= TIMESTAMP_SUB(
    (SELECT MAX(event_date) FROM `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`), 
    INTERVAL 30 DAY
  )
)

SELECT * FROM funnel_stages;


-- ----------------------------------------------------------------------------
-- 2. STAGE-TO-STAGE CONVERSION RATES
-- ----------------------------------------------------------------------------
WITH funnel_stages AS (
  SELECT
    COUNT(DISTINCT IF(event_type = 'page_view', user_id, NULL)) AS stage_1_views,
    COUNT(DISTINCT IF(event_type = 'add_to_cart', user_id, NULL)) AS stage_2_cart,
    COUNT(DISTINCT IF(event_type = 'checkout_start', user_id, NULL)) AS stage_3_checkout,
    COUNT(DISTINCT IF(event_type = 'payment_info', user_id, NULL)) AS stage_4_payment,
    COUNT(DISTINCT IF(event_type = 'purchase', user_id, NULL)) AS stage_5_purchase
  FROM `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`
  WHERE event_date >= TIMESTAMP_SUB(
    (SELECT MAX(event_date) FROM `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`), 
    INTERVAL 30 DAY
  )
)

SELECT
  stage_1_views,
  stage_2_cart,
  ROUND(stage_2_cart * 100.0 / stage_1_views, 2) AS view_to_cart_rate,

  stage_3_checkout,
  ROUND(stage_3_checkout * 100.0 / stage_2_cart, 2) AS cart_to_checkout_rate,

  stage_4_payment,
  ROUND(stage_4_payment * 100.0 / stage_3_checkout, 2) AS checkout_to_payment_rate,

  stage_5_purchase,
  ROUND(stage_5_purchase * 100.0 / stage_4_payment, 2) AS payment_to_purchase_rate,

  ROUND(stage_5_purchase * 100.0 / stage_1_views, 2) AS overall_conversion_rate
FROM funnel_stages;


-- ----------------------------------------------------------------------------
-- 3. FUNNEL PERFORMANCE BY TRAFFIC SOURCE
-- ----------------------------------------------------------------------------
WITH source_funnel AS (
  SELECT
    traffic_source,
    COUNT(DISTINCT IF(event_type = 'page_view', user_id, NULL)) AS views,
    COUNT(DISTINCT IF(event_type = 'add_to_cart', user_id, NULL)) AS carts,
    COUNT(DISTINCT IF(event_type = 'purchase', user_id, NULL)) AS purchases
  FROM `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`
  WHERE event_date >= TIMESTAMP_SUB(
    (SELECT MAX(event_date) FROM `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`), 
    INTERVAL 30 DAY
  )
  GROUP BY traffic_source
)

SELECT
  traffic_source,
  views,
  carts,
  purchases,
  ROUND(carts * 100.0 / views, 2) AS cart_conversion_rate,
  ROUND(purchases * 100.0 / views, 2) AS purchase_conversion_rate,
  ROUND(purchases * 100.0 / carts, 2) AS cart_to_purchase_conversion_rate
FROM source_funnel
ORDER BY purchases DESC;


-- ----------------------------------------------------------------------------
-- 4. TIME-TO-CONVERSION ANALYSIS
-- ----------------------------------------------------------------------------
WITH user_journey AS (
  SELECT
    user_id,
    MIN(IF(event_type = 'page_view', event_date, NULL)) AS view_time,
    MIN(IF(event_type = 'add_to_cart', event_date, NULL)) AS cart_time,
    MIN(IF(event_type = 'purchase', event_date, NULL)) AS purchase_time
  FROM `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`
  WHERE event_date >= TIMESTAMP_SUB(
    (SELECT MAX(event_date) FROM `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`), 
    INTERVAL 30 DAY
  )
  GROUP BY user_id
  HAVING purchase_time IS NOT NULL
)

SELECT
  COUNT(*) AS converted_users,
  ROUND(AVG(TIMESTAMP_DIFF(cart_time, view_time, MINUTE)), 2) AS avg_view_to_cart_minutes,
  ROUND(AVG(TIMESTAMP_DIFF(purchase_time, cart_time, MINUTE)), 2) AS avg_cart_to_purchase_minutes,
  ROUND(AVG(TIMESTAMP_DIFF(purchase_time, view_time, MINUTE)), 2) AS avg_total_journey_minutes
FROM user_journey;


-- ----------------------------------------------------------------------------
-- 5. REVENUE & UNIT ECONOMICS ANALYSIS
-- ----------------------------------------------------------------------------
WITH funnel_revenue AS (
  SELECT
    COUNT(DISTINCT IF(event_type = 'page_view', user_id, NULL)) AS total_visitors,
    COUNT(DISTINCT IF(event_type = 'purchase', user_id, NULL)) AS total_buyers,
    SUM(IF(event_type = 'purchase', amount, 0)) AS total_revenue,
    COUNT(IF(event_type = 'purchase', 1, NULL)) AS total_orders
  FROM `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`
  WHERE event_date >= TIMESTAMP_SUB(
    (SELECT MAX(event_date) FROM `project-cfc35ca0-05d6-4d00-8eb.Portfolio.cleaned_user_events`), 
    INTERVAL 30 DAY
  )
)

SELECT
  total_visitors,
  total_buyers,
  total_orders,
  ROUND(total_revenue, 2) AS total_revenue,
  ROUND(total_revenue / NULLIF(total_orders, 0), 2) AS avg_order_value,
  ROUND(total_revenue / NULLIF(total_buyers, 0), 2) AS revenue_per_buyer,
  ROUND(total_revenue / NULLIF(total_visitors, 0), 2) AS revenue_per_visitor
FROM funnel_revenue;