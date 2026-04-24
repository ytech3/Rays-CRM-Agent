- =====================================================
-- TASK 5: Refresh Email Analytics
-- Pure SQL — no AI functions, negligible cost
-- Runs after activity metrics but only once per day
-- Uses timestamp check to skip if already ran today
-- =====================================================
CREATE TABLE IF NOT EXISTS TBRDP_DW_PROD.IM_RPT.T_EMAIL_ANALYTICS (
    analytics_generated_at TIMESTAMP
);

-- =====================================================
-- TASK 5: Refresh Email Analytics
-- Pure SQL — no AI functions, negligible cost
-- Runs after activity metrics, skips if already ran today
-- =====================================================


CREATE OR REPLACE TASK TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_EMAIL_ANALYTICS
    WAREHOUSE = TBRDP_DW_CORTEX_XS_WH
    AFTER TBRDP_DW_PROD.IM_RPT.TSK_REFRESH_ACTIVITY_METRICS
AS
BEGIN
    -- Only rebuild if we haven't already today
    IF ((SELECT COALESCE(MAX(analytics_generated_at), '1900-01-01'::TIMESTAMP) 
         FROM TBRDP_DW_PROD.IM_RPT.T_EMAIL_ANALYTICS) < DATE_TRUNC('DAY', CURRENT_TIMESTAMP())) THEN

        CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_EMAIL_ANALYTICS AS
        WITH 
        email_base AS (
            SELECT 
                e.ID AS email_id,
                e.MESSAGE_DATE,
                DATE(e.MESSAGE_DATE) AS email_date,
                HOUR(e.MESSAGE_DATE) AS email_hour,
                DAYOFWEEK(e.MESSAGE_DATE) AS email_dow,
                CASE DAYOFWEEK(e.MESSAGE_DATE)
                    WHEN 0 THEN 'Sunday'
                    WHEN 1 THEN 'Monday'
                    WHEN 2 THEN 'Tuesday'
                    WHEN 3 THEN 'Wednesday'
                    WHEN 4 THEN 'Thursday'
                    WHEN 5 THEN 'Friday'
                    WHEN 6 THEN 'Saturday'
                END AS email_day_name,
                e.FROM_ADDRESS,
                e.TO_ADDRESS,
                e.SUBJECT,
                e.INCOMING,
                e.RELATED_TO_ID,
                e.PARENT_ID,
                e.ACTIVITY_ID,
                u_creator.ID AS rep_user_id,
                u_creator.NAME AS rep_name,
                o.ID AS opportunity_id,
                o.NAME AS opportunity_name,
                o.ACCOUNT_ID,
                ee.SENTIMENT_SCORE,
                ee.SENTIMENT_CATEGORY,
                ee.EMAIL_TOPIC,
                ee.EMAIL_SIGNAL
            FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE e
            LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_SALESFORCE_USER_CURRENT u_creator
                ON e.CREATED_BY_ID = u_creator.ID
            LEFT JOIN TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_OPPORTUNITY o
                ON e.RELATED_TO_ID = o.ID
                AND o.SYSTEM_CURRENT_FLAG = 'Y'
            LEFT JOIN TBRDP_DW_PROD.IM_RPT.T_EMAIL_ENRICHED ee
                ON e.ID = ee.EMAIL_ID
            WHERE e.MESSAGE_DATE IS NOT NULL
              AND e.SYSTEM_CURRENT_FLAG = 'Y'
              AND e.IS_DELETED = FALSE
        ),
        response_pairs AS (
            SELECT 
                outbound.email_id AS outbound_email_id,
                outbound.RELATED_TO_ID,
                outbound.MESSAGE_DATE AS outbound_time,
                MIN(inbound.MESSAGE_DATE) AS first_response_time,
                DATEDIFF('minute', outbound.MESSAGE_DATE, MIN(inbound.MESSAGE_DATE)) AS response_minutes
            FROM email_base outbound
            JOIN email_base inbound
                ON outbound.RELATED_TO_ID = inbound.RELATED_TO_ID
                AND inbound.MESSAGE_DATE > outbound.MESSAGE_DATE
                AND inbound.INCOMING = TRUE
                AND outbound.INCOMING = FALSE
                AND DATEDIFF('day', outbound.MESSAGE_DATE, inbound.MESSAGE_DATE) <= 30
            WHERE outbound.RELATED_TO_ID IS NOT NULL
            GROUP BY outbound.email_id, outbound.RELATED_TO_ID, outbound.MESSAGE_DATE
        )
        SELECT 
            eb.email_id,
            eb.MESSAGE_DATE,
            eb.email_date,
            eb.email_hour,
            eb.email_dow,
            eb.email_day_name,
            eb.FROM_ADDRESS,
            eb.TO_ADDRESS,
            eb.SUBJECT,
            eb.INCOMING,
            CASE WHEN eb.INCOMING = TRUE THEN 'Inbound' ELSE 'Outbound' END AS email_direction,
            eb.RELATED_TO_ID,
            eb.opportunity_id,
            eb.opportunity_name,
            eb.ACCOUNT_ID,
            eb.rep_user_id,
            eb.rep_name,
            eb.SENTIMENT_SCORE,
            eb.SENTIMENT_CATEGORY,
            eb.EMAIL_TOPIC,
            eb.EMAIL_SIGNAL,
            rp.response_minutes,
            CASE 
                WHEN rp.response_minutes IS NULL THEN 'No Response'
                WHEN rp.response_minutes <= 60 THEN 'Within 1 Hour'
                WHEN rp.response_minutes <= 240 THEN 'Within 4 Hours'
                WHEN rp.response_minutes <= 1440 THEN 'Within 24 Hours'
                WHEN rp.response_minutes <= 4320 THEN 'Within 3 Days'
                ELSE 'Over 3 Days'
            END AS response_time_bucket,
            CASE 
                WHEN eb.email_hour BETWEEN 6 AND 8 THEN 'Early Morning (6-9am)'
                WHEN eb.email_hour BETWEEN 9 AND 11 THEN 'Morning (9am-12pm)'
                WHEN eb.email_hour BETWEEN 12 AND 13 THEN 'Lunch (12-2pm)'
                WHEN eb.email_hour BETWEEN 14 AND 16 THEN 'Afternoon (2-5pm)'
                WHEN eb.email_hour BETWEEN 17 AND 19 THEN 'Evening (5-8pm)'
                ELSE 'Off Hours'
            END AS time_of_day_bucket,
            CURRENT_TIMESTAMP() AS analytics_generated_at
        FROM email_base eb
        LEFT JOIN response_pairs rp
            ON eb.email_id = rp.outbound_email_id;

    END IF;
END;