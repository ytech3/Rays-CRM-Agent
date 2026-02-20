-- =============================================================================
-- FINAL T_CALL_ACTIVITY REBUILD — Eastern Time Aligned
-- Converts all timestamps to America/New_York to match Tableau dashboard
-- =============================================================================

CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY AS

WITH task_link AS (
    SELECT
        t.ID AS task_id,
        t.WHAT_ID AS opportunity_id,
        t.WHO_ID AS contact_id,
        t.ACCOUNT_ID,
        t.SUBJECT AS task_subject,
        t.DESCRIPTION AS task_notes,
        t.CALL_DISPOSITION
    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK t
    WHERE t.SYSTEM_CURRENT_FLAG = 'Y'
      AND t.IS_DELETED = FALSE
),

session_history_calls AS (
    SELECT
        sh.ID AS session_id,
        'SESSION_HISTORY' AS call_source,
        sh.NAME AS record_name,
        sh.ZVC_ENGAGEMENT_ID_C AS engagement_id,
        INITCAP(sh.ZVC_TYPE_C) AS call_direction,
        sh.ZVC_CHANNEL_C AS call_channel,
        'Contact Center' AS interaction_type,
        sh.ZVC_CHANNEL_SOURCE_C AS channel_source,

        -- TIMESTAMPS CONVERTED TO EASTERN TIME
        CONVERT_TIMEZONE('America/New_York', sh.ZVC_START_TIME_C) AS call_start_time,
        CONVERT_TIMEZONE('America/New_York', sh.ZVC_END_TIME_C) AS call_end_time,

        -- Talk Time: dashboard uses ZVC_ANSWER_TIME_C for Session History
        sh.ZVC_ANSWER_TIME_C AS talk_time_raw,
        CASE
            WHEN sh.ZVC_ANSWER_TIME_C IS NOT NULL
                 AND sh.ZVC_ANSWER_TIME_C LIKE '%:%'
            THEN (SPLIT_PART(sh.ZVC_ANSWER_TIME_C, ':', 1)::INTEGER * 60
                  + SPLIT_PART(sh.ZVC_ANSWER_TIME_C, ':', 2)::INTEGER)
            ELSE NULL
        END AS talk_time_seconds,

        sh.ZVC_DURATION_C AS duration_raw,
        CASE
            WHEN sh.ZVC_DURATION_C IS NULL THEN 0
            WHEN REGEXP_COUNT(sh.ZVC_DURATION_C, ':') = 1 THEN
                TRY_CAST(SPLIT_PART(sh.ZVC_DURATION_C, ':', 1) AS NUMBER) * 60
                + TRY_CAST(SPLIT_PART(sh.ZVC_DURATION_C, ':', 2) AS NUMBER)
            WHEN REGEXP_COUNT(sh.ZVC_DURATION_C, ':') = 2 THEN
                TRY_CAST(SPLIT_PART(sh.ZVC_DURATION_C, ':', 1) AS NUMBER) * 3600
                + TRY_CAST(SPLIT_PART(sh.ZVC_DURATION_C, ':', 2) AS NUMBER) * 60
                + TRY_CAST(SPLIT_PART(sh.ZVC_DURATION_C, ':', 3) AS NUMBER)
            ELSE 0
        END AS duration_seconds,

        sh.ZVC_DISPOSITION_C AS disposition,
        sh.ZVC_DISPOSITION_C AS call_result,
        sh.ZVC_IS_MISSED_C AS is_missed,
        sh.ZVC_IS_TRANSFER_C AS is_transfer,

        sh.OWNER_ID AS agent_owner_id,
        u.NAME AS agent_name,
        sh.ZVC_AGENT_EMAIL_C AS agent_email,
        u.IS_ACTIVE AS agent_is_active,
        CASE
            WHEN u.IS_ACTIVE = FALSE THEN FALSE
            WHEN u.PROFILE_ID != '00ecw000001t0rfAAA' THEN FALSE
            ELSE TRUE
        END AS is_active_sales_rep,

        sh.ZVC_CONSUMER_DISPLAY_NAME_C AS consumer_name,
        sh.ZVC_CONSUMER_NUMBER_C AS consumer_phone,
        sh.ZVC_CONTACT_PHONE_C AS contact_phone,
        NULL AS callee_phone,

        sh.ZVC_NOTES_C AS call_notes,
        NULL AS voicemail_content,
        sh.ZVC_RECORDING_C AS recording_reference,
        sh.ZVC_VOICEMAIL_C AS voicemail_reference,

        sh.ZVC_QUEUE_C AS queue_name,

        sh.ZVC_TASK_ID_C AS linked_task_id,
        tl.opportunity_id,
        tl.contact_id,
        tl.ACCOUNT_ID AS account_id,
        tl.task_subject,
        tl.task_notes,
        tl.CALL_DISPOSITION AS task_call_disposition,

        CONVERT_TIMEZONE('America/New_York', sh.CREATED_DATE) AS created_date,
        CONVERT_TIMEZONE('America/New_York', sh.LAST_MODIFIED_DATE) AS last_modified_date,
        CURRENT_TIMESTAMP() AS loaded_at

    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_ZVC_SESSION_HISTORY_C sh
    LEFT OUTER JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u
        ON LOWER(sh.ZVC_AGENT_EMAIL_C) = LOWER(u.EMAIL)
        AND u.SYSTEM_CURRENT_FLAG = 'Y'
    LEFT JOIN task_link tl
        ON sh.ZVC_TASK_ID_C = tl.task_id
    WHERE sh.SYSTEM_CURRENT_FLAG = 'Y'
      AND sh.IS_DELETED = FALSE
),

zoom_call_log_calls AS (
    SELECT
        cl.ID AS session_id,
        'ZOOM_CALL_LOG' AS call_source,
        cl.NAME AS record_name,
        cl.ZVC_CALL_ID_C AS engagement_id,
        INITCAP(cl.ZVC_CALL_TYPE_C) AS call_direction,
        'Voice' AS call_channel,
        cl.ZVC_INTERACTION_TYPE_C AS interaction_type,
        cl.ZVC_CALL_LEVEL_TYPE_C AS channel_source,

        -- TIMESTAMPS CONVERTED TO EASTERN TIME
        CONVERT_TIMEZONE('America/New_York', cl.ZVC_RING_START_TIME_C) AS call_start_time,
        CONVERT_TIMEZONE('America/New_York', cl.ZVC_CALL_END_TIME_C) AS call_end_time,

        -- Talk Time: dashboard uses ZVC_CALL_DURATION_C for Call Log
        cl.ZVC_CALL_DURATION_C AS talk_time_raw,
        CASE
            WHEN cl.ZVC_CALL_DURATION_C IS NOT NULL
                 AND cl.ZVC_CALL_DURATION_C LIKE '%:%'
            THEN (SPLIT_PART(cl.ZVC_CALL_DURATION_C, ':', 1)::INTEGER * 60
                  + SPLIT_PART(cl.ZVC_CALL_DURATION_C, ':', 2)::INTEGER)
            ELSE NULL
        END AS talk_time_seconds,

        cl.ZVC_CALL_DURATION_C AS duration_raw,
        CASE
            WHEN cl.ZVC_CALL_DURATION_C IS NULL THEN 0
            WHEN REGEXP_COUNT(cl.ZVC_CALL_DURATION_C, ':') = 1 THEN
                TRY_CAST(SPLIT_PART(cl.ZVC_CALL_DURATION_C, ':', 1) AS NUMBER) * 60
                + TRY_CAST(SPLIT_PART(cl.ZVC_CALL_DURATION_C, ':', 2) AS NUMBER)
            WHEN REGEXP_COUNT(cl.ZVC_CALL_DURATION_C, ':') = 2 THEN
                TRY_CAST(SPLIT_PART(cl.ZVC_CALL_DURATION_C, ':', 1) AS NUMBER) * 3600
                + TRY_CAST(SPLIT_PART(cl.ZVC_CALL_DURATION_C, ':', 2) AS NUMBER) * 60
                + TRY_CAST(SPLIT_PART(cl.ZVC_CALL_DURATION_C, ':', 3) AS NUMBER)
            ELSE 0
        END AS duration_seconds,

        NULL AS disposition,
        cl.ZVC_CALL_RESULT_C AS call_result,
        CASE
            WHEN cl.ZVC_CALL_RESULT_C IN ('ring_timeout', 'no_answer', 'missed') THEN TRUE
            ELSE FALSE
        END AS is_missed,
        FALSE AS is_transfer,

        cl.OWNER_ID AS agent_owner_id,
        u.NAME AS agent_name,
        u.EMAIL AS agent_email,
        u.IS_ACTIVE AS agent_is_active,
        CASE
            WHEN u.IS_ACTIVE = FALSE THEN FALSE
            WHEN u.PROFILE_ID != '00ecw000001t0rfAAA' THEN FALSE
            ELSE TRUE
        END AS is_active_sales_rep,

        cl.ZVC_THIRD_PARTY_NAME_C AS consumer_name,
        cl.ZVC_CALLER_PHONE_NUMBER_C AS consumer_phone,
        NULL AS contact_phone,
        cl.ZVC_CALLEE_PHONE_NUMBER_C AS callee_phone,

        NULL AS call_notes,
        cl.ZVC_VOICE_MAIL_C AS voicemail_content,
        NULL AS recording_reference,
        NULL AS voicemail_reference,

        NULL AS queue_name,

        cl.ZVC_TASK_ID_C AS linked_task_id,
        tl.opportunity_id,
        tl.contact_id,
        tl.ACCOUNT_ID AS account_id,
        tl.task_subject,
        tl.task_notes,
        tl.CALL_DISPOSITION AS task_call_disposition,

        CONVERT_TIMEZONE('America/New_York', cl.CREATED_DATE) AS created_date,
        CONVERT_TIMEZONE('America/New_York', cl.LAST_MODIFIED_DATE) AS last_modified_date,
        CURRENT_TIMESTAMP() AS loaded_at

    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C cl
    INNER JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u
        ON cl.OWNER_ID = u.ID
        AND u.SYSTEM_CURRENT_FLAG = 'Y'
    LEFT JOIN task_link tl
        ON cl.ZVC_TASK_ID_C = tl.task_id
    WHERE cl.SYSTEM_CURRENT_FLAG = 'Y'
      AND cl.IS_DELETED = FALSE
      AND cl.ZVC_INTERACTION_TYPE_C = 'Phone'
)

SELECT * FROM session_history_calls
UNION ALL
SELECT * FROM zoom_call_log_calls;


-- Enable change tracking
ALTER TABLE TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY
    SET CHANGE_TRACKING = TRUE;


-- =============================================================================
-- VALIDATE: Compare with dashboard
-- =============================================================================

-- VALIDATE: This month in Eastern Time — should match dashboard
SELECT
    agent_name,
    call_direction,
    COUNT(*) AS total_calls,
    ROUND(AVG(talk_time_seconds), 1) AS avg_talk_time_secs,
    ROUND(AVG(talk_time_seconds) / 60.0, 1) AS avg_talk_time_mins
FROM TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY
WHERE call_start_time >= DATE_TRUNC('MONTH', CURRENT_DATE())
  AND is_active_sales_rep = TRUE
  AND call_direction IN ('Inbound', 'Outbound')
GROUP BY 1, 2
ORDER BY 1, 2;