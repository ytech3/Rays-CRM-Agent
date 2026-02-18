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
	tables (
		OPPORTUNITIES as TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY primary key (ID) with synonyms=('deals','pipeline','sales opportunities') comment='Sales opportunities with revenue, stage, and close dates',
		DEAL_HEALTH as TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE primary key (OPPORTUNITY_ID) with synonyms=('health scores','deal assessment') comment='AI-generated health scores and risk assessments for opportunities',
		ACTIVITY_METRICS as TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS primary key (OPPORTUNITY_ID) with synonyms=('engagement','activities','interactions') comment='Aggregated email, call, and task metrics per opportunity',
		USERS as TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER primary key (ID) with synonyms=('sales reps','account executives','owners') comment='Sales representative details and team information',
		TICKET_TEAM_DEPT as TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING primary key (USER_ID) with synonyms=('ticket team','department classification','sales vs service','group AEs','SM AEs','TSRs','corporate partnerships') comment='Department classification for 23 reps across 5 teams: Ticket Sales Group AEs (7), Ticket Service (4), Ticket Member AEs (2), Ticket Sales Reps/TSRs (4), and Corporate Partnership Sales (6)',
		CUSTOMER_360 as TBRDP_DW_PROD.IM_RPT.T_CUSTOMER_360 primary key (SF_ACCOUNT_ID) with synonyms=('customer intelligence','customer 360','customer profile','customer data','account intelligence','lifetime value','LTV','customer lifetime') comment='Unified customer view linking CRM opportunities to actual ticket purchases. Contains lifetime value, revenue tiers, conversion metrics, churn risk, and purchase history for 371K mapped customers.'
	)
	relationships (
		OPPORTUNITIES_TO_ACTIVITY as OPPORTUNITIES(ID) references ACTIVITY_METRICS(OPPORTUNITY_ID),
		OPPORTUNITIES_TO_CUSTOMER as OPPORTUNITIES(ACCOUNT_ID) references CUSTOMER_360(SF_ACCOUNT_ID),
		OPPORTUNITIES_TO_HEALTH as OPPORTUNITIES(ID) references DEAL_HEALTH(OPPORTUNITY_ID),
		OPPORTUNITIES_TO_OWNER as OPPORTUNITIES(OWNER_ID) references USERS(ID),
		USERS_TO_TICKET_DEPT as USERS(ID) references TICKET_TEAM_DEPT(USER_ID)
	)
	facts (
		OPPORTUNITIES.DEAL_AMOUNT as opportunities.AMOUNT comment='Revenue amount of the opportunity',
		OPPORTUNITIES.WEIGHTED_AMOUNT as opportunities.AMOUNT * (opportunities.PROBABILITY / 100) comment='Probability-weighted revenue (amount x probability)',
		OPPORTUNITIES.PROBABILITY_PCT as opportunities.PROBABILITY comment='Win probability percentage (0-100)',
		DEAL_HEALTH.HEALTH_SCORE_VALUE as deal_health.health_score comment='AI-calculated health score (0-100)',
		ACTIVITY_METRICS.TOTAL_EMAILS_COUNT as activity_metrics.total_emails comment='Total email count for this opportunity',
		ACTIVITY_METRICS.TOTAL_CALLS_COUNT as activity_metrics.total_calls comment='Total call count for this opportunity',
		ACTIVITY_METRICS.DAYS_SINCE_CONTACT as activity_metrics.days_since_last_email comment='Number of days since last email contact',
		ACTIVITY_METRICS.AVG_SENTIMENT_SCORE as activity_metrics.avg_email_sentiment comment='Average email sentiment score (-1 to 1)',
		CUSTOMER_360.CUST_TICKET_REV as customer_360.TOTAL_TICKET_REVENUE comment='Total actual ticket purchase revenue for this customer across all seasons',
		CUSTOMER_360.CUST_CRM_WON_REV as customer_360.CRM_WON_REVENUE comment='Total CRM opportunity won revenue for this customer',
		CUSTOMER_360.CUST_LTV as customer_360.ESTIMATED_LIFETIME_VALUE comment='Estimated customer lifetime value (greater of CRM won or ticket revenue)',
		CUSTOMER_360.CUST_PURCHASE_COUNT as customer_360.TOTAL_TICKET_PURCHASES comment='Total number of ticket transactions for this customer',
		CUSTOMER_360.CUST_OPP_COUNT as customer_360.TOTAL_OPPORTUNITIES comment='Total number of CRM opportunities for this customer',
		CUSTOMER_360.CUST_WON_OPP_COUNT as customer_360.WON_OPPORTUNITIES comment='Total number of won CRM opportunities for this customer',
		CUSTOMER_360.CUST_DAYS_SINCE_PURCHASE as customer_360.DAYS_SINCE_LAST_PURCHASE comment='Number of days since the customers last ticket purchase',
		CUSTOMER_360.CUST_EVENTS_ATTENDED as customer_360.UNIQUE_EVENTS_ATTENDED comment='Number of unique events the customer attended',
		CUSTOMER_360.CUST_SEASON_TIX_REV as customer_360.SEASON_TICKET_REVENUE comment='Revenue from Traditional Season ticket purchases',
		CUSTOMER_360.CUST_SINGLE_GAME_REV as customer_360.SINGLE_GAME_REVENUE comment='Revenue from Single Game ticket purchases',
		CUSTOMER_360.CUST_SUITE_REV as customer_360.SUITE_REVENUE comment='Revenue from Suite ticket purchases',
		CUSTOMER_360.CUST_GROUP_REV as customer_360.GROUP_REVENUE comment='Revenue from Group ticket purchases',
		CUSTOMER_360.CUST_FLEX_REV as customer_360.FLEX_SEASON_REVENUE comment='Revenue from Flex Season ticket purchases',
		CUSTOMER_360.CUST_SPONSOR_REV as customer_360.SPONSOR_REVENUE comment='Revenue from Sponsor ticket purchases',
		CUSTOMER_360.CUST_CONVERSION_DAYS as customer_360.DAYS_OPP_TO_FIRST_PURCHASE comment='Number of days from first CRM opportunity to first actual ticket purchase',
		CUSTOMER_360.CUST_SEASONS_COUNT as customer_360.SEASONS_PURCHASED comment='Number of different seasons the customer purchased tickets for'
	)
	dimensions (
		OPPORTUNITIES.OPP_NAME as opportunities.NAME with synonyms=('opportunity name','deal name') comment='Name of the sales opportunity',
		OPPORTUNITIES.STAGE as opportunities.STAGE_NAME with synonyms=('sales stage','pipeline stage','deal stage') comment='Current stage in the sales pipeline',
		OPPORTUNITIES.CLOSE_DATE as opportunities.CLOSE_DATE with synonyms=('expected close','close date') comment='Expected close date for the opportunity',
		OPPORTUNITIES.CLOSE_MONTH as DATE_TRUNC('MONTH', opportunities.CLOSE_DATE) with synonyms=('closing month') comment='Month when the opportunity is expected to close',
		OPPORTUNITIES.CLOSE_QUARTER as DATE_TRUNC('QUARTER', opportunities.CLOSE_DATE) with synonyms=('closing quarter') comment='Quarter when the opportunity is expected to close',
		OPPORTUNITIES.IS_CLOSED as opportunities.IS_CLOSED with synonyms=('closed status') comment='Whether the opportunity is closed (won or lost)',
		OPPORTUNITIES.IS_WON as opportunities.IS_WON with synonyms=('won status') comment='Whether the opportunity was won',
		DEAL_HEALTH.HEALTH_CATEGORY as deal_health.health_category with synonyms=('health status','deal health','risk level') comment='Health category: Healthy, At Risk, or Critical',
		DEAL_HEALTH.IS_AT_RISK as (deal_health.health_category IN ('At Risk', 'Critical')) with synonyms=('at risk flag','risky deals') comment='Boolean flag for at-risk opportunities',
		ACTIVITY_METRICS.ENGAGEMENT_LEVEL as activity_metrics.engagement_level with synonyms=('activity level','engagement score') comment='Engagement level: High, Medium, or Low',
		ACTIVITY_METRICS.HAS_SENTIMENT_RISK as activity_metrics.has_sentiment_risk with synonyms=('negative sentiment flag','sentiment risk') comment='Whether the opportunity has negative email sentiment (risk indicator)',
		ACTIVITY_METRICS.IS_GHOSTED_FLAG as activity_metrics.is_ghosted with synonyms=('ghosted status','no recent contact') comment='Whether opportunity has had no contact for 60+ days',
		USERS.REP_NAME as users.NAME with synonyms=('sales rep','account executive','owner name') comment='Name of the sales representative',
		USERS.REP_EMAIL as users.EMAIL with synonyms=('owner email') comment='Email address of the sales representative',
		USERS.IS_ACTIVE as users.IS_ACTIVE with synonyms=('active rep','active user') comment='Whether the sales rep is currently active',
		TICKET_TEAM_DEPT.TICKET_DEPARTMENT as ticket_team_dept.department with synonyms=('department','team type','sales vs service','group AEs','member AEs','TSRs','corporate partnerships') comment='Department code: TICKET_SALES (Group AEs), TICKET_SERVICE (Service Reps), TICKET_MEMBER_AE (Season Member AEs), TICKET_TSR (Ticket Sales Reps), CORPORATE_PARTNERSHIP_SALES (CP Sales)',
		TICKET_TEAM_DEPT.TICKET_TEAM as ticket_team_dept.TEAM with synonyms=('team name','ticket team name','group name') comment='Team display name: Ticket Sales Group Account Executives, Ticket Service, Ticket Account Executive, Ticket Sales Representative, or CP Sales',
		TICKET_TEAM_DEPT.TICKET_REP_NAME as ticket_team_dept.USER_NAME with synonyms=('department rep name','classified rep name') comment='Sales or service rep name from department classification',
		CUSTOMER_360.ACCOUNT_NAME as customer_360.SF_ACCOUNT_NAME with synonyms=('customer name','account name','patron name','client name') comment='Salesforce account name for the customer',
		CUSTOMER_360.CUSTOMER_SEGMENT as customer_360.CUSTOMER_SEGMENT with synonyms=('customer type','segment','customer classification') comment='Customer segment: CRM + Purchaser, CRM Only, Direct Purchaser, or Prospect.',
		CUSTOMER_360.REVENUE_TIER as customer_360.REVENUE_TIER with synonyms=('value tier','customer tier','revenue level','customer value') comment='Revenue tier based on total ticket purchases: Platinum, Gold, Silver, Bronze, No Revenue',
		CUSTOMER_360.RECENCY_TIER as customer_360.RECENCY_TIER with synonyms=('recency','activity recency','last purchase recency','engagement recency') comment='Recency tier based on days since last purchase: Active, Recent, Lapsed, Dormant, No Purchases',
		CUSTOMER_360.CHURN_RISK as customer_360.CHURN_RISK_FLAG with synonyms=('churn risk','at risk of churning','retention risk') comment='Whether the customer is at risk of churning',
		CUSTOMER_360.UPSELL_FLAG as customer_360.UPSELL_CANDIDATE with synonyms=('upsell candidate','upsell opportunity','upsell potential') comment='Whether the customer is an upsell candidate',
		CUSTOMER_360.LOYAL_FLAG as customer_360.IS_LOYAL_CUSTOMER with synonyms=('loyal customer','multi-season buyer','repeat buyer') comment='Whether the customer has purchased tickets in 3 or more seasons',
		CUSTOMER_360.HAS_BOTH as customer_360.HAS_CRM_AND_PURCHASES with synonyms=('has CRM and purchases','fully tracked customer','attributed customer') comment='Whether the customer has both CRM opportunities AND actual ticket purchases',
		CUSTOMER_360.TICKET_TYPES as customer_360.TICKET_TYPES_PURCHASED with synonyms=('ticket types bought','products purchased') comment='Comma-separated list of ticket types the customer has purchased',
		CUSTOMER_360.PURCHASE_SEASON_LIST as customer_360.PURCHASE_SEASONS with synonyms=('seasons purchased','active seasons') comment='Comma-separated list of seasons the customer has purchased tickets for',
		CUSTOMER_360.PERSON_ACCOUNT as customer_360.IS_PERSON_ACCOUNT with synonyms=('person account','individual','person vs business') comment='Whether this is a person account vs business account',
		CUSTOMER_360.ACCOUNT_BILLING_CITY as customer_360.BILLING_CITY with synonyms=('city','customer city') comment='Billing city of the customer account',
		CUSTOMER_360.ACCOUNT_BILLING_STATE as customer_360.BILLING_STATE with synonyms=('state','customer state') comment='Billing state of the customer account'
	)
	metrics (
		OPPORTUNITIES.TOTAL_PIPELINE_VALUE as SUM(opportunities.deal_amount) comment='Total value of all opportunities in the pipeline',
		OPPORTUNITIES.WEIGHTED_PIPELINE_VALUE as SUM(opportunities.weighted_amount) comment='Total probability-weighted pipeline value',
		OPPORTUNITIES.AVERAGE_DEAL_SIZE as AVG(opportunities.deal_amount) comment='Average opportunity value',
		OPPORTUNITIES.OPPORTUNITY_COUNT as COUNT(opportunities.ID) comment='Total number of opportunities',
		OPPORTUNITIES.WON_COUNT as SUM(CASE WHEN opportunities.IS_WON = TRUE THEN 1 ELSE 0 END) comment='Number of won opportunities',
		OPPORTUNITIES.LOST_COUNT as SUM(CASE WHEN opportunities.IS_CLOSED = TRUE AND opportunities.IS_WON = FALSE THEN 1 ELSE 0 END) comment='Number of lost opportunities',
		OPPORTUNITIES.WIN_RATE_PCT as (SUM(CASE WHEN opportunities.IS_WON = TRUE THEN 1 ELSE 0 END) * 100.0) / NULLIF(SUM(CASE WHEN opportunities.IS_CLOSED = TRUE THEN 1 ELSE 0 END), 0) comment='Win rate percentage',
		OPPORTUNITIES.TICKET_SALES_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SALES' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('group AE pipeline','group AE revenue','ticket sales total') comment='Total pipeline value for Ticket Sales Group AEs',
		OPPORTUNITIES.TICKET_SERVICE_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SERVICE' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('service pipeline','service team pipeline','ticket service total') comment='Total pipeline value for Ticket Service department',
		OPPORTUNITIES.TICKET_SALES_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SALES' THEN 1 END) with synonyms=('group AE opportunities','group AE deals') comment='Number of opportunities owned by Ticket Sales Group AEs',
		OPPORTUNITIES.TICKET_SERVICE_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SERVICE' THEN 1 END) with synonyms=('service opportunities','service team deals') comment='Number of opportunities owned by Ticket Service reps',
		OPPORTUNITIES.MEMBER_AE_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_MEMBER_AE' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('member AE pipeline','season member pipeline','SM AE revenue') comment='Total pipeline value for Ticket Member AEs (Season Membership)',
		OPPORTUNITIES.MEMBER_AE_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_MEMBER_AE' THEN 1 END) with synonyms=('member AE opportunities','SM AE deals') comment='Number of opportunities owned by Ticket Member AEs',
		OPPORTUNITIES.TSR_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_TSR' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('TSR pipeline','ticket sales rep pipeline','TSR revenue') comment='Total pipeline value for Ticket Sales Representatives (TSRs)',
		OPPORTUNITIES.TSR_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_TSR' THEN 1 END) with synonyms=('TSR opportunities','TSR deals') comment='Number of opportunities owned by TSRs',
		OPPORTUNITIES.CP_SALES_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'CORPORATE_PARTNERSHIP_SALES' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('corporate partnership pipeline','CP pipeline','sponsorship pipeline') comment='Total pipeline value for Corporate Partnership Sales',
		OPPORTUNITIES.CP_SALES_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'CORPORATE_PARTNERSHIP_SALES' THEN 1 END) with synonyms=('CP opportunities','corporate partnership deals','sponsorship deals') comment='Number of opportunities owned by Corporate Partnership Sales',
		DEAL_HEALTH.AVERAGE_HEALTH_SCORE as AVG(deal_health.health_score_value) comment='Average health score across opportunities',
		DEAL_HEALTH.AT_RISK_COUNT as COUNT(CASE WHEN deal_health.is_at_risk = TRUE THEN 1 END) comment='Count of at-risk or critical opportunities',
		DEAL_HEALTH.AT_RISK_VALUE as SUM(CASE WHEN deal_health.is_at_risk = TRUE THEN opportunities.deal_amount ELSE 0 END) comment='Total pipeline value of at-risk opportunities',
		ACTIVITY_METRICS.TOTAL_EMAIL_VOLUME as SUM(activity_metrics.total_emails_count) comment='Total number of emails across all opportunities',
		ACTIVITY_METRICS.TOTAL_CALL_VOLUME as SUM(activity_metrics.total_calls_count) comment='Total number of calls across all opportunities',
		ACTIVITY_METRICS.AVG_EMAILS_PER_DEAL as AVG(activity_metrics.total_emails_count) comment='Average number of emails per opportunity',
		ACTIVITY_METRICS.GHOSTED_DEAL_COUNT as COUNT(CASE WHEN activity_metrics.is_ghosted_flag = TRUE THEN 1 END) comment='Number of opportunities with no contact for 60+ days',
		CUSTOMER_360.AGG_TICKET_REVENUE as SUM(customer_360.cust_ticket_rev) with synonyms=('actual revenue','ticket sales revenue','purchase revenue','total purchases','total ticket revenue') comment='Total actual ticket purchase revenue across all customers',
		CUSTOMER_360.AGG_LIFETIME_VALUE as SUM(customer_360.cust_ltv) with synonyms=('total LTV','combined lifetime value','customer value total','total lifetime value') comment='Total estimated lifetime value across all customers',
		CUSTOMER_360.AGG_AVG_LTV as AVG(customer_360.cust_ltv) with synonyms=('average LTV','average customer value','mean lifetime value','average lifetime value') comment='Average estimated lifetime value per customer',
		CUSTOMER_360.AGG_CUSTOMER_COUNT as COUNT(customer_360.SF_ACCOUNT_ID) with synonyms=('number of customers','account count','total customers','customer count') comment='Total count of customer accounts',
		CUSTOMER_360.AGG_AVG_PURCHASES as AVG(customer_360.cust_purchase_count) with synonyms=('average purchases per customer','avg transactions','avg ticket purchases') comment='Average number of ticket purchases per customer',
		CUSTOMER_360.AGG_AVG_EVENTS as AVG(customer_360.cust_events_attended) with synonyms=('average games attended','avg events per customer','avg events attended') comment='Average number of unique events attended per customer',
		CUSTOMER_360.AGG_CHURN_RISK_COUNT as COUNT(CASE WHEN customer_360.churn_risk = TRUE THEN 1 END) with synonyms=('at risk of churning count','churn risk customers','churn risk count') comment='Number of customers at risk of churning',
		CUSTOMER_360.AGG_UPSELL_COUNT as COUNT(CASE WHEN customer_360.upsell_flag = TRUE THEN 1 END) with synonyms=('upsell opportunities','upsell candidate count','upsell candidates') comment='Number of customers who are upsell candidates',
		CUSTOMER_360.AGG_LOYAL_COUNT as COUNT(CASE WHEN customer_360.loyal_flag = TRUE THEN 1 END) with synonyms=('loyal customers','repeat buyers','multi-season buyers','loyal customer count') comment='Number of loyal customers who purchased in 3+ seasons',
		CUSTOMER_360.AGG_AVG_CONVERSION_DAYS as AVG(customer_360.cust_conversion_days) with synonyms=('average days to convert','conversion speed','time to purchase','avg conversion days') comment='Average number of days from first CRM opportunity creation to first actual ticket purchase',
		CUSTOMER_360.AGG_SEASON_TIX_REVENUE as SUM(customer_360.cust_season_tix_rev) with synonyms=('season ticket total','traditional season revenue','total season ticket revenue') comment='Total revenue from Traditional Season ticket purchases across all customers',
		CUSTOMER_360.AGG_SINGLE_GAME_REVENUE as SUM(customer_360.cust_single_game_rev) with synonyms=('single game total','individual game revenue','total single game revenue') comment='Total revenue from Single Game ticket purchases across all customers',
		CUSTOMER_360.AGG_SUITE_REVENUE as SUM(customer_360.cust_suite_rev) with synonyms=('suite total','premium seating revenue','total suite revenue') comment='Total revenue from Suite ticket purchases across all customers',
		CUSTOMER_360.AGG_GROUP_REVENUE as SUM(customer_360.cust_group_rev) with synonyms=('group sales total','group ticket revenue','total group revenue') comment='Total revenue from Group ticket purchases across all customers'
	)
	comment='Semantic view for CRM sales intelligence with Customer 360 - enables natural language queries about pipeline, deal health, rep performance across 5 departments (Group AEs, Service, Member AEs, TSRs, Corporate Partnerships), customer lifetime value, ticket purchase attribution, and customer segmentation.'
	ai_sql_generation $$
    When generating SQL:
    1. Always filter for SYSTEM_CURRENT_FLAG = 'Y' on opportunities table to get current records only
    2. For this month queries, use DATE_TRUNC('MONTH', CURRENT_DATE())
    3. For this quarter queries, use DATE_TRUNC('QUARTER', CURRENT_DATE())
    4. Round currency values to 2 decimal places
    5. For percentage metrics, multiply by 1 to ensure numeric display
    6. When showing health scores, include the health_category for context
    7. For at-risk queries, focus on health_category IN ('At Risk', 'Critical')
    8. For department comparisons, join through users_to_ticket_dept relationship
    9. For Customer 360 queries, use the customer_360 table directly or via the opportunities_to_customer relationship
    10. When asked about actual revenue or ticket sales, use customer_360.total_ticket_revenue (not pipeline amounts)
    11. When asked about lifetime value or LTV, use customer_360.estimated_lifetime_value
    12. For customer segments: CRM + Purchaser, CRM Only, Direct Purchaser, Prospect
    13. For revenue tiers: Platinum ($50K+), Gold ($10K-$50K), Silver ($1K-$10K), Bronze (<$1K), No Revenue
    14. For recency tiers: Active (30 days), Recent (90 days), Lapsed (1 year), Dormant (1+ year), No Purchases
    15. Churn risk customers had purchases but none in 365+ days AND no open opportunities
    16. Upsell candidates buy single game tickets but not season tickets
    17. Department codes: TICKET_SALES = Group AEs (7 reps), TICKET_SERVICE = Service Reps (4 reps), TICKET_MEMBER_AE = Season Member AEs (2 reps), TICKET_TSR = Ticket Sales Reps (4 reps), CORPORATE_PARTNERSHIP_SALES = CP Sales (6 reps)
    18. When asked about Group AEs or group account executives, filter ticket_team_dept.department = 'TICKET_SALES'
    19. When asked about SM AEs or season membership or member AEs, filter ticket_team_dept.department = 'TICKET_MEMBER_AE'
    20. When asked about TSRs or ticket sales reps, filter ticket_team_dept.department = 'TICKET_TSR'
    21. When asked about corporate partnerships or sponsorship sales, filter ticket_team_dept.department = 'CORPORATE_PARTNERSHIP_SALES'
    22. When comparing departments or teams, group by ticket_team_dept.department or ticket_team_dept.team
  $$
	ai_question_categorization $$
    Question Classification Rules:
    
    ANSWERABLE questions about:
    - Pipeline value, stage, or close dates
    - Deal health, risk levels, or engagement
    - Sales rep performance or activity metrics
    - Win rates, conversion metrics
    - Email/call volume and sentiment
    - Department comparisons across all 5 teams (Group AEs, Service, Member AEs, TSRs, CP Sales)
    - Individual rep performance by name
    - Customer lifetime value, revenue tiers, customer segments
    - Ticket purchase revenue, actual sales vs pipeline
    - Churn risk, upsell candidates, loyal customers
    - Customer conversion analysis (opportunity to purchase)
    - Revenue by ticket type (season tickets, single game, suite, group)
    - Customer recency and engagement patterns
    - Corporate partnership pipeline and performance
    
    CLARIFICATION NEEDED for vague questions like:
    - Show me deals without time frame or filters
    - How are we doing without specific metrics
    - Show me customers without segment or tier filter
    Ask user to specify: which metric, which time period, or which segment
    
    REJECT questions about:
    - Individual customer PII, email addresses, or home addresses
    - Questions requiring data not in this semantic view
    Direct users to contact their data administrator.
  $$;


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