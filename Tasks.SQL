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

    SNOWFLAKE.CORTEX.SENTIMENT(s.TEXT_BODY) AS SENTIMENT_SCORE,

    CASE 
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(s.TEXT_BODY) >= 0.5 THEN 'Positive'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(s.TEXT_BODY) >= 0 THEN 'Neutral'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(s.TEXT_BODY) >= -0.5 THEN 'Slightly Negative'
        ELSE 'Negative'
    END AS SENTIMENT_CATEGORY,

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
        'llama3.1-70b',
        CONCAT(
            'Summarize this sales email in one concise sentence (max 50 words): ',
            SUBSTRING(s.TEXT_BODY, 1, 2000)
        )
    ) AS EMAIL_SUMMARY,

    s.CREATED_DATE,
    s.SYSTEM_CURRENT_FLAG,
    CURRENT_TIMESTAMP() AS ENRICHMENT_TIMESTAMP

FROM TBRDP_DW_PROD.IM_RPT.STM_NEW_EMAILS s
WHERE s.TEXT_BODY IS NOT NULL
  AND LENGTH(s.TEXT_BODY) > 50
  AND LENGTH(s.TEXT_BODY) < 32000
  AND s.SYSTEM_CURRENT_FLAG = 'Y'
  AND NOT EXISTS (
      SELECT 1 FROM TBRDP_DW_PROD.IM_RPT.T_EMAIL_ENRICHED e
      WHERE e.EMAIL_ID = s.ID
  )
LIMIT 500;

-- =====================================================
-- TASK 2: Refresh Opportunity Activity Metrics
-- Pure SQL — no AI functions, negligible cost
-- Runs as child of TSK_ENRICH_NEW_EMAILS
-- Uses MERGE to update existing + insert new opps
-- =====================================================
CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_ACTIVITY_METRICS
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    AFTER TBRDP_DW_PROD.IM_RPT.TSK_ENRICH_NEW_EMAILS
AS
MERGE INTO TBRDP_DW_PROD.IM_RPT.T_OPPORTUNITY_ACTIVITY_METRICS tgt
USING (
    WITH email_metrics AS (
        SELECT 
            e.RELATED_TO_ID AS opportunity_id,
            COUNT(*) AS total_emails,
            COUNT(CASE WHEN e.INCOMING = TRUE THEN 1 END) AS incoming_emails,
            COUNT(CASE WHEN e.INCOMING = FALSE THEN 1 END) AS outgoing_emails,
            MAX(e.MESSAGE_DATE) AS last_email_date,
            DATEDIFF('day', MAX(e.MESSAGE_DATE), CURRENT_DATE()) AS days_since_last_email,
            AVG(ee.SENTIMENT_SCORE) AS avg_email_sentiment,
            COUNT(CASE WHEN ee.SENTIMENT_CATEGORY = 'Negative' THEN 1 END) AS negative_email_count,
            COUNT(CASE WHEN ee.EMAIL_TOPIC IN ('{"label": "Objection/Concern"}', '{"label": "Competitor Mention"}') THEN 1 END) AS risk_emails
        FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE e
        LEFT JOIN TBRDP_DW_PROD.IM_RPT.T_EMAIL_ENRICHED ee
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
        COALESCE(em.total_emails, 0) AS total_emails,
        COALESCE(em.incoming_emails, 0) AS incoming_emails,
        COALESCE(em.outgoing_emails, 0) AS outgoing_emails,
        em.last_email_date,
        COALESCE(em.days_since_last_email, 9999) AS days_since_last_email,
        COALESCE(em.avg_email_sentiment, 0) AS avg_email_sentiment,
        COALESCE(em.negative_email_count, 0) AS negative_email_count,
        COALESCE(em.risk_emails, 0) AS risk_emails,
        COALESCE(cm.total_calls, 0) AS total_calls,
        COALESCE(cm.total_call_duration_seconds, 0) AS total_call_duration_seconds,
        COALESCE(cm.avg_call_duration_seconds, 0) AS avg_call_duration_seconds,
        cm.last_call_date,
        COALESCE(cm.days_since_last_call, 9999) AS days_since_last_call,
        COALESCE(cm.completed_calls, 0) AS completed_calls,
        COALESCE(cm.missed_calls, 0) AS missed_calls,
        COALESCE(tm.total_tasks, 0) AS total_tasks,
        COALESCE(tm.completed_tasks, 0) AS completed_tasks,
        COALESCE(tm.pending_tasks, 0) AS pending_tasks,
        tm.last_completed_task_date,
        COALESCE(tm.days_since_last_completed_task, 9999) AS days_since_last_completed_task,
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
        CURRENT_TIMESTAMP() AS metrics_timestamp
    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
    LEFT JOIN email_metrics em ON o.ID = em.opportunity_id
    LEFT JOIN call_metrics cm ON o.ID = cm.opportunity_id
    LEFT JOIN task_metrics tm ON o.ID = tm.opportunity_id
    WHERE o.SYSTEM_CURRENT_FLAG = 'Y'
      AND o.IS_CLOSED = FALSE
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
    tgt.METRICS_TIMESTAMP = src.metrics_timestamp
WHEN NOT MATCHED THEN INSERT (
    OPPORTUNITY_ID, OPPORTUNITY_NAME, ACCOUNT_ID, OWNER_ID, STAGE_NAME,
    AMOUNT, EST_REVENUE_C, PROBABILITY, CLOSE_DATE, CREATED_DATE,
    TOTAL_EMAILS, INCOMING_EMAILS, OUTGOING_EMAILS, LAST_EMAIL_DATE,
    DAYS_SINCE_LAST_EMAIL, AVG_EMAIL_SENTIMENT, NEGATIVE_EMAIL_COUNT, RISK_EMAILS,
    TOTAL_CALLS, TOTAL_CALL_DURATION_SECONDS, AVG_CALL_DURATION_SECONDS,
    LAST_CALL_DATE, DAYS_SINCE_LAST_CALL, COMPLETED_CALLS, MISSED_CALLS,
    TOTAL_TASKS, COMPLETED_TASKS, PENDING_TASKS, LAST_COMPLETED_TASK_DATE,
    DAYS_SINCE_LAST_COMPLETED_TASK, ENGAGEMENT_LEVEL, IS_GHOSTED,
    HAS_SENTIMENT_RISK, METRICS_TIMESTAMP
) VALUES (
    src.opportunity_id, src.opportunity_name, src.account_id, src.owner_id, src.stage_name,
    src.amount, src.est_revenue_c, src.probability, src.close_date, src.created_date,
    src.total_emails, src.incoming_emails, src.outgoing_emails, src.last_email_date,
    src.days_since_last_email, src.avg_email_sentiment, src.negative_email_count, src.risk_emails,
    src.total_calls, src.total_call_duration_seconds, src.avg_call_duration_seconds,
    src.last_call_date, src.days_since_last_call, src.completed_calls, src.missed_calls,
    src.total_tasks, src.completed_tasks, src.pending_tasks, src.last_completed_task_date,
    src.days_since_last_completed_task, src.engagement_level, src.is_ghosted,
    src.has_sentiment_risk, src.metrics_timestamp
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
            )) >= 40 THEN 'At Risk'
            ELSE 'Critical'
        END AS HEALTH_CATEGORY,

        -- Single AI call: Deal Assessment only
        SNOWFLAKE.CORTEX.COMPLETE(
            'llama3.1-70b',
            CONCAT(
                'Analyze this sales opportunity and provide a 2-sentence assessment with risks and recommended next action. ',
                'Deal: ', COALESCE(OPPORTUNITY_NAME, 'Unknown'), '. ',
                'Stage: ', COALESCE(STAGE_NAME, 'Unknown'), '. ',
                'Value: $', COALESCE(CAST(AMOUNT AS VARCHAR), '0'), '. ',
                'Days to close: ', COALESCE(CAST(days_until_close AS VARCHAR), 'Unknown'), '. ',
                'Last email contact: ', COALESCE(CAST(DAYS_SINCE_LAST_EMAIL AS VARCHAR), 'Unknown'), ' days ago. ',
                'Email sentiment: ', COALESCE(CAST(ROUND(AVG_EMAIL_SENTIMENT, 2) AS VARCHAR), '0'), '. ',
                'Engagement: ', COALESCE(ENGAGEMENT_LEVEL, 'Unknown'), '. ',
                CASE WHEN IS_GHOSTED = TRUE THEN 'WARNING: Customer is not responding. ' ELSE '' END,
                CASE WHEN HAS_SENTIMENT_RISK = TRUE THEN 'WARNING: Negative sentiment detected. ' ELSE '' END
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
    tgt.HEALTH_SCORE = src.HEALTH_SCORE,
    tgt.HEALTH_CATEGORY = src.HEALTH_CATEGORY,
    tgt.AI_DEAL_ASSESSMENT = src.AI_DEAL_ASSESSMENT,
    tgt.SCORING_TIMESTAMP = src.SCORING_TIMESTAMP
WHEN NOT MATCHED THEN INSERT (
    OPPORTUNITY_ID, OPPORTUNITY_NAME, STAGE_NAME, AMOUNT, PROBABILITY,
    CLOSE_DATE, DAYS_UNTIL_CLOSE, TOTAL_EMAILS, TOTAL_CALLS,
    DAYS_SINCE_LAST_EMAIL, DAYS_SINCE_LAST_CALL, AVG_EMAIL_SENTIMENT,
    ENGAGEMENT_LEVEL, IS_GHOSTED, HAS_SENTIMENT_RISK,
    HEALTH_SCORE, HEALTH_CATEGORY, AI_DEAL_ASSESSMENT,
    SCORING_TIMESTAMP
) VALUES (
    src.OPPORTUNITY_ID, src.OPPORTUNITY_NAME, src.STAGE_NAME, src.AMOUNT, src.PROBABILITY,
    src.CLOSE_DATE, src.days_until_close, src.TOTAL_EMAILS, src.TOTAL_CALLS,
    src.DAYS_SINCE_LAST_EMAIL, src.DAYS_SINCE_LAST_CALL, src.AVG_EMAIL_SENTIMENT,
    src.ENGAGEMENT_LEVEL, src.IS_GHOSTED, src.HAS_SENTIMENT_RISK,
    src.HEALTH_SCORE, src.HEALTH_CATEGORY, src.AI_DEAL_ASSESSMENT,
    src.SCORING_TIMESTAMP
);

-- =====================================================
-- TASK 4: Refresh Customer 360
-- Pure SQL — no AI functions, negligible cost
-- Runs after activity metrics refresh
-- Full MERGE on account-level aggregations
-- =====================================================
CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_CUSTOMER_360
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    AFTER TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_ACTIVITY_METRICS
AS
CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_CUSTOMER_360 AS
WITH 
opp_summary AS (
    SELECT 
        opp.ACCOUNT_ID,
        COUNT(DISTINCT opp.ID) AS total_opportunities,
        COUNT(DISTINCT CASE WHEN opp.IS_WON = TRUE THEN opp.ID END) AS won_opportunities,
        COUNT(DISTINCT CASE WHEN opp.IS_CLOSED = TRUE AND opp.IS_WON = FALSE THEN opp.ID END) AS lost_opportunities,
        COUNT(DISTINCT CASE WHEN opp.IS_CLOSED = FALSE THEN opp.ID END) AS open_opportunities,
        SUM(CASE WHEN opp.IS_WON = TRUE THEN COALESCE(opp.AMOUNT, 0) ELSE 0 END) AS crm_won_revenue,
        SUM(CASE WHEN opp.IS_CLOSED = FALSE THEN COALESCE(opp.AMOUNT, 0) ELSE 0 END) AS crm_open_pipeline,
        SUM(COALESCE(opp.AMOUNT, 0)) AS crm_total_pipeline,
        CASE 
            WHEN COUNT(DISTINCT CASE WHEN opp.IS_CLOSED = TRUE THEN opp.ID END) > 0
            THEN ROUND(
                COUNT(DISTINCT CASE WHEN opp.IS_WON = TRUE THEN opp.ID END) * 100.0 / 
                COUNT(DISTINCT CASE WHEN opp.IS_CLOSED = TRUE THEN opp.ID END), 2
            )
            ELSE NULL
        END AS win_rate_pct,
        MIN(opp.CREATED_DATE) AS first_opportunity_date,
        MAX(opp.CREATED_DATE) AS latest_opportunity_date,
        MIN(CASE WHEN opp.IS_WON = TRUE THEN opp.CLOSE_DATE END) AS first_won_date,
        MAX(CASE WHEN opp.IS_WON = TRUE THEN opp.CLOSE_DATE END) AS latest_won_date,
        LISTAGG(DISTINCT opp.TICKET_TYPE_C, ', ') WITHIN GROUP (ORDER BY opp.TICKET_TYPE_C) AS crm_ticket_types,
        LISTAGG(DISTINCT opp.SEASON_C, ', ') WITHIN GROUP (ORDER BY opp.SEASON_C) AS crm_seasons,
        MAX_BY(opp.OWNER_ID, opp.CREATED_DATE) AS current_owner_id
    FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY opp
    WHERE opp.SYSTEM_CURRENT_FLAG = 'Y'
      AND opp.IS_DELETED = FALSE
      AND opp.ACCOUNT_ID IS NOT NULL
    GROUP BY opp.ACCOUNT_ID
),
ticket_summary AS (
    SELECT 
        ts.FINANCIAL_PATRON_ACCOUNT_ID AS patron_id,
        COUNT(*) AS total_ticket_purchases,
        COUNT(DISTINCT ts.EVENT_ID) AS unique_events_attended,
        SUM(COALESCE(ts.PRICE, 0)) AS total_ticket_revenue,
        SUM(COALESCE(ts.PAID_AMOUNT, 0)) AS total_paid_amount,
        ROUND(AVG(COALESCE(ts.PRICE, 0)), 2) AS avg_ticket_price,
        MAX(COALESCE(ts.PRICE, 0)) AS max_ticket_price,
        COUNT(DISTINCT ts.SEASON_YEAR) AS seasons_purchased,
        LISTAGG(DISTINCT CAST(ts.SEASON_YEAR AS VARCHAR), ', ') 
            WITHIN GROUP (ORDER BY CAST(ts.SEASON_YEAR AS VARCHAR)) AS purchase_seasons,
        LISTAGG(DISTINCT ts.TICKET_TYPE_GROUPING, ', ') 
            WITHIN GROUP (ORDER BY ts.TICKET_TYPE_GROUPING) AS ticket_types_purchased,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Traditional Seasons' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS season_ticket_revenue,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Single Game' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS single_game_revenue,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Flex Season' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS flex_season_revenue,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Group' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS group_revenue,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Suite' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS suite_revenue,
        SUM(CASE WHEN ts.TICKET_TYPE_GROUPING = 'Sponsor' THEN COALESCE(ts.PRICE, 0) ELSE 0 END) AS sponsor_revenue,
        MIN(ts.PURCHASE_DATE) AS first_purchase_date,
        MAX(ts.PURCHASE_DATE) AS latest_purchase_date,
        DATEDIFF('day', MAX(ts.PURCHASE_DATE), CURRENT_TIMESTAMP()) AS days_since_last_purchase,
        MAX(ts.MEMBERSHIP_TYPE) AS latest_membership_type,
        MAX(ts.MEMBERSHIP_PLAN) AS latest_membership_plan,
        COUNT(CASE WHEN ts.DATA_SOURCE = 'Transaction Detail' THEN 1 END) AS transaction_records,
        COUNT(CASE WHEN ts.DATA_SOURCE = 'Membership Detail' THEN 1 END) AS membership_records
    FROM TBRDP_DW_PROD.IM_RPT.V_TDC_TICKET_SALES_UNIFIED ts
    WHERE ts.FINANCIAL_PATRON_ACCOUNT_ID IS NOT NULL
    GROUP BY ts.FINANCIAL_PATRON_ACCOUNT_ID
)
SELECT 
    xw.SF_ACCOUNT_ID,
    xw.SF_ACCOUNT_NAME,
    xw.PATRON_ACCOUNT_ID_FLOAT AS PATRON_ACCOUNT_ID,
    xw.PV_ACCOUNT_NAME,
    xw.IS_PERSON_ACCOUNT,
    xw.ACCOUNT_TYPE,
    xw.INDUSTRY,
    xw.BILLING_CITY,
    xw.BILLING_STATE,
    xw.BILLING_ZIP,
    xw.ACCOUNT_OWNER_ID,
    xw.TICKET_SALES_REP,
    xw.TICKET_SERVICE_REP,
    xw.SUITE_SALES_REP,
    xw.GROUP_SALES_REP,
    xw.PARTNERSHIP_STATUS,
    xw.LEAD_SOURCE,
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
    COALESCE(ts.total_ticket_revenue, 0) AS lifetime_ticket_value,
    GREATEST(COALESCE(os.crm_won_revenue, 0), COALESCE(ts.total_ticket_revenue, 0)) AS estimated_lifetime_value,
    COALESCE(ts.total_ticket_revenue, 0) - COALESCE(os.crm_won_revenue, 0) AS revenue_attribution_gap,
    CASE 
        WHEN os.total_opportunities > 0 AND ts.total_ticket_purchases > 0 THEN TRUE
        ELSE FALSE
    END AS has_crm_and_purchases,
    CASE
        WHEN os.total_opportunities > 0 AND ts.total_ticket_purchases > 0 THEN 'CRM + Purchaser'
        WHEN os.total_opportunities > 0 AND COALESCE(ts.total_ticket_purchases, 0) = 0 THEN 'CRM Only'
        WHEN COALESCE(os.total_opportunities, 0) = 0 AND ts.total_ticket_purchases > 0 THEN 'Direct Purchaser'
        ELSE 'Prospect'
    END AS customer_segment,
    CASE 
        WHEN os.first_opportunity_date IS NOT NULL AND ts.first_purchase_date IS NOT NULL
        THEN DATEDIFF('day', os.first_opportunity_date, ts.first_purchase_date)
        ELSE NULL
    END AS days_opp_to_first_purchase,
    CASE 
        WHEN ts.days_since_last_purchase <= 30 THEN 'Active (30 days)'
        WHEN ts.days_since_last_purchase <= 90 THEN 'Recent (90 days)'
        WHEN ts.days_since_last_purchase <= 365 THEN 'Lapsed (1 year)'
        WHEN ts.days_since_last_purchase > 365 THEN 'Dormant (1+ year)'
        ELSE 'No Purchases'
    END AS recency_tier,
    CASE
        WHEN COALESCE(ts.total_ticket_revenue, 0) >= 50000 THEN 'Platinum ($50K+)'
        WHEN COALESCE(ts.total_ticket_revenue, 0) >= 10000 THEN 'Gold ($10K-$50K)'
        WHEN COALESCE(ts.total_ticket_revenue, 0) >= 1000 THEN 'Silver ($1K-$10K)'
        WHEN COALESCE(ts.total_ticket_revenue, 0) > 0 THEN 'Bronze (<$1K)'
        ELSE 'No Revenue'
    END AS revenue_tier,
    CASE 
        WHEN ts.total_ticket_purchases > 0 
         AND ts.days_since_last_purchase > 365 
         AND COALESCE(os.open_opportunities, 0) = 0 
        THEN TRUE
        ELSE FALSE
    END AS churn_risk_flag,
    CASE
        WHEN COALESCE(ts.single_game_revenue, 0) > 0 
         AND COALESCE(ts.season_ticket_revenue, 0) = 0
         AND COALESCE(ts.flex_season_revenue, 0) = 0
        THEN TRUE
        ELSE FALSE
    END AS upsell_candidate,
    CASE 
        WHEN COALESCE(ts.seasons_purchased, 0) >= 3 THEN TRUE
        ELSE FALSE
    END AS is_loyal_customer,
    xw.ACCOUNT_CREATED_DATE,
    CURRENT_TIMESTAMP() AS last_refreshed_at
FROM TBRDP_DW_PROD.IM_RPT.T_ACCOUNT_CROSSWALK xw
LEFT JOIN opp_summary os ON xw.SF_ACCOUNT_ID = os.ACCOUNT_ID
LEFT JOIN ticket_summary ts ON xw.PATRON_ACCOUNT_ID_FLOAT = ts.patron_id;