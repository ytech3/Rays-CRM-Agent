-- =====================================================
-- T_DIM_ACTIVITY_SUMMARY
-- Dimensional model activity detail table for exact
-- Tableau-matching activity counts by rep, date, direction.
--
-- SOURCE: Same dimensional model as Tableau
-- "DM Salesforce Activities Prod" datasource:
-- v_fact_activities + V_DIM_ACTIVITY_TYPE +
-- V_DIM_ACTIVITY_STATUS + V_DIM_CRM_USER__ACTIVITY_OWNER +
-- V_DIM_DATE__ACTIVITY_DATE + V_DIM_OPPORTUNITY +
-- V_DIM_EMAIL_MESSAGE
--
-- PURPOSE: The agent should NEVER say "counts may differ
-- from Tableau" — this table produces exact-match counts.
-- Use for rep-level activity counts by date range.
-- Keep T_EMAIL_ANALYTICS for email content/sentiment and
-- T_CALL_ACTIVITY for call notes/voicemail search.
--
-- COUNTING: Uses COUNT(DISTINCT ACTIVITY_KEY) to match
-- Tableau COUNTD([ACTIVITY_ID]).
--
-- SCOPE: ALL activities (no season/record-type filter).
-- =====================================================

CREATE TABLE IF NOT EXISTS TBRDP_DW_PROD.IM_RPT.T_DIM_ACTIVITY_SUMMARY (
    ACTIVITY_KEY VARCHAR(18),           -- V_FACT_ACTIVITIES_KEY
    ACTIVITY_DATE DATE,                  -- From V_DIM_DATE__ACTIVITY_DATE.DIM_DATE_BK
    ACTIVITY_SUBTYPE VARCHAR(120),       -- Email, Call, Task, ListEmail from V_DIM_ACTIVITY_TYPE
    ACTIVITY_TYPE VARCHAR(765),          -- More specific: "Call Inbound", "Call Outbound", "Email" from V_DIM_ACTIVITY_TYPE
    ACTIVITY_STATUS VARCHAR(120),        -- From V_DIM_ACTIVITY_STATUS
    REP_NAME VARCHAR(255),               -- From V_DIM_CRM_USER__ACTIVITY_OWNER
    REP_USER_ID VARCHAR(18),             -- CRM_USER_ID_BK from V_DIM_CRM_USER__ACTIVITY_OWNER
    OPPORTUNITY_ID VARCHAR(18),          -- From V_DIM_OPPORTUNITY.OPPORTUNITY_ID_BK
    CALL_DURATION_SECONDS NUMBER(38,0),  -- From V_FACT_ACTIVITIES
    EMAIL_INCOMING BOOLEAN,              -- From V_DIM_EMAIL_MESSAGE
    EMAIL_MESSAGE_DATE TIMESTAMP_NTZ,    -- From V_DIM_EMAIL_MESSAGE
    LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_WATERMARK TIMESTAMP_TZ        -- MAX(_FIVETRAN_SYNCED) at build time; informational "source as-of" (no longer used to gate rebuilds)
);

-- =====================================================
-- TASK: Refresh T_DIM_ACTIVITY_SUMMARY
-- Pure SQL — no AI functions, ~2-3s per run, negligible cost.
-- STANDALONE (NOT part of the TSK_ENRICH_NEW_EMAILS DAG).
-- Rebuilds UNCONDITIONALLY every 30 minutes so LOADED_AT always
-- reflects a recent run. (Previously gated by a _FIVETRAN_SYNCED
-- watermark, which made the freshness footer read "stale" overnight
-- and occasionally lagged new rows. The rebuild is cheap enough that
-- an unconditional refresh is simpler and more predictable.)
-- Sources from dimensional model for exact Tableau match.
--
-- DEPLOY NOTE: CREATE OR REPLACE TASK leaves the task SUSPENDED, and
-- IM_RPT is a managed-access schema — run this as the task owner role.
-- You MUST resume it afterward (see ALTER TASK ... RESUME below).
-- =====================================================
CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_DIM_ACTIVITY_SUMMARY
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    SCHEDULE = '30 MINUTE'
AS
    CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_DIM_ACTIVITY_SUMMARY AS
    SELECT
        fact.V_FACT_ACTIVITIES_KEY AS ACTIVITY_KEY,
        dad.DIM_DATE_BK AS ACTIVITY_DATE,
        actt.ACTIVITY_SUBTYPE,
        actt.ACTIVITY_TYPE,
        acts.ACTIVITY_STATUS,
        aown.NAME AS REP_NAME,
        aown.CRM_USER_ID_BK AS REP_USER_ID,
        dopps.OPPORTUNITY_ID_BK AS OPPORTUNITY_ID,
        fact.CALL_DURATION_IN_SECONDS AS CALL_DURATION_SECONDS,
        dem.INCOMING AS EMAIL_INCOMING,
        dem.MESSAGE_DATE AS EMAIL_MESSAGE_DATE,
        CURRENT_TIMESTAMP() AS LOADED_AT,
        (SELECT MAX(_FIVETRAN_SYNCED)
           FROM TBRDP_DW_PROD.IM_RPT.V_FACT_ACTIVITIES) AS SOURCE_WATERMARK
    FROM TBRDP_DW_PROD.IM_RPT.V_FACT_ACTIVITIES fact
    INNER JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_ACTIVITY_TYPE actt
        ON fact.V_DIM_ACTIVITY_TYPE_KEY = actt.V_DIM_ACTIVITY_TYPE_KEY
    LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_ACTIVITY_STATUS acts
        ON fact.V_DIM_ACTIVITY_STATUS_KEY = acts.V_DIM_ACTIVITY_STATUS_KEY
    LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_CRM_USER__ACTIVITY_OWNER aown
        ON fact.V_DIM_CRM_USER__ACTIVITY_OWNER_KEY = aown.V_DIM_CRM_USER__ACTIVITY_OWNER_KEY
        AND aown.SYSTEM_CURRENT_FLAG = 'Y'
    LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_DATE__ACTIVITY_DATE dad
        ON fact.V_DIM_DATE__ACTIVITY_DATE_KEY = dad.V_DIM_DATE__ACTIVITY_DATE_KEY
    LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_OPPORTUNITY dopps
        ON fact.V_DIM_OPPORTUNITY_KEY = dopps.V_DIM_OPPORTUNITY_KEY
    LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_EMAIL_MESSAGE dem
        ON fact.V_DIM_EMAIL_MESSAGE_KEY = dem.V_DIM_EMAIL_MESSAGE_KEY;

-- REQUIRED after the CREATE OR REPLACE above (task is created suspended):
ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_DIM_ACTIVITY_SUMMARY RESUME;
