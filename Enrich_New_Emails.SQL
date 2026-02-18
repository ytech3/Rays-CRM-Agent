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