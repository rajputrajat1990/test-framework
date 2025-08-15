-- Sprint 4: Flink SQL Validation Queries
-- Additional validation queries for comprehensive testing

-- Performance Validation Queries
-- These queries help validate that transformations perform within acceptable limits

-- Query 1: Throughput Validation
-- Measures processing rate and latency
SELECT 
    'throughput_validation' as test_name,
    COUNT(*) as processed_events,
    COUNT(DISTINCT user_id) as unique_users_processed,
    (MAX(processing_time) - MIN(processing_time)) SECOND as processing_window_seconds,
    CAST(COUNT(*) AS DOUBLE) / 
    CAST((MAX(processing_time) - MIN(processing_time)) SECOND AS DOUBLE) as events_per_second,
    CASE 
        WHEN CAST(COUNT(*) AS DOUBLE) / 
             CAST((MAX(processing_time) - MIN(processing_time)) SECOND AS DOUBLE) >= 1000 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as performance_test_result
FROM user_events_enriched
WHERE processing_time IS NOT NULL;

-- Query 2: Latency Validation
-- Measures end-to-end processing latency
SELECT 
    'latency_validation' as test_name,
    COUNT(*) as measured_events,
    AVG((processing_time - event_time) SECOND) as avg_latency_seconds,
    MAX((processing_time - event_time) SECOND) as max_latency_seconds,
    MIN((processing_time - event_time) SECOND) as min_latency_seconds,
    CASE 
        WHEN AVG((processing_time - event_time) SECOND) <= 5 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as latency_test_result
FROM user_events_enriched
WHERE processing_time IS NOT NULL AND event_time IS NOT NULL;

-- Query 3: Memory and Resource Validation
-- Validates resource usage patterns
SELECT 
    'resource_usage_validation' as test_name,
    COUNT(*) as total_processed_events,
    COUNT(DISTINCT DATE(event_time)) as processing_days,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) / COUNT(DISTINCT user_id) as avg_events_per_user,
    CASE 
        WHEN COUNT(*) / COUNT(DISTINCT user_id) <= 10000  -- Max 10K events per user
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as resource_test_result
FROM user_events_enriched;

-- Query 4: Window Processing Validation
-- Validates window boundary handling
SELECT 
    'window_boundary_validation' as test_name,
    COUNT(*) as total_windows,
    COUNT(DISTINCT window_start) as unique_start_times,
    COUNT(DISTINCT window_end) as unique_end_times,
    AVG((window_end - window_start) MINUTE) as avg_window_duration_minutes,
    CASE 
        WHEN AVG((window_end - window_start) MINUTE) = 60  -- Hourly windows should be 60 minutes
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as window_test_result
FROM user_activity_hourly;

-- Query 5: Late Data Handling Validation
-- Tests how well the system handles late-arriving data
SELECT 
    'late_data_handling' as test_name,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE event_time < processing_time) as on_time_events,
    COUNT(*) FILTER (WHERE (processing_time - event_time) SECOND > 60) as late_events,
    CAST(COUNT(*) FILTER (WHERE (processing_time - event_time) SECOND > 60) AS DOUBLE) /
    CAST(COUNT(*) AS DOUBLE) * 100 as late_data_percentage,
    CASE 
        WHEN CAST(COUNT(*) FILTER (WHERE (processing_time - event_time) SECOND > 60) AS DOUBLE) /
             CAST(COUNT(*) AS DOUBLE) * 100 <= 5  -- Less than 5% late data acceptable
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as late_data_test_result
FROM user_events_enriched
WHERE processing_time IS NOT NULL AND event_time IS NOT NULL;

-- Query 6: Watermark and Event Time Validation
-- Validates event time processing and watermarks
SELECT 
    'event_time_validation' as test_name,
    COUNT(*) as events_with_event_time,
    MIN(event_time) as earliest_event_time,
    MAX(event_time) as latest_event_time,
    COUNT(DISTINCT DATE(event_time)) as unique_event_dates,
    CASE 
        WHEN MIN(event_time) IS NOT NULL AND MAX(event_time) IS NOT NULL 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as event_time_test_result,
    (MAX(event_time) - MIN(event_time)) DAY as time_span_days
FROM user_events_enriched;

-- Query 7: Join Accuracy Validation
-- Validates temporal join accuracy and completeness
SELECT 
    'join_accuracy_validation' as test_name,
    COUNT(*) as total_join_attempts,
    COUNT(user_name) as successful_joins,
    COUNT(*) - COUNT(user_name) as failed_joins,
    CAST(COUNT(user_name) AS DOUBLE) / CAST(COUNT(*) AS DOUBLE) * 100 as join_success_rate,
    CASE 
        WHEN CAST(COUNT(user_name) AS DOUBLE) / CAST(COUNT(*) AS DOUBLE) * 100 >= 95 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as join_test_result
FROM user_events_enriched;

-- Query 8: Aggregation Accuracy Validation
-- Validates mathematical accuracy of aggregations
SELECT 
    'aggregation_accuracy_validation' as test_name,
    COUNT(*) as total_aggregation_windows,
    SUM(total_events) as sum_of_events,
    SUM(total_revenue) as sum_of_revenue,
    AVG(conversion_rate) as avg_conversion_rate,
    STDDEV(conversion_rate) as conversion_rate_stddev,
    CASE 
        WHEN AVG(conversion_rate) BETWEEN 0 AND 100 AND 
             SUM(total_events) > 0 AND 
             SUM(total_revenue) >= 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as aggregation_test_result
FROM user_activity_hourly;

-- Query 9: Data Type Validation
-- Ensures all data types are correct after transformation
SELECT 
    'data_type_validation' as test_name,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE purchase_amount >= 0) as valid_amounts,
    COUNT(*) FILTER (WHERE tier_multiplier >= 1.0) as valid_multipliers,
    COUNT(*) FILTER (WHERE event_time IS NOT NULL) as valid_timestamps,
    CASE 
        WHEN COUNT(*) = COUNT(*) FILTER (WHERE purchase_amount >= 0) AND
             COUNT(*) = COUNT(*) FILTER (WHERE tier_multiplier >= 1.0) AND
             COUNT(*) = COUNT(*) FILTER (WHERE event_time IS NOT NULL)
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as data_type_test_result
FROM user_events_enriched;

-- Query 10: End-to-End Data Quality Validation
-- Comprehensive data quality check across all transformations
WITH quality_metrics AS (
    SELECT 
        'data_quality_comprehensive' as test_name,
        -- Enrichment quality
        (SELECT COUNT(*) FROM user_events_enriched) as enriched_count,
        (SELECT COUNT(*) FROM user_events_enriched WHERE user_name IS NOT NULL) as complete_enrichments,
        -- Aggregation quality
        (SELECT COUNT(*) FROM user_activity_hourly) as hourly_aggregations,
        (SELECT COUNT(*) FROM user_activity_sliding) as sliding_aggregations,
        -- Session quality
        (SELECT COUNT(*) FROM user_sessions) as session_count,
        (SELECT AVG(session_duration_minutes) FROM user_sessions) as avg_session_duration,
        -- Daily analytics quality
        (SELECT COUNT(*) FROM user_analytics_daily) as daily_records,
        (SELECT SUM(daily_revenue) FROM user_analytics_daily) as total_daily_revenue
)
SELECT 
    test_name,
    enriched_count,
    complete_enrichments,
    hourly_aggregations,
    sliding_aggregations,
    session_count,
    avg_session_duration,
    daily_records,
    total_daily_revenue,
    CASE 
        WHEN enriched_count > 0 AND 
             complete_enrichments = enriched_count AND
             hourly_aggregations > 0 AND
             sliding_aggregations > 0 AND
             session_count > 0 AND
             avg_session_duration > 0 AND
             daily_records > 0 AND
             total_daily_revenue >= 0
        THEN 'PASS'
        ELSE 'FAIL'
    END as comprehensive_test_result,
    CAST(complete_enrichments AS DOUBLE) / CAST(enriched_count AS DOUBLE) * 100 as data_completeness_percentage
FROM quality_metrics;
