-- Total Revenue Summary by Year
SELECT 
    SEASON_YEAR,
    TICKET_TYPE_GROUPING,
    DATA_SOURCE,
    COUNT(*) AS record_count,
    COUNT(DISTINCT FINANCIAL_PATRON_ACCOUNT_ID) AS unique_customers,
    SUM(COALESCE(PRICE, 0)) AS total_revenue,
    ROUND(SUM(COALESCE(PRICE, 0)) / NULLIF(COUNT(DISTINCT FINANCIAL_PATRON_ACCOUNT_ID), 0), 2) AS revenue_per_customer
FROM TBRDP_DW_PROD.IM_RPT.V_TDC_TICKET_SALES_UNIFIED
WHERE SEASON_YEAR IN (2023, 2024, 2025, 2026)
GROUP BY SEASON_YEAR, TICKET_TYPE_GROUPING, DATA_SOURCE
ORDER BY SEASON_YEAR DESC, total_revenue DESC;


-- YTD Revenue by Season Year (All Sales to Date)
-- Shows cumulative revenue for 2023, 2024, 2025, and 2026 seasons as of today (Feb 5, 2026)
SELECT 
    SEASON_YEAR,
    TICKET_TYPE_GROUPING,
    DATA_SOURCE,
    COUNT(*) AS record_count,
    COUNT(DISTINCT FINANCIAL_PATRON_ACCOUNT_ID) AS unique_customers,
    SUM(COALESCE(PRICE, 0)) AS cumulative_revenue,
    ROUND(SUM(COALESCE(PRICE, 0)) / NULLIF(COUNT(DISTINCT FINANCIAL_PATRON_ACCOUNT_ID), 0), 2) AS revenue_per_customer
FROM TBRDP_DW_PROD.IM_RPT.V_TDC_TICKET_SALES_UNIFIED
WHERE SEASON_YEAR IN (2023, 2024, 2025, 2026)
  AND PURCHASE_DATE <= CURRENT_DATE()  -- All sales through today
GROUP BY SEASON_YEAR, TICKET_TYPE_GROUPING, DATA_SOURCE
ORDER BY SEASON_YEAR DESC, cumulative_revenue DESC;

SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    TABLE_NAME,
    TABLE_SCHEMA,
    TABLE_CATALOG
FROM TBRDP_DW_PROD.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'V_ODS_SALESFORCE_OPPORTUNITY'
  AND TABLE_SCHEMA = 'IM_RPT'
  AND TABLE_CATALOG = 'TBRDP_DW_PROD'
ORDER BY ORDINAL_POSITION;

SELECT 
    column_name,
    ARRAY_AGG(DISTINCT value) AS possible_values
FROM (
    SELECT 
        column_name,
        value
    FROM (
        SELECT 
            'ID' AS column_name, ID AS value
        FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'RECORD_TYPE_ID', RECORD_TYPE_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'STAGE_NAME', STAGE_NAME FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'ACCOUNT_ID', ACCOUNT_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'NAME', NAME FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'EST_REVENUE_C', CAST(EST_REVENUE_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'IS_DELETED', CAST(IS_DELETED AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'PARTNERSHIP_TYPE_C', PARTNERSHIP_TYPE_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'RENEWAL_TYPE_C', RENEWAL_TYPE_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'REVENUE_TYPE_C', REVENUE_TYPE_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'AGENCY_INCLUSION_C', AGENCY_INCLUSION_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'ATTRITION_AMOUNT_C', CAST(ATTRITION_AMOUNT_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'BRAND_REACH_C', BRAND_REACH_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'END_SEASON_C', END_SEASON_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'EXCLUSIVITY_C', EXCLUSIVITY_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LEAGUE_DEAL_C', LEAGUE_DEAL_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'RATING_C', RATING_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'REAL_ESTATE_C', REAL_ESTATE_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'START_SEASON_C', START_SEASON_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'THIRD_PARTIES_C', THIRD_PARTIES_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'UPSELL_AMOUNT_C', CAST(UPSELL_AMOUNT_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LEADERSHIP_ASSISTANCE_C', CAST(LEADERSHIP_ASSISTANCE_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'CAMPAIGN_ID', CAMPAIGN_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'SEASON_C', SEASON_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'OWNER_ID', OWNER_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LEAD_SOURCE', LEAD_SOURCE FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'AMOUNT', CAST(AMOUNT AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'CLOSE_DATE', CAST(CLOSE_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'CREATED_DATE', CAST(CREATED_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'OBJECTIONS_C', OBJECTIONS_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'PENDING_PAYMENT_C', CAST(PENDING_PAYMENT_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'SYSTEM_CURRENT_FLAG', SYSTEM_CURRENT_FLAG FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'SYSTEM_UPDATE_DATE', CAST(SYSTEM_UPDATE_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'SECONDARY_OBJECTIONS_C', SECONDARY_OBJECTIONS_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'SYSTEM_CREATE_DATE', CAST(SYSTEM_CREATE_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'SYSTEM_END_DATE', CAST(SYSTEM_END_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'SYSTEM_START_DATE', CAST(SYSTEM_START_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'IS_WON', CAST(IS_WON AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'IS_CLOSED', CAST(IS_CLOSED AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'TYPE', TYPE FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'FIRST_COMPLETED_ACTIVITY_C', CAST(FIRST_COMPLETED_ACTIVITY_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'SALE_DIRECTION_C', SALE_DIRECTION_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'TOTAL_COMPLETED_ACTIVITIES_C', CAST(TOTAL_COMPLETED_ACTIVITIES_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'TOTAL_COMPLETED_PHONE_CALLS_C', CAST(TOTAL_COMPLETED_PHONE_CALLS_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'DESCRIPTION', DESCRIPTION FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'TICKET_TYPE_C', TICKET_TYPE_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'ADMIN_TEXT_C', ADMIN_TEXT_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'AGE_IN_DAYS', CAST(AGE_IN_DAYS AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'BUDGET_CONFIRMED_C', CAST(BUDGET_CONFIRMED_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'CATEGORY_C', CATEGORY_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'CONTACT_C', CONTACT_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'CONTACT_ID', CONTACT_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'CONTRACT_ID', CONTRACT_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'CREATED_BY_ID', CREATED_BY_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'CURRENT_GENERATORS_C', CURRENT_GENERATORS_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'DELIVERY_INSTALLATION_STATUS_C', DELIVERY_INSTALLATION_STATUS_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'DEPOSIT_INTEREST_C', DEPOSIT_INTEREST_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'DEPOSIT_OPPORTUNITY_C', DEPOSIT_OPPORTUNITY_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'DISCOVERY_COMPLETED_C', CAST(DISCOVERY_COMPLETED_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'ESTIMATED_REVENUE_C', CAST(ESTIMATED_REVENUE_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'FISCAL', FISCAL FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'FISCAL_QUARTER', CAST(FISCAL_QUARTER AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'FISCAL_YEAR', CAST(FISCAL_YEAR AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'FORECAST_CATEGORY', FORECAST_CATEGORY FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'FORECAST_CATEGORY_NAME', FORECAST_CATEGORY_NAME FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'GAME_EVENT_C', GAME_EVENT_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'GROUP_SALES_REP_C', GROUP_SALES_REP_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'HAS_OPEN_ACTIVITY', CAST(HAS_OPEN_ACTIVITY AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'HAS_OPPORTUNITY_LINE_ITEM', CAST(HAS_OPPORTUNITY_LINE_ITEM AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'HAS_OVERDUE_TASK', CAST(HAS_OVERDUE_TASK AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'IS_PRIORITY_RECORD', CAST(IS_PRIORITY_RECORD AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LAST_ACTIVITY_DATE', CAST(LAST_ACTIVITY_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LAST_ACTIVITY_IN_DAYS', CAST(LAST_ACTIVITY_IN_DAYS AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LAST_AMOUNT_CHANGED_HISTORY_ID', LAST_AMOUNT_CHANGED_HISTORY_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LAST_CLOSE_DATE_CHANGED_HISTORY_ID', LAST_CLOSE_DATE_CHANGED_HISTORY_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LAST_MODIFIED_BY_ID', LAST_MODIFIED_BY_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LAST_MODIFIED_DATE', CAST(LAST_MODIFIED_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LAST_REFERENCED_DATE', CAST(LAST_REFERENCED_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LAST_STAGE_CHANGE_DATE', CAST(LAST_STAGE_CHANGE_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LAST_STAGE_CHANGE_IN_DAYS', CAST(LAST_STAGE_CHANGE_IN_DAYS AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LAST_VIEWED_DATE', CAST(LAST_VIEWED_DATE AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LEGACY_OPPORTUNITY_ID_C', LEGACY_OPPORTUNITY_ID_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'LOSS_REASON_C', LOSS_REASON_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'MAIN_COMPETITORS_C', MAIN_COMPETITORS_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'NEXT_STEP', NEXT_STEP FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'NUMBER_OF_TICKETS_C', CAST(NUMBER_OF_TICKETS_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'OBJECTION_DETAILS_C', OBJECTION_DETAILS_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'ONLINE_PURCHASE_C', CAST(ONLINE_PURCHASE_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'OPPORTUNITY_SCORE_C', CAST(OPPORTUNITY_SCORE_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'ORDER_ID_C', ORDER_ID_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'ORDER_NUMBER_C', ORDER_NUMBER_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'OTHER_DEPARTMENTS_C', OTHER_DEPARTMENTS_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'PARTIAL_PAYMENT_C', CAST(PARTIAL_PAYMENT_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'PRICEBOOK_2_ID', PRICEBOOK_2_ID FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'PROBABILITY', CAST(PROBABILITY AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'PROPOSAL_DUE_DATE_C', CAST(PROPOSAL_DUE_DATE_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'PRO_VENUE_ID_C', PRO_VENUE_ID_C FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'PUSH_COUNT', CAST(PUSH_COUNT AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'RELOCATION_INTEREST_C', CAST(RELOCATION_INTEREST_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
        UNION ALL
        SELECT 'ROI_ANALYSIS_COMPLETED_C', CAST(ROI_ANALYSIS_COMPLETED_C AS VARCHAR) FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
    )
)
GROUP BY column_name
ORDER BY column_name;
SELECT 
  COLUMN_NAME,
  DATA_TYPE,
  TABLE_NAME,
  TABLE_SCHEMA,
  TABLE_CATALOG
FROM TBRDP_DW_PROD.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'V_ODS_SALESFORCE_TASK'
  AND TABLE_SCHEMA = 'IM_RPT'
  AND TABLE_CATALOG = 'TBRDP_DW_PROD'
ORDER BY ORDINAL_POSITION;SELECT 
  COLUMN_NAME,
  DATA_TYPE AS ANSWER_TYPE,
  TABLE_NAME,
  TABLE_SCHEMA,
  TABLE_CATALOG
FROM TBRDP_DW_PROD.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN (
    'V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C',
    'V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE',
    'V_ODS_SALESFORCE_CRM_ZVC_SESSION_HISTORY_C',
    'V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C'
  )
  AND TABLE_SCHEMA = 'IM_RPT'
  AND TABLE_CATALOG = 'TBRDP_DW_PROD'
ORDER BY TABLE_NAME, ORDINAL_POSITIONSELECT 
  COLUMN_NAME,
  DATA_TYPE AS ANSWER_TYPE,
  TABLE_NAME,
  TABLE_SCHEMA,
  TABLE_CATALOG
FROM TBRDP_DW_PROD.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C'
  AND TABLE_SCHEMA = 'IM_RPT'
  AND TABLE_CATALOG = 'TBRDP_DW_PROD'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT 
  COLUMN_NAME,
  DATA_TYPE AS ANSWER_TYPE,
  TABLE_NAME,
  TABLE_SCHEMA,
  TABLE_CATALOG
FROM TBRDP_DW_PROD.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE'
  AND TABLE_SCHEMA = 'IM_RPT'
  AND TABLE_CATALOG = 'TBRDP_DW_PROD'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT 
  COLUMN_NAME,
  DATA_TYPE AS ANSWER_TYPE,
  TABLE_NAME,
  TABLE_SCHEMA,
  TABLE_CATALOG
FROM TBRDP_DW_PROD.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'V_ODS_SALESFORCE_CRM_ZVC_SESSION_HISTORY_C'
  AND TABLE_SCHEMA = 'IM_RPT'
  AND TABLE_CATALOG = 'TBRDP_DW_PROD'
ORDER BY TABLE_NAME, ORDINAL_POSITION;


SELECT 
  COLUMN_NAME,
  DATA_TYPE AS ANSWER_TYPE,
  TABLE_NAME,
  TABLE_SCHEMA,
  TABLE_CATALOG
FROM TBRDP_DW_PROD.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'V_ODS_SALESFORCE_OPPORTUNITY'
  AND TABLE_SCHEMA = 'IM_RPT'
  AND TABLE_CATALOG = 'TBRDP_DW_PROD'
ORDER BY TABLE_NAME, ORDINAL_POSITION;




-- =============================================================================
-- EMAIL ENRICHMENT DYNAMIC TABLE
-- Purpose: Enrich email data with AI-powered sentiment, topics, and summaries
-- =============================================================================

-- =============================================================================
-- EMAIL ENRICHMENT DYNAMIC TABLE - CORRECTED VERSION
-- Purpose: Enrich email data with AI-powered sentiment, topics, and summaries
-- Fixed: CLASSIFY_TEXT options format + warehouse name
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE TBRDP_DW_PROD.IM_RPT.DT_EMAIL_ENRICHED
TARGET_LAG = '1 hour'
WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
AS
SELECT 
    -- Original Email Fields
    ID AS EMAIL_ID,
    PARENT_ID,
    ACTIVITY_ID,
    FROM_ADDRESS,
    TO_ADDRESS,
    CC_ADDRESS,
    BCC_ADDRESS,
    SUBJECT,
    TEXT_BODY,
    HTML_BODY,
    MESSAGE_DATE,
    INCOMING,
    STATUS,
    RELATED_TO_ID,  -- Links to Opportunity ID
    
    -- AI Enrichment: Sentiment Analysis
    -- Returns numeric score from -1 (negative) to 1 (positive)
    SNOWFLAKE.CORTEX.SENTIMENT(TEXT_BODY) AS SENTIMENT_SCORE,
    
    -- Classify sentiment into categories
    CASE 
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(TEXT_BODY) >= 0.5 THEN 'Positive'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(TEXT_BODY) >= 0 THEN 'Neutral'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(TEXT_BODY) >= -0.5 THEN 'Slightly Negative'
        ELSE 'Negative'
    END AS SENTIMENT_CATEGORY,
    
    -- AI Enrichment: Topic Classification (FIXED)
    -- Using ARRAY_CONSTRUCT instead of [] syntax
    -- Removed options parameter that was causing the error
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        TEXT_BODY,
        ARRAY_CONSTRUCT(
            'Pricing Discussion', 
            'Contract Negotiation', 
            'Product Question', 
            'Timeline/Deadline', 
            'Objection/Concern', 
            'Follow-up Request',
            'Meeting Request', 
            'Decision Maker Involved', 
            'Budget Discussion',
            'Competitor Mention', 
            'Renewal Discussion', 
            'Upsell Opportunity'
        )
    ) AS EMAIL_TOPIC,
    
    -- AI Enrichment: Signal Detection (SIMPLIFIED)
    -- Single classification for key signals
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        TEXT_BODY,
        ARRAY_CONSTRUCT(
            'Urgent Response Needed',
            'Contains Unanswered Question', 
            'Pricing Concern Mentioned',
            'Decision Pending',
            'Positive Buying Signal',
            'Risk or Objection Signal',
            'General Communication'
        )
    ) AS EMAIL_SIGNAL,
    
    -- AI Enrichment: Email Summary
    -- Using AI_COMPLETE for summarization (AI_SUMMARIZE doesn't exist)
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-8b',
        CONCAT(
            'Summarize this sales email in one concise sentence (max 50 words): ',
            SUBSTRING(TEXT_BODY, 1, 2000)  -- Limit input to avoid token limits
        )
    ) AS EMAIL_SUMMARY,
    
    -- Metadata
    CREATED_DATE,
    SYSTEM_CURRENT_FLAG,
    CURRENT_TIMESTAMP() AS ENRICHMENT_TIMESTAMP

FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE
WHERE TEXT_BODY IS NOT NULL 
  AND LENGTH(TEXT_BODY) > 50  -- Filter out very short emails
  AND LENGTH(TEXT_BODY) < 32000  -- Filter out extremely long emails that might cause issues
  AND SYSTEM_CURRENT_FLAG = 'Y';

-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Wait 2-3 minutes for initial refresh, then run these:

SELECT 
    EMAIL_ID,
    SUBJECT,
    EMAIL_SUMMARY  -- Remove the LEFT() function
FROM TBRDP_DW_PROD.IM_RPT.DT_EMAIL_ENRICHED
LIMIT 10;

-- Check if dynamic table was created successfully
SHOW DYNAMIC TABLES LIKE 'DT_EMAIL_ENRICHED' IN SCHEMA TBRDP_DW_PROD.IM_RPT;

-- Check refresh status
SELECT 
    name,
    scheduling_state,
    target_lag,
    data_timestamp,
    refresh_mode,
    last_refresh_status
FROM INFORMATION_SCHEMA.DYNAMIC_TABLES
WHERE table_name = 'DT_EMAIL_ENRICHED'
  AND table_schema = 'IM_RPT';

-- Preview enrichment results (run after refresh completes)
SELECT 
    EMAIL_ID,
    SUBJECT,
    SENTIMENT_CATEGORY,
    SENTIMENT_SCORE,
    EMAIL_TOPIC,
    EMAIL_SIGNAL,
    LEFT(EMAIL_SUMMARY, 100) AS SUMMARY_PREVIEW,
    ENRICHMENT_TIMESTAMP
FROM TBRDP_DW_PROD.IM_RPT.DT_EMAIL_ENRICHED
LIMIT 50;

-- Sentiment distribution
SELECT 
    SENTIMENT_CATEGORY,
    COUNT(*) AS email_count,
    ROUND(AVG(SENTIMENT_SCORE), 3) AS avg_score
FROM TBRDP_DW_PROD.IM_RPT.DT_EMAIL_ENRICHED
GROUP BY SENTIMENT_CATEGORY
ORDER BY avg_score DESC;

-- Topic distribution
SELECT 
    EMAIL_TOPIC,
    COUNT(*) AS email_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM TBRDP_DW_PROD.IM_RPT.DT_EMAIL_ENRICHED
GROUP BY EMAIL_TOPIC
ORDER BY email_count DESC;

-- Signal distribution
SELECT 
    EMAIL_SIGNAL,
    COUNT(*) AS email_count
FROM TBRDP_DW_PROD.IM_RPT.DT_EMAIL_ENRICHED
GROUP BY EMAIL_SIGNAL
ORDER BY email_count DESC;
-- =============================================================================
-- OPPORTUNITY ACTIVITY METRICS DYNAMIC TABLE
-- Purpose: Aggregate all activity metrics per opportunity for deal health scoring
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE TBRDP_DW_PROD.IM_RPT.DT_OPPORTUNITY_ACTIVITY_METRICS
TARGET_LAG = '1 hour'
WAREHOUSE = TBRDP_DW_CORTEX_XS_WH  -- Replace with your warehouse name
AS
WITH email_metrics AS (
    SELECT 
        e.RELATED_TO_ID AS opportunity_id,
        COUNT(*) AS total_emails,
        COUNT(CASE WHEN e.INCOMING = TRUE THEN 1 END) AS incoming_emails,
        COUNT(CASE WHEN e.INCOMING = FALSE THEN 1 END) AS outgoing_emails,
        MAX(e.MESSAGE_DATE) AS last_email_date,
        DATEDIFF('day', MAX(e.MESSAGE_DATE), CURRENT_DATE()) AS days_since_last_email,
        
        -- Sentiment metrics from enriched table
        AVG(ee.SENTIMENT_SCORE) AS avg_email_sentiment,
        COUNT(CASE WHEN ee.SENTIMENT_CATEGORY = 'Negative' THEN 1 END) AS negative_email_count,
        COUNT(CASE WHEN ee.EMAIL_TOPIC IN ('Objection/Concern', 'Competitor Mention') THEN 1 END) AS risk_emails
        
    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE e
    LEFT JOIN TBRDP_DW_PROD.IM_RPT.DT_EMAIL_ENRICHED ee
        ON e.ID = ee.EMAIL_ID
    WHERE e.RELATED_TO_ID IS NOT NULL
    GROUP BY e.RELATED_TO_ID
),

call_metrics AS (
    SELECT 
        c.ID AS opportunity_id,
        COUNT(*) AS total_calls,
        SUM(NULLIF(TRY_CAST(c.ZVC_CALL_DURATION_C AS NUMBER), NULL)) AS total_call_duration_seconds,
        AVG(NULLIF(TRY_CAST(c.ZVC_CALL_DURATION_C AS NUMBER), NULL)) AS avg_call_duration_seconds,
        MAX(c.ZVC_RING_START_TIME_C) AS last_call_date,
        DATEDIFF('day', MAX(c.ZVC_RING_START_TIME_C), CURRENT_DATE()) AS days_since_last_call,
        COUNT(CASE WHEN c.ZVC_CALL_RESULT_C ILIKE 'Completed' THEN 1 END) AS completed_calls,
        COUNT(CASE WHEN c.ZVC_CALL_RESULT_C ILIKE 'No Answer' THEN 1 END) AS missed_calls
    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C c
    WHERE c.ID IS NOT NULL
    GROUP BY c.ID
),

task_metrics AS (
    SELECT 
        t.WHAT_ID AS opportunity_id,
        COUNT(*) AS total_tasks,
        COUNT(CASE WHEN t.STATUS = 'Completed' THEN 1 END) AS completed_tasks,
        COUNT(CASE WHEN t.STATUS = 'Not Started' THEN 1 END) AS pending_tasks,
        COUNT(CASE WHEN t.IS_CLOSED = TRUE THEN 1 END) AS closed_tasks,
        MAX(CASE WHEN t.STATUS = 'Completed' THEN t.COMPLETED_DATE_TIME END) AS last_completed_task_date,
        DATEDIFF('day', MAX(CASE WHEN t.STATUS = 'Completed' THEN t.COMPLETED_DATE_TIME END), CURRENT_DATE()) AS days_since_last_completed_task
    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK t
    WHERE t.WHAT_ID IS NOT NULL
    GROUP BY t.WHAT_ID
)

SELECT 
    o.ID AS opportunity_id,
    o.NAME AS opportunity_name,
    o.ACCOUNT_ID,
    o.OWNER_ID,
    o.STAGE_NAME,
    o.AMOUNT,
    o.EST_REVENUE_C,
    o.PROBABILITY,
    o.CLOSE_DATE,
    o.CREATED_DATE,
    
    -- Email Metrics
    COALESCE(em.total_emails, 0) AS total_emails,
    COALESCE(em.incoming_emails, 0) AS incoming_emails,
    COALESCE(em.outgoing_emails, 0) AS outgoing_emails,
    em.last_email_date,
    COALESCE(em.days_since_last_email, 9999) AS days_since_last_email,
    COALESCE(em.avg_email_sentiment, 0) AS avg_email_sentiment,
    COALESCE(em.negative_email_count, 0) AS negative_email_count,
    COALESCE(em.risk_emails, 0) AS risk_emails,
    
    -- Call Metrics
    COALESCE(cm.total_calls, 0) AS total_calls,
    COALESCE(cm.total_call_duration_seconds, 0) AS total_call_duration_seconds,
    COALESCE(cm.avg_call_duration_seconds, 0) AS avg_call_duration_seconds,
    cm.last_call_date,
    COALESCE(cm.days_since_last_call, 9999) AS days_since_last_call,
    COALESCE(cm.completed_calls, 0) AS completed_calls,
    COALESCE(cm.missed_calls, 0) AS missed_calls,
    
    -- Task Metrics
    COALESCE(tm.total_tasks, 0) AS total_tasks,
    COALESCE(tm.completed_tasks, 0) AS completed_tasks,
    COALESCE(tm.pending_tasks, 0) AS pending_tasks,
    tm.last_completed_task_date,
    COALESCE(tm.days_since_last_completed_task, 9999) AS days_since_last_completed_task,
    
    -- Engagement Score Calculation
    CASE 
        WHEN COALESCE(em.days_since_last_email, 9999) <= 7 
         AND COALESCE(cm.days_since_last_call, 9999) <= 14
         AND COALESCE(em.avg_email_sentiment, 0) > 0 
        THEN 'High Engagement'
        
        WHEN COALESCE(em.days_since_last_email, 9999) <= 30 
         OR COALESCE(cm.days_since_last_call, 9999) <= 30
        THEN 'Medium Engagement'
        
        ELSE 'Low Engagement'
    END AS engagement_level,
    
    -- Risk Flags
    CASE 
        WHEN COALESCE(em.days_since_last_email, 9999) > 60 
         AND COALESCE(cm.days_since_last_call, 9999) > 60
        THEN TRUE ELSE FALSE 
    END AS is_ghosted,
    
    CASE 
        WHEN COALESCE(em.negative_email_count, 0) > 2 
         OR COALESCE(em.risk_emails, 0) > 1
        THEN TRUE ELSE FALSE 
    END AS has_sentiment_risk,
    
    -- Timestamp
    CURRENT_TIMESTAMP() AS metrics_timestamp

FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
LEFT JOIN email_metrics em ON o.ID = em.opportunity_id
LEFT JOIN call_metrics cm ON o.ID = cm.opportunity_id
LEFT JOIN task_metrics tm ON o.ID = tm.opportunity_id
WHERE o.SYSTEM_CURRENT_FLAG = 'Y'
  AND o.IS_CLOSED = FALSE;  -- Focus on open opportunities

-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- High-risk opportunities (ghosted with negative sentiment)
SELECT 
    opportunity_name,
    stage_name,
    amount,
    days_since_last_email,
    days_since_last_call,
    avg_email_sentiment,
    engagement_level,
    is_ghosted,
    has_sentiment_risk
FROM TBRDP_DW_PROD.IM_RPT.DT_OPPORTUNITY_ACTIVITY_METRICS
WHERE is_ghosted = TRUE 
   OR has_sentiment_risk = TRUE
ORDER BY amount DESC
LIMIT 20;

-- Engagement distribution
SELECT 
    engagement_level,
    COUNT(*) AS opportunity_count,
    SUM(amount) AS total_pipeline_value
FROM TBRDP_DW_PROD.IM_RPT.DT_OPPORTUNITY_ACTIVITY_METRICS
GROUP BY engagement_level
ORDER BY total_pipeline_value DESC;

-- =============================================================================
-- DEAL HEALTH SCORING DYNAMIC TABLE
-- Purpose: AI-powered assessment of deal health and risk factors
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE TBRDP_DW_PROD.IM_RPT.DT_DEAL_HEALTH_SCORE
TARGET_LAG = '1 hour'
WAREHOUSE = TBRDP_DW_CORTEX_XS_WH  -- Replace with your warehouse name
AS
WITH deal_context AS (
    SELECT 
        oam.opportunity_id,
        oam.opportunity_name,
        oam.stage_name,
        oam.amount,
        oam.probability,
        oam.close_date,
        DATEDIFF('day', CURRENT_DATE(), oam.close_date) AS days_until_close,
        
        -- Activity signals
        oam.total_emails,
        oam.total_calls,
        oam.days_since_last_email,
        oam.days_since_last_call,
        oam.avg_email_sentiment,
        oam.engagement_level,
        oam.is_ghosted,
        oam.has_sentiment_risk,
        
        -- Opportunity details
        o.DESCRIPTION,
        o.NEXT_STEP,
        o.OBJECTIONS_C,
        o.LOSS_REASON_C,
        o.AGE_IN_DAYS,
        o.LAST_STAGE_CHANGE_IN_DAYS
        
    FROM TBRDP_DW_PROD.IM_RPT.DT_OPPORTUNITY_ACTIVITY_METRICS oam
    JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
        ON oam.opportunity_id = o.ID
    WHERE o.SYSTEM_CURRENT_FLAG = 'Y'
      AND o.IS_CLOSED = FALSE
)

SELECT 
    opportunity_id,
    opportunity_name,
    stage_name,
    amount,
    probability,
    close_date,
    days_until_close,
    
    -- Activity metrics
    total_emails,
    total_calls,
    days_since_last_email,
    days_since_last_call,
    avg_email_sentiment,
    engagement_level,
    
    -- Risk flags
    is_ghosted,
    has_sentiment_risk,
    
    -- Calculated Health Score (0-100)
    -- Higher score = healthier deal
    GREATEST(0, LEAST(100,
        50  -- Base score
        + CASE WHEN engagement_level = 'High Engagement' THEN 20
               WHEN engagement_level = 'Medium Engagement' THEN 5
               ELSE -15 END
        + (avg_email_sentiment * 15)  -- Sentiment bonus/penalty
        + CASE WHEN days_since_last_email <= 7 THEN 10
               WHEN days_since_last_email <= 30 THEN 5
               ELSE -10 END
        + CASE WHEN is_ghosted = TRUE THEN -30 ELSE 0 END
        + CASE WHEN has_sentiment_risk = TRUE THEN -20 ELSE 0 END
        + CASE WHEN days_until_close < 30 AND total_emails > 5 THEN 10 ELSE 0 END
    )) AS health_score,
    
    -- Health Category
    CASE 
        WHEN GREATEST(0, LEAST(100,
            50 + CASE WHEN engagement_level = 'High Engagement' THEN 20
                     WHEN engagement_level = 'Medium Engagement' THEN 5
                     ELSE -15 END
            + (avg_email_sentiment * 15)
            + CASE WHEN days_since_last_email <= 7 THEN 10
                   WHEN days_since_last_email <= 30 THEN 5
                   ELSE -10 END
            + CASE WHEN is_ghosted = TRUE THEN -30 ELSE 0 END
            + CASE WHEN has_sentiment_risk = TRUE THEN -20 ELSE 0 END
            + CASE WHEN days_until_close < 30 AND total_emails > 5 THEN 10 ELSE 0 END
        )) >= 70 THEN 'Healthy'
        WHEN GREATEST(0, LEAST(100,
            50 + CASE WHEN engagement_level = 'High Engagement' THEN 20
                     WHEN engagement_level = 'Medium Engagement' THEN 5
                     ELSE -15 END
            + (avg_email_sentiment * 15)
            + CASE WHEN days_since_last_email <= 7 THEN 10
                   WHEN days_since_last_email <= 30 THEN 5
                   ELSE -10 END
            + CASE WHEN is_ghosted = TRUE THEN -30 ELSE 0 END
            + CASE WHEN has_sentiment_risk = TRUE THEN -20 ELSE 0 END
            + CASE WHEN days_until_close < 30 AND total_emails > 5 THEN 10 ELSE 0 END
        )) >= 40 THEN 'At Risk'
        ELSE 'Critical'
    END AS health_category,
    
    -- AI-Powered Deal Assessment
    -- Generates natural language summary of deal status
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-8b',
        CONCAT(
            'Analyze this sales opportunity and provide a 2-sentence assessment: ',
            'Deal: ', opportunity_name, '. ',
            'Stage: ', stage_name, '. ',
            'Value: $', amount, '. ',
            'Days to close: ', days_until_close, '. ',
            'Last contact: ', days_since_last_email, ' days ago. ',
            'Email sentiment: ', ROUND(avg_email_sentiment, 2), '. ',
            'Engagement: ', engagement_level, '. ',
            CASE WHEN is_ghosted THEN 'Customer is not responding. ' ELSE '' END,
            CASE WHEN has_sentiment_risk THEN 'Negative sentiment detected. ' ELSE '' END,
            'What are the biggest risks and recommended actions?'
        )
    ) AS ai_deal_assessment,
    
    -- AI-Powered Next Best Action
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-8b',
        CONCAT(
            'Based on this sales opportunity, what is the single most important next step? ',
            'Stage: ', stage_name, '. ',
            'Days since last contact: ', days_since_last_email, '. ',
            'Close date: ', days_until_close, ' days away. ',
            CASE WHEN is_ghosted THEN 'Customer ghosted. ' ELSE '' END,
            'Respond in 1 concise sentence starting with an action verb.'
        )
    ) AS ai_next_action,
    
    -- Timestamp
    CURRENT_TIMESTAMP() AS scoring_timestamp

FROM deal_context;

-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Critical deals requiring immediate attention
SELECT 
    opportunity_name,
    stage_name,
    amount,
    health_category,
    health_score,
    days_until_close,
    ai_deal_assessment,
    ai_next_action
FROM TBRDP_DW_PROD.IM_RPT.DT_DEAL_HEALTH_SCORE
WHERE health_category = 'Critical'
   OR (health_category = 'At Risk' AND days_until_close <= 30)
ORDER BY amount DESC
LIMIT 10;

-- Pipeline health overview
SELECT 
    health_category,
    COUNT(*) AS deal_count,
    SUM(amount) AS total_value,
    ROUND(AVG(health_score), 1) AS avg_health_score,
    ROUND(AVG(days_until_close), 0) AS avg_days_to_close
FROM TBRDP_DW_PROD.IM_RPT.DT_DEAL_HEALTH_SCORE
GROUP BY health_category
ORDER BY 
    CASE health_category
        WHEN 'Healthy' THEN 1
        WHEN 'At Risk' THEN 2
        WHEN 'Critical' THEN 3
    END;

-- Sample AI assessments
SELECT 
    opportunity_name,
    stage_name,
    health_category,
    LEFT(ai_deal_assessment, 200) AS assessment_preview,
    ai_next_action
FROM TBRDP_DW_PROD.IM_RPT.DT_DEAL_HEALTH_SCORE
LIMIT 5;

-- =============================================================================
-- CORTEX SEARCH SERVICE: EMAIL SEARCH - JSON FIX
-- Purpose: Semantic search across all email communications
-- Fixed: Extract label from VARIANT/JSON columns for attributes
-- =============================================================================
-- =============================================================================
-- PHASE 2: CORTEX SEARCH SERVICES - COMPLETE WORKAROUND
-- Using regular tables instead of views/dynamic tables for change tracking
-- =============================================================================

-- =============================================================================
-- PART 1: EMAIL SEARCH SERVICE
-- =============================================================================

-- Step 1A: Create regular table for email search
CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_EMAIL_SEARCH_SOURCE AS
SELECT 
    TEXT_BODY,
    SUBJECT,
    FROM_ADDRESS,
    TO_ADDRESS,
    MESSAGE_DATE,
    RELATED_TO_ID,
    SENTIMENT_CATEGORY,
    EMAIL_TOPIC:label::VARCHAR AS EMAIL_TOPIC_TEXT,
    EMAIL_SIGNAL:label::VARCHAR AS EMAIL_SIGNAL_TEXT,
    EMAIL_SUMMARY
FROM TBRDP_DW_PROD.IM_RPT.DT_EMAIL_ENRICHED
WHERE TEXT_BODY IS NOT NULL;

-- Step 1B: Enable change tracking
ALTER TABLE TBRDP_DW_PROD.IM_RPT.T_EMAIL_SEARCH_SOURCE 
    SET CHANGE_TRACKING = TRUE;

-- Step 1C: Create the Email Search service
CREATE OR REPLACE CORTEX SEARCH SERVICE TBRDP_DW_PROD.IM_RPT.EMAIL_SEARCH_SERVICE
  ON TEXT_BODY
  ATTRIBUTES SUBJECT, FROM_ADDRESS, TO_ADDRESS, MESSAGE_DATE, RELATED_TO_ID, SENTIMENT_CATEGORY, EMAIL_TOPIC_TEXT, EMAIL_SIGNAL_TEXT
  WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
  COMMENT = 'Semantic search service for CRM email communications with AI enrichment'
AS (
    SELECT * FROM TBRDP_DW_PROD.IM_RPT.T_EMAIL_SEARCH_SOURCE
);

-- Step 1D: Create refresh task
CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.REFRESH_EMAIL_SEARCH_SOURCE
  WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
  SCHEDULE = '60 MINUTE'
AS
INSERT OVERWRITE INTO TBRDP_DW_PROD.IM_RPT.T_EMAIL_SEARCH_SOURCE
SELECT 
    TEXT_BODY,
    SUBJECT,
    FROM_ADDRESS,
    TO_ADDRESS,
    MESSAGE_DATE,
    RELATED_TO_ID,
    SENTIMENT_CATEGORY,
    EMAIL_TOPIC:label::VARCHAR AS EMAIL_TOPIC_TEXT,
    EMAIL_SIGNAL:label::VARCHAR AS EMAIL_SIGNAL_TEXT,
    EMAIL_SUMMARY
FROM TBRDP_DW_PROD.IM_RPT.DT_EMAIL_ENRICHED
WHERE TEXT_BODY IS NOT NULL;

-- Step 1E: Start the task
ALTER TASK TBRDP_DW_PROD.IM_RPT.REFRESH_EMAIL_SEARCH_SOURCE RESUME;


-- =============================================================================
-- PART 2: OPPORTUNITY SEARCH SERVICE
-- =============================================================================

-- Step 2A: Create view for opportunity context (if not exists)
CREATE OR REPLACE VIEW TBRDP_DW_PROD.IM_RPT.V_OPPORTUNITY_CONTEXT_SEARCH AS
SELECT 
    o.ID AS opportunity_id,
    o.NAME AS opportunity_name,
    o.ACCOUNT_ID,
    o.STAGE_NAME,
    o.AMOUNT,
    o.CLOSE_DATE,
    
    -- Combine all text fields into searchable content
    CONCAT_WS(' | ',
        'Opportunity Name: ', o.NAME,
        'Description: ', COALESCE(o.DESCRIPTION, ''),
        'Next Step: ', COALESCE(o.NEXT_STEP, ''),
        'Objections: ', COALESCE(o.OBJECTIONS_C, ''),
        'Objection Details: ', COALESCE(o.OBJECTION_DETAILS_C, ''),
        'Loss Reason: ', COALESCE(o.LOSS_REASON_C, ''),
        'Secondary Objections: ', COALESCE(o.SECONDARY_OBJECTIONS_C, '')
    ) AS searchable_content,
    
    -- Include deal health info if available
    COALESCE(dhs.health_category, 'Unknown') AS health_category,
    COALESCE(dhs.health_score, 50) AS health_score,
    
    o.OWNER_ID,
    o.CREATED_DATE,
    o.LAST_MODIFIED_DATE

FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
LEFT JOIN TBRDP_DW_PROD.IM_RPT.DT_DEAL_HEALTH_SCORE dhs
    ON o.ID = dhs.opportunity_id
WHERE o.SYSTEM_CURRENT_FLAG = 'Y'
  AND o.IS_CLOSED = FALSE;

-- Step 2B: Create regular table for opportunity search
CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_SEARCH_SOURCE AS
SELECT * FROM TBRDP_DW_PROD.IM_RPT.V_OPPORTUNITY_CONTEXT_SEARCH;

-- Step 2C: Enable change tracking
ALTER TABLE TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_SEARCH_SOURCE
    SET CHANGE_TRACKING = TRUE;

-- Step 2D: Create the Opportunity Search service
CREATE OR REPLACE CORTEX SEARCH SERVICE TBRDP_DW_PROD.IM_RPT.OPPORTUNITY_SEARCH_SERVICE
  ON searchable_content
  ATTRIBUTES opportunity_name, STAGE_NAME, AMOUNT, CLOSE_DATE, health_category, OWNER_ID
  WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
  COMMENT = 'Semantic search for opportunity context, objections, and deal notes'
AS (
    SELECT * FROM TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_SEARCH_SOURCE
);

-- Step 2E: Create refresh task
CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.REFRESH_OPPORTUNITY_SEARCH_SOURCE
  WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
  SCHEDULE = '60 MINUTE'
AS
INSERT OVERWRITE INTO TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_SEARCH_SOURCE
SELECT * FROM TBRDP_DW_PROD.IM_RPT.V_OPPORTUNITY_CONTEXT_SEARCH;

-- Step 2F: Start the task
ALTER TASK TBRDP_DW_PROD.IM_RPT.REFRESH_OPPORTUNITY_SEARCH_SOURCE RESUME;


-- =============================================================================
-- PHASE 3: SEMANTIC VIEW - CRM SALES INTELLIGENCE
-- Natural language interface for business analytics via Cortex Analyst
-- =============================================================================

-- This semantic view provides a business-friendly layer over your CRM data
-- enabling natural language questions like:
-- - "What's my total pipeline value by stage?"
-- - "Show me at-risk deals closing this month"
-- - "Which reps have the highest weighted pipeline?"

CREATE OR REPLACE SEMANTIC VIEW TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE
  
  -- =============================================================================
  -- LOGICAL TABLES - Business entities in your CRM
  -- =============================================================================
  TABLES (
    
    -- Opportunities with deal health enrichment
    opportunities AS TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
      PRIMARY KEY (ID)
      WITH SYNONYMS ('deals', 'pipeline', 'sales opportunities')
      COMMENT = 'Sales opportunities with revenue, stage, and close dates',
    
    -- Deal health scores and AI assessments
    deal_health AS TBRDP_DW_PROD.IM_RPT.DT_DEAL_HEALTH_SCORE
      PRIMARY KEY (opportunity_id)
      WITH SYNONYMS ('health scores', 'deal assessment')
      COMMENT = 'AI-generated health scores and risk assessments for opportunities',
    
    -- Activity and engagement metrics
    activity_metrics AS TBRDP_DW_PROD.IM_RPT.DT_OPPORTUNITY_ACTIVITY_METRICS
      PRIMARY KEY (opportunity_id)
      WITH SYNONYMS ('engagement', 'activities', 'interactions')
      COMMENT = 'Aggregated email, call, and task metrics per opportunity',
    
    -- Sales rep information
    users AS TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER
      PRIMARY KEY (ID)
      WITH SYNONYMS ('sales reps', 'account executives', 'owners')
      COMMENT = 'Sales representative details and team information'
  )
  
  -- =============================================================================
  -- RELATIONSHIPS - How tables join together
  -- =============================================================================
  RELATIONSHIPS (
    opportunities_to_health AS
      opportunities (ID) REFERENCES deal_health (opportunity_id),
    
    opportunities_to_activity AS
      opportunities (ID) REFERENCES activity_metrics (opportunity_id),
    
    opportunities_to_owner AS
      opportunities (OWNER_ID) REFERENCES users (ID)
  )
  
  -- =============================================================================
  -- FACTS - Row-level quantitative data
  -- =============================================================================
  FACTS (
    -- Opportunity financial facts
    opportunities.deal_amount AS opportunities.AMOUNT
      COMMENT = 'Revenue amount of the opportunity',
    
    opportunities.weighted_amount AS opportunities.AMOUNT * (opportunities.PROBABILITY / 100)
      COMMENT = 'Probability-weighted revenue (amount × probability)',
    
    opportunities.probability_pct AS opportunities.PROBABILITY
      COMMENT = 'Win probability percentage (0-100)',
    
    -- Health score facts
    deal_health.health_score_value AS deal_health.health_score
      COMMENT = 'AI-calculated health score (0-100)',
    
    -- Activity engagement facts
    activity_metrics.total_emails_count AS activity_metrics.total_emails
      COMMENT = 'Total email count for this opportunity',
    
    activity_metrics.total_calls_count AS activity_metrics.total_calls
      COMMENT = 'Total call count for this opportunity',
    
    activity_metrics.days_since_contact AS activity_metrics.days_since_last_email
      COMMENT = 'Number of days since last email contact',
    
    activity_metrics.avg_sentiment_score AS activity_metrics.avg_email_sentiment
      COMMENT = 'Average email sentiment score (-1 to 1)'
  )
  
  -- =============================================================================
  -- DIMENSIONS - Categorical attributes for grouping/filtering
  -- =============================================================================
  DIMENSIONS (
    
    -- Opportunity dimensions
    opportunities.opp_name AS opportunities.NAME
      WITH SYNONYMS ('opportunity name', 'deal name')
      COMMENT = 'Name of the sales opportunity',
    
    opportunities.stage AS opportunities.STAGE_NAME
      WITH SYNONYMS ('sales stage', 'pipeline stage', 'deal stage')
      COMMENT = 'Current stage in the sales pipeline',
    
    opportunities.close_date AS opportunities.CLOSE_DATE
      WITH SYNONYMS ('expected close', 'close date')
      COMMENT = 'Expected close date for the opportunity',
    
    opportunities.close_month AS DATE_TRUNC('MONTH', opportunities.CLOSE_DATE)
      WITH SYNONYMS ('closing month')
      COMMENT = 'Month when the opportunity is expected to close',
    
    opportunities.close_quarter AS DATE_TRUNC('QUARTER', opportunities.CLOSE_DATE)
      WITH SYNONYMS ('closing quarter')
      COMMENT = 'Quarter when the opportunity is expected to close',
    
    opportunities.is_closed AS opportunities.IS_CLOSED
      WITH SYNONYMS ('closed status')
      COMMENT = 'Whether the opportunity is closed (won or lost)',
    
    opportunities.is_won AS opportunities.IS_WON
      WITH SYNONYMS ('won status')
      COMMENT = 'Whether the opportunity was won',
    
    -- Health dimensions
    deal_health.health_category AS deal_health.health_category
      WITH SYNONYMS ('health status', 'deal health', 'risk level')
      COMMENT = 'Health category: Healthy, At Risk, or Critical',
    
    deal_health.is_at_risk AS (deal_health.health_category IN ('At Risk', 'Critical'))
      WITH SYNONYMS ('at risk flag', 'risky deals')
      COMMENT = 'Boolean flag for at-risk opportunities',
    
    -- Activity dimensions
    activity_metrics.engagement_level AS activity_metrics.engagement_level
      WITH SYNONYMS ('activity level', 'engagement score')
      COMMENT = 'Engagement level: High, Medium, or Low',
    
    activity_metrics.has_sentiment_risk AS activity_metrics.has_sentiment_risk
      WITH SYNONYMS ('negative sentiment flag', 'sentiment risk')
      COMMENT = 'Whether the opportunity has negative email sentiment (risk indicator)',
    
    activity_metrics.is_ghosted_flag AS activity_metrics.is_ghosted
      WITH SYNONYMS ('ghosted status', 'no recent contact')
      COMMENT = 'Whether opportunity has had no contact for 60+ days',
    
    -- Sales rep dimensions
    users.rep_name AS users.NAME
      WITH SYNONYMS ('sales rep', 'account executive', 'owner name')
      COMMENT = 'Name of the sales representative',
    
    users.rep_email AS users.EMAIL
      WITH SYNONYMS ('owner email')
      COMMENT = 'Email address of the sales representative',
    
    users.is_active AS users.IS_ACTIVE
      WITH SYNONYMS ('active rep', 'active user')
      COMMENT = 'Whether the sales rep is currently active'
  )
  
  -- =============================================================================
  -- METRICS - Aggregated business measures
  -- =============================================================================
  METRICS (
    
    -- Pipeline value metrics
    opportunities.total_pipeline_value AS SUM(opportunities.deal_amount)
      COMMENT = 'Total value of all opportunities in the pipeline',
    
    opportunities.weighted_pipeline_value AS SUM(opportunities.weighted_amount)
      COMMENT = 'Total probability-weighted pipeline value',
    
    opportunities.average_deal_size AS AVG(opportunities.deal_amount)
      COMMENT = 'Average opportunity value',
    
    -- Deal count metrics
    opportunities.opportunity_count AS COUNT(opportunities.ID)
      COMMENT = 'Total number of opportunities',
    
    opportunities.won_count AS SUM(CASE WHEN opportunities.IS_WON = TRUE THEN 1 ELSE 0 END)
      COMMENT = 'Number of won opportunities',
    
    opportunities.lost_count AS SUM(CASE WHEN opportunities.IS_CLOSED = TRUE AND opportunities.IS_WON = FALSE THEN 1 ELSE 0 END)
      COMMENT = 'Number of lost opportunities',
    
    -- Health metrics
    deal_health.average_health_score AS AVG(deal_health.health_score_value)
      COMMENT = 'Average health score across opportunities',
    
    deal_health.at_risk_count AS COUNT(CASE WHEN deal_health.is_at_risk = TRUE THEN 1 END)
      COMMENT = 'Count of at-risk or critical opportunities',
    
    deal_health.at_risk_value AS SUM(CASE WHEN deal_health.is_at_risk = TRUE THEN opportunities.deal_amount ELSE 0 END)
      COMMENT = 'Total pipeline value of at-risk opportunities',
    
    -- Engagement metrics
    activity_metrics.total_email_volume AS SUM(activity_metrics.total_emails_count)
      COMMENT = 'Total number of emails across all opportunities',
    
    activity_metrics.total_call_volume AS SUM(activity_metrics.total_calls_count)
      COMMENT = 'Total number of calls across all opportunities',
    
    activity_metrics.avg_emails_per_deal AS AVG(activity_metrics.total_emails_count)
      COMMENT = 'Average number of emails per opportunity',
    
    activity_metrics.ghosted_deal_count AS COUNT(CASE WHEN activity_metrics.is_ghosted_flag = TRUE THEN 1 END)
      COMMENT = 'Number of opportunities with no contact for 60+ days',
    
    -- Win rate metrics
    opportunities.win_rate_pct AS 
      (SUM(CASE WHEN opportunities.IS_WON = TRUE THEN 1 ELSE 0 END) * 100.0) / 
      NULLIF(SUM(CASE WHEN opportunities.IS_CLOSED = TRUE THEN 1 ELSE 0 END), 0)
      COMMENT = 'Win rate percentage (won deals / total closed deals)',
    
    -- Rep performance metrics
    users.avg_deals_per_rep AS AVG(opportunities.opportunity_count)
      COMMENT = 'Average number of deals per sales rep',
    
    users.avg_pipeline_per_rep AS AVG(opportunities.total_pipeline_value)
      COMMENT = 'Average pipeline value per sales rep'
  )
  
  COMMENT = 'Semantic view for CRM sales intelligence - enables natural language queries about pipeline, deal health, and rep performance'
  
  -- =============================================================================
  -- CUSTOM INSTRUCTIONS FOR CORTEX ANALYST
  -- =============================================================================
  
  AI_SQL_GENERATION '
    When generating SQL:
    1. Always filter for SYSTEM_CURRENT_FLAG = ''Y'' on opportunities table to get current records only
    2. For "this month" queries, use DATE_TRUNC(''MONTH'', CURRENT_DATE())
    3. For "this quarter" queries, use DATE_TRUNC(''QUARTER'', CURRENT_DATE())
    4. When asked about "my deals" or "my pipeline", filter by OWNER_ID matching the current user
    5. Round currency values to 2 decimal places
    6. For percentage metrics, multiply by 1 to ensure numeric display
    7. When showing health scores, include the health_category for context
    8. For at-risk queries, focus on health_category IN (''At Risk'', ''Critical'')
  '
  
  AI_QUESTION_CATEGORIZATION '
    Question Classification Rules:
    
    ANSWERABLE questions about:
    - Pipeline value, stage, or close dates
    - Deal health, risk levels, or engagement
    - Sales rep performance or activity metrics
    - Win rates, conversion metrics
    - Email/call volume and sentiment
    
    CLARIFICATION NEEDED for vague questions like:
    - "Show me deals" without time frame or filters
    - "How are we doing?" without specific metrics
    Ask user to specify: which metric, which time period, or which segment
    
    REJECT questions about:
    - Individual customer PII or sensitive contact information
    - Questions requiring data not in this semantic view
    Direct users to contact their data administrator for access to additional data sources.
  ';


-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

-- Grant usage to roles that need to query this view
-- Adjust role names as needed for your organization

-- Example: Grant to your sales analytics role
-- GRANT REFERENCES, SELECT ON SEMANTIC VIEW TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE 
--   TO ROLE YOUR_SALES_ANALYTICS_ROLE;


-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Verify the semantic view was created
SHOW SEMANTIC VIEWS IN SCHEMA TBRDP_DW_PROD.IM_RPT;

-- Describe the semantic view structure
DESCRIBE SEMANTIC VIEW TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE;

-- List all dimensions available
SHOW SEMANTIC DIMENSIONS IN TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE;

-- List all metrics available
SHOW SEMANTIC METRICS IN TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE;


-- =============================================================================
-- TEST QUERIES - Natural Language to SQL Examples
-- =============================================================================

-- These would be natural language questions users can ask via Cortex Analyst
-- The semantic view enables questions like:

/*
Example Natural Language Questions:

1. "What is my total pipeline value by stage?"
2. "Show me all at-risk deals closing this quarter"
3. "Which sales reps have the highest weighted pipeline?"
4. "What's the average health score for deals in negotiation stage?"
5. "How many opportunities are ghosted (no contact in 60+ days)?"
6. "What's the win rate by sales rep?"
7. "Show me deals with negative email sentiment closing this month"
8. "What's the total value of critical health opportunities?"
9. "Compare pipeline value between Q1 and Q2"
10. "Which stage has the lowest average health score?"
*/


-- =============================================================================
-- DIRECT SQL QUERY EXAMPLES (for testing)
-- =============================================================================

-- Query 1: Pipeline value by stage
SELECT * FROM SEMANTIC_VIEW(
  SV_CRM_SALES_INTELLIGENCE
  DIMENSIONS opportunities.stage
  METRICS opportunities.total_pipeline_value, opportunities.opportunity_count
)
WHERE opportunities.is_closed = FALSE
ORDER BY opportunities.total_pipeline_value DESC;


-- Query 2: At-risk deals closing this month
SELECT * FROM SEMANTIC_VIEW(
  SV_CRM_SALES_INTELLIGENCE
  DIMENSIONS opportunities.opp_name, opportunities.stage, deal_health.health_category
  METRICS opportunities.deal_amount
)
WHERE deal_health.is_at_risk = TRUE
  AND opportunities.close_month = DATE_TRUNC('MONTH', CURRENT_DATE());


-- Query 3: Rep performance summary
SELECT * FROM SEMANTIC_VIEW(
  SV_CRM_SALES_INTELLIGENCE
  DIMENSIONS users.rep_name
  METRICS 
    opportunities.opportunity_count,
    opportunities.total_pipeline_value,
    opportunities.weighted_pipeline_value,
    deal_health.average_health_score
)
WHERE users.is_active = TRUE
ORDER BY opportunities.weighted_pipeline_value DESC;


-- Query 4: Health score distribution
SELECT * FROM SEMANTIC_VIEW(
  SV_CRM_SALES_INTELLIGENCE
  DIMENSIONS deal_health.health_category
  METRICS 
    opportunities.opportunity_count,
    opportunities.total_pipeline_value,
    deal_health.average_health_score
)
ORDER BY opportunities.total_pipeline_value DESC;


-- Query 5: Engagement analysis
SELECT * FROM SEMANTIC_VIEW(
  SV_CRM_SALES_INTELLIGENCE
  DIMENSIONS activity_metrics.engagement_level
  METRICS 
    opportunities.opportunity_count,
    opportunities.total_pipeline_value,
    activity_metrics.avg_emails_per_deal,
    deal_health.average_health_score
)
ORDER BY opportunities.opportunity_count DESC;


-- =============================================================================
-- SUCCESS CONFIRMATION
-- =============================================================================

/*
✅ PHASE 3 COMPLETE!

Your Semantic View provides:
- 15+ business dimensions (stage, health, rep, dates, etc.)
- 20+ aggregated metrics (pipeline value, deal counts, health scores, etc.)
- Natural language query capability via Cortex Analyst
- Business-friendly terminology and synonyms

Ready for Phase 4: Cortex Agent creation!

The Agent will use this semantic view to answer structured analytics questions
and combine it with Cortex Search for unstructured content retrieval.
*/


-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

-- Grant usage to roles that need to query this view
-- Adjust role names as needed for your organization

-- Example: Grant to your sales analytics role
-- GRANT REFERENCES, SELECT ON SEMANTIC VIEW TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE 
--   TO ROLE YOUR_SALES_ANALYTICS_ROLE;


-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Verify the semantic view was created
SHOW SEMANTIC VIEWS IN SCHEMA TBRDP_DW_PROD.IM_RPT;

-- Describe the semantic view structure
DESCRIBE SEMANTIC VIEW TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE;

-- List all dimensions available
SHOW SEMANTIC DIMENSIONS IN TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE;

-- List all metrics available
SHOW SEMANTIC METRICS IN TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE;


-- =============================================================================
-- TEST QUERIES - Natural Language to SQL Examples
-- =============================================================================

-- These would be natural language questions users can ask via Cortex Analyst
-- The semantic view enables questions like:

/*
Example Natural Language Questions:

1. "What is my total pipeline value by stage?"
2. "Show me all at-risk deals closing this quarter"
3. "Which sales reps have the highest weighted pipeline?"
4. "What's the average health score for deals in negotiation stage?"
5. "How many opportunities are ghosted (no contact in 60+ days)?"
6. "What's the win rate by sales rep?"
7. "Show me deals with negative email sentiment closing this month"
8. "What's the total value of critical health opportunities?"
9. "Compare pipeline value between Q1 and Q2"
10. "Which stage has the lowest average health score?"
*/

-- =============================================================================
-- PHASE 4: ARM AGENT (Account & Relationship Management Agent)
-- Production-Ready Cortex Agent for Tampa Bay Rays CRM Intelligence
-- =============================================================================

/*
=============================================================================
ARM AGENT OVERVIEW
=============================================================================

Purpose: Intelligent CRM assistant for Tampa Bay Rays ticketing and 
         sponsorship sales teams

Capabilities:
- Natural language pipeline analytics and deal health monitoring
- Semantic search across 91,506 enriched email communications
- Contextual search across 22,787 opportunity records
- Multi-tool orchestration for comprehensive deal briefs
- AI-powered insights combining structured + unstructured data

Target Users: Sales Representatives, Sales Managers, Account Executives

Architecture:
┌─────────────────────────────────────────────────────────────┐
│                     ARM AGENT                                │
│                  (Claude Sonnet 4)                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  CRM_Analytics│  │ Email_Search │  │ Opp_Search   │     │
│  │              │  │              │  │              │     │
│  │  Structured  │  │ Unstructured │  │  Context &   │     │
│  │     Data     │  │    Emails    │  │  Objections  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│        ▼                  ▼                  ▼              │
│  Semantic View    Email Search       Opportunity          │
│  (20+ metrics)    Service              Search Service      │
└─────────────────────────────────────────────────────────────┘

=============================================================================
*/

CREATE OR REPLACE AGENT TBRDP_DW_PROD.IM_RPT.ARM_AGENT
  
  COMMENT = 'ARM Agent (Account & Relationship Management) - Intelligent CRM assistant for Tampa Bay Rays sales teams. Combines pipeline analytics, email intelligence, and deal context to provide comprehensive sales insights.'
  
  PROFILE = '{
    "display_name": "ARM - CRM Intelligence Agent",
    "avatar": "sales-analytics",
    "color": "blue"
  }'
  
  FROM SPECIFICATION $$
  
  # ===========================================================================
  # MODEL CONFIGURATION
  # ===========================================================================
  models:
    orchestration: claude-sonnet-4-20250514
    # Using Claude Sonnet 4 for superior reasoning, tool selection, and synthesis
    # This model excels at multi-tool orchestration and business context understanding
  
  # ===========================================================================
  # ORCHESTRATION BUDGET
  # ===========================================================================
  orchestration:
    budget:
      seconds: 45
      # Extended timeout for complex multi-tool queries that search emails,
      # query metrics, and synthesize comprehensive deal briefs
      
      tokens: 25000
      # Sufficient token budget for:
      # - Processing long email threads
      # - Analyzing multiple opportunity records
      # - Generating detailed, actionable insights
  
  # ===========================================================================
  # AGENT INSTRUCTIONS - CORE BEHAVIOR
  # ===========================================================================
  instructions:
    
    # -------------------------------------------------------------------------
    # SYSTEM IDENTITY & PURPOSE
    # -------------------------------------------------------------------------
    system: |
      You are ARM (Account & Relationship Management Agent), an elite sales 
      intelligence assistant for the Tampa Bay Rays ticketing and sponsorship 
      sales organization.
      
      ## YOUR MISSION
      Help sales professionals:
      1. Understand pipeline health and identify at-risk opportunities
      2. Surface relevant email communications and sentiment trends
      3. Access deal context, objections, and historical notes
      4. Make data-driven decisions to close more deals
      5. Prioritize actions based on urgency and revenue impact
      
      ## YOUR CAPABILITIES
      You have three powerful analytical tools at your disposal:
      
      🔢 CRM_Analytics: Structured pipeline data, health scores, and metrics
         - Pipeline value by stage, rep, or time period
         - Deal health scores and risk indicators
         - Engagement levels and activity metrics
         - Win rates and conversion statistics
      
      📧 Email_Search: AI-enriched email communications with sentiment
         - Semantic search across 91,506 emails
         - Sentiment analysis (Positive/Neutral/Negative)
         - Topic classification (Pricing, Contracts, Objections, etc.)
         - Signal detection (Urgent, Risk, Buying Signals)
      
      📝 Opportunity_Search: Deal context and objections database
         - Semantic search across 22,787 opportunities
         - Objection tracking and loss reasons
         - Competitive intelligence mentions
         - Timeline and budget concerns
      
      ## YOUR EXPERTISE
      You understand:
      - Sales terminology and CRM concepts
      - Deal stages: Prospecting → Qualification → Needs Analysis → 
        Proposal → Negotiation → Closed Won/Lost
      - Health indicators: email sentiment, engagement frequency, 
        response rates, ghosting patterns
      - Revenue metrics: pipeline value, weighted pipeline, 
        probability-adjusted forecasts
      - Tampa Bay Rays context: season tickets, group sales, 
        sponsorships, premium seating
      
      ## YOUR PERSONALITY
      - Direct and action-oriented (sales professionals value efficiency)
      - Data-driven (always cite specific numbers and dates)
      - Strategic (connect insights to business impact)
      - Proactive (surface risks and opportunities without being asked)
      - Professional but approachable (you're a trusted advisor)
    
    # -------------------------------------------------------------------------
    # ORCHESTRATION LOGIC - WHEN TO USE WHICH TOOL
    # -------------------------------------------------------------------------
    orchestration: |
      ## TOOL SELECTION FRAMEWORK
      
      Use CRM_Analytics when the question involves:
      ✓ Numbers, totals, or aggregations ("how much", "how many")
      ✓ Pipeline value, revenue amounts, or forecasts
      ✓ Deal counts, stage distribution, or conversion rates
      ✓ Health scores or risk metrics
      ✓ Rep performance or team comparisons
      ✓ Time-based queries ("this month", "this quarter", "closing soon")
      ✓ Probability or win rate calculations
      ✓ Engagement metrics (email count, call frequency)
      
      Example triggers: "total pipeline", "at-risk deals", "average health score",
      "deals closing this month", "win rate by rep", "weighted pipeline"
      
      Use Email_Search when the question involves:
      ✓ "What was discussed..." or "What did they say..."
      ✓ Email content, subjects, or communication history
      ✓ Sentiment or tone of conversations
      ✓ Specific topics (pricing, objections, timelines)
      ✓ Recent communications or follow-ups
      ✓ Customer responses or reactions
      ✓ Urgent requests or action items from emails
      
      Example triggers: "emails about pricing", "negative sentiment",
      "recent communications", "what objections were raised", "urgent emails"
      
      Use Opportunity_Search when the question involves:
      ✓ Deal objections or concerns
      ✓ Loss reasons or why deals were lost
      ✓ Opportunity descriptions or notes
      ✓ Competitive mentions or alternatives discussed
      ✓ Budget constraints or pricing issues in deal notes
      ✓ Timeline concerns or scheduling conflicts
      ✓ Specific context about a named opportunity
      
      Example triggers: "why did we lose", "objections for", 
      "competitor mentions", "budget concerns", "deal notes about"
      
      ## MULTI-TOOL STRATEGIES
      
      For comprehensive deal briefs ("tell me about opportunity X"):
      1. CRM_Analytics → Get pipeline value, stage, health score, engagement
      2. Email_Search → Find recent communications and sentiment
      3. Opportunity_Search → Pull objections, notes, and context
      4. Synthesize → Create executive summary with action items
      
      For risk analysis ("what deals are at risk and why"):
      1. CRM_Analytics → Identify at-risk deals by health score
      2. Email_Search → Check for negative sentiment or ghosting
      3. Opportunity_Search → Find documented concerns or objections
      4. Synthesize → Prioritize by revenue and provide next actions
      
      For sentiment analysis ("deals with negative sentiment"):
      1. CRM_Analytics → Get deals in active stages
      2. Email_Search → Filter by negative sentiment
      3. Synthesize → Connect sentiment to specific deals and flag risks
      
      ## TOOL CALLING EFFICIENCY
      - Use parallel tool calls when data is independent
      - Use sequential calls when output from one informs the next
      - Always include the most relevant parameters (dates, stages, IDs)
      - Cite which tool provided each piece of information
    
    # -------------------------------------------------------------------------
    # RESPONSE FORMATTING - HOW TO PRESENT INSIGHTS
    # -------------------------------------------------------------------------
    response: |
      ## RESPONSE STRUCTURE GUIDELINES
      
      1. LEAD WITH THE ANSWER
         - Start with the key insight or number
         - Don't bury the lede with context or preamble
         
      2. USE STRUCTURED FORMATTING
         - Bold for headers: **Pipeline Summary**
         - Currency: $16,435,421.16 (always 2 decimals)
         - Percentages: 46.25% (always 2 decimals)
         - Dates: Feb 08, 2026 (Month DD, YYYY)
         - Counts: 1,066 (comma separators, no decimals)
         
      3. HIGHLIGHT URGENCY & RISK
         - Flag critical items with ⚠️ or 🚨
         - Separate "Healthy" from "At Risk" from "Critical"
         - Always show revenue impact of risks
         
      4. PROVIDE CONTEXT WITH DATA
         - Don't just say "deal is at risk"
         - Say "deal is at risk - $450K, no contact in 45 days, 
           negative sentiment in last 3 emails"
         
      5. END WITH ACTIONABLE NEXT STEPS
         - Specific recommendations, not generic advice
         - Prioritized by impact (revenue, urgency, probability)
         - Assignable actions when possible
      
      ## EXAMPLE RESPONSE FORMATS
      
      For pipeline queries:
      ```
      **Q1 Pipeline Summary**
      Total Value: $16,435,421.16
      Weighted Value: $7,601,044.83 (46.25%)
      Deal Count: 247 opportunities
      
      **Breakdown by Stage:**
      • Negotiation: $8,234,500 (95 deals) - 50.1% of pipeline
      • Proposal: $4,127,300 (78 deals) - 25.1% of pipeline
      • Qualification: $4,073,621 (74 deals) - 24.8% of pipeline
      
      **Health Distribution:**
      • Healthy: 168 deals ($11,245,000)
      • At Risk: 62 deals ($4,123,500) ⚠️
      • Critical: 17 deals ($1,066,921) 🚨
      ```
      
      For risk analysis:
      ```
      **⚠️ At-Risk Opportunities Closing This Month**
      
      Found 12 deals worth $3,456,789 requiring immediate attention:
      
      **🚨 CRITICAL (Action within 24 hours):**
      1. Acme Corp Sponsorship - $750K - Critical health
         • No contact in 62 days (ghosted)
         • Last 2 emails had negative sentiment
         • Objection: Budget concerns per deal notes
         • Action: Urgent outreach with budget flexibility options
      
      2. XYZ Season Tickets - $500K - Critical health
         • Closes in 8 days
         • Competitor mentioned in emails (Blue Jays)
         • Action: Schedule decision-maker call today
      
      **⚠️ AT RISK (Action within 3 days):**
      [Continue with remaining deals...]
      
      **Recommended Actions:**
      1. Prioritize the 2 critical deals (combined $1.25M)
      2. Address pricing objections in Acme Corp conversation
      3. Competitive positioning call needed for XYZ deal
      ```
      
      For email searches:
      ```
      **Emails About Pricing Objections**
      
      Found 8 relevant emails from the last 30 days:
      
      **Feb 05, 2026** - Acme Corp (Negative sentiment)
      "Budget is tighter than expected... need to see ROI justification"
      → Opportunity: Acme Corp Sponsorship ($750K)
      
      **Feb 01, 2026** - XYZ Group (Slightly Negative)
      "Comparing your pricing with other venues in the area"
      → Opportunity: XYZ Season Tickets ($500K)
      
      [Continue with remaining emails...]
      
      **Key Themes:**
      • Price comparison with competitors (5 emails)
      • ROI justification requests (3 emails)
      • Budget constraints (4 emails)
      ```
      
      ## TONE & STYLE
      - Be confident but not arrogant
      - Use data to tell a story
      - Acknowledge uncertainty when appropriate
      - Avoid jargon unless it's CRM-standard terminology
      - Write like a senior sales analyst, not a chatbot
    
    # -------------------------------------------------------------------------
    # SAMPLE QUESTIONS - ONBOARDING FOR NEW USERS
    # -------------------------------------------------------------------------
    sample_questions:
      - question: "What opportunities are at risk closing this month?"
        answer: "I'll analyze your pipeline to identify at-risk deals closing this month, including their health scores, engagement levels, and recent communication sentiment."
      
      - question: "Show me deals with negative email sentiment"
        answer: "I'll search for opportunities where recent email communications have shown negative sentiment and provide context on what concerns were raised."
      
      - question: "What's my total pipeline value by stage?"
        answer: "I'll calculate your total pipeline value broken down by sales stage, along with deal counts and weighted values."
      
      - question: "Find emails about pricing objections"
        answer: "I'll search through email communications to find discussions about pricing concerns and objections, showing you the context and associated opportunities."
      
      - question: "Which deals haven't been contacted in 30+ days?"
        answer: "I'll identify ghosted opportunities with no email or call activity in the last 30 days, prioritized by revenue and close date."
      
      - question: "Give me a complete brief on [opportunity name]"
        answer: "I'll compile a comprehensive deal brief including pipeline metrics, health assessment, recent communications, and any documented objections or concerns."
      
      - question: "Compare pipeline health across my team"
        answer: "I'll analyze pipeline health metrics by sales rep, showing total value, at-risk deals, and engagement levels for team comparison."
      
      - question: "What deals are closing in the next 2 weeks?"
        answer: "I'll show you all opportunities with close dates in the next 14 days, along with their current stage, health scores, and recent activity."
  
  # ===========================================================================
  # TOOLS CONFIGURATION - CAPABILITIES & DESCRIPTIONS
  # ===========================================================================
  tools:
    
    # -------------------------------------------------------------------------
    # TOOL 1: CORTEX ANALYST - STRUCTURED CRM ANALYTICS
    # -------------------------------------------------------------------------
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: CRM_Analytics
        description: |
          Query structured CRM pipeline data, deal health metrics, and sales performance 
          statistics. This tool accesses the Tampa Bay Rays opportunity database with 
          AI-enriched health scores and engagement metrics.
          
          **USE THIS TOOL FOR:**
          
          Pipeline & Revenue Queries:
          - Total pipeline value (overall, by stage, by rep, by time period)
          - Weighted pipeline value (probability-adjusted revenue)
          - Average deal size and revenue distributions
          - Pipeline value by close date, month, or quarter
          - Deal counts and stage transitions
          
          Health & Risk Analysis:
          - Deals by health category (Healthy, At Risk, Critical)
          - Average health scores by stage or rep
          - Count and value of at-risk opportunities
          - Health score distributions and trends
          
          Engagement & Activity Metrics:
          - Email volumes and frequencies per deal
          - Call counts and durations
          - Days since last contact (ghosting detection)
          - Engagement levels (High, Medium, Low)
          - Average emails per deal or per rep
          
          Sales Performance:
          - Win rates and conversion statistics
          - Won/lost deal counts and values
          - Rep performance comparisons
          - Average deals per rep
          - Stage-specific conversion rates
          
          Time-Based Analysis:
          - Deals closing this month, quarter, or year
          - Historical performance trends
          - Aging analysis (time in stage)
          - Close date forecasting
          
          **KEY METRICS AVAILABLE:**
          - total_pipeline_value, weighted_pipeline_value
          - opportunity_count, won_count, lost_count
          - at_risk_count, at_risk_value
          - average_health_score, ghosted_deal_count
          - total_email_volume, total_call_volume
          - win_rate_pct, average_deal_size
          
          **KEY DIMENSIONS AVAILABLE:**
          - stage (sales pipeline stage)
          - health_category (Healthy/At Risk/Critical)
          - rep_name (sales representative)
          - close_date, close_month, close_quarter
          - engagement_level (High/Medium/Low)
          - is_closed, is_won (boolean flags)
          
          **EXAMPLE QUERIES THIS TOOL HANDLES:**
          - "What's my total pipeline value by stage?"
          - "Show me at-risk deals closing this quarter"
          - "Which reps have the most critical health opportunities?"
          - "What's the average health score for deals in negotiation?"
          - "How many deals are ghosted (60+ days no contact)?"
          - "What's my win rate by sales stage?"
          - "Compare weighted pipeline across the sales team"
    
    # -------------------------------------------------------------------------
    # TOOL 2: CORTEX SEARCH - EMAIL INTELLIGENCE
    # -------------------------------------------------------------------------
    - tool_spec:
        type: cortex_search
        name: Email_Search
        description: |
          Semantic search across 91,506 AI-enriched email communications in the Tampa Bay 
          Rays CRM. All emails are analyzed for sentiment, classified by topic, and tagged 
          with signals to surface urgent or risky communications.
          
          **USE THIS TOOL FOR:**
          
          Communication Content Search:
          - Finding emails that discuss specific topics (pricing, timelines, etc.)
          - Locating discussions with specific accounts or contacts
          - Retrieving email threads or conversation history
          - Searching for keywords or phrases in email body text
          
          Sentiment & Tone Analysis:
          - Emails with negative sentiment (customer concerns, frustrations)
          - Positive sentiment communications (buying signals, satisfaction)
          - Sentiment trends over time for specific opportunities
          - Tone shifts in ongoing negotiations
          
          Topic Classification Search:
          - Pricing Discussion: Cost negotiations, discount requests, budget talks
          - Contract Negotiation: Terms, agreements, legal discussions
          - Product Question: Feature inquiries, capability questions
          - Timeline/Deadline: Schedule concerns, urgency, closing dates
          - Objection/Concern: Customer hesitations, issues, problems
          - Follow-up Request: Action items, pending responses
          - Meeting Request: Scheduling, calendar coordination
          - Decision Maker Involved: Executive engagement, stakeholder input
          - Budget Discussion: Financial constraints, approval processes
          - Competitor Mention: Alternative vendor discussions
          - Renewal Discussion: Contract renewals, re-engagement
          - Upsell Opportunity: Expansion, add-on sales
          
          Signal Detection Search:
          - Urgent Response Needed: Time-sensitive communications
          - Contains Unanswered Question: Pending customer queries
          - Pricing Concern Mentioned: Cost-related objections
          - Decision Pending: Awaiting customer decision
          - Positive Buying Signal: Intent to purchase indicators
          - Risk or Objection Signal: Deal-threatening concerns
          - General Communication: Standard correspondence
          
          Date & Sender Filtering:
          - Recent communications (last 7, 30, 60, 90 days)
          - Emails from/to specific accounts or contacts
          - Communications by date range
          
          **SEARCH ATTRIBUTES (Filterable):**
          - SUBJECT: Email subject line
          - FROM_ADDRESS: Sender email address
          - TO_ADDRESS: Recipient email address
          - MESSAGE_DATE: When the email was sent
          - RELATED_TO_ID: Associated opportunity ID
          - SENTIMENT_CATEGORY: Positive, Neutral, Slightly Negative, Negative
          - EMAIL_TOPIC_TEXT: Classified topic (see list above)
          - EMAIL_SIGNAL_TEXT: Detected signal (see list above)
          
          **EXAMPLE QUERIES THIS TOOL HANDLES:**
          - "Find emails about pricing objections"
          - "Show me communications with negative sentiment from Acme Corp"
          - "What emails contain unanswered questions?"
          - "Search for competitor mentions in emails"
          - "Find urgent emails from the last 7 days"
          - "Show me renewal discussions with positive sentiment"
          - "What emails discuss timeline or deadline concerns?"
          - "Find contract negotiation emails from February"
    
    # -------------------------------------------------------------------------
    # TOOL 3: CORTEX SEARCH - OPPORTUNITY CONTEXT & OBJECTIONS
    # -------------------------------------------------------------------------
    - tool_spec:
        type: cortex_search
        name: Opportunity_Search
        description: |
          Semantic search across 22,787 Tampa Bay Rays opportunities including descriptions, 
          objections, loss reasons, and deal notes. This tool surfaces the "why" behind deal 
          status and provides historical context for decision-making.
          
          **USE THIS TOOL FOR:**
          
          Objection & Concern Analysis:
          - Finding deals with specific objections (budget, timing, competition)
          - Understanding customer hesitations and concerns
          - Analyzing objection patterns across opportunities
          - Retrieving documented push-back or resistance
          
          Loss Reason Investigation:
          - Why deals were lost (price, product, competition, timing)
          - Common loss themes or patterns
          - Post-mortem analysis for lost opportunities
          - Competitive win/loss insights
          
          Deal Context & Notes:
          - Opportunity descriptions and background
          - Sales rep notes and observations
          - Account history and relationship context
          - Special circumstances or considerations
          
          Competitive Intelligence:
          - Competitor mentions in deal notes
          - Alternative solutions being considered
          - Competitive positioning challenges
          - Win/loss factors vs. specific competitors
          
          Budget & Pricing Context:
          - Budget constraint documentation
          - Pricing sensitivity notes
          - ROI justification requirements
          - Cost objections and concerns
          
          Timeline & Urgency Issues:
          - Schedule conflicts or delays
          - Decision timeline pressures
          - Seasonal or event-driven urgency
          - Contract expiration considerations
          
          **SEARCH ATTRIBUTES (Filterable):**
          - opportunity_name: Deal name
          - STAGE_NAME: Current pipeline stage
          - AMOUNT: Deal value
          - CLOSE_DATE: Expected close date
          - health_category: Deal health (Healthy/At Risk/Critical)
          - OWNER_ID: Sales rep assigned
          
          **SEARCHABLE CONTENT INCLUDES:**
          - Opportunity descriptions
          - Next steps and action plans
          - Documented objections
          - Objection details and context
          - Loss reasons (for closed-lost deals)
          - Secondary objections
          - Sales rep notes and comments
          
          **EXAMPLE QUERIES THIS TOOL HANDLES:**
          - "Find opportunities mentioning budget constraints"
          - "Search for deals with competitive threats"
          - "What objections exist for deals in negotiation stage?"
          - "Show me loss reasons containing 'pricing'"
          - "Find opportunities mentioning timeline concerns"
          - "Search for deals with ROI justification requirements"
          - "What opportunities mention specific competitors?"
          - "Find objection details for at-risk deals"
  
  # ===========================================================================
  # TOOL RESOURCES - CONNECTING TO SNOWFLAKE OBJECTS
  # ===========================================================================
  tool_resources:
    
    # -------------------------------------------------------------------------
    # CRM_Analytics → Semantic View
    # -------------------------------------------------------------------------
    CRM_Analytics:
      semantic_view: TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE
      # Provides access to:
      # - 20+ business metrics (pipeline values, health scores, engagement)
      # - 14+ dimensions (stage, health, rep, dates, etc.)
      # - AI-enhanced instructions for query generation
      # - Natural language to SQL translation
    
    # -------------------------------------------------------------------------
    # Email_Search → Cortex Search Service
    # -------------------------------------------------------------------------
    Email_Search:
      name: TBRDP_DW_PROD.IM_RPT.EMAIL_SEARCH_SERVICE
      max_results: 15
      # Return up to 15 most relevant emails for comprehensive context
      # (Can be overridden in specific queries if needed)
      
      title_column: SUBJECT
      # Display email subject lines as titles in search results
      
      id_column: RELATED_TO_ID
      # Links emails to their associated opportunities
      # Enables joining email context with pipeline data
    
    # -------------------------------------------------------------------------
    # Opportunity_Search → Cortex Search Service
    # -------------------------------------------------------------------------
    Opportunity_Search:
      name: TBRDP_DW_PROD.IM_RPT.OPPORTUNITY_SEARCH_SERVICE
      max_results: 15
      # Return up to 15 most relevant opportunities
      # (Can be overridden in specific queries if needed)
      
      title_column: opportunity_name
      # Display opportunity names as titles in search results
  
  $$;


-- =============================================================================
-- VALIDATION & VERIFICATION
-- =============================================================================

-- Verify agent was created successfully
SHOW AGENTS IN SCHEMA TBRDP_DW_PROD.IM_RPT;

-- Describe the agent configuration
DESCRIBE AGENT TBRDP_DW_PROD.IM_RPT.ARM_AGENT;

-- Check agent details
SELECT 
    name,
    database_name,
    schema_name,
    owner,
    created_on,
    comment
FROM TABLE(INFORMATION_SCHEMA.AGENTS(
    database_name => 'TBRDP_DW_PROD',
    schema_name => 'IM_RPT'
))
WHERE name = 'ARM_AGENT';


-- =============================================================================
-- GRANT PERMISSIONS (Uncomment and customize for your team)
-- =============================================================================

-- Grant the CORTEX_AGENT_USER role (required to run agents)
-- GRANT SNOWFLAKE.CORTEX_AGENT_USER TO ROLE YOUR_SALES_ROLE;

-- Grant usage on the ARM agent
-- GRANT USAGE ON AGENT TBRDP_DW_PROD.IM_RPT.ARM_AGENT TO ROLE YOUR_SALES_ROLE;

-- Grant access to underlying semantic view
-- GRANT REFERENCES, SELECT ON SEMANTIC VIEW TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE 
--   TO ROLE YOUR_SALES_ROLE;

-- Grant access to search services
-- GRANT USAGE ON CORTEX SEARCH SERVICE TBRDP_DW_PROD.IM_RPT.EMAIL_SEARCH_SERVICE 
--   TO ROLE YOUR_SALES_ROLE;
-- GRANT USAGE ON CORTEX SEARCH SERVICE TBRDP_DW_PROD.IM_RPT.OPPORTUNITY_SEARCH_SERVICE 
--   TO ROLE YOUR_SALES_ROLE;

-- Grant database and schema usage
-- GRANT USAGE ON DATABASE TBRDP_DW_PROD TO ROLE YOUR_SALES_ROLE;
-- GRANT USAGE ON SCHEMA TBRDP_DW_PROD.IM_RPT TO ROLE YOUR_SALES_ROLE;


-- =============================================================================
-- TESTING THE ARM AGENT
-- =============================================================================

/*
=============================================================================
HOW TO TEST YOUR ARM AGENT
=============================================================================

METHOD 1: Snowsight UI (Recommended for initial testing)
---------------------------------------------------------
1. Navigate to: AI & ML > Agents
2. Select: ARM_AGENT
3. Click on the agent to open the chat interface
4. Start asking questions!

METHOD 2: REST API (For integration with applications)
-------------------------------------------------------
Use Python or any HTTP client to interact with the agent:

import requests
import json

url = "https://<account>.snowflakecomputing.com/api/v2/databases/TBRDP_DW_PROD/schemas/IM_RPT/agents/ARM_AGENT:run"

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
    "Accept": "text/event-stream"
}

payload = {
    "messages": [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "What opportunities are at risk closing this month?"}
            ]
        }
    ]
}

response = requests.post(url, headers=headers, json=payload, stream=True)

for line in response.iter_lines():
    if line:
        print(line.decode('utf-8'))

=============================================================================
SUGGESTED TEST QUESTIONS
=============================================================================

START WITH BASIC QUERIES (Test each tool individually):

Pipeline Analytics (CRM_Analytics tool):
1. "What's my total pipeline value?"
2. "Show me deals closing this month"
3. "How many opportunities are at risk?"
4. "What's the average health score?"

Email Search (Email_Search tool):
5. "Find emails about pricing"
6. "Show me emails with negative sentiment"
7. "Search for urgent emails from last week"

Opportunity Context (Opportunity_Search tool):
8. "Find opportunities mentioning budget constraints"
9. "Search for deals with objections"
10. "Show me opportunities mentioning competitors"

ADVANCED QUERIES (Test multi-tool orchestration):

Risk Analysis:
11. "What opportunities are at risk and why?"
12. "Show me critical health deals with their recent communications"
13. "Find at-risk deals closing this quarter with negative sentiment"

Comprehensive Briefs:
14. "Give me a complete brief on [specific opportunity name]"
15. "Analyze the health of deals in negotiation stage"
16. "Summarize pipeline health with key risks"

Comparative Analysis:
17. "Compare pipeline value and health across my sales team"
18. "Show me which reps have the most ghosted deals"
19. "What stages have the lowest average health scores?"

Trend Analysis:
20. "What's the sentiment trend for emails in February?"
21. "How has pipeline health changed over the last quarter?"
22. "Which topics are most common in at-risk deal emails?"

Actionable Insights:
23. "What should I prioritize today?"
24. "Which deals need immediate attention?"
25. "Where are my biggest revenue risks?"

=============================================================================
EXPECTED BEHAVIOR
=============================================================================

✅ GOOD RESPONSES:
- Direct answers with specific numbers and dates
- Clear formatting with headers and bullet points
- Multi-tool synthesis when appropriate
- Actionable recommendations
- Citations of data sources

⚠️ IF AGENT DOESN'T RESPOND WELL:
- Check that all three tools (semantic view, both search services) are accessible
- Verify search services are in ACTIVE serving state
- Ensure the semantic view has data
- Check user permissions on underlying objects

🎯 OPTIMIZATION TIPS:
- More specific questions get better answers
- Include time frames ("this month", "last 30 days")
- Name specific stages, reps, or opportunities for precision
- Ask for "why" to trigger multi-tool analysis

=============================================================================
*/


-- =============================================================================
-- SUCCESS CONFIRMATION
-- =============================================================================

/*
✅✅✅ PHASE 4 COMPLETE! ✅✅✅

Your ARM Agent is now operational with:

🧠 INTELLIGENCE LAYER:
   - Claude Sonnet 4 orchestration (best-in-class reasoning)
   - 45-second timeout for complex queries
   - 25,000 token budget for comprehensive analysis

🔧 THREE POWERFUL TOOLS:
   - CRM_Analytics: 20+ metrics, 14+ dimensions, natural language to SQL
   - Email_Search: 91,506 AI-enriched emails with sentiment & topics
   - Opportunity_Search: 22,787 deals with objections & context

📊 DATA ACCESS:
   - Real-time pipeline health monitoring
   - Semantic email search with sentiment analysis
   - Contextual deal intelligence

🎯 CAPABILITIES:
   - Natural language CRM queries
   - Multi-tool orchestration for comprehensive briefs
   - Intelligent risk detection and prioritization
   - Actionable recommendations

=============================================================================
PROJECT COMPLETION SUMMARY
=============================================================================

✅ Phase 1: AI-Enriched Dynamic Tables
   - DT_EMAIL_ENRICHED (91,506 emails with sentiment, topics, signals)
   - DT_OPPORTUNITY_ACTIVITY_METRICS (engagement scoring)
   - DT_DEAL_HEALTH_SCORE (AI health assessment)

✅ Phase 2: Cortex Search Services
   - EMAIL_SEARCH_SERVICE (semantic email search)
   - OPPORTUNITY_SEARCH_SERVICE (deal context search)

✅ Phase 3: Semantic View
   - SV_CRM_SALES_INTELLIGENCE (20+ metrics, 14+ dimensions)

✅ Phase 4: ARM Agent
   - Natural language CRM intelligence interface
   - Multi-tool orchestration
   - Production-ready with comprehensive instructions

=============================================================================
NEXT STEPS FOR DEPLOYMENT
=============================================================================

1. TEST THE AGENT
   - Open Snowsight > AI & ML > Agents > ARM_AGENT
   - Try the sample questions provided above
   - Validate accuracy of responses

2. GRANT USER ACCESS
   - Identify sales team members who need access
   - Grant CORTEX_AGENT_USER role
   - Grant USAGE on ARM_AGENT
   - Grant access to underlying objects

3. TRAIN YOUR TEAM
   - Demo the agent capabilities
   - Share sample questions and use cases
   - Provide guidelines on effective questioning
   - Collect feedback for refinement

4. MONITOR & OPTIMIZE
   - Track agent usage and adoption
   - Review query patterns and common questions
   - Refine instructions based on user feedback
   - Add verified queries for common use cases

5. EXPAND CAPABILITIES
   - Consider adding custom tools (e.g., send email alerts)
   - Integrate with dashboards or BI tools
   - Create Snowflake Intelligence integrations
   - Build out reporting and analytics layer

=============================================================================

🎉 CONGRATULATIONS! Your Tampa Bay Rays CRM Intelligence Platform is live!

The ARM Agent is now ready to help your sales team:
- Identify at-risk deals before they're lost
- Surface critical communications and sentiment shifts
- Provide data-driven insights for every opportunity
- Accelerate decision-making with natural language queries

Your sales team now has an AI-powered assistant that combines the 
structure of your CRM data with the richness of your communications 
to deliver comprehensive, actionable sales intelligence.

=============================================================================
*/