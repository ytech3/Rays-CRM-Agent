-- =====================================================
-- AUTOMATED TASK: Enrich new emails only
-- Fires every 2 hours, ONLY when stream has new data
-- NOT EXISTS prevents any duplicate processing
-- LIMIT 500 caps each run as cost safety
-- =====================================================
CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    SCHEDULE = '120 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('TBRDP_DW_PROD.IM_RPT.STM_NEW_EMAILS')
AS
INSERT INTO TBRDP_DW_PROD.IM_RPT.T_EMAIL_ENRICHED
SELECT
    sub.EMAIL_ID,
    sub.PARENT_ID,
    sub.ACTIVITY_ID,
    sub.FROM_ADDRESS,
    sub.TO_ADDRESS,
    sub.CC_ADDRESS,
    sub.BCC_ADDRESS,
    sub.SUBJECT,
    sub.TEXT_BODY,
    sub.HTML_BODY,
    sub.MESSAGE_DATE,
    sub.INCOMING,
    sub.STATUS,
    sub.RELATED_TO_ID,
    NULL AS SENTIMENT_SCORE,
    CASE
        WHEN sub.SENTIMENT_RAW >= 0.5 THEN 'Positive'
        WHEN sub.SENTIMENT_RAW >= 0 THEN 'Neutral'
        WHEN sub.SENTIMENT_RAW >= -0.5 THEN 'Slightly Negative'
        ELSE 'Negative'
    END AS SENTIMENT_CATEGORY,
    sub.EMAIL_TOPIC,
    sub.EMAIL_SIGNAL,
    sub.EMAIL_SUMMARY,
    sub.CREATED_DATE,
    sub.SYSTEM_CURRENT_FLAG,
    CURRENT_TIMESTAMP() AS ENRICHMENT_TIMESTAMP
FROM (
    SELECT
        s.ID AS EMAIL_ID,
        s.PARENT_ID,
        s.ACTIVITY_ID,
        s.FROM_ADDRESS,
        s.TO_ADDRESS,
        s.CC_ADDRESS,
        s.BCC_ADDRESS,
        s.SUBJECT,
        s.TEXT_BODY,
        s.HTML_BODY,
        s.MESSAGE_DATE,
        s.INCOMING,
        s.STATUS,
        s.RELATED_TO_ID,
        SNOWFLAKE.CORTEX.SENTIMENT(s.TEXT_BODY) AS SENTIMENT_RAW,
        SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
            s.TEXT_BODY,
            ARRAY_CONSTRUCT(
                'Pricing Discussion', 'Contract Negotiation', 'Product Question',
                'Timeline/Deadline', 'Objection/Concern', 'Follow-up Request',
                'Meeting Request', 'Decision Maker Involved', 'Budget Discussion',
                'Competitor Mention', 'Renewal Discussion', 'Upsell Opportunity'
            )
        ) AS EMAIL_TOPIC,
        SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
            s.TEXT_BODY,
            ARRAY_CONSTRUCT(
                'Urgent Response Needed', 'Contains Unanswered Question',
                'Pricing Concern Mentioned', 'Decision Pending',
                'Positive Buying Signal', 'Risk or Objection Signal',
                'General Communication'
            )
        ) AS EMAIL_SIGNAL,
        SNOWFLAKE.CORTEX.COMPLETE(
            'llama3.1-8b',
            CONCAT(
                'Summarize this sales email in one concise sentence (max 50 words): ',
                SUBSTRING(s.TEXT_BODY, 1, 2000)
            )
        ) AS EMAIL_SUMMARY,
        s.CREATED_DATE,
        s.SYSTEM_CURRENT_FLAG
    FROM TBRDP_DW_PROD.IM_RPT.STM_NEW_EMAILS s
    WHERE s.TEXT_BODY IS NOT NULL
      AND LENGTH(s.TEXT_BODY) > 50
      AND LENGTH(s.TEXT_BODY) < 32000
      AND s.SYSTEM_CURRENT_FLAG = 'Y'
      AND NOT EXISTS (
          SELECT 1 FROM TBRDP_DW_PROD.IM_RPT.T_EMAIL_ENRICHED e
          WHERE e.EMAIL_ID = s.ID
      )
    LIMIT 200
) sub;

-- =====================================================
-- TASK 2: Refresh Opportunity Activity Metrics
-- Pure SQL — no AI functions, negligible cost
-- Runs as child of TSK_ENRICH_NEW_EMAILS
-- Uses MERGE to update existing + insert new opps
--
-- SOURCE: Dimensional model (v_fact_activities + dims)
-- matching Tableau "DM Salesforce Activities Prod"
-- datasource for consistent activity counts.
-- FILTER: 2026 season, Ticketing record type only
-- COUNTD: Uses COUNT(DISTINCT V_FACT_ACTIVITIES_KEY)
-- to match Tableau's COUNTD([ACTIVITY_ID])
-- SENTIMENT: Preserved via v_dim_email_message →
-- T_EMAIL_ENRICHED join path
-- =====================================================
CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_ACTIVITY_METRICS
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    AFTER TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS
AS
MERGE INTO TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS tgt
USING (
    -- -------------------------------------------------------
    -- Activity metrics from dimensional model (matches Tableau)
    -- v_fact_activities is pre-filtered and deduped by ETL
    -- -------------------------------------------------------
    WITH dim_activities AS (
        SELECT
            fact.V_FACT_ACTIVITIES_KEY,
            fact.CALL_DURATION_IN_SECONDS,
            actt.ACTIVITY_SUBTYPE,                           -- Email, Call, Task, ListEmail
            acts.ACTIVITY_STATUS,                            -- Completed, Open, In Progress
            dopps.OPPORTUNITY_ID_BK AS opportunity_id,
            -- Activity date from date dimension (populated for ALL subtypes)
            dad.DIM_DATE_BK AS activity_date,
            -- Email-specific fields from dim_email_message
            dem.ID_BK AS email_id_bk,
            dem.INCOMING AS email_incoming,
            dem.MESSAGE_DATE AS email_message_date
        FROM TBRDP_DW_PROD.IM_RPT.V_FACT_ACTIVITIES fact
        INNER JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_ACTIVITY_TYPE actt
            ON fact.V_DIM_ACTIVITY_TYPE_KEY = actt.V_DIM_ACTIVITY_TYPE_KEY
        LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_ACTIVITY_STATUS acts
            ON fact.V_DIM_ACTIVITY_STATUS_KEY = acts.V_DIM_ACTIVITY_STATUS_KEY
        LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_OPPORTUNITY dopps
            ON fact.V_DIM_OPPORTUNITY_KEY = dopps.V_DIM_OPPORTUNITY_KEY
        -- Join to v_fact_opportunities for season filtering
        INNER JOIN (
            SELECT DISTINCT fopps.V_DIM_OPPORTUNITY_KEY
            FROM TBRDP_DW_PROD.IM_RPT.V_FACT_OPPORTUNITIES fopps
            INNER JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_CRM_SEASON__OPP_SEASON sea
                ON fopps.V_DIM_CRM_SEASON__OPP_SEASON_KEY = sea.V_DIM_CRM_SEASON__OPP_SEASON_KEY
            WHERE sea.NAME = '2026'
        ) opp_season ON dopps.V_DIM_OPPORTUNITY_KEY = opp_season.V_DIM_OPPORTUNITY_KEY
        -- Activity date dimension (has dates for ALL activity subtypes)
        LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_DATE__ACTIVITY_DATE dad
            ON fact.V_DIM_DATE__ACTIVITY_DATE_KEY = dad.V_DIM_DATE__ACTIVITY_DATE_KEY
        -- Email dimension for direction and message date (emails only)
        LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_DIM_EMAIL_MESSAGE dem
            ON fact.V_DIM_EMAIL_MESSAGE_KEY = dem.V_DIM_EMAIL_MESSAGE_KEY
        WHERE dopps.OPPORTUNITY_ID_BK IS NOT NULL
          AND dopps.RECORD_TYPE = 'Ticketing'
    ),
    -- -------------------------------------------------------
    -- Aggregate to opportunity level
    -- -------------------------------------------------------
    activity_agg AS (
        SELECT
            da.opportunity_id,
            -- Total activities (matches Tableau COUNTD)
            COUNT(DISTINCT da.V_FACT_ACTIVITIES_KEY) AS total_activities,
            -- Email metrics
            COUNT(DISTINCT CASE WHEN da.ACTIVITY_SUBTYPE = 'Email' THEN da.V_FACT_ACTIVITIES_KEY END) AS total_emails,
            COUNT(DISTINCT CASE WHEN da.ACTIVITY_SUBTYPE = 'Email' AND da.email_incoming = TRUE THEN da.V_FACT_ACTIVITIES_KEY END) AS incoming_emails,
            COUNT(DISTINCT CASE WHEN da.ACTIVITY_SUBTYPE = 'Email' AND da.email_incoming = FALSE THEN da.V_FACT_ACTIVITIES_KEY END) AS outgoing_emails,
            MAX(CASE WHEN da.ACTIVITY_SUBTYPE = 'Email' THEN da.email_message_date END) AS last_email_date,
            DATEDIFF('day',
                MAX(CASE WHEN da.ACTIVITY_SUBTYPE = 'Email' THEN da.email_message_date END),
                CURRENT_DATE()
            ) AS days_since_last_email,
            -- Call metrics
            COUNT(DISTINCT CASE WHEN da.ACTIVITY_SUBTYPE = 'Call' THEN da.V_FACT_ACTIVITIES_KEY END) AS total_calls,
            SUM(CASE WHEN da.ACTIVITY_SUBTYPE = 'Call' THEN COALESCE(da.CALL_DURATION_IN_SECONDS, 0) ELSE 0 END) AS total_call_duration_seconds,
            AVG(CASE WHEN da.ACTIVITY_SUBTYPE = 'Call' AND da.CALL_DURATION_IN_SECONDS IS NOT NULL THEN da.CALL_DURATION_IN_SECONDS END) AS avg_call_duration_seconds,
            MAX(CASE WHEN da.ACTIVITY_SUBTYPE = 'Call' THEN da.activity_date END) AS last_call_date,
            DATEDIFF('day',
                MAX(CASE WHEN da.ACTIVITY_SUBTYPE = 'Call' THEN da.activity_date END),
                CURRENT_DATE()
            ) AS days_since_last_call,
            COUNT(DISTINCT CASE WHEN da.ACTIVITY_SUBTYPE = 'Call' AND da.ACTIVITY_STATUS = 'Completed' THEN da.V_FACT_ACTIVITIES_KEY END) AS completed_calls,
            COUNT(DISTINCT CASE WHEN da.ACTIVITY_SUBTYPE = 'Call' AND da.ACTIVITY_STATUS != 'Completed' THEN da.V_FACT_ACTIVITIES_KEY END) AS missed_calls,
            -- Task metrics
            COUNT(DISTINCT CASE WHEN da.ACTIVITY_SUBTYPE = 'Task' THEN da.V_FACT_ACTIVITIES_KEY END) AS total_tasks,
            COUNT(DISTINCT CASE WHEN da.ACTIVITY_SUBTYPE = 'Task' AND da.ACTIVITY_STATUS = 'Completed' THEN da.V_FACT_ACTIVITIES_KEY END) AS completed_tasks,
            COUNT(DISTINCT CASE WHEN da.ACTIVITY_SUBTYPE = 'Task' AND da.ACTIVITY_STATUS IN ('Open', 'In Progress') THEN da.V_FACT_ACTIVITIES_KEY END) AS pending_tasks,
            MAX(CASE WHEN da.ACTIVITY_SUBTYPE = 'Task' AND da.ACTIVITY_STATUS = 'Completed' THEN da.activity_date END) AS last_completed_task_date,
            DATEDIFF('day',
                MAX(CASE WHEN da.ACTIVITY_SUBTYPE = 'Task' AND da.ACTIVITY_STATUS = 'Completed' THEN da.activity_date END),
                CURRENT_DATE()
            ) AS days_since_last_completed_task
        FROM dim_activities da
        GROUP BY da.opportunity_id
    ),
    -- -------------------------------------------------------
    -- Task urgency: next task date and overdue count per opp
    -- Source: V_SALESFORCE_TASKS_CURRENT (deduped SCD2)
    -- -------------------------------------------------------
    task_urgency AS (
        SELECT
            t.WHAT_ID AS opportunity_id,
            COUNT(CASE WHEN t.ACTIVITY_DATE < CURRENT_DATE() THEN 1 END) AS overdue_task_count,
            MIN(t.ACTIVITY_DATE) AS next_task_date,
            MIN_BY(t.SUBJECT, t.ACTIVITY_DATE) AS next_task_subject,
            CASE
                WHEN MIN(t.ACTIVITY_DATE) < CURRENT_DATE() THEN 'Overdue'
                WHEN MIN(t.ACTIVITY_DATE) = CURRENT_DATE() THEN 'Due Today'
                WHEN MIN(t.ACTIVITY_DATE) <= DATEADD('day', 7, CURRENT_DATE()) THEN 'Next 7 Days'
                ELSE 'Later'
            END AS task_urgency
        FROM TBRDP_DW_PROD.IM_RPT.V_SALESFORCE_TASKS_CURRENT t
        WHERE t.WHAT_ID IS NOT NULL
          AND t.ACTIVITY_DATE IS NOT NULL
          AND t.IS_CLOSED = FALSE
        GROUP BY t.WHAT_ID
    ),
    -- -------------------------------------------------------
    -- Email sentiment from T_EMAIL_ENRICHED (via dim model)
    -- Join: v_dim_email_message.ID_BK → T_EMAIL_ENRICHED.EMAIL_ID
    -- -------------------------------------------------------
    email_sentiment AS (
        SELECT
            da.opportunity_id,
            AVG(ee.SENTIMENT_SCORE) AS avg_email_sentiment,
            COUNT(CASE WHEN ee.SENTIMENT_CATEGORY = 'Negative' THEN 1 END) AS negative_email_count,
            COUNT(CASE WHEN ee.EMAIL_TOPIC IN ('{"label": "Objection/Concern"}', '{"label": "Competitor Mention"}') THEN 1 END) AS risk_emails
        FROM dim_activities da
        INNER JOIN TBRDP_DW_PROD.IM_RPT.T_EMAIL_ENRICHED ee
            ON da.email_id_bk = ee.EMAIL_ID
        WHERE da.ACTIVITY_SUBTYPE = 'Email'
          AND da.email_id_bk IS NOT NULL
        GROUP BY da.opportunity_id
    )
    -- -------------------------------------------------------
    -- Final SELECT: join opportunity details with activity agg
    -- -------------------------------------------------------
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
        COALESCE(aa.total_activities, 0) AS total_activities,
        COALESCE(aa.total_emails, 0) AS total_emails,
        COALESCE(aa.incoming_emails, 0) AS incoming_emails,
        COALESCE(aa.outgoing_emails, 0) AS outgoing_emails,
        aa.last_email_date,
        COALESCE(aa.days_since_last_email, 9999) AS days_since_last_email,
        COALESCE(es.avg_email_sentiment, 0) AS avg_email_sentiment,
        COALESCE(es.negative_email_count, 0) AS negative_email_count,
        COALESCE(es.risk_emails, 0) AS risk_emails,
        COALESCE(aa.total_calls, 0) AS total_calls,
        COALESCE(aa.total_call_duration_seconds, 0) AS total_call_duration_seconds,
        COALESCE(aa.avg_call_duration_seconds, 0) AS avg_call_duration_seconds,
        aa.last_call_date,
        COALESCE(aa.days_since_last_call, 9999) AS days_since_last_call,
        COALESCE(aa.completed_calls, 0) AS completed_calls,
        COALESCE(aa.missed_calls, 0) AS missed_calls,
        COALESCE(aa.total_tasks, 0) AS total_tasks,
        COALESCE(aa.completed_tasks, 0) AS completed_tasks,
        COALESCE(aa.pending_tasks, 0) AS pending_tasks,
        aa.last_completed_task_date,
        COALESCE(aa.days_since_last_completed_task, 9999) AS days_since_last_completed_task,
        -- Task urgency columns
        COALESCE(tu.overdue_task_count, 0) AS overdue_task_count,
        tu.next_task_date,
        tu.next_task_subject,
        COALESCE(tu.task_urgency, 'No Open Tasks') AS task_urgency,
        CASE
            WHEN COALESCE(aa.days_since_last_email, 9999) <= 7
             AND COALESCE(aa.days_since_last_call, 9999) <= 14
             AND COALESCE(es.avg_email_sentiment, 0) > 0
            THEN 'High Engagement'
            WHEN COALESCE(aa.days_since_last_email, 9999) <= 30
              OR COALESCE(aa.days_since_last_call, 9999) <= 30
            THEN 'Medium Engagement'
            ELSE 'Low Engagement'
        END AS engagement_level,
        CASE
            WHEN COALESCE(aa.days_since_last_email, 9999) > 60
             AND COALESCE(aa.days_since_last_call, 9999) > 60
            THEN TRUE ELSE FALSE
        END AS is_ghosted,
        CASE
            WHEN COALESCE(es.negative_email_count, 0) > 2
              OR COALESCE(es.risk_emails, 0) > 1
            THEN TRUE ELSE FALSE
        END AS has_sentiment_risk,
        CURRENT_TIMESTAMP() AS metrics_timestamp
    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
    INNER JOIN activity_agg aa ON o.ID = aa.opportunity_id
    LEFT JOIN email_sentiment es ON o.ID = es.opportunity_id
    LEFT JOIN task_urgency tu ON o.ID = tu.opportunity_id
    WHERE o.SYSTEM_CURRENT_FLAG = 'Y'
) src
ON tgt.OPPORTUNITY_ID = src.opportunity_id
WHEN MATCHED THEN UPDATE SET
    tgt.OPPORTUNITY_NAME = src.opportunity_name,
    tgt.ACCOUNT_ID = src.account_id,
    tgt.OWNER_ID = src.owner_id,
    tgt.STAGE_NAME = src.stage_name,
    tgt.AMOUNT = src.amount,
    tgt.EST_REVENUE_C = src.est_revenue_c,
    tgt.PROBABILITY = src.probability,
    tgt.CLOSE_DATE = src.close_date,
    tgt.TOTAL_ACTIVITIES = src.total_activities,
    tgt.TOTAL_EMAILS = src.total_emails,
    tgt.INCOMING_EMAILS = src.incoming_emails,
    tgt.OUTGOING_EMAILS = src.outgoing_emails,
    tgt.LAST_EMAIL_DATE = src.last_email_date,
    tgt.DAYS_SINCE_LAST_EMAIL = src.days_since_last_email,
    tgt.AVG_EMAIL_SENTIMENT = src.avg_email_sentiment,
    tgt.NEGATIVE_EMAIL_COUNT = src.negative_email_count,
    tgt.RISK_EMAILS = src.risk_emails,
    tgt.TOTAL_CALLS = src.total_calls,
    tgt.TOTAL_CALL_DURATION_SECONDS = src.total_call_duration_seconds,
    tgt.AVG_CALL_DURATION_SECONDS = src.avg_call_duration_seconds,
    tgt.LAST_CALL_DATE = src.last_call_date,
    tgt.DAYS_SINCE_LAST_CALL = src.days_since_last_call,
    tgt.COMPLETED_CALLS = src.completed_calls,
    tgt.MISSED_CALLS = src.missed_calls,
    tgt.TOTAL_TASKS = src.total_tasks,
    tgt.COMPLETED_TASKS = src.completed_tasks,
    tgt.PENDING_TASKS = src.pending_tasks,
    tgt.LAST_COMPLETED_TASK_DATE = src.last_completed_task_date,
    tgt.DAYS_SINCE_LAST_COMPLETED_TASK = src.days_since_last_completed_task,
    tgt.ENGAGEMENT_LEVEL = src.engagement_level,
    tgt.IS_GHOSTED = src.is_ghosted,
    tgt.HAS_SENTIMENT_RISK = src.has_sentiment_risk,
    tgt.OVERDUE_TASK_COUNT = src.overdue_task_count,
    tgt.NEXT_TASK_DATE = src.next_task_date,
    tgt.NEXT_TASK_SUBJECT = src.next_task_subject,
    tgt.TASK_URGENCY = src.task_urgency,
    tgt.METRICS_TIMESTAMP = src.metrics_timestamp
WHEN NOT MATCHED THEN INSERT (
    OPPORTUNITY_ID, OPPORTUNITY_NAME, ACCOUNT_ID, OWNER_ID, STAGE_NAME,
    AMOUNT, EST_REVENUE_C, PROBABILITY, CLOSE_DATE, CREATED_DATE,
    TOTAL_ACTIVITIES,
    TOTAL_EMAILS, INCOMING_EMAILS, OUTGOING_EMAILS, LAST_EMAIL_DATE,
    DAYS_SINCE_LAST_EMAIL, AVG_EMAIL_SENTIMENT, NEGATIVE_EMAIL_COUNT, RISK_EMAILS,
    TOTAL_CALLS, TOTAL_CALL_DURATION_SECONDS, AVG_CALL_DURATION_SECONDS,
    LAST_CALL_DATE, DAYS_SINCE_LAST_CALL, COMPLETED_CALLS, MISSED_CALLS,
    TOTAL_TASKS, COMPLETED_TASKS, PENDING_TASKS, LAST_COMPLETED_TASK_DATE,
    DAYS_SINCE_LAST_COMPLETED_TASK, ENGAGEMENT_LEVEL, IS_GHOSTED,
    HAS_SENTIMENT_RISK, OVERDUE_TASK_COUNT, NEXT_TASK_DATE, NEXT_TASK_SUBJECT,
    TASK_URGENCY, METRICS_TIMESTAMP
) VALUES (
    src.opportunity_id, src.opportunity_name, src.account_id, src.owner_id, src.stage_name,
    src.amount, src.est_revenue_c, src.probability, src.close_date, src.created_date,
    src.total_activities,
    src.total_emails, src.incoming_emails, src.outgoing_emails, src.last_email_date,
    src.days_since_last_email, src.avg_email_sentiment, src.negative_email_count, src.risk_emails,
    src.total_calls, src.total_call_duration_seconds, src.avg_call_duration_seconds,
    src.last_call_date, src.days_since_last_call, src.completed_calls, src.missed_calls,
    src.total_tasks, src.completed_tasks, src.pending_tasks, src.last_completed_task_date,
    src.days_since_last_completed_task, src.engagement_level, src.is_ghosted,
    src.has_sentiment_risk, src.overdue_task_count, src.next_task_date, src.next_task_subject,
    src.task_urgency, src.metrics_timestamp
);

-- =====================================================
-- TASK 3: Refresh Deal Health Scores
-- Runs after activity metrics refresh
-- MERGE: updates existing scores, inserts new opps
-- AI calls: 2x COMPLETE per row (assessment + action)
-- Cost safety: only open opportunities
-- =====================================================
-- =====================================================
-- TASK 3 (OPTIMIZED): Refresh Deal Health Scores
-- Only rescores opps with changed activity metrics
-- Single AI call per row (assessment only, no next action)
-- =====================================================
CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_DEAL_HEALTH
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    AFTER TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_ACTIVITY_METRICS
AS
MERGE INTO TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE tgt
USING (
    WITH deal_context AS (
        SELECT 
            oam.OPPORTUNITY_ID,
            oam.OPPORTUNITY_NAME,
            oam.STAGE_NAME,
            oam.AMOUNT,
            oam.PROBABILITY,
            oam.CLOSE_DATE,
            DATEDIFF('day', CURRENT_DATE(), oam.CLOSE_DATE) AS days_until_close,
            oam.TOTAL_EMAILS,
            oam.TOTAL_CALLS,
            oam.DAYS_SINCE_LAST_EMAIL,
            oam.DAYS_SINCE_LAST_CALL,
            oam.AVG_EMAIL_SENTIMENT,
            oam.ENGAGEMENT_LEVEL,
            oam.IS_GHOSTED,
            oam.HAS_SENTIMENT_RISK,
            oam.OVERDUE_TASK_COUNT,
            oam.NEXT_TASK_DATE,
            oam.TASK_URGENCY,
            oam.METRICS_TIMESTAMP
        FROM TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS oam
        JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
            ON oam.OPPORTUNITY_ID = o.ID
        LEFT JOIN TBRDP_DW_PROD.IM_RPT.T_DEAL_HEALTH_SCORE dh
            ON oam.OPPORTUNITY_ID = dh.OPPORTUNITY_ID
        WHERE o.SYSTEM_CURRENT_FLAG = 'Y'
          AND o.IS_CLOSED = FALSE
          AND o.STAGE_NAME IN ('Initial Conversation', 'In-Contact')
          -- ONLY opps where activity metrics are newer than last scoring
          AND oam.METRICS_TIMESTAMP > COALESCE(dh.SCORING_TIMESTAMP, '1900-01-01'::TIMESTAMP)
    )
    SELECT 
        OPPORTUNITY_ID,
        OPPORTUNITY_NAME,
        STAGE_NAME,
        AMOUNT,
        PROBABILITY,
        CLOSE_DATE,
        days_until_close,
        TOTAL_EMAILS,
        TOTAL_CALLS,
        DAYS_SINCE_LAST_EMAIL,
        DAYS_SINCE_LAST_CALL,
        AVG_EMAIL_SENTIMENT,
        ENGAGEMENT_LEVEL,
        IS_GHOSTED,
        HAS_SENTIMENT_RISK,
        OVERDUE_TASK_COUNT,
        NEXT_TASK_DATE,
        TASK_URGENCY,

        GREATEST(0, LEAST(100,
            50
            + CASE WHEN ENGAGEMENT_LEVEL = 'High Engagement' THEN 20
                   WHEN ENGAGEMENT_LEVEL = 'Medium Engagement' THEN 5
                   ELSE -15 END
            + (COALESCE(AVG_EMAIL_SENTIMENT, 0) * 15)
            + CASE WHEN COALESCE(DAYS_SINCE_LAST_EMAIL, 9999) <= 7 THEN 10
                   WHEN COALESCE(DAYS_SINCE_LAST_EMAIL, 9999) <= 30 THEN 5
                   ELSE -10 END
            + CASE WHEN IS_GHOSTED = TRUE THEN -30 ELSE 0 END
            + CASE WHEN HAS_SENTIMENT_RISK = TRUE THEN -20 ELSE 0 END
            + CASE WHEN days_until_close < 30 AND COALESCE(TOTAL_EMAILS, 0) > 5 THEN 10 ELSE 0 END
            -- Task urgency adjustments (primary urgency signal)
            + CASE WHEN TASK_URGENCY = 'Overdue' AND OVERDUE_TASK_COUNT >= 3 THEN -25
                   WHEN TASK_URGENCY = 'Overdue' THEN -15
                   WHEN TASK_URGENCY = 'Due Today' THEN -5
                   WHEN TASK_URGENCY = 'Next 7 Days' THEN 0
                   WHEN TASK_URGENCY = 'No Open Tasks' AND ENGAGEMENT_LEVEL = 'Low Engagement' THEN -10
                   ELSE 0 END
        )) AS HEALTH_SCORE,

        CASE 
            WHEN GREATEST(0, LEAST(100,
                50
                + CASE WHEN ENGAGEMENT_LEVEL = 'High Engagement' THEN 20
                       WHEN ENGAGEMENT_LEVEL = 'Medium Engagement' THEN 5
                       ELSE -15 END
                + (COALESCE(AVG_EMAIL_SENTIMENT, 0) * 15)
                + CASE WHEN COALESCE(DAYS_SINCE_LAST_EMAIL, 9999) <= 7 THEN 10
                       WHEN COALESCE(DAYS_SINCE_LAST_EMAIL, 9999) <= 30 THEN 5
                       ELSE -10 END
                + CASE WHEN IS_GHOSTED = TRUE THEN -30 ELSE 0 END
                + CASE WHEN HAS_SENTIMENT_RISK = TRUE THEN -20 ELSE 0 END
                + CASE WHEN days_until_close < 30 AND COALESCE(TOTAL_EMAILS, 0) > 5 THEN 10 ELSE 0 END
                + CASE WHEN TASK_URGENCY = 'Overdue' AND OVERDUE_TASK_COUNT >= 3 THEN -25
                       WHEN TASK_URGENCY = 'Overdue' THEN -15
                       WHEN TASK_URGENCY = 'Due Today' THEN -5
                       WHEN TASK_URGENCY = 'Next 7 Days' THEN 0
                       WHEN TASK_URGENCY = 'No Open Tasks' AND ENGAGEMENT_LEVEL = 'Low Engagement' THEN -10
                       ELSE 0 END
            )) >= 70 THEN 'Healthy'
            WHEN GREATEST(0, LEAST(100,
                50
                + CASE WHEN ENGAGEMENT_LEVEL = 'High Engagement' THEN 20
                       WHEN ENGAGEMENT_LEVEL = 'Medium Engagement' THEN 5
                       ELSE -15 END
                + (COALESCE(AVG_EMAIL_SENTIMENT, 0) * 15)
                + CASE WHEN COALESCE(DAYS_SINCE_LAST_EMAIL, 9999) <= 7 THEN 10
                       WHEN COALESCE(DAYS_SINCE_LAST_EMAIL, 9999) <= 30 THEN 5
                       ELSE -10 END
                + CASE WHEN IS_GHOSTED = TRUE THEN -30 ELSE 0 END
                + CASE WHEN HAS_SENTIMENT_RISK = TRUE THEN -20 ELSE 0 END
                + CASE WHEN days_until_close < 30 AND COALESCE(TOTAL_EMAILS, 0) > 5 THEN 10 ELSE 0 END
                + CASE WHEN TASK_URGENCY = 'Overdue' AND OVERDUE_TASK_COUNT >= 3 THEN -25
                       WHEN TASK_URGENCY = 'Overdue' THEN -15
                       WHEN TASK_URGENCY = 'Due Today' THEN -5
                       WHEN TASK_URGENCY = 'Next 7 Days' THEN 0
                       WHEN TASK_URGENCY = 'No Open Tasks' AND ENGAGEMENT_LEVEL = 'Low Engagement' THEN -10
                       ELSE 0 END
            )) >= 40 THEN 'At Risk'
            ELSE 'Critical'
        END AS HEALTH_CATEGORY,

        -- Single AI call: Deal Assessment only
        SNOWFLAKE.CORTEX.COMPLETE(
            'llama3.1-8b',
            CONCAT(
                'Analyze this sales opportunity and provide a 2-sentence assessment with risks and recommended next action. ',
                'Deal: ', COALESCE(OPPORTUNITY_NAME, 'Unknown'), '. ',
                'Stage: ', COALESCE(STAGE_NAME, 'Unknown'), '. ',
                'Value: $', COALESCE(CAST(AMOUNT AS VARCHAR), '0'), '. ',
                'Days to close: ', COALESCE(CAST(days_until_close AS VARCHAR), 'Unknown'), '. ',
                'Last email contact: ', COALESCE(CAST(DAYS_SINCE_LAST_EMAIL AS VARCHAR), 'Unknown'), ' days ago. ',
                'Email sentiment: ', COALESCE(CAST(ROUND(AVG_EMAIL_SENTIMENT, 2) AS VARCHAR), '0'), '. ',
                'Engagement: ', COALESCE(ENGAGEMENT_LEVEL, 'Unknown'), '. ',
                'Task urgency: ', COALESCE(TASK_URGENCY, 'No Open Tasks'), '. ',
                'Overdue tasks: ', CAST(COALESCE(OVERDUE_TASK_COUNT, 0) AS VARCHAR), '. ',
                CASE WHEN NEXT_TASK_DATE IS NOT NULL THEN CONCAT('Next task due: ', CAST(NEXT_TASK_DATE AS VARCHAR), '. ') ELSE '' END,
                CASE WHEN IS_GHOSTED = TRUE THEN 'WARNING: Customer is not responding. ' ELSE '' END,
                CASE WHEN HAS_SENTIMENT_RISK = TRUE THEN 'WARNING: Negative sentiment detected. ' ELSE '' END,
                CASE WHEN TASK_URGENCY = 'Overdue' THEN 'PRIORITY: Overdue tasks require immediate attention. ' ELSE '' END
            )
        ) AS AI_DEAL_ASSESSMENT,

        CURRENT_TIMESTAMP() AS SCORING_TIMESTAMP

    FROM deal_context
) src
ON tgt.OPPORTUNITY_ID = src.OPPORTUNITY_ID
WHEN MATCHED THEN UPDATE SET
    tgt.OPPORTUNITY_NAME = src.OPPORTUNITY_NAME,
    tgt.STAGE_NAME = src.STAGE_NAME,
    tgt.AMOUNT = src.AMOUNT,
    tgt.PROBABILITY = src.PROBABILITY,
    tgt.CLOSE_DATE = src.CLOSE_DATE,
    tgt.DAYS_UNTIL_CLOSE = src.days_until_close,
    tgt.TOTAL_EMAILS = src.TOTAL_EMAILS,
    tgt.TOTAL_CALLS = src.TOTAL_CALLS,
    tgt.DAYS_SINCE_LAST_EMAIL = src.DAYS_SINCE_LAST_EMAIL,
    tgt.DAYS_SINCE_LAST_CALL = src.DAYS_SINCE_LAST_CALL,
    tgt.AVG_EMAIL_SENTIMENT = src.AVG_EMAIL_SENTIMENT,
    tgt.ENGAGEMENT_LEVEL = src.ENGAGEMENT_LEVEL,
    tgt.IS_GHOSTED = src.IS_GHOSTED,
    tgt.HAS_SENTIMENT_RISK = src.HAS_SENTIMENT_RISK,
    tgt.OVERDUE_TASK_COUNT = src.OVERDUE_TASK_COUNT,
    tgt.NEXT_TASK_DATE = src.NEXT_TASK_DATE,
    tgt.TASK_URGENCY = src.TASK_URGENCY,
    tgt.HEALTH_SCORE = src.HEALTH_SCORE,
    tgt.HEALTH_CATEGORY = src.HEALTH_CATEGORY,
    tgt.AI_DEAL_ASSESSMENT = src.AI_DEAL_ASSESSMENT,
    tgt.SCORING_TIMESTAMP = src.SCORING_TIMESTAMP
WHEN NOT MATCHED THEN INSERT (
    OPPORTUNITY_ID, OPPORTUNITY_NAME, STAGE_NAME, AMOUNT, PROBABILITY,
    CLOSE_DATE, DAYS_UNTIL_CLOSE, TOTAL_EMAILS, TOTAL_CALLS,
    DAYS_SINCE_LAST_EMAIL, DAYS_SINCE_LAST_CALL, AVG_EMAIL_SENTIMENT,
    ENGAGEMENT_LEVEL, IS_GHOSTED, HAS_SENTIMENT_RISK,
    OVERDUE_TASK_COUNT, NEXT_TASK_DATE, TASK_URGENCY,
    HEALTH_SCORE, HEALTH_CATEGORY, AI_DEAL_ASSESSMENT,
    SCORING_TIMESTAMP
) VALUES (
    src.OPPORTUNITY_ID, src.OPPORTUNITY_NAME, src.STAGE_NAME, src.AMOUNT, src.PROBABILITY,
    src.CLOSE_DATE, src.days_until_close, src.TOTAL_EMAILS, src.TOTAL_CALLS,
    src.DAYS_SINCE_LAST_EMAIL, src.DAYS_SINCE_LAST_CALL, src.AVG_EMAIL_SENTIMENT,
    src.ENGAGEMENT_LEVEL, src.IS_GHOSTED, src.HAS_SENTIMENT_RISK,
    src.OVERDUE_TASK_COUNT, src.NEXT_TASK_DATE, src.TASK_URGENCY,
    src.HEALTH_SCORE, src.HEALTH_CATEGORY, src.AI_DEAL_ASSESSMENT,
    src.SCORING_TIMESTAMP
);

-- TSK_REFRESH_CUSTOMER_360 permanently removed 2026-06-05. DROP TASK executed in Snowflake.