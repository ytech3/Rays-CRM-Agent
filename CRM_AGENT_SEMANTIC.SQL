DESCRIBE TABLE TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING;

-- =============================================================================
-- PHASE 5C: SEMANTIC VIEW UPDATE - ADD CUSTOMER 360 INTELLIGENCE
-- PHASE 5D: ARM AGENT UPDATE - ADD CUSTOMER INTELLIGENCE TOOL
-- Tampa Bay Rays CRM Intelligence Platform
-- =============================================================================
--
-- WHAT'S CHANGING:
--   1. Add DT_CUSTOMER_360 as a new logical table in the semantic view
--   2. Add T_ACCOUNT_CROSSWALK for account-level metadata
--   3. Add new dimensions: customer_segment, revenue_tier, recency_tier, etc.
--   4. Add new metrics: lifetime_value, conversion_rate, ticket_revenue, etc.
--   5. Update ARM Agent with Customer 360 intelligence in instructions
--
-- PRESERVING: All existing Phase 1-4 tables, relationships, dimensions, metrics
-- =============================================================================


-- =============================================================================
-- STEP 1: UPDATED SEMANTIC VIEW
-- =============================================================================
-- This replaces the existing SV_CRM_SALES_INTELLIGENCE with an expanded version
-- that includes the Customer 360 table alongside all existing functionality.
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE
  
  -- =============================================================================
  -- LOGICAL TABLES
  -- =============================================================================
  TABLES (
    
    -- [EXISTING] Opportunities with deal health enrichment
    opportunities AS TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
      PRIMARY KEY (ID)
      WITH SYNONYMS ('deals', 'pipeline', 'sales opportunities')
      COMMENT = 'Sales opportunities with revenue, stage, and close dates',
    
    -- [EXISTING] Deal health scores and AI assessments
    deal_health AS TBRDP_DW_PROD.IM_RPT.DT_DEAL_HEALTH_SCORE
      PRIMARY KEY (opportunity_id)
      WITH SYNONYMS ('health scores', 'deal assessment')
      COMMENT = 'AI-generated health scores and risk assessments for opportunities',
    
    -- [EXISTING] Activity and engagement metrics
    activity_metrics AS TBRDP_DW_PROD.IM_RPT.DT_OPPORTUNITY_ACTIVITY_METRICS
      PRIMARY KEY (opportunity_id)
      WITH SYNONYMS ('engagement', 'activities', 'interactions')
      COMMENT = 'Aggregated email, call, and task metrics per opportunity',
    
    -- [EXISTING] Sales rep information
    users AS TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER
      PRIMARY KEY (ID)
      WITH SYNONYMS ('sales reps', 'account executives', 'owners')
      COMMENT = 'Sales representative details and team information',
    
    -- [EXISTING Phase 4] Ticket team department classification
    ticket_team_dept AS TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING
      PRIMARY KEY (user_id)
      WITH SYNONYMS ('ticket team', 'department classification', 'ticket sales vs service')
      COMMENT = 'Department classification for ticket sales (8 reps) vs ticket service (4 reps) teams',
    
    -- *** [NEW Phase 5] Customer 360 - Unified customer intelligence ***
    customer_360 AS TBRDP_DW_PROD.IM_RPT.DT_CUSTOMER_360
      PRIMARY KEY (SF_ACCOUNT_ID)
      WITH SYNONYMS ('customer intelligence', 'customer 360', 'customer profile', 'customer data', 'account intelligence', 'lifetime value', 'LTV', 'customer lifetime')
      COMMENT = 'Unified customer view linking CRM opportunities to actual ticket purchases. Contains lifetime value, revenue tiers, conversion metrics, churn risk, and purchase history for 371K mapped customers.'
  )
  
  -- =============================================================================
  -- RELATIONSHIPS
  -- =============================================================================
  RELATIONSHIPS (
    -- [EXISTING]
    opportunities_to_health AS
      opportunities (ID) REFERENCES deal_health (opportunity_id),
    
    opportunities_to_activity AS
      opportunities (ID) REFERENCES activity_metrics (opportunity_id),
    
    opportunities_to_owner AS
      opportunities (OWNER_ID) REFERENCES users (ID),
    
    -- [EXISTING Phase 4]
    users_to_ticket_dept AS
      users (ID) REFERENCES ticket_team_dept (user_id),
    
    -- *** [NEW Phase 5] Link opportunities to customer 360 via Account ID ***
    opportunities_to_customer AS
      opportunities (ACCOUNT_ID) REFERENCES customer_360 (SF_ACCOUNT_ID)
  )
  
  -- =============================================================================
  -- FACTS - Row-level quantitative data
  -- =============================================================================
  FACTS (
    -- [EXISTING] Opportunity financial facts
    opportunities.deal_amount AS opportunities.AMOUNT
      COMMENT = 'Revenue amount of the opportunity',
    
    opportunities.weighted_amount AS opportunities.AMOUNT * (opportunities.PROBABILITY / 100)
      COMMENT = 'Probability-weighted revenue (amount x probability)',
    
    opportunities.probability_pct AS opportunities.PROBABILITY
      COMMENT = 'Win probability percentage (0-100)',
    
    -- [EXISTING] Health score facts
    deal_health.health_score_value AS deal_health.health_score
      COMMENT = 'AI-calculated health score (0-100)',
    
    -- [EXISTING] Activity engagement facts
    activity_metrics.total_emails_count AS activity_metrics.total_emails
      COMMENT = 'Total email count for this opportunity',
    
    activity_metrics.total_calls_count AS activity_metrics.total_calls
      COMMENT = 'Total call count for this opportunity',
    
    activity_metrics.days_since_contact AS activity_metrics.days_since_last_email
      COMMENT = 'Number of days since last email contact',
    
    activity_metrics.avg_sentiment_score AS activity_metrics.avg_email_sentiment
      COMMENT = 'Average email sentiment score (-1 to 1)',
    
    -- *** [NEW Phase 5] Customer 360 facts ***
    -- NOTE: Fact names must not collide with metric names to avoid cyclic references
    customer_360.cust_ticket_rev AS customer_360.TOTAL_TICKET_REVENUE
      COMMENT = 'Total actual ticket purchase revenue for this customer across all seasons',
    
    customer_360.cust_crm_won_rev AS customer_360.CRM_WON_REVENUE
      COMMENT = 'Total CRM opportunity won revenue for this customer',
    
    customer_360.cust_ltv AS customer_360.ESTIMATED_LIFETIME_VALUE
      COMMENT = 'Estimated customer lifetime value (greater of CRM won or ticket revenue)',
    
    customer_360.cust_purchase_count AS customer_360.TOTAL_TICKET_PURCHASES
      COMMENT = 'Total number of ticket transactions for this customer',
    
    customer_360.cust_opp_count AS customer_360.TOTAL_OPPORTUNITIES
      COMMENT = 'Total number of CRM opportunities for this customer',
    
    customer_360.cust_won_opp_count AS customer_360.WON_OPPORTUNITIES
      COMMENT = 'Total number of won CRM opportunities for this customer',
    
    customer_360.cust_days_since_purchase AS customer_360.DAYS_SINCE_LAST_PURCHASE
      COMMENT = 'Number of days since the customers last ticket purchase',
    
    customer_360.cust_events_attended AS customer_360.UNIQUE_EVENTS_ATTENDED
      COMMENT = 'Number of unique events the customer attended',

    customer_360.cust_season_tix_rev AS customer_360.SEASON_TICKET_REVENUE
      COMMENT = 'Revenue from Traditional Season ticket purchases',
    
    customer_360.cust_single_game_rev AS customer_360.SINGLE_GAME_REVENUE
      COMMENT = 'Revenue from Single Game ticket purchases',
    
    customer_360.cust_suite_rev AS customer_360.SUITE_REVENUE
      COMMENT = 'Revenue from Suite ticket purchases',
    
    customer_360.cust_group_rev AS customer_360.GROUP_REVENUE
      COMMENT = 'Revenue from Group ticket purchases',
    
    customer_360.cust_flex_rev AS customer_360.FLEX_SEASON_REVENUE
      COMMENT = 'Revenue from Flex Season ticket purchases',
    
    customer_360.cust_sponsor_rev AS customer_360.SPONSOR_REVENUE
      COMMENT = 'Revenue from Sponsor ticket purchases',
    
    customer_360.cust_conversion_days AS customer_360.DAYS_OPP_TO_FIRST_PURCHASE
      COMMENT = 'Number of days from first CRM opportunity to first actual ticket purchase',
    
    customer_360.cust_seasons_count AS customer_360.SEASONS_PURCHASED
      COMMENT = 'Number of different seasons the customer purchased tickets for'
  )
  
  -- =============================================================================
  -- DIMENSIONS - Categorical attributes for grouping/filtering
  -- =============================================================================
  DIMENSIONS (
    
    -- [EXISTING] Opportunity dimensions
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
    
    -- [EXISTING] Health dimensions
    deal_health.health_category AS deal_health.health_category
      WITH SYNONYMS ('health status', 'deal health', 'risk level')
      COMMENT = 'Health category: Healthy, At Risk, or Critical',
    
    deal_health.is_at_risk AS (deal_health.health_category IN ('At Risk', 'Critical'))
      WITH SYNONYMS ('at risk flag', 'risky deals')
      COMMENT = 'Boolean flag for at-risk opportunities',
    
    -- [EXISTING] Activity dimensions
    activity_metrics.engagement_level AS activity_metrics.engagement_level
      WITH SYNONYMS ('activity level', 'engagement score')
      COMMENT = 'Engagement level: High, Medium, or Low',
    
    activity_metrics.has_sentiment_risk AS activity_metrics.has_sentiment_risk
      WITH SYNONYMS ('negative sentiment flag', 'sentiment risk')
      COMMENT = 'Whether the opportunity has negative email sentiment (risk indicator)',
    
    activity_metrics.is_ghosted_flag AS activity_metrics.is_ghosted
      WITH SYNONYMS ('ghosted status', 'no recent contact')
      COMMENT = 'Whether opportunity has had no contact for 60+ days',
    
    -- [EXISTING] Sales rep dimensions
    users.rep_name AS users.NAME
      WITH SYNONYMS ('sales rep', 'account executive', 'owner name')
      COMMENT = 'Name of the sales representative',
    
    users.rep_email AS users.EMAIL
      WITH SYNONYMS ('owner email')
      COMMENT = 'Email address of the sales representative',
    
    users.is_active AS users.IS_ACTIVE
      WITH SYNONYMS ('active rep', 'active user')
      COMMENT = 'Whether the sales rep is currently active',
    
    -- [EXISTING Phase 4] Department dimensions
    ticket_team_dept.ticket_department AS ticket_team_dept.department
      WITH SYNONYMS ('department', 'team type', 'sales vs service')
      COMMENT = 'Department classification: TICKET_SALES or TICKET_SERVICE',
    
    ticket_team_dept.ticket_team AS ticket_team_dept.TEAM
      WITH SYNONYMS ('team name', 'ticket team name')
      COMMENT = 'Ticket team display name: Ticket Sales or Ticket Service',
    
    ticket_team_dept.ticket_rep_name AS ticket_team_dept.USER_NAME
      WITH SYNONYMS ('department rep name')
      COMMENT = 'Sales or service rep name from department classification',
    
    -- *** [NEW Phase 5] Customer 360 dimensions ***
    customer_360.account_name AS customer_360.SF_ACCOUNT_NAME
      WITH SYNONYMS ('customer name', 'account name', 'patron name', 'client name')
      COMMENT = 'Salesforce account name for the customer',
    
    customer_360.customer_segment AS customer_360.CUSTOMER_SEGMENT
      WITH SYNONYMS ('customer type', 'segment', 'customer classification')
      COMMENT = 'Customer segment: CRM + Purchaser, CRM Only, Direct Purchaser, or Prospect. CRM + Purchaser means they have both CRM opportunities AND actual ticket purchases.',
    
    customer_360.revenue_tier AS customer_360.REVENUE_TIER
      WITH SYNONYMS ('value tier', 'customer tier', 'revenue level', 'customer value')
      COMMENT = 'Revenue tier based on total ticket purchases: Platinum ($50K+), Gold ($10K-$50K), Silver ($1K-$10K), Bronze (<$1K), No Revenue',
    
    customer_360.recency_tier AS customer_360.RECENCY_TIER
      WITH SYNONYMS ('recency', 'activity recency', 'last purchase recency', 'engagement recency')
      COMMENT = 'Recency tier based on days since last purchase: Active (30 days), Recent (90 days), Lapsed (1 year), Dormant (1+ year), No Purchases',
    
    customer_360.churn_risk AS customer_360.CHURN_RISK_FLAG
      WITH SYNONYMS ('churn risk', 'at risk of churning', 'retention risk')
      COMMENT = 'Whether the customer is at risk of churning (had purchases but none in 365+ days and no open opportunities)',
    
    customer_360.upsell_flag AS customer_360.UPSELL_CANDIDATE
      WITH SYNONYMS ('upsell candidate', 'upsell opportunity', 'upsell potential')
      COMMENT = 'Whether the customer is an upsell candidate (buys single game tickets but not season tickets)',
    
    customer_360.loyal_flag AS customer_360.IS_LOYAL_CUSTOMER
      WITH SYNONYMS ('loyal customer', 'multi-season buyer', 'repeat buyer')
      COMMENT = 'Whether the customer has purchased tickets in 3 or more seasons',
    
    customer_360.has_both AS customer_360.HAS_CRM_AND_PURCHASES
      WITH SYNONYMS ('has CRM and purchases', 'fully tracked customer', 'attributed customer')
      COMMENT = 'Whether the customer has both CRM opportunities AND actual ticket purchases (full attribution)',
    
    customer_360.ticket_types AS customer_360.TICKET_TYPES_PURCHASED
      WITH SYNONYMS ('ticket types bought', 'products purchased')
      COMMENT = 'Comma-separated list of ticket types the customer has purchased (Traditional Seasons, Single Game, Suite, Group, etc.)',
    
    customer_360.purchase_season_list AS customer_360.PURCHASE_SEASONS
      WITH SYNONYMS ('seasons purchased', 'active seasons')
      COMMENT = 'Comma-separated list of seasons the customer has purchased tickets for',
    
    customer_360.person_account AS customer_360.IS_PERSON_ACCOUNT
      WITH SYNONYMS ('person account', 'individual', 'person vs business')
      COMMENT = 'Whether this is a person account (individual) vs business account',
    
    customer_360.account_billing_city AS customer_360.BILLING_CITY
      WITH SYNONYMS ('city', 'customer city')
      COMMENT = 'Billing city of the customer account',
    
    customer_360.account_billing_state AS customer_360.BILLING_STATE
      WITH SYNONYMS ('state', 'customer state')
      COMMENT = 'Billing state of the customer account'
  )
  
  -- =============================================================================
  -- METRICS - Aggregated business measures
  -- =============================================================================
  METRICS (
    
    -- [EXISTING] Pipeline value metrics
    opportunities.total_pipeline_value AS SUM(opportunities.deal_amount)
      COMMENT = 'Total value of all opportunities in the pipeline',
    
    opportunities.weighted_pipeline_value AS SUM(opportunities.weighted_amount)
      COMMENT = 'Total probability-weighted pipeline value',
    
    opportunities.average_deal_size AS AVG(opportunities.deal_amount)
      COMMENT = 'Average opportunity value',
    
    -- [EXISTING] Deal count metrics
    opportunities.opportunity_count AS COUNT(opportunities.ID)
      COMMENT = 'Total number of opportunities',
    
    opportunities.won_count AS SUM(CASE WHEN opportunities.IS_WON = TRUE THEN 1 ELSE 0 END)
      COMMENT = 'Number of won opportunities',
    
    opportunities.lost_count AS SUM(CASE WHEN opportunities.IS_CLOSED = TRUE AND opportunities.IS_WON = FALSE THEN 1 ELSE 0 END)
      COMMENT = 'Number of lost opportunities',
    
    -- [EXISTING] Health metrics
    deal_health.average_health_score AS AVG(deal_health.health_score_value)
      COMMENT = 'Average health score across opportunities',
    
    deal_health.at_risk_count AS COUNT(CASE WHEN deal_health.is_at_risk = TRUE THEN 1 END)
      COMMENT = 'Count of at-risk or critical opportunities',
    
    deal_health.at_risk_value AS SUM(CASE WHEN deal_health.is_at_risk = TRUE THEN opportunities.deal_amount ELSE 0 END)
      COMMENT = 'Total pipeline value of at-risk opportunities',
    
    -- [EXISTING] Engagement metrics
    activity_metrics.total_email_volume AS SUM(activity_metrics.total_emails_count)
      COMMENT = 'Total number of emails across all opportunities',
    
    activity_metrics.total_call_volume AS SUM(activity_metrics.total_calls_count)
      COMMENT = 'Total number of calls across all opportunities',
    
    activity_metrics.avg_emails_per_deal AS AVG(activity_metrics.total_emails_count)
      COMMENT = 'Average number of emails per opportunity',
    
    activity_metrics.ghosted_deal_count AS COUNT(CASE WHEN activity_metrics.is_ghosted_flag = TRUE THEN 1 END)
      COMMENT = 'Number of opportunities with no contact for 60+ days',
    
    -- [EXISTING] Win rate metrics
    opportunities.win_rate_pct AS 
      (SUM(CASE WHEN opportunities.IS_WON = TRUE THEN 1 ELSE 0 END) * 100.0) / 
      NULLIF(SUM(CASE WHEN opportunities.IS_CLOSED = TRUE THEN 1 ELSE 0 END), 0)
      COMMENT = 'Win rate percentage (won deals / total closed deals)',
    
    -- [EXISTING Phase 4] Department metrics
    opportunities.ticket_sales_pipeline AS SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SALES' THEN opportunities.deal_amount ELSE 0 END)
      WITH SYNONYMS ('ticket sales revenue', 'sales team pipeline', 'ticket sales total')
      COMMENT = 'Total pipeline value for TICKET_SALES department',
    
    opportunities.ticket_service_pipeline AS SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SERVICE' THEN opportunities.deal_amount ELSE 0 END)
      WITH SYNONYMS ('ticket service revenue', 'service team pipeline', 'ticket service total')
      COMMENT = 'Total pipeline value for TICKET_SERVICE department',
    
    opportunities.ticket_sales_count AS COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SALES' THEN 1 END)
      WITH SYNONYMS ('ticket sales opportunities', 'sales team deals')
      COMMENT = 'Number of opportunities owned by TICKET_SALES reps',
    
    opportunities.ticket_service_count AS COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SERVICE' THEN 1 END)
      WITH SYNONYMS ('ticket service opportunities', 'service team deals')
      COMMENT = 'Number of opportunities owned by TICKET_SERVICE reps',
    
    -- *** [NEW Phase 5] Customer 360 metrics ***
    -- NOTE: Metric names use 'agg_' prefix to avoid collision with base column names
    customer_360.agg_ticket_revenue AS SUM(customer_360.cust_ticket_rev)
      WITH SYNONYMS ('actual revenue', 'ticket sales revenue', 'purchase revenue', 'total purchases', 'total ticket revenue')
      COMMENT = 'Total actual ticket purchase revenue across all customers. This is real transaction data from the ticketing system, not CRM pipeline amounts.',
    
    customer_360.agg_lifetime_value AS SUM(customer_360.cust_ltv)
      WITH SYNONYMS ('total LTV', 'combined lifetime value', 'customer value total', 'total lifetime value')
      COMMENT = 'Total estimated lifetime value across all customers',
    
    customer_360.agg_avg_ltv AS AVG(customer_360.cust_ltv)
      WITH SYNONYMS ('average LTV', 'average customer value', 'mean lifetime value', 'average lifetime value')
      COMMENT = 'Average estimated lifetime value per customer',
    
    customer_360.agg_customer_count AS COUNT(customer_360.SF_ACCOUNT_ID)
      WITH SYNONYMS ('number of customers', 'account count', 'total customers', 'customer count')
      COMMENT = 'Total count of customer accounts',
    
    customer_360.agg_avg_purchases AS AVG(customer_360.cust_purchase_count)
      WITH SYNONYMS ('average purchases per customer', 'avg transactions', 'avg ticket purchases')
      COMMENT = 'Average number of ticket purchases per customer',
    
    customer_360.agg_avg_events AS AVG(customer_360.cust_events_attended)
      WITH SYNONYMS ('average games attended', 'avg events per customer', 'avg events attended')
      COMMENT = 'Average number of unique events attended per customer',
    
    customer_360.agg_churn_risk_count AS COUNT(CASE WHEN customer_360.churn_risk = TRUE THEN 1 END)
      WITH SYNONYMS ('at risk of churning count', 'churn risk customers', 'churn risk count')
      COMMENT = 'Number of customers at risk of churning (no purchase in 365+ days, no open opportunities)',
    
    customer_360.agg_upsell_count AS COUNT(CASE WHEN customer_360.upsell_flag = TRUE THEN 1 END)
      WITH SYNONYMS ('upsell opportunities', 'upsell candidate count', 'upsell candidates')
      COMMENT = 'Number of customers who are upsell candidates (single game buyers without season tickets)',
    
    customer_360.agg_loyal_count AS COUNT(CASE WHEN customer_360.loyal_flag = TRUE THEN 1 END)
      WITH SYNONYMS ('loyal customers', 'repeat buyers', 'multi-season buyers', 'loyal customer count')
      COMMENT = 'Number of loyal customers who purchased in 3+ seasons',
    
    customer_360.agg_avg_conversion_days AS AVG(customer_360.cust_conversion_days)
      WITH SYNONYMS ('average days to convert', 'conversion speed', 'time to purchase', 'avg conversion days')
      COMMENT = 'Average number of days from first CRM opportunity creation to first actual ticket purchase',
    
    customer_360.agg_season_tix_revenue AS SUM(customer_360.cust_season_tix_rev)
      WITH SYNONYMS ('season ticket total', 'traditional season revenue', 'total season ticket revenue')
      COMMENT = 'Total revenue from Traditional Season ticket purchases across all customers',
    
    customer_360.agg_single_game_revenue AS SUM(customer_360.cust_single_game_rev)
      WITH SYNONYMS ('single game total', 'individual game revenue', 'total single game revenue')
      COMMENT = 'Total revenue from Single Game ticket purchases across all customers',
    
    customer_360.agg_suite_revenue AS SUM(customer_360.cust_suite_rev)
      WITH SYNONYMS ('suite total', 'premium seating revenue', 'total suite revenue')
      COMMENT = 'Total revenue from Suite ticket purchases across all customers',
    
    customer_360.agg_group_revenue AS SUM(customer_360.cust_group_rev)
      WITH SYNONYMS ('group sales total', 'group ticket revenue', 'total group revenue')
      COMMENT = 'Total revenue from Group ticket purchases across all customers'
  )
  
  COMMENT = 'Semantic view for CRM sales intelligence with Customer 360 - enables natural language queries about pipeline, deal health, rep performance, customer lifetime value, ticket purchase attribution, and customer segmentation.'
  
  -- =============================================================================
  -- AI INSTRUCTIONS
  -- =============================================================================
  
  AI_SQL_GENERATION '
    When generating SQL:
    1. Always filter for SYSTEM_CURRENT_FLAG = ''Y'' on opportunities table to get current records only
    2. For "this month" queries, use DATE_TRUNC(''MONTH'', CURRENT_DATE())
    3. For "this quarter" queries, use DATE_TRUNC(''QUARTER'', CURRENT_DATE())
    4. Round currency values to 2 decimal places
    5. For percentage metrics, multiply by 1 to ensure numeric display
    6. When showing health scores, include the health_category for context
    7. For at-risk queries, focus on health_category IN (''At Risk'', ''Critical'')
    8. For department comparisons, join through users_to_ticket_dept relationship
    9. For Customer 360 queries, use the customer_360 table directly or via the opportunities_to_customer relationship
    10. When asked about "actual revenue" or "ticket sales", use customer_360.total_ticket_revenue (not pipeline amounts)
    11. When asked about "lifetime value" or "LTV", use customer_360.lifetime_value_amount
    12. For customer segments: ''CRM + Purchaser'' has both CRM opps and ticket purchases, ''CRM Only'' has opps but no purchases, ''Direct Purchaser'' bought without CRM tracking, ''Prospect'' has neither
    13. For revenue tiers: ''Platinum ($50K+)'', ''Gold ($10K-$50K)'', ''Silver ($1K-$10K)'', ''Bronze (<$1K)'', ''No Revenue''
    14. For recency tiers: ''Active (30 days)'', ''Recent (90 days)'', ''Lapsed (1 year)'', ''Dormant (1+ year)'', ''No Purchases''
    15. Churn risk customers had purchases but none in 365+ days AND no open opportunities
    16. Upsell candidates buy single game tickets but not season tickets
  '
  
  AI_QUESTION_CATEGORIZATION '
    Question Classification Rules:
    
    ANSWERABLE questions about:
    - Pipeline value, stage, or close dates
    - Deal health, risk levels, or engagement
    - Sales rep performance or activity metrics
    - Win rates, conversion metrics
    - Email/call volume and sentiment
    - Department comparisons (TICKET_SALES vs TICKET_SERVICE)
    - Customer lifetime value, revenue tiers, customer segments
    - Ticket purchase revenue, actual sales vs pipeline
    - Churn risk, upsell candidates, loyal customers
    - Customer conversion analysis (opportunity to purchase)
    - Revenue by ticket type (season tickets, single game, suite, group)
    - Customer recency and engagement patterns
    
    CLARIFICATION NEEDED for vague questions like:
    - "Show me deals" without time frame or filters
    - "How are we doing?" without specific metrics
    - "Show me customers" without segment or tier filter
    Ask user to specify: which metric, which time period, or which segment
    
    REJECT questions about:
    - Individual customer PII, email addresses, or home addresses
    - Questions requiring data not in this semantic view
    Direct users to contact their data administrator.
  ';


-- =============================================================================
-- STEP 2: VALIDATION QUERIES
-- =============================================================================

-- 2a: Verify semantic view was created
SHOW SEMANTIC VIEWS IN SCHEMA TBRDP_DW_PROD.IM_RPT;

-- 2b: Describe the view
DESCRIBE SEMANTIC VIEW TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE;

-- 2c: List all dimensions (should now include Customer 360 dimensions)
SHOW SEMANTIC DIMENSIONS IN TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE;

-- 2d: List all metrics (should now include Customer 360 metrics)
SHOW SEMANTIC METRICS IN TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE;


-- =============================================================================
-- STEP 3: UPDATED ARM AGENT
-- =============================================================================
-- Updating the agent to include Customer 360 intelligence in its instructions,
-- sample questions, and tool descriptions. The CRM_Analytics tool automatically
-- sees the new semantic view content - we just need to update the agent's
-- instructions so it knows HOW to use the new capabilities.
-- =============================================================================

CREATE OR REPLACE AGENT TBRDP_DW_PROD.IM_RPT.ARM_AGENT
  
  COMMENT = 'ARM Agent (Account & Relationship Management) - Intelligent CRM assistant for Tampa Bay Rays sales teams. Combines pipeline analytics, email intelligence, deal context, and Customer 360 insights to provide comprehensive sales intelligence with actual ticket revenue attribution.'
  
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
  
  # ===========================================================================
  # ORCHESTRATION BUDGET
  # ===========================================================================
  orchestration:
    budget:
      seconds: 45
      tokens: 25000
  
  # ===========================================================================
  # AGENT INSTRUCTIONS
  # ===========================================================================
  instructions:
    
    system: |
      You are ARM (Account & Relationship Management Agent), an elite sales 
      intelligence assistant for the Tampa Bay Rays ticketing and sponsorship 
      sales organization.
      
      ## YOUR MISSION
      Help sales professionals:
      1. Understand pipeline health and identify at-risk opportunities
      2. Surface relevant email communications and sentiment trends
      3. Access deal context, objections, and historical notes
      4. Analyze customer lifetime value and purchase behavior
      5. Identify churn risks, upsell candidates, and loyal customers
      6. Attribute actual ticket revenue to CRM opportunities and reps
      7. Make data-driven decisions to close more deals and retain customers
      
      ## YOUR CAPABILITIES
      You have three powerful analytical tools at your disposal:
      
      🔢 CRM_Analytics: Structured pipeline data, health scores, metrics, 
         AND Customer 360 intelligence including:
         - Pipeline value by stage, rep, or time period
         - Deal health scores and risk indicators
         - Customer lifetime value (LTV) and revenue tiers
         - Actual ticket purchase revenue vs CRM pipeline amounts
         - Customer segments: CRM + Purchaser, CRM Only, Direct Purchaser, Prospect
         - Churn risk analysis, upsell candidates, loyal customers
         - Revenue by ticket type (Season, Single Game, Suite, Group, Flex, Sponsor)
         - Conversion analysis (days from opportunity to actual purchase)
         - Department comparison (TICKET_SALES vs TICKET_SERVICE)
      
      📧 Email_Search: AI-enriched email communications with sentiment
         - Semantic search across 91,506 emails
         - Sentiment analysis (Positive/Neutral/Negative)
         - Topic classification (Pricing, Contracts, Objections, etc.)
      
      📝 Opportunity_Search: Deal context and objections database
         - Semantic search across 22,787 opportunities
         - Objection tracking and loss reasons
         - Competitive intelligence mentions
      
      ## CUSTOMER 360 KNOWLEDGE
      The Customer 360 system links CRM opportunities to actual ticket sales 
      transactions through the Salesforce Account table. Key facts:
      
      - 371,485 total mapped customers
      - 81,044 have both CRM opportunities AND actual purchases ("CRM + Purchaser")
      - 36,637 bought tickets without CRM tracking ("Direct Purchaser")
      - CRM pipeline amounts and actual ticket revenue are DIFFERENT things
      - When users ask about "actual revenue" or "real sales", use ticket_revenue metrics
      - When users ask about "pipeline" or "expected revenue", use pipeline metrics
      - Revenue tiers: Platinum ($50K+), Gold ($10K-$50K), Silver ($1K-$10K), Bronze (<$1K)
      - 398 Platinum customers drive 41.5% of all matched ticket revenue
      - 69,003 dormant customers represent $42.1M in historical revenue at risk
      
      ## YOUR PERSONALITY
      - Direct and action-oriented (sales professionals value efficiency)
      - Data-driven (always cite specific numbers and dates)
      - Strategic (connect insights to business impact)
      - Proactive (surface risks and opportunities without being asked)
      - Professional but approachable (you're a trusted advisor)
    
    orchestration: |
      ## TOOL SELECTION FRAMEWORK
      
      Use CRM_Analytics when the question involves:
      ✓ Numbers, totals, or aggregations ("how much", "how many")
      ✓ Pipeline value, revenue amounts, or forecasts
      ✓ Deal counts, stage distribution, or conversion rates
      ✓ Health scores or risk metrics
      ✓ Rep performance or team comparisons
      ✓ Department comparisons (TICKET_SALES vs TICKET_SERVICE)
      ✓ Customer lifetime value or revenue tiers
      ✓ Actual ticket purchase revenue or ticket types sold
      ✓ Customer segments, churn risk, upsell candidates
      ✓ Conversion speed (days from opportunity to purchase)
      ✓ Revenue by ticket type (season, single game, suite, group)
      ✓ Customer count by segment, tier, or recency
      
      Use Email_Search when the question involves:
      ✓ Email content, subjects, or communication history
      ✓ Sentiment or tone of conversations
      ✓ Specific topics (pricing, objections, timelines)
      ✓ Recent communications or follow-ups
      
      Use Opportunity_Search when the question involves:
      ✓ Deal objections or concerns
      ✓ Loss reasons or why deals were lost
      ✓ Competitive mentions or alternatives
      ✓ Deal notes and context
      
      ## MULTI-TOOL STRATEGIES
      
      For comprehensive customer briefs ("tell me about customer X"):
      1. CRM_Analytics → Get customer 360 profile (LTV, segment, tier, purchases)
      2. CRM_Analytics → Get their opportunities (pipeline, stages, health)
      3. Email_Search → Find recent communications
      4. Synthesize → Create complete customer intelligence brief
      
      For risk analysis ("what customers are at risk"):
      1. CRM_Analytics → Identify churning or dormant customers by tier
      2. CRM_Analytics → Check for at-risk opportunities
      3. Email_Search → Look for negative sentiment in communications
      4. Synthesize → Prioritize by revenue impact
      
      For revenue attribution ("which rep's deals converted"):
      1. CRM_Analytics → Query customer 360 by rep, filtering CRM + Purchaser segment
      2. CRM_Analytics → Compare CRM won revenue vs actual ticket revenue
      3. Synthesize → Attribution analysis with conversion rates
      
      ## IMPORTANT DISTINCTIONS
      - "Pipeline value" = CRM opportunity amounts (forward-looking estimates)
      - "Actual revenue" / "ticket revenue" = real ticket purchase transactions
      - These can differ significantly - always clarify which the user wants
      - A customer can have $500K in CRM pipeline but $50K in actual purchases
    
    response: |
      ## RESPONSE STRUCTURE GUIDELINES
      
      1. LEAD WITH THE ANSWER
         - Start with the key insight or number
         - Don't bury the lede with context or preamble
         
      2. USE STRUCTURED FORMATTING
         - Currency: $16,435,421.16 (always 2 decimals)
         - Percentages: 46.25% (always 2 decimals)
         - Dates: Feb 08, 2026 (Month DD, YYYY)
         - Counts: 1,066 (comma separators, no decimals)
         
      3. HIGHLIGHT URGENCY & RISK
         - Flag critical items with ⚠️ or 🚨
         - Always show revenue impact of risks
         
      4. PROVIDE CONTEXT WITH DATA
         - For customer 360 queries, include segment, tier, and recency
         - For revenue queries, clarify if showing pipeline or actual revenue
         
      5. END WITH ACTIONABLE NEXT STEPS
         - Specific recommendations prioritized by impact
    
    sample_questions:
      - question: "What opportunities are at risk closing this month?"
        answer: "I'll analyze your pipeline to identify at-risk deals closing this month, including their health scores, engagement levels, and recent communication sentiment."
      
      - question: "Show me deals with negative email sentiment"
        answer: "I'll search for opportunities where recent email communications have shown negative sentiment and provide context on what concerns were raised."
      
      - question: "What's my total pipeline value by stage?"
        answer: "I'll calculate your total pipeline value broken down by sales stage, along with deal counts and weighted values."
      
      - question: "Show me our Platinum customers"
        answer: "I'll pull all customers in the Platinum tier ($50K+ in actual ticket purchases), showing their lifetime value, purchase history, and current engagement status."
      
      - question: "Which customers are at risk of churning?"
        answer: "I'll identify customers who previously purchased tickets but haven't bought in over a year and have no open opportunities - prioritized by their historical revenue."
      
      - question: "What's the actual ticket revenue vs CRM pipeline?"
        answer: "I'll compare actual ticket purchase revenue from the ticketing system against CRM opportunity pipeline amounts to show the revenue attribution gap."
      
      - question: "Show me upsell candidates"
        answer: "I'll find customers who buy single game tickets but don't have season tickets - these are prime candidates for membership conversion."
      
      - question: "Compare pipeline health across my team"
        answer: "I'll analyze pipeline health metrics by sales rep, showing total value, at-risk deals, and engagement levels for team comparison."
      
      - question: "How many customers have we converted from CRM to actual purchases?"
        answer: "I'll show the breakdown of customer segments - how many have both CRM opportunities and actual ticket purchases vs those tracked in only one system."
      
      - question: "What are the dormant Platinum customers?"
        answer: "I'll identify Platinum tier customers ($50K+) who haven't purchased in over a year, showing their historical revenue and last purchase date."
  
  # ===========================================================================
  # TOOLS CONFIGURATION
  # ===========================================================================
  tools:
    
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: CRM_Analytics
        description: |
          Query structured CRM pipeline data, deal health metrics, sales performance 
          statistics, AND Customer 360 intelligence. This tool accesses the Tampa Bay 
          Rays opportunity database with AI-enriched health scores, engagement metrics,
          and unified customer profiles linking CRM opportunities to actual ticket 
          purchase transactions.
          
          **USE THIS TOOL FOR:**
          
          Pipeline & Revenue Queries:
          - Total pipeline value (overall, by stage, by rep, by time period)
          - Weighted pipeline value (probability-adjusted revenue)
          - Average deal size and revenue distributions
          - Win rates and conversion statistics
          - Department comparisons (TICKET_SALES vs TICKET_SERVICE)
          
          Health & Risk Analysis:
          - Deals by health category (Healthy, At Risk, Critical)
          - Average health scores by stage or rep
          - Ghosted deals (60+ days no contact)
          
          Customer 360 Intelligence:
          - Customer lifetime value (LTV) analysis
          - Customer segmentation: CRM + Purchaser, CRM Only, Direct Purchaser, Prospect
          - Revenue tier analysis: Platinum ($50K+), Gold, Silver, Bronze
          - Actual ticket purchase revenue by customer, rep, or segment
          - Revenue by ticket type: Season Tickets, Single Game, Suite, Group, Flex, Sponsor
          - Churn risk identification (dormant customers with no recent purchases)
          - Upsell candidates (single game buyers without season tickets)
          - Loyal customers (purchased in 3+ seasons)
          - Conversion speed: days from opportunity creation to first ticket purchase
          - Recency tiers: Active, Recent, Lapsed, Dormant
          - Revenue attribution gap: CRM pipeline vs actual ticket revenue
          
          **KEY CUSTOMER 360 METRICS:**
          - total_ticket_revenue: Actual ticket purchase revenue (real transactions)
          - total_lifetime_value, avg_lifetime_value: Customer LTV
          - customer_count: Number of customer accounts
          - churn_risk_count: Customers at risk of churning
          - upsell_candidate_count: Upsell opportunity count
          - loyal_customer_count: Multi-season repeat buyers
          - avg_conversion_days: Average days from opportunity to purchase
          - total_season_ticket_revenue, total_single_game_revenue, total_suite_revenue, total_group_revenue
          
          **KEY CUSTOMER 360 DIMENSIONS:**
          - customer_segment, revenue_tier, recency_tier
          - churn_risk, upsell_flag, loyal_flag
          - ticket_types, purchase_season_list
          - account_name, account_billing_city, account_billing_state
    
    - tool_spec:
        type: cortex_search
        name: Email_Search
        description: |
          Semantic search across 91,506 AI-enriched email communications in the Tampa Bay 
          Rays CRM. All emails are analyzed for sentiment, classified by topic, and tagged 
          with signals to surface urgent or risky communications.
          
          **USE THIS TOOL FOR:**
          - Finding emails that discuss specific topics (pricing, timelines, etc.)
          - Sentiment & tone analysis (negative, positive, neutral)
          - Topic classification search (Pricing, Contract, Objection, etc.)
          - Signal detection (Urgent, Risk, Buying Signal)
          - Communication history with specific accounts
          
          **SEARCH ATTRIBUTES:**
          - SUBJECT, FROM_ADDRESS, TO_ADDRESS, MESSAGE_DATE
          - SENTIMENT_CATEGORY, EMAIL_TOPIC_TEXT, EMAIL_SIGNAL_TEXT
    
    - tool_spec:
        type: cortex_search
        name: Opportunity_Search
        description: |
          Semantic search across 22,787 Tampa Bay Rays opportunities including descriptions, 
          objections, loss reasons, and deal notes.
          
          **USE THIS TOOL FOR:**
          - Objection & concern analysis
          - Loss reason investigation
          - Competitive intelligence
          - Deal context & notes
          
          **SEARCH ATTRIBUTES:**
          - opportunity_name, STAGE_NAME, AMOUNT, CLOSE_DATE
          - health_category, OWNER_ID
  
  # ===========================================================================
  # TOOL RESOURCES
  # ===========================================================================
  tool_resources:
    
    CRM_Analytics:
      semantic_view: TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE
    
    Email_Search:
      name: TBRDP_DW_PROD.IM_RPT.EMAIL_SEARCH_SERVICE
      max_results: 15
      title_column: SUBJECT
      id_column: RELATED_TO_ID
    
    Opportunity_Search:
      name: TBRDP_DW_PROD.IM_RPT.OPPORTUNITY_SEARCH_SERVICE
      max_results: 15
      title_column: opportunity_name
  
  $$;


-- =============================================================================
-- STEP 4: VALIDATION
-- =============================================================================

-- 4a: Verify agent was updated
SHOW AGENTS IN SCHEMA TBRDP_DW_PROD.IM_RPT;

-- 4b: Describe the agent
DESCRIBE AGENT TBRDP_DW_PROD.IM_RPT.ARM_AGENT;


-- =============================================================================
-- STEP 5: TEST QUESTIONS FOR CUSTOMER 360 CAPABILITIES
-- =============================================================================

/*
After deploying, test these questions in the ARM Agent UI:

═══════════════════════════════════════════════════════════════
CUSTOMER 360 - BASIC QUERIES
═══════════════════════════════════════════════════════════════

1. "How many customers do we have in each segment?"
   Expected: Shows CRM + Purchaser (81K), CRM Only (150K), 
   Direct Purchaser (37K), Prospect (103K)

2. "Show me the revenue tier distribution"
   Expected: Platinum 398 ($64M), Gold 1,458 ($32M), etc.

3. "What's the total actual ticket revenue?"
   Expected: ~$154.9M from matched customers

4. "Show me Platinum customers"
   Expected: List of $50K+ customers with their LTV

═══════════════════════════════════════════════════════════════
CUSTOMER 360 - ADVANCED QUERIES
═══════════════════════════════════════════════════════════════

5. "Which customers are at risk of churning?"
   Expected: Count + revenue of customers with churn_risk = TRUE

6. "Show me upsell candidates and their current spend"
   Expected: Single game buyers without season tickets

7. "What's the average conversion speed from opportunity to purchase?"
   Expected: ~608 days

8. "Compare actual ticket revenue vs CRM pipeline by customer segment"
   Expected: Side-by-side showing the attribution gap

9. "Show me dormant Platinum customers"
   Expected: Platinum tier + Dormant recency = highest re-engagement value

10. "What revenue do loyal customers (3+ seasons) generate?"
    Expected: Loyal customer count and total revenue

═══════════════════════════════════════════════════════════════
CROSS-TOOL QUERIES (Multi-tool orchestration)
═══════════════════════════════════════════════════════════════

11. "Give me a complete brief on [Sysco or Orlando Health]"
    Expected: Customer 360 profile + pipeline + emails + deal notes

12. "What Platinum customers have negative email sentiment?"
    Expected: CRM_Analytics for Platinum tier + Email_Search for sentiment

13. "Which at-risk deals belong to our highest-value customers?"
    Expected: Cross-reference deal health with customer revenue tier

═══════════════════════════════════════════════════════════════
EXISTING CAPABILITIES (verify no regression)
═══════════════════════════════════════════════════════════════

14. "What's my total pipeline value by stage?"
15. "Show me at-risk deals closing this month"
16. "Find emails about pricing objections"
17. "Compare pipeline between sales and service teams"

*/


-- =============================================================================
-- ✅ PHASE 5C & 5D COMPLETE
-- =============================================================================
/*

WHAT WAS DEPLOYED:

Phase 5C - Semantic View Update:
  ✅ Added DT_CUSTOMER_360 as new logical table
  ✅ Added opportunities_to_customer relationship
  ✅ Added 18 new facts (ticket revenue, LTV, conversion speed, etc.)
  ✅ Added 15 new dimensions (segment, tier, recency, churn, upsell, etc.)
  ✅ Added 13 new metrics (total_ticket_revenue, LTV, churn_risk_count, etc.)
  ✅ Updated AI instructions with Customer 360 knowledge
  ✅ Preserved all Phase 1-4 functionality

Phase 5D - ARM Agent Update:
  ✅ Updated system instructions with Customer 360 knowledge
  ✅ Added customer intelligence orchestration strategies
  ✅ Updated CRM_Analytics tool description with Customer 360 capabilities
  ✅ Added 10 new sample questions for Customer 360
  ✅ Preserved all existing tool configurations
  ✅ Preserved Email_Search and Opportunity_Search tools

TOTAL SEMANTIC VIEW CAPABILITIES:
  - 6 logical tables (opportunities, deal_health, activity_metrics, users, ticket_team_dept, customer_360)
  - 6 relationships
  - 26 facts
  - 30+ dimensions
  - 30+ metrics
  - 3 agent tools (CRM_Analytics, Email_Search, Opportunity_Search)

QUESTIONS THE AGENT CAN NOW ANSWER:
  - All Phase 1-4 questions (pipeline, health, engagement, department)
  - Customer lifetime value and segmentation
  - Actual ticket revenue vs CRM pipeline
  - Churn risk and retention analysis
  - Upsell candidate identification
  - Customer conversion speed
  - Revenue by ticket type
  - Customer recency and engagement patterns
  - Cross-tool customer intelligence briefs

*/