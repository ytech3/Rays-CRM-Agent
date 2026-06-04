-- =====================================================================
-- DEPLOY: SV_CRM_SALES_INTELLIGENCE
-- Built from live GET_DDL (preserves SYSTEM_CURRENT filter + verified
-- queries + CA extension). Two corrections applied:
--   1) RESTORES the DEAL_HEALTH table (regression — it was dropped from
--      the live view but T_DEAL_HEALTH_SCORE is still maintained and the
--      agent advertises health-score capabilities). Re-adds the table,
--      OPPORTUNITIES_TO_HEALTH relationship, facts, dimensions, metrics,
--      and CA-extension registration.
--   2) ADDS the ACTIVITY_DATA_LAST_REFRESHED freshness metric on
--      ACTIVITY_DETAIL (in metrics() and CA extension).
-- Run the whole file. Filter + verified queries survive — no GUI re-add.
-- =====================================================================

CREATE OR REPLACE VIEW TBRDP_DW_PROD.IM_RPT.V_SALESFORCE_TASKS_CURRENT AS
SELECT *
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK
WHERE SYSTEM_CURRENT_FLAG = 'Y'
  AND IS_DELETED = FALSE
QUALIFY ROW_NUMBER() OVER (PARTITION BY ID ORDER BY SYSTEM_VERSION DESC) = 1;

CREATE OR REPLACE VIEW TBRDP_DW_PROD.IM_RPT.V_SALESFORCE_USER_CURRENT AS
SELECT *
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER
WHERE SYSTEM_CURRENT_FLAG = 'Y';

create or replace semantic view TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE
    tables (
        ACTIVITY_DETAIL as TBRDP_DW_PROD.IM_RPT.T_DIM_ACTIVITY_SUMMARY primary key (ACTIVITY_KEY) with synonyms=('activity counts','activity detail','activity summary','dimensional activities','rep activities','tableau activities') comment='Individual activity records sourced from the same dimensional model as Tableau "DM Salesforce Activities Prod". Use for COUNTING activities by rep and date range — produces exact Tableau-matching counts. Use COUNT(DISTINCT ACTIVITY_KEY) to match Tableau COUNTD. For email CONTENT analysis use EMAIL_ANALYTICS. For call NOTES use CALL_ACTIVITY.',
        ACTIVITY_METRICS as TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS primary key (OPPORTUNITY_ID) with synonyms=('activities','engagement','interactions') comment='Aggregated email, call, and task metrics per opportunity',
        CALL_ACTIVITY as TBRDP_DW_PROD.IM_RPT.T_CALL_ACTIVITY primary key (SESSION_ID) with synonyms=('call activity','call data','call log','call metrics','calls','phone activity','phone calls','zoom calls') comment='Unified call activity from Zoom Contact Center (Session History) and Zoom Phone (Call Log). Contains call direction, talk time, duration, agent attribution, notes, and opportunity linkage. All timestamps in Eastern Time to match Tableau dashboard.',
        CUSTOMER_360 as TBRDP_DW_PROD.IM_RPT.T_CUSTOMER_360 primary key (SF_ACCOUNT_ID) with synonyms=('account intelligence','customer 360','customer data','customer intelligence','customer lifetime','customer profile','lifetime value','LTV') comment='Unified customer view linking CRM opportunities to actual ticket purchases. Contains lifetime value, revenue tiers, conversion metrics, churn risk, and purchase history for 371K mapped customers.',
        DEAL_HEALTH as TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE primary key (OPPORTUNITY_ID) with synonyms=('health scores','deal assessment') comment='AI-generated health scores and risk assessments for opportunities',
        EMAIL_ANALYTICS as TBRDP_DW_PROD.IM_RPT.T_EMAIL_ANALYTICS primary key (EMAIL_ID) with synonyms=('communications','email activity','email metrics','email volume','emails','outreach','response times') comment='Individual email records with timestamps, direction, rep attribution, sentiment, response time calculations, and time-of-day analysis. Use for email volume counts, send time optimization, and response rate analysis.',
        GAME_ATTENDANCE as TBRDP_DW_PROD.IM_RPT.V_CUSTOMER_GAME_ATTENDANCE primary key (FINANCIAL_PATRON_ACCOUNT_ID) with synonyms=('attendance summary','fan attendance summary','game attendance','games attended summary','win loss record') comment='Aggregated game attendance metrics per customer based on scanned tickets (IS_SCANNED=1). Use for summary stats like total games attended, win percentage, total spend. Covers 2023-2025 seasons.',
        GAME_ATTENDANCE_DETAIL as TBRDP_DW_PROD.IM_RPT.V_CUSTOMER_GAME_ATTENDANCE_DETAIL primary key (FINANCIAL_PATRON_ACCOUNT_ID,GAMEPK) with synonyms=('game dates','game history','individual games','specific games attended','what games','which games') comment='Individual game attendance records with dates, opponents, scores, and outcomes. Use when asking about specific games a customer attended, game dates, or drill-down from summary stats. Scan-based (IS_SCANNED=1), 2023-2025 seasons.',
        OPPORTUNITIES as TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY primary key (ID) with synonyms=('deals','pipeline','sales opportunities') comment='Sales opportunities with revenue, stage, and close dates',
        SALESFORCE_TASKS as TBRDP_DW_PROD.IM_RPT.V_SALESFORCE_TASKS_CURRENT primary key (ID) with synonyms=('action items','follow-ups','salesforce tasks','task list','tasks','to-dos') comment='Individual Salesforce task records, pre-deduplicated for SCD Type 2 safety. Contains due dates (ACTIVITY_DATE), status, type, priority, and foreign keys to opportunities (WHAT_ID) and reps (OWNER_ID). Use for listing tasks by rep, filtering by due date range, or sorting by linked opportunity revenue.',
        TICKET_TEAM_DEPT as TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING primary key (USER_ID) with synonyms=('call center','corporate partnerships','department classification','group AEs','interns','leadership','sales vs service','SM AEs','ticket team','TSRs') comment='Department classification for 43 reps across 8 teams: Ticket Leadership (11), Ticket Sales Group AEs (7), Corporate Partnership Sales (6), Ticket Service (5), Ticket Member AEs (4), Ticket Sales Reps/TSRs (4), Ticket Interns (4), Call Center (2)',
        USERS as TBRDP_DW_PROD.IM_RPT.V_SALESFORCE_USER_CURRENT primary key (ID) with synonyms=('account executives','owners','sales reps') comment='Sales representative details — pre-filtered to current SCD2 records only (SYSTEM_CURRENT_FLAG=Y) to prevent join fan-out'
    )
    relationships (
        ACTIVITY_DETAIL_TO_OPPORTUNITY as ACTIVITY_DETAIL(OPPORTUNITY_ID) references OPPORTUNITIES(ID),
        ACTIVITY_DETAIL_TO_REP as ACTIVITY_DETAIL(REP_USER_ID) references USERS(ID),
        CALL_TO_OPPORTUNITY as CALL_ACTIVITY(OPPORTUNITY_ID) references OPPORTUNITIES(ID),
        CALL_TO_USER as CALL_ACTIVITY(AGENT_OWNER_ID) references USERS(ID),
        CUSTOMER_TO_GAME_ATTENDANCE as CUSTOMER_360(PATRON_ACCOUNT_ID) references GAME_ATTENDANCE(FINANCIAL_PATRON_ACCOUNT_ID),
        EMAILS_TO_OPPORTUNITY as EMAIL_ANALYTICS(OPPORTUNITY_ID) references OPPORTUNITIES(ID),
        EMAILS_TO_REP as EMAIL_ANALYTICS(REP_USER_ID) references USERS(ID),
        OPPORTUNITIES_TO_ACTIVITY as OPPORTUNITIES(ID) references ACTIVITY_METRICS(OPPORTUNITY_ID),
        OPPORTUNITIES_TO_CUSTOMER as OPPORTUNITIES(ACCOUNT_ID) references CUSTOMER_360(SF_ACCOUNT_ID),
        OPPORTUNITIES_TO_HEALTH as OPPORTUNITIES(ID) references DEAL_HEALTH(OPPORTUNITY_ID),
        OPPORTUNITIES_TO_OWNER as OPPORTUNITIES(OWNER_ID) references USERS(ID),
        TASKS_TO_OPPORTUNITY as SALESFORCE_TASKS(WHAT_ID) references OPPORTUNITIES(ID),
        TASKS_TO_OWNER as SALESFORCE_TASKS(OWNER_ID) references USERS(ID),
        USERS_TO_TICKET_DEPT as USERS(ID) references TICKET_TEAM_DEPT(USER_ID)
    )
    facts (
        ACTIVITY_DETAIL.DIM_CALL_DURATION as activity_detail.CALL_DURATION_SECONDS comment='Call duration in seconds from the dimensional model',
        ACTIVITY_METRICS.AVG_SENTIMENT_SCORE as activity_metrics.AVG_EMAIL_SENTIMENT comment='Average email sentiment score (-1 to 1)',
        ACTIVITY_METRICS.DAYS_SINCE_CONTACT as activity_metrics.DAYS_SINCE_LAST_EMAIL comment='Number of days since last email contact',
        ACTIVITY_METRICS.OVERDUE_TASK_COUNT_VALUE as activity_metrics.OVERDUE_TASK_COUNT with synonyms=('late tasks','overdue tasks','past due tasks') comment='Number of open tasks past their due date for this opportunity',
        ACTIVITY_METRICS.TOTAL_ACTIVITIES_COUNT as activity_metrics.TOTAL_ACTIVITIES with synonyms=('activity count','all activities','total activities') comment='Total count of all activities (emails + calls + tasks) for this opportunity. Sourced from dimensional model (v_fact_activities) matching Tableau COUNTD([ACTIVITY_ID]).',
        ACTIVITY_METRICS.TOTAL_CALLS_COUNT as activity_metrics.TOTAL_CALLS comment='Total call count for this opportunity',
        ACTIVITY_METRICS.TOTAL_EMAILS_COUNT as activity_metrics.TOTAL_EMAILS comment='Total email count for this opportunity',
        CALL_ACTIVITY.DURATION_SECONDS as DURATION_SECONDS with synonyms=('call length','full duration','total duration') comment='Total call duration in seconds including ring time and wrap-up.',
        CALL_ACTIVITY.TALK_TIME_SECONDS as TALK_TIME_SECONDS with synonyms=('answer time','conversation time','speaking time','talk time') comment='Actual talk/speaking time in seconds. Matches Tableau dashboard Talk Time metric. For Contact Center uses answer_time; for Zoom Phone uses call_duration.',
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
        DEAL_HEALTH.HEALTH_SCORE_VALUE as deal_health.HEALTH_SCORE comment='AI-calculated health score (0-100)',
        EMAIL_ANALYTICS.EMAIL_RESPONSE_MINUTES as email_analytics.RESPONSE_MINUTES comment='Minutes until first inbound response to this outbound email. NULL if no response within 30 days.',
        EMAIL_ANALYTICS.EMAIL_SENTIMENT as email_analytics.SENTIMENT_SCORE comment='Sentiment score for this individual email (-1 to 1)',
        GAME_ATTENDANCE.AVG_TICKET_PRICE_AMOUNT as game_attendance.AVG_TICKET_PRICE with synonyms=('average ticket price','avg price per ticket') comment='Average ticket price across all attended games',
        GAME_ATTENDANCE.GAMES_ATTENDED_COUNT as game_attendance.GAMES_ATTENDED with synonyms=('attendance count','games attended','number of games') comment='Total number of games attended by this customer based on scanned tickets (IS_SCANNED=1)',
        GAME_ATTENDANCE.LOSSES_ATTENDED as game_attendance.GAMES_LOST with synonyms=('games lost','losses attended','rays losses attended') comment='Number of Rays losses at games this customer attended',
        GAME_ATTENDANCE.TOTAL_TICKET_SPEND_AMOUNT as game_attendance.TOTAL_TICKET_SPEND with synonyms=('game ticket spend','ticket spending','total attendance spend') comment='Total amount spent on tickets for attended games',
        GAME_ATTENDANCE.WIN_PERCENTAGE_ATTENDED as game_attendance.WIN_PCT_ATTENDED with synonyms=('luck factor','win percentage at attended games','win rate attended') comment='Percentage of attended games that were Rays wins (0-100)',
        GAME_ATTENDANCE.WINS_ATTENDED as game_attendance.GAMES_WON with synonyms=('games won','rays wins attended','wins attended') comment='Number of Rays wins at games this customer attended',
        GAME_ATTENDANCE_DETAIL.DETAIL_AWAY_SCORE as game_attendance_detail.AWAY_SCORE comment='Away team score for this game',
        GAME_ATTENDANCE_DETAIL.DETAIL_HOME_SCORE as game_attendance_detail.HOME_SCORE comment='Home team score for this game',
        GAME_ATTENDANCE_DETAIL.DETAIL_SPEND as game_attendance_detail.TICKET_SPEND with synonyms=('game spend','spent on game','ticket cost for game') comment='Amount spent on tickets for this specific game',
        GAME_ATTENDANCE_DETAIL.DETAIL_TICKETS as game_attendance_detail.TICKETS_PURCHASED with synonyms=('how many tickets','tickets bought','tickets for game') comment='Number of tickets purchased for this specific game',
        OPPORTUNITIES.DEAL_AMOUNT as opportunities.AMOUNT comment='Revenue amount of the opportunity',
        OPPORTUNITIES.PROBABILITY_PCT as opportunities.PROBABILITY comment='Win probability percentage (0-100)',
        OPPORTUNITIES.WEIGHTED_AMOUNT as opportunities.AMOUNT * (opportunities.PROBABILITY / 100) comment='Probability-weighted revenue (amount x probability)'
    )
    dimensions (
        ACTIVITY_DETAIL.DIM_ACTIVITY_DATE as activity_detail.ACTIVITY_DATE with synonyms=('activity date','date of activity','dim activity date') comment='Date the activity occurred. Use range-based filtering: ACTIVITY_DATE >= start AND ACTIVITY_DATE <= end.',
        ACTIVITY_DETAIL.DIM_ACTIVITY_STATUS as activity_detail.ACTIVITY_STATUS with synonyms=('activity status','completed open') comment='Activity status: Completed, Open, In Progress.',
        ACTIVITY_DETAIL.DIM_ACTIVITY_SUBTYPE as activity_detail.ACTIVITY_SUBTYPE with synonyms=('activity category','activity subtype','email call task') comment='Activity category: Email, Call, Task, ListEmail. Use for high-level activity breakdowns.',
        ACTIVITY_DETAIL.DIM_ACTIVITY_TYPE as activity_detail.ACTIVITY_TYPE with synonyms=('activity type detail','call inbound outbound','specific activity type') comment='Specific activity type: "Call Inbound", "Call Outbound", "Email", "Task", etc. Use ACTIVITY_TYPE for direction breakdown on calls.',
        ACTIVITY_DETAIL.DIM_EMAIL_INCOMING as activity_detail.EMAIL_INCOMING with synonyms=('email direction dim','inbound outbound email dim') comment='Whether this email was incoming (TRUE) or outgoing (FALSE). Only populated for Email subtype.',
        ACTIVITY_DETAIL.DIM_REP_NAME as activity_detail.REP_NAME with synonyms=('activity owner','activity rep','dim rep name') comment='Name of the rep who owns this activity — from the dimensional model activity owner, matches Tableau attribution.',
        ACTIVITY_METRICS.ENGAGEMENT_LEVEL as activity_metrics.ENGAGEMENT_LEVEL with synonyms=('activity level','engagement score') comment='Engagement level: High, Medium, or Low',
        ACTIVITY_METRICS.HAS_SENTIMENT_RISK as activity_metrics.HAS_SENTIMENT_RISK with synonyms=('negative sentiment flag','sentiment risk') comment='Whether the opportunity has negative email sentiment (risk indicator)',
        ACTIVITY_METRICS.IS_GHOSTED_FLAG as activity_metrics.IS_GHOSTED with synonyms=('ghosted status','no recent contact') comment='Whether opportunity has had no contact for 60+ days',
        ACTIVITY_METRICS.NEXT_TASK_DUE_DATE as activity_metrics.NEXT_TASK_DATE with synonyms=('next due date','next task date','soonest task','upcoming task date') comment='Date of the earliest open task for this opportunity. Use as the primary scheduling signal instead of close date.',
        ACTIVITY_METRICS.NEXT_TASK_NAME as activity_metrics.NEXT_TASK_SUBJECT with synonyms=('next action item','next task subject','upcoming task name') comment='Subject line of the next upcoming or overdue task for this opportunity',
        ACTIVITY_METRICS.TASK_URGENCY_LEVEL as activity_metrics.TASK_URGENCY with synonyms=('overdue status','task priority level','task urgency','upcoming task status') comment='Task urgency category: Overdue (past due, highest priority), Due Today, Next 7 Days, Later, or No Open Tasks. This is the PRIMARY urgency signal — prioritize over close date.',
        CALL_ACTIVITY.ACCOUNT_ID as ACCOUNT_ID comment='Linked account ID (via Task)',
        CALL_ACTIVITY.AGENT_EMAIL as AGENT_EMAIL comment='Email address of the agent',
        CALL_ACTIVITY.AGENT_NAME as AGENT_NAME with synonyms=('caller name','rep who called','who made the call') comment='Name of the sales rep who made or received the call',
        CALL_ACTIVITY.AGENT_OWNER_ID as AGENT_OWNER_ID comment='Salesforce User ID of the agent — used for joins to USERS table',
        CALL_ACTIVITY.CALL_CHANNEL as CALL_CHANNEL comment='Communication channel used (Voice, etc.)',
        CALL_ACTIVITY.CALL_DATE as DATE(CALL_START_TIME) with synonyms=('date of call') comment='Date of the call (no time component, Eastern Time)',
        CALL_ACTIVITY.CALL_DIRECTION as CALL_DIRECTION with synonyms=('call type','direction','inbound','outbound') comment='Whether the call was Inbound or Outbound. Standardized with INITCAP.',
        CALL_ACTIVITY.CALL_END_TIME as CALL_END_TIME comment='Date and time when the call ended (Eastern Time)',
        CALL_ACTIVITY.CALL_MONTH as DATE_TRUNC('MONTH', CALL_START_TIME) with synonyms=('call month','monthly calls') comment='Month of the call for trend analysis (Eastern Time)',
        CALL_ACTIVITY.CALL_NOTES as CALL_NOTES with synonyms=('call notes','notes','what was discussed') comment='Notes logged by the rep during or after the call. Only available for Contact Center sessions where rep logged notes in Salesforce.',
        CALL_ACTIVITY.CALL_RESULT as CALL_RESULT with synonyms=('call outcome','call result','result') comment='Call result: answered, connected, ring_timeout, no_answer, missed',
        CALL_ACTIVITY.CALL_SOURCE as CALL_SOURCE with synonyms=('call system','contact center','zoom phone') comment='Source system: SESSION_HISTORY (Zoom Contact Center) or ZOOM_CALL_LOG (Zoom Phone). Use to distinguish call origin.',
        CALL_ACTIVITY.CALL_START_TIME as CALL_START_TIME with synonyms=('call date','call time','when was the call') comment='Date and time when the call started (Eastern Time)',
        CALL_ACTIVITY.CALL_WEEK as DATEADD('day', -DAYOFWEEK(DATE(CALL_START_TIME)), DATE(CALL_START_TIME)) with synonyms=('call week','weekly calls') comment='Week of the call (Sunday start) for trend analysis (Eastern Time)',
        CALL_ACTIVITY.CALLEE_PHONE as CALLEE_PHONE comment='Phone number called (from Zoom Call Log)',
        CALL_ACTIVITY.CHANNEL_SOURCE as CHANNEL_SOURCE comment='Channel source detail',
        CALL_ACTIVITY.CONSUMER_NAME as CONSUMER_NAME with synonyms=('consumer name','fan name','who was called') comment='Name of the customer/consumer on the call',
        CALL_ACTIVITY.CONSUMER_PHONE as CONSUMER_PHONE comment='Phone number of the consumer (E.164 format)',
        CALL_ACTIVITY.CONTACT_ID as CONTACT_ID comment='Linked contact ID (via Task)',
        CALL_ACTIVITY.CONTACT_PHONE as CONTACT_PHONE comment='Contact phone number from Session History',
        CALL_ACTIVITY.CREATED_DATE as CREATED_DATE comment='When the Salesforce record was created (Eastern Time)',
        CALL_ACTIVITY.DISPOSITION as DISPOSITION comment='Disposition/outcome of the call from Contact Center sessions',
        CALL_ACTIVITY.ENGAGEMENT_ID as ENGAGEMENT_ID comment='Zoom engagement ID for the call',
        CALL_ACTIVITY.INTERACTION_TYPE as INTERACTION_TYPE with synonyms=('contact center or phone') comment='Contact Center or Phone — indicates routing method',
        CALL_ACTIVITY.IS_ACTIVE_SALES_REP as IS_ACTIVE_SALES_REP with synonyms=('active sales rep','dashboard rep filter','sales rep filter') comment='Whether the agent is an active Ticket Sales profile rep. Use to filter to dashboard-matching rep list.',
        CALL_ACTIVITY.IS_MISSED as IS_MISSED with synonyms=('missed call','unanswered') comment='Whether the call was missed/unanswered',
        CALL_ACTIVITY.IS_TRANSFER as IS_TRANSFER comment='Whether the call was transferred',
        CALL_ACTIVITY.LAST_MODIFIED_DATE as LAST_MODIFIED_DATE comment='When the record was last modified (Eastern Time)',
        CALL_ACTIVITY.LINKED_TASK_ID as LINKED_TASK_ID comment='Salesforce Task ID linked to this call',
        CALL_ACTIVITY.LOADED_AT as LOADED_AT comment='When the record was loaded into T_CALL_ACTIVITY',
        CALL_ACTIVITY.OPPORTUNITY_ID as OPPORTUNITY_ID comment='Linked opportunity ID (via Task → WHAT_ID)',
        CALL_ACTIVITY.QUEUE_NAME as QUEUE_NAME with synonyms=('call queue','department queue') comment='Contact Center queue name (Ticket Call Center, Season Member Services, etc.)',
        CALL_ACTIVITY.RECORD_NAME as RECORD_NAME comment='Salesforce record name',
        CALL_ACTIVITY.RECORDING_REFERENCE as RECORDING_REFERENCE comment='URL to the call recording',
        CALL_ACTIVITY.SESSION_ID as SESSION_ID comment='Unique identifier for the call record',
        CALL_ACTIVITY.TASK_NOTES as TASK_NOTES comment='Notes from the linked Salesforce Task',
        CALL_ACTIVITY.TASK_SUBJECT as TASK_SUBJECT comment='Subject of the linked Salesforce Task',
        CALL_ACTIVITY.VOICEMAIL_CONTENT as VOICEMAIL_CONTENT with synonyms=('VM','voicemail') comment='Voicemail content/reference from Zoom Phone calls',
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
        CUSTOMER_360.REVENUE_TIER as customer_360.REVENUE_TIER with synonyms=('customer tier','customer value','revenue level','value tier') comment='Revenue tier based on total ticket purchases: Platinum, Gold, Silver, Bronze, No Revenue',
        CUSTOMER_360.TICKET_TYPES as customer_360.TICKET_TYPES_PURCHASED with synonyms=('products purchased','ticket types bought') comment='Comma-separated list of ticket types the customer has purchased',
        CUSTOMER_360.UPSELL_FLAG as customer_360.UPSELL_CANDIDATE with synonyms=('upsell candidate','upsell opportunity','upsell potential') comment='Whether the customer is an upsell candidate',
        DEAL_HEALTH.DEAL_TASK_URGENCY as deal_health.TASK_URGENCY with synonyms=('deal task urgency','health task urgency') comment='Task urgency for scored deals: Overdue, Due Today, Next 7 Days, Later, or No Open Tasks',
        DEAL_HEALTH.HEALTH_CATEGORY as deal_health.HEALTH_CATEGORY with synonyms=('health status','deal health','risk level') comment='Health category: Healthy, At Risk, or Critical',
        DEAL_HEALTH.IS_AT_RISK as (deal_health.HEALTH_CATEGORY IN ('At Risk', 'Critical')) with synonyms=('at risk flag','risky deals') comment='Boolean flag for at-risk opportunities',
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
        GAME_ATTENDANCE.FIRST_GAME_DATE as game_attendance.FIRST_GAME_DATE with synonyms=('earliest game','first game') comment='Date of the first game this customer attended',
        GAME_ATTENDANCE.LAST_GAME_DATE as game_attendance.LAST_GAME_DATE with synonyms=('last game','latest game','most recent game') comment='Date of the most recent game this customer attended',
        GAME_ATTENDANCE.SEASONS_ATTENDED as game_attendance.SEASONS_ATTENDED with synonyms=('seasons attended list','which seasons attended') comment='Comma-separated list of seasons the customer attended games',
        GAME_ATTENDANCE.SEASONS_COUNT as game_attendance.SEASONS_ATTENDED_COUNT with synonyms=('how many seasons','number of seasons attended') comment='Number of distinct seasons the customer attended games',
        GAME_ATTENDANCE_DETAIL.DETAIL_AWAY_TEAM as game_attendance_detail.AWAY_TEAM with synonyms=('away team','visiting team') comment='Away team abbreviation',
        GAME_ATTENDANCE_DETAIL.DETAIL_EMAIL as game_attendance_detail.EMAIL with synonyms=('fan email','patron email') comment='Email address of the fan who attended',
        GAME_ATTENDANCE_DETAIL.DETAIL_EVENT_NAME as game_attendance_detail.EVENT_NAME with synonyms=('event','game name','matchup name') comment='Name of the event/game (e.g., "Tampa Bay Rays vs. Boston Red Sox")',
        GAME_ATTENDANCE_DETAIL.DETAIL_GAME_DATE as game_attendance_detail.GAME_DATE with synonyms=('date of game','game date','when was the game') comment='Date of the specific game attended',
        GAME_ATTENDANCE_DETAIL.DETAIL_GAME_RESULT as game_attendance_detail.GAME_RESULT with synonyms=('game result','outcome','W or L','win loss') comment='Game result: WIN or LOSS',
        GAME_ATTENDANCE_DETAIL.DETAIL_GAMEPK as game_attendance_detail.GAMEPK with synonyms=('game id','game pk','mlb game id') comment='MLB Game ID — unique identifier for each game',
        GAME_ATTENDANCE_DETAIL.DETAIL_HOME_TEAM as game_attendance_detail.HOME_TEAM with synonyms=('home team') comment='Home team abbreviation',
        GAME_ATTENDANCE_DETAIL.DETAIL_OPPONENT as game_attendance_detail.OPPONENT with synonyms=('opponent','opposing team','versus','who did rays play') comment='Opponent team abbreviation (e.g., BOS, NYY, BAL)',
        GAME_ATTENDANCE_DETAIL.DETAIL_PATRON_NAME as game_attendance_detail.PATRON_ACCOUNT_NAME with synonyms=('customer name for game','fan name','patron name') comment='Name of the fan who attended the game',
        GAME_ATTENDANCE_DETAIL.DETAIL_RAYS_HOME as game_attendance_detail.RAYS_HOME with synonyms=('home game','home or away','rays at home') comment='Whether Rays were the home team for this game',
        GAME_ATTENDANCE_DETAIL.DETAIL_RAYS_WIN as game_attendance_detail.RAYS_WIN with synonyms=('did rays win','rays won','win or loss') comment='Whether Rays won this game (true/false)',
        GAME_ATTENDANCE_DETAIL.DETAIL_SEASON as game_attendance_detail.SEASON_YEAR with synonyms=('game season','season of game','which season') comment='Season year of the game (2023, 2024, 2025)',
        OPPORTUNITIES.CLOSE_DATE as opportunities.CLOSE_DATE with synonyms=('close date','expected close') comment='Expected close date for the opportunity',
        OPPORTUNITIES.CLOSE_MONTH as DATE_TRUNC('MONTH', opportunities.CLOSE_DATE) with synonyms=('closing month') comment='Month when the opportunity is expected to close',
        OPPORTUNITIES.CLOSE_QUARTER as DATE_TRUNC('QUARTER', opportunities.CLOSE_DATE) with synonyms=('closing quarter') comment='Quarter when the opportunity is expected to close',
        OPPORTUNITIES.CREATED_DATE as opportunities.CREATED_DATE with synonyms=('creation date','date created','opened date','opportunity created') comment='Date when the opportunity was first created in Salesforce',
        OPPORTUNITIES.CREATED_MONTH as DATE_TRUNC('MONTH', opportunities.CREATED_DATE) with synonyms=('creation month','opened month') comment='Month when the opportunity was created',
        OPPORTUNITIES.CREATED_QUARTER as DATE_TRUNC('QUARTER', opportunities.CREATED_DATE) with synonyms=('creation quarter','opened quarter') comment='Quarter when the opportunity was created',
        OPPORTUNITIES.IS_CLOSED as opportunities.IS_CLOSED with synonyms=('closed status') comment='Whether the opportunity is closed (won or lost)',
        OPPORTUNITIES.IS_WON as opportunities.IS_WON with synonyms=('won status') comment='Whether the opportunity was won',
        OPPORTUNITIES.OPP_NAME as opportunities.NAME with synonyms=('deal name','opportunity name') comment='Name of the sales opportunity',
        OPPORTUNITIES.PRIMARY_OBJECTION as opportunities.OBJECTIONS_C with synonyms=('closed lost reason','loss reason','objection','primary objection','why lost') comment='Primary objection or reason the deal was lost. Top values: Neglect Meter, Season Over, Bad Contact/No Response, Financial, Not a Fan, Too Far to Drive, Schedule/Time, Working with another rep. NULL if not recorded.',
        OPPORTUNITIES.SECONDARY_OBJECTION as opportunities.SECONDARY_OBJECTIONS_C with synonyms=('loss detail','objection detail','secondary objection','secondary reason') comment='Secondary objection providing additional detail on why the deal was lost. Examples: Never Answered, Season Over, Bad Phone Number, Not Interested, Stadium location. NULL if not recorded.',
        OPPORTUNITIES.STAGE as opportunities.STAGE_NAME with synonyms=('deal stage','pipeline stage','sales stage') comment='Current stage in the sales pipeline',
        SALESFORCE_TASKS.TASK_CALL_DISPOSITION as salesforce_tasks.CALL_DISPOSITION with synonyms=('salesforce task result','task call outcome','task disposition') comment='Call disposition/outcome for phone call type tasks (Salesforce Task field)',
        SALESFORCE_TASKS.TASK_DESCRIPTION as salesforce_tasks.DESCRIPTION with synonyms=('task body','task description','task details','task notes') comment='Detailed description or notes entered on the task',
        SALESFORCE_TASKS.TASK_DUE_DATE as salesforce_tasks.ACTIVITY_DATE with synonyms=('activity date','due date','scheduled date','task due date','when due') comment='Scheduled due date for the task. This is a DATE field — use direct date comparisons, not TIMESTAMP casting.',
        SALESFORCE_TASKS.TASK_IS_CLOSED as salesforce_tasks.IS_CLOSED with synonyms=('completed flag','is complete','task closed') comment='Whether the task is closed/completed (boolean)',
        SALESFORCE_TASKS.TASK_PRIORITY as salesforce_tasks.PRIORITY with synonyms=('high priority tasks','task priority','urgency') comment='Priority level of the task: High, Normal, Low',
        SALESFORCE_TASKS.TASK_STATUS as salesforce_tasks.STATUS with synonyms=('completion status','task status') comment='Task status: Completed, In Progress, Not Started',
        SALESFORCE_TASKS.TASK_SUBJECT as salesforce_tasks.SUBJECT with synonyms=('task name','task subject','task title') comment='Subject/title of the Salesforce task',
        SALESFORCE_TASKS.TASK_TYPE as salesforce_tasks.TYPE with synonyms=('activity type','call task','meeting task','task type') comment='Type of task: Call, Email, Meeting, Task',
        TICKET_TEAM_DEPT.TICKET_DEPARTMENT as ticket_team_dept.DEPARTMENT with synonyms=('call center','corporate partnerships','department','group AEs','interns','leadership','member AEs','sales vs service','team type','TSRs') comment='Department code: TICKET_LEADERSHIP (Leadership/Managers), TICKET_SALES (Group AEs), CORPORATE_PARTNERSHIP_SALES (CP Sales), TICKET_SERVICE (Service Reps), TICKET_MEMBER_AE (Season Member AEs), TICKET_TSR (Ticket Sales Reps), TICKET_INTERN (Interns), CALL_CENTER (Call Center)',
        TICKET_TEAM_DEPT.TICKET_REP_NAME as ticket_team_dept.USER_NAME with synonyms=('classified rep name','department rep name') comment='Sales or service rep name from department classification',
        TICKET_TEAM_DEPT.TICKET_TEAM as ticket_team_dept.TEAM with synonyms=('group name','team name','ticket team name') comment='Team display name: Ticket Leadership, Ticket Sales Group Account Executives, CP Sales, Ticket Service, Ticket Account Executive, Ticket Sales Representative, Ticket Intern, or Call Center',
        USERS.IS_ACTIVE as users.IS_ACTIVE with synonyms=('active rep','active user') comment='Whether the sales rep is currently active',
        USERS.REP_EMAIL as users.EMAIL with synonyms=('owner email') comment='Email address of the sales representative',
        USERS.REP_NAME as users.NAME with synonyms=('account executive','owner name','sales rep') comment='Name of the sales representative'
    )
    metrics (
        ACTIVITY_DETAIL.DIM_INBOUND_CALLS as COUNT(DISTINCT CASE WHEN activity_detail.dim_activity_type = 'Call Inbound' THEN activity_detail.ACTIVITY_KEY END) with synonyms=('dim inbound calls','exact inbound count','tableau inbound calls') comment='Inbound call count matching Tableau.',
        ACTIVITY_DETAIL.DIM_OUTBOUND_CALLS as COUNT(DISTINCT CASE WHEN activity_detail.dim_activity_type = 'Call Outbound' THEN activity_detail.ACTIVITY_KEY END) with synonyms=('dim outbound calls','exact outbound count','tableau outbound calls') comment='Outbound call count matching Tableau.',
        ACTIVITY_DETAIL.DIM_TOTAL_ACTIVITIES as COUNT(DISTINCT activity_detail.ACTIVITY_KEY) with synonyms=('dim total activities','exact activity count','tableau activity count') comment='Total activity count matching Tableau COUNTD. Use this for all rep-level activity counting queries.',
        ACTIVITY_DETAIL.DIM_TOTAL_CALLS as COUNT(DISTINCT CASE WHEN activity_detail.dim_activity_subtype = 'Call' THEN activity_detail.ACTIVITY_KEY END) with synonyms=('dim call count','exact call count','tableau call count') comment='Call count matching Tableau. Use for rep-level call counting.',
        ACTIVITY_DETAIL.DIM_TOTAL_EMAILS as COUNT(DISTINCT CASE WHEN activity_detail.dim_activity_subtype = 'Email' THEN activity_detail.ACTIVITY_KEY END) with synonyms=('dim email count','exact email count','tableau email count') comment='Email count matching Tableau. Use for rep-level email counting.',
        ACTIVITY_DETAIL.DIM_TOTAL_TASKS as COUNT(DISTINCT CASE WHEN activity_detail.dim_activity_subtype = 'Task' THEN activity_detail.ACTIVITY_KEY END) with synonyms=('dim task count','exact task count','tableau task count') comment='Task count matching Tableau.',
        ACTIVITY_DETAIL.ACTIVITY_DATA_LAST_REFRESHED as MAX(activity_detail.LOADED_AT) with synonyms=('activity data last refreshed','when was activity data updated','activity data freshness','data as of','last updated','last refresh') comment='Most recent rebuild time of the activity detail table (T_DIM_ACTIVITY_SUMMARY). Use to report how current the call/email/task activity counts are.',
        ACTIVITY_METRICS.AVG_EMAILS_PER_DEAL as AVG(activity_metrics.total_emails_count) comment='Average number of emails per opportunity',
        ACTIVITY_METRICS.DEALS_WITH_OVERDUE_TASKS as COUNT(CASE WHEN activity_metrics.task_urgency_level = 'Overdue' THEN 1 END) with synonyms=('deals needing attention','opportunities with overdue tasks','overdue task deals') comment='Number of opportunities that have at least one overdue task — highest priority deals',
        ACTIVITY_METRICS.GHOSTED_DEAL_COUNT as COUNT(CASE WHEN activity_metrics.is_ghosted_flag = TRUE THEN 1 END) comment='Number of opportunities with no contact for 60+ days',
        ACTIVITY_METRICS.OVERDUE_TASK_TOTAL as SUM(activity_metrics.overdue_task_count_value) with synonyms=('all overdue tasks','past due task count','total overdue tasks') comment='Total number of overdue tasks across all opportunities',
        ACTIVITY_METRICS.TOTAL_CALL_VOLUME as SUM(activity_metrics.total_calls_count) comment='Total number of calls across all opportunities',
        ACTIVITY_METRICS.TOTAL_EMAIL_VOLUME as SUM(activity_metrics.total_emails_count) comment='Total number of emails across all opportunities',
        CALL_ACTIVITY.AVG_CALL_DURATION_SECONDS as AVG(DURATION_SECONDS) comment='Average total call duration in seconds (includes ring/wait)',
        CALL_ACTIVITY.AVG_TALK_TIME_MINUTES as ROUND(AVG(TALK_TIME_SECONDS) / 60.0, 1) with synonyms=('average call length','avg talk minutes') comment='Average talk time in minutes (matches Tableau dashboard)',
        CALL_ACTIVITY.AVG_TALK_TIME_SECONDS as AVG(TALK_TIME_SECONDS) with synonyms=('average talk time','avg speaking time') comment='Average talk time in seconds (matches Tableau dashboard)',
        CALL_ACTIVITY.CALLS_LINKED_TO_OPPORTUNITY as SUM(CASE WHEN OPPORTUNITY_ID IS NOT NULL THEN 1 ELSE 0 END) with synonyms=('attributed calls','linked calls') comment='Number of calls linked to an opportunity',
        CALL_ACTIVITY.CALLS_WITH_NOTES as SUM(CASE WHEN CALL_NOTES IS NOT NULL THEN 1 ELSE 0 END) with synonyms=('logged calls','noted calls') comment='Number of calls where rep logged notes',
        CALL_ACTIVITY.INBOUND_CALLS as SUM(CASE WHEN CALL_DIRECTION = 'Inbound' THEN 1 ELSE 0 END) with synonyms=('calls received','incoming calls') comment='Number of inbound calls',
        CALL_ACTIVITY.MISSED_CALLS as SUM(CASE WHEN IS_MISSED = TRUE THEN 1 ELSE 0 END) with synonyms=('unanswered calls') comment='Number of missed/unanswered calls',
        CALL_ACTIVITY.NOTE_LOGGING_RATE as ROUND(SUM(CASE WHEN CALL_NOTES IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(SESSION_ID), 0), 1) with synonyms=('disposition rate','logging compliance','logging rate') comment='Percentage of calls with notes logged',
        CALL_ACTIVITY.OUTBOUND_CALLS as SUM(CASE WHEN CALL_DIRECTION = 'Outbound' THEN 1 ELSE 0 END) with synonyms=('calls made','dials','outgoing calls') comment='Number of outbound calls',
        CALL_ACTIVITY.TOTAL_CALL_MINUTES as ROUND(SUM(DURATION_SECONDS) / 60.0, 1) comment='Total call duration in minutes (includes ring/wait)',
        CALL_ACTIVITY.TOTAL_CALLS as COUNT(SESSION_ID) with synonyms=('call count','number of calls') comment='Total number of calls',
        CALL_ACTIVITY.TOTAL_TALK_MINUTES as ROUND(SUM(TALK_TIME_SECONDS) / 60.0, 1) with synonyms=('total speaking time','total talk time') comment='Total talk time in minutes across all calls',
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
        DEAL_HEALTH.AT_RISK_COUNT as COUNT(CASE WHEN deal_health.is_at_risk = TRUE THEN 1 END) comment='Count of at-risk or critical opportunities',
        DEAL_HEALTH.AT_RISK_VALUE as SUM(CASE WHEN deal_health.is_at_risk = TRUE THEN opportunities.deal_amount ELSE 0 END) comment='Total pipeline value of at-risk opportunities',
        DEAL_HEALTH.AVERAGE_HEALTH_SCORE as AVG(deal_health.health_score_value) comment='Average health score across opportunities',
        EMAIL_ANALYTICS.AVG_RESPONSE_MINUTES as AVG(email_analytics.email_response_minutes) with synonyms=('average response time','avg reply time','mean response time') comment='Average response time in minutes for outbound emails that received a reply within 30 days',
        EMAIL_ANALYTICS.MEDIAN_RESPONSE_MINUTES as MEDIAN(email_analytics.email_response_minutes) with synonyms=('median response time','typical response time') comment='Median response time in minutes — more representative than average as it ignores outliers',
        EMAIL_ANALYTICS.RESPONSE_RATE as (COUNT(CASE WHEN email_analytics.email_response_bucket != 'No Response' AND email_analytics.email_dir = 'Outbound' THEN 1 END) * 100.0) / NULLIF(COUNT(CASE WHEN email_analytics.email_dir = 'Outbound' THEN 1 END), 0) with synonyms=('email response rate','reply rate','response percentage') comment='Percentage of outbound emails that received a response within 30 days',
        EMAIL_ANALYTICS.TOTAL_EMAIL_COUNT as COUNT(email_analytics.EMAIL_ID) with synonyms=('all emails','email count','total emails') comment='Total number of all emails (inbound + outbound)',
        EMAIL_ANALYTICS.TOTAL_EMAILS_RECEIVED as COUNT(CASE WHEN email_analytics.email_dir = 'Inbound' THEN 1 END) with synonyms=('emails received','inbound emails','incoming email count') comment='Total number of inbound emails received',
        EMAIL_ANALYTICS.TOTAL_EMAILS_SENT as COUNT(CASE WHEN email_analytics.email_dir = 'Outbound' THEN 1 END) with synonyms=('emails sent','outbound emails','outgoing email count') comment='Total number of outbound emails sent by reps',
        GAME_ATTENDANCE.AVG_GAMES_PER_CUSTOMER as AVG(game_attendance.games_attended_count) with synonyms=('average games attended','avg games per fan') comment='Average games attended per customer',
        GAME_ATTENDANCE.AVG_WIN_PCT_ATTENDED as AVG(game_attendance.win_percentage_attended) with synonyms=('average win percentage','avg win rate attended') comment='Average win percentage at attended games across customers',
        GAME_ATTENDANCE.CUSTOMERS_WITH_HIGH_WIN_PCT as COUNT(CASE WHEN game_attendance.win_percentage_attended >= 60 THEN 1 END) with synonyms=('high win rate fans','lucky customers') comment='Number of customers who attended games with 60%+ Rays win rate',
        GAME_ATTENDANCE.TOTAL_GAME_TICKET_SPEND as SUM(game_attendance.total_ticket_spend_amount) with synonyms=('aggregate game spend','total ticket spend on games') comment='Total ticket spend on attended games across all customers',
        GAME_ATTENDANCE.TOTAL_GAMES_ATTENDED as SUM(game_attendance.games_attended_count) with synonyms=('aggregate games attended','total games attended') comment='Total games attended across all customers',
        GAME_ATTENDANCE.TOTAL_LOSSES_ATTENDED as SUM(game_attendance.losses_attended) with synonyms=('aggregate losses','total losses attended') comment='Total Rays losses attended across all customers',
        GAME_ATTENDANCE.TOTAL_WINS_ATTENDED as SUM(game_attendance.wins_attended) with synonyms=('aggregate wins','total wins attended') comment='Total Rays wins attended across all customers',
        GAME_ATTENDANCE_DETAIL.DETAIL_GAME_COUNT as COUNT(DISTINCT game_attendance_detail.detail_gamepk) with synonyms=('games in detail','number of game records','unique games') comment='Count of distinct games in attendance detail records',
        GAME_ATTENDANCE_DETAIL.DETAIL_LOSSES_COUNT as COUNT(CASE WHEN game_attendance_detail.detail_rays_win = FALSE THEN 1 END) with synonyms=('detail loss count','losses in detail') comment='Count of Rays losses in game detail records',
        GAME_ATTENDANCE_DETAIL.DETAIL_WINS_COUNT as COUNT(CASE WHEN game_attendance_detail.detail_rays_win = TRUE THEN 1 END) with synonyms=('detail win count','wins in detail') comment='Count of Rays wins in game detail records',
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
        SALESFORCE_TASKS.TASK_COUNT as COUNT(salesforce_tasks.ID) comment='Total number of Salesforce tasks'
    )
    comment='Semantic view for CRM sales intelligence (12 tables) — enables natural language queries about pipeline, deal health scores and at-risk analysis, engagement levels, rep performance across 5 departments, customer lifetime value, ticket purchase attribution, customer segmentation, email volume, send time optimization, response time analysis, call activity metrics by rep and date, individual Salesforce task queries by rep, due date, and status, closed lost objection/loss reason analysis, game attendance metrics (summary and per-game detail with opponents, scores, and outcomes), and Tableau-matching activity counts by rep and date range via ACTIVITY_DETAIL.'
    ai_sql_generation '
    When generating SQL:
    1. Always filter for SYSTEM_CURRENT_FLAG = ''Y'' on the OPPORTUNITIES table AND the USERS table to get current records only. The USERS table (V_SALESFORCE_USER_CURRENT) is already pre-filtered, but OPPORTUNITIES (V_ODS_SALESFORCE_OPPORTUNITY) still requires an explicit WHERE SYSTEM_CURRENT_FLAG = ''Y'' in every query.
    2. CRITICAL DATE FILTERING - CREATED_DATE, CLOSE_DATE, and MESSAGE_DATE are TIMESTAMP_TZ fields. NEVER use DATE_TRUNC(field) = ''date-string'' as it fails on timestamp comparison. Always use range-based filtering:
       - For this month: field >= DATE_TRUNC(''MONTH'', CURRENT_DATE()) AND field < DATEADD(''MONTH'', 1, DATE_TRUNC(''MONTH'', CURRENT_DATE()))
       - For this quarter: field >= DATE_TRUNC(''QUARTER'', CURRENT_DATE()) AND field < DATEADD(''QUARTER'', 1, DATE_TRUNC(''QUARTER'', CURRENT_DATE()))
       - For this year: field >= DATE_TRUNC(''YEAR'', CURRENT_DATE()) AND field < DATEADD(''YEAR'', 1, DATE_TRUNC(''YEAR'', CURRENT_DATE()))
       - For last month: field >= DATEADD(''MONTH'', -1, DATE_TRUNC(''MONTH'', CURRENT_DATE())) AND field < DATE_TRUNC(''MONTH'', CURRENT_DATE())
       - For a specific month: field >= ''2026-02-01''::TIMESTAMP_NTZ AND field < ''2026-03-01''::TIMESTAMP_NTZ
       - WEEK CONVENTION (Sunday–Saturday): Do NOT use DATE_TRUNC(''week'', ...) for weekly filtering — Snowflake defaults to Monday. Instead, always calculate Sunday-based week boundaries using DAYOFWEEK() which returns 0=Sunday, 1=Monday, ..., 6=Saturday:
         * Start of this week (Sunday): DATEADD(''day'', -DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE())
         * End of this week (Saturday night): DATEADD(''day'', 7 - DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE())
         * Start of last week (previous Sunday): DATEADD(''day'', -7 - DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE())
         * For "this week": field >= DATEADD(''day'', -DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE()) AND field < DATEADD(''day'', 7 - DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE())
         * For "last week": field >= DATEADD(''day'', -7 - DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE()) AND field < DATEADD(''day'', -DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE())
         * For TIMESTAMP fields, cast the boundary to TIMESTAMP: field >= DATEADD(''day'', -DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE())::TIMESTAMP_NTZ
         * This applies to ALL tables and ALL date/timestamp fields when filtering by week.
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
    27. For call activity questions (call counts, talk time, rep call volume), use the CALL_ACTIVITY table directly. TALK_TIME_SECONDS matches the Tableau dashboard metric. DURATION_SECONDS is total call time including ring/wait.
    28. When filtering calls by date, CALL_START_TIME is a TIMESTAMP in Eastern Time. Use range-based filtering (same rules as rule 2): CALL_START_TIME >= DATE_TRUNC(''MONTH'', CURRENT_DATE()) AND CALL_START_TIME < DATEADD(''MONTH'', 1, DATE_TRUNC(''MONTH'', CURRENT_DATE()))
    29. CRITICAL — MANDATORY CALL FILTERS: Every query against CALL_ACTIVITY MUST include ALL of these filters:
        a) IS_ACTIVE_SALES_REP = TRUE — excludes orphaned Zoom records not matched to a sales rep
        b) CALL_DIRECTION IN (''Inbound'', ''Outbound'') — excludes system/internal records
        Omitting these filters overstates call counts by 2–6x. When grouping by rep, use AGENT_NAME (not a JOIN to USERS). When the user asks for calls by direction, break out Inbound and Outbound separately.
        Example correct call query:
        SELECT AGENT_NAME, CALL_DIRECTION, COUNT(SESSION_ID) AS total_calls
        FROM call_activity
        WHERE IS_ACTIVE_SALES_REP = TRUE
          AND CALL_DIRECTION IN (''Inbound'', ''Outbound'')
          AND CALL_START_TIME >= [date_range_start]
          AND CALL_START_TIME < [date_range_end]
        GROUP BY AGENT_NAME, CALL_DIRECTION
    30. CALL_SOURCE distinguishes Contact Center (SESSION_HISTORY) from Zoom Phone (ZOOM_CALL_LOG). Most reps have calls in both sources — do not filter by source unless the user specifically asks.
    31. TASK QUERIES — salesforce_tasks.ACTIVITY_DATE is a DATE field (not TIMESTAMP). Use direct date comparisons only — do NOT cast to TIMESTAMP. Use Sunday–Saturday week boundaries (see rule 2 WEEK CONVENTION):
        - For "last week" (previous calendar week, Sun–Sat): ACTIVITY_DATE >= DATEADD(''day'', -7 - DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE()) AND ACTIVITY_DATE < DATEADD(''day'', -DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE())
        - For "this week" (current Sun–Sat): ACTIVITY_DATE >= DATEADD(''day'', -DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE()) AND ACTIVITY_DATE < DATEADD(''day'', 7 - DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE())
        - For "today": ACTIVITY_DATE = CURRENT_DATE()
        - For "overdue" (past due and not yet closed): ACTIVITY_DATE < CURRENT_DATE() AND salesforce_tasks.IS_CLOSED = FALSE
        - For "next 7 days": ACTIVITY_DATE > CURRENT_DATE() AND ACTIVITY_DATE <= DATEADD(''day'', 7, CURRENT_DATE())
    32. When filtering tasks by rep name, join SALESFORCE_TASKS to USERS via the TASKS_TO_OWNER relationship and filter using: users.NAME ILIKE ''%rep name%''
    33. When asked to sort or list tasks by opportunity revenue, join SALESFORCE_TASKS to OPPORTUNITIES via the TASKS_TO_OPPORTUNITY relationship and ORDER BY opportunities.AMOUNT DESC NULLS LAST. Tasks where WHAT_ID IS NULL (no linked opportunity) should appear last.
    34. For task listing queries, always include these columns in the output: salesforce_tasks.SUBJECT, salesforce_tasks.ACTIVITY_DATE, salesforce_tasks.STATUS, salesforce_tasks.PRIORITY, and the linked opportunity NAME and AMOUNT where available.
    35. When asked about loss reasons, why deals were lost, objections, or closed lost analysis, use the PRIMARY_OBJECTION (OBJECTIONS_C) and SECONDARY_OBJECTION (SECONDARY_OBJECTIONS_C) dimensions on the OPPORTUNITIES table. Always filter IS_CLOSED = TRUE AND IS_WON = FALSE when analyzing loss reasons. Note: many older records have NULL objections — filter PRIMARY_OBJECTION IS NOT NULL to exclude unclassified records unless the user wants to see the full picture. Top objection values: Neglect Meter, Season Over, Bad Contact/No Response, Financial, Not a Fan, Too Far to Drive, Schedule/Time, Working with another rep.
    36. GAME ATTENDANCE — For summary-level attendance questions (how many games attended, win percentage, total spend), use the GAME_ATTENDANCE table. For specific game details (which games, opponents, scores, dates), use GAME_ATTENDANCE_DETAIL. Both are linked to CUSTOMER_360 via PATRON_ACCOUNT_ID = FINANCIAL_PATRON_ACCOUNT_ID.
    37. Game attendance data is scan-based (IS_SCANNED=1) covering 2023-2025 seasons. Only customers who physically scanned into the stadium are included.
    38. When filtering game attendance by season, use game_attendance_detail.SEASON_YEAR (e.g., 2024). When filtering by opponent, use game_attendance_detail.OPPONENT with team abbreviations (e.g., ''BOS'', ''NYY'', ''BAL'').
    39. For game results, RAYS_WIN is a boolean and GAME_RESULT is ''WIN'' or ''LOSS''. Use GAME_RESULT for display and RAYS_WIN for boolean filtering.
    40. When asked about a customer''s game history alongside their CRM data, join through CUSTOMER_360 using the CUSTOMER_TO_GAME_ATTENDANCE relationship. GAME_ATTENDANCE_DETAIL shares FINANCIAL_PATRON_ACCOUNT_ID with GAME_ATTENDANCE for drill-down.
    41. ACTIVITY COUNTING (CRITICAL) — For rep-level activity counts by date range (e.g., "how many calls/emails did rep X make this week", "activity breakdown for Brandon Harnick"), ALWAYS use the ACTIVITY_DETAIL table — NOT email_analytics or call_activity. The ACTIVITY_DETAIL table sources from the same dimensional model as Tableau and produces exact-match counts. Use ACTIVITY_TYPE for direction: ''Call Inbound'', ''Call Outbound''. Use ACTIVITY_SUBTYPE for category: ''Email'', ''Call'', ''Task''. Use COUNT(DISTINCT ACTIVITY_KEY) to match Tableau COUNTD. Filter by REP_NAME ILIKE ''%rep name%'' and ACTIVITY_DATE range.
    42. Use EMAIL_ANALYTICS only for email content analysis, response times, sentiment, send-time optimization, and individual email details. Use CALL_ACTIVITY only for call notes, voicemail content, and detailed call session data. For COUNTING activities by rep and date, always use ACTIVITY_DETAIL.
    43. When the user says "emails" in a counting context (how many emails did X send, email count by rep this week), use ACTIVITY_DETAIL with ACTIVITY_SUBTYPE = ''Email''. When they want email content, sentiment, or response times, use EMAIL_ANALYTICS. When they say "calls" in a counting context (how many calls, call volume by rep), use ACTIVITY_DETAIL with ACTIVITY_SUBTYPE = ''Call''. When they want call notes or voicemail content, use CALL_ACTIVITY.
    44. ACTIVITY_DETAIL date filtering — ACTIVITY_DATE is a DATE field. Use direct date comparisons: ACTIVITY_DATE >= ''2026-04-12'' AND ACTIVITY_DATE <= ''2026-04-18''. Do NOT cast to TIMESTAMP.
    45. TASK URGENCY PRIORITIZATION — When asked about "urgent deals", "what needs attention", "priority opportunities", "next actions", "what should I work on", or any prioritization question, use TASK_URGENCY as the PRIMARY urgency signal. Order by task urgency: Overdue first (highest priority), then Due Today, then Next 7 Days. Close date is a SECONDARY consideration — only use it as a tiebreaker within the same urgency tier. For aggregate views, use activity_metrics.TASK_URGENCY. For scored deals, use deal_health.TASK_URGENCY. Example: ORDER BY CASE WHEN activity_metrics.TASK_URGENCY = ''Overdue'' THEN 1 WHEN activity_metrics.TASK_URGENCY = ''Due Today'' THEN 2 WHEN activity_metrics.TASK_URGENCY = ''Next 7 Days'' THEN 3 WHEN activity_metrics.TASK_URGENCY = ''Later'' THEN 4 ELSE 5 END, activity_metrics.NEXT_TASK_DATE ASC NULLS LAST.
    46. When asked about overdue tasks at the opportunity level (aggregated counts, which deals have overdue tasks), use ACTIVITY_METRICS.OVERDUE_TASK_COUNT and ACTIVITY_METRICS.TASK_URGENCY. When asked about individual overdue tasks (list each task), use SALESFORCE_TASKS with filter ACTIVITY_DATE < CURRENT_DATE() AND IS_CLOSED = FALSE.
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
    - Weekly and monthly call trends by rep or team
    - Salesforce tasks by rep name, due date, status, type, or priority
    - Tasks due last week, this week, today, or overdue
    - Task lists sorted by linked opportunity revenue
    - Pending, completed, or overdue task counts by rep
    - Loss reasons, objections, why deals were closed lost
    - Objection breakdown by rep, department, or time period
    - Primary and secondary objection analysis
    - Game attendance: total games attended, win percentage, ticket spend per customer
    - Which games a customer attended, opponents, scores, game dates
    - Game attendance by season, by opponent, home vs away
    - Customer game history alongside CRM and ticket purchase data
    - Fans with high win percentages (lucky customers)
    - Activity counts by rep and date range (exact Tableau-matching via ACTIVITY_DETAIL)
    - How many emails/calls/tasks did a rep make this week/month
    - Activity breakdown by type (Email, Call, Task) and direction (Inbound, Outbound)
    - Task urgency: which deals have overdue tasks, what needs immediate attention
    - Priority-based deal views: deals ordered by task urgency rather than close date
    - Overdue task counts by rep, department, or opportunity
    - Next upcoming task date and subject for opportunities

    CLARIFICATION NEEDED for vague questions like:
    - Show me deals without time frame or filters
    - How are we doing without specific metrics
    - Show me customers without segment or tier filter
    Ask user to specify: which metric, which time period, or which segment'
    ai_verified_queries (
        "Show me all opportunities for a specific campaign with activity metrics, engagement level, and rep details" AS (
QUESTION 'Show me all opportunities for a specific campaign with activity metrics, engagement level, and rep details'
VERIFIED_AT 1778179314
VERIFIED_BY 'Yuki Taketani'
ONBOARDING_QUESTION false
SQL 'SELECT __opportunities.id AS opportunity_id, __opportunities.opp_name AS opportunity_name,
    __opportunities.stage, __users.rep_name, ROUND(__opportunities.deal_amount, 2) AS amount,
    __activity_metrics.engagement_level, __activity_metrics.task_urgency_level,
    __activity_metrics.total_activities_count, __activity_metrics.total_emails_count,
    __activity_metrics.total_calls_count, __activity_metrics.days_since_contact,
    __opportunities.close_date, __customer_360.account_name, __opportunities.created_date
    FROM __opportunities LEFT OUTER JOIN __users ON __opportunities.owner_id = __users.id
    INNER JOIN __activity_metrics ON __opportunities.id = __activity_metrics.opportunity_id
    LEFT OUTER JOIN __customer_360 ON __opportunities.account_id = __customer_360.sf_account_id
    WHERE __opportunities.system_current_flag = ''Y''
    AND __opportunities.opp_name ILIKE ''%campaign_name%''
    AND __opportunities.stage IN (''Initial Conversation'', ''In contact'')
    ORDER BY __users.rep_name, __activity_metrics.days_since_contact DESC'),
        "I want to analyze the TSR performance on the Campaign labeled ""2026 04.14 - VOC Homestand 1: 06-10 Games"".

Specifically, I want to know how all of the opportunities that are in the stage ""Initial Conversation"" or ""In contact"" are progressing.

I want to " AS (
QUESTION 'I want to analyze the TSR performance on the Campaign labeled "2026 04.14 - VOC Homestand 1: 06-10 Games".

Specifically, I want to know how all of the opportunities that are in the stage "Initial Conversation" or "In contact" are progressing.

I want to know the quick but important details for each opportunity broken down by sales rep. Do not make any assumptions. Based on all of the call notes, and reading through each email, provide me with a short 2-3 sentence description of how the deal is progressing based on the customer feedback and how likely the deal is to turn into a closed won opportunity.'
VERIFIED_AT 1778179435
VERIFIED_BY 'Yuki Taketani'
ONBOARDING_QUESTION true
SQL 'WITH __opportunities AS (
  SELECT
    close_date,
    created_date,
    name AS opp_name,
    stage_name AS stage,
    account_id,
    id,
    owner_id,
    amount AS deal_amount
  FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
), __users AS (
  SELECT
    name AS rep_name,
    id
  FROM TBRDP_DW_PROD.IM_RPT.V_SALESFORCE_USER_CURRENT
), __activity_metrics AS (
  SELECT
    engagement_level,
    task_urgency AS task_urgency_level,
    opportunity_id,
    days_since_last_email AS days_since_contact,
    total_activities AS total_activities_count,
    total_calls AS total_calls_count,
    total_emails AS total_emails_count
  FROM TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS
), __customer_360 AS (
  SELECT
    sf_account_name AS account_name,
    sf_account_id
  FROM TBRDP_DW_PROD.IM_RPT.T_CUSTOMER_360
)
SELECT
  __opportunities.id AS opportunity_id,
  __opportunities.opp_name AS opportunity_name,
  __opportunities.stage,
  __users.rep_name,
  ROUND(__opportunities.deal_amount, 2) AS amount,
  __activity_metrics.engagement_level,
  __activity_metrics.task_urgency_level,
  __activity_metrics.total_activities_count,
  __activity_metrics.total_emails_count,
  __activity_metrics.total_calls_count,
  __activity_metrics.days_since_contact,
  __opportunities.close_date,
  __customer_360.account_name,
  __opportunities.created_date
FROM __opportunities
LEFT OUTER JOIN __users
  ON __opportunities.owner_id = __users.id
INNER JOIN __activity_metrics
  ON __opportunities.id = __activity_metrics.opportunity_id
LEFT OUTER JOIN __customer_360
  ON __opportunities.account_id = __customer_360.sf_account_id
WHERE
  __opportunities.system_current_flag = ''Y''
  AND __opportunities.opp_name ILIKE ''%2026 04.14 - VOC Homestand 1: 06-10 Games%''
  AND __opportunities.stage IN (''Initial Conversation'', ''In contact'')
ORDER BY
  __users.rep_name,
  __activity_metrics.days_since_contact DESC /* Generated by Cortex */;')
    )
    with extension (CA='{"tables":[{"name":"ACTIVITY_DETAIL","dimensions":[{"name":"DIM_ACTIVITY_DATE"},{"name":"DIM_ACTIVITY_STATUS"},{"name":"DIM_ACTIVITY_SUBTYPE"},{"name":"DIM_ACTIVITY_TYPE"},{"name":"DIM_EMAIL_INCOMING"},{"name":"DIM_REP_NAME"}],"facts":[{"name":"DIM_CALL_DURATION"}],"metrics":[{"name":"DIM_INBOUND_CALLS"},{"name":"DIM_OUTBOUND_CALLS"},{"name":"DIM_TOTAL_ACTIVITIES"},{"name":"DIM_TOTAL_CALLS"},{"name":"DIM_TOTAL_EMAILS"},{"name":"DIM_TOTAL_TASKS"},{"name":"ACTIVITY_DATA_LAST_REFRESHED"}]},{"name":"ACTIVITY_METRICS","dimensions":[{"name":"ENGAGEMENT_LEVEL"},{"name":"HAS_SENTIMENT_RISK"},{"name":"IS_GHOSTED_FLAG"},{"name":"NEXT_TASK_DUE_DATE"},{"name":"NEXT_TASK_NAME"},{"name":"TASK_URGENCY_LEVEL"}],"facts":[{"name":"AVG_SENTIMENT_SCORE"},{"name":"DAYS_SINCE_CONTACT"},{"name":"OVERDUE_TASK_COUNT_VALUE"},{"name":"TOTAL_ACTIVITIES_COUNT"},{"name":"TOTAL_CALLS_COUNT"},{"name":"TOTAL_EMAILS_COUNT"}],"metrics":[{"name":"AVG_EMAILS_PER_DEAL"},{"name":"DEALS_WITH_OVERDUE_TASKS"},{"name":"GHOSTED_DEAL_COUNT"},{"name":"OVERDUE_TASK_TOTAL"},{"name":"TOTAL_CALL_VOLUME"},{"name":"TOTAL_EMAIL_VOLUME"}]},{"name":"CALL_ACTIVITY","dimensions":[{"name":"ACCOUNT_ID"},{"name":"AGENT_EMAIL"},{"name":"AGENT_NAME"},{"name":"AGENT_OWNER_ID"},{"name":"CALL_CHANNEL"},{"name":"CALL_DATE"},{"name":"CALL_DIRECTION"},{"name":"CALL_END_TIME"},{"name":"CALL_MONTH"},{"name":"CALL_NOTES"},{"name":"CALL_RESULT"},{"name":"CALL_SOURCE"},{"name":"CALL_START_TIME"},{"name":"CALL_WEEK"},{"name":"CALLEE_PHONE"},{"name":"CHANNEL_SOURCE"},{"name":"CONSUMER_NAME"},{"name":"CONSUMER_PHONE"},{"name":"CONTACT_ID"},{"name":"CONTACT_PHONE"},{"name":"CREATED_DATE"},{"name":"DISPOSITION"},{"name":"ENGAGEMENT_ID"},{"name":"INTERACTION_TYPE"},{"name":"IS_ACTIVE_SALES_REP"},{"name":"IS_MISSED"},{"name":"IS_TRANSFER"},{"name":"LAST_MODIFIED_DATE"},{"name":"LINKED_TASK_ID"},{"name":"LOADED_AT"},{"name":"OPPORTUNITY_ID"},{"name":"QUEUE_NAME"},{"name":"RECORD_NAME"},{"name":"RECORDING_REFERENCE"},{"name":"SESSION_ID"},{"name":"TASK_NOTES"},{"name":"TASK_SUBJECT"},{"name":"VOICEMAIL_CONTENT"}],"facts":[{"name":"DURATION_SECONDS"},{"name":"TALK_TIME_SECONDS"}],"metrics":[{"name":"AVG_CALL_DURATION_SECONDS"},{"name":"AVG_TALK_TIME_MINUTES"},{"name":"AVG_TALK_TIME_SECONDS"},{"name":"CALLS_LINKED_TO_OPPORTUNITY"},{"name":"CALLS_WITH_NOTES"},{"name":"INBOUND_CALLS"},{"name":"MISSED_CALLS"},{"name":"NOTE_LOGGING_RATE"},{"name":"OUTBOUND_CALLS"},{"name":"TOTAL_CALL_MINUTES"},{"name":"TOTAL_CALLS"},{"name":"TOTAL_TALK_MINUTES"}]},{"name":"CUSTOMER_360","dimensions":[{"name":"ACCOUNT_BILLING_CITY"},{"name":"ACCOUNT_BILLING_STATE"},{"name":"ACCOUNT_NAME"},{"name":"CHURN_RISK"},{"name":"CUSTOMER_SEGMENT"},{"name":"HAS_BOTH"},{"name":"LOYAL_FLAG"},{"name":"PERSON_ACCOUNT"},{"name":"PURCHASE_SEASON_LIST"},{"name":"RECENCY_TIER"},{"name":"REVENUE_TIER"},{"name":"TICKET_TYPES"},{"name":"UPSELL_FLAG"}],"facts":[{"name":"CUST_CONVERSION_DAYS"},{"name":"CUST_CRM_WON_REV"},{"name":"CUST_DAYS_SINCE_PURCHASE"},{"name":"CUST_EVENTS_ATTENDED"},{"name":"CUST_FLEX_REV"},{"name":"CUST_GROUP_REV"},{"name":"CUST_LTV"},{"name":"CUST_OPP_COUNT"},{"name":"CUST_PURCHASE_COUNT"},{"name":"CUST_SEASON_TIX_REV"},{"name":"CUST_SEASONS_COUNT"},{"name":"CUST_SINGLE_GAME_REV"},{"name":"CUST_SPONSOR_REV"},{"name":"CUST_SUITE_REV"},{"name":"CUST_TICKET_REV"},{"name":"CUST_WON_OPP_COUNT"}],"metrics":[{"name":"AGG_AVG_CONVERSION_DAYS"},{"name":"AGG_AVG_EVENTS"},{"name":"AGG_AVG_LTV"},{"name":"AGG_AVG_PURCHASES"},{"name":"AGG_CHURN_RISK_COUNT"},{"name":"AGG_CUSTOMER_COUNT"},{"name":"AGG_GROUP_REVENUE"},{"name":"AGG_LIFETIME_VALUE"},{"name":"AGG_LOYAL_COUNT"},{"name":"AGG_SEASON_TIX_REVENUE"},{"name":"AGG_SINGLE_GAME_REVENUE"},{"name":"AGG_SUITE_REVENUE"},{"name":"AGG_TICKET_REVENUE"},{"name":"AGG_UPSELL_COUNT"}]},{"name":"DEAL_HEALTH","dimensions":[{"name":"DEAL_TASK_URGENCY"},{"name":"HEALTH_CATEGORY"},{"name":"IS_AT_RISK"}],"facts":[{"name":"HEALTH_SCORE_VALUE"}],"metrics":[{"name":"AT_RISK_COUNT"},{"name":"AT_RISK_VALUE"},{"name":"AVERAGE_HEALTH_SCORE"}]},{"name":"EMAIL_ANALYTICS","dimensions":[{"name":"EMAIL_DAY"},{"name":"EMAIL_DIR"},{"name":"EMAIL_HOUR_OF_DAY"},{"name":"EMAIL_OPP_NAME"},{"name":"EMAIL_REP"},{"name":"EMAIL_RESPONSE_BUCKET"},{"name":"EMAIL_SEND_DATE"},{"name":"EMAIL_SENT_CATEGORY"},{"name":"EMAIL_SUBJECT"},{"name":"EMAIL_TIME_BUCKET"},{"name":"EMAIL_TIMESTAMP"}],"facts":[{"name":"EMAIL_RESPONSE_MINUTES"},{"name":"EMAIL_SENTIMENT"}],"metrics":[{"name":"AVG_RESPONSE_MINUTES"},{"name":"MEDIAN_RESPONSE_MINUTES"},{"name":"RESPONSE_RATE"},{"name":"TOTAL_EMAIL_COUNT"},{"name":"TOTAL_EMAILS_RECEIVED"},{"name":"TOTAL_EMAILS_SENT"}]},{"name":"GAME_ATTENDANCE","dimensions":[{"name":"FIRST_GAME_DATE"},{"name":"LAST_GAME_DATE"},{"name":"SEASONS_ATTENDED"},{"name":"SEASONS_COUNT"}],"facts":[{"name":"AVG_TICKET_PRICE_AMOUNT"},{"name":"GAMES_ATTENDED_COUNT"},{"name":"LOSSES_ATTENDED"},{"name":"TOTAL_TICKET_SPEND_AMOUNT"},{"name":"WIN_PERCENTAGE_ATTENDED"},{"name":"WINS_ATTENDED"}],"metrics":[{"name":"AVG_GAMES_PER_CUSTOMER"},{"name":"AVG_WIN_PCT_ATTENDED"},{"name":"CUSTOMERS_WITH_HIGH_WIN_PCT"},{"name":"TOTAL_GAME_TICKET_SPEND"},{"name":"TOTAL_GAMES_ATTENDED"},{"name":"TOTAL_LOSSES_ATTENDED"},{"name":"TOTAL_WINS_ATTENDED"}]},{"name":"GAME_ATTENDANCE_DETAIL","dimensions":[{"name":"DETAIL_AWAY_TEAM"},{"name":"DETAIL_EMAIL"},{"name":"DETAIL_EVENT_NAME"},{"name":"DETAIL_GAME_DATE"},{"name":"DETAIL_GAME_RESULT"},{"name":"DETAIL_GAMEPK"},{"name":"DETAIL_HOME_TEAM"},{"name":"DETAIL_OPPONENT"},{"name":"DETAIL_PATRON_NAME"},{"name":"DETAIL_RAYS_HOME"},{"name":"DETAIL_RAYS_WIN"},{"name":"DETAIL_SEASON"}],"facts":[{"name":"DETAIL_AWAY_SCORE"},{"name":"DETAIL_HOME_SCORE"},{"name":"DETAIL_SPEND"},{"name":"DETAIL_TICKETS"}],"metrics":[{"name":"DETAIL_GAME_COUNT"},{"name":"DETAIL_LOSSES_COUNT"},{"name":"DETAIL_WINS_COUNT"}]},{"name":"OPPORTUNITIES","dimensions":[{"name":"CLOSE_DATE"},{"name":"CLOSE_MONTH"},{"name":"CLOSE_QUARTER"},{"name":"CREATED_DATE"},{"name":"CREATED_MONTH"},{"name":"CREATED_QUARTER"},{"name":"IS_CLOSED"},{"name":"IS_WON"},{"name":"OPP_NAME"},{"name":"PRIMARY_OBJECTION"},{"name":"SECONDARY_OBJECTION"},{"name":"STAGE"}],"facts":[{"name":"DEAL_AMOUNT"},{"name":"PROBABILITY_PCT"},{"name":"WEIGHTED_AMOUNT"}],"metrics":[{"name":"AVERAGE_DEAL_SIZE"},{"name":"CP_SALES_COUNT"},{"name":"CP_SALES_PIPELINE"},{"name":"LOST_COUNT"},{"name":"MEMBER_AE_COUNT"},{"name":"MEMBER_AE_PIPELINE"},{"name":"OPPORTUNITY_COUNT"},{"name":"TICKET_SALES_COUNT"},{"name":"TICKET_SALES_PIPELINE"},{"name":"TICKET_SERVICE_COUNT"},{"name":"TICKET_SERVICE_PIPELINE"},{"name":"TOTAL_PIPELINE_VALUE"},{"name":"TSR_COUNT"},{"name":"TSR_PIPELINE"},{"name":"WEIGHTED_PIPELINE_VALUE"},{"name":"WIN_RATE_PCT"},{"name":"WON_COUNT"}],"filters":[{"name":"SYSTEM_CURRENT","expr":"SYSTEM_CURRENT_FLAG = ''Y''"}]},{"name":"SALESFORCE_TASKS","dimensions":[{"name":"TASK_CALL_DISPOSITION"},{"name":"TASK_DESCRIPTION"},{"name":"TASK_DUE_DATE"},{"name":"TASK_IS_CLOSED"},{"name":"TASK_PRIORITY"},{"name":"TASK_STATUS"},{"name":"TASK_SUBJECT"},{"name":"TASK_TYPE"}],"metrics":[{"name":"TASK_COUNT"}]},{"name":"TICKET_TEAM_DEPT","dimensions":[{"name":"TICKET_DEPARTMENT"},{"name":"TICKET_REP_NAME"},{"name":"TICKET_TEAM"}]},{"name":"USERS","dimensions":[{"name":"IS_ACTIVE"},{"name":"REP_EMAIL"},{"name":"REP_NAME"}]}],"relationships":[{"name":"ACTIVITY_DETAIL_TO_OPPORTUNITY"},{"name":"ACTIVITY_DETAIL_TO_REP"},{"name":"CALL_TO_OPPORTUNITY"},{"name":"CALL_TO_USER"},{"name":"CUSTOMER_TO_GAME_ATTENDANCE"},{"name":"EMAILS_TO_OPPORTUNITY"},{"name":"EMAILS_TO_REP"},{"name":"OPPORTUNITIES_TO_ACTIVITY"},{"name":"OPPORTUNITIES_TO_CUSTOMER"},{"name":"OPPORTUNITIES_TO_HEALTH"},{"name":"OPPORTUNITIES_TO_OWNER"},{"name":"TASKS_TO_OPPORTUNITY"},{"name":"TASKS_TO_OWNER"},{"name":"USERS_TO_TICKET_DEPT"}]}');
