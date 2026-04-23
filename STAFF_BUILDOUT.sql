-- =============================================================================
-- TICKET TEAM DEPARTMENT CLASSIFICATION
-- =============================================================================
-- 23 reps across 5 departments:
--   TICKET_SALES (7), TICKET_SERVICE (4), TICKET_MEMBER_AE (2),
--   TICKET_TSR (4), CORPORATE_PARTNERSHIP_SALES (6)
-- =============================================================================

-- STEP 1: DEPARTMENT MAPPING TABLE
CREATE OR REPLACE TABLE TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING AS
SELECT user_id, user_name, department, team, 
       CURRENT_TIMESTAMP() AS classification_date, 
       'Manual Classification - Feb 2026' AS classification_source
FROM (
    -- TICKET SALES GROUP ACCOUNT EXECUTIVES (7)
    SELECT '005cw000001aoaPAAQ' AS user_id, 'Rafael Lazala' AS user_name, 'TICKET_SALES' AS department, 'Ticket Sales Group Account Executives' AS team
    UNION ALL SELECT '005cw000002URuTAAW', 'Brock Shively', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    UNION ALL SELECT '005cw000003XvozAAC', 'Colin McGlinchey', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    UNION ALL SELECT '005cw000002URsrAAG', 'Jordan Beech', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    UNION ALL SELECT '005cw000001cB1tAAE', 'Tate Anderson', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    UNION ALL SELECT '005cw000001c9bCAAQ', 'Brandon Harnick', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    UNION ALL SELECT '005cw000001c8GxAAI', 'Lindsay Auld', 'TICKET_SALES', 'Ticket Sales Group Account Executives'
    -- TICKET SERVICE REPRESENTATIVES (4)
    UNION ALL SELECT '005cw000001cAqbAAE', 'Jared Consiglio', 'TICKET_SERVICE', 'Ticket Service'
    UNION ALL SELECT '005cw000001aoc1AAA', 'Kacey McGlone', 'TICKET_SERVICE', 'Ticket Service'
    UNION ALL SELECT '005cw000001cAx3AAE', 'Steven Long', 'TICKET_SERVICE', 'Ticket Service'
    UNION ALL SELECT '005cw000001cB9xAAE', 'Zach Grundt', 'TICKET_SERVICE', 'Ticket Service'
    -- TICKET SEASON MEMBER ACCOUNT EXECUTIVES (2)
    UNION ALL SELECT '005cw000005SFqrAAG', 'Eric Yalowitz', 'TICKET_MEMBER_AE', 'Ticket Account Executive'
    UNION ALL SELECT '005cw000005SFm1AAG', 'Madison Jones', 'TICKET_MEMBER_AE', 'Ticket Account Executive'
    -- TICKET SALES REPRESENTATIVES / TSRs (4)
    UNION ALL SELECT '005cw000005SFyvAAG', 'Alexa Linchuck', 'TICKET_TSR', 'Ticket Sales Representative'
    UNION ALL SELECT '005cw000005SG0XAAW', 'Benjamin Knee', 'TICKET_TSR', 'Ticket Sales Representative'
    UNION ALL SELECT '005cw000005SG5NAAW', 'Emily Prindiville', 'TICKET_TSR', 'Ticket Sales Representative'
    UNION ALL SELECT '005cw000005SJJNAA4', 'Torrey Pursel', 'TICKET_TSR', 'Ticket Sales Representative'
    -- CORPORATE PARTNERSHIP SALES (6)
    UNION ALL SELECT '005cw000001SUsDAAW', 'John Pope', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
    UNION ALL SELECT '005cw000001c96XAAQ', 'Jazzmine McDonald', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
    UNION ALL SELECT '005cw000001SV57AAG', 'Ifadare Ogunleye', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
    UNION ALL SELECT '005cw000001SV9xAAG', 'Michael Lee', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
    UNION ALL SELECT '005cw000001c8iMAAQ', 'Daniel Schonborn', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
    UNION ALL SELECT '005cw000001c9XxAAI', 'Stephen Lanier', 'CORPORATE_PARTNERSHIP_SALES', 'CP Sales'
);

-- STEP 2: ENRICHED USER VIEW WITH DEPARTMENT INFO
CREATE OR REPLACE VIEW TBRDP_DW_PROD.IM_RPT.V_TICKET_TEAM_WITH_DEPARTMENT
COMMENT = 'Ticket team members with department classification and full Salesforce user details'
AS
SELECT 
    u.ID AS user_id,
    u.NAME AS user_name,
    u.EMAIL,
    u.USERNAME,
    d.department,
    d.team,
    d.classification_date,
    d.classification_source,
    u.IS_ACTIVE,
    u._FIVETRAN_DELETED AS IS_DELETED,
    u.PROFILE_ID,
    u.USER_TYPE,
    u.CREATED_DATE,
    u.LAST_LOGIN_DATE,
    u.LAST_MODIFIED_DATE
FROM TBRDP_DW_PROD.IM_RPT.V_ODS_SALESFORCE_USER u
INNER JOIN TBRDP_DW_PROD.IM_RPT.T_TICKET_TEAM_DEPARTMENT_MAPPING d
    ON u.ID = d.user_id
WHERE u.IS_ACTIVE = TRUE
  AND u._FIVETRAN_DELETED = FALSE;
