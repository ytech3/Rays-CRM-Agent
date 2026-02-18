-- =============================================================================
-- PHASE 5B: CUSTOMER 360 - BUILDING THE BRIDGE
-- Tampa Bay Rays CRM Intelligence Platform
-- =============================================================================
--
-- LINKAGE PATH DISCOVERED:
--   Opportunity.ACCOUNT_ID 
--     → V_ODS_SALESFORCE_ACCOUNT.ID 
--     → V_ODS_SALESFORCE_ACCOUNT.PRIMARY_ACCOUNT_NUMBER_C 
--     → TRY_CAST(... AS FLOAT) 
--     → V_TDC_TICKET_SALES_UNIFIED.FINANCIAL_PATRON_ACCOUNT_ID
--
-- MATCH RATE: 42.5% (117,680 of 277,126 ticket customers in CRM)
-- This is excellent for a cross-system linkage.
--
-- DATABASE: TBRDP_DW_PROD.IM_RPT
-- WAREHOUSE: TBRDP_DW_CORTEX_XS_WH
-- =============================================================================


-- =============================================================================
-- STEP 1: ACCOUNT CROSSWALK TABLE
-- =============================================================================
-- Purpose: A lightweight mapping table that connects Salesforce Account IDs
-- to TDC Patron Account IDs. This is the Rosetta Stone for all Phase 5 joins.
-- Using a regular table (not dynamic) because the mapping is relatively stable 
-- and we control refresh via a scheduled task.
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

-- Validate crosswalk
SELECT 
    COUNT(*) AS total_mappings,
    COUNT(DISTINCT SF_ACCOUNT_ID) AS unique_sf_accounts,
    COUNT(DISTINCT PATRON_ACCOUNT_ID_FLOAT) AS unique_patron_ids,
    COUNT(CASE WHEN IS_PERSON_ACCOUNT = TRUE THEN 1 END) AS person_accounts,
    COUNT(CASE WHEN IS_PERSON_ACCOUNT = FALSE THEN 1 END) AS business_accounts
FROM TBRDP_DW_PROD.IM_RPT.T_ACCOUNT_CROSSWALK;


-- =============================================================================
-- STEP 2: CUSTOMER 360 DYNAMIC TABLE
-- =============================================================================
-- Purpose: Customer-level aggregation combining CRM opportunity data with 
-- actual ticket purchase transactions. One row per Salesforce Account.
-- 
-- This enables:
--   - Revenue attribution (opportunity $ vs actual purchase $)
--   - Customer lifecycle analysis (first contact → first purchase → repeat)
--   - Lifetime value calculation
--   - Conversion rate measurement
--   - Rep performance vs actual revenue
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE TBRDP_DW_PROD.IM_RPT.DT_CUSTOMER_360
TARGET_LAG = '1 hour'
WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
AS
WITH 

-- CRM Opportunity Summary per Account
opp_summary AS (
    SELECT 
        opp.ACCOUNT_ID,
        
        -- Opportunity counts
        COUNT(DISTINCT opp.ID) AS total_opportunities,
        COUNT(DISTINCT CASE WHEN opp.IS_WON = TRUE THEN opp.ID END) AS won_opportunities,
        COUNT(DISTINCT CASE WHEN opp.IS_CLOSED = TRUE AND opp.IS_WON = FALSE THEN opp.ID END) AS lost_opportunities,
        COUNT(DISTINCT CASE WHEN opp.IS_CLOSED = FALSE THEN opp.ID END) AS open_opportunities,
        
        -- Revenue from CRM
        SUM(CASE WHEN opp.IS_WON = TRUE THEN COALESCE(opp.AMOUNT, 0) ELSE 0 END) AS crm_won_revenue,
        SUM(CASE WHEN opp.IS_CLOSED = FALSE THEN COALESCE(opp.AMOUNT, 0) ELSE 0 END) AS crm_open_pipeline,
        SUM(COALESCE(opp.AMOUNT, 0)) AS crm_total_pipeline,
        
        -- Win rate
        CASE 
            WHEN COUNT(DISTINCT CASE WHEN opp.IS_CLOSED = TRUE THEN opp.ID END) > 0
            THEN ROUND(
                COUNT(DISTINCT CASE WHEN opp.IS_WON = TRUE THEN opp.ID END) * 100.0 / 
                COUNT(DISTINCT CASE WHEN opp.IS_CLOSED = TRUE THEN opp.ID END), 2
            )
            ELSE NULL
        END AS win_rate_pct,
        
        -- Timeline
        MIN(opp.CREATED_DATE) AS first_opportunity_date,
        MAX(opp.CREATED_DATE) AS latest_opportunity_date,
        MIN(CASE WHEN opp.IS_WON = TRUE THEN opp.CLOSE_DATE END) AS first_won_date,
        MAX(CASE WHEN opp.IS_WON = TRUE THEN opp.CLOSE_DATE END) AS latest_won_date,
        
        -- Ticket type from CRM (what type of tickets were in the opportunities)
        LISTAGG(DISTINCT opp.TICKET_TYPE_C, ', ') WITHIN GROUP (ORDER BY opp.TICKET_TYPE_C) AS crm_ticket_types,
        
        -- Seasons from CRM
        LISTAGG(DISTINCT opp.SEASON_C, ', ') WITHIN GROUP (ORDER BY opp.SEASON_C) AS crm_seasons,
        
        -- Current owner
        MAX_BY(opp.OWNER_ID, opp.CREATED_DATE) AS current_owner_id

    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY opp
    WHERE opp.SYSTEM_CURRENT_FLAG = 'Y'
      AND opp.IS_DELETED = FALSE
      AND opp.ACCOUNT_ID IS NOT NULL
    GROUP BY opp.ACCOUNT_ID
),

-- Ticket Purchase Summary per Patron Account
ticket_summary AS (
    SELECT 
        ts.FINANCIAL_PATRON_ACCOUNT_ID AS patron_id,
        
        -- Purchase counts
        COUNT(*) AS total_ticket_purchases,
        COUNT(DISTINCT ts.EVENT_ID) AS unique_events_attended,
        
        -- Revenue from ticket purchases
        SUM(COALESCE(ts.PRICE, 0)) AS total_ticket_revenue,
        SUM(COALESCE(ts.PAID_AMOUNT, 0)) AS total_paid_amount,
        ROUND(AVG(COALESCE(ts.PRICE, 0)), 2) AS avg_ticket_price,
        MAX(COALESCE(ts.PRICE, 0)) AS max_ticket_price,
        
        -- Seasons purchased
        COUNT(DISTINCT ts.SEASON_YEAR) AS seasons_purchased,
        LISTAGG(DISTINCT CAST(ts.SEASON_YEAR AS VARCHAR), ', ') 
            WITHIN GROUP (ORDER BY CAST(ts.SEASON_YEAR AS VARCHAR)) AS purchase_seasons,
        
        -- Ticket types purchased
        LISTAGG(DISTINCT ts.TICKET_TYPE_GROUPING, ', ') 
            WITHIN GROUP (ORDER BY ts.TICKET_TYPE_GROUPING) AS ticket_types_purchased,
        
        -- Revenue by ticket type
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Traditional Seasons' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS season_ticket_revenue,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Single Game' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS single_game_revenue,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Flex Season' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS flex_season_revenue,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Group' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS group_revenue,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Suite' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS suite_revenue,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Sponsor' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS sponsor_revenue,
        
        -- Timeline
        MIN(ts.PURCHASE_DATE) AS first_purchase_date,
        MAX(ts.PURCHASE_DATE) AS latest_purchase_date,
        
        -- Recency
        DATEDIFF('day', MAX(ts.PURCHASE_DATE), CURRENT_TIMESTAMP()) AS days_since_last_purchase,
        
        -- Membership info (from membership detail records)
        MAX(ts.MEMBERSHIP_TYPE) AS latest_membership_type,
        MAX(ts.MEMBERSHIP_PLAN) AS latest_membership_plan,
        
        -- Data source breakdown
        COUNT(CASE WHEN ts.DATA_SOURCE = 'Transaction Detail' THEN 1 END) AS transaction_records,
        COUNT(CASE WHEN ts.DATA_SOURCE = 'Membership Detail' THEN 1 END) AS membership_records
        
    FROM TBRDP_DW_PROD.IM_RPT.V_TDC_TICKET_SALES_UNIFIED ts
    WHERE ts.FINANCIAL_PATRON_ACCOUNT_ID IS NOT NULL
    GROUP BY ts.FINANCIAL_PATRON_ACCOUNT_ID
)

-- Final Customer 360 join
SELECT 
    -- Identity
    xw.SF_ACCOUNT_ID,
    xw.SF_ACCOUNT_NAME,
    xw.PATRON_ACCOUNT_ID_FLOAT AS PATRON_ACCOUNT_ID,
    xw.PV_ACCOUNT_NAME,
    xw.IS_PERSON_ACCOUNT,
    xw.ACCOUNT_TYPE,
    xw.INDUSTRY,
    
    -- Location
    xw.BILLING_CITY,
    xw.BILLING_STATE,
    xw.BILLING_ZIP,
    
    -- Rep assignments
    xw.ACCOUNT_OWNER_ID,
    xw.TICKET_SALES_REP,
    xw.TICKET_SERVICE_REP,
    xw.SUITE_SALES_REP,
    xw.GROUP_SALES_REP,
    xw.PARTNERSHIP_STATUS,
    xw.LEAD_SOURCE,
    
    -- CRM Opportunity Metrics
    COALESCE(os.total_opportunities, 0) AS total_opportunities,
    COALESCE(os.won_opportunities, 0) AS won_opportunities,
    COALESCE(os.lost_opportunities, 0) AS lost_opportunities,
    COALESCE(os.open_opportunities, 0) AS open_opportunities,
    COALESCE(os.crm_won_revenue, 0) AS crm_won_revenue,
    COALESCE(os.crm_open_pipeline, 0) AS crm_open_pipeline,
    COALESCE(os.crm_total_pipeline, 0) AS crm_total_pipeline,
    os.win_rate_pct,
    os.first_opportunity_date,
    os.latest_opportunity_date,
    os.first_won_date,
    os.latest_won_date,
    os.crm_ticket_types,
    os.crm_seasons,
    os.current_owner_id,
    
    -- Ticket Purchase Metrics
    COALESCE(ts.total_ticket_purchases, 0) AS total_ticket_purchases,
    COALESCE(ts.unique_events_attended, 0) AS unique_events_attended,
    COALESCE(ts.total_ticket_revenue, 0) AS total_ticket_revenue,
    COALESCE(ts.total_paid_amount, 0) AS total_paid_amount,
    ts.avg_ticket_price,
    ts.max_ticket_price,
    COALESCE(ts.seasons_purchased, 0) AS seasons_purchased,
    ts.purchase_seasons,
    ts.ticket_types_purchased,
    COALESCE(ts.season_ticket_revenue, 0) AS season_ticket_revenue,
    COALESCE(ts.single_game_revenue, 0) AS single_game_revenue,
    COALESCE(ts.flex_season_revenue, 0) AS flex_season_revenue,
    COALESCE(ts.group_revenue, 0) AS group_revenue,
    COALESCE(ts.suite_revenue, 0) AS suite_revenue,
    COALESCE(ts.sponsor_revenue, 0) AS sponsor_revenue,
    ts.first_purchase_date,
    ts.latest_purchase_date,
    ts.days_since_last_purchase,
    ts.latest_membership_type,
    ts.latest_membership_plan,
    COALESCE(ts.transaction_records, 0) AS transaction_records,
    COALESCE(ts.membership_records, 0) AS membership_records,
    
    -- ==========================================================================
    -- DERIVED CUSTOMER INTELLIGENCE METRICS
    -- ==========================================================================
    
    -- Lifetime Value (total ticket revenue from actual purchases)
    COALESCE(ts.total_ticket_revenue, 0) AS lifetime_ticket_value,
    
    -- Combined lifetime value (CRM won + ticket purchases, deduplicated by taking max)
    -- Using MAX because won revenue and ticket revenue may overlap
    GREATEST(COALESCE(os.crm_won_revenue, 0), COALESCE(ts.total_ticket_revenue, 0)) AS estimated_lifetime_value,
    
    -- Revenue attribution gap: difference between what CRM says vs actual purchases
    COALESCE(ts.total_ticket_revenue, 0) - COALESCE(os.crm_won_revenue, 0) AS revenue_attribution_gap,
    
    -- Conversion indicator: Has CRM opportunities AND actual ticket purchases
    CASE 
        WHEN os.total_opportunities > 0 AND ts.total_ticket_purchases > 0 THEN TRUE
        ELSE FALSE
    END AS has_crm_and_purchases,
    
    -- Customer segment based on behavior
    CASE
        WHEN os.total_opportunities > 0 AND ts.total_ticket_purchases > 0 THEN 'CRM + Purchaser'
        WHEN os.total_opportunities > 0 AND COALESCE(ts.total_ticket_purchases, 0) = 0 THEN 'CRM Only'
        WHEN COALESCE(os.total_opportunities, 0) = 0 AND ts.total_ticket_purchases > 0 THEN 'Direct Purchaser'
        ELSE 'Prospect'
    END AS customer_segment,
    
    -- Days from first opportunity to first purchase (conversion speed)
    CASE 
        WHEN os.first_opportunity_date IS NOT NULL AND ts.first_purchase_date IS NOT NULL
        THEN DATEDIFF('day', os.first_opportunity_date, ts.first_purchase_date)
        ELSE NULL
    END AS days_opp_to_first_purchase,
    
    -- Engagement recency tier
    CASE 
        WHEN ts.days_since_last_purchase <= 30 THEN 'Active (30 days)'
        WHEN ts.days_since_last_purchase <= 90 THEN 'Recent (90 days)'
        WHEN ts.days_since_last_purchase <= 365 THEN 'Lapsed (1 year)'
        WHEN ts.days_since_last_purchase > 365 THEN 'Dormant (1+ year)'
        ELSE 'No Purchases'
    END AS recency_tier,
    
    -- Revenue tier based on total ticket revenue
    CASE
        WHEN COALESCE(ts.total_ticket_revenue, 0) >= 50000 THEN 'Platinum ($50K+)'
        WHEN COALESCE(ts.total_ticket_revenue, 0) >= 10000 THEN 'Gold ($10K-$50K)'
        WHEN COALESCE(ts.total_ticket_revenue, 0) >= 1000 THEN 'Silver ($1K-$10K)'
        WHEN COALESCE(ts.total_ticket_revenue, 0) > 0 THEN 'Bronze (<$1K)'
        ELSE 'No Revenue'
    END AS revenue_tier,
    
    -- Churn risk flag (had purchases but none in last 365 days AND no open opportunities)
    CASE 
        WHEN ts.total_ticket_purchases > 0 
         AND ts.days_since_last_purchase > 365 
         AND COALESCE(os.open_opportunities, 0) = 0 
        THEN TRUE
        ELSE FALSE
    END AS churn_risk_flag,
    
    -- Upsell potential (single game buyers without season tickets)
    CASE
        WHEN COALESCE(ts.single_game_revenue, 0) > 0 
         AND COALESCE(ts.season_ticket_revenue, 0) = 0
         AND COALESCE(ts.flex_season_revenue, 0) = 0
        THEN TRUE
        ELSE FALSE
    END AS upsell_candidate,
    
    -- Multi-season loyalty (purchased in 3+ seasons)
    CASE 
        WHEN COALESCE(ts.seasons_purchased, 0) >= 3 THEN TRUE
        ELSE FALSE
    END AS is_loyal_customer,

    -- Metadata
    xw.ACCOUNT_CREATED_DATE,
    CURRENT_TIMESTAMP() AS last_refreshed_at

FROM TBRDP_DW_PROD.IM_RPT.T_ACCOUNT_CROSSWALK xw
LEFT JOIN opp_summary os ON xw.SF_ACCOUNT_ID = os.ACCOUNT_ID
LEFT JOIN ticket_summary ts ON xw.PATRON_ACCOUNT_ID_FLOAT = ts.patron_id;


-- =============================================================================
-- STEP 3: VALIDATION QUERIES
-- =============================================================================

-- 3a: Overall Customer 360 summary
SELECT 
    COUNT(*) AS total_customers,
    COUNT(CASE WHEN customer_segment = 'CRM + Purchaser' THEN 1 END) AS crm_and_purchaser,
    COUNT(CASE WHEN customer_segment = 'CRM Only' THEN 1 END) AS crm_only,
    COUNT(CASE WHEN customer_segment = 'Direct Purchaser' THEN 1 END) AS direct_purchaser,
    COUNT(CASE WHEN customer_segment = 'Prospect' THEN 1 END) AS prospect,
    ROUND(SUM(total_ticket_revenue), 2) AS total_ticket_revenue,
    ROUND(SUM(crm_won_revenue), 2) AS total_crm_won_revenue,
    ROUND(AVG(lifetime_ticket_value), 2) AS avg_lifetime_value
FROM TBRDP_DW_PROD.IM_RPT.DT_CUSTOMER_360;

-- 3b: Revenue tier distribution
SELECT 
    revenue_tier,
    COUNT(*) AS customer_count,
    ROUND(SUM(total_ticket_revenue), 2) AS total_revenue,
    ROUND(AVG(total_ticket_revenue), 2) AS avg_revenue,
    ROUND(AVG(total_opportunities), 1) AS avg_opportunities
FROM TBRDP_DW_PROD.IM_RPT.DT_CUSTOMER_360
WHERE total_ticket_revenue > 0
GROUP BY revenue_tier
ORDER BY total_revenue DESC;

-- 3c: Recency tier distribution
SELECT 
    recency_tier,
    COUNT(*) AS customer_count,
    ROUND(SUM(total_ticket_revenue), 2) AS total_revenue
FROM TBRDP_DW_PROD.IM_RPT.DT_CUSTOMER_360
GROUP BY recency_tier
ORDER BY customer_count DESC;

-- 3d: Conversion analysis - CRM opportunities that led to purchases
SELECT 
    customer_segment,
    COUNT(*) AS customers,
    ROUND(AVG(days_opp_to_first_purchase), 1) AS avg_days_to_purchase,
    ROUND(AVG(win_rate_pct), 1) AS avg_win_rate,
    ROUND(SUM(total_ticket_revenue), 2) AS total_ticket_revenue,
    ROUND(SUM(crm_won_revenue), 2) AS total_crm_won_revenue,
    ROUND(AVG(total_ticket_revenue), 2) AS avg_ticket_revenue
FROM TBRDP_DW_PROD.IM_RPT.DT_CUSTOMER_360
GROUP BY customer_segment
ORDER BY total_ticket_revenue DESC;

-- 3e: Churn risk summary
SELECT 
    churn_risk_flag,
    COUNT(*) AS customer_count,
    ROUND(SUM(total_ticket_revenue), 2) AS at_risk_revenue,
    ROUND(AVG(days_since_last_purchase), 0) AS avg_days_since_purchase
FROM TBRDP_DW_PROD.IM_RPT.DT_CUSTOMER_360
WHERE total_ticket_revenue > 0
GROUP BY churn_risk_flag;

-- 3f: Upsell candidates (single game buyers who could become season ticket holders)
SELECT 
    COUNT(*) AS upsell_candidates,
    ROUND(SUM(total_ticket_revenue), 2) AS current_revenue,
    ROUND(AVG(single_game_revenue), 2) AS avg_single_game_spend,
    ROUND(AVG(unique_events_attended), 1) AS avg_games_attended
FROM TBRDP_DW_PROD.IM_RPT.DT_CUSTOMER_360
WHERE upsell_candidate = TRUE;

-- 3g: Sample matched records - verify join quality
SELECT 
    SF_ACCOUNT_NAME,
    PV_ACCOUNT_NAME,
    customer_segment,
    revenue_tier,
    total_opportunities,
    won_opportunities,
    ROUND(crm_won_revenue, 2) AS crm_won_revenue,
    total_ticket_purchases,
    ROUND(total_ticket_revenue, 2) AS total_ticket_revenue,
    ticket_types_purchased,
    purchase_seasons,
    days_opp_to_first_purchase,
    recency_tier
FROM TBRDP_DW_PROD.IM_RPT.DT_CUSTOMER_360
WHERE customer_segment = 'CRM + Purchaser'
  AND total_ticket_revenue > 1000
ORDER BY total_ticket_revenue DESC
LIMIT 25;


-- =============================================================================
-- STEP 4: SCHEDULED REFRESH FOR CROSSWALK TABLE
-- =============================================================================
-- The crosswalk table is a regular table (not dynamic) so we need a task
-- to keep it updated. Weekly refresh is sufficient since account mappings 
-- don't change frequently.
-- =============================================================================

CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TASK_REFRESH_ACCOUNT_CROSSWALK
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    SCHEDULE = 'USING CRON 0 6 * * 1 America/New_York'  -- Every Monday at 6 AM ET
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

-- Enable the task (uncomment when ready)
-- ALTER TASK TBRDP_DW_PROD.IM_RPT.TASK_REFRESH_ACCOUNT_CROSSWALK RESUME;


