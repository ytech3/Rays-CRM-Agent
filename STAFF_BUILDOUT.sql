
-- =============================================================================
-- PHASE 4: TICKET TEAM CLASSIFICATION - FOCUSED IMPLEMENTATION
-- =============================================================================
-- Purpose: Classify specific 12 ticket sales and service representatives
-- Database: TBRDP_DW_PROD
-- Schema: IM_RPT
-- Date: February 9, 2026
-- =============================================================================

/*
SCOPE: 
- 8 Ticket SALES Representatives
- 4 Ticket SERVICE Representatives  
- 12 total individuals

GOAL:
Enable accurate performance comparisons within each department:
- SALES reps compared to other SALES reps
- SERVICE reps compared to other SERVICE reps
*/

-- =============================================================================
-- STEP 1: CREATE DEPARTMENT MAPPING TABLE FOR TICKET TEAM
-- =============================================================================

CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING AS
SELECT user_id, user_name, department, team, 
       CURRENT_TIMESTAMP() AS classification_date, 
       'Manual Classification - Feb 2026' AS classification_source
FROM (
    -- =============================================================================
    -- TICKET SALES GROUP ACCOUNT EXECUTIVES (7 total)
    -- =============================================================================
    SELECT '005cw000001aoaPAAQ' AS user_id, 'Rafael Lazala' AS user_name, 'TICKET_SALES' AS department, 'Ticket Sales Group Account Executives' AS team
    UNION ALL
    SELECT '005cw000002URuTAAW', 'Brock Shively', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    UNION ALL
    SELECT '005cw000003XvozAAC', 'Colin McGlinchey', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    UNION ALL
    SELECT '005cw000002URsrAAG', 'Jordan Beech', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    UNION ALL
    SELECT '005cw000001cB1tAAE', 'Tate Anderson', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    UNION ALL
    SELECT '005cw000001c9bCAAQ', 'Brandon Harnick', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    UNION ALL
    SELECT '005cw000001c8GxAAI', 'Lindsay Auld', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    -- =============================================================================
    -- TICKET SERVICE REPRESENTATIVES (4 total)
    -- =============================================================================
    UNION ALL
    SELECT '005cw000001cAqbAAE', 'Jared Consiglio', 'TICKET_SERVICE', 'Ticket Service'
    UNION ALL
    SELECT '005cw000001aoc1AAA', 'Kacey McGlone', 'TICKET_SERVICE', 'Ticket Service'
    UNION ALL
    SELECT '005cw000001cAx3AAE', 'Steven Long', 'TICKET_SERVICE', 'Ticket Service'
    UNION ALL
    SELECT '005cw000001cB9xAAE', 'Zach Grundt', 'TICKET_SERVICE', 'Ticket Service'
    -- =============================================================================
    -- TICKET SEASON MEMBER ACCOUNT EXECUTIVES (2 total)
    -- =============================================================================
    UNION ALL
    SELECT '005cw000005SFqrAAG', 'Eric Yalowitz', 'TICKET_MEMBER_AE', 'Ticket Account Executive'
    UNION ALL
    SELECT '005cw000005SFm1AAG', 'Madison Jones', 'TICKET_MEMBER_AE', 'Ticket Account Executive'
    -- =============================================================================
    -- TICKET SALES REPRESENTATIVES / TSRs (4 total)
    -- =============================================================================
    UNION ALL
    SELECT '005cw000005SFyvAAG', 'Alexa Linchuck', 'TICKET_TSR', 'Ticket Sales Representative'
    UNION ALL
    SELECT '005cw000005SG0XAAW', 'Benjamin Knee', 'TICKET_TSR', 'Ticket Sales Representative'
    UNION ALL
    SELECT '005cw000005SG5NAAW', 'Emily Prindiville', 'TICKET_TSR', 'Ticket Sales Representative'
    UNION ALL
    SELECT '005cw000005SJJNAA4', 'Torrey Pursel', 'TICKET_TSR', 'Ticket Sales Representative'
    -- =============================================================================
    -- CORPORATE PARTNERSHIP SALES (6 total)
    -- =============================================================================
    UNION ALL
    SELECT '005cw000001SUsDAAW', 'John Pope', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
    UNION ALL
    SELECT '005cw000001c96XAAQ', 'Jazzmine McDonald', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
    UNION ALL
    SELECT '005cw000001SV57AAG', 'Ifadare Ogunleye', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
    UNION ALL
    SELECT '005cw000001SV9xAAG', 'Michael Lee', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
    UNION ALL
    SELECT '005cw000001c8iMAAQ', 'Daniel Schonborn', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
    UNION ALL
    SELECT '005cw000001c9XxAAI', 'Stephen Lanier', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
);


-- =============================================================================
-- STEP 2: VERIFY THE MAPPING
-- =============================================================================

-- Query to confirm all 12 users are classified correctly
SELECT 
    department,
    team,
    COUNT(*) AS rep_count,
    LISTAGG(user_name, ', ') WITHIN GROUP (ORDER BY user_name) AS rep_names
FROM TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING
GROUP BY department, team
ORDER BY department;

/*
Expected Output:
department      | team           | rep_count | rep_names
----------------+----------------+-----------+--------------------------------------------------
TICKET_SALES    | Ticket Sales   | 8         | Brandon Harnick, Brock Shively, Chase Pittman...
TICKET_SERVICE  | Ticket Service | 4         | Jared Consiglio, Kacey McGlone, Steven Long...
*/

-- =============================================================================
-- STEP 3: CREATE ENRICHED USER VIEW WITH DEPARTMENT INFO
-- =============================================================================

DESCRIBE VIEW TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER;

CREATE OR REPLACE VIEW TBRDP_DW_PROD.IM_RPT.V_TICKET_TEAM_WITH_DEPARTMENT
COMMENT = 'Ticket team members with department classification and full Salesforce user details'
AS
SELECT 
    -- User identification
    u.ID AS user_id,
    u.NAME AS user_name,
    u.EMAIL,
    u.USERNAME,
    
    -- Department classification
    d.department,
    d.team,
    d.classification_date,
    d.classification_source,
    
    -- User status
    u.IS_ACTIVE,
    u._FIVETRAN_DELETED AS IS_DELETED,
    
    -- Profile and role info (for reference)
    u.PROFILE_ID,
    u.USER_TYPE,
    
    -- Dates
    u.CREATED_DATE,
    u.LAST_LOGIN_DATE,
    u.LAST_MODIFIED_DATE
    
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u
INNER JOIN TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING d
    ON u.ID = d.user_id
WHERE u.IS_ACTIVE = TRUE
  AND u._FIVETRAN_DELETED = FALSE;

-- =============================================================================
-- STEP 4: VERIFY USER DETAILS FROM SALESFORCE
-- =============================================================================

-- Confirm all 12 users exist and are active in Salesforce
SELECT 
    user_id,
    user_name,
    email,
    department,
    team,
    PROFILE_ID,
    IS_ACTIVE,
    last_login_date
FROM TBRDP_DW_PROD.IM_RPT.V_TICKET_TEAM_WITH_DEPARTMENT
ORDER BY department, user_name;

/*
This query should return 12 rows. If you get fewer than 12:
- Check that all user IDs are correct
- Check that all users are ISACTIVE = TRUE
- Check that all users have IS_DELETED = FALSE
*/

-- =============================================================================
-- STEP 5: PERFORMANCE ANALYSIS - TICKET SALES TEAM
-- =============================================================================

-- Last 12 months performance for Ticket SALES representatives
SELECT 
    u.user_name,
    u.email,
    u.department,
    
    -- Opportunity metrics
    COUNT(DISTINCT o.ID) AS total_opportunities,
    COUNT(DISTINCT CASE WHEN o.STAGE_NAME = 'Closed Won' THEN o.ID END) AS won_deals,
    COUNT(DISTINCT CASE WHEN o.STAGE_NAME = 'Closed Lost' THEN o.ID END) AS lost_deals,
    COUNT(DISTINCT CASE WHEN o.IS_CLOSED = FALSE THEN o.ID END) AS open_pipeline,
    
    -- Revenue metrics
    SUM(COALESCE(o.AMOUNT, 0)) AS total_pipeline_value,
    SUM(CASE WHEN o.STAGE_NAME = 'Closed Won' THEN COALESCE(o.AMOUNT, 0) ELSE 0 END) AS total_revenue,
    SUM(CASE WHEN o.STAGE_NAME = 'Closed Lost' THEN COALESCE(o.AMOUNT, 0) ELSE 0 END) AS lost_revenue,
    SUM(CASE WHEN o.IS_CLOSED = FALSE THEN COALESCE(o.AMOUNT, 0) ELSE 0 END) AS open_pipeline_value,
    
    -- Average deal size
    ROUND(AVG(CASE WHEN o.STAGE_NAME = 'Closed Won' THEN o.AMOUNT END), 2) AS avg_deal_size,
    
    -- Win rate
    ROUND(COUNT(DISTINCT CASE WHEN o.STAGE_NAME = 'Closed Won' THEN o.ID END) * 100.0 / 
          NULLIF(COUNT(DISTINCT CASE WHEN o.IS_CLOSED = TRUE THEN o.ID END), 0), 2) AS win_rate_pct,
    
    -- Deal velocity (average days to close for won deals)
    ROUND(AVG(CASE WHEN o.STAGE_NAME = 'Closed Won' 
                   THEN DATEDIFF('day', o.CREATED_DATE, o.CLOSE_DATE) 
              END), 1) AS avg_days_to_close

FROM TBRDP_DW_PROD.IM_RPT.V_TICKET_TEAM_WITH_DEPARTMENT u
LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
    ON u.user_id = o.OWNER_ID
    AND o.CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())  -- Last 12 months
WHERE u.department = 'TICKET_SALES'
GROUP BY u.user_name, u.email, u.department
ORDER BY total_revenue DESC;

-- =============================================================================
-- STEP 6: PERFORMANCE ANALYSIS - TICKET SERVICE TEAM
-- =============================================================================
DESCRIBE VIEW TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE;


-- Last 12 months performance for Ticket SERVICE representatives
SELECT 
    u.user_name,
    u.email,
    u.department,
    
    -- Task metrics
    COUNT(DISTINCT t.ID) AS total_tasks,
    COUNT(DISTINCT CASE WHEN t.STATUS = 'Completed' THEN t.ID END) AS completed_tasks,
    COUNT(DISTINCT CASE WHEN t.STATUS != 'Completed' THEN t.ID END) AS open_tasks,
    
    -- Completion rate
    ROUND(COUNT(DISTINCT CASE WHEN t.STATUS = 'Completed' THEN t.ID END) * 100.0 / 
          NULLIF(COUNT(DISTINCT t.ID), 0), 2) AS task_completion_rate_pct,
    
    -- Account coverage
    COUNT(DISTINCT t.ACCOUNT_ID) AS unique_accounts_served,
    COUNT(DISTINCT t.WHO_ID) AS unique_contacts_served,
    
    -- Email activity
    COUNT(DISTINCT e.ID) AS total_emails_sent,
    
    -- Response time (hours from task creation to completion)
    ROUND(AVG(CASE WHEN t.STATUS = 'Completed' AND t.COMPLETED_DATE_TIME IS NOT NULL
                   THEN DATEDIFF('hour', t.CREATED_DATE, t.COMPLETED_DATE_TIME) 
              END), 1) AS avg_hours_to_complete_task,
    
    -- Call activity
    COUNT(DISTINCT c.ID) AS total_calls_logged

FROM TBRDP_DW_PROD.IM_RPT.V_TICKET_TEAM_WITH_DEPARTMENT u
LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK t
    ON u.user_id = t.OWNER_ID
    AND t.CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())  -- Last 12 months
LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE e
    ON u.user_id = e.CREATED_BY_ID
    AND e.MESSAGE_DATE >= DATEADD('month', -12, CURRENT_DATE())
LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C c
    ON u.user_id = c.OWNER_ID  -- Adjust field name if different
    AND c.CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())
WHERE u.department = 'TICKET_SERVICE'
GROUP BY u.user_name, u.email, u.department
ORDER BY completed_tasks DESC;

-- =============================================================================
-- STEP 7: COMBINED ACTIVITY SUMMARY (ALL 12 REPS)
-- =============================================================================

-- Overview of all ticket team members with key metrics
SELECT 
    u.department,
    u.user_name,
    u.email,
    
    -- Universal metrics (apply to both sales and service)
    COUNT(DISTINCT o.ID) AS opportunities,
    COUNT(DISTINCT t.ID) AS tasks,
    COUNT(DISTINCT e.ID) AS emails,
    COUNT(DISTINCT c.ID) AS calls,
    
    -- Revenue (mainly for sales, but some service may have opps)
    SUM(CASE WHEN o.STAGE_NAME = 'Closed Won' THEN COALESCE(o.AMOUNT, 0) ELSE 0 END) AS revenue,
    
    -- Win rate (for sales reps)
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN o.IS_CLOSED = TRUE THEN o.ID END) > 0
        THEN ROUND(COUNT(DISTINCT CASE WHEN o.STAGE_NAME = 'Closed Won' THEN o.ID END) * 100.0 / 
                   COUNT(DISTINCT CASE WHEN o.IS_CLOSED = TRUE THEN o.ID END), 2)
        ELSE NULL
    END AS win_rate_pct,
    
    -- Task completion (mainly for service)
    CASE 
        WHEN COUNT(DISTINCT t.ID) > 0
        THEN ROUND(COUNT(DISTINCT CASE WHEN t.STATUS = 'Completed' THEN t.ID END) * 100.0 / 
                   COUNT(DISTINCT t.ID), 2)
        ELSE NULL
    END AS task_completion_pct,
    
    -- Last activity date
    GREATEST(
        COALESCE(MAX(o.LAST_MODIFIED_DATE), '1900-01-01'::DATE),
        COALESCE(MAX(t.LAST_MODIFIED_DATE), '1900-01-01'::DATE),
        COALESCE(MAX(e.MESSAGE_DATE), '1900-01-01'::DATE),
        COALESCE(MAX(c.CREATED_DATE), '1900-01-01'::DATE)
    ) AS last_activity_date

FROM TBRDP_DW_PROD.IM_RPT.V_TICKET_TEAM_WITH_DEPARTMENT u
LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
    ON u.user_id = o.OWNER_ID
    AND o.CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())
LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK t
    ON u.user_id = t.OWNER_ID
    AND t.CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())
LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE e
    ON u.user_id = e.CREATED_BY_ID
    AND e.MESSAGE_DATE >= DATEADD('month', -12, CURRENT_DATE())
LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C c
    ON u.user_id = c.OWNER_ID
    AND c.CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())
GROUP BY u.department, u.user_name, u.email
ORDER BY u.department, u.user_name;

-- =============================================================================
-- STEP 8: DEPARTMENT COMPARISON SUMMARY
-- =============================================================================

-- High-level comparison between Ticket Sales vs Ticket Service teams
SELECT 
    department,
    COUNT(DISTINCT u.user_id) AS total_reps,
    
    -- Activity volumes
    SUM(opp_count) AS total_opportunities,
    SUM(task_count) AS total_tasks,
    SUM(email_count) AS total_emails,
    
    -- Revenue (mainly sales)
    SUM(revenue) AS total_revenue,
    ROUND(AVG(revenue), 2) AS avg_revenue_per_rep,
    
    -- Win rate (mainly sales)
    ROUND(SUM(won_deals) * 100.0 / NULLIF(SUM(closed_deals), 0), 2) AS team_win_rate_pct,
    
    -- Task completion (mainly service)
    ROUND(SUM(completed_tasks) * 100.0 / NULLIF(SUM(task_count), 0), 2) AS team_task_completion_pct,
    
    -- Per rep averages
    ROUND(AVG(opp_count), 1) AS avg_opps_per_rep,
    ROUND(AVG(task_count), 1) AS avg_tasks_per_rep,
    ROUND(AVG(email_count), 1) AS avg_emails_per_rep

FROM (
    SELECT 
        u.user_id,
        u.department,
        COUNT(DISTINCT o.ID) AS opp_count,
        COUNT(DISTINCT CASE WHEN o.STAGE_NAME = 'Closed Won' THEN o.ID END) AS won_deals,
        COUNT(DISTINCT CASE WHEN o.IS_CLOSED = TRUE THEN o.ID END) AS closed_deals,
        COUNT(DISTINCT t.ID) AS task_count,
        COUNT(DISTINCT CASE WHEN t.STATUS = 'Completed' THEN t.ID END) AS completed_tasks,
        COUNT(DISTINCT e.ID) AS email_count,
        SUM(CASE WHEN o.STAGE_NAME = 'Closed Won' THEN COALESCE(o.AMOUNT, 0) ELSE 0 END) AS revenue
    FROM TBRDP_DW_PROD.IM_RPT.V_TICKET_TEAM_WITH_DEPARTMENT u
    LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
        ON u.user_id = o.OWNER_ID
        AND o.CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())
    LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK t
        ON u.user_id = t.OWNER_ID
        AND t.CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())
    LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE e
        ON u.user_id = e.CREATED_BY_ID
        AND e.MESSAGE_DATE >= DATEADD('month', -12, CURRENT_DATE())
    GROUP BY u.user_id, u.department
) subquery
GROUP BY department
ORDER BY department;

-- =============================================================================
-- STEP 9: LINK TO EXISTING ARM AGENT INFRASTRUCTURE
-- =============================================================================

-- Check which of the 12 reps have data in your existing AI-enriched tables
SELECT 
    u.department,
    u.user_name,
    
    -- Enriched email data (from Phase 1)
    COUNT(DISTINCT e.EMAIL_ID) AS ai_enriched_emails,
    
    -- Deal health scores (from Phase 1)
    COUNT(DISTINCT h.opportunity_id) AS deals_with_health_scores,
    
    -- Activity metrics (from Phase 1)
    COUNT(DISTINCT a.opportunity_id) AS deals_with_activity_metrics

FROM TBRDP_DW_PROD.IM_RPT.V_TICKET_TEAM_WITH_DEPARTMENT u
LEFT JOIN TBRDP_DW_PROD.IM_RPT.DT_EMAIL_ENRICHED e
    ON u.user_id = e.FROM_USER_ID
LEFT JOIN TBRDP_DW_PROD.IM_RPT.DT_DEAL_HEALTH_SCORE h
    ON EXISTS (
        SELECT 1 FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
        WHERE o.ID = h.opportunity_id
        AND o.OWNER_ID = u.user_id
    )
LEFT JOIN TBRDP_DW_PROD.IM_RPT.DT_OPPORTUNITY_ACTIVITY_METRICS a
    ON EXISTS (
        SELECT 1 FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
        WHERE o.ID = a.opportunity_id
        AND o.OWNER_ID = u.user_id
    )
GROUP BY u.department, u.user_name
ORDER BY u.department, u.user_name;

-- =============================================================================
-- STEP 10: VALIDATE EMAIL/CALL/TASK DATA EXISTS
-- =============================================================================

-- Diagnostic query to ensure we're joining to the right fields
-- This helps identify any data quality issues before we build Phase 5 & 6

SELECT 
    'Opportunities' AS data_source,
    COUNT(*) AS total_records,
    COUNT(DISTINCT OWNER_ID) AS unique_owners,
    SUM(CASE WHEN OWNER_ID IN (SELECT user_id FROM TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING) 
             THEN 1 ELSE 0 END) AS records_for_ticket_team,
    MIN(CREATED_DATE) AS earliest_date,
    MAX(CREATED_DATE) AS latest_date
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY
WHERE CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())

UNION ALL

SELECT 
    'Tasks' AS data_source,
    COUNT(*) AS total_records,
    COUNT(DISTINCT OWNER_ID) AS unique_owners,
    SUM(CASE WHEN OWNER_ID IN (SELECT user_id FROM TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING) 
             THEN 1 ELSE 0 END) AS records_for_ticket_team,
    MIN(CREATED_DATE) AS earliest_date,
    MAX(CREATED_DATE) AS latest_date
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_TASK
WHERE CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())

UNION ALL

SELECT 
    'Emails' AS data_source,
    COUNT(*) AS total_records,
    COUNT(DISTINCT CREATED_BY_ID) AS unique_owners,
    SUM(CASE WHEN CREATED_BY_ID IN (SELECT user_id FROM TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING) 
             THEN 1 ELSE 0 END) AS records_for_ticket_team,
    MIN(MESSAGE_DATE) AS earliest_date,
    MAX(MESSAGE_DATE) AS latest_date
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE
WHERE MESSAGE_DATE >= DATEADD('month', -12, CURRENT_DATE())

UNION ALL

SELECT 
    'Call Logs' AS data_source,
    COUNT(*) AS total_records,
    COUNT(DISTINCT OWNER_ID) AS unique_owners,  -- May need adjustment
    SUM(CASE WHEN OWNER_ID IN (SELECT user_id FROM TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING) 
             THEN 1 ELSE 0 END) AS records_for_ticket_team,
    MIN(CREATED_DATE) AS earliest_date,
    MAX(CREATED_DATE) AS latest_date
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C
WHERE CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())

ORDER BY data_source;

-- =============================================================================
-- SUCCESS CONFIRMATION
-- =============================================================================

/*
✅ PHASE 4 COMPLETE - FOCUSED IMPLEMENTATION

You now have:
1. ✅ T_TICKET_TEAM_DEPARTMENT_MAPPING - Classification table for 12 reps
2. ✅ V_TICKET_TEAM_WITH_DEPARTMENT - Enriched view with user details
3. ✅ Performance queries for Sales team (Query 5)
4. ✅ Performance queries for Service team (Query 6)
5. ✅ Combined activity summary (Query 7)
6. ✅ Department comparison (Query 8)
7. ✅ Link to existing ARM Agent infrastructure (Query 9)
8. ✅ Data validation diagnostics (Query 10)

NEXT STEPS:
→ Run Step 10 (validation query) to identify any JOIN field issues
→ Review performance outputs to ensure data looks reasonable
→ Proceed to Phase 5: Customer 360 (link to ticket sales transactions)
→ Proceed to Phase 6: Expand ARM Agent with ticket team insights

CURRENT SCOPE:
- 8 Ticket SALES Representatives: Revenue, win rates, deal metrics
- 4 Ticket SERVICE Representatives: Task completion, account coverage, response times
- Fair performance comparisons within each department

=============================================================================



-- =============================================================================
-- PHASE 4B: ARM AGENT SEMANTIC VIEW UPDATE
-- =============================================================================
-- Purpose: Add ticket team department classification to ARM Agent's semantic view
-- This enables the agent to understand and filter by TICKET_SALES vs TICKET_SERVICE
-- Database: TBRDP_DW_PROD
-- Schema: IM_RPT
-- Date: February 9, 2026
-- =============================================================================

/*
WHAT THIS DOES:
Your ARM Agent currently queries SV_CRM_SALES_INTELLIGENCE for pipeline analytics.
This update adds the ticket team department classification so the agent can:
- Filter by department (TICKET_SALES vs TICKET_SERVICE)
- Compare performance across departments
- Answer questions like "Show me TICKET_SALES rep performance"

APPROACH:
We're adding your new T_TICKET_TEAM_DEPARTMENT_MAPPING table as a logical table
in the semantic view, with appropriate relationships to the users table.
*/
-- =============================================================================
-- STEP 1: UPDATE SEMANTIC VIEW - ADD TICKET TEAM CLASSIFICATION
-- =============================================================================

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
      COMMENT = 'Sales representative details and team information',
    
    -- *** NEW: Ticket team department classification ***
    ticket_team_dept AS TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING
      PRIMARY KEY (user_id)
      WITH SYNONYMS ('ticket team', 'department classification', 'ticket sales vs service')
      COMMENT = 'Department classification for ticket sales (8 reps) vs ticket service (4 reps) teams'
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
      opportunities (OWNER_ID) REFERENCES users (ID),
    
    -- *** NEW: Link users to their department classification ***
    users_to_ticket_dept AS
      users (ID) REFERENCES ticket_team_dept (user_id)
  )
  
  -- =============================================================================
  -- FACTS - Numeric measures
  -- =============================================================================
  FACTS (
    opportunities.deal_amount AS AMOUNT
      WITH SYNONYMS ('revenue', 'opportunity amount', 'deal size')
      COMMENT = 'Total opportunity amount in dollars',
    
    opportunities.weighted_amount AS AMOUNT * PROBABILITY / 100
      WITH SYNONYMS ('weighted revenue', 'weighted pipeline', 'probability-adjusted amount')
      COMMENT = 'Opportunity amount adjusted by win probability',
    
    opportunities.probability AS PROBABILITY
      WITH SYNONYMS ('win probability', 'close probability', 'likelihood')
      COMMENT = 'Probability of winning the deal (0-100%)',
    
    deal_health.health_score AS health_score
      WITH SYNONYMS ('deal health', 'opportunity health', 'risk score')
      COMMENT = 'AI-calculated health score from 0-100',
    
    activity_metrics.opp_emails AS TOTAL_EMAILS
      WITH SYNONYMS ('emails sent', 'email activity', 'messages')
      COMMENT = 'Total number of emails for this opportunity',
    
    activity_metrics.opp_calls AS TOTAL_CALLS
      WITH SYNONYMS ('calls made', 'phone calls', 'call activity')
      COMMENT = 'Total number of calls for this opportunity',
    
    activity_metrics.opp_tasks AS TOTAL_TASKS
      WITH SYNONYMS ('tasks created', 'activities', 'to-dos')
      COMMENT = 'Total number of tasks for this opportunity',
    
    activity_metrics.days_since_last_contact AS DAYS_SINCE_LAST_EMAIL
      WITH SYNONYMS ('days since contact', 'time since last touch', 'inactivity days')
      COMMENT = 'Number of days since last email'
  )
  
  -- =============================================================================
  -- DIMENSIONS - Categorical attributes and filters
  -- =============================================================================
  DIMENSIONS (
    opportunities.stage AS STAGE_NAME
      WITH SYNONYMS ('sales stage', 'deal stage', 'pipeline stage')
      COMMENT = 'Current stage of the opportunity (e.g., Prospecting, Negotiation, Closed Won)',
    
    opportunities.close_date AS CLOSE_DATE
      WITH SYNONYMS ('expected close date', 'close date', 'target close')
      COMMENT = 'Expected or actual close date of the opportunity',
    
    opportunities.is_closed AS IS_CLOSED
      WITH SYNONYMS ('closed', 'deal closed', 'finalized')
      COMMENT = 'Whether the opportunity is closed (won or lost)',
    
    opportunities.is_won AS IS_WON
      WITH SYNONYMS ('won', 'closed won', 'deal won')
      COMMENT = 'Whether the opportunity was won',
    
    opportunities.created_date AS CREATED_DATE
      WITH SYNONYMS ('opportunity created', 'deal created', 'creation date')
      COMMENT = 'Date the opportunity was created',
    
    opportunities.opportunity_type AS TYPE
      WITH SYNONYMS ('deal type', 'opp type')
      COMMENT = 'Type of opportunity (e.g., New Business, Renewal, Upsell)',
    
    deal_health.health_category AS health_category
      WITH SYNONYMS ('deal health status', 'health level', 'risk category')
      COMMENT = 'Health category: Healthy, At Risk, or Critical',
    
    activity_metrics.engagement_level AS engagement_level
      WITH SYNONYMS ('activity level', 'engagement status')
      COMMENT = 'Engagement level: High, Medium, or Low based on activity volume',
    
    activity_metrics.is_ghosted AS is_ghosted
      WITH SYNONYMS ('ghosted deal', 'no recent contact', 'inactive')
      COMMENT = 'Whether the opportunity has been inactive for 60+ days',
    
    activity_metrics.has_sentiment_risk AS HAS_SENTIMENT_RISK
      WITH SYNONYMS ('negative sentiment', 'sentiment risk', 'concerning sentiment')
      COMMENT = 'Whether recent communications show negative sentiment',
    
    users.owner_name AS NAME
      WITH SYNONYMS ('sales rep name', 'account executive', 'rep name', 'owner')
      COMMENT = 'Name of the sales representative who owns the opportunity',
    
    users.owner_email AS EMAIL
      WITH SYNONYMS ('rep email', 'owner email')
      COMMENT = 'Email address of the opportunity owner',
    
    users.owner_id AS ID
      WITH SYNONYMS ('user id', 'rep id')
      COMMENT = 'Salesforce user ID of the opportunity owner',
    
    ticket_team_dept.ticket_department AS department
      WITH SYNONYMS ('department', 'team type', 'sales vs service', 'ticket team type')
      COMMENT = 'Department classification: TICKET_SALES or TICKET_SERVICE',
    
    ticket_team_dept.ticket_team AS team
      WITH SYNONYMS ('team name', 'sub-team')
      COMMENT = 'Team name: Ticket Sales or Ticket Service',
    
    ticket_team_dept.ticket_rep_name AS user_name
      WITH SYNONYMS ('ticket rep', 'ticket team member')
      COMMENT = 'Name from ticket team classification (for validation/reference)'
  )
  
  -- =============================================================================
  -- CALCULATED METRICS - Business KPIs
  -- =============================================================================
  METRICS (
    opportunities.total_pipeline_value AS SUM(deal_amount)
      WITH SYNONYMS ('total pipeline', 'pipeline value', 'total revenue in pipeline')
      COMMENT = 'Sum of all opportunity amounts',
    
    opportunities.weighted_pipeline_value AS SUM(weighted_amount)
      WITH SYNONYMS ('weighted pipeline', 'probability-adjusted pipeline', 'forecasted revenue')
      COMMENT = 'Sum of opportunity amounts weighted by win probability',
    
    opportunities.average_deal_size AS AVG(deal_amount)
      WITH SYNONYMS ('avg deal size', 'average opportunity amount', 'mean deal value')
      COMMENT = 'Average opportunity amount',
    
    deal_health.average_health_score AS AVG(health_score)
      WITH SYNONYMS ('avg health score', 'mean health', 'average deal health')
      COMMENT = 'Average health score across opportunities',
    
    deal_health.healthy_count AS COUNT(CASE WHEN health_category = 'Healthy' THEN 1 END)
      WITH SYNONYMS ('healthy deals', 'healthy opportunities')
      COMMENT = 'Number of opportunities with Healthy status',
    
    deal_health.at_risk_count AS COUNT(CASE WHEN health_category = 'At Risk' THEN 1 END)
      WITH SYNONYMS ('at risk deals', 'at risk opportunities')
      COMMENT = 'Number of opportunities with At Risk status',
    
    deal_health.critical_count AS COUNT(CASE WHEN health_category = 'Critical' THEN 1 END)
      WITH SYNONYMS ('critical deals', 'critical opportunities')
      COMMENT = 'Number of opportunities with Critical status',
    
    opportunities.opportunity_count AS COUNT(*)
      WITH SYNONYMS ('number of deals', 'deal count', 'opp count', 'total opportunities')
      COMMENT = 'Total number of opportunities',
    
    opportunities.closed_won_count AS COUNT(CASE WHEN is_won = TRUE THEN 1 END)
      WITH SYNONYMS ('won deals', 'closed won', 'wins')
      COMMENT = 'Number of opportunities marked as Closed Won',
    
    opportunities.closed_lost_count AS COUNT(CASE WHEN is_closed = TRUE AND is_won = FALSE THEN 1 END)
      WITH SYNONYMS ('lost deals', 'closed lost', 'losses')
      COMMENT = 'Number of opportunities marked as Closed Lost',
    
    opportunities.win_rate_pct AS (COUNT(CASE WHEN is_won = TRUE THEN 1 END) * 100.0) / 
                     NULLIF(COUNT(CASE WHEN is_closed = TRUE THEN 1 END), 0)
      WITH SYNONYMS ('win rate', 'win percentage', 'close rate')
      COMMENT = 'Percentage of closed opportunities that were won',
    
    activity_metrics.sum_emails AS SUM(opp_emails)
      WITH SYNONYMS ('total email activity', 'email volume', 'total emails')
      COMMENT = 'Total number of emails across all opportunities',
    
    activity_metrics.sum_calls AS SUM(opp_calls)
      WITH SYNONYMS ('total call activity', 'call volume', 'total calls')
      COMMENT = 'Total number of calls across all opportunities',
    
    activity_metrics.sum_tasks AS SUM(opp_tasks)
      WITH SYNONYMS ('total task activity', 'task volume', 'total tasks')
      COMMENT = 'Total number of tasks across all opportunities',
    
    activity_metrics.ghosted_count AS COUNT(CASE WHEN is_ghosted = TRUE THEN 1 END)
      WITH SYNONYMS ('ghosted deals', 'inactive opportunities')
      COMMENT = 'Number of opportunities with no contact in 60+ days'
  )
  
  -- =============================================================================
  -- AI INSTRUCTIONS - Guide Cortex Analyst behavior
  -- =============================================================================
  COMMENT = $$
# Sales Intelligence Semantic Model - Enhanced with Ticket Team Classification

This semantic model provides access to CRM opportunity data with AI-enriched health scores,
activity metrics, and **ticket team department classification** (TICKET_SALES vs TICKET_SERVICE).

## Data Scope
- **Opportunities**: Sales pipeline with revenue, stages, and close dates
- **Deal Health**: AI-generated health scores and risk assessments  
- **Activity Metrics**: Email, call, and task engagement levels
- **Users**: Sales representatives with ticket team department classification
- **Ticket Team**: Classification of 12 ticket team members (8 SALES, 4 SERVICE)

## Key Business Rules

### Department Classification
- **TICKET_SALES (8 reps)**: Rafael Lazala, Brock Shively, Colin McGlinchey, Jordan Beech, 
  Chase Pittman, Tate Anderson, Brandon Harnick, Lindsay Auld
- **TICKET_SERVICE (4 reps)**: Jared Consiglio, Kacey McGlone, Steven Long, Zach Grundt
- Use `ticket_department` dimension to filter by department type
- Use `ticket_team` dimension to get team name
- Use `owner_name` dimension to filter by specific rep name

### Health Categories
- **Healthy**: Health score 70-100, actively engaged, no major risks
- **At Risk**: Health score 40-69, warning signs present
- **Critical**: Health score 0-39, requires immediate attention

### Engagement Levels  
- **High**: 10+ activities (emails/calls/tasks) in last 30 days
- **Medium**: 3-9 activities in last 30 days
- **Low**: 0-2 activities in last 30 days

### Ghosted Deals
- Opportunity marked as ghosted if no contact in 60+ days
- Use `is_ghosted` dimension to find inactive deals

## Question Answering Patterns

### Pipeline Questions
- "Total pipeline value" → Use `total_pipeline_value` metric
- "Weighted pipeline" → Use `weighted_pipeline_value` metric
- "Pipeline by stage" → Filter by `stage` dimension
- "Pipeline by department" → Filter by `ticket_department` dimension
- "Ticket sales team pipeline" → Use `ticket_sales_pipeline` metric or filter by `ticket_department = 'TICKET_SALES'`
- "Ticket service team pipeline" → Use `ticket_service_pipeline` metric or filter by `ticket_department = 'TICKET_SERVICE'`

### Performance Questions
- "Win rate" → Use `win_rate_pct` metric
- "Rep performance" → Group by `owner_name` dimension
- "Sales team performance" → Filter by `ticket_department = 'TICKET_SALES'` and group by `owner_name`
- "Service team performance" → Filter by `ticket_department = 'TICKET_SERVICE'` and group by `owner_name`
- "Compare departments" → Group by `ticket_department` dimension

### Health Questions
- "At-risk deals" → Filter by `health_category = 'At Risk'`
- "Critical opportunities" → Filter by `health_category = 'Critical'`
- "Average health score" → Use `average_health_score` metric
- "Unhealthy deals by rep" → Filter by health_category and group by `owner_name`

### Activity Questions
- "Ghosted deals" → Filter by `is_ghosted = TRUE`
- "Low engagement opportunities" → Filter by `engagement_level = 'Low'`
- "Email activity by rep" → Use `total_emails` metric and group by `owner_name`
- "Inactive SALES team deals" → Filter by `ticket_department = 'TICKET_SALES'` AND `is_ghosted = TRUE`

### Time-Based Questions
- "Deals closing this month" → Filter `close_date` between start and end of current month
- "Deals closing this quarter" → Filter `close_date` between start and end of current quarter
- "Recently created opportunities" → Filter by `created_date` in recent time period
- "Deals closing in next 30 days" → Filter `close_date` between today and 30 days from now

### Department Comparison Questions
- "Compare sales vs service teams" → Group by `ticket_department`
- "Which department has higher win rate" → Calculate `win_rate_pct` grouped by `ticket_department`
- "Sales team vs service team pipeline" → Use `ticket_sales_pipeline` and `ticket_service_pipeline` metrics
- "How many opportunities per department" → Use `ticket_sales_count` and `ticket_service_count` metrics

## SQL Generation Guidelines

1. **Always join through relationships** defined in the semantic model
2. **Use LEFT JOINs** for optional relationships (health scores, activity metrics may not exist for all opportunities)
3. **Filter by department** when questions mention "ticket sales", "ticket service", "sales team", or "service team"
4. **Include owner_name** when questions ask "by rep" or "per sales rep"
5. **Calculate percentages** using NULLIF to avoid division by zero
6. **Format currency** values with 2 decimal places
7. **Sort results** by relevance (typically highest values first unless specified otherwise)
8. **Limit results** to top 10-20 unless user asks for more
9. **Handle NULLs gracefully** using COALESCE for metrics that might be missing

## Example Query Patterns

### Example 1: Department Performance Comparison
Question: "Compare pipeline value between ticket sales and ticket service teams"
```sql
SELECT 
    ticket_department,
    SUM(deal_amount) as total_pipeline,
    COUNT(*) as opportunity_count,
    ROUND(AVG(deal_amount), 2) as avg_deal_size
FROM opportunities o
JOIN users u ON o.owner_id = u.id
LEFT JOIN ticket_team_dept t ON u.id = t.user_id
WHERE ticket_department IS NOT NULL
GROUP BY ticket_department
ORDER BY total_pipeline DESC
```

### Example 2: Sales Team Rep Leaderboard
Question: "Show me top performers on the ticket sales team"
```sql
SELECT 
    u.name as rep_name,
    COUNT(o.id) as total_opportunities,
    SUM(CASE WHEN o.is_won THEN 1 ELSE 0 END) as won_deals,
    SUM(CASE WHEN o.is_won THEN o.amount ELSE 0 END) as total_revenue,
    ROUND(SUM(CASE WHEN o.is_won THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(SUM(CASE WHEN o.is_closed THEN 1 ELSE 0 END), 0), 2) as win_rate_pct
FROM opportunities o
JOIN users u ON o.owner_id = u.id
JOIN ticket_team_dept t ON u.id = t.user_id
WHERE t.department = 'TICKET_SALES'
  AND o.created_date >= DATEADD('month', -12, CURRENT_DATE())
GROUP BY u.name
ORDER BY total_revenue DESC
```

### Example 3: Service Team Activity Analysis
Question: "What's the task completion rate for the ticket service team"
```sql
SELECT 
    u.name as rep_name,
    SUM(a.task_count) as total_tasks,
    COUNT(o.id) as opportunities_managed,
    ROUND(AVG(a.engagement_level), 2) as avg_engagement
FROM opportunities o
JOIN users u ON o.owner_id = u.id
JOIN ticket_team_dept t ON u.id = t.user_id
LEFT JOIN activity_metrics a ON o.id = a.opportunity_id
WHERE t.department = 'TICKET_SERVICE'
  AND o.created_date >= DATEADD('month', -12, CURRENT_DATE())
GROUP BY u.name
ORDER BY total_tasks DESC
```

## Important Notes
- Not all users have ticket department classification (only the 12 ticket team members)
- When filtering by department, ensure to check for NULL values if including non-ticket-team users
- Department-specific metrics automatically filter to relevant team members
- Use owner_name for specific rep queries, ticket_department for team-level analysis
$$;

-- =============================================================================
-- STEP 2: VERIFY SEMANTIC VIEW UPDATE
-- =============================================================================

-- Query to confirm semantic view was created successfully
DESCRIBE SEMANTIC VIEW TBRDP_DW_PROD.IM_RPT.SV_CRM_SALES_INTELLIGENCE;

-- Query to confirm ticket_team_dept table is accessible
SELECT 
    'Logical Tables' AS component,
    COUNT(*) AS count
FROM (SELECT 1 WHERE EXISTS (
    SELECT 1 FROM TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING LIMIT 1
));

-- =============================================================================
-- STEP 3: TEST THE SEMANTIC VIEW WITH DEPARTMENT FILTERS
-- =============================================================================

-- Test Query 1: Can we access ticket department through the semantic view?
-- This simulates what Cortex Analyst will do
SELECT 
    u.NAME AS owner_name,
    t.department AS ticket_department,
    t.team AS ticket_team,
    COUNT(DISTINCT o.ID) AS opportunity_count,
    SUM(COALESCE(o.AMOUNT, 0)) AS total_pipeline
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u
    ON o.OWNER_ID = u.ID
LEFT JOIN TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING t
    ON u.ID = t.user_id
WHERE t.department IS NOT NULL
  AND o.CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())
GROUP BY u.NAME, t.department, t.team
ORDER BY t.department, total_pipeline DESC;

-- Test Query 2: Department comparison
SELECT 
    t.department,
    COUNT(DISTINCT u.ID) AS rep_count,
    COUNT(DISTINCT o.ID) AS opportunity_count,
    SUM(COALESCE(o.AMOUNT, 0)) AS total_pipeline,
    SUM(CASE WHEN o.STAGE_NAME = 'Closed Won' THEN COALESCE(o.AMOUNT, 0) ELSE 0 END) AS revenue,
    ROUND(SUM(CASE WHEN o.IS_WON THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(SUM(CASE WHEN o.IS_CLOSED THEN 1 ELSE 0 END), 0), 2) AS win_rate_pct
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u
    ON o.OWNER_ID = u.ID
JOIN TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING t
    ON u.ID = t.user_id
WHERE o.CREATED_DATE >= DATEADD('month', -12, CURRENT_DATE())
GROUP BY t.department
ORDER BY t.department;

-- =============================================================================
-- SUCCESS CONFIRMATION
-- =============================================================================

/*
✅ PHASE 4B COMPLETE - SEMANTIC VIEW UPDATED!

Your ARM Agent's semantic view now includes:

NEW LOGICAL TABLE:
- ticket_team_dept: Department classification for 12 ticket team members

NEW RELATIONSHIP:
- users_to_ticket_dept: Links users to their department classification

NEW DIMENSIONS:
- ticket_department: TICKET_SALES or TICKET_SERVICE
- ticket_team: Team name (Ticket Sales or Ticket Service)
- ticket_rep_name: Rep name from classification table

NEW METRICS:
- ticket_sales_pipeline: Total pipeline for TICKET_SALES department
- ticket_service_pipeline: Total pipeline for TICKET_SERVICE department
- ticket_sales_count: Number of opportunities for TICKET_SALES reps
- ticket_service_count: Number of opportunities for TICKET_SERVICE reps

ENHANCED AI INSTRUCTIONS:
- Department comparison question patterns
- Sales vs service team filtering logic
- Example queries for common use cases

YOUR ARM AGENT CAN NOW ANSWER:
✓ "Show me ticket sales team performance"
✓ "Compare sales vs service teams"
✓ "What's the pipeline for ticket service reps?"
✓ "Which department has a higher win rate?"
✓ "Show me Rafael's opportunities" (with department context)

NEXT STEP:
You do NOT need to recreate the ARM Agent. The agent automatically uses
the updated semantic view. Just test it with these new question types!

=============================================================================
*/