-- Sprint 4: Flink SQL Transformation Tests
-- Validation queries to verify transformation accuracy

-- Test 1: User Enrichment Validation
-- Verify that all events are properly enriched with user data
SELECT 
    'user_enrichment_completeness' as test_name,
    COUNT(*) as total_events,
    COUNT(user_name) as events_with_user_name,
    COUNT(user_email) as events_with_user_email,
    CASE 
        WHEN COUNT(*) = COUNT(user_name) AND COUNT(*) = COUNT(user_email) 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as test_result,
    CAST(COUNT(user_name) AS DOUBLE) / CAST(COUNT(*) AS DOUBLE) * 100 as enrichment_rate
FROM user_events_enriched;

-- Test 2: Purchase Amount Calculation Validation
-- Verify purchase amounts are correctly calculated
SELECT 
    'purchase_amount_calculation' as test_name,
    COUNT(*) as total_purchase_events,
    SUM(purchase_amount) as total_calculated_amount,
    AVG(purchase_amount) as avg_purchase_amount,
    MIN(purchase_amount) as min_purchase_amount,
    MAX(purchase_amount) as max_purchase_amount,
    CASE 
        WHEN MIN(purchase_amount) >= 0 AND MAX(purchase_amount) <= 10000 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as test_result
FROM user_events_enriched
WHERE event_type = 'purchase' AND purchase_amount > 0;

-- Test 3: Temporal Join Accuracy
-- Verify temporal joins are working correctly with proper time alignment
SELECT 
    'temporal_join_accuracy' as test_name,
    COUNT(*) as total_joined_events,
    COUNT(DISTINCT user_id) as unique_users,
    -- Check for any events without proper user data (should be 0)
    COUNT(*) - COUNT(user_name) as missing_user_data,
    CASE 
        WHEN COUNT(*) = COUNT(user_name) 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as test_result,
    MIN(event_time) as earliest_event,
    MAX(event_time) as latest_event
FROM user_events_enriched;

-- Test 4: Windowed Aggregation Validation
-- Verify hourly aggregations are correct
SELECT 
    'hourly_aggregation_accuracy' as test_name,
    COUNT(*) as total_windows,
    SUM(total_events) as sum_of_events_in_windows,
    AVG(total_events) as avg_events_per_window,
    AVG(conversion_rate) as avg_conversion_rate,
    CASE 
        WHEN AVG(conversion_rate) >= 0 AND AVG(conversion_rate) <= 100 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as test_result
FROM user_activity_hourly;

-- Test 5: Revenue Calculation Validation
-- Verify revenue calculations in aggregations
SELECT 
    'revenue_calculation_accuracy' as test_name,
    COUNT(*) as windows_with_revenue,
    SUM(total_revenue) as total_calculated_revenue,
    AVG(avg_purchase_amount) as avg_calculated_purchase_amount,
    CASE 
        WHEN SUM(total_revenue) > 0 AND AVG(avg_purchase_amount) > 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as test_result,
    MIN(total_revenue) as min_window_revenue,
    MAX(total_revenue) as max_window_revenue
FROM user_activity_hourly
WHERE total_revenue > 0;

-- Test 6: Sliding Window Validation
-- Verify sliding window computations
SELECT 
    'sliding_window_accuracy' as test_name,
    COUNT(*) as total_sliding_windows,
    AVG(events_last_5min) as avg_events_per_5min_window,
    COUNT(DISTINCT activity_level) as unique_activity_levels,
    CASE 
        WHEN COUNT(DISTINCT activity_level) >= 2 AND AVG(events_last_5min) >= 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as test_result
FROM user_activity_sliding;

-- Test 7: Session Analysis Validation
-- Verify session grouping and duration calculations
SELECT 
    'session_analysis_accuracy' as test_name,
    COUNT(*) as total_sessions,
    AVG(session_duration_minutes) as avg_session_duration,
    COUNT(DISTINCT session_type) as unique_session_types,
    SUM(session_value) as total_session_value,
    CASE 
        WHEN AVG(session_duration_minutes) >= 0 AND COUNT(DISTINCT session_type) >= 3 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as test_result
FROM user_sessions;

-- Test 8: Daily Analytics Validation
-- Verify daily rollup calculations
SELECT 
    'daily_analytics_accuracy' as test_name,
    COUNT(*) as total_daily_records,
    AVG(daily_events) as avg_daily_events,
    COUNT(DISTINCT customer_segment) as unique_segments,
    AVG(daily_revenue) as avg_daily_revenue,
    CASE 
        WHEN COUNT(DISTINCT customer_segment) >= 3 AND AVG(daily_revenue) >= 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as test_result
FROM user_analytics_daily;

-- Test 9: Anomaly Detection Validation
-- Verify anomaly detection logic
SELECT 
    'anomaly_detection_accuracy' as test_name,
    COUNT(*) as total_analyzed_events,
    COUNT(DISTINCT anomaly_flag) as unique_anomaly_types,
    COUNT(*) FILTER (WHERE anomaly_flag != 'NORMAL') as flagged_events,
    AVG(risk_score) as avg_risk_score,
    CASE 
        WHEN COUNT(DISTINCT anomaly_flag) >= 2 AND AVG(risk_score) BETWEEN 1 AND 5 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as test_result,
    CAST(COUNT(*) FILTER (WHERE anomaly_flag != 'NORMAL') AS DOUBLE) / 
    CAST(COUNT(*) AS DOUBLE) * 100 as anomaly_rate
FROM user_anomaly_detection;

-- Test 10: Data Consistency Across Transformations
-- Cross-validation between different transformation outputs
SELECT 
    'cross_transformation_consistency' as test_name,
    e.total_events_enriched,
    h.total_events_hourly,
    s.total_events_sessions,
    d.total_events_daily,
    CASE 
        WHEN ABS(e.total_events_enriched - h.total_events_hourly) <= 
             GREATEST(e.total_events_enriched * 0.01, 10)  -- 1% tolerance or 10 events
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as test_result,
    ABS(e.total_events_enriched - h.total_events_hourly) as event_count_difference
FROM 
    (SELECT COUNT(*) as total_events_enriched FROM user_events_enriched) e,
    (SELECT SUM(total_events) as total_events_hourly FROM user_activity_hourly) h,
    (SELECT SUM(session_events) as total_events_sessions FROM user_sessions) s,
    (SELECT SUM(daily_events) as total_events_daily FROM user_analytics_daily) d;
