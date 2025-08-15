-- Sprint 4: Flink SQL Windowed Analytics Transformation
-- Advanced windowed analytics for business intelligence

-- Daily user analytics with advanced metrics
CREATE TABLE user_analytics_daily AS
SELECT 
    user_id,
    TUMBLE_START(event_timestamp, INTERVAL '1' DAY) as date_window,
    -- Basic metrics
    COUNT(*) as daily_events,
    COUNT(DISTINCT session_id) as daily_sessions,
    COUNT(DISTINCT event_type) as unique_event_types,
    
    -- Time-based analysis
    COUNT(DISTINCT HOUR(event_timestamp)) as active_hours,
    FIRST_VALUE(event_timestamp) as first_event_time,
    LAST_VALUE(event_timestamp) as last_event_time,
    
    -- Engagement metrics
    SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) as page_views,
    SUM(CASE WHEN event_type = 'click' THEN 1 ELSE 0 END) as clicks,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
    
    -- Revenue metrics
    SUM(
        CASE 
            WHEN event_type = 'purchase' THEN 
                CAST(JSON_VALUE(payload, '$.amount') AS DECIMAL(10,2))
            ELSE 0.0 
        END
    ) as daily_revenue,
    
    -- Advanced behavioral analysis
    CASE 
        WHEN COUNT(*) > 100 AND SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) > 5 
        THEN 'HIGH_VALUE_CUSTOMER'
        WHEN COUNT(*) > 50 AND SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) > 2 
        THEN 'REGULAR_CUSTOMER'
        WHEN COUNT(*) > 20 AND SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) = 0 
        THEN 'BROWSER'
        ELSE 'OCCASIONAL_USER'
    END as customer_segment,
    
    -- Trend indicators
    LAG(COUNT(*), 1) OVER (
        PARTITION BY user_id 
        ORDER BY TUMBLE_START(event_timestamp, INTERVAL '1' DAY)
    ) as previous_day_events,
    
    -- Calculate growth rate
    CASE 
        WHEN LAG(COUNT(*), 1) OVER (
            PARTITION BY user_id 
            ORDER BY TUMBLE_START(event_timestamp, INTERVAL '1' DAY)
        ) > 0 THEN
            (CAST(COUNT(*) AS DOUBLE) - CAST(LAG(COUNT(*), 1) OVER (
                PARTITION BY user_id 
                ORDER BY TUMBLE_START(event_timestamp, INTERVAL '1' DAY)
            ) AS DOUBLE)) / CAST(LAG(COUNT(*), 1) OVER (
                PARTITION BY user_id 
                ORDER BY TUMBLE_START(event_timestamp, INTERVAL '1' DAY)
            ) AS DOUBLE) * 100
        ELSE 0.0
    END as activity_growth_rate

FROM user_events_source
GROUP BY 
    user_id, 
    TUMBLE(event_timestamp, INTERVAL '1' DAY);

-- Real-time anomaly detection with complex event processing
CREATE TABLE user_anomaly_detection AS
SELECT 
    user_id,
    event_timestamp,
    event_type,
    -- Current event context
    COUNT(*) OVER (
        PARTITION BY user_id 
        ORDER BY event_timestamp 
        RANGE BETWEEN INTERVAL '1' HOUR PRECEDING AND CURRENT ROW
    ) as events_last_hour,
    
    COUNT(*) OVER (
        PARTITION BY user_id 
        ORDER BY event_timestamp 
        RANGE BETWEEN INTERVAL '1' DAY PRECEDING AND CURRENT ROW
    ) as events_last_day,
    
    -- Anomaly detection flags
    CASE 
        WHEN COUNT(*) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp 
            RANGE BETWEEN INTERVAL '5' MINUTE PRECEDING AND CURRENT ROW
        ) > 20 THEN 'SUSPICIOUS_ACTIVITY'
        WHEN event_type = 'purchase' AND 
             CAST(JSON_VALUE(payload, '$.amount') AS DECIMAL(10,2)) > 1000 THEN 'HIGH_VALUE_TRANSACTION'
        WHEN COUNT(DISTINCT event_type) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp 
            RANGE BETWEEN INTERVAL '1' MINUTE PRECEDING AND CURRENT ROW
        ) > 5 THEN 'RAPID_BEHAVIOR_CHANGE'
        ELSE 'NORMAL'
    END as anomaly_flag,
    
    -- Risk scoring
    CASE 
        WHEN COUNT(*) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp 
            RANGE BETWEEN INTERVAL '5' MINUTE PRECEDING AND CURRENT ROW
        ) > 50 THEN 5  -- High risk
        WHEN COUNT(*) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp 
            RANGE BETWEEN INTERVAL '5' MINUTE PRECEDING AND CURRENT ROW
        ) > 30 THEN 3  -- Medium risk
        WHEN COUNT(*) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp 
            RANGE BETWEEN INTERVAL '5' MINUTE PRECEDING AND CURRENT ROW
        ) > 15 THEN 2  -- Low risk
        ELSE 1         -- Normal
    END as risk_score
    
FROM user_events_source;
