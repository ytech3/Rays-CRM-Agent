-- =============================================================================
-- ACCOUNT CROSSWALK TABLE + REFRESH TASK
-- Connects Salesforce Account IDs to TDC Patron Account IDs
-- =============================================================================
--
-- LINKAGE PATH:
--   Opportunity.ACCOUNT_ID 
--     → V_ODS_SALESFORCE_ACCOUNT.ID 
--     → V_ODS_SALESFORCE_ACCOUNT.PRIMARY_ACCOUNT_NUMBER_C 
--     → TRY_CAST(... AS FLOAT) 
--     → V_TDC_TICKET_SALES_UNIFIED.FINANCIAL_PATRON_ACCOUNT_ID
--
-- DATABASE: TBRDP_DW_PROD.IM_RPT
-- =============================================================================

CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_ACCOUNT_CROSSWALK AS
SELECT 
    sa.ID                                           AS SF_ACCOUNT_ID,
    sa.NAME                                         AS SF_ACCOUNT_NAME,
    sa.PRIMARY_ACCOUNT_NUMBER_C                     AS PATRON_ACCOUNT_NUMBER,
    TRY_CAST(sa.PRIMARY_ACCOUNT_NUMBER_C AS FLOAT)  AS PATRON_ACCOUNT_ID_FLOAT,
    sa.PERSON_EMAIL                                 AS SF_PERSON_EMAIL,
    sa.BUSINESS_EMAIL_C                             AS SF_BUSINESS_EMAIL,
    sa.PV_ACCOUNT_NAME_C                            AS PV_ACCOUNT_NAME,
    sa.IS_PERSON_ACCOUNT                            AS IS_PERSON_ACCOUNT,
    sa.TYPE                                         AS ACCOUNT_TYPE,
    sa.INDUSTRY                                     AS INDUSTRY,
    sa.OWNER_ID                                     AS ACCOUNT_OWNER_ID,
    sa.TICKET_SALES_REP_C                           AS TICKET_SALES_REP,
    sa.TICKET_SERVICE_REP_C                         AS TICKET_SERVICE_REP,
    sa.SUITE_SALES_REP_C                            AS SUITE_SALES_REP,
    sa.GROUP_SALES_REP_C                            AS GROUP_SALES_REP,
    sa.PARTNERSHIP_STATUS_C                         AS PARTNERSHIP_STATUS,
    sa.LEAD_SOURCE_C                                AS LEAD_SOURCE,
    sa.BILLING_CITY                                 AS BILLING_CITY,
    sa.BILLING_STATE                                AS BILLING_STATE,
    sa.BILLING_POSTAL_CODE                          AS BILLING_ZIP,
    sa.CREATED_DATE                                 AS ACCOUNT_CREATED_DATE,
    CURRENT_TIMESTAMP()                             AS CROSSWALK_UPDATED_AT
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_ACCOUNT sa
WHERE sa.SYSTEM_CURRENT_FLAG = 'Y'
  AND sa.PRIMARY_ACCOUNT_NUMBER_C IS NOT NULL
  AND TRY_CAST(sa.PRIMARY_ACCOUNT_NUMBER_C AS FLOAT) IS NOT NULL;

-- =============================================================================
-- SCHEDULED REFRESH TASK
-- Weekly Monday 6 AM ET — account mappings are relatively stable
-- =============================================================================
CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TASK_REFRESH_ACCOUNT_CROSSWALK
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    SCHEDULE = 'USING CRON 0 6 * * 1 America/New_York'
AS
CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_ACCOUNT_CROSSWALK AS
SELECT 
    sa.ID                                           AS SF_ACCOUNT_ID,
    sa.NAME                                         AS SF_ACCOUNT_NAME,
    sa.PRIMARY_ACCOUNT_NUMBER_C                     AS PATRON_ACCOUNT_NUMBER,
    TRY_CAST(sa.PRIMARY_ACCOUNT_NUMBER_C AS FLOAT)  AS PATRON_ACCOUNT_ID_FLOAT,
    sa.PERSON_EMAIL                                 AS SF_PERSON_EMAIL,
    sa.BUSINESS_EMAIL_C                             AS SF_BUSINESS_EMAIL,
    sa.PV_ACCOUNT_NAME_C                            AS PV_ACCOUNT_NAME,
    sa.IS_PERSON_ACCOUNT                            AS IS_PERSON_ACCOUNT,
    sa.TYPE                                         AS ACCOUNT_TYPE,
    sa.INDUSTRY                                     AS INDUSTRY,
    sa.OWNER_ID                                     AS ACCOUNT_OWNER_ID,
    sa.TICKET_SALES_REP_C                           AS TICKET_SALES_REP,
    sa.TICKET_SERVICE_REP_C                         AS TICKET_SERVICE_REP,
    sa.SUITE_SALES_REP_C                            AS SUITE_SALES_REP,
    sa.GROUP_SALES_REP_C                            AS GROUP_SALES_REP,
    sa.PARTNERSHIP_STATUS_C                         AS PARTNERSHIP_STATUS,
    sa.LEAD_SOURCE_C                                AS LEAD_SOURCE,
    sa.BILLING_CITY                                 AS BILLING_CITY,
    sa.BILLING_STATE                                AS BILLING_STATE,
    sa.BILLING_POSTAL_CODE                          AS BILLING_ZIP,
    sa.CREATED_DATE                                 AS ACCOUNT_CREATED_DATE,
    CURRENT_TIMESTAMP()                             AS CROSSWALK_UPDATED_AT
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_ACCOUNT sa
WHERE sa.SYSTEM_CURRENT_FLAG = 'Y'
  AND sa.PRIMARY_ACCOUNT_NUMBER_C IS NOT NULL
  AND TRY_CAST(sa.PRIMARY_ACCOUNT_NUMBER_C AS FLOAT) IS NOT NULL;

-- NOTE: T_CUSTOMER_360 is rebuilt by TSK_REFRESH_CUSTOMER_360 defined in Tasks.SQL
