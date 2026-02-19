-- =====================================================
-- STEP 1: Create T_CALL_ACTIVITY (Permanent Table)
-- Pure SQL - ZERO AI functions - ZERO cost risk
-- One-time bulk load from Session History
-- =====================================================

CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY AS
WITH task_link AS (
    -- Link sessions to opportunities via Task.WHAT_ID
    SELECT
        t.ID AS task_id,
        t.WHAT_ID AS opportunity_id,
        t.WHO_ID AS contact_id,
        t.ACCOUNT_ID,
        t.SUBJECT AS task_subject,
        t.DESCRIPTION AS task_notes,
        t.CALL_DISPOSITION,
        t.CALL_DISPOSITION_C,
        t.CALL_TYPE,
        t.CALL_DURATION_IN_SECONDS AS task_call_duration_seconds
    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK t
    WHERE t.SYSTEM_CURRENT_FLAG = 'Y'
      AND t.IS_DELETED = FALSE
)
SELECT
    -- Session Identity
    sh.ID AS session_id,
    sh.NAME AS session_name,
    sh.ZVC_ENGAGEMENT_ID_C AS engagement_id,

    -- Call Direction & Type
    sh.ZVC_TYPE_C AS call_direction,           -- 'Inbound' or 'Outbound'
    sh.ZVC_CHANNEL_C AS call_channel,          -- 'Voice', etc.
    sh.ZVC_CHANNEL_SOURCE_C AS channel_source,

    -- Timing
    sh.ZVC_START_TIME_C AS call_start_time,
    sh.ZVC_END_TIME_C AS call_end_time,
    sh.ZVC_DURATION_C AS duration_raw,         -- 'HH:MM' or 'MM:SS' string
    -- Parse duration string to seconds for analytics
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
    sh.ZVC_ANSWER_TIME_C AS answer_time,
    sh.ZVC_WAIT_TIME_C AS wait_time,
    sh.ZVC_WARP_UP_TIME_C AS wrap_up_time,
    sh.ZVC_HANDLING_TIME_C AS handling_time,

    -- Outcome & Disposition
    sh.ZVC_DISPOSITION_C AS disposition,
    sh.ZVC_IS_MISSED_C AS is_missed,
    sh.ZVC_IS_TRANSFER_C AS is_transfer,
    sh.ZVC_IS_TRANSFER_TO_QUEUE_C AS is_transfer_to_queue,
    sh.ZVC_IS_UPGRADE_C AS is_upgrade,

    -- Agent Info
    sh.OWNER_ID AS agent_owner_id,
    sh.ZVC_AGENT_NAME_C AS agent_name,
    sh.ZVC_AGENT_EMAIL_C AS agent_email,
    sh.ZVC_AGENT_USER_EMAIL_C AS agent_user_email,
    sh.ZVC_AGENT_ID_C AS agent_id,

    -- Customer/Contact Info
    sh.ZVC_CONSUMER_DISPLAY_NAME_C AS consumer_name,
    sh.ZVC_CONSUMER_NUMBER_C AS consumer_phone,
    sh.ZVC_CONTACT_PHONE_C AS contact_phone,

    -- Notes & Content (THE GOLD - 14,533 rows have notes)
    sh.ZVC_NOTES_C AS call_notes,
    sh.ZVC_VOICEMAIL_C AS voicemail_info,
    sh.ZVC_RECORDING_C AS recording_reference,

    -- Queue / Routing
    sh.ZVC_QUEUE_C AS queue_name,
    sh.ZVC_QUEUE_WAIT_TYPE_C AS queue_wait_type,

    -- Salesforce Linkages (via Task join)
    sh.ZVC_TASK_ID_C AS linked_task_id,
    tl.opportunity_id,
    tl.contact_id,
    tl.ACCOUNT_ID AS account_id,
    tl.task_subject,
    tl.task_notes,
    tl.CALL_DISPOSITION AS task_call_disposition,

    -- Salesforce Direct Links (mostly NULL but preserved)
    sh.ZVC_CONTACT_C AS sf_contact_id,
    sh.ZVC_ACCOUNT_C AS sf_account_id,
    sh.ZVC_LEAD_C AS sf_lead_id,
    sh.ZVC_CAMPAIGN_C AS sf_campaign_id,
    sh.ZVC_CASE_C AS sf_case_id,

    -- Metadata
    sh.CREATED_DATE,
    sh.LAST_MODIFIED_DATE,
    CURRENT_TIMESTAMP() AS loaded_at

FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_ZVC_SESSION_HISTORY_C sh
LEFT JOIN task_link tl
    ON sh.ZVC_TASK_ID_C = tl.task_id
WHERE sh.SYSTEM_CURRENT_FLAG = 'Y'
  AND sh.IS_DELETED = FALSE;



-- Verify the load 
-- Run this immediately after creation to validate the load:
SELECT
    COUNT(*) AS total_rows,
    COUNT(opportunity_id) AS rows_linked_to_opportunity,
    COUNT(account_id) AS rows_linked_to_account,
    COUNT(contact_id) AS rows_linked_to_contact,
    COUNT(call_notes) AS rows_with_notes,
    COUNT(DISTINCT agent_name) AS unique_agents,
    COUNT(CASE WHEN call_direction = 'Inbound' THEN 1 END) AS inbound_calls,
    COUNT(CASE WHEN call_direction = 'Outbound' THEN 1 END) AS outbound_calls,
    ROUND(AVG(duration_seconds), 1) AS avg_duration_secs,
    MIN(call_start_time) AS earliest_call,
    MAX(call_start_time) AS latest_call
FROM TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY;

-- Enable change tracking 
ALTER TABLE TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY
    SET CHANGE_TRACKING = TRUE;

-- STEP 2
-- This append only stream detexts new sessions records as they sync from Salesforce. It feeds the incremental refresh task 

CREATE OR REPLACE STREAM TBRDP_DW_PROD.IM_RPT.STM_SESSION_HISTORY_CHANGES
    ON VIEW TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_ZVC_SESSION_HISTORY_C
    APPEND_ONLY = TRUE
    SHOW_INITIAL_ROWS = FALSE;

