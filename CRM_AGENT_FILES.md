# ARM Agent - Data Schema Documentation
I am continuing development of the Tampa Bay Rays ARM Agent (Account & Relationship Management Agent) — a CRM Intelligence Platform built on Snowflake Cortex.
Database: TBRDP_DW_PROD.IM_RPT
Warehouse: TBRDP_DW_CORTEX_XS_WH
ARCHITECTURE — Streams + Tasks (rebuilt Feb 17-18, 2026 after $25K/week Dynamic Table cost crisis):
Permanent Data Tables:

T_EMAIL_ENRICHED (~98K rows) — emails with AI sentiment, topic, signal, summary via llama3.1-70b
T_OPPORTUNITY_ACTIVITY_METRICS (22,787 rows) — email/call/task counts, engagement levels, ghosting flags per opportunity
T_DEAL_HEALTH_SCORE (22,787 rows) — AI health scores (0-100), categories (Healthy/At Risk/Critical), deal assessments
T_CUSTOMER_360 (371,485 rows) — unified customer profiles with LTV, revenue tiers, churn risk, upsell flags, ticket purchase history
T_EMAIL_ANALYTICS (100,900 rows) — individual email records with direction, rep attribution, response times, time-of-day buckets, sentiment
T_TICKET_TEAM_DEPARTMENT_MAPPING (23 reps) — 5 departments: TICKET_SALES (7 Group AEs), TICKET_SERVICE (4), TICKET_MEMBER_AE (2), TICKET_TSR (4), CORPORATE_PARTNERSHIP_SALES (6)
T_EMAIL_SEARCH_SOURCE — staging for email search (replaced by direct view)
T_OPPORTUNITY_SEARCH_SOURCE — staging for opportunity search (replaced by direct view)

Streams (4 active, append-only):

STM_NEW_EMAILS → V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE
STM_OPPORTUNITY_CHANGES → V_ODS_SALESFORCE_OPPORTUNITY
STM_CALL_LOG_CHANGES → V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C
STM_TASK_CHANGES → V_ODS_SALESFORCE_TASK

Task DAG (5 tasks, stream-triggered every 2 hours):

TSK_ENRICH_NEW_EMAILS (root, 120-min schedule, SYSTEM$STREAM_HAS_DATA condition, LIMIT 500)

TSK_REFRESH_ACTIVITY_METRICS (child, pure SQL)

TSK_REFRESH_DEAL_HEALTH (grandchild, 1 AI call, changed-only filter ~200 opps)
TSK_REFRESH_CUSTOMER_360 (grandchild, pure SQL)
TSK_REFRESH_EMAIL_ANALYTICS (grandchild, pure SQL, once-daily via timestamp check)

Cortex Search Services (2 active):

EMAIL_SEARCH_SERVICE — reads from V_EMAIL_SEARCH_SOURCE view on T_EMAIL_ENRICHED, 4-hour lag, snowflake-arctic-embed-l-v2.0
OPPORTUNITY_SEARCH_SERVICE — reads from V_OPPORTUNITY_CONTEXT_SEARCH view on V_ODS_SALESFORCE_OPPORTUNITY + T_DEAL_HEALTH_SCORE, 6-hour lag

Semantic View: SV_CRM_SALES_INTELLIGENCE

7 logical tables: OPPORTUNITIES, DEAL_HEALTH, ACTIVITY_METRICS, USERS, TICKET_TEAM_DEPT, CUSTOMER_360, EMAIL_ANALYTICS
Named filter: CURRENT_RECORDS_ONLY (SYSTEM_CURRENT_FLAG = 'Y') on OPPORTUNITIES
Custom SQL generation rules including critical date range filtering (never DATE_TRUNC = string), department code mappings, email analytics routing
3 verified queries for rep opportunity counts and department pipeline comparison
ai_sql_generation and ai_question_categorization in $$ blocks

ARM Agent: 3 tools connected:

Cortex Analyst → SV_CRM_SALES_INTELLIGENCE
Cortex Search → EMAIL_SEARCH_SERVICE
Cortex Search → OPPORTUNITY_SEARCH_SERVICE

Cost Profile: ~3-6/day ($90-180/month) vs. old $3,500/day. 5 layers of cost protection: stream consumption, SYSTEM
STREAM_HAS_DATA, NOT EXISTS guards, LIMIT 500, changed-only scoring.

Key Learnings:

Dynamic Tables with Cortex AI functions force FULL refresh — never use them for AI enrichment
Cortex Search Services can read directly from views (no staging table needed if change tracking works)
WHEN clause on child tasks only supports SYSTEM$STREAM_HAS_DATA (no subqueries) — use BEGIN/IF for daily-only logic
Timestamp fields (CREATED_DATE, CLOSE_DATE, MESSAGE_DATE) require range-based filtering, never DATE_TRUNC = string comparison
CREATE OR REPLACE SEMANTIC VIEW wipes named filters and verified queries — must re-add in Snowsight editor after


**Tampa Bay Rays CRM Intelligence Platform**  
Database: `TBRDP_DW_PROD`  
Schema: `IM_RPT`

---

## Overview

This document provides comprehensive schema definitions for all data sources used in the ARM Agent (Account & Relationship Management Agent) project. The ARM Agent is a CRM Intelligence Platform that enriches Salesforce data with AI-powered sentiment analysis, deal health scoring, and natural language search capabilities.

### Platform Statistics
- **Email Records**: 90,000+
- **Opportunities**: 22,000+
- **Customer Records**: 371,485
- **Platinum Customers**: 398 (driving $64.2M in revenue)

### Core Architecture
- **Database**: Snowflake (TBRDP_DW_PROD.IM_RPT)
- **AI Services**: Cortex AI (COMPLETE, CLASSIFY_TEXT, SENTIMENT)
- **Models**: Llama 3.1-8b
- **Processing**: Streams + Tasks (incremental, every 2 hours)
- **Search**: Cortex Search Services (EMAIL_SEARCH_SERVICE, OPPORTUNITY_SEARCH_SERVICE)
- **Query Interface**: Semantic Views (SV_CRM_SALES_INTELLIGENCE)
- **Agent Model**: Claude Sonnet 4

---

## Table of Contents

1. [V_ODS_SALESFORCE_OPPORTUNITY](#v_ods_salesforce_opportunity) - Core Sales Pipeline
2. [V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE](#v_ods_salesforce_crm_email_message) - Email Communications
3. [V_ODS_SALESFORCE_TASK](#v_ods_salesforce_task) - Sales Activities & Tasks
4. [V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C](#v_ods_salesforce_crm_zvc_zoom_call_log_c) - Zoom Call Logs
5. [V_ODS_SALESFORCE_CRM_ZVC_SESSION_HISTORY_C](#v_ods_salesforce_crm_zvc_session_history_c) - Session History
6. [V_ODS_SALESFORCE_USER](#v_ods_salesforce_user) - User Information

---

## V_ODS_SALESFORCE_OPPORTUNITY

**Purpose**: The core sales pipeline containing all opportunity data including revenue amounts, stages, probabilities, and close dates.

**Use Cases**:
- Pipeline revenue analysis ("How much revenue is in the pipeline?")
- Stage progression tracking ("What deals are in Negotiation stage?")
- Close date forecasting ("What deals are closing this month?")
- Deal health scoring and risk assessment

**Row Count**: 22,000+ opportunities

### Schema Definition

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| ID | TEXT | Unique Salesforce opportunity identifier |
| IS_DELETED | BOOLEAN | Soft delete flag |
| ACCOUNT_ID | TEXT | Foreign key to account |
| RECORD_TYPE_ID | TEXT | Salesforce record type identifier |
| NAME | TEXT | Opportunity name/title |
| DESCRIPTION | TEXT | Detailed opportunity description |
| STAGE_NAME | TEXT | Current sales stage (e.g., Prospecting, Qualification, Negotiation) |
| ATTRITION_AMOUNT_C | FLOAT | Custom: Amount lost to attrition |
| AMOUNT | FLOAT | **KEY METRIC**: Total opportunity value |
| PROBABILITY | FLOAT | **KEY METRIC**: Win probability (0-100) |
| CLOSE_DATE | DATE | **KEY METRIC**: Expected close date |
| TYPE | TEXT | Opportunity type (New Business, Renewal, Upsell) |
| NEXT_STEP | TEXT | Next action required |
| LEAD_SOURCE | TEXT | Original lead source |
| IS_CLOSED | BOOLEAN | **KEY METRIC**: Whether opportunity is closed |
| RENEWAL_TYPE_C | TEXT | Custom: Type of renewal if applicable |
| IS_WON | BOOLEAN | **KEY METRIC**: Whether opportunity was won |
| FORECAST_CATEGORY | TEXT | Salesforce forecast category |
| FORECAST_CATEGORY_NAME | TEXT | Forecast category display name |
| CAMPAIGN_ID | TEXT | Associated campaign |
| HAS_OPPORTUNITY_LINE_ITEM | BOOLEAN | Has line items flag |
| PRICEBOOK_2_ID | TEXT | Associated pricebook |
| OWNER_ID | TEXT | **KEY RELATIONSHIP**: Sales rep owner ID |
| CREATED_DATE | TIMESTAMP_TZ | Record creation timestamp |
| AGE_IN_DAYS | NUMBER | Days since opportunity created |
| CREATED_BY_ID | TEXT | User who created record |
| LAST_MODIFIED_DATE | TIMESTAMP_TZ | Last modification timestamp |
| LAST_MODIFIED_BY_ID | TEXT | User who last modified |
| SYSTEM_MODSTAMP | TIMESTAMP_TZ | System modification timestamp |
| LAST_ACTIVITY_DATE | DATE | **KEY METRIC**: Date of last activity |
| LAST_ACTIVITY_IN_DAYS | NUMBER | **KEY METRIC**: Days since last activity (ghosting indicator) |
| PUSH_COUNT | NUMBER | Number of times close date was pushed |
| LAST_STAGE_CHANGE_DATE | TIMESTAMP_TZ | When stage last changed |
| LAST_STAGE_CHANGE_IN_DAYS | NUMBER | Days since stage change (stagnation indicator) |
| FISCAL_QUARTER | NUMBER | Fiscal quarter |
| FISCAL_YEAR | NUMBER | Fiscal year |
| FISCAL | TEXT | Combined fiscal period |
| CONTACT_ID | TEXT | Primary contact |
| SALE_DIRECTION_C | TEXT | Custom: Sale direction/type |
| LAST_VIEWED_DATE | TIMESTAMP_TZ | Last time viewed in UI |
| LAST_REFERENCED_DATE | TIMESTAMP_TZ | Last time referenced |
| SYNCED_QUOTE_ID | TEXT | Synced quote reference |
| CONTRACT_ID | TEXT | Associated contract |
| HAS_OPEN_ACTIVITY | BOOLEAN | Has open activities flag |
| HAS_OVERDUE_TASK | BOOLEAN | **KEY METRIC**: Has overdue tasks (risk indicator) |
| LAST_AMOUNT_CHANGED_HISTORY_ID | TEXT | Amount change history reference |
| LAST_CLOSE_DATE_CHANGED_HISTORY_ID | TEXT | Close date change history reference |
| IS_PRIORITY_RECORD | BOOLEAN | Priority flag |
| BUDGET_CONFIRMED_C | BOOLEAN | Budget confirmation flag |
| DISCOVERY_COMPLETED_C | BOOLEAN | Discovery phase completed |
| ROI_ANALYSIS_COMPLETED_C | BOOLEAN | ROI analysis completed |
| SBQQ_AMENDED_CONTRACT_C | TEXT | CPQ: Amended contract reference |
| LOSS_REASON_C | TEXT | **KEY METRIC**: Reason for loss (if lost) |
| SBQQ_CONTRACTED_C | BOOLEAN | CPQ: Contracted flag |
| SBQQ_CREATE_CONTRACTED_PRICES_C | BOOLEAN | CPQ: Create contracted prices |
| SBQQ_ORDER_GROUP_ID_C | TEXT | CPQ: Order group |
| SBQQ_ORDERED_C | BOOLEAN | CPQ: Ordered flag |
| SBQQ_PRIMARY_QUOTE_C | TEXT | CPQ: Primary quote reference |
| SBQQ_QUOTE_PRICEBOOK_ID_C | TEXT | CPQ: Quote pricebook |
| SBQQ_RENEWAL_C | BOOLEAN | CPQ: Renewal flag |
| SBQQ_RENEWED_CONTRACT_C | TEXT | CPQ: Renewed contract |
| SBAA_APPROVAL_STATUS_C | TEXT | Approval status |
| SBAA_APPROVAL_STEP_C | FLOAT | Approval step number |
| SBAA_APPROVER_C | TEXT | Current approver |
| SBAA_STEP_APPROVED_C | BOOLEAN | Step approved flag |
| SBAA_SUBMITTED_DATE_C | DATE | Approval submission date |
| SBAA_SUBMITTED_USER_C | TEXT | User who submitted for approval |
| AGENCY_INCLUSION_C | TEXT | Agency involvement details |
| BRAND_REACH_C | TEXT | Brand reach information |
| CATEGORY_C | TEXT | Opportunity category |
| UPSELL_AMOUNT_C | FLOAT | Upsell amount if applicable |
| DELIVERY_INSTALLATION_STATUS_C | TEXT | Delivery/installation status |
| EXCLUSIVITY_C | TEXT | Exclusivity terms |
| LEAGUE_DEAL_C | TEXT | League-wide deal flag |
| OBJECTIONS_C | TEXT | **KEY METRIC**: Customer objections |
| OTHER_DEPARTMENTS_C | TEXT | Other departments involved |
| PARTNERSHIP_TYPE_C | TEXT | Type of partnership |
| RATING_C | TEXT | Opportunity rating |
| REAL_ESTATE_C | TEXT | Real estate involvement |
| REVENUE_TYPE_C | TEXT | Revenue classification |
| THIRD_PARTIES_C | TEXT | Third party involvement |
| CONTACT_C | TEXT | Additional contact reference |
| CURRENT_GENERATORS_C | TEXT | Current revenue generators |
| END_SEASON_C | TEXT | End season for deal |
| EST_REVENUE_C | FLOAT | Estimated revenue |
| ESTIMATED_REVENUE_C | FLOAT | Alternative estimated revenue |
| GROUP_SALES_REP_C | TEXT | Group sales representative |
| MAIN_COMPETITORS_C | TEXT | Main competitors |
| ORDER_NUMBER_C | TEXT | Order number |
| ORDER_ID_C | TEXT | Order ID reference |
| PENDING_PAYMENT_C | BOOLEAN | Pending payment flag |
| PRO_VENUE_ID_C | TEXT | Pro venue ID |
| PROPOSAL_DUE_DATE_C | DATE | Proposal due date |
| START_SEASON_C | TEXT | Start season for deal |
| SUITE_SALES_REP_C | TEXT | Suite sales representative |
| TICKET_SALES_REP_C | TEXT | Ticket sales representative |
| TICKET_SERVICE_REP_C | TEXT | Ticket service representative |
| TICKET_TYPE_C | TEXT | Type of tickets |
| TRACKING_NUMBER_C | TEXT | Tracking number |
| SECONDARY_OBJECTIONS_C | TEXT | Secondary objections |
| LEGACY_OPPORTUNITY_ID_C | TEXT | Legacy system ID |
| ADMIN_TEXT_C | TEXT | Admin notes |
| NUMBER_OF_TICKETS_C | FLOAT | Number of tickets in deal |
| SEASON_C | TEXT | Season identifier |
| OPPORTUNITY_SCORE_C | FLOAT | **KEY METRIC**: Opportunity score |
| OBJECTION_DETAILS_C | TEXT | Detailed objection information |
| RELOCATION_INTEREST_C | BOOLEAN | Relocation interest flag |
| ONLINE_PURCHASE_C | BOOLEAN | Online purchase flag |
| DEPOSIT_INTEREST_C | TEXT | Deposit interest level |
| DEPOSIT_OPPORTUNITY_C | TEXT | Deposit opportunity reference |
| GAME_EVENT_C | TEXT | Associated game/event |
| PARTIAL_PAYMENT_C | BOOLEAN | Partial payment allowed |
| FIRST_COMPLETED_ACTIVITY_C | DATE | First completed activity date |
| TOTAL_COMPLETED_ACTIVITIES_C | FLOAT | **KEY METRIC**: Total completed activities count |
| TOTAL_COMPLETED_PHONE_CALLS_C | FLOAT | **KEY METRIC**: Total completed phone calls |
| LEADERSHIP_ASSISTANCE_C | BOOLEAN | Requires leadership assistance |
| _FIVETRAN_DELETED | BOOLEAN | Fivetran soft delete |
| _FIVETRAN_SYNCED | TIMESTAMP_TZ | Fivetran sync timestamp |
| SYSTEM_VERSION | NUMBER | SCD Type 2 version number |
| SYSTEM_CURRENT_FLAG | TEXT | SCD Type 2 current record flag |
| SYSTEM_START_DATE | TIMESTAMP_LTZ | SCD Type 2 valid from date |
| SYSTEM_END_DATE | TIMESTAMP_LTZ | SCD Type 2 valid to date |
| SYSTEM_CREATE_DATE | TIMESTAMP_LTZ | System record creation |
| SYSTEM_UPDATE_DATE | TIMESTAMP_LTZ | System record update |

**Key Relationships**:
- `OWNER_ID` → `V_ODS_SALESFORCE_USER.ID`
- `ACCOUNT_ID` → Account table (not in scope)
- `CONTACT_ID` → Contact table (not in scope)

---

## V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE

**Purpose**: Repository of all email correspondence linked to opportunities and accounts. Used for sentiment analysis, communication pattern detection, and identifying engagement gaps.

**Use Cases**:
- Email sentiment analysis ("What's the tone of recent emails?")
- Response time tracking ("How quickly are we responding?")
- Communication gap detection ("When was the last email?")
- Email thread analysis and summarization
- Ghosting detection (lack of client responses)

**Row Count**: 90,000+ emails

### Schema Definition

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| ID | TEXT | Unique email message identifier |
| PARENT_ID | TEXT | Parent record (Opportunity, Account, etc.) |
| ACTIVITY_ID | TEXT | Associated activity record |
| CREATED_BY_ID | TEXT | User who created the record |
| CREATED_DATE | TIMESTAMP_TZ | Email creation timestamp |
| LAST_MODIFIED_DATE | TIMESTAMP_TZ | Last modification timestamp |
| LAST_MODIFIED_BY_ID | TEXT | User who last modified |
| SYSTEM_MODSTAMP | TIMESTAMP_TZ | System modification timestamp |
| TEXT_BODY | TEXT | **KEY FIELD**: Plain text email body for AI analysis |
| HTML_BODY | TEXT | HTML formatted email body |
| HEADERS | TEXT | Email headers |
| SUBJECT | TEXT | **KEY FIELD**: Email subject line |
| NAME | TEXT | Email name/identifier |
| FROM_NAME | TEXT | Sender display name |
| FROM_ADDRESS | TEXT | **KEY FIELD**: Sender email address |
| VALIDATED_FROM_ADDRESS | TEXT | Validated sender address |
| TO_ADDRESS | TEXT | **KEY FIELD**: Recipient email address(es) |
| CC_ADDRESS | TEXT | CC recipient address(es) |
| BCC_ADDRESS | TEXT | BCC recipient address(es) |
| INCOMING | BOOLEAN | **KEY FIELD**: Whether email is incoming (from client) |
| HAS_ATTACHMENT | BOOLEAN | Attachment presence flag |
| STATUS | TEXT | Email status (Sent, Draft, etc.) |
| MESSAGE_DATE | TIMESTAMP_TZ | **KEY FIELD**: Actual email send/receive timestamp |
| IS_DELETED | BOOLEAN | Soft delete flag |
| REPLY_TO_EMAIL_MESSAGE_ID | TEXT | **KEY FIELD**: Reply chain reference |
| IS_EXTERNALLY_VISIBLE | BOOLEAN | External visibility flag |
| MESSAGE_IDENTIFIER | TEXT | Message ID from headers |
| THREAD_IDENTIFIER | TEXT | **KEY FIELD**: Email thread identifier |
| CLIENT_THREAD_IDENTIFIER | TEXT | Client-side thread ID |
| FROM_ID | TEXT | Salesforce user ID of sender |
| IS_CLIENT_MANAGED | BOOLEAN | Client managed flag |
| ATTACHMENT_IDS | TEXT | List of attachment IDs |
| RELATED_TO_ID | TEXT | Related object ID (Opportunity, Account) |
| IS_TRACKED | BOOLEAN | Tracking enabled flag |
| IS_OPENED | BOOLEAN | **KEY FIELD**: Email opened by recipient |
| FIRST_OPENED_DATE | TIMESTAMP_TZ | First time email was opened |
| LAST_OPENED_DATE | TIMESTAMP_TZ | Last time email was opened |
| IS_BOUNCED | BOOLEAN | Email bounce flag |
| EMAIL_TEMPLATE_ID | TEXT | Template used (if any) |
| AUTOMATION_TYPE | TEXT | Type of automation |
| SOURCE | TEXT | Email source system |
| _FIVETRAN_DELETED | BOOLEAN | Fivetran soft delete |
| _FIVETRAN_SYNCED | TIMESTAMP_TZ | Fivetran sync timestamp |
| SYSTEM_VERSION | NUMBER | SCD Type 2 version number |
| SYSTEM_CURRENT_FLAG | TEXT | SCD Type 2 current record flag |
| SYSTEM_START_DATE | TIMESTAMP_LTZ | SCD Type 2 valid from date |
| SYSTEM_END_DATE | TIMESTAMP_LTZ | SCD Type 2 valid to date |
| SYSTEM_CREATE_DATE | TIMESTAMP_LTZ | System record creation |
| SYSTEM_UPDATE_DATE | TIMESTAMP_LTZ | System record update |

**Key Fields for AI Analysis**:
- `TEXT_BODY` - Used for sentiment analysis via CORTEX.SENTIMENT
- `SUBJECT` + `TEXT_BODY` - Indexed in EMAIL_SEARCH_SERVICE
- `INCOMING` - Critical for distinguishing client vs. rep communications
- `MESSAGE_DATE` - Used to calculate days since last contact

**Key Relationships**:
- `PARENT_ID` → Can link to Opportunity, Account, or other objects
- `RELATED_TO_ID` → Additional relationship field
- `FROM_ID` → `V_ODS_SALESFORCE_USER.ID`

---

## V_ODS_SALESFORCE_TASK

**Purpose**: Sales activities and tasks including calls, meetings, and to-dos. Used to measure sales activity levels and engagement frequency.

**Use Cases**:
- Activity tracking ("How many calls did rep make this week?")
- Engagement frequency ("When was last touchpoint?")
- Zoom call logging integration
- Task completion tracking
- Overdue task identification

**Row Count**: Varies (tracks all sales activities)

### Schema Definition

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| ID | TEXT | Unique task identifier |
| WHO_ID | TEXT | Person (Contact/Lead) associated with task |
| WHAT_ID | TEXT | **KEY RELATIONSHIP**: What (Account/Opportunity) associated with task |
| WHO_COUNT | NUMBER | Count of who associations |
| WHAT_COUNT | NUMBER | Count of what associations |
| SUBJECT | TEXT | **KEY FIELD**: Task subject/title |
| ACTIVITY_DATE | DATE | **KEY FIELD**: Scheduled activity date |
| STATUS | TEXT | **KEY FIELD**: Task status (Completed, In Progress, Not Started) |
| PRIORITY | TEXT | Task priority level |
| IS_HIGH_PRIORITY | BOOLEAN | High priority flag |
| OWNER_ID | TEXT | **KEY RELATIONSHIP**: Task owner (sales rep) |
| DESCRIPTION | TEXT | **KEY FIELD**: Detailed task description |
| TYPE | TEXT | **KEY FIELD**: Task type (Call, Email, Meeting) |
| IS_DELETED | BOOLEAN | Soft delete flag |
| ACCOUNT_ID | TEXT | Associated account |
| IS_CLOSED | BOOLEAN | **KEY FIELD**: Whether task is closed/completed |
| CREATED_DATE | TIMESTAMP_TZ | Task creation timestamp |
| CREATED_BY_ID | TEXT | User who created task |
| LAST_MODIFIED_DATE | TIMESTAMP_TZ | Last modification timestamp |
| LAST_MODIFIED_BY_ID | TEXT | User who last modified |
| SYSTEM_MODSTAMP | TIMESTAMP_TZ | System modification timestamp |
| IS_ARCHIVED | BOOLEAN | Archive flag |
| CALL_DURATION_IN_SECONDS | NUMBER | **KEY FIELD**: Call duration for phone tasks |
| CALL_TYPE | TEXT | Type of call (Inbound, Outbound) |
| CALL_DISPOSITION | TEXT | **KEY FIELD**: Call outcome/disposition |
| CALL_OBJECT | TEXT | Call object reference |
| REMINDER_DATE_TIME | TIMESTAMP_TZ | Reminder timestamp |
| IS_REMINDER_SET | BOOLEAN | Reminder set flag |
| RECURRENCE_ACTIVITY_ID | TEXT | Recurring task parent ID |
| IS_RECURRENCE | BOOLEAN | Is recurring task |
| RECURRENCE_START_DATE_ONLY | DATE | Recurrence start date |
| RECURRENCE_END_DATE_ONLY | DATE | Recurrence end date |
| RECURRENCE_TIME_ZONE_SID_KEY | TEXT | Recurrence timezone |
| RECURRENCE_TYPE | TEXT | Type of recurrence |
| RECURRENCE_INTERVAL | NUMBER | Recurrence interval |
| RECURRENCE_DAY_OF_WEEK_MASK | NUMBER | Day of week mask |
| RECURRENCE_DAY_OF_MONTH | NUMBER | Day of month |
| RECURRENCE_INSTANCE | TEXT | Recurrence instance |
| RECURRENCE_MONTH_OF_YEAR | TEXT | Month of year for recurrence |
| RECURRENCE_REGENERATED_TYPE | TEXT | Regenerated recurrence type |
| TASK_SUBTYPE | TEXT | Task subtype |
| COMPLETED_DATE_TIME | TIMESTAMP_TZ | **KEY FIELD**: Completion timestamp |
| CALL_DISPOSITION_C | TEXT | Custom call disposition |
| LEGACY_OWNER_NAME_C | TEXT | Legacy owner name |
| ZVC_SCHEDULE_A_ZOOM_MEETING_C | BOOLEAN | **ZOOM**: Schedule Zoom meeting flag |
| ZVC_SESSION_HISTORY_C | TEXT | **ZOOM**: Session history reference |
| ZVC_ZOOM_CALL_LOG_C | TEXT | **ZOOM**: Zoom call log reference |
| ZVC_ZOOM_MEETING_C | TEXT | **ZOOM**: Zoom meeting reference |
| ZVC_ZOOM_TASK_TYPE_C | TEXT | **ZOOM**: Zoom task type |
| ZVC_ZOOM_ZRA_ANALYSIS_C | TEXT | **ZOOM**: Zoom Revenue Accelerator analysis |
| LEGACY_ACTIVITY_ID_C | TEXT | Legacy system activity ID |
| _FIVETRAN_DELETED | BOOLEAN | Fivetran soft delete |
| _FIVETRAN_SYNCED | TIMESTAMP_TZ | Fivetran sync timestamp |
| SYSTEM_VERSION | NUMBER | SCD Type 2 version number |
| SYSTEM_CURRENT_FLAG | TEXT | SCD Type 2 current record flag |
| SYSTEM_START_DATE | TIMESTAMP_LTZ | SCD Type 2 valid from date |
| SYSTEM_END_DATE | TIMESTAMP_LTZ | SCD Type 2 valid to date |
| SYSTEM_CREATE_DATE | TIMESTAMP_LTZ | System record creation |
| SYSTEM_UPDATE_DATE | TIMESTAMP_LTZ | System record update |

**Key Relationships**:
- `WHAT_ID` → `V_ODS_SALESFORCE_OPPORTUNITY.ID` (primary use case)
- `OWNER_ID` → `V_ODS_SALESFORCE_USER.ID`
- `ZVC_ZOOM_CALL_LOG_C` → Links to Zoom call data

**Activity Type Categories**:
- **Call**: Phone calls (inbound/outbound)
- **Email**: Email activities (often auto-logged)
- **Meeting**: Meetings and appointments
- **Task**: General to-dos and follow-ups

---

## V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C

**Purpose**: Technical logs of Zoom calls integrated with Salesforce. Provides granular call metadata including duration, participants, and call quality metrics.

**Use Cases**:
- Measuring call engagement ("How long was the demo?")
- Call frequency tracking ("How many Zoom calls this week?")
- Meeting attendance verification
- Call success/failure tracking

**Note**: This table has the same schema as TASK but focuses specifically on Zoom-related fields.

### Schema Definition

*(Schema identical to V_ODS_SALESFORCE_TASK - see above)*

**Key Zoom-Specific Fields**:
- `ZVC_SCHEDULE_A_ZOOM_MEETING_C` - Whether Zoom was scheduled
- `ZVC_SESSION_HISTORY_C` - Link to session history
- `ZVC_ZOOM_CALL_LOG_C` - Call log identifier
- `ZVC_ZOOM_MEETING_C` - Meeting identifier
- `ZVC_ZOOM_TASK_TYPE_C` - Type of Zoom activity
- `ZVC_ZOOM_ZRA_ANALYSIS_C` - Revenue Accelerator insights
- `CALL_DURATION_IN_SECONDS` - Actual call duration
- `CALL_DISPOSITION` - Call outcome

**Usage Pattern**:
```sql
-- Example: Get Zoom calls for an opportunity
SELECT 
    ACTIVITY_DATE,
    CALL_DURATION_IN_SECONDS,
    CALL_DISPOSITION,
    ZVC_ZOOM_TASK_TYPE_C
FROM V_ODS_SALESFORCE_TASK
WHERE WHAT_ID = '<opportunity_id>'
  AND ZVC_ZOOM_MEETING_C IS NOT NULL
  AND SYSTEM_CURRENT_FLAG = 'Y'
ORDER BY ACTIVITY_DATE DESC;
```

---

## V_ODS_SALESFORCE_CRM_ZVC_SESSION_HISTORY_C

**Purpose**: Detailed session metadata for Zoom interactions including participant information, session duration, call disposition, and engagement metrics.

**Use Cases**:
- Detailed meeting analytics
- Participant tracking
- Call quality assessment
- Recording management
- Session notes and smart notes

### Schema Definition

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| ID | TEXT | Unique session history identifier |
| OWNER_ID | TEXT | Session owner |
| IS_DELETED | BOOLEAN | Soft delete flag |
| NAME | TEXT | Session name |
| CREATED_DATE | TIMESTAMP_TZ | Record creation timestamp |
| CREATED_BY_ID | TEXT | User who created record |
| LAST_MODIFIED_DATE | TIMESTAMP_TZ | Last modification timestamp |
| LAST_MODIFIED_BY_ID | TEXT | User who last modified |
| SYSTEM_MODSTAMP | TIMESTAMP_TZ | System modification timestamp |
| LAST_VIEWED_DATE | TIMESTAMP_TZ | Last time viewed |
| LAST_REFERENCED_DATE | TIMESTAMP_TZ | Last time referenced |
| ZVC_CHANNEL_C | TEXT | **ZOOM**: Communication channel |
| ZVC_ACCOUNT_C | TEXT | **ZOOM**: Associated account |
| ZVC_AGENT_CHANNEL_ID_C | TEXT | **ZOOM**: Agent channel identifier |
| ZVC_AGENT_EMAIL_C | TEXT | **ZOOM**: Agent email address |
| ZVC_AGENT_PHONE_C | TEXT | **ZOOM**: Agent phone number |
| ZVC_AGENT_USER_EMAIL_C | TEXT | **ZOOM**: Agent user email |
| ZVC_ANSWER_TIME_C | TEXT | **ZOOM**: Time to answer |
| ZVC_CALL_ID_C | TEXT | **ZOOM**: Call identifier |
| ZVC_CAMPAIGN_C | TEXT | Associated campaign |
| ZVC_CASE_C | TEXT | Associated case |
| ZVC_CHAT_TRANSCRIPT_C | TEXT | **ZOOM**: Chat transcript |
| ZVC_CONTACT_PHONE_C | TEXT | Contact phone number |
| ZVC_CONTACT_C | TEXT | Associated contact |
| ZVC_DISPOSITION_C | TEXT | **KEY FIELD**: Call disposition/outcome |
| ZVC_DURATION_C | TEXT | **KEY FIELD**: Session duration |
| ZVC_END_TIME_C | TIMESTAMP_TZ | **KEY FIELD**: Session end timestamp |
| ZVC_ENGAGEMENT_ID_C | TEXT | Engagement identifier |
| ZVC_EXISTING_TASK_C | TEXT | Link to existing task |
| ZVC_FROM_SESSION_HISTORY_C | TEXT | From session history reference |
| ZVC_IS_RELATED_TO_DISMISSED_C | BOOLEAN | Related to dismissed flag |
| ZVC_IS_TASK_CONNECTED_C | BOOLEAN | Task connection flag |
| ZVC_LEAD_C | TEXT | Associated lead |
| ZVC_NOTES_C | TEXT | **KEY FIELD**: Session notes |
| ZVC_QUEUE_C | TEXT | Queue information |
| ZVC_RECORDING_C | TEXT | **KEY FIELD**: Recording URL/reference |
| ZVC_SMART_NOTES_C | TEXT | **KEY FIELD**: AI-generated smart notes |
| ZVC_START_TIME_C | TIMESTAMP_TZ | **KEY FIELD**: Session start timestamp |
| ZVC_TASK_ID_C | TEXT | **KEY RELATIONSHIP**: Associated task ID |
| ZVC_TYPE_C | TEXT | **KEY FIELD**: Session type (Call, Meeting, etc.) |
| ZVC_USER_C | TEXT | Associated Zoom user |
| ZVC_WAIT_TIME_C | TEXT | Wait time before answer |
| ZVC_WARP_UP_TIME_C | TEXT | Wrap-up time after call |
| ZVC_IS_MISSED_C | BOOLEAN | **KEY FIELD**: Missed call flag |
| ZVC_IS_TRANSFER_TO_QUEUE_C | BOOLEAN | Transfer to queue flag |
| ZVC_IS_TRANSFER_C | BOOLEAN | Call transfer flag |
| ZVC_IS_UPGRADE_C | BOOLEAN | Call upgrade flag |
| ZVC_VOICEMAIL_C | TEXT | Voicemail reference |
| ZVC_QUEUE_WAIT_TYPE_C | TEXT | Queue wait type |
| ZVC_CHANNEL_SOURCE_C | TEXT | Channel source |
| ZVC_AGENT_NAME_C | TEXT | **KEY FIELD**: Agent name |
| ZVC_CONSUMER_DISPLAY_NAME_C | TEXT | **KEY FIELD**: Customer display name |
| ZVC_AGENT_ID_C | TEXT | Agent identifier |
| ZVC_CONSUMER_NUMBER_C | TEXT | Customer phone number |
| ZVC_HANDLING_TIME_C | TEXT | Total handling time |
| _FIVETRAN_DELETED | BOOLEAN | Fivetran soft delete |
| _FIVETRAN_SYNCED | TIMESTAMP_TZ | Fivetran sync timestamp |
| SYSTEM_CREATE_DATE | TIMESTAMP_LTZ | System record creation |
| SYSTEM_UPDATE_DATE | TIMESTAMP_LTZ | System record update |
| SYSTEM_VERSION | NUMBER | SCD Type 2 version number |
| SYSTEM_CURRENT_FLAG | TEXT | SCD Type 2 current record flag |
| SYSTEM_START_DATE | TIMESTAMP_LTZ | SCD Type 2 valid from date |
| SYSTEM_END_DATE | TIMESTAMP_LTZ | SCD Type 2 valid to date |

**Key Relationships**:
- `ZVC_TASK_ID_C` → `V_ODS_SALESFORCE_TASK.ID`
- `ZVC_CONTACT_C` → Contact table
- `ZVC_ACCOUNT_C` → Account table

**Usage Pattern**:
```sql
-- Example: Get session details for recent Zoom calls
SELECT 
    ZVC_START_TIME_C,
    ZVC_END_TIME_C,
    ZVC_DURATION_C,
    ZVC_DISPOSITION_C,
    ZVC_AGENT_NAME_C,
    ZVC_CONSUMER_DISPLAY_NAME_C,
    ZVC_NOTES_C,
    ZVC_SMART_NOTES_C,
    ZVC_IS_MISSED_C
FROM V_ODS_SALESFORCE_CRM_ZVC_SESSION_HISTORY_C
WHERE ZVC_TASK_ID_C IN (
    SELECT ID FROM V_ODS_SALESFORCE_TASK 
    WHERE WHAT_ID = '<opportunity_id>'
)
  AND SYSTEM_CURRENT_FLAG = 'Y'
ORDER BY ZVC_START_TIME_C DESC;
```

---

## V_ODS_SALESFORCE_USER

**Purpose**: User/employee information for sales representatives and other system users. Critical for attribution, performance tracking, and personalizing agent responses.

**Use Cases**:
- Sales rep identification and attribution
- Performance tracking by rep
- Team structure and reporting relationships
- Email address validation and matching

**Key Fields for ARM Agent**:
- Name fields for display
- Email for matching with email communications
- Manager relationships for escalation
- Active status for filtering current reps

### Schema Definition

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| ID | TEXT | **KEY FIELD**: Unique user identifier |
| USERNAME | TEXT | Salesforce username |
| LAST_NAME | TEXT | **KEY FIELD**: Last name |
| FIRST_NAME | TEXT | **KEY FIELD**: First name |
| MIDDLE_NAME | TEXT | Middle name |
| SUFFIX | TEXT | Name suffix |
| NAME | TEXT | **KEY FIELD**: Full name |
| COMPANY_NAME | TEXT | Company name |
| DIVISION | TEXT | Division/department |
| DEPARTMENT | TEXT | Department |
| TITLE | TEXT | **KEY FIELD**: Job title |
| STREET | TEXT | Street address |
| CITY | TEXT | City |
| STATE | TEXT | State |
| POSTAL_CODE | TEXT | Postal code |
| COUNTRY | TEXT | Country |
| LATITUDE | FLOAT | Geographic latitude |
| LONGITUDE | FLOAT | Geographic longitude |
| GEOCODE_ACCURACY | TEXT | Geocoding accuracy |
| EMAIL | TEXT | **KEY FIELD**: Primary email address for matching |
| EMAIL_PREFERENCES_AUTO_BCC | BOOLEAN | Auto BCC preference |
| EMAIL_PREFERENCES_AUTO_BCC_STAY_IN_TOUCH | BOOLEAN | Auto BCC stay in touch |
| EMAIL_PREFERENCES_STAY_IN_TOUCH_REMINDER | BOOLEAN | Stay in touch reminder |
| SENDER_EMAIL | TEXT | Sender email override |
| SENDER_NAME | TEXT | Sender name override |
| SIGNATURE | TEXT | Email signature |
| STAY_IN_TOUCH_SUBJECT | TEXT | Stay in touch subject |
| STAY_IN_TOUCH_SIGNATURE | TEXT | Stay in touch signature |
| STAY_IN_TOUCH_NOTE | TEXT | Stay in touch note |
| PHONE | TEXT | Work phone |
| FAX | TEXT | Fax number |
| MOBILE_PHONE | TEXT | Mobile phone |
| ALIAS | TEXT | User alias |
| COMMUNITY_NICKNAME | TEXT | Community nickname |
| BADGE_TEXT | TEXT | Badge text |
| IS_ACTIVE | BOOLEAN | **KEY FIELD**: Active user flag |
| TIME_ZONE_SID_KEY | TEXT | Timezone |
| USER_ROLE_ID | TEXT | User role identifier |
| LOCALE_SID_KEY | TEXT | Locale |
| RECEIVES_INFO_EMAILS | BOOLEAN | Receives info emails |
| RECEIVES_ADMIN_INFO_EMAILS | BOOLEAN | Receives admin emails |
| EMAIL_ENCODING_KEY | TEXT | Email encoding |
| PROFILE_ID | TEXT | Profile identifier |
| USER_TYPE | TEXT | User type (Standard, etc.) |
| START_DAY | TEXT | Start day of week |
| END_DAY | TEXT | End day of week |
| LANGUAGE_LOCALE_KEY | TEXT | Language locale |
| EMPLOYEE_NUMBER | TEXT | Employee number |
| DELEGATED_APPROVER_ID | TEXT | Delegated approver |
| MANAGER_ID | TEXT | **KEY RELATIONSHIP**: Manager user ID |
| LAST_LOGIN_DATE | TIMESTAMP_TZ | Last login timestamp |
| LAST_PASSWORD_CHANGE_DATE | TIMESTAMP_TZ | Last password change |
| CREATED_DATE | TIMESTAMP_TZ | User creation date |
| CREATED_BY_ID | TEXT | Created by user |
| LAST_MODIFIED_DATE | TIMESTAMP_TZ | Last modification timestamp |
| LAST_MODIFIED_BY_ID | TEXT | Last modified by user |
| SYSTEM_MODSTAMP | TIMESTAMP_TZ | System modification timestamp |
| PASSWORD_EXPIRATION_DATE | TIMESTAMP_TZ | Password expiration |
| NUMBER_OF_FAILED_LOGINS | NUMBER | Failed login count |
| SU_ACCESS_EXPIRATION_DATE | DATE | Super user access expiration |
| OFFLINE_TRIAL_EXPIRATION_DATE | TIMESTAMP_TZ | Offline trial expiration |
| OFFLINE_PDA_TRIAL_EXPIRATION_DATE | TIMESTAMP_TZ | Offline PDA trial expiration |
| USER_PERMISSIONS_MARKETING_USER | BOOLEAN | Marketing user permission |
| USER_PERMISSIONS_OFFLINE_USER | BOOLEAN | Offline user permission |
| USER_PERMISSIONS_AVANTGO_USER | BOOLEAN | AvantGo user permission |
| USER_PERMISSIONS_CALL_CENTER_AUTO_LOGIN | BOOLEAN | Call center auto-login permission |
| USER_PERMISSIONS_SFCONTENT_USER | BOOLEAN | Salesforce content user |
| USER_PERMISSIONS_KNOWLEDGE_USER | BOOLEAN | Knowledge user permission |
| USER_PERMISSIONS_INTERACTION_USER | BOOLEAN | Interaction user permission |
| USER_PERMISSIONS_SUPPORT_USER | BOOLEAN | Support user permission |
| FORECAST_ENABLED | BOOLEAN | Forecast enabled flag |
| *(100+ USER_PREFERENCES fields omitted for brevity - UI preferences)* | BOOLEAN | Various user preference flags |
| CONTACT_ID | TEXT | Contact reference |
| ACCOUNT_ID | TEXT | Account reference |
| CALL_CENTER_ID | TEXT | Call center identifier |
| EXTENSION | TEXT | Phone extension |
| FEDERATION_IDENTIFIER | TEXT | Federation ID |
| ABOUT_ME | TEXT | User bio |
| FULL_PHOTO_URL | TEXT | Full photo URL |
| SMALL_PHOTO_URL | TEXT | Small photo URL |
| IS_EXT_INDICATOR_VISIBLE | BOOLEAN | External indicator visible |
| OUT_OF_OFFICE_MESSAGE | TEXT | Out of office message |
| MEDIUM_PHOTO_URL | TEXT | Medium photo URL |
| DIGEST_FREQUENCY | TEXT | Digest frequency |
| DEFAULT_GROUP_NOTIFICATION_FREQUENCY | TEXT | Group notification frequency |
| LAST_VIEWED_DATE | TIMESTAMP_TZ | Last viewed timestamp |
| LAST_REFERENCED_DATE | TIMESTAMP_TZ | Last referenced timestamp |
| BANNER_PHOTO_URL | TEXT | Banner photo URL |
| SMALL_BANNER_PHOTO_URL | TEXT | Small banner URL |
| MEDIUM_BANNER_PHOTO_URL | TEXT | Medium banner URL |
| IS_PROFILE_PHOTO_ACTIVE | BOOLEAN | Profile photo active |
| SBQQ_DEFAULT_PRODUCT_LOOKUP_TAB_C | TEXT | CPQ: Default product lookup tab |
| SBQQ_PRODUCT_SORT_PREFERENCE_C | TEXT | CPQ: Product sort preference |
| SBQQ_DIAGNOSTIC_TOOL_ENABLED_C | BOOLEAN | CPQ: Diagnostic tool enabled |
| SBQQ_OUTPUT_FORMAT_CHANGE_ALLOWED_C | BOOLEAN | CPQ: Output format change allowed |
| SBQQ_RESET_PRODUCT_LOOKUP_C | BOOLEAN | CPQ: Reset product lookup |
| SBQQ_THEME_C | TEXT | CPQ: Theme |
| _FIVETRAN_DELETED | BOOLEAN | Fivetran soft delete |
| _FIVETRAN_SYNCED | TIMESTAMP_TZ | Fivetran sync timestamp |
| SYSTEM_VERSION | NUMBER | SCD Type 2 version number |
| SYSTEM_CURRENT_FLAG | TEXT | SCD Type 2 current record flag |
| SYSTEM_START_DATE | TIMESTAMP_LTZ | SCD Type 2 valid from date |
| SYSTEM_END_DATE | TIMESTAMP_LTZ | SCD Type 2 valid to date |
| SYSTEM_CREATE_DATE | TIMESTAMP_LTZ | System record creation |
| SYSTEM_UPDATE_DATE | TIMESTAMP_LTZ | System record update |

**Key Relationships**:
- `MANAGER_ID` → `V_ODS_SALESFORCE_USER.ID` (self-referencing)
- `ID` ← `V_ODS_SALESFORCE_OPPORTUNITY.OWNER_ID`
- `ID` ← `V_ODS_SALESFORCE_TASK.OWNER_ID`
- `EMAIL` ← Used for matching with `V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE.FROM_ADDRESS`

**Hardcoded User ID Mappings** (for semantic view reliability):
```sql
-- Known sales reps (example - update with actual IDs)
CASE 
    WHEN u.ID = '0055e000001abcXXX' THEN 'John Smith'
    WHEN u.ID = '0055e000001defYYY' THEN 'Jane Doe'
    -- Add all known sales reps for 100% accuracy
END AS rep_name
```

---

## Data Quality & Processing Notes

### Incremental Processing Architecture

The ARM Agent uses a **Streams + Tasks** architecture to process only changed records:

1. **Streams** detect data changes:
   - `STREAM_OPPORTUNITIES` - Opportunity changes
   - `STREAM_EMAILS` - New emails
   - `STREAM_TASKS` - Task updates
   - `STREAM_SESSIONS` - Zoom session changes

2. **Task DAG** runs every 2 hours (only when changes exist):
   - Checks `SYSTEM$STREAM_HAS_DATA()` before executing
   - Processes max 500 records per run (cost protection)
   - Updates only changed records (not full refresh)
   - Consumes stream rows permanently

3. **Cost Protection Layers**:
   - Hard limits: 500 records per execution
   - Timestamp guards: Only recent changes
   - NOT EXISTS checks: Prevent duplicate processing
   - Stream consumption: Automatic deduplication

### SCD Type 2 Tracking

All tables use Slowly Changing Dimension Type 2 tracking:
- `SYSTEM_VERSION` - Version number
- `SYSTEM_CURRENT_FLAG` - 'Y' for current, 'N' for historical
- `SYSTEM_START_DATE` - Valid from timestamp
- `SYSTEM_END_DATE` - Valid to timestamp (NULL for current)
- `SYSTEM_CREATE_DATE` - Record creation
- `SYSTEM_UPDATE_DATE` - Last update

**Always filter**: `WHERE SYSTEM_CURRENT_FLAG = 'Y'` to get current records only.

### Fivetran Metadata

All tables include Fivetran sync metadata:
- `_FIVETRAN_SYNCED` - Last sync timestamp
- `_FIVETRAN_DELETED` - Soft delete flag

### JSON Extraction for Cortex Search

Cortex Search Services require VARCHAR columns, not JSON objects. When building search services:

```sql
-- INCORRECT (will fail)
SELECT JSON_COLUMN FROM table;

-- CORRECT (extract to VARCHAR)
SELECT 
    JSON_COLUMN:field_name::VARCHAR AS field_name
FROM table;
```

### Cost Optimization Lessons

**Critical Issue Encountered**: Dynamic Tables with Cortex AI functions caused $25,000 weekly cost overrun when forced into full refresh mode instead of incremental processing.

**Solution Implemented**:
1. Migrated from Dynamic Tables → Streams + Tasks
2. Process only changed records (200 opps vs 22,000 per cycle)
3. Multiple cost guard layers
4. Reduced AI calls (removed unnecessary fields)
5. Result: $3,500/day → $3-6/day (99% cost reduction)

---

## ARM Agent Architecture

### Three-Tool Orchestration

The ARM Agent uses Claude Sonnet 4 with three specialized tools:

1. **CRM_Analytics** (Semantic View)
   - Structured SQL queries against `SV_CRM_SALES_INTELLIGENCE`
   - Pipeline metrics, stage analysis, revenue forecasting
   - Rep performance tracking

2. **Email_Search** (Cortex Search Service)
   - Semantic search across 90,000+ emails
   - Natural language queries: "Show frustrated emails from last week"
   - Sentiment-filtered search

3. **Opportunity_Search** (Cortex Search Service)
   - Semantic search across 22,000+ opportunities
   - Deal context retrieval
   - Enriched with AI-generated health scores

### AI Enrichment Fields

Each opportunity is enriched with Cortex AI-generated fields:

- **SENTIMENT_SCORE** - Overall sentiment of recent communications
- **SENTIMENT_LABEL** - Categorized sentiment (Positive, Neutral, Negative)
- **DEAL_HEALTH_SCORE** - AI-calculated health score (0-100)
- **ENGAGEMENT_LEVEL** - Classified engagement (High, Medium, Low)
- **RISK_FACTORS** - Identified risk indicators
- **AI_SUMMARY** - Natural language deal summary

### Cortex AI Configuration

**Model**: Llama 3.1-8b (llama3.1-8b)

**Functions Used**:
```sql
-- Sentiment Analysis
CORTEX.SENTIMENT(email_body) AS sentiment_score

-- Text Classification
CORTEX.CLASSIFY_TEXT(
    email_body,
    ['Positive', 'Neutral', 'Negative', 'Urgent']
) AS category

-- Text Generation
CORTEX.COMPLETE(
    'llama3.1-8b',
    [
        {'role': 'system', 'content': 'You are a sales intelligence analyst...'},
        {'role': 'user', 'content': 'Summarize this opportunity...'}
    ]
) AS ai_summary
```

### Semantic View Configuration

The semantic view (`SV_CRM_SALES_INTELLIGENCE`) provides natural language SQL capabilities:

**Example Queries**:
- "What's our total pipeline by stage?"
- "Show me opportunities closing this quarter"
- "Which reps have the most at-risk deals?"
- "What's our win rate by sales rep?"

**Business Metrics Available**:
- Pipeline value by stage
- Win rate calculations (Won/Total opportunities)
- Days since last activity
- Stage duration tracking
- Rep performance metrics
- Close date forecasting

---

## Quick Reference - Common Queries

### Get Opportunity with Recent Activities
```sql
SELECT 
    o.ID,
    o.NAME,
    o.AMOUNT,
    o.STAGE_NAME,
    o.PROBABILITY,
    o.CLOSE_DATE,
    o.LAST_ACTIVITY_DATE,
    o.LAST_ACTIVITY_IN_DAYS,
    u.NAME as owner_name,
    COUNT(DISTINCT t.ID) as total_activities,
    COUNT(DISTINCT e.ID) as total_emails
FROM V_ODS_SALESFORCE_OPPORTUNITY o
LEFT JOIN V_ODS_SALESFORCE_USER u ON o.OWNER_ID = u.ID
LEFT JOIN V_ODS_SALESFORCE_TASK t ON o.ID = t.WHAT_ID AND t.SYSTEM_CURRENT_FLAG = 'Y'
LEFT JOIN V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE e ON o.ID = e.PARENT_ID AND e.SYSTEM_CURRENT_FLAG = 'Y'
WHERE o.SYSTEM_CURRENT_FLAG = 'Y'
  AND o.IS_DELETED = FALSE
  AND o.IS_CLOSED = FALSE
GROUP BY 1,2,3,4,5,6,7,8,9;
```

### Get Email Thread Analysis
```sql
SELECT 
    THREAD_IDENTIFIER,
    COUNT(*) as email_count,
    MIN(MESSAGE_DATE) as first_email,
    MAX(MESSAGE_DATE) as last_email,
    DATEDIFF('day', MAX(MESSAGE_DATE), CURRENT_DATE()) as days_since_last,
    SUM(CASE WHEN INCOMING = TRUE THEN 1 ELSE 0 END) as incoming_count,
    SUM(CASE WHEN INCOMING = FALSE THEN 1 ELSE 0 END) as outgoing_count
FROM V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE
WHERE PARENT_ID = '<opportunity_id>'
  AND SYSTEM_CURRENT_FLAG = 'Y'
  AND IS_DELETED = FALSE
GROUP BY THREAD_IDENTIFIER
ORDER BY last_email DESC;
```

### Get Rep Performance Summary
```sql
SELECT 
    u.NAME as rep_name,
    COUNT(DISTINCT o.ID) as total_opportunities,
    SUM(o.AMOUNT) as total_pipeline_value,
    SUM(CASE WHEN o.IS_WON = TRUE THEN o.AMOUNT ELSE 0 END) as won_revenue,
    COUNT(DISTINCT CASE WHEN o.IS_WON = TRUE THEN o.ID END) as won_count,
    COUNT(DISTINCT t.ID) as total_activities,
    AVG(o.LAST_ACTIVITY_IN_DAYS) as avg_days_since_activity
FROM V_ODS_SALESFORCE_USER u
LEFT JOIN V_ODS_SALESFORCE_OPPORTUNITY o 
    ON u.ID = o.OWNER_ID 
    AND o.SYSTEM_CURRENT_FLAG = 'Y'
    AND o.IS_DELETED = FALSE
LEFT JOIN V_ODS_SALESFORCE_TASK t 
    ON u.ID = t.OWNER_ID 
    AND t.SYSTEM_CURRENT_FLAG = 'Y'
    AND t.IS_DELETED = FALSE
    AND t.ACTIVITY_DATE >= DATEADD('day', -30, CURRENT_DATE())
WHERE u.SYSTEM_CURRENT_FLAG = 'Y'
  AND u.IS_ACTIVE = TRUE
GROUP BY u.NAME
ORDER BY total_pipeline_value DESC;
```

---

## Document Metadata

- **Last Updated**: February 18, 2026
- **Created By**: Yuki, Data Engineer, Tampa Bay Rays
- **Project**: ARM Agent (Account & Relationship Management Agent)
- **Version**: 1.0
- **Status**: Production

### Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-02-18 | 1.0 | Initial comprehensive documentation | Yuki |

---

## Additional Resources

### Related Files in Project
- `CRM_AGENT_SQL` - All SQL queries used in project
- `Cortex_Agents` - Snowflake Cortex Agent documentation
- `Cortex_Search` - Cortex Search Service documentation
- `Semantic_Views` - Semantic View implementation guide
- `CREATE_AGENT` - Agent creation SQL syntax
- `CREATE_CORTEX_SEARCH_SERVICE` - Search service creation syntax

### Key Learnings
1. **Cost Control**: Streams + Tasks >> Dynamic Tables for incremental AI processing
2. **Change Tracking**: Create regular table intermediaries for Cortex Search with views
3. **JSON Handling**: Extract to VARCHAR, don't use JSON columns in search services
4. **User Mapping**: Hardcode known user IDs for 100% accuracy in semantic views
5. **Data Reconciliation**: Always validate against production dashboards

### Success Metrics
- **Cost Reduction**: 99% (from $3,500/day to $3-6/day)
- **Processing Efficiency**: 200 vs 22,000 records per cycle
- **Data Freshness**: 2-hour refresh cycle
- **Coverage**: 90K+ emails, 22K+ opportunities, 371K+ customers

---

*This document is part of the ARM Agent project knowledge base and should be maintained as the authoritative reference for all data schemas and relationships.*
