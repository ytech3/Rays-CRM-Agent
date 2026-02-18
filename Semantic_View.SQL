create or replace semantic view TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE
	tables (
		OPPORTUNITIES as TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY primary key (ID) with synonyms=('deals','pipeline','sales opportunities') comment='Sales opportunities with revenue, stage, and close dates',
		DEAL_HEALTH as TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE primary key (OPPORTUNITY_ID) with synonyms=('health scores','deal assessment') comment='AI-generated health scores and risk assessments for opportunities',
		ACTIVITY_METRICS as TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS primary key (OPPORTUNITY_ID) with synonyms=('engagement','activities','interactions') comment='Aggregated email, call, and task metrics per opportunity',
		USERS as TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER primary key (ID) with synonyms=('sales reps','account executives','owners') comment='Sales representative details and team information',
		TICKET_TEAM_DEPT as TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING primary key (USER_ID) with synonyms=('ticket team','department classification','ticket sales vs service') comment='Department classification for ticket sales (8 reps) vs ticket service (4 reps) teams',
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
		TICKET_TEAM_DEPT.TICKET_DEPARTMENT as ticket_team_dept.department with synonyms=('department','team type','sales vs service') comment='Department classification: TICKET_SALES or TICKET_SERVICE',
		TICKET_TEAM_DEPT.TICKET_TEAM as ticket_team_dept.TEAM with synonyms=('team name','ticket team name') comment='Ticket team display name: Ticket Sales or Ticket Service',
		TICKET_TEAM_DEPT.TICKET_REP_NAME as ticket_team_dept.USER_NAME with synonyms=('department rep name') comment='Sales or service rep name from department classification',
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
		OPPORTUNITIES.TICKET_SALES_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SALES' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('ticket sales revenue','sales team pipeline','ticket sales total') comment='Total pipeline value for TICKET_SALES department',
		OPPORTUNITIES.TICKET_SERVICE_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SERVICE' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('ticket service revenue','service team pipeline','ticket service total') comment='Total pipeline value for TICKET_SERVICE department',
		OPPORTUNITIES.TICKET_SALES_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SALES' THEN 1 END) with synonyms=('ticket sales opportunities','sales team deals') comment='Number of opportunities owned by TICKET_SALES reps',
		OPPORTUNITIES.TICKET_SERVICE_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SERVICE' THEN 1 END) with synonyms=('ticket service opportunities','service team deals') comment='Number of opportunities owned by TICKET_SERVICE reps',
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
	comment='Semantic view for CRM sales intelligence with Customer 360 - enables natural language queries about pipeline, deal health, rep performance, customer lifetime value, ticket purchase attribution, and customer segmentation.'
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
  $$
	ai_question_categorization $$
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
    - Show me deals without time frame or filters
    - How are we doing without specific metrics
    - Show me customers without segment or tier filter
    Ask user to specify: which metric, which time period, or which segment
    
    REJECT questions about:
    - Individual customer PII, email addresses, or home addresses
    - Questions requiring data not in this semantic view
    Direct users to contact their data administrator.
  $$;