-- Sprint 4: Flink SQL Event Aggregation Transformation
-- This transformation creates windowed aggregations for user analytics

-- Create hourly user activity summary
CREATE TABLE user_activity_hourly AS
SELECT 
    user_id,
    TUMBLE_START(event_timestamp, INTERVAL '1' HOUR) as window_start,
    TUMBLE_END(event_timestamp, INTERVAL '1' HOUR) as window_end,
    COUNT(*) as total_events,
    COUNT(DISTINCT session_id) as unique_sessions,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchase_count,
    SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) as view_count,
    SUM(CASE WHEN event_type = 'click' THEN 1 ELSE 0 END) as click_count,
    SUM(CASE WHEN event_type = 'login' THEN 1 ELSE 0 END) as login_count,
    -- Revenue calculations
    SUM(
        CASE 
            WHEN event_type = 'purchase' THEN 
                CAST(JSON_VALUE(payload, '$.amount') AS DECIMAL(10,2))
            ELSE 0.0 
        END
    ) as total_revenue,
    AVG(
        CASE 
            WHEN event_type = 'purchase' THEN 
                CAST(JSON_VALUE(payload, '$.amount') AS DECIMAL(10,2))
            ELSE NULL
        END
    ) as avg_purchase_amount,
    -- Conversion metrics
    CAST(SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS DOUBLE) / 
    CAST(COUNT(*) AS DOUBLE) * 100 as conversion_rate
FROM user_events_source
GROUP BY 
    user_id, 
    TUMBLE(event_timestamp, INTERVAL '1' HOUR);

-- Create sliding window for real-time metrics (5-minute windows, sliding every minute)
CREATE TABLE user_activity_sliding AS
SELECT 
    user_id,
    HOP_START(event_timestamp, INTERVAL '1' MINUTE, INTERVAL '5' MINUTE) as window_start,
    HOP_END(event_timestamp, INTERVAL '1' MINUTE, INTERVAL '5' MINUTE) as window_end,
    COUNT(*) as events_last_5min,
    COUNT(DISTINCT event_type) as unique_event_types,
    COLLECT(event_type) as event_types_array,
    -- Real-time alerting conditions
    CASE 
        WHEN COUNT(*) > 100 THEN 'HIGH_ACTIVITY'
        WHEN COUNT(*) > 50 THEN 'MEDIUM_ACTIVITY'
        ELSE 'LOW_ACTIVITY'
    END as activity_level
FROM user_events_source
GROUP BY 
    user_id,
    HOP(event_timestamp, INTERVAL '1' MINUTE, INTERVAL '5' MINUTE);

-- Create session-based aggregations
CREATE TABLE user_sessions AS
SELECT 
    user_id,
    session_id,
    MIN(event_timestamp) as session_start,
    MAX(event_timestamp) as session_end,
    COUNT(*) as session_events,
    COUNT(DISTINCT event_type) as unique_event_types_in_session,
    -- Session duration in minutes
    (MAX(event_timestamp) - MIN(event_timestamp)) MINUTE as session_duration_minutes,
    -- Session value
    SUM(
        CASE 
            WHEN event_type = 'purchase' THEN 
                CAST(JSON_VALUE(payload, '$.amount') AS DECIMAL(10,2))
            ELSE 0.0 
        END
    ) as session_value,
    -- Session behavior patterns
    CASE 
        WHEN SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) > 0 THEN 'CONVERTER'
        WHEN COUNT(*) > 20 THEN 'BROWSER'
        WHEN COUNT(*) < 5 THEN 'QUICK_VISIT'
        ELSE 'REGULAR'
    END as session_type
FROM user_events_source
GROUP BY user_id, session_id;
