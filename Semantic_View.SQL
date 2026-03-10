-- =====================================================
-- Dedup view for V_ODS_SALESFORCE_TASK
-- V_ODS_SALESFORCE_TASK has a known SCD Type 2 data
-- quality issue where multiple SYSTEM_CURRENT_FLAG = 'Y'
-- rows can exist for the same task ID. This view uses
-- QUALIFY to guarantee exactly one row per task ID,
-- taking the highest SYSTEM_VERSION as the winner.
-- Always reference this view (not the raw source) for
-- any task queries to prevent fan-out duplication.
-- =====================================================
CREATE OR REPLACE VIEW TBRDP_DW_PROD.IM_RPT.V_SALESFORCE_TASKS_CURRENT AS
SELECT *
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK
WHERE SYSTEM_CURRENT_FLAG = 'Y'
  AND IS_DELETED = FALSE
QUALIFY ROW_NUMBER() OVER (PARTITION BY ID ORDER BY SYSTEM_VERSION DESC) = 1;

CREATE OR REPLACE SEMANTIC VIEW TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE
	tables (
		OPPORTUNITIES as TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY primary key (ID) with synonyms=('deals','pipeline','sales opportunities') comment='Sales opportunities with revenue, stage, and close dates',
		DEAL_HEALTH as TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE primary key (OPPORTUNITY_ID) with synonyms=('health scores','deal assessment') comment='AI-generated health scores and risk assessments for opportunities',
		ACTIVITY_METRICS as TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS primary key (OPPORTUNITY_ID) with synonyms=('engagement','activities','interactions') comment='Aggregated email, call, and task metrics per opportunity',
		USERS as TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER primary key (ID) with synonyms=('sales reps','account executives','owners') comment='Sales representative details and team information',
		TICKET_TEAM_DEPT as TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING primary key (USER_ID) with synonyms=('ticket team','department classification','sales vs service','group AEs','SM AEs','TSRs','corporate partnerships') comment='Department classification for 23 reps across 5 teams: Ticket Sales Group AEs (7), Ticket Service (4), Ticket Member AEs (2), Ticket Sales Reps/TSRs (4), and Corporate Partnership Sales (6)',
		CUSTOMER_360 as TBRDP_DW_PROD.IM_RPT.T_CUSTOMER_360 primary key (SF_ACCOUNT_ID) with synonyms=('customer intelligence','customer 360','customer profile','customer data','account intelligence','lifetime value','LTV','customer lifetime') comment='Unified customer view linking CRM opportunities to actual ticket purchases. Contains lifetime value, revenue tiers, conversion metrics, churn risk, and purchase history for 371K mapped customers.',
		EMAIL_ANALYTICS as TBRDP_DW_PROD.IM_RPT.T_EMAIL_ANALYTICS primary key (EMAIL_ID) with synonyms=('emails','email activity','email metrics','email volume','outreach','communications','response times') comment='Individual email records with timestamps, direction, rep attribution, sentiment, response time calculations, and time-of-day analysis. Use for email volume counts, send time optimization, and response rate analysis.',
		SALESFORCE_TASKS as TBRDP_DW_PROD.IM_RPT.V_SALESFORCE_TASKS_CURRENT primary key (ID) with synonyms=('tasks','to-dos','follow-ups','action items','salesforce tasks','task list') comment='Individual Salesforce task records, pre-deduplicated for SCD Type 2 safety. Contains due dates (ACTIVITY_DATE), status, type, priority, and foreign keys to opportunities (WHAT_ID) and reps (OWNER_ID). Use for listing tasks by rep, filtering by due date range, or sorting by linked opportunity revenue.',
		CALL_ACTIVITY as TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY primary key (SESSION_ID) with synonyms=('call activity','call data','call log','call metrics','calls','phone activity','phone calls','zoom calls') comment='Unified call activity from Zoom Contact Center (Session History) and Zoom Phone (Call Log). Contains call direction, talk time, duration, agent attribution, notes, and opportunity linkage. All timestamps in Eastern Time to match Tableau dashboard.'
	)
	relationships (
		OPPORTUNITIES_TO_ACTIVITY as OPPORTUNITIES(ID) references ACTIVITY_METRICS(OPPORTUNITY_ID),
		OPPORTUNITIES_TO_CUSTOMER as OPPORTUNITIES(ACCOUNT_ID) references CUSTOMER_360(SF_ACCOUNT_ID),
		OPPORTUNITIES_TO_HEALTH as OPPORTUNITIES(ID) references DEAL_HEALTH(OPPORTUNITY_ID),
		OPPORTUNITIES_TO_OWNER as OPPORTUNITIES(OWNER_ID) references USERS(ID),
		USERS_TO_TICKET_DEPT as USERS(ID) references TICKET_TEAM_DEPT(USER_ID),
		EMAILS_TO_OPPORTUNITY as EMAIL_ANALYTICS(OPPORTUNITY_ID) references OPPORTUNITIES(ID),
		EMAILS_TO_REP as EMAIL_ANALYTICS(REP_USER_ID) references USERS(ID),
		TASKS_TO_OPPORTUNITY as SALESFORCE_TASKS(WHAT_ID) references OPPORTUNITIES(ID),
		TASKS_TO_OWNER as SALESFORCE_TASKS(OWNER_ID) references USERS(ID),
		CALL_TO_OPPORTUNITY as CALL_ACTIVITY(OPPORTUNITY_ID) references OPPORTUNITIES(ID),
		CALL_TO_USER as CALL_ACTIVITY(AGENT_OWNER_ID) references USERS(ID)
	)
	facts (
		OPPORTUNITIES.DEAL_AMOUNT as opportunities.AMOUNT comment='Revenue amount of the opportunity',
		OPPORTUNITIES.WEIGHTED_AMOUNT as opportunities.AMOUNT * (opportunities.PROBABILITY / 100) comment='Probability-weighted revenue (amount x probability)',
		OPPORTUNITIES.PROBABILITY_PCT as opportunities.PROBABILITY comment='Win probability percentage (0-100)',
		DEAL_HEALTH.HEALTH_SCORE_VALUE as deal_health.HEALTH_SCORE comment='AI-calculated health score (0-100)',
		ACTIVITY_METRICS.TOTAL_EMAILS_COUNT as activity_metrics.TOTAL_EMAILS comment='Total email count for this opportunity',
		ACTIVITY_METRICS.TOTAL_CALLS_COUNT as activity_metrics.TOTAL_CALLS comment='Total call count for this opportunity',
		ACTIVITY_METRICS.DAYS_SINCE_CONTACT as activity_metrics.DAYS_SINCE_LAST_EMAIL comment='Number of days since last email contact',
		ACTIVITY_METRICS.AVG_SENTIMENT_SCORE as activity_metrics.AVG_EMAIL_SENTIMENT comment='Average email sentiment score (-1 to 1)',
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
		CUSTOMER_360.CUST_SEASONS_COUNT as customer_360.SEASONS_PURCHASED comment='Number of different seasons the customer purchased tickets for',
		EMAIL_ANALYTICS.EMAIL_SENTIMENT as email_analytics.SENTIMENT_SCORE comment='Sentiment score for this individual email (-1 to 1)',
		EMAIL_ANALYTICS.EMAIL_RESPONSE_MINUTES as email_analytics.RESPONSE_MINUTES comment='Minutes until first inbound response to this outbound email. NULL if no response within 30 days.',
		CALL_ACTIVITY.TALK_TIME_SECONDS as TALK_TIME_SECONDS with synonyms=('talk time','speaking time','conversation time','answer time') comment='Actual talk/speaking time in seconds. Matches Tableau dashboard Talk Time metric. For Contact Center uses answer_time; for Zoom Phone uses call_duration.',
		CALL_ACTIVITY.DURATION_SECONDS as DURATION_SECONDS with synonyms=('call length','total duration','full duration') comment='Total call duration in seconds including ring time and wrap-up.'
	)
	dimensions (
		OPPORTUNITIES.OPP_NAME as opportunities.NAME with synonyms=('opportunity name','deal name') comment='Name of the sales opportunity',
		OPPORTUNITIES.STAGE as opportunities.STAGE_NAME with synonyms=('sales stage','pipeline stage','deal stage') comment='Current stage in the sales pipeline',
		OPPORTUNITIES.CLOSE_DATE as opportunities.CLOSE_DATE with synonyms=('expected close','close date') comment='Expected close date for the opportunity',
		OPPORTUNITIES.CLOSE_MONTH as DATE_TRUNC('MONTH', opportunities.CLOSE_DATE) with synonyms=('closing month') comment='Month when the opportunity is expected to close',
		OPPORTUNITIES.CLOSE_QUARTER as DATE_TRUNC('QUARTER', opportunities.CLOSE_DATE) with synonyms=('closing quarter') comment='Quarter when the opportunity is expected to close',
		OPPORTUNITIES.CREATED_DATE as opportunities.CREATED_DATE with synonyms=('creation date','opened date','opportunity created','date created') comment='Date when the opportunity was first created in Salesforce',
		OPPORTUNITIES.CREATED_MONTH as DATE_TRUNC('MONTH', opportunities.CREATED_DATE) with synonyms=('creation month','opened month') comment='Month when the opportunity was created',
		OPPORTUNITIES.CREATED_QUARTER as DATE_TRUNC('QUARTER', opportunities.CREATED_DATE) with synonyms=('creation quarter','opened quarter') comment='Quarter when the opportunity was created',
		OPPORTUNITIES.IS_CLOSED as opportunities.IS_CLOSED with synonyms=('closed status') comment='Whether the opportunity is closed (won or lost)',
		OPPORTUNITIES.IS_WON as opportunities.IS_WON with synonyms=('won status') comment='Whether the opportunity was won',
		OPPORTUNITIES.PRIMARY_OBJECTION as opportunities.OBJECTIONS_C with synonyms=('objection','loss reason','why lost','closed lost reason','primary objection') comment='Primary objection or reason the deal was lost. Top values: Neglect Meter, Season Over, Bad Contact/No Response, Financial, Not a Fan, Too Far to Drive, Schedule/Time, Working with another rep. NULL if not recorded.',
		OPPORTUNITIES.SECONDARY_OBJECTION as opportunities.SECONDARY_OBJECTIONS_C with synonyms=('secondary objection','objection detail','loss detail','secondary reason') comment='Secondary objection providing additional detail on why the deal was lost. Examples: Never Answered, Season Over, Bad Phone Number, Not Interested, Stadium location. NULL if not recorded.',
		DEAL_HEALTH.HEALTH_CATEGORY as deal_health.HEALTH_CATEGORY with synonyms=('health status','deal health','risk level') comment='Health category: Healthy, At Risk, or Critical',
		DEAL_HEALTH.IS_AT_RISK as (deal_health.HEALTH_CATEGORY IN ('At Risk', 'Critical')) with synonyms=('at risk flag','risky deals') comment='Boolean flag for at-risk opportunities',
		ACTIVITY_METRICS.ENGAGEMENT_LEVEL as activity_metrics.ENGAGEMENT_LEVEL with synonyms=('activity level','engagement score') comment='Engagement level: High, Medium, or Low',
		ACTIVITY_METRICS.HAS_SENTIMENT_RISK as activity_metrics.HAS_SENTIMENT_RISK with synonyms=('negative sentiment flag','sentiment risk') comment='Whether the opportunity has negative email sentiment (risk indicator)',
		ACTIVITY_METRICS.IS_GHOSTED_FLAG as activity_metrics.IS_GHOSTED with synonyms=('ghosted status','no recent contact') comment='Whether opportunity has had no contact for 60+ days',
		USERS.REP_NAME as users.NAME with synonyms=('sales rep','account executive','owner name') comment='Name of the sales representative',
		USERS.REP_EMAIL as users.EMAIL with synonyms=('owner email') comment='Email address of the sales representative',
		USERS.IS_ACTIVE as users.IS_ACTIVE with synonyms=('active rep','active user') comment='Whether the sales rep is currently active',
		TICKET_TEAM_DEPT.TICKET_DEPARTMENT as ticket_team_dept.DEPARTMENT with synonyms=('department','team type','sales vs service','group AEs','member AEs','TSRs','corporate partnerships') comment='Department code: TICKET_SALES (Group AEs), TICKET_SERVICE (Service Reps), TICKET_MEMBER_AE (Season Member AEs), TICKET_TSR (Ticket Sales Reps), CORPORATE_PARTNERSHIP_SALES (CP Sales)',
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
		CUSTOMER_360.ACCOUNT_BILLING_STATE as customer_360.BILLING_STATE with synonyms=('state','customer state') comment='Billing state of the customer account',
		EMAIL_ANALYTICS.EMAIL_SEND_DATE as email_analytics.EMAIL_DATE with synonyms=('email date','send date','message date') comment='Date the email was sent or received',
		EMAIL_ANALYTICS.EMAIL_TIMESTAMP as email_analytics.MESSAGE_DATE with synonyms=('email timestamp','exact send time') comment='Exact timestamp when email was sent or received',
		EMAIL_ANALYTICS.EMAIL_DIR as email_analytics.EMAIL_DIRECTION with synonyms=('inbound outbound','email type','sent or received') comment='Whether the email was Inbound (received) or Outbound (sent by rep)',
		EMAIL_ANALYTICS.EMAIL_DAY as email_analytics.EMAIL_DAY_NAME with synonyms=('day of week','weekday') comment='Day of week the email was sent (Monday through Sunday)',
		EMAIL_ANALYTICS.EMAIL_HOUR_OF_DAY as email_analytics.EMAIL_HOUR with synonyms=('hour sent','time sent','hour of day') comment='Hour of day (0-23) when the email was sent',
		EMAIL_ANALYTICS.EMAIL_TIME_BUCKET as email_analytics.TIME_OF_DAY_BUCKET with synonyms=('time of day','send time window','outreach time') comment='Time of day bucket: Early Morning (6-9am), Morning (9am-12pm), Lunch (12-2pm), Afternoon (2-5pm), Evening (5-8pm), Off Hours',
		EMAIL_ANALYTICS.EMAIL_RESPONSE_BUCKET as email_analytics.RESPONSE_TIME_BUCKET with synonyms=('response speed','reply time','how fast responded') comment='Response time category: Within 1 Hour, Within 4 Hours, Within 24 Hours, Within 3 Days, Over 3 Days, No Response',
		EMAIL_ANALYTICS.EMAIL_REP as email_analytics.REP_NAME with synonyms=('email sender','who sent','emailing rep') comment='Name of the rep associated with this email (sender for outbound, opportunity owner for inbound)',
		EMAIL_ANALYTICS.EMAIL_SENT_CATEGORY as email_analytics.SENTIMENT_CATEGORY with synonyms=('email tone','email sentiment') comment='Sentiment category of this email: Positive, Neutral, Slightly Negative, or Negative',
		EMAIL_ANALYTICS.EMAIL_OPP_NAME as email_analytics.OPPORTUNITY_NAME with synonyms=('related opportunity','email opportunity') comment='Name of the opportunity this email is associated with',
		EMAIL_ANALYTICS.EMAIL_SUBJECT as email_analytics.SUBJECT with synonyms=('email subject','subject line') comment='Subject line of the email',
		SALESFORCE_TASKS.TASK_SUBJECT as salesforce_tasks.SUBJECT with synonyms=('task name','task title','task subject') comment='Subject/title of the Salesforce task',
		SALESFORCE_TASKS.TASK_STATUS as salesforce_tasks.STATUS with synonyms=('task status','completion status') comment='Task status: Completed, In Progress, Not Started',
		SALESFORCE_TASKS.TASK_TYPE as salesforce_tasks.TYPE with synonyms=('task type','activity type','call task','meeting task') comment='Type of task: Call, Email, Meeting, Task',
		SALESFORCE_TASKS.TASK_PRIORITY as salesforce_tasks.PRIORITY with synonyms=('task priority','urgency','high priority tasks') comment='Priority level of the task: High, Normal, Low',
		SALESFORCE_TASKS.TASK_DUE_DATE as salesforce_tasks.ACTIVITY_DATE with synonyms=('due date','task due date','activity date','scheduled date','when due') comment='Scheduled due date for the task. This is a DATE field — use direct date comparisons, not TIMESTAMP casting.',
		SALESFORCE_TASKS.TASK_IS_CLOSED as salesforce_tasks.IS_CLOSED with synonyms=('task closed','completed flag','is complete') comment='Whether the task is closed/completed (boolean)',
		SALESFORCE_TASKS.TASK_CALL_DISPOSITION as salesforce_tasks.CALL_DISPOSITION with synonyms=('task call outcome','task disposition','salesforce task result') comment='Call disposition/outcome for phone call type tasks (Salesforce Task field)',
		SALESFORCE_TASKS.TASK_DESCRIPTION as salesforce_tasks.DESCRIPTION with synonyms=('task notes','task details','task description','task body') comment='Detailed description or notes entered on the task',
		CALL_ACTIVITY.CALL_DIRECTION as CALL_DIRECTION with synonyms=('call type','direction','inbound','outbound') comment='Whether the call was Inbound or Outbound. Standardized with INITCAP.',
		CALL_ACTIVITY.CALL_SOURCE as CALL_SOURCE with synonyms=('call system','contact center','zoom phone') comment='Source system: SESSION_HISTORY (Zoom Contact Center) or ZOOM_CALL_LOG (Zoom Phone). Use to distinguish call origin.',
		CALL_ACTIVITY.CALL_CHANNEL as CALL_CHANNEL comment='Communication channel used (Voice, etc.)',
		CALL_ACTIVITY.INTERACTION_TYPE as INTERACTION_TYPE with synonyms=('contact center or phone') comment='Contact Center or Phone — indicates routing method',
		CALL_ACTIVITY.AGENT_NAME as AGENT_NAME with synonyms=('caller name','rep who called','who made the call') comment='Name of the sales rep who made or received the call',
		CALL_ACTIVITY.AGENT_EMAIL as AGENT_EMAIL comment='Email address of the agent',
		CALL_ACTIVITY.AGENT_OWNER_ID as AGENT_OWNER_ID comment='Salesforce User ID of the agent — used for joins to USERS table',
		CALL_ACTIVITY.IS_ACTIVE_SALES_REP as IS_ACTIVE_SALES_REP with synonyms=('active sales rep','sales rep filter','dashboard rep filter') comment='Whether the agent is an active Ticket Sales profile rep. Use to filter to dashboard-matching rep list.',
		CALL_ACTIVITY.DISPOSITION as DISPOSITION comment='Disposition/outcome of the call from Contact Center sessions',
		CALL_ACTIVITY.CALL_RESULT as CALL_RESULT with synonyms=('call outcome','call result','result') comment='Call result: answered, connected, ring_timeout, no_answer, missed',
		CALL_ACTIVITY.IS_MISSED as IS_MISSED with synonyms=('missed call','unanswered') comment='Whether the call was missed/unanswered',
		CALL_ACTIVITY.IS_TRANSFER as IS_TRANSFER comment='Whether the call was transferred',
		CALL_ACTIVITY.CONSUMER_NAME as CONSUMER_NAME with synonyms=('consumer name','fan name','who was called') comment='Name of the customer/consumer on the call',
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
		CUSTOMER_360.AGG_GROUP_REVENUE as SUM(customer_360.cust_group_rev) with synonyms=('group sales total','group ticket revenue','total group revenue') comment='Total revenue from Group ticket purchases across all customers',
		EMAIL_ANALYTICS.TOTAL_EMAILS_SENT as COUNT(CASE WHEN email_analytics.email_dir = 'Outbound' THEN 1 END) with synonyms=('emails sent','outbound emails','outgoing email count') comment='Total number of outbound emails sent by reps',
		EMAIL_ANALYTICS.TOTAL_EMAILS_RECEIVED as COUNT(CASE WHEN email_analytics.email_dir = 'Inbound' THEN 1 END) with synonyms=('emails received','inbound emails','incoming email count') comment='Total number of inbound emails received',
		EMAIL_ANALYTICS.TOTAL_EMAIL_COUNT as COUNT(email_analytics.EMAIL_ID) with synonyms=('total emails','all emails','email count') comment='Total number of all emails (inbound + outbound)',
		EMAIL_ANALYTICS.AVG_RESPONSE_MINUTES as AVG(email_analytics.email_response_minutes) with synonyms=('average response time','mean response time','avg reply time') comment='Average response time in minutes for outbound emails that received a reply within 30 days',
		EMAIL_ANALYTICS.MEDIAN_RESPONSE_MINUTES as MEDIAN(email_analytics.email_response_minutes) with synonyms=('median response time','typical response time') comment='Median response time in minutes — more representative than average as it ignores outliers',
		EMAIL_ANALYTICS.RESPONSE_RATE as (COUNT(CASE WHEN email_analytics.email_response_bucket != 'No Response' AND email_analytics.email_dir = 'Outbound' THEN 1 END) * 100.0) / NULLIF(COUNT(CASE WHEN email_analytics.email_dir = 'Outbound' THEN 1 END), 0) with synonyms=('reply rate','email response rate','response percentage') comment='Percentage of outbound emails that received a response within 30 days',
		SALESFORCE_TASKS.TASK_COUNT as COUNT(salesforce_tasks.ID) comment='Total number of Salesforce tasks',
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
	filters (
		CURRENT_RECORDS_ONLY as OPPORTUNITIES.SYSTEM_CURRENT_FLAG = 'Y' comment='Filter to current SCD Type 2 records only — always apply on opportunity queries'
	)
	comment='Semantic view for CRM sales intelligence — enables natural language queries about pipeline, deal health, rep performance across 5 departments, customer lifetime value, ticket purchase attribution, customer segmentation, email volume, send time optimization, response time analysis, call activity metrics by rep and date, individual Salesforce task queries by rep, due date, and status, and closed lost objection/loss reason analysis.'
	ai_sql_generation $
    When generating SQL:
    1. Always filter for SYSTEM_CURRENT_FLAG = 'Y' on opportunities table to get current records only
    2. CRITICAL DATE FILTERING - CREATED_DATE, CLOSE_DATE, and MESSAGE_DATE are TIMESTAMP_TZ fields. NEVER use DATE_TRUNC(field) = 'date-string' as it fails on timestamp comparison. Always use range-based filtering:
       - For this month: field >= DATE_TRUNC('MONTH', CURRENT_DATE()) AND field < DATEADD('MONTH', 1, DATE_TRUNC('MONTH', CURRENT_DATE()))
       - For this quarter: field >= DATE_TRUNC('QUARTER', CURRENT_DATE()) AND field < DATEADD('QUARTER', 1, DATE_TRUNC('QUARTER', CURRENT_DATE()))
       - For this year: field >= DATE_TRUNC('YEAR', CURRENT_DATE()) AND field < DATEADD('YEAR', 1, DATE_TRUNC('YEAR', CURRENT_DATE()))
       - For last month: field >= DATEADD('MONTH', -1, DATE_TRUNC('MONTH', CURRENT_DATE())) AND field < DATE_TRUNC('MONTH', CURRENT_DATE())
       - For a specific month: field >= '2026-02-01'::TIMESTAMP_NTZ AND field < '2026-03-01'::TIMESTAMP_NTZ
    3. Round currency values to 2 decimal places
    4. For percentage metrics, multiply by 1 to ensure numeric display
    5. When showing health scores, include the health_category for context
    6. For at-risk queries, focus on health_category IN ('At Risk', 'Critical')
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
    17. When asked about Group AEs or group account executives, filter ticket_team_dept.department = 'TICKET_SALES'
    18. When asked about SM AEs or season membership or member AEs, filter ticket_team_dept.department = 'TICKET_MEMBER_AE'
    19. When asked about TSRs or ticket sales reps, filter ticket_team_dept.department = 'TICKET_TSR'
    20. When asked about corporate partnerships or sponsorship sales, filter ticket_team_dept.department = 'CORPORATE_PARTNERSHIP_SALES'
    21. When comparing departments or teams, group by ticket_team_dept.department or ticket_team_dept.team
    22. For email volume questions (how many emails sent, email count by rep), use the EMAIL_ANALYTICS table, NOT activity_metrics
    23. For response time analysis, use email_analytics.response_minutes and response_time_bucket. Filter to email_direction = 'Outbound' when analyzing response rates
    24. For best time to send or outreach optimization, group by email_analytics.time_of_day_bucket or email_analytics.email_hour and analyze response rates
    25. For best day to send, group by email_analytics.email_day_name and analyze response rates
    26. When filtering emails by date, use email_analytics.email_date with range-based filtering (same rules as rule 2)
    27. For call activity questions (call counts, talk time, rep call volume), use the CALL_ACTIVITY table directly. TALK_TIME_SECONDS matches the Tableau dashboard metric. DURATION_SECONDS is total call time including ring/wait.
    28. When filtering calls by date, CALL_START_TIME is a TIMESTAMP in Eastern Time. Use range-based filtering (same rules as rule 2): CALL_START_TIME >= DATE_TRUNC('MONTH', CURRENT_DATE()) AND CALL_START_TIME < DATEADD('MONTH', 1, DATE_TRUNC('MONTH', CURRENT_DATE()))
    29. CRITICAL: ALL call count queries MUST filter IS_ACTIVE_SALES_REP = TRUE and CALL_DIRECTION IN ('Inbound', 'Outbound'). NEVER omit these filters. T_CALL_ACTIVITY uses a LEFT JOIN for Session History — records where the agent email did not match an active sales rep are still inserted with IS_ACTIVE_SALES_REP = FALSE, and their AGENT_NAME is still populated from Zoom session data. Without IS_ACTIVE_SALES_REP = TRUE, rep-specific queries (AGENT_NAME ILIKE) will include these orphaned records and overstate counts by 2–6x. Filter by AGENT_NAME for rep-specific queries.
    30. CALL_SOURCE distinguishes Contact Center (SESSION_HISTORY) from Zoom Phone (ZOOM_CALL_LOG). Most reps have calls in both sources — do not filter by source unless the user specifically asks.
    31. TASK QUERIES — salesforce_tasks.ACTIVITY_DATE is a DATE field (not TIMESTAMP). Use direct date comparisons only — do NOT cast to TIMESTAMP:
        - For "last week" (previous calendar week, Sun–Sat): ACTIVITY_DATE >= DATEADD('week', -1, DATE_TRUNC('week', CURRENT_DATE())) AND ACTIVITY_DATE < DATE_TRUNC('week', CURRENT_DATE())
        - For "this week": ACTIVITY_DATE >= DATE_TRUNC('week', CURRENT_DATE()) AND ACTIVITY_DATE < DATEADD('week', 1, DATE_TRUNC('week', CURRENT_DATE()))
        - For "today": ACTIVITY_DATE = CURRENT_DATE()
        - For "overdue" (past due and not yet closed): ACTIVITY_DATE < CURRENT_DATE() AND salesforce_tasks.IS_CLOSED = FALSE
        - For "next 7 days": ACTIVITY_DATE > CURRENT_DATE() AND ACTIVITY_DATE <= DATEADD('day', 7, CURRENT_DATE())
    32. When filtering tasks by rep name, join SALESFORCE_TASKS to USERS via the TASKS_TO_OWNER relationship and filter using: users.NAME ILIKE '%rep name%'
    33. When asked to sort or list tasks by opportunity revenue, join SALESFORCE_TASKS to OPPORTUNITIES via the TASKS_TO_OPPORTUNITY relationship and ORDER BY opportunities.AMOUNT DESC NULLS LAST. Tasks where WHAT_ID IS NULL (no linked opportunity) should appear last.
    34. For task listing queries, always include these columns in the output: salesforce_tasks.SUBJECT, salesforce_tasks.ACTIVITY_DATE, salesforce_tasks.STATUS, salesforce_tasks.PRIORITY, and the linked opportunity NAME and AMOUNT where available.
    35. When asked about loss reasons, why deals were lost, objections, or closed lost analysis, use the PRIMARY_OBJECTION (OBJECTIONS_C) and SECONDARY_OBJECTION (SECONDARY_OBJECTIONS_C) dimensions on the OPPORTUNITIES table. Always filter IS_CLOSED = TRUE AND IS_WON = FALSE when analyzing loss reasons. Note: many older records have NULL objections — filter PRIMARY_OBJECTION IS NOT NULL to exclude unclassified records unless the user wants to see the full picture. Top objection values: Neglect Meter, Season Over, Bad Contact/No Response, Financial, Not a Fan, Too Far to Drive, Schedule/Time, Working with another rep.
  $
	ai_question_categorization $
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
    - Weekly and monthly call trends by rep or team
    - Salesforce tasks by rep name, due date, status, type, or priority
    - Tasks due last week, this week, today, or overdue
    - Task lists sorted by linked opportunity revenue
    - Pending, completed, or overdue task counts by rep
    - Loss reasons, objections, why deals were closed lost
    - Objection breakdown by rep, department, or time period
    - Primary and secondary objection analysis

    CLARIFICATION NEEDED for vague questions like:
    - Show me deals without time frame or filters
    - How are we doing without specific metrics
    - Show me customers without segment or tier filter
    Ask user to specify: which metric, which time period, or which segment
  $;
