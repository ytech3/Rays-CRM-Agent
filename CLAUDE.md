# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Snowflake SQL definitions for the **ARM Agent** (Account & Relationship Management Agent) — a CRM Intelligence Platform powered by Snowflake Cortex. It enriches Salesforce data with AI-generated sentiment analysis, deal health scoring, and call activity tracking to support the Tampa Bay Rays ticket sales organization.

Target schema: `TBRDP_DW_PROD.IM_RPT`
Warehouse: `TBRDP_DW_CORTEX_XS_WH`
Agent model: Claude Sonnet 4

There are no build, lint, or test commands. Changes are deployed by executing SQL directly against Snowflake.

## Files

- **T_Call_Activity.SQL** — Defines `T_CALL_ACTIVITY`, a permanent table unioning Zoom Session History and Zoom Call Log call records. Also defines `TSK_REFRESH_CALL_ACTIVITY`, the incremental task that appends new records daily.
- **Semantic_View.SQL** — Defines `SV_CRM_SALES_INTELLIGENCE`, the Snowflake Semantic View used by Cortex Analyst for natural-language SQL queries.
- **Email_Analytics.SQL** — Defines `T_EMAIL_ANALYTICS`, a permanent table of individual email records with direction, rep attribution, response times, sentiment, and time-of-day buckets.
- **CRM_AGENT_CONFIG.yaml** — Cortex Agent configuration file defining the three tools (Cortex Analyst, Email Search, Opportunity Search) and system prompt.
- **CRM_AGENT_FILES.md** — Comprehensive schema documentation for all source views and enriched tables.

## Architecture

### Data Flow

Salesforce data lands via Fivetran into source views → Streams detect changes → Task DAG enriches and materializes into permanent tables → Cortex Search indexes the tables → Cortex Analyst queries the Semantic View → ARM Agent orchestrates all three tools.

### Permanent Enriched Tables

| Table | Rows | Description |
|-------|------|-------------|
| `T_EMAIL_ENRICHED` | ~98K | Emails with AI sentiment, topic, signal, summary (llama3.1-70b) |
| `T_EMAIL_ANALYTICS` | ~101K | Email records with direction, rep attribution, response times, sentiment |
| `T_OPPORTUNITY_ACTIVITY_METRICS` | ~22,787 | Email/call/task counts, engagement levels, ghosting flags per opportunity |
| `T_DEAL_HEALTH_SCORE` | ~22,787 | AI health scores (0–100), categories (Healthy/At Risk/Critical) |
| `T_CUSTOMER_360` | ~371,485 | Unified customer profiles with LTV, revenue tiers, churn risk, upsell flags |
| `T_CALL_ACTIVITY` | Growing | Zoom call records from Session History + Call Log, deduped by session_id |
| `T_TICKET_TEAM_DEPARTMENT_MAPPING` | 23 reps | 5 departments: TICKET_SALES (7), TICKET_SERVICE (4), TICKET_MEMBER_AE (2), TICKET_TSR (4), CORPORATE_PARTNERSHIP_SALES (6) |

### Streams (4 active, append-only)

| Stream | Source View |
|--------|------------|
| `STM_NEW_EMAILS` | `V_ODS_SALESFORCE_CRM_EMAIL_MESSAGE` |
| `STM_OPPORTUNITY_CHANGES` | `V_ODS_SALESFORCE_OPPORTUNITY` |
| `STM_CALL_LOG_CHANGES` | `V_ODS_SALESFORCE_CRM_ZVC_ZOOM_CALL_LOG_C` |
| `STM_TASK_CHANGES` | `V_ODS_SALESFORCE_TASK` |

### Task DAG (6 tasks, 2-hour cycle)

```
TSK_ENRICH_NEW_EMAILS (root, 120-min schedule, SYSTEM$STREAM_HAS_DATA guard, LIMIT 500)
├── TSK_REFRESH_ACTIVITY_METRICS (child, pure SQL)
├── TSK_REFRESH_DEAL_HEALTH (grandchild, AI call, changed-only ~200 opps)
├── TSK_REFRESH_CUSTOMER_360 (grandchild, pure SQL)
├── TSK_REFRESH_EMAIL_ANALYTICS (grandchild, pure SQL, once-daily timestamp check)
└── TSK_REFRESH_CALL_ACTIVITY (child, pure SQL, once-daily timestamp check)
```

**Critical**: When modifying any task in the DAG, the root task (`TSK_ENRICH_NEW_EMAILS`) must be suspended first, then the child task modified, then the root task resumed.

### Cortex Search Services (2 active)

| Service | Source | Lag | Embedding Model |
|---------|--------|-----|-----------------|
| `EMAIL_SEARCH_SERVICE` | `V_EMAIL_SEARCH_SOURCE` (view on `T_EMAIL_ENRICHED`) | 4 hours | snowflake-arctic-embed-l-v2.0 |
| `OPPORTUNITY_SEARCH_SERVICE` | `V_OPPORTUNITY_CONTEXT_SEARCH` (view on opportunity + deal health) | 6 hours | snowflake-arctic-embed-l-v2.0 |

### Semantic View (`SV_CRM_SALES_INTELLIGENCE`)

7 logical tables: `OPPORTUNITIES`, `DEAL_HEALTH`, `ACTIVITY_METRICS`, `USERS`, `TICKET_TEAM_DEPT`, `CUSTOMER_360`, `EMAIL_ANALYTICS`

Named filter: `CURRENT_RECORDS_ONLY` (`SYSTEM_CURRENT_FLAG = 'Y'`) on OPPORTUNITIES.

**Critical**: `CREATE OR REPLACE SEMANTIC VIEW` wipes all named filters and verified queries — always re-add them in Snowsight editor after any rebuild.

### ARM Agent Tools

| Tool | Type | Capability |
|------|------|------------|
| `CRM_Analytics` | Cortex Analyst → `SV_CRM_SALES_INTELLIGENCE` | Structured SQL: pipeline metrics, rep performance, revenue forecasting |
| `Email_Search` | Cortex Search → `EMAIL_SEARCH_SERVICE` | Semantic search across 90K+ emails by sentiment, topic, date |
| `Opportunity_Search` | Cortex Search → `OPPORTUNITY_SEARCH_SERVICE` | Semantic search across 22K+ opportunities with AI health scores |

## T_CALL_ACTIVITY Design

Unions two Zoom data sources:

| Source | Join Method | Agent Attribution |
|--------|-------------|------------------|
| `SESSION_HISTORY` | LEFT JOIN on `ZVC_AGENT_EMAIL_C = u.EMAIL` | Falls back to `sh.OWNER_ID` (queue ID) if email match fails |
| `ZOOM_CALL_LOG` | INNER JOIN on `cl.OWNER_ID = u.ID` | Record excluded entirely if join fails |

**Known issue pattern**: `V_ODS_SALESFORCE_TASK` can have multiple `SYSTEM_CURRENT_FLAG = 'Y'` rows for the same task ID (SCD Type 2 data quality). All `task_link` CTEs must include `QUALIFY ROW_NUMBER() OVER (PARTITION BY t.ID ORDER BY t.SYSTEM_VERSION DESC) = 1` to prevent fan-out duplication.

**Do NOT run `CREATE OR REPLACE TABLE T_CALL_ACTIVITY`** to fix duplicates — use the table swap dedup approach instead (reads only the existing table, not all source views).

## Sales Team Structure

5 departments across 23 reps:
- `TICKET_SALES` — 7 Group AEs
- `TICKET_SERVICE` — 4 reps
- `TICKET_MEMBER_AE` — 2 reps
- `TICKET_TSR` — 4 reps (Benjamin Knee, Alexa Linkchuck, Emily Prindiville, Torrey Pursel)
- `CORPORATE_PARTNERSHIP_SALES` — 6 reps

Rep-to-user mapping is maintained in `T_TICKET_TEAM_DEPARTMENT_MAPPING`. Rep profile ID for active sales reps: `00ecw000001t0rfAAA`.

## Cost Profile

~$3–6/day (~$90–180/month). Five layers of cost protection:
1. `SYSTEM$STREAM_HAS_DATA` — task only fires when changes exist
2. `LIMIT 500` on email enrichment — caps AI calls per cycle
3. `NOT EXISTS` guards — prevents duplicate inserts
4. Changed-only scoring — deal health scores ~200 changed opps, not all 22K
5. Once-daily timestamp checks — call activity and email analytics skip if already run today

**Historical warning**: Dynamic Tables with Cortex AI functions force full refresh and caused a $25K/week cost overrun. Never use Dynamic Tables for AI enrichment — use Streams + Tasks instead.

## Key Conventions

- Always filter `SYSTEM_CURRENT_FLAG = 'Y'` on all SCD Type 2 source views
- Never use `DATE_TRUNC = string` comparisons on timestamp fields — always use range-based filtering (`>= date AND < date + 1`)
- Cortex Search Services require VARCHAR columns — extract JSON fields to VARCHAR before indexing
- `WHEN` clause on child tasks only supports `SYSTEM$STREAM_HAS_DATA` — use `BEGIN/IF` blocks for more complex daily-only logic
- Department codes in semantic view queries: `TICKET_TSR`, `TICKET_SALES`, `TICKET_SERVICE`, `TICKET_MEMBER_AE`, `CORPORATE_PARTNERSHIP_SALES`
