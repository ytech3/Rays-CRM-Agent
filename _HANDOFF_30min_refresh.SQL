-- =====================================================================
-- HAND-OFF: Finish enabling the 30-minute refresh of T_DIM_ACTIVITY_SUMMARY
-- For: the role that administers TBRDP_DW_PROD.IM_RPT (managed-access schema)
--      and/or the role that owns the CRM task DAG (<PIPELINE_ROLE>).
-- =====================================================================
--
-- BACKGROUND / CURRENT STATE
-- --------------------------
-- TSK_REFRESH_DIM_ACTIVITY_SUMMARY was redefined to run STANDALONE every
-- 30 minutes (previously a child of TSK_ENRICH_NEW_EMAILS, gated daily and
-- only when new emails arrived). The new definition rebuilds the table only
-- when V_FACT_ACTIVITIES has new data, using a _FIVETRAN_SYNCED watermark.
--
-- PROBLEM: the CREATE OR REPLACE was run by an analytics/consumer role, so
-- the task is currently OWNED BY THE WRONG ROLE and is non-runnable:
--   (a) that role lacks account-level EXECUTE TASK, and
--   (b) that role cannot SELECT V_FACT_ACTIVITIES / the V_DIM_* views.
-- IM_RPT is a managed-access schema, so only the schema owner can re-home it.
--
-- GOAL: task owned by <PIPELINE_ROLE> (the role that owns the rest of the
-- CRM DAG and can already read the dimensional model + holds EXECUTE TASK),
-- running every 30 min, rebuilding only when the source changed.
--
-- WHY: makes "how many calls/emails did rep X make today" current within
-- 30 min instead of up to a day stale. Pure SQL, negligible compute.
-- NOTE: only helps if V_FACT_ACTIVITIES (Fivetran) actually loads more than
-- once/day — confirm with: SELECT MAX(_FIVETRAN_SYNCED) FROM ...V_FACT_ACTIVITIES;
-- =====================================================================


-- ---------------------------------------------------------------------
-- STEP 0 — Identify the roles (run as a role that can SHOW these)
-- ---------------------------------------------------------------------
SHOW SCHEMAS LIKE 'IM_RPT' IN DATABASE TBRDP_DW_PROD;      -- 'owner' = schema owner role
SHOW TASKS IN SCHEMA TBRDP_DW_PROD.IM_RPT;                 -- 'owner' of TSK_ENRICH_NEW_EMAILS = <PIPELINE_ROLE>
-- Replace <PIPELINE_ROLE> below with that owner.


-- ---------------------------------------------------------------------
-- STEP 1 — Re-home the task to <PIPELINE_ROLE>
-- Run as the IM_RPT schema owner (managed-access requirement).
-- ---------------------------------------------------------------------
GRANT OWNERSHIP ON TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_DIM_ACTIVITY_SUMMARY
    TO ROLE <PIPELINE_ROLE> COPY CURRENT GRANTS;


-- ---------------------------------------------------------------------
-- STEP 2 — Everything below runs as <PIPELINE_ROLE>
-- (already has SELECT on the dim views and EXECUTE TASK)
-- ---------------------------------------------------------------------
USE ROLE <PIPELINE_ROLE>;
USE WAREHOUSE TBRDP_DW_CORTEX_XS_WH;


-- STEP 2a — Seed T_DIM_ACTIVITY_SUMMARY so the SOURCE_WATERMARK guard works
--           (the current table predates that column). Also loads fresh data now.
CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_DIM_ACTIVITY_SUMMARY AS
SELECT
    fact.V_FACT_ACTIVITIES_KEY        AS ACTIVITY_KEY,
    dad.DIM_DATE_BK                   AS ACTIVITY_DATE,
    actt.ACTIVITY_SUBTYPE,
    actt.ACTIVITY_TYPE,
    acts.ACTIVITY_STATUS,
    aown.NAME                         AS REP_NAME,
    aown.CRM_USER_ID_BK               AS REP_USER_ID,
    dopps.OPPORTUNITY_ID_BK           AS OPPORTUNITY_ID,
    fact.CALL_DURATION_IN_SECONDS     AS CALL_DURATION_SECONDS,
    dem.INCOMING                      AS EMAIL_INCOMING,
    dem.MESSAGE_DATE                  AS EMAIL_MESSAGE_DATE,
    CURRENT_TIMESTAMP()               AS LOADED_AT,
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


-- STEP 2b — (Optional) confirm the live task definition is the 30-min standalone
--           version with the watermark guard before resuming.
SELECT GET_DDL('TASK', 'TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_DIM_ACTIVITY_SUMMARY');
-- Expected: SCHEDULE = '30 MINUTE', no AFTER clause, body guarded by
-- IF ((SELECT MAX(_FIVETRAN_SYNCED) FROM ...V_FACT_ACTIVITIES)
--     > (SELECT COALESCE(MAX(SOURCE_WATERMARK),'1900-01-01'::TIMESTAMP)
--        FROM ...T_DIM_ACTIVITY_SUMMARY)) THEN  CREATE OR REPLACE TABLE ... ;
-- If it is NOT, re-create it from DIM_Activity_Summary.SQL (30-min variant).


-- STEP 2c — Resume and force one test run
ALTER TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_DIM_ACTIVITY_SUMMARY RESUME;
EXECUTE TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_DIM_ACTIVITY_SUMMARY;


-- ---------------------------------------------------------------------
-- STEP 3 — Verify
-- ---------------------------------------------------------------------
-- Task ran clean? (expect SUCCEEDED, or SKIPPED when nothing changed)
SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, ERROR_MESSAGE
FROM TABLE(TBRDP_DW_PROD.INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'TSK_REFRESH_DIM_ACTIVITY_SUMMARY'))
ORDER BY SCHEDULED_TIME DESC
LIMIT 5;

-- Data is fresh and watermark populated?
SELECT MAX(LOADED_AT) AS built_at, MAX(SOURCE_WATERMARK) AS source_as_of
FROM TBRDP_DW_PROD.IM_RPT.T_DIM_ACTIVITY_SUMMARY;

-- Scheduled correctly? (expect state=started, schedule=30 MINUTE, no predecessor)
SHOW TASKS LIKE 'TSK_REFRESH_DIM_ACTIVITY_SUMMARY' IN SCHEMA TBRDP_DW_PROD.IM_RPT;


-- ---------------------------------------------------------------------
-- STEP 4 — (Optional, recommended) tighten the freshness alert
-- Health_Check.SQL currently flags T_DIM_ACTIVITY_SUMMARY stale after 48h.
-- With a 30-min refresh, lower that threshold to ~2-3h so a stalled
-- refresh actually alerts.
-- ---------------------------------------------------------------------
