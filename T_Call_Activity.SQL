-- =============================================================================
-- FIX: Rebuild T_CALL_ACTIVITY with corrected AGENT_OWNER_ID for Session History
-- Session History OWNER_ID is a queue/system ID, not the rep's User ID.
-- We already join to Users via email — just store that User ID instead.
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
        CONVERT_TIMEZONE('America/New_York', sh.ZVC_START_TIME_C) AS call_start_time,
        CONVERT_TIMEZONE('America/New_York', sh.ZVC_END_TIME_C) AS call_end_time,
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

        -- FIX: Use the User ID from email join, NOT sh.OWNER_ID
        COALESCE(u.ID, sh.OWNER_ID) AS agent_owner_id,

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
        CONVERT_TIMEZONE('America/New_York', cl.ZVC_RING_START_TIME_C) AS call_start_time,
        CONVERT_TIMEZONE('America/New_York', cl.ZVC_CALL_END_TIME_C) AS call_end_time,
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
        CASE WHEN cl.ZVC_CALL_RESULT_C IN ('ring_timeout', 'no_answer', 'missed') THEN TRUE ELSE FALSE END AS is_missed,
        FALSE AS is_transfer,

        -- Call Log already uses the correct User ID via INNER JOIN
        u.ID AS agent_owner_id,

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


-- Verify: Ben Knee should now have ONE agent_owner_id across both sources
SELECT 
    call_source,
    agent_name,
    agent_owner_id,
    COUNT(*) AS calls
FROM TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY
WHERE agent_name ILIKE '%Knee%'
  AND call_direction = 'Outbound'
  AND call_start_time >= '2026-02-01'
GROUP BY 1, 2, 3
ORDER BY 1;


ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS SUSPEND;

CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_CALL_ACTIVITY
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    AFTER TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS
AS
BEGIN
    IF ((SELECT COALESCE(MAX(loaded_at), '1900-01-01'::TIMESTAMP)
         FROM TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY) < DATE_TRUNC('DAY', CURRENT_TIMESTAMP())) THEN

        -- INSERT 1: New Session History records
        INSERT INTO TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY
        WITH task_link AS (
            SELECT t.ID AS task_id, t.WHAT_ID AS opportunity_id,
                   t.WHO_ID AS contact_id, t.ACCOUNT_ID,
                   t.SUBJECT AS task_subject, t.DESCRIPTION AS task_notes,
                   t.CALL_DISPOSITION
            FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK t
            WHERE t.SYSTEM_CURRENT_FLAG = 'Y' AND t.IS_DELETED = FALSE
        )
        SELECT
            sh.ID,
            'SESSION_HISTORY',
            sh.NAME,
            sh.ZVC_ENGAGEMENT_ID_C,
            INITCAP(sh.ZVC_TYPE_C),
            sh.ZVC_CHANNEL_C,
            'Contact Center',
            sh.ZVC_CHANNEL_SOURCE_C,
            CONVERT_TIMEZONE('America/New_York', sh.ZVC_START_TIME_C),
            CONVERT_TIMEZONE('America/New_York', sh.ZVC_END_TIME_C),
            sh.ZVC_ANSWER_TIME_C,
            CASE
                WHEN sh.ZVC_ANSWER_TIME_C IS NOT NULL
                     AND sh.ZVC_ANSWER_TIME_C LIKE '%:%'
                THEN (SPLIT_PART(sh.ZVC_ANSWER_TIME_C, ':', 1)::INTEGER * 60
                      + SPLIT_PART(sh.ZVC_ANSWER_TIME_C, ':', 2)::INTEGER)
                ELSE NULL
            END,
            sh.ZVC_DURATION_C,
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
            END,
            sh.ZVC_DISPOSITION_C,
            sh.ZVC_DISPOSITION_C,
            sh.ZVC_IS_MISSED_C,
            sh.ZVC_IS_TRANSFER_C,
            -- FIX: Use User ID from email join, not raw sh.OWNER_ID
            COALESCE(u.ID, sh.OWNER_ID),
            u.NAME,
            sh.ZVC_AGENT_EMAIL_C,
            u.IS_ACTIVE,
            CASE
                WHEN u.IS_ACTIVE = FALSE THEN FALSE
                WHEN u.PROFILE_ID != '00ecw000001t0rfAAA' THEN FALSE
                ELSE TRUE
            END,
            sh.ZVC_CONSUMER_DISPLAY_NAME_C,
            sh.ZVC_CONSUMER_NUMBER_C,
            sh.ZVC_CONTACT_PHONE_C,
            NULL,
            sh.ZVC_NOTES_C,
            NULL,
            sh.ZVC_RECORDING_C,
            sh.ZVC_VOICEMAIL_C,
            sh.ZVC_QUEUE_C,
            sh.ZVC_TASK_ID_C,
            tl.opportunity_id,
            tl.contact_id,
            tl.ACCOUNT_ID,
            tl.task_subject,
            tl.task_notes,
            tl.CALL_DISPOSITION,
            CONVERT_TIMEZONE('America/New_York', sh.CREATED_DATE),
            CONVERT_TIMEZONE('America/New_York', sh.LAST_MODIFIED_DATE),
            CURRENT_TIMESTAMP()
        FROM TBRDP_DW_PROD.IM_RPT.STM_SESSION_HISTORY_CHANGES sh
        LEFT OUTER JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u
            ON LOWER(sh.ZVC_AGENT_EMAIL_C) = LOWER(u.EMAIL)
            AND u.SYSTEM_CURRENT_FLAG = 'Y'
        LEFT JOIN task_link tl ON sh.ZVC_TASK_ID_C = tl.task_id
        WHERE sh.SYSTEM_CURRENT_FLAG = 'Y'
          AND sh.IS_DELETED = FALSE
          AND NOT EXISTS (
              SELECT 1 FROM TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY ca
              WHERE ca.session_id = sh.ID AND ca.call_source = 'SESSION_HISTORY'
          );

        -- INSERT 2: New Zoom Call Log records
        INSERT INTO TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY
        WITH task_link AS (
            SELECT t.ID AS task_id, t.WHAT_ID AS opportunity_id,
                   t.WHO_ID AS contact_id, t.ACCOUNT_ID,
                   t.SUBJECT AS task_subject, t.DESCRIPTION AS task_notes,
                   t.CALL_DISPOSITION
            FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK t
            WHERE t.SYSTEM_CURRENT_FLAG = 'Y' AND t.IS_DELETED = FALSE
        )
        SELECT
            cl.ID,
            'ZOOM_CALL_LOG',
            cl.NAME,
            cl.ZVC_CALL_ID_C,
            INITCAP(cl.ZVC_CALL_TYPE_C),
            'Voice',
            COALESCE(cl.ZVC_INTERACTION_TYPE_C, 'Phone'),
            cl.ZVC_CALL_LEVEL_TYPE_C,
            CONVERT_TIMEZONE('America/New_York', cl.ZVC_RING_START_TIME_C),
            CONVERT_TIMEZONE('America/New_York', cl.ZVC_CALL_END_TIME_C),
            cl.ZVC_CALL_DURATION_C,
            CASE
                WHEN cl.ZVC_CALL_DURATION_C IS NOT NULL
                     AND cl.ZVC_CALL_DURATION_C LIKE '%:%'
                THEN (SPLIT_PART(cl.ZVC_CALL_DURATION_C, ':', 1)::INTEGER * 60
                      + SPLIT_PART(cl.ZVC_CALL_DURATION_C, ':', 2)::INTEGER)
                ELSE NULL
            END,
            cl.ZVC_CALL_DURATION_C,
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
            END,
            NULL,
            cl.ZVC_CALL_RESULT_C,
            CASE WHEN cl.ZVC_CALL_RESULT_C IN ('ring_timeout', 'no_answer', 'missed') THEN TRUE ELSE FALSE END,
            FALSE,
            u.ID,
            u.NAME,
            u.EMAIL,
            u.IS_ACTIVE,
            CASE
                WHEN u.IS_ACTIVE = FALSE THEN FALSE
                WHEN u.PROFILE_ID != '00ecw000001t0rfAAA' THEN FALSE
                ELSE TRUE
            END,
            cl.ZVC_THIRD_PARTY_NAME_C,
            cl.ZVC_CALLER_PHONE_NUMBER_C,
            NULL,
            cl.ZVC_CALLEE_PHONE_NUMBER_C,
            NULL,
            cl.ZVC_VOICE_MAIL_C,
            NULL,
            NULL,
            NULL,
            cl.ZVC_TASK_ID_C,
            tl.opportunity_id,
            tl.contact_id,
            tl.ACCOUNT_ID,
            tl.task_subject,
            tl.task_notes,
            tl.CALL_DISPOSITION,
            CONVERT_TIMEZONE('America/New_York', cl.CREATED_DATE),
            CONVERT_TIMEZONE('America/New_York', cl.LAST_MODIFIED_DATE),
            CURRENT_TIMESTAMP()
        FROM TBRDP_DW_PROD.IM_RPT.STM_CALL_LOG_CHANGES cl
        INNER JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u
            ON cl.OWNER_ID = u.ID
            AND u.SYSTEM_CURRENT_FLAG = 'Y'
        LEFT JOIN task_link tl ON cl.ZVC_TASK_ID_C = tl.task_id
        WHERE cl.SYSTEM_CURRENT_FLAG = 'Y'
          AND cl.IS_DELETED = FALSE
          AND cl.ZVC_INTERACTION_TYPE_C = 'Phone'
          AND NOT EXISTS (
              SELECT 1 FROM TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY ca
              WHERE ca.session_id = cl.ID AND ca.call_source = 'ZOOM_CALL_LOG'
          );

    END IF;
END;

