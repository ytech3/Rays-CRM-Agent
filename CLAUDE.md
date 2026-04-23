# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Snowflake SQL definitions for the **ARM Agent** (Account & Relationship Management Agent) — a CRM Intelligence Platform powered by Snowflake Cortex. It enriches Salesforce data with AI-generated sentiment analysis, deal health scoring, and call activity tracking to support the Tampa Bay Rays ticket sales organization.

Target schema: `TBRDP_DW_PROD.IM_RPT`
Warehouse: `TBRDP_DW_CORTEX_XS_WH`
Agent model: Claude Sonnet 4.5

There are no build, lint, or test commands. Changes are deployed by executing SQL directly against Snowflake.

## Files

- **Semantic_View.SQL** — Defines `SV_CRM_SALES_INTELLIGENCE`, the Snowflake Semantic View (10 logical tables) used by Cortex Analyst for natural-language SQL queries.
- **Tasks.SQL** — Defines the 6-task DAG: root `TSK_ENRICH_NEW_EMAILS` (120-min), child tasks for activity metrics, deal health, customer 360, email analytics, and call activity. Also defines the 5 append-only streams.
- **CUSTOMER_360.SQL** — Defines `T_CUSTOMER_360`, the unified customer profile table with LTV, revenue tiers, churn risk, and upsell flags. Refreshed by `TSK_REFRESH_CUSTOMER_360`.
- **T_Call_Activity.SQL** — Defines `T_CALL_ACTIVITY`, a permanent table unioning Zoom Session History and Zoom Call Log call records. Also defines `TSK_REFRESH_CALL_ACTIVITY`, the incremental task that appends new records daily.
- **Email_Analytics.SQL** — Defines `T_EMAIL_ANALYTICS`, a permanent table of individual email records with direction, rep attribution, response times, sentiment, and time-of-day buckets.
- **Game_Attendance_Views.SQL** — Defines `V_CUSTOMER_GAME_ATTENDANCE` (aggregated per-customer) and `V_CUSTOMER_GAME_ATTENDANCE_DETAIL` (individual game records). Scan-based (IS_SCANNED=1) using V_FACT_INDIVIDUAL_SEAT_SALES joined to T_GAME_RESULTS. Covers 2023–2025 seasons.
- **Source_Views.SQL** — Defines source views used by Cortex Search services: `V_EMAIL_SEARCH_SOURCE`, `V_CALL_SEARCH_SOURCE`, `V_OPPORTUNITY_CONTEXT_SEARCH`.
- **Cortex_Search.SQL** — Defines the 3 Cortex Search services: EMAIL_SEARCH_SERVICE, CALL_SEARCH_SERVICE, OPPORTUNITY_SEARCH_SERVICE.
- **STAFF_BUILDOUT.sql** — Defines `V_SALESFORCE_USER_CURRENT`, `V_SALESFORCE_TASKS_CURRENT`, and `T_TICKET_TEAM_DEPARTMENT_MAPPING` for rep attribution and team structure.
- **Health_Check.SQL** — Defines `TSK_CRM_AGENT_HEALTH_CHECK` (daily 7am ET monitoring task), `CRM_AGENT_ALERTS` notification integration, `T_CRM_AGENT_HEALTH_LOG` audit table, manual health check queries, and emergency recovery procedures.
- **MLB_UDF.sql** / **MLB_SCHEDULE_UDF.sql** — External API UDFs for MLB game results and schedule data.
- **CRM Agent Config.yaml** — Cortex Agent configuration file defining the four tools (CRM Analytics, Email Search, Call Search, Opportunity Search) and system prompt.
- **CRM_AGENT_FILES.md** — Comprehensive schema documentation for all source views and enriched tables.

## Architecture

### Data Flow

Salesforce data lands via Fivetran into source views → Streams detect changes → Task DAG enriches and materializes into permanent tables → Cortex Search indexes the tables → Cortex Analyst queries the Semantic View → ARM Agent orchestrates all three tools.

### Permanent Enriched Tables

| Table | Rows | Description |
|-------|------|-------------|
| `T_EMAIL_ENRICHED` | ~161K | Emails with AI sentiment, topic, signal, summary (llama3.1-70b) |
| `T_EMAIL_ANALYTICS` | ~163K | Email records with direction, rep attribution, response times, sentiment |
| `T_OPPORTUNITY_ACTIVITY_METRICS` | ~43,801 | Email/call/task counts, engagement levels, ghosting flags per opportunity |
| `T_DEAL_HEALTH_SCORE` | ~2,948 | AI health scores (0–100), categories (Healthy/At Risk/Critical). Only scores deals in 'Initial Conversation' or 'In-Contact' stages. |
| `T_CUSTOMER_360` | ~437,461 | Unified customer profiles with LTV, revenue tiers, churn risk, upsell flags |
| `T_CALL_ACTIVITY` | ~86,453 | Zoom call records from Session History + Call Log, deduped by session_id |
| `T_TICKET_TEAM_DEPARTMENT_MAPPING` | 43 reps | 8 departments: TICKET_SALES (7), TICKET_SERVICE (5), TICKET_MEMBER_AE (4), TICKET_TSR (4), CORPORATE_PARTNERSHIP_SALES (6), TICKET_LEADERSHIP (11), TICKET_INTERN (4), CALL_CENTER (2). USER_NAME column is VARCHAR(50). |

### Streams (5 active, append-only)

| Stream | Source View |
|--------|------------|
| `STM_NEW_EMAILS` | `V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE` |
| `STM_OPPORTUNITY_CHANGES` | `V_ODS_SALESFORCE_OPPORTUNITY` |
| `STM_CALL_LOG_CHANGES` | `V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C` |
| `STM_SESSION_HISTORY_CHANGES` | `V_ODS_SALESFORCE_CRM_ZVC_SESSION_HISTORY_C` |
| `STM_TASK_CHANGES` | `V_ODS_SALESFORCE_TASK` |

**Stream staleness**: Streams go stale if not consumed within ~14 days. If a stream shows `stale=true` in `SHOW STREAMS`, recreate it with `CREATE OR REPLACE STREAM ... ON VIEW ... APPEND_ONLY = TRUE`.

### Task DAG (6 tasks, 2-hour cycle)

```
TSK_ENRICH_NEW_EMAILS (root, 120-min schedule, SYSTEM$STREAM_HAS_DATA guard, LIMIT 500)
├── TSK_REFRESH_ACTIVITY_METRICS (child, pure SQL)
├── TSK_REFRESH_DEAL_HEALTH (grandchild, AI call, changed-only, stage filter: 'Initial Conversation' + 'In-Contact' only)
├── TSK_REFRESH_CUSTOMER_360 (grandchild, pure SQL)
├── TSK_REFRESH_EMAIL_ANALYTICS (grandchild, pure SQL, once-daily timestamp check)
└── TSK_REFRESH_CALL_ACTIVITY (child, pure SQL, once-daily timestamp check)
```

**Critical**: When modifying any task in the DAG, the root task (`TSK_ENRICH_NEW_EMAILS`) must be suspended first, then the child task modified, then the root task resumed.

### Cortex Search Services (3 active)

| Service | Source | Lag | Embedding Model |
|---------|--------|-----|-----------------|
| `EMAIL_SEARCH_SERVICE` | `V_EMAIL_SEARCH_SOURCE` (view on `T_EMAIL_ENRICHED`) | 4 hours | snowflake-arctic-embed-l-v2.0 |
| `CALL_SEARCH_SERVICE` | `V_CALL_SEARCH_SOURCE` (view on `T_CALL_ACTIVITY`) | 1 day | snowflake-arctic-embed-l-v2.0 |
| `OPPORTUNITY_SEARCH_SERVICE` | `V_OPPORTUNITY_CONTEXT_SEARCH` (view on opportunity + deal health) | 6 hours | snowflake-arctic-embed-l-v2.0 |

### Semantic View (`SV_CRM_SALES_INTELLIGENCE`)

10 logical tables: `OPPORTUNITIES`, `DEAL_HEALTH`, `ACTIVITY_METRICS`, `USERS`, `TICKET_TEAM_DEPT`, `CUSTOMER_360`, `EMAIL_ANALYTICS`, `CALL_ACTIVITY`, `GAME_ATTENDANCE`, `GAME_ATTENDANCE_DETAIL`

Named filter: `CURRENT_RECORDS_ONLY` (`SYSTEM_CURRENT_FLAG = 'Y'`) on OPPORTUNITIES.

**Critical**: `CREATE OR REPLACE SEMANTIC VIEW` wipes all named filters and verified queries — always re-add them in Snowsight editor after any rebuild.

### ARM Agent Tools

| Tool | Type | Capability |
|------|------|------------|
| `CRM_Analytics` | Cortex Analyst → `SV_CRM_SALES_INTELLIGENCE` | Structured SQL: pipeline metrics, rep performance, call volume, revenue forecasting, game attendance |
| `Email_Search` | Cortex Search → `EMAIL_SEARCH_SERVICE` | Semantic search across ~161K emails by sentiment, topic, date |
| `Call_Search` | Cortex Search → `CALL_SEARCH_SERVICE` | Semantic search across ~40K call notes, voicemails, dispositions |
| `Opportunity_Search` | Cortex Search → `OPPORTUNITY_SEARCH_SERVICE` | Semantic search across ~28K opportunities with AI health scores |

## T_CALL_ACTIVITY Design

Unions two Zoom data sources:

| Source | Join Method | Agent Attribution |
|--------|-------------|------------------|
| `SESSION_HISTORY` | LEFT JOIN on `ZVC_AGENT_EMAIL_C = u.EMAIL` | Falls back to `sh.OWNER_ID` (queue ID) if email match fails |
| `ZOOM_CALL_LOG` | INNER JOIN on `cl.OWNER_ID = u.ID` | Record excluded entirely if join fails |

**Known issue pattern**: `V_ODS_SALESFORCE_TASK` can have multiple `SYSTEM_CURRENT_FLAG = 'Y'` rows for the same task ID (SCD Type 2 data quality). All `task_link` CTEs must include `QUALIFY ROW_NUMBER() OVER (PARTITION BY t.ID ORDER BY t.SYSTEM_VERSION DESC) = 1` to prevent fan-out duplication.

**Do NOT run `CREATE OR REPLACE TABLE T_CALL_ACTIVITY`** — ever. It causes two unrecoverable problems: (1) wipes change tracking, breaking CALL_SEARCH_SERVICE; (2) orphans stream records that were already consumed, creating permanent data gaps. If records are missing, use a source-view backfill: INSERT INTO T_CALL_ACTIVITY ... FROM V_ODS_SALESFORCE_CRM_ZVC_SESSION_HISTORY_C / V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C with NOT EXISTS guard. This is safe and idempotent.

## Sales Team Structure

8 departments across 43 reps:
- `TICKET_LEADERSHIP` — 11 reps (managers/directors who oversee staff)
- `TICKET_SALES` — 7 Group AEs
- `CORPORATE_PARTNERSHIP_SALES` — 6 reps
- `TICKET_SERVICE` — 5 reps
- `TICKET_MEMBER_AE` — 4 reps
- `TICKET_TSR` — 4 reps (Benjamin Knee, Alexa Linkchuck, Emily Prindiville, Torrey Pursel)
- `TICKET_INTERN` — 4 reps
- `CALL_CENTER` — 2 reps

Rep-to-user mapping is maintained in `T_TICKET_TEAM_DEPARTMENT_MAPPING`. Rep profile ID for active sales reps: `00ecw000001t0rfAAA`.

## Cost Profile

~$3–6/day (~$90–180/month). Five layers of cost protection:
1. `SYSTEM$STREAM_HAS_DATA` — task only fires when changes exist
2. `LIMIT 500` on email enrichment — caps AI calls per cycle
3. `NOT EXISTS` guards — prevents duplicate inserts
4. Changed-only scoring — deal health scores only changed opps in 'Initial Conversation' or 'In-Contact' stages
5. Once-daily timestamp checks — call activity and email analytics skip if already run today

**Historical warning**: Dynamic Tables with Cortex AI functions force full refresh and caused a $25K/week cost overrun. Never use Dynamic Tables for AI enrichment — use Streams + Tasks instead.

## Key Conventions

- Always filter `SYSTEM_CURRENT_FLAG = 'Y'` on all SCD Type 2 source views
- Never use `DATE_TRUNC = string` comparisons on timestamp fields — always use range-based filtering (`>= date AND < date + 1`)
- Cortex Search Services require VARCHAR columns — extract JSON fields to VARCHAR before indexing
- `WHEN` clause on child tasks only supports `SYSTEM$STREAM_HAS_DATA` — use `BEGIN/IF` blocks for more complex daily-only logic
- Department codes in semantic view queries: `TICKET_TSR`, `TICKET_SALES`, `TICKET_SERVICE`, `TICKET_MEMBER_AE`, `CORPORATE_PARTNERSHIP_SALES`, `TICKET_LEADERSHIP`, `TICKET_INTERN`, `CALL_CENTER`
- **Snowflake does not support correlated subqueries inside CTE WHERE clauses** — use LEFT JOIN instead. Example: the `TSK_REFRESH_DEAL_HEALTH` changed-only filter originally used `(SELECT tgt2.SCORING_TIMESTAMP FROM ... WHERE tgt2.OPPORTUNITY_ID = oam.OPPORTUNITY_ID)` which silently returned 0 rows. Fixed March 10, 2026 by replacing with `LEFT JOIN T_DEAL_HEALTH_SCORE dh ON oam.OPPORTUNITY_ID = dh.OPPORTUNITY_ID`.

## Monitoring & Health Check

### Automated Protection (deployed March 9, 2026)

1. **Retry tolerance**: Root task `TSK_ENRICH_NEW_EMAILS` has `SUSPEND_TASK_AFTER_NUM_FAILURES = 3` — survives transient Cortex AI timeouts instead of dying on the first failure.
2. **Daily health check**: `TSK_CRM_AGENT_HEALTH_CHECK` runs at 7am ET, checks freshness of all 6 permanent tables and deal health score distribution (alerts if Critical > 80%), sends email via `CRM_AGENT_ALERTS` notification integration if anything needs attention.
3. **Audit log**: `T_CRM_AGENT_HEALTH_LOG` records every health check result (HEALTHY or UNHEALTHY with details).

### Freshness Thresholds

| Table | Stale After | Why |
|-------|------------|-----|
| `T_EMAIL_ENRICHED` | 26 hours | Should refresh every 2-hour cycle |
| `T_OPPORTUNITY_ACTIVITY_METRICS` | 26 hours | Runs after every email enrichment |
| `T_DEAL_HEALTH_SCORE` | 26 hours | Runs after activity metrics |
| `T_CUSTOMER_360` | 26 hours | Runs after activity metrics |
| `T_EMAIL_ANALYTICS` | 48 hours | Once-daily rebuild |
| `T_CALL_ACTIVITY` | 48 hours | Once-daily incremental |

### Emergency Recovery Playbook

See `Health_Check.SQL` for full recovery procedures. Quick reference:

- **Root task suspended** → `ALTER TASK TSK_ENRICH_NEW_EMAILS RESUME;`
- **Stream stale** → `CREATE OR REPLACE STREAM ... ON VIEW ... APPEND_ONLY = TRUE;`
- **Child task suspended** → Suspend root → resume child → resume root
- **Full manual refresh** → Run Steps 1-8 from Health_Check.SQL comments (~30 min, ~$25-35)
- **TASK_HISTORY query** → Must use `TBRDP_DW_PROD.INFORMATION_SCHEMA.TASK_HISTORY()` (fully qualified database prefix required)
