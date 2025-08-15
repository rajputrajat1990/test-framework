-- Sprint 4: Flink SQL User Enrichment Transformation
-- This transformation enriches user events with user profile data

-- Create the enriched events table with user profile data
CREATE TABLE user_events_enriched AS
SELECT 
    e.user_id,
    e.event_type,
    e.event_timestamp,
    e.session_id,
    e.payload,
    u.user_name,
    u.user_email,
    u.registration_date,
    u.user_tier,
    u.country,
    -- Add computed fields
    CASE 
        WHEN e.event_type = 'purchase' THEN 
            CAST(JSON_VALUE(e.payload, '$.amount') AS DECIMAL(10,2))
        ELSE 0.0 
    END as purchase_amount,
    CASE 
        WHEN u.user_tier = 'premium' THEN 1.5
        WHEN u.user_tier = 'gold' THEN 1.2
        ELSE 1.0 
    END as tier_multiplier,
    -- Time-based computations
    CAST(e.event_timestamp AS TIMESTAMP_LTZ(3)) as event_time,
    PROCTIME() as processing_time
FROM user_events e
JOIN users FOR SYSTEM_TIME AS OF e.event_timestamp AS u
    ON e.user_id = u.user_id
WHERE e.event_type IN ('purchase', 'view', 'click', 'login', 'logout');
