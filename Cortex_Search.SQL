-- =====================================================
-- CORTEX SEARCH SERVICES
-- Three semantic search services for the ARM Agent
-- All read from views (not tables) for incremental refresh
-- =====================================================

-- 1. EMAIL SEARCH SERVICE
-- Source: V_EMAIL_SEARCH_SOURCE (view on T_EMAIL_ENRICHED)
-- Searchable column: TEXT_BODY
-- Refresh: Every 4 hours (incremental)
CREATE OR REPLACE CORTEX SEARCH SERVICE TBRDP_DW_PROD.IM_RPT.EMAIL_SEARCH_SERVICE
    ON TEXT_BODY
    ATTRIBUTES SUBJECT, FROM_ADDRESS, TO_ADDRESS, MESSAGE_DATE, RELATED_TO_ID,
               SENTIMENT_CATEGORY, EMAIL_TOPIC_TEXT, EMAIL_SIGNAL_TEXT, EMAIL_SUMMARY
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    TARGET_LAG = '4 hours'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    COMMENT = 'Semantic search for CRM email communications - reads from view directly'
    REFRESH_MODE = INCREMENTAL
AS (
    SELECT * FROM TBRDP_DW_PROD.IM_RPT.V_EMAIL_SEARCH_SOURCE
);

-- 2. CALL SEARCH SERVICE
-- Source: V_CALL_SEARCH_SOURCE (view on T_CALL_ACTIVITY)
-- Searchable column: SEARCH_CONTENT
-- Refresh: Daily (incremental)
CREATE OR REPLACE CORTEX SEARCH SERVICE TBRDP_DW_PROD.IM_RPT.CALL_SEARCH_SERVICE
    ON SEARCH_CONTENT
    ATTRIBUTES AGENT_NAME, CALL_DIRECTION, CALL_SOURCE, DISPOSITION, CALL_RESULT,
               CALL_DURATION_CATEGORY, OPPORTUNITY_ID, ACCOUNT_ID, CALL_DATE
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    TARGET_LAG = '1 day'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    REFRESH_MODE = INCREMENTAL
AS (
    SELECT * FROM TBRDP_DW_PROD.IM_RPT.V_CALL_SEARCH_SOURCE
);

-- 3. OPPORTUNITY SEARCH SERVICE
-- Source: V_OPPORTUNITY_CONTEXT_SEARCH (view joining opportunity + deal health data)
-- Searchable column: SEARCHABLE_CONTENT
-- Refresh: Every 6 hours (incremental)
CREATE OR REPLACE CORTEX SEARCH SERVICE TBRDP_DW_PROD.IM_RPT.OPPORTUNITY_SEARCH_SERVICE
    ON SEARCHABLE_CONTENT
    ATTRIBUTES OPPORTUNITY_NAME, ACCOUNT_ID, STAGE_NAME, AMOUNT, CLOSE_DATE,
               HEALTH_CATEGORY, HEALTH_SCORE, OWNER_ID
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    TARGET_LAG = '6 hours'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    COMMENT = 'Semantic search for opportunity context - reads from view directly'
    REFRESH_MODE = INCREMENTAL
AS (
    SELECT * FROM TBRDP_DW_PROD.IM_RPT.V_OPPORTUNITY_CONTEXT_SEARCH
);
