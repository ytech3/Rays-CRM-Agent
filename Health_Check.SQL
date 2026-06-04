-- =============================================================================
-- CRM AGENT — MONITORING & HEALTH CHECK
-- Created: March 9, 2026
-- =============================================================================
--
-- PURPOSE:
-- Automated daily health monitoring for the CRM Agent pipeline.
-- Checks freshness of all 6 permanent tables and sends email alert
-- if anything is stale. Prevents silent DAG failures from going
-- unnoticed (as happened March 3-9, 2026 when root task suspended
-- due to a transient Cortex AI error and wasn't caught for 6 days).
--
-- COMPONENTS:
-- 1. CRM_AGENT_ALERTS — Email notification integration
-- 2. TSK_CRM_AGENT_HEALTH_CHECK — Daily 7am ET health check task
-- 3. T_CRM_AGENT_HEALTH_LOG — Audit log of all health checks
--
-- DEPENDENCIES:
-- - All 6 permanent tables must exist
-- - SYSTEM$SEND_EMAIL requires the notification integration
-- =============================================================================


-- =============================================================================
-- STEP 1: Email Notification Integration
-- =============================================================================
CREATE OR REPLACE NOTIFICATION INTEGRATION CRM_AGENT_ALERTS
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('ytaketani@raysbaseball.com')
    COMMENT = 'CRM Agent health check email alerts';


-- =============================================================================
-- STEP 2: Root Task Resilience
-- Set retry tolerance so transient errors don't kill the DAG.
-- Must suspend root first, then alter, then resume.
-- =============================================================================
-- ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS SUSPEND;
-- ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS
--     SET SUSPEND_TASK_AFTER_NUM_FAILURES = 3;
-- ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS RESUME;


-- =============================================================================
-- STEP 3: Daily Health Check Task
-- Runs at 7am ET every day. Checks all table freshness timestamps.
-- Sends email only when issues are found; silently logs "HEALTHY" otherwise.
-- =============================================================================
CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TSK_CRM_AGENT_HEALTH_CHECK
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    SCHEDULE = 'USING CRON 0 7 * * * America/New_York'
    COMMENT = 'Daily CRM Agent pipeline health check — alerts if any table is stale or deal health distribution is skewed'
AS
DECLARE
    v_issues STRING DEFAULT '';
    v_email_enriched_ts TIMESTAMP;
    v_activity_metrics_ts TIMESTAMP;
    v_email_analytics_ts TIMESTAMP;
    v_call_activity_ts TIMESTAMP;
    v_deal_health_ts TIMESTAMP;
    v_customer_360_ts TIMESTAMP;
    v_dim_activity_ts TIMESTAMP;
    v_threshold_2h TIMESTAMP;
    v_threshold_3h TIMESTAMP;
    v_threshold_48h TIMESTAMP;
    v_total_scored NUMBER;
    v_critical_count NUMBER;
    v_critical_pct NUMBER;
BEGIN
    v_threshold_2h := DATEADD('HOUR', -26, CURRENT_TIMESTAMP());
    v_threshold_3h := DATEADD('HOUR', -3, CURRENT_TIMESTAMP());
    v_threshold_48h := DATEADD('HOUR', -48, CURRENT_TIMESTAMP());

    -- Get latest timestamps from each table
    SELECT COALESCE(MAX(ENRICHMENT_TIMESTAMP), '1900-01-01'::TIMESTAMP)
        INTO :v_email_enriched_ts FROM TBRDP_DW_PROD.IM_RPT.T_EMAIL_ENRICHED;

    SELECT COALESCE(MAX(METRICS_TIMESTAMP), '1900-01-01'::TIMESTAMP)
        INTO :v_activity_metrics_ts FROM TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS;

    SELECT COALESCE(MAX(SCORING_TIMESTAMP), '1900-01-01'::TIMESTAMP)
        INTO :v_deal_health_ts FROM TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE;

    SELECT COALESCE(MAX(LAST_REFRESHED_AT), '1900-01-01'::TIMESTAMP)
        INTO :v_customer_360_ts FROM TBRDP_DW_PROD.IM_RPT.T_CUSTOMER_360;

    SELECT COALESCE(MAX(ANALYTICS_GENERATED_AT), '1900-01-01'::TIMESTAMP)
        INTO :v_email_analytics_ts FROM TBRDP_DW_PROD.IM_RPT.T_EMAIL_ANALYTICS;

    SELECT COALESCE(MAX(LOADED_AT), '1900-01-01'::TIMESTAMP)
        INTO :v_call_activity_ts FROM TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY;

    SELECT COALESCE(MAX(LOADED_AT), '1900-01-01'::TIMESTAMP)
        INTO :v_dim_activity_ts FROM TBRDP_DW_PROD.IM_RPT.T_DIM_ACTIVITY_SUMMARY;

    -- Check each table against thresholds
    IF (:v_email_enriched_ts < :v_threshold_2h) THEN
        v_issues := :v_issues || '- T_EMAIL_ENRICHED is stale (last: ' || :v_email_enriched_ts::VARCHAR || '). Root task may be suspended.\n';
    END IF;

    IF (:v_activity_metrics_ts < :v_threshold_2h) THEN
        v_issues := :v_issues || '- T_ACTIVITY_METRICS is stale (last: ' || :v_activity_metrics_ts::VARCHAR || ').\n';
    END IF;

    IF (:v_deal_health_ts < :v_threshold_2h) THEN
        v_issues := :v_issues || '- T_DEAL_HEALTH_SCORE is stale (last: ' || :v_deal_health_ts::VARCHAR || ').\n';
    END IF;

    IF (:v_customer_360_ts < :v_threshold_2h) THEN
        v_issues := :v_issues || '- T_CUSTOMER_360 is stale (last: ' || :v_customer_360_ts::VARCHAR || ').\n';
    END IF;

    IF (:v_email_analytics_ts < :v_threshold_48h) THEN
        v_issues := :v_issues || '- T_EMAIL_ANALYTICS is stale (last: ' || :v_email_analytics_ts::VARCHAR || ').\n';
    END IF;

    IF (:v_call_activity_ts < :v_threshold_48h) THEN
        v_issues := :v_issues || '- T_CALL_ACTIVITY is stale (last: ' || :v_call_activity_ts::VARCHAR || ').\n';
    END IF;

    -- 30-min standalone refresh (TSK_REFRESH_DIM_ACTIVITY_SUMMARY); guarded by
    -- SOURCE_WATERMARK so LOADED_AT only advances when V_FACT_ACTIVITIES loads new data.
    IF (:v_dim_activity_ts < :v_threshold_3h) THEN
        v_issues := :v_issues || '- T_DIM_ACTIVITY_SUMMARY is stale (last: ' || :v_dim_activity_ts::VARCHAR || '). 30-min refresh task may be suspended or source not loading.\n';
    END IF;

    -- Deal health distribution check — alert if Critical > 80%
    SELECT COUNT(*) INTO :v_total_scored FROM TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE;
    SELECT COUNT(*) INTO :v_critical_count FROM TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE WHERE HEALTH_CATEGORY = 'Critical';

    IF (:v_total_scored > 0) THEN
        v_critical_pct := ROUND(:v_critical_count * 100.0 / :v_total_scored, 1);
        IF (:v_critical_pct > 80) THEN
            v_issues := :v_issues || '- DEAL HEALTH DISTRIBUTION SKEWED: ' || :v_critical_pct::VARCHAR || '% Critical (' || :v_critical_count::VARCHAR || '/' || :v_total_scored::VARCHAR || ' deals). Scoring formula or stage filter may need review.\n';
        END IF;
    END IF;

    -- Log results
    CREATE TABLE IF NOT EXISTS TBRDP_DW_PROD.IM_RPT.T_CRM_AGENT_HEALTH_LOG (
        check_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
        status VARCHAR,
        issues VARCHAR
    );

    -- Send alert if issues found, otherwise log healthy
    IF (:v_issues != '') THEN
        INSERT INTO TBRDP_DW_PROD.IM_RPT.T_CRM_AGENT_HEALTH_LOG (status, issues)
        VALUES ('UNHEALTHY', :v_issues);

        CALL SYSTEM$SEND_EMAIL(
            'CRM_AGENT_ALERTS',
            'ytaketani@raysbaseball.com',
            'CRM Agent Health Alert - Action Required',
            'The following CRM Agent components need attention:\n\n' || :v_issues ||
            '\nTo diagnose: SHOW TASKS IN SCHEMA TBRDP_DW_PROD.IM_RPT;\n' ||
            'To resume DAG: ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS RESUME;'
        );
    ELSE
        INSERT INTO TBRDP_DW_PROD.IM_RPT.T_CRM_AGENT_HEALTH_LOG (status, issues)
        VALUES ('HEALTHY', 'All systems current.');
    END IF;
END;

ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_CRM_AGENT_HEALTH_CHECK RESUME;


-- =============================================================================
-- MANUAL HEALTH CHECK QUERY
-- Save as a Snowsight worksheet for pre-presentation confidence checks
-- =============================================================================
/*
SELECT 'T_EMAIL_ENRICHED' AS component, MAX(ENRICHMENT_TIMESTAMP) AS last_refresh FROM TBRDP_DW_PROD.IM_RPT.T_EMAIL_ENRICHED
UNION ALL SELECT 'T_ACTIVITY_METRICS', MAX(METRICS_TIMESTAMP) FROM TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS
UNION ALL SELECT 'T_DEAL_HEALTH', MAX(SCORING_TIMESTAMP) FROM TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE
UNION ALL SELECT 'T_CUSTOMER_360', MAX(LAST_REFRESHED_AT) FROM TBRDP_DW_PROD.IM_RPT.T_CUSTOMER_360
UNION ALL SELECT 'T_EMAIL_ANALYTICS', MAX(ANALYTICS_GENERATED_AT) FROM TBRDP_DW_PROD.IM_RPT.T_EMAIL_ANALYTICS
UNION ALL SELECT 'T_CALL_ACTIVITY', MAX(LOADED_AT) FROM TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY
UNION ALL SELECT 'T_DIM_ACTIVITY_SUMMARY', MAX(LOADED_AT) FROM TBRDP_DW_PROD.IM_RPT.T_DIM_ACTIVITY_SUMMARY
ORDER BY 1;

-- Health check log
SELECT * FROM TBRDP_DW_PROD.IM_RPT.T_CRM_AGENT_HEALTH_LOG ORDER BY check_time DESC LIMIT 10;

-- Stream health
SELECT 'STM_NEW_EMAILS' AS stream, SYSTEM$STREAM_HAS_DATA('TBRDP_DW_PROD.IM_RPT.STM_NEW_EMAILS') AS has_data
UNION ALL SELECT 'STM_OPPORTUNITY_CHANGES', SYSTEM$STREAM_HAS_DATA('TBRDP_DW_PROD.IM_RPT.STM_OPPORTUNITY_CHANGES')
UNION ALL SELECT 'STM_CALL_LOG_CHANGES', SYSTEM$STREAM_HAS_DATA('TBRDP_DW_PROD.IM_RPT.STM_CALL_LOG_CHANGES')
UNION ALL SELECT 'STM_SESSION_HISTORY_CHANGES', SYSTEM$STREAM_HAS_DATA('TBRDP_DW_PROD.IM_RPT.STM_SESSION_HISTORY_CHANGES')
UNION ALL SELECT 'STM_TASK_CHANGES', SYSTEM$STREAM_HAS_DATA('TBRDP_DW_PROD.IM_RPT.STM_TASK_CHANGES');

-- Search service status
SHOW CORTEX SEARCH SERVICES IN SCHEMA TBRDP_DW_PROD.IM_RPT;
*/


-- =============================================================================
-- EMERGENCY RECOVERY PROCEDURES
-- =============================================================================
--
-- SCENARIO 1: Root task suspended (SUSPENDED_DUE_TO_ERRORS)
-- The daily health check will email you. To fix:
--   1. Check task history: SELECT * FROM TABLE(TBRDP_DW_PROD.INFORMATION_SCHEMA.TASK_HISTORY(...))
--   2. Fix the underlying error if needed
--   3. Resume: ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS RESUME;
--
-- SCENARIO 2: Stale streams (stream shows stale=true in SHOW STREAMS)
-- Streams go stale when not consumed within retention window (~14 days).
-- Recreate them:
--   CREATE OR REPLACE STREAM TBRDP_DW_PROD.IM_RPT.STM_OPPORTUNITY_CHANGES
--       ON VIEW TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
--       APPEND_ONLY = TRUE;
--   CREATE OR REPLACE STREAM TBRDP_DW_PROD.IM_RPT.STM_TASK_CHANGES
--       ON VIEW TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK
--       APPEND_ONLY = TRUE;
--   (Repeat for STM_NEW_EMAILS, STM_CALL_LOG_CHANGES, STM_SESSION_HISTORY_CHANGES if needed)
--
-- SCENARIO 3: Full manual refresh (pre-presentation, all tables stale)
-- Run each step sequentially — Step 1 is the bottleneck (~20-25 min for AI calls):
--   Step 0: Recreate any stale streams (see Scenario 2)
--   Step 1: INSERT INTO T_EMAIL_ENRICHED ... FROM STM_NEW_EMAILS (remove LIMIT 500 for full backlog)
--   Step 2: Run the MERGE for T_OPPORTUNITY_ACTIVITY_METRICS
--   Step 3: Run the MERGE for T_DEAL_HEALTH_SCORE
--   Step 4: CREATE OR REPLACE TABLE T_CUSTOMER_360 AS ...
--   Step 5: CREATE OR REPLACE TABLE T_EMAIL_ANALYTICS AS ...
--   Step 6: INSERT INTO T_CALL_ACTIVITY from source views with NOT EXISTS guard
--   Step 7: CREATE OR REPLACE TABLE T_ACCOUNT_CROSSWALK AS ...
--   Step 8: Resume all tasks (suspend root → resume children → resume root)
--   Cost estimate: ~$25-35 for 4,000 email backlog
--
-- SCENARIO 4: Child task suspended separately
-- This can happen if you modify a child task and forget to resume it.
-- Must suspend root first:
--   ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS SUSPEND;
--   ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_CALL_ACTIVITY RESUME;  -- or whichever child
--   ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS RESUME;
