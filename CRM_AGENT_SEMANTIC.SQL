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

create or replace semantic view SV_CRM_SALES_INTELLIGENCE
	tables (
		ACTIVITY_METRICS as TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS primary key (OPPORTUNITY_ID) with synonyms=('activities','engagement','interactions') comment='Aggregated email, call, and task metrics per opportunity',
		CUSTOMER_360 as TBRDP_DW_PROD.IM_RPT.T_CUSTOMER_360 primary key (SF_ACCOUNT_ID) with synonyms=('account intelligence','customer 360','customer data','customer intelligence','customer lifetime','customer profile','lifetime value','LTV') comment='Unified customer view linking CRM opportunities to actual ticket purchases. Contains lifetime value, revenue tiers, conversion metrics, churn risk, and purchase history for 371K mapped customers.',
		DEAL_HEALTH as TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE primary key (OPPORTUNITY_ID) with synonyms=('deal assessment','health scores') comment='AI-generated health scores and risk assessments for opportunities',
		EMAIL_ANALYTICS as TBRDP_DW_PROD.IM_RPT.T_EMAIL_ANALYTICS primary key (EMAIL_ID) with synonyms=('communications','email activity','email metrics','email volume','emails','outreach','response times') comment='Individual email records with timestamps, direction, rep attribution, sentiment, response time calculations, and time-of-day analysis. Use for email volume counts, send time optimization, and response rate analysis.',
		OPPORTUNITIES as TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY primary key (ID) with synonyms=('deals','pipeline','sales opportunities') comment='Sales opportunities with revenue, stage, and close dates',
		TICKET_TEAM_DEPT as TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING primary key (USER_ID) with synonyms=('corporate partnerships','department classification','group AEs','sales vs service','SM AEs','ticket team','TSRs') comment='Department classification for 23 reps across 5 teams: Ticket Sales Group AEs (7), Ticket Service (4), Ticket Member AEs (2), Ticket Sales Reps/TSRs (4), and Corporate Partnership Sales (6)',
		USERS as TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER primary key (ID) with synonyms=('account executives','owners','sales reps') comment='Sales representative details and team information',
		CALL_ACTIVITY as TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY primary key (SESSION_ID) with synonyms=('call activity','call data','call log','call metrics','calls','phone activity','phone calls','zoom calls') comment='Unified call activity from Zoom Contact Center (Session History) and Zoom Phone (Call Log). Contains call direction, talk time, duration, agent attribution, notes, and opportunity linkage. All timestamps in Eastern Time to match Tableau dashboard.'
	)
	relationships (
		EMAILS_TO_OPPORTUNITY as EMAIL_ANALYTICS(OPPORTUNITY_ID) references OPPORTUNITIES(ID),
		EMAILS_TO_REP as EMAIL_ANALYTICS(REP_USER_ID) references USERS(ID),
		OPPORTUNITIES_TO_ACTIVITY as OPPORTUNITIES(ID) references ACTIVITY_METRICS(OPPORTUNITY_ID),
		OPPORTUNITIES_TO_CUSTOMER as OPPORTUNITIES(ACCOUNT_ID) references CUSTOMER_360(SF_ACCOUNT_ID),
		OPPORTUNITIES_TO_HEALTH as OPPORTUNITIES(ID) references DEAL_HEALTH(OPPORTUNITY_ID),
		OPPORTUNITIES_TO_OWNER as OPPORTUNITIES(OWNER_ID) references USERS(ID),
		USERS_TO_TICKET_DEPT as USERS(ID) references TICKET_TEAM_DEPT(USER_ID),
		CALL_TO_OPPORTUNITY as CALL_ACTIVITY(OPPORTUNITY_ID) references OPPORTUNITIES(ID),
		CALL_TO_USER as CALL_ACTIVITY(AGENT_OWNER_ID) references USERS(ID)
	)
	facts (
		-- ===== ACTIVITY_METRICS facts (unchanged) =====
		ACTIVITY_METRICS.AVG_SENTIMENT_SCORE as activity_metrics.AVG_EMAIL_SENTIMENT comment='Average email sentiment score (-1 to 1)',
		ACTIVITY_METRICS.DAYS_SINCE_CONTACT as activity_metrics.DAYS_SINCE_LAST_EMAIL comment='Number of days since last email contact',
		ACTIVITY_METRICS.TOTAL_CALLS_COUNT as activity_metrics.TOTAL_CALLS comment='Total call count for this opportunity',
		ACTIVITY_METRICS.TOTAL_EMAILS_COUNT as activity_metrics.TOTAL_EMAILS comment='Total email count for this opportunity',
		-- ===== CUSTOMER_360 facts (unchanged) =====
		CUSTOMER_360.CUST_CONVERSION_DAYS as customer_360.DAYS_OPP_TO_FIRST_PURCHASE comment='Number of days from first CRM opportunity to first actual ticket purchase',
		CUSTOMER_360.CUST_CRM_WON_REV as customer_360.CRM_WON_REVENUE comment='Total CRM opportunity won revenue for this customer',
		CUSTOMER_360.CUST_DAYS_SINCE_PURCHASE as customer_360.DAYS_SINCE_LAST_PURCHASE comment='Number of days since the customers last ticket purchase',
		CUSTOMER_360.CUST_EVENTS_ATTENDED as customer_360.UNIQUE_EVENTS_ATTENDED comment='Number of unique events the customer attended',
		CUSTOMER_360.CUST_FLEX_REV as customer_360.FLEX_SEASON_REVENUE comment='Revenue from Flex Season ticket purchases',
		CUSTOMER_360.CUST_GROUP_REV as customer_360.GROUP_REVENUE comment='Revenue from Group ticket purchases',
		CUSTOMER_360.CUST_LTV as customer_360.ESTIMATED_LIFETIME_VALUE comment='Estimated customer lifetime value (greater of CRM won or ticket revenue)',
		CUSTOMER_360.CUST_OPP_COUNT as customer_360.TOTAL_OPPORTUNITIES comment='Total number of CRM opportunities for this customer',
		CUSTOMER_360.CUST_PURCHASE_COUNT as customer_360.TOTAL_TICKET_PURCHASES comment='Total number of ticket transactions for this customer',
		CUSTOMER_360.CUST_SEASON_TIX_REV as customer_360.SEASON_TICKET_REVENUE comment='Revenue from Traditional Season ticket purchases',
		CUSTOMER_360.CUST_SEASONS_COUNT as customer_360.SEASONS_PURCHASED comment='Number of different seasons the customer purchased tickets for',
		CUSTOMER_360.CUST_SINGLE_GAME_REV as customer_360.SINGLE_GAME_REVENUE comment='Revenue from Single Game ticket purchases',
		CUSTOMER_360.CUST_SPONSOR_REV as customer_360.SPONSOR_REVENUE comment='Revenue from Sponsor ticket purchases',
		CUSTOMER_360.CUST_SUITE_REV as customer_360.SUITE_REVENUE comment='Revenue from Suite ticket purchases',
		CUSTOMER_360.CUST_TICKET_REV as customer_360.TOTAL_TICKET_REVENUE comment='Total actual ticket purchase revenue for this customer across all seasons',
		CUSTOMER_360.CUST_WON_OPP_COUNT as customer_360.WON_OPPORTUNITIES comment='Total number of won CRM opportunities for this customer',
		-- ===== DEAL_HEALTH facts (unchanged) =====
		DEAL_HEALTH.HEALTH_SCORE_VALUE as deal_health.HEALTH_SCORE comment='AI-calculated health score (0-100)',
		-- ===== EMAIL_ANALYTICS facts (unchanged) =====
		EMAIL_ANALYTICS.EMAIL_RESPONSE_MINUTES as email_analytics.RESPONSE_MINUTES comment='Minutes until first inbound response to this outbound email. NULL if no response within 30 days.',
		EMAIL_ANALYTICS.EMAIL_SENTIMENT as email_analytics.SENTIMENT_SCORE comment='Sentiment score for this individual email (-1 to 1)',
		-- ===== OPPORTUNITIES facts (unchanged) =====
		OPPORTUNITIES.DEAL_AMOUNT as opportunities.AMOUNT comment='Revenue amount of the opportunity',
		OPPORTUNITIES.PROBABILITY_PCT as opportunities.PROBABILITY comment='Win probability percentage (0-100)',
		OPPORTUNITIES.WEIGHTED_AMOUNT as opportunities.AMOUNT * (opportunities.PROBABILITY / 100) comment='Probability-weighted revenue (amount x probability)',
		-- ===== CALL_ACTIVITY facts (CORRECTED) =====
		CALL_ACTIVITY.TALK_TIME_SECONDS as TALK_TIME_SECONDS with synonyms=('talk time','speaking time','conversation time','answer time') comment='Actual talk/speaking time in seconds. Matches Tableau dashboard Talk Time metric. For Contact Center uses answer_time; for Zoom Phone uses call_duration.',
		CALL_ACTIVITY.DURATION_SECONDS as DURATION_SECONDS with synonyms=('call length','total duration','full duration') comment='Total call duration in seconds including ring time and wrap-up.'
	)
	dimensions (
		-- ===== ACTIVITY_METRICS dimensions (unchanged) =====
		ACTIVITY_METRICS.ENGAGEMENT_LEVEL as activity_metrics.ENGAGEMENT_LEVEL with synonyms=('activity level','engagement score') comment='Engagement level: High, Medium, or Low',
		ACTIVITY_METRICS.HAS_SENTIMENT_RISK as activity_metrics.HAS_SENTIMENT_RISK with synonyms=('negative sentiment flag','sentiment risk') comment='Whether the opportunity has negative email sentiment (risk indicator)',
		ACTIVITY_METRICS.IS_GHOSTED_FLAG as activity_metrics.IS_GHOSTED with synonyms=('ghosted status','no recent contact') comment='Whether opportunity has had no contact for 60+ days',
		-- ===== CUSTOMER_360 dimensions (unchanged) =====
		CUSTOMER_360.ACCOUNT_BILLING_CITY as customer_360.BILLING_CITY with synonyms=('city','customer city') comment='Billing city of the customer account',
		CUSTOMER_360.ACCOUNT_BILLING_STATE as customer_360.BILLING_STATE with synonyms=('customer state','state') comment='Billing state of the customer account',
		CUSTOMER_360.ACCOUNT_NAME as customer_360.SF_ACCOUNT_NAME with synonyms=('account name','client name','customer name','patron name') comment='Salesforce account name for the customer',
		CUSTOMER_360.CHURN_RISK as customer_360.CHURN_RISK_FLAG with synonyms=('at risk of churning','churn risk','retention risk') comment='Whether the customer is at risk of churning',
		CUSTOMER_360.CUSTOMER_SEGMENT as customer_360.CUSTOMER_SEGMENT with synonyms=('customer classification','customer type','segment') comment='Customer segment: CRM + Purchaser, CRM Only, Direct Purchaser, or Prospect.',
		CUSTOMER_360.HAS_BOTH as customer_360.HAS_CRM_AND_PURCHASES with synonyms=('attributed customer','fully tracked customer','has CRM and purchases') comment='Whether the customer has both CRM opportunities AND actual ticket purchases',
		CUSTOMER_360.LOYAL_FLAG as customer_360.IS_LOYAL_CUSTOMER with synonyms=('loyal customer','multi-season buyer','repeat buyer') comment='Whether the customer has purchased tickets in 3 or more seasons',
		CUSTOMER_360.PERSON_ACCOUNT as customer_360.IS_PERSON_ACCOUNT with synonyms=('individual','person account','person vs business') comment='Whether this is a person account vs business account',
		CUSTOMER_360.PURCHASE_SEASON_LIST as customer_360.PURCHASE_SEASONS with synonyms=('active seasons','seasons purchased') comment='Comma-separated list of seasons the customer has purchased tickets for',
		CUSTOMER_360.RECENCY_TIER as customer_360.RECENCY_TIER with synonyms=('activity recency','engagement recency','last purchase recency','recency') comment='Recency tier based on days since last purchase: Active, Recent, Lapsed, Dormant, No Purchases',
		CUSTOMER_360.REVENUE_TIER as customer_360.REVENUE_TIER with synonyms=('customer tier','customer value','revenue level','value tier') comment='Revenue tier based on total ticket purchases: Platinum ($50K+), Gold ($10K-$50K), Silver ($1K-$10K), Bronze (<$1K), No Revenue',
		CUSTOMER_360.TICKET_TYPES as customer_360.TICKET_TYPES_PURCHASED with synonyms=('products purchased','ticket types bought') comment='Comma-separated list of ticket types the customer has purchased',
		CUSTOMER_360.UPSELL_FLAG as customer_360.UPSELL_CANDIDATE with synonyms=('upsell candidate','upsell opportunity','upsell potential') comment='Whether the customer is an upsell candidate',
		-- ===== DEAL_HEALTH dimensions (unchanged) =====
		DEAL_HEALTH.HEALTH_CATEGORY as deal_health.HEALTH_CATEGORY with synonyms=('deal health','health status','risk level') comment='Health category: Healthy, At Risk, or Critical',
		DEAL_HEALTH.IS_AT_RISK as (deal_health.HEALTH_CATEGORY IN ('At Risk', 'Critical')) with synonyms=('at risk flag','risky deals') comment='Boolean flag for at-risk opportunities',
		-- ===== EMAIL_ANALYTICS dimensions (unchanged) =====
		EMAIL_ANALYTICS.EMAIL_DAY as email_analytics.EMAIL_DAY_NAME with synonyms=('day of week','weekday') comment='Day of week the email was sent (Monday through Sunday)',
		EMAIL_ANALYTICS.EMAIL_DIR as email_analytics.EMAIL_DIRECTION with synonyms=('email type','inbound outbound','sent or received') comment='Whether the email was Inbound (received) or Outbound (sent by rep)',
		EMAIL_ANALYTICS.EMAIL_HOUR_OF_DAY as email_analytics.EMAIL_HOUR with synonyms=('hour of day','hour sent','time sent') comment='Hour of day (0-23) when the email was sent',
		EMAIL_ANALYTICS.EMAIL_OPP_NAME as email_analytics.OPPORTUNITY_NAME with synonyms=('email opportunity','related opportunity') comment='Name of the opportunity this email is associated with',
		EMAIL_ANALYTICS.EMAIL_REP as email_analytics.REP_NAME with synonyms=('email sender','emailing rep','who sent') comment='Name of the rep associated with this email (sender for outbound, opportunity owner for inbound)',
		EMAIL_ANALYTICS.EMAIL_RESPONSE_BUCKET as email_analytics.RESPONSE_TIME_BUCKET with synonyms=('how fast responded','reply time','response speed') comment='Response time category: Within 1 Hour, Within 4 Hours, Within 24 Hours, Within 3 Days, Over 3 Days, No Response',
		EMAIL_ANALYTICS.EMAIL_SEND_DATE as email_analytics.EMAIL_DATE with synonyms=('email date','message date','send date') comment='Date the email was sent or received',
		EMAIL_ANALYTICS.EMAIL_SENT_CATEGORY as email_analytics.SENTIMENT_CATEGORY with synonyms=('email sentiment','email tone') comment='Sentiment category of this email: Positive, Neutral, Slightly Negative, or Negative',
		EMAIL_ANALYTICS.EMAIL_SUBJECT as email_analytics.SUBJECT with synonyms=('email subject','subject line') comment='Subject line of the email',
		EMAIL_ANALYTICS.EMAIL_TIME_BUCKET as email_analytics.TIME_OF_DAY_BUCKET with synonyms=('outreach time','send time window','time of day') comment='Time of day bucket: Early Morning (6-9am), Morning (9am-12pm), Lunch (12-2pm), Afternoon (2-5pm), Evening (5-8pm), Off Hours',
		EMAIL_ANALYTICS.EMAIL_TIMESTAMP as email_analytics.MESSAGE_DATE with synonyms=('email timestamp','exact send time') comment='Exact timestamp when email was sent or received',
		-- ===== OPPORTUNITIES dimensions (unchanged) =====
		OPPORTUNITIES.CLOSE_DATE as opportunities.CLOSE_DATE with synonyms=('close date','expected close') comment='Expected close date for the opportunity',
		OPPORTUNITIES.CLOSE_MONTH as DATE_TRUNC('MONTH', opportunities.CLOSE_DATE) with synonyms=('closing month') comment='Month when the opportunity is expected to close',
		OPPORTUNITIES.CLOSE_QUARTER as DATE_TRUNC('QUARTER', opportunities.CLOSE_DATE) with synonyms=('closing quarter') comment='Quarter when the opportunity is expected to close',
		OPPORTUNITIES.CREATED_DATE as opportunities.CREATED_DATE with synonyms=('creation date','date created','opened date','opportunity created') comment='Date when the opportunity was first created in Salesforce',
		OPPORTUNITIES.CREATED_MONTH as DATE_TRUNC('MONTH', opportunities.CREATED_DATE) with synonyms=('creation month','opened month') comment='Month when the opportunity was created',
		OPPORTUNITIES.CREATED_QUARTER as DATE_TRUNC('QUARTER', opportunities.CREATED_DATE) with synonyms=('creation quarter','opened quarter') comment='Quarter when the opportunity was created',
		OPPORTUNITIES.IS_CLOSED as opportunities.IS_CLOSED with synonyms=('closed status') comment='Whether the opportunity is closed (won or lost)',
		OPPORTUNITIES.IS_WON as opportunities.IS_WON with synonyms=('won status') comment='Whether the opportunity was won',
		OPPORTUNITIES.OPP_NAME as opportunities.NAME with synonyms=('deal name','opportunity name') comment='Name of the sales opportunity',
		OPPORTUNITIES.STAGE as opportunities.STAGE_NAME with synonyms=('deal stage','pipeline stage','sales stage') comment='Current stage in the sales pipeline',
		-- ===== TICKET_TEAM_DEPT dimensions (unchanged) =====
		TICKET_TEAM_DEPT.TICKET_DEPARTMENT as ticket_team_dept.DEPARTMENT with synonyms=('corporate partnerships','department','group AEs','member AEs','sales vs service','team type','TSRs') comment='Department code: TICKET_SALES (Group AEs), TICKET_SERVICE (Service Reps), TICKET_MEMBER_AE (Season Member AEs), TICKET_TSR (Ticket Sales Reps), CORPORATE_PARTNERSHIP_SALES (CP Sales)',
		TICKET_TEAM_DEPT.TICKET_REP_NAME as ticket_team_dept.USER_NAME with synonyms=('classified rep name','department rep name') comment='Sales or service rep name from department classification',
		TICKET_TEAM_DEPT.TICKET_TEAM as ticket_team_dept.TEAM with synonyms=('group name','team name','ticket team name') comment='Team display name: Ticket Sales Group Account Executives, Ticket Service, Ticket Account Executive, Ticket Sales Representative, or CP Sales',
		-- ===== USERS dimensions (unchanged) =====
		USERS.IS_ACTIVE as users.IS_ACTIVE with synonyms=('active rep','active user') comment='Whether the sales rep is currently active',
		USERS.REP_EMAIL as users.EMAIL with synonyms=('owner email') comment='Email address of the sales representative',
		USERS.REP_NAME as users.NAME with synonyms=('account executive','owner name','sales rep') comment='Name of the sales representative',
		-- ===== CALL_ACTIVITY dimensions (CORRECTED — matches actual T_CALL_ACTIVITY columns) =====
		CALL_ACTIVITY.CALL_DIRECTION as CALL_DIRECTION with synonyms=('call type','direction','inbound','outbound') comment='Whether the call was Inbound or Outbound. Standardized with INITCAP.',
		CALL_ACTIVITY.CALL_SOURCE as CALL_SOURCE with synonyms=('call system','contact center','zoom phone') comment='Source system: SESSION_HISTORY (Zoom Contact Center) or ZOOM_CALL_LOG (Zoom Phone). Use to distinguish call origin.',
		CALL_ACTIVITY.CALL_CHANNEL as CALL_CHANNEL comment='Communication channel used (Voice, etc.)',
		CALL_ACTIVITY.INTERACTION_TYPE as INTERACTION_TYPE with synonyms=('contact center or phone') comment='Contact Center or Phone — indicates routing method',
		CALL_ACTIVITY.AGENT_NAME as AGENT_NAME with synonyms=('caller name','rep who called','who made the call') comment='Name of the sales rep who made or received the call',
		CALL_ACTIVITY.AGENT_EMAIL as AGENT_EMAIL comment='Email address of the agent',
		CALL_ACTIVITY.AGENT_OWNER_ID as AGENT_OWNER_ID comment='Salesforce User ID of the agent — used for joins to USERS table',
		CALL_ACTIVITY.IS_ACTIVE_SALES_REP as IS_ACTIVE_SALES_REP with synonyms=('active rep','sales rep filter') comment='Whether the agent is an active Ticket Sales profile rep. Use to filter to dashboard-matching rep list.',
		CALL_ACTIVITY.DISPOSITION as DISPOSITION comment='Disposition/outcome of the call from Contact Center sessions',
		CALL_ACTIVITY.CALL_RESULT as CALL_RESULT with synonyms=('call outcome','result') comment='Call result: answered, connected, ring_timeout, no_answer, missed',
		CALL_ACTIVITY.IS_MISSED as IS_MISSED with synonyms=('missed call','unanswered') comment='Whether the call was missed/unanswered',
		CALL_ACTIVITY.IS_TRANSFER as IS_TRANSFER comment='Whether the call was transferred',
		CALL_ACTIVITY.CONSUMER_NAME as CONSUMER_NAME with synonyms=('customer name','fan name','who was called') comment='Name of the customer/consumer on the call',
		CALL_ACTIVITY.CONSUMER_PHONE as CONSUMER_PHONE comment='Phone number of the consumer (E.164 format)',
		CALL_ACTIVITY.CONTACT_PHONE as CONTACT_PHONE comment='Contact phone number from Session History',
		CALL_ACTIVITY.CALLEE_PHONE as CALLEE_PHONE comment='Phone number called (from Zoom Call Log)',
		CALL_ACTIVITY.CALL_NOTES as CALL_NOTES with synonyms=('call notes','notes','what was discussed') comment='Notes logged by the rep during or after the call. Only available for Contact Center sessions where rep logged notes in Salesforce.',
		CALL_ACTIVITY.VOICEMAIL_CONTENT as VOICEMAIL_CONTENT with synonyms=('voicemail','VM') comment='Voicemail content/reference from Zoom Phone calls',
		CALL_ACTIVITY.RECORDING_REFERENCE as RECORDING_REFERENCE comment='URL to the call recording',
		CALL_ACTIVITY.QUEUE_NAME as QUEUE_NAME with synonyms=('call queue','department queue') comment='Contact Center queue name (Ticket Call Center, Season Member Services, etc.)',
		CALL_ACTIVITY.OPPORTUNITY_ID as OPPORTUNITY_ID comment='Linked opportunity ID (via Task → WHAT_ID)',
		CALL_ACTIVITY.ACCOUNT_ID as ACCOUNT_ID comment='Linked account ID (via Task)',
		CALL_ACTIVITY.CONTACT_ID as CONTACT_ID comment='Linked contact ID (via Task)',
		CALL_ACTIVITY.LINKED_TASK_ID as LINKED_TASK_ID comment='Salesforce Task ID linked to this call',
		CALL_ACTIVITY.TASK_SUBJECT as TASK_SUBJECT comment='Subject of the linked Salesforce Task',
		CALL_ACTIVITY.TASK_NOTES as TASK_NOTES comment='Notes from the linked Salesforce Task',
		CALL_ACTIVITY.SESSION_ID as SESSION_ID comment='Unique identifier for the call record',
		CALL_ACTIVITY.RECORD_NAME as RECORD_NAME comment='Salesforce record name',
		CALL_ACTIVITY.ENGAGEMENT_ID as ENGAGEMENT_ID comment='Zoom engagement ID for the call',
		CALL_ACTIVITY.CHANNEL_SOURCE as CHANNEL_SOURCE comment='Channel source detail',
		-- CALL_ACTIVITY time dimensions
		CALL_ACTIVITY.CALL_START_TIME as CALL_START_TIME with synonyms=('call date','call time','when was the call') comment='Date and time when the call started (Eastern Time)',
		CALL_ACTIVITY.CALL_END_TIME as CALL_END_TIME comment='Date and time when the call ended (Eastern Time)',
		CALL_ACTIVITY.CALL_MONTH as DATE_TRUNC('MONTH', CALL_START_TIME) with synonyms=('call month','monthly calls') comment='Month of the call for trend analysis (Eastern Time)',
		CALL_ACTIVITY.CALL_WEEK as DATE_TRUNC('WEEK', CALL_START_TIME) with synonyms=('call week','weekly calls') comment='Week of the call for trend analysis (Eastern Time)',
		CALL_ACTIVITY.CALL_DATE as DATE(CALL_START_TIME) with synonyms=('date of call') comment='Date of the call (no time component, Eastern Time)',
		CALL_ACTIVITY.CREATED_DATE as CREATED_DATE comment='When the Salesforce record was created (Eastern Time)',
		CALL_ACTIVITY.LAST_MODIFIED_DATE as LAST_MODIFIED_DATE comment='When the record was last modified (Eastern Time)',
		CALL_ACTIVITY.LOADED_AT as LOADED_AT comment='When the record was loaded into T_CALL_ACTIVITY'
	)
	metrics (
		-- ===== ACTIVITY_METRICS metrics (unchanged) =====
		ACTIVITY_METRICS.AVG_EMAILS_PER_DEAL as AVG(activity_metrics.total_emails_count) comment='Average number of emails per opportunity',
		ACTIVITY_METRICS.GHOSTED_DEAL_COUNT as COUNT(CASE WHEN activity_metrics.is_ghosted_flag = TRUE THEN 1 END) comment='Number of opportunities with no contact for 60+ days',
		ACTIVITY_METRICS.TOTAL_CALL_VOLUME as SUM(activity_metrics.total_calls_count) comment='Total number of calls across all opportunities',
		ACTIVITY_METRICS.TOTAL_EMAIL_VOLUME as SUM(activity_metrics.total_emails_count) comment='Total number of emails across all opportunities',
		-- ===== CUSTOMER_360 metrics (unchanged) =====
		CUSTOMER_360.AGG_AVG_CONVERSION_DAYS as AVG(customer_360.cust_conversion_days) with synonyms=('average days to convert','avg conversion days','conversion speed','time to purchase') comment='Average number of days from first CRM opportunity creation to first actual ticket purchase',
		CUSTOMER_360.AGG_AVG_EVENTS as AVG(customer_360.cust_events_attended) with synonyms=('average games attended','avg events attended','avg events per customer') comment='Average number of unique events attended per customer',
		CUSTOMER_360.AGG_AVG_LTV as AVG(customer_360.cust_ltv) with synonyms=('average customer value','average lifetime value','average LTV','mean lifetime value') comment='Average estimated lifetime value per customer',
		CUSTOMER_360.AGG_AVG_PURCHASES as AVG(customer_360.cust_purchase_count) with synonyms=('average purchases per customer','avg ticket purchases','avg transactions') comment='Average number of ticket purchases per customer',
		CUSTOMER_360.AGG_CHURN_RISK_COUNT as COUNT(CASE WHEN customer_360.churn_risk = TRUE THEN 1 END) with synonyms=('at risk of churning count','churn risk count','churn risk customers') comment='Number of customers at risk of churning',
		CUSTOMER_360.AGG_CUSTOMER_COUNT as COUNT(customer_360.SF_ACCOUNT_ID) with synonyms=('account count','customer count','number of customers','total customers') comment='Total count of customer accounts',
		CUSTOMER_360.AGG_GROUP_REVENUE as SUM(customer_360.cust_group_rev) with synonyms=('group sales total','group ticket revenue','total group revenue') comment='Total revenue from Group ticket purchases across all customers',
		CUSTOMER_360.AGG_LIFETIME_VALUE as SUM(customer_360.cust_ltv) with synonyms=('combined lifetime value','customer value total','total lifetime value','total LTV') comment='Total estimated lifetime value across all customers',
		CUSTOMER_360.AGG_LOYAL_COUNT as COUNT(CASE WHEN customer_360.loyal_flag = TRUE THEN 1 END) with synonyms=('loyal customer count','loyal customers','multi-season buyers','repeat buyers') comment='Number of loyal customers who purchased in 3+ seasons',
		CUSTOMER_360.AGG_SEASON_TIX_REVENUE as SUM(customer_360.cust_season_tix_rev) with synonyms=('season ticket total','total season ticket revenue','traditional season revenue') comment='Total revenue from Traditional Season ticket purchases across all customers',
		CUSTOMER_360.AGG_SINGLE_GAME_REVENUE as SUM(customer_360.cust_single_game_rev) with synonyms=('individual game revenue','single game total','total single game revenue') comment='Total revenue from Single Game ticket purchases across all customers',
		CUSTOMER_360.AGG_SUITE_REVENUE as SUM(customer_360.cust_suite_rev) with synonyms=('premium seating revenue','suite total','total suite revenue') comment='Total revenue from Suite ticket purchases across all customers',
		CUSTOMER_360.AGG_TICKET_REVENUE as SUM(customer_360.cust_ticket_rev) with synonyms=('actual revenue','purchase revenue','ticket sales revenue','total purchases','total ticket revenue') comment='Total actual ticket purchase revenue across all customers',
		CUSTOMER_360.AGG_UPSELL_COUNT as COUNT(CASE WHEN customer_360.upsell_flag = TRUE THEN 1 END) with synonyms=('upsell candidate count','upsell candidates','upsell opportunities') comment='Number of customers who are upsell candidates',
		-- ===== DEAL_HEALTH metrics (unchanged) =====
		DEAL_HEALTH.AT_RISK_COUNT as COUNT(CASE WHEN deal_health.is_at_risk = TRUE THEN 1 END) comment='Count of at-risk or critical opportunities',
		DEAL_HEALTH.AT_RISK_VALUE as SUM(CASE WHEN deal_health.is_at_risk = TRUE THEN opportunities.deal_amount ELSE 0 END) comment='Total pipeline value of at-risk opportunities',
		DEAL_HEALTH.AVERAGE_HEALTH_SCORE as AVG(deal_health.health_score_value) comment='Average health score across opportunities',
		-- ===== EMAIL_ANALYTICS metrics (unchanged) =====
		EMAIL_ANALYTICS.AVG_RESPONSE_MINUTES as AVG(email_analytics.email_response_minutes) with synonyms=('average response time','avg reply time','mean response time') comment='Average response time in minutes for outbound emails that received a reply within 30 days',
		EMAIL_ANALYTICS.MEDIAN_RESPONSE_MINUTES as MEDIAN(email_analytics.email_response_minutes) with synonyms=('median response time','typical response time') comment='Median response time in minutes — more representative than average as it ignores outliers',
		EMAIL_ANALYTICS.RESPONSE_RATE as (COUNT(CASE WHEN email_analytics.email_response_bucket != 'No Response' AND email_analytics.email_dir = 'Outbound' THEN 1 END) * 100.0) / NULLIF(COUNT(CASE WHEN email_analytics.email_dir = 'Outbound' THEN 1 END), 0) with synonyms=('email response rate','reply rate','response percentage') comment='Percentage of outbound emails that received a response within 30 days',
		EMAIL_ANALYTICS.TOTAL_EMAIL_COUNT as COUNT(email_analytics.EMAIL_ID) with synonyms=('all emails','email count','total emails') comment='Total number of all emails (inbound + outbound)',
		EMAIL_ANALYTICS.TOTAL_EMAILS_RECEIVED as COUNT(CASE WHEN email_analytics.email_dir = 'Inbound' THEN 1 END) with synonyms=('emails received','inbound emails','incoming email count') comment='Total number of inbound emails received',
		EMAIL_ANALYTICS.TOTAL_EMAILS_SENT as COUNT(CASE WHEN email_analytics.email_dir = 'Outbound' THEN 1 END) with synonyms=('emails sent','outbound emails','outgoing email count') comment='Total number of outbound emails sent by reps',
		-- ===== OPPORTUNITIES metrics (unchanged) =====
		OPPORTUNITIES.AVERAGE_DEAL_SIZE as AVG(opportunities.deal_amount) comment='Average opportunity value',
		OPPORTUNITIES.CP_SALES_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'CORPORATE_PARTNERSHIP_SALES' THEN 1 END) with synonyms=('corporate partnership deals','CP opportunities','sponsorship deals') comment='Number of opportunities owned by Corporate Partnership Sales',
		OPPORTUNITIES.CP_SALES_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'CORPORATE_PARTNERSHIP_SALES' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('corporate partnership pipeline','CP pipeline','sponsorship pipeline') comment='Total pipeline value for Corporate Partnership Sales',
		OPPORTUNITIES.LOST_COUNT as SUM(CASE WHEN opportunities.IS_CLOSED = TRUE AND opportunities.IS_WON = FALSE THEN 1 ELSE 0 END) comment='Number of lost opportunities',
		OPPORTUNITIES.MEMBER_AE_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_MEMBER_AE' THEN 1 END) with synonyms=('member AE opportunities','SM AE deals') comment='Number of opportunities owned by Ticket Member AEs',
		OPPORTUNITIES.MEMBER_AE_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_MEMBER_AE' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('member AE pipeline','season member pipeline','SM AE revenue') comment='Total pipeline value for Ticket Member AEs (Season Membership)',
		OPPORTUNITIES.OPPORTUNITY_COUNT as COUNT(opportunities.ID) comment='Total number of opportunities',
		OPPORTUNITIES.TICKET_SALES_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SALES' THEN 1 END) with synonyms=('group AE deals','group AE opportunities') comment='Number of opportunities owned by Ticket Sales Group AEs',
		OPPORTUNITIES.TICKET_SALES_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SALES' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('group AE pipeline','group AE revenue','ticket sales total') comment='Total pipeline value for Ticket Sales Group AEs',
		OPPORTUNITIES.TICKET_SERVICE_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SERVICE' THEN 1 END) with synonyms=('service opportunities','service team deals') comment='Number of opportunities owned by Ticket Service reps',
		OPPORTUNITIES.TICKET_SERVICE_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_SERVICE' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('service pipeline','service team pipeline','ticket service total') comment='Total pipeline value for Ticket Service department',
		OPPORTUNITIES.TOTAL_PIPELINE_VALUE as SUM(opportunities.deal_amount) comment='Total value of all opportunities in the pipeline',
		OPPORTUNITIES.TSR_COUNT as COUNT(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_TSR' THEN 1 END) with synonyms=('TSR deals','TSR opportunities') comment='Number of opportunities owned by TSRs',
		OPPORTUNITIES.TSR_PIPELINE as SUM(CASE WHEN ticket_team_dept.ticket_department = 'TICKET_TSR' THEN opportunities.deal_amount ELSE 0 END) with synonyms=('ticket sales rep pipeline','TSR pipeline','TSR revenue') comment='Total pipeline value for Ticket Sales Representatives (TSRs)',
		OPPORTUNITIES.WEIGHTED_PIPELINE_VALUE as SUM(opportunities.weighted_amount) comment='Total probability-weighted pipeline value',
		OPPORTUNITIES.WIN_RATE_PCT as (SUM(CASE WHEN opportunities.IS_WON = TRUE THEN 1 ELSE 0 END) * 100.0) / NULLIF(SUM(CASE WHEN opportunities.IS_CLOSED = TRUE THEN 1 ELSE 0 END), 0) comment='Win rate percentage',
		OPPORTUNITIES.WON_COUNT as SUM(CASE WHEN opportunities.IS_WON = TRUE THEN 1 ELSE 0 END) comment='Number of won opportunities',
		-- ===== CALL_ACTIVITY metrics (CORRECTED) =====
		CALL_ACTIVITY.TOTAL_CALLS as COUNT(SESSION_ID) with synonyms=('call count','number of calls') comment='Total number of calls',
		CALL_ACTIVITY.INBOUND_CALLS as SUM(CASE WHEN CALL_DIRECTION = 'Inbound' THEN 1 ELSE 0 END) with synonyms=('calls received','incoming calls') comment='Number of inbound calls',
		CALL_ACTIVITY.OUTBOUND_CALLS as SUM(CASE WHEN CALL_DIRECTION = 'Outbound' THEN 1 ELSE 0 END) with synonyms=('calls made','dials','outgoing calls') comment='Number of outbound calls',
		CALL_ACTIVITY.MISSED_CALLS as SUM(CASE WHEN IS_MISSED = TRUE THEN 1 ELSE 0 END) with synonyms=('unanswered calls') comment='Number of missed/unanswered calls',
		CALL_ACTIVITY.AVG_TALK_TIME_SECONDS as AVG(TALK_TIME_SECONDS) with synonyms=('average talk time','avg speaking time') comment='Average talk time in seconds (matches Tableau dashboard)',
		CALL_ACTIVITY.AVG_TALK_TIME_MINUTES as ROUND(AVG(TALK_TIME_SECONDS) / 60.0, 1) with synonyms=('average call length','avg talk minutes') comment='Average talk time in minutes (matches Tableau dashboard)',
		CALL_ACTIVITY.TOTAL_TALK_MINUTES as ROUND(SUM(TALK_TIME_SECONDS) / 60.0, 1) with synonyms=('total talk time','total speaking time') comment='Total talk time in minutes across all calls',
		CALL_ACTIVITY.AVG_CALL_DURATION_SECONDS as AVG(DURATION_SECONDS) comment='Average total call duration in seconds (includes ring/wait)',
		CALL_ACTIVITY.TOTAL_CALL_MINUTES as ROUND(SUM(DURATION_SECONDS) / 60.0, 1) comment='Total call duration in minutes (includes ring/wait)',
		CALL_ACTIVITY.CALLS_WITH_NOTES as SUM(CASE WHEN CALL_NOTES IS NOT NULL THEN 1 ELSE 0 END) with synonyms=('logged calls','noted calls') comment='Number of calls where rep logged notes',
		CALL_ACTIVITY.NOTE_LOGGING_RATE as ROUND(SUM(CASE WHEN CALL_NOTES IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(SESSION_ID), 0), 1) with synonyms=('disposition rate','logging compliance','logging rate') comment='Percentage of calls with notes logged',
		CALL_ACTIVITY.CALLS_LINKED_TO_OPPORTUNITY as SUM(CASE WHEN OPPORTUNITY_ID IS NOT NULL THEN 1 ELSE 0 END) with synonyms=('attributed calls','linked calls') comment='Number of calls linked to an opportunity'
	)
	comment='Semantic view for CRM sales intelligence with Customer 360 and Email Analytics - enables natural language queries about pipeline, deal health, rep performance across 5 departments, customer lifetime value, ticket purchase attribution, customer segmentation, email volume, send time optimization, response time analysis, and call activity metrics.'
	ai_sql_generation '
    When generating SQL:
    1. Always filter for SYSTEM_CURRENT_FLAG = ''Y'' on opportunities table to get current records only
    2. CRITICAL DATE FILTERING - CREATED_DATE, CLOSE_DATE, and MESSAGE_DATE are TIMESTAMP_TZ fields. NEVER use DATE_TRUNC(field) = ''date-string'' as it fails on timestamp comparison. Always use range-based filtering:
       - For this month: field >= DATE_TRUNC(''MONTH'', CURRENT_DATE()) AND field < DATEADD(''MONTH'', 1, DATE_TRUNC(''MONTH'', CURRENT_DATE()))
       - For this quarter: field >= DATE_TRUNC(''QUARTER'', CURRENT_DATE()) AND field < DATEADD(''QUARTER'', 1, DATE_TRUNC(''QUARTER'', CURRENT_DATE()))
       - For this year: field >= DATE_TRUNC(''YEAR'', CURRENT_DATE()) AND field < DATEADD(''YEAR'', 1, DATE_TRUNC(''YEAR'', CURRENT_DATE()))
       - For last month: field >= DATEADD(''MONTH'', -1, DATE_TRUNC(''MONTH'', CURRENT_DATE())) AND field < DATE_TRUNC(''MONTH'', CURRENT_DATE())
       - For a specific month: field >= ''2026-02-01''::TIMESTAMP_NTZ AND field < ''2026-03-01''::TIMESTAMP_NTZ
    3. Round currency values to 2 decimal places
    4. For percentage metrics, multiply by 1 to ensure numeric display
    5. When showing health scores, include the health_category for context
    6. For at-risk queries, focus on health_category IN (''At Risk'', ''Critical'')
    7. For department comparisons, join through users_to_ticket_dept relationship
    8. For Customer 360 queries, use the customer_360 table directly or via the opportunities_to_customer relationship
    9. When asked about actual revenue or ticket sales, use customer_360.total_ticket_revenue (not pipeline amounts)
    10. When asked about lifetime value or LTV, use customer_360.estimated_lifetime_value
    11. For customer segments: CRM + Purchaser, CRM Only, Direct Purchaser, Prospect
    12. For revenue tiers: Platinum ($50K+), Gold ($10K-$50K), Silver ($1K-$10K), Bronze (<$1K), No Revenue
    13. For recency tiers: Active (30 days), Recent (90 days), Lapsed (1 year), Dormant (1+ year), No Purchases
    14. Churn risk customers had purchases but none in 365+ days AND no open opportunities
    15. Upsell candidates buy single game tickets but not season tickets
    16. Department codes: TICKET_SALES = Group AEs (7 reps), TICKET_SERVICE = Service Reps (4 reps), TICKET_MEMBER_AE = Season Member AEs (2 reps), TICKET_TSR = Ticket Sales Reps (4 reps), CORPORATE_PARTNERSHIP_SALES = CP Sales (6 reps)
    17. When asked about Group AEs or group account executives, filter ticket_team_dept.department = ''TICKET_SALES''
    18. When asked about SM AEs or season membership or member AEs, filter ticket_team_dept.department = ''TICKET_MEMBER_AE''
    19. When asked about TSRs or ticket sales reps, filter ticket_team_dept.department = ''TICKET_TSR''
    20. When asked about corporate partnerships or sponsorship sales, filter ticket_team_dept.department = ''CORPORATE_PARTNERSHIP_SALES''
    21. When comparing departments or teams, group by ticket_team_dept.department or ticket_team_dept.team
    22. For email volume questions (how many emails sent, email count by rep), use the EMAIL_ANALYTICS table, NOT activity_metrics
    23. For response time analysis, use email_analytics.response_minutes and response_time_bucket. Filter to email_direction = ''Outbound'' when analyzing response rates
    24. For best time to send or outreach optimization, group by email_analytics.time_of_day_bucket or email_analytics.email_hour and analyze response rates
    25. For best day to send, group by email_analytics.email_day_name and analyze response rates
    26. When filtering emails by date, use email_analytics.email_date with range-based filtering (same rules as rule 2)
    27. For call activity questions, use the CALL_ACTIVITY table. TALK_TIME_SECONDS matches the Tableau dashboard metric. DURATION_SECONDS is total call time including ring/wait.
    28. When filtering calls by date, CALL_START_TIME is in Eastern Time. Use range-based filtering (same rules as rule 2).
    29. To match dashboard call counts, filter IS_ACTIVE_SALES_REP = TRUE and CALL_DIRECTION IN (''Inbound'', ''Outbound'') to exclude internal and null-direction calls.
    30. CALL_SOURCE distinguishes Contact Center (SESSION_HISTORY) from Zoom Phone (ZOOM_CALL_LOG). Most reps have calls in both sources.
  '
	ai_question_categorization '
    Question Classification Rules:
    
    ANSWERABLE questions about:
    - Pipeline value, stage, or close dates
    - Deal health, risk levels, or engagement
    - Sales rep performance or activity metrics
    - Win rates, conversion metrics
    - Email volume, emails sent or received by rep or department
    - Best time of day or day of week to send emails
    - Response times and response rates
    - Department comparisons across all 5 teams (Group AEs, Service, Member AEs, TSRs, CP Sales)
    - Individual rep performance by name
    - Customer lifetime value, revenue tiers, customer segments
    - Ticket purchase revenue, actual sales vs pipeline
    - Churn risk, upsell candidates, loyal customers
    - Customer conversion analysis (opportunity to purchase)
    - Revenue by ticket type (season tickets, single game, suite, group)
    - Customer recency and engagement patterns
    - Corporate partnership pipeline and performance
    - Call activity: total calls, inbound vs outbound, talk time, call duration by rep
    - Call notes and what was discussed on calls
    - Missed calls, note logging rates, calls linked to opportunities
    - Weekly and monthly call trends
    
    CLARIFICATION NEEDED for vague questions like:
    - Show me deals without time frame or filters
    - How are we doing without specific metrics
    - Show me customers without segment or tier filter
    Ask user to specify: which metric, which time period, or which segment'
	with extension (CA='{"tables":[{"name":"ACTIVITY_METRICS","dimensions":[{"name":"ENGAGEMENT_LEVEL"},{"name":"HAS_SENTIMENT_RISK"},{"name":"IS_GHOSTED_FLAG"}],"facts":[{"name":"AVG_SENTIMENT_SCORE"},{"name":"DAYS_SINCE_CONTACT"},{"name":"TOTAL_CALLS_COUNT"},{"name":"TOTAL_EMAILS_COUNT"}],"metrics":[{"name":"AVG_EMAILS_PER_DEAL"},{"name":"GHOSTED_DEAL_COUNT"},{"name":"TOTAL_CALL_VOLUME"},{"name":"TOTAL_EMAIL_VOLUME"}]},{"name":"CUSTOMER_360","dimensions":[{"name":"ACCOUNT_BILLING_CITY"},{"name":"ACCOUNT_BILLING_STATE"},{"name":"ACCOUNT_NAME"},{"name":"CHURN_RISK"},{"name":"CUSTOMER_SEGMENT"},{"name":"HAS_BOTH"},{"name":"LOYAL_FLAG"},{"name":"PERSON_ACCOUNT"},{"name":"PURCHASE_SEASON_LIST"},{"name":"RECENCY_TIER"},{"name":"REVENUE_TIER"},{"name":"TICKET_TYPES"},{"name":"UPSELL_FLAG"}],"facts":[{"name":"CUST_CONVERSION_DAYS"},{"name":"CUST_CRM_WON_REV"},{"name":"CUST_DAYS_SINCE_PURCHASE"},{"name":"CUST_EVENTS_ATTENDED"},{"name":"CUST_FLEX_REV"},{"name":"CUST_GROUP_REV"},{"name":"CUST_LTV"},{"name":"CUST_OPP_COUNT"},{"name":"CUST_PURCHASE_COUNT"},{"name":"CUST_SEASON_TIX_REV"},{"name":"CUST_SEASONS_COUNT"},{"name":"CUST_SINGLE_GAME_REV"},{"name":"CUST_SPONSOR_REV"},{"name":"CUST_SUITE_REV"},{"name":"CUST_TICKET_REV"},{"name":"CUST_WON_OPP_COUNT"}],"metrics":[{"name":"AGG_AVG_CONVERSION_DAYS"},{"name":"AGG_AVG_EVENTS"},{"name":"AGG_AVG_LTV"},{"name":"AGG_AVG_PURCHASES"},{"name":"AGG_CHURN_RISK_COUNT"},{"name":"AGG_CUSTOMER_COUNT"},{"name":"AGG_GROUP_REVENUE"},{"name":"AGG_LIFETIME_VALUE"},{"name":"AGG_LOYAL_COUNT"},{"name":"AGG_SEASON_TIX_REVENUE"},{"name":"AGG_SINGLE_GAME_REVENUE"},{"name":"AGG_SUITE_REVENUE"},{"name":"AGG_TICKET_REVENUE"},{"name":"AGG_UPSELL_COUNT"}]},{"name":"DEAL_HEALTH","dimensions":[{"name":"HEALTH_CATEGORY"},{"name":"IS_AT_RISK"}],"facts":[{"name":"HEALTH_SCORE_VALUE"}],"metrics":[{"name":"AT_RISK_COUNT"},{"name":"AT_RISK_VALUE"},{"name":"AVERAGE_HEALTH_SCORE"}]},{"name":"EMAIL_ANALYTICS","dimensions":[{"name":"EMAIL_DAY"},{"name":"EMAIL_DIR"},{"name":"EMAIL_HOUR_OF_DAY"},{"name":"EMAIL_OPP_NAME"},{"name":"EMAIL_REP"},{"name":"EMAIL_RESPONSE_BUCKET"},{"name":"EMAIL_SEND_DATE"},{"name":"EMAIL_SENT_CATEGORY"},{"name":"EMAIL_SUBJECT"},{"name":"EMAIL_TIME_BUCKET"},{"name":"EMAIL_TIMESTAMP"}],"facts":[{"name":"EMAIL_RESPONSE_MINUTES"},{"name":"EMAIL_SENTIMENT"}],"metrics":[{"name":"AVG_RESPONSE_MINUTES"},{"name":"MEDIAN_RESPONSE_MINUTES"},{"name":"RESPONSE_RATE"},{"name":"TOTAL_EMAIL_COUNT"},{"name":"TOTAL_EMAILS_RECEIVED"},{"name":"TOTAL_EMAILS_SENT"}]},{"name":"OPPORTUNITIES","dimensions":[{"name":"CLOSE_DATE"},{"name":"CLOSE_MONTH"},{"name":"CLOSE_QUARTER"},{"name":"CREATED_DATE"},{"name":"CREATED_MONTH"},{"name":"CREATED_QUARTER"},{"name":"IS_CLOSED"},{"name":"IS_WON"},{"name":"OPP_NAME"},{"name":"STAGE"}],"facts":[{"name":"DEAL_AMOUNT"},{"name":"PROBABILITY_PCT"},{"name":"WEIGHTED_AMOUNT"}],"metrics":[{"name":"AVERAGE_DEAL_SIZE"},{"name":"CP_SALES_COUNT"},{"name":"CP_SALES_PIPELINE"},{"name":"LOST_COUNT"},{"name":"MEMBER_AE_COUNT"},{"name":"MEMBER_AE_PIPELINE"},{"name":"OPPORTUNITY_COUNT"},{"name":"TICKET_SALES_COUNT"},{"name":"TICKET_SALES_PIPELINE"},{"name":"TICKET_SERVICE_COUNT"},{"name":"TICKET_SERVICE_PIPELINE"},{"name":"TOTAL_PIPELINE_VALUE"},{"name":"TSR_COUNT"},{"name":"TSR_PIPELINE"},{"name":"WEIGHTED_PIPELINE_VALUE"},{"name":"WIN_RATE_PCT"},{"name":"WON_COUNT"}],"filters":[{"name":"CURRENT_RECORDS_ONLY","description":"Filters to current record versions only","expr":"SYSTEM_CURRENT_FLAG = ''Y''"}]},{"name":"TICKET_TEAM_DEPT","dimensions":[{"name":"TICKET_DEPARTMENT"},{"name":"TICKET_REP_NAME"},{"name":"TICKET_TEAM"}]},{"name":"USERS","dimensions":[{"name":"IS_ACTIVE"},{"name":"REP_EMAIL"},{"name":"REP_NAME"}]},{"name":"CALL_ACTIVITY","dimensions":[{"name":"CALL_DIRECTION"},{"name":"CALL_SOURCE"},{"name":"CALL_CHANNEL"},{"name":"INTERACTION_TYPE"},{"name":"AGENT_NAME"},{"name":"AGENT_EMAIL"},{"name":"AGENT_OWNER_ID"},{"name":"IS_ACTIVE_SALES_REP"},{"name":"DISPOSITION"},{"name":"CALL_RESULT"},{"name":"IS_MISSED"},{"name":"IS_TRANSFER"},{"name":"CONSUMER_NAME"},{"name":"CONSUMER_PHONE"},{"name":"CONTACT_PHONE"},{"name":"CALLEE_PHONE"},{"name":"CALL_NOTES"},{"name":"VOICEMAIL_CONTENT"},{"name":"RECORDING_REFERENCE"},{"name":"QUEUE_NAME"},{"name":"OPPORTUNITY_ID"},{"name":"ACCOUNT_ID"},{"name":"CONTACT_ID"},{"name":"LINKED_TASK_ID"},{"name":"TASK_SUBJECT"},{"name":"TASK_NOTES"},{"name":"SESSION_ID"},{"name":"RECORD_NAME"},{"name":"ENGAGEMENT_ID"},{"name":"CHANNEL_SOURCE"},{"name":"CALL_START_TIME"},{"name":"CALL_END_TIME"},{"name":"CALL_MONTH"},{"name":"CALL_WEEK"},{"name":"CALL_DATE"},{"name":"CREATED_DATE"},{"name":"LAST_MODIFIED_DATE"},{"name":"LOADED_AT"}],"facts":[{"name":"TALK_TIME_SECONDS"},{"name":"DURATION_SECONDS"}],"metrics":[{"name":"TOTAL_CALLS"},{"name":"INBOUND_CALLS"},{"name":"OUTBOUND_CALLS"},{"name":"MISSED_CALLS"},{"name":"AVG_TALK_TIME_SECONDS"},{"name":"AVG_TALK_TIME_MINUTES"},{"name":"TOTAL_TALK_MINUTES"},{"name":"AVG_CALL_DURATION_SECONDS"},{"name":"TOTAL_CALL_MINUTES"},{"name":"CALLS_WITH_NOTES"},{"name":"NOTE_LOGGING_RATE"},{"name":"CALLS_LINKED_TO_OPPORTUNITY"}]}],"relationships":[{"name":"EMAILS_TO_OPPORTUNITY"},{"name":"EMAILS_TO_REP"},{"name":"OPPORTUNITIES_TO_ACTIVITY"},{"name":"OPPORTUNITIES_TO_CUSTOMER"},{"name":"OPPORTUNITIES_TO_HEALTH"},{"name":"OPPORTUNITIES_TO_OWNER"},{"name":"USERS_TO_TICKET_DEPT"},{"name":"CALL_TO_OPPORTUNITY"},{"name":"CALL_TO_USER"}],"verified_queries":[{"name":"\\"How many opportunities has a rep started this month?\\"","sql":"SELECT u.NAME AS rep_name, COUNT(o.ID) AS opportunities_started FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u ON o.OWNER_ID = u.ID WHERE o.SYSTEM_CURRENT_FLAG = ''Y'' AND o.CREATED_DATE >= DATE_TRUNC(''MONTH'', CURRENT_DATE()) AND o.CREATED_DATE < DATEADD(''MONTH'', 1, DATE_TRUNC(''MONTH'', CURRENT_DATE())) GROUP BY u.NAME ORDER BY opportunities_started DESC","question":"How many opportunities has a rep started this month?","verified_at":1771448705,"verified_by":"Yuki Taketani","use_as_onboarding_question":false},{"name":"\\"How many opportunities did a rep create in a given month?\\"","sql":"SELECT u.NAME AS rep_name, COUNT(o.ID) AS opportunities_started, MIN(o.CREATED_DATE) AS earliest_created, MAX(o.CREATED_DATE) AS latest_created FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u ON o.OWNER_ID = u.ID WHERE o.SYSTEM_CURRENT_FLAG = ''Y'' AND o.CREATED_DATE >= DATE_TRUNC(''MONTH'', ''2026-01-15''::DATE) AND o.CREATED_DATE < DATEADD(''MONTH'', 1, DATE_TRUNC(''MONTH'', ''2026-01-15''::DATE)) GROUP BY u.NAME ORDER BY opportunities_started DESC","question":"How many opportunities did a rep create in a given month?","verified_at":1771448740,"verified_by":"Yuki Taketani","use_as_onboarding_question":false},{"name":"\\"Compare pipeline value across all departments\\"","sql":"SELECT t.TEAM AS department_name, COUNT(o.ID) AS total_opportunities, SUM(o.AMOUNT) AS total_pipeline, SUM(CASE WHEN o.IS_WON = TRUE THEN 1 ELSE 0 END) AS won_count, SUM(CASE WHEN o.IS_WON = TRUE THEN o.AMOUNT ELSE 0 END) AS won_revenue FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u ON o.OWNER_ID = u.ID JOIN TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING t ON u.ID = t.USER_ID WHERE o.SYSTEM_CURRENT_FLAG = ''Y'' GROUP BY t.TEAM ORDER BY total_pipeline DESC","question":"Compare pipeline value across all departments","verified_at":1771448782,"verified_by":"Yuki Taketani","use_as_onboarding_question":false}]}');

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