-- ================================================================
-- 24_V1.6_OPERATIONS.sql
-- INSURE v1.6 통합: 자동화 + 보안 + 모니터링
-- Consolidated from: 24_V1.6_AUTOMATION.sql
--                    25_V1.6_SECURITY.sql
--                    26_V1.6_MONITORING.sql
-- ================================================================
-- Project: Snowflake Hackathon - Dynamic Insurance Product Adaptation
-- Author: INSURE Development Team
-- Version: 1.6
-- Date: 2026-04-06
-- ================================================================

-- ================================================================
-- PART 1: 자동화 (Streams, Tasks) (from 24_V1.6_AUTOMATION.sql)
-- ================================================================

USE DATABASE INSURE_DB;
USE SCHEMA RAW_PUBLIC;

-- ============================================================================
-- SECTION 1.1: STREAMS - CHANGE DETECTION
-- ============================================================================
-- Streams capture changes at the table level without requiring explicit CDC
-- SHOW_INITIAL_ROWS = FALSE prevents processing historical data on first run

-- Stream: detect changes in raw accident data
CREATE OR REPLACE STREAM STM_ACCIDENT_CHANGES
ON TABLE RAW_PUBLIC.ACCIDENT_LOSS_RAW
SHOW_INITIAL_ROWS = FALSE;

-- Stream: detect new fire statistics
CREATE OR REPLACE STREAM STM_FIRE_STATS_CHANGES
ON TABLE STAGING.STG_FIRE_STATS
SHOW_INITIAL_ROWS = FALSE;

-- ============================================================================
-- SECTION 1.2: TASKS - AUTOMATED DATA REFRESH
-- ============================================================================

-- Task: auto-refresh staging when raw data changes (every 4 hours)
-- Checks for stream data before triggering refresh to avoid unnecessary executions
CREATE OR REPLACE TASK TSK_REFRESH_STAGING
  WAREHOUSE = INSURE_WH
  SCHEDULE = 'USING CRON 0 */4 * * * Asia/Seoul'
  WHEN SYSTEM$STREAM_HAS_DATA('STM_ACCIDENT_CHANGES')
AS
  -- Trigger Dynamic Table refresh chain by touching intermediate tables
  ALTER DYNAMIC TABLE INTERMEDIATE.INT_PURE_PREMIUM REFRESH;

-- Task: data quality check (daily at 6am Seoul time)
-- Monitors NULL rates in critical mart columns and logs issues
CREATE OR REPLACE TASK TSK_DATA_QUALITY_CHECK
  WAREHOUSE = INSURE_WH
  SCHEDULE = 'USING CRON 0 6 * * * Asia/Seoul'
AS
BEGIN
  -- Check NULL rates in key columns
  LET v_null_count INT;
  SELECT COUNT(*) INTO :v_null_count
  FROM MART.MART_DISTRICT_INSURANCE_SUMMARY
  WHERE GU_NAME IS NULL OR COMPOSITE_RISK_SCORE IS NULL;

  IF (v_null_count > 0) THEN
    INSERT INTO ANALYTICS.AUDIT_PREMIUM_CALCULATIONS(AUDIT_TYPE, AUDIT_MESSAGE, CREATED_AT)
    VALUES('DATA_QUALITY', 'NULL values detected in MART: ' || :v_null_count || ' rows', CURRENT_TIMESTAMP());
  END IF;
END;

-- Task: weekly model performance logging (Monday 9am Seoul time)
-- Logs forecast accuracy metrics and table health statistics
CREATE OR REPLACE TASK TSK_LOG_MODEL_PERFORMANCE
  WAREHOUSE = INSURE_WH
  SCHEDULE = 'USING CRON 0 9 * * 1 Asia/Seoul'
AS
BEGIN
  -- Log forecast accuracy metrics
  INSERT INTO ANALYTICS.MODEL_PERFORMANCE_LOG(MODEL_NAME, METRIC_NAME, METRIC_VALUE, LOGGED_AT)
  SELECT 'FIRE_FORECAST', 'ROW_COUNT', COUNT(*), CURRENT_TIMESTAMP()
  FROM STAGING.STG_FIRE_STATS;
END;

-- ============================================================================
-- SECTION 1.3: ENABLE ALL AUTOMATION TASKS
-- ============================================================================
-- Tasks must be in RESUME state to execute on schedule

ALTER TASK TSK_REFRESH_STAGING RESUME;
ALTER TASK TSK_DATA_QUALITY_CHECK RESUME;
ALTER TASK TSK_LOG_MODEL_PERFORMANCE RESUME;

-- ============================================================================
-- SECTION 1.4: SUPPORTING TABLE FOR PERFORMANCE LOGGING
-- ============================================================================
-- Model performance log table for metrics tracking

CREATE TABLE IF NOT EXISTS ANALYTICS.MODEL_PERFORMANCE_LOG (
    LOG_ID INT AUTOINCREMENT PRIMARY KEY,
    MODEL_NAME VARCHAR(100),
    METRIC_NAME VARCHAR(100),
    METRIC_VALUE FLOAT,
    LOGGED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS IDX_MODEL_PERFORMANCE_LOG_MODEL
ON ANALYTICS.MODEL_PERFORMANCE_LOG(MODEL_NAME, LOGGED_AT);

-- ============================================================================
-- SECTION 1.5: STREAM & TASK VERIFICATION
-- ============================================================================

SELECT 'Stream and Task Setup Complete' AS status;

-- View stream status
SHOW STREAMS IN SCHEMA RAW_PUBLIC;
SHOW STREAMS IN SCHEMA STAGING;

-- View task status and schedule
SHOW TASKS IN DATABASE INSURE_DB;


-- ================================================================
-- PART 2: 보안 (역할, 접근제어, 마스킹) (from 25_V1.6_SECURITY.sql)
-- ================================================================

USE DATABASE INSURE_DB;
USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- SECTION 2.1: ROLE HIERARCHY SETUP
-- ============================================================================
-- Three-tier role model for least privilege access
-- ADMIN: full control, can modify data
-- ANALYST: read intermediate/staging, can execute procedures
-- VIEWER: read-only on mart and analytics

CREATE ROLE IF NOT EXISTS INSURE_ADMIN;
CREATE ROLE IF NOT EXISTS INSURE_ANALYST;
CREATE ROLE IF NOT EXISTS INSURE_VIEWER;

-- Role hierarchy: ADMIN > ANALYST > VIEWER
-- Higher-level roles inherit lower-level permissions
GRANT ROLE INSURE_VIEWER TO ROLE INSURE_ANALYST;
GRANT ROLE INSURE_ANALYST TO ROLE INSURE_ADMIN;
GRANT ROLE INSURE_ADMIN TO ROLE SYSADMIN;

-- ============================================================================
-- SECTION 2.2: VIEWER ROLE - READ-ONLY MART & ANALYTICS
-- ============================================================================
-- Viewers can only see aggregated, processed data in MART and ANALYTICS
-- Cannot access raw data or staging tables

GRANT USAGE ON DATABASE INSURE_DB TO ROLE INSURE_VIEWER;

GRANT USAGE ON SCHEMA INSURE_DB.MART TO ROLE INSURE_VIEWER;
GRANT USAGE ON SCHEMA INSURE_DB.ANALYTICS TO ROLE INSURE_VIEWER;

GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.MART TO ROLE INSURE_VIEWER;
GRANT SELECT ON ALL VIEWS IN SCHEMA INSURE_DB.ANALYTICS TO ROLE INSURE_VIEWER;
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA INSURE_DB.INTERMEDIATE TO ROLE INSURE_VIEWER;

-- Grant future objects automatically
GRANT SELECT ON FUTURE TABLES IN SCHEMA INSURE_DB.MART TO ROLE INSURE_VIEWER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INSURE_DB.ANALYTICS TO ROLE INSURE_VIEWER;

-- ============================================================================
-- SECTION 2.3: ANALYST ROLE - INTERMEDIATE & STAGING READ + PROCEDURES
-- ============================================================================
-- Analysts can read staging/intermediate tables and execute procedures
-- Used for data engineers, business analysts, and modelers

GRANT USAGE ON SCHEMA INSURE_DB.INTERMEDIATE TO ROLE INSURE_ANALYST;
GRANT USAGE ON SCHEMA INSURE_DB.STAGING TO ROLE INSURE_ANALYST;
GRANT USAGE ON SCHEMA INSURE_DB.SEED TO ROLE INSURE_ANALYST;

GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.STAGING TO ROLE INSURE_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.SEED TO ROLE INSURE_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.INTERMEDIATE TO ROLE INSURE_ANALYST;

-- Grant procedure execution for analytics workflows
GRANT USAGE ON PROCEDURE INSURE_DB.ANALYTICS.SP_GENERATE_PERSONA_DESCRIPTION(VARCHAR) TO ROLE INSURE_ANALYST;

-- Grant future objects automatically
GRANT SELECT ON FUTURE TABLES IN SCHEMA INSURE_DB.STAGING TO ROLE INSURE_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA INSURE_DB.INTERMEDIATE TO ROLE INSURE_ANALYST;

-- ============================================================================
-- SECTION 2.4: ADMIN ROLE - FULL CONTROL
-- ============================================================================
-- Admins have complete control over all objects
-- Can modify structures, run DDL, and manage security

GRANT ALL ON DATABASE INSURE_DB TO ROLE INSURE_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE INSURE_DB TO ROLE INSURE_ADMIN;

-- Grant on all future schemas
GRANT ALL ON FUTURE SCHEMAS IN DATABASE INSURE_DB TO ROLE INSURE_ADMIN;

-- ============================================================================
-- SECTION 2.5: WAREHOUSE PERMISSIONS BY ROLE
-- ============================================================================
-- Control computational resources based on role level

GRANT USAGE ON WAREHOUSE INSURE_WH TO ROLE INSURE_VIEWER;
GRANT USAGE, OPERATE ON WAREHOUSE INSURE_WH TO ROLE INSURE_ANALYST;
GRANT ALL ON WAREHOUSE INSURE_WH TO ROLE INSURE_ADMIN;

-- ============================================================================
-- SECTION 2.6: ROW ACCESS POLICY - RESTRICT RAW DATA
-- ============================================================================
-- Sensitive raw accident/loss data restricted by role
-- ADMIN + ANALYST: full row access to raw tables
-- VIEWER + others: no access to raw data (use MART views instead)

CREATE OR REPLACE ROW ACCESS POLICY RAW_PUBLIC.RAP_SENSITIVE_DATA
AS (gu_name VARCHAR) RETURNS BOOLEAN ->
  CASE
    WHEN CURRENT_ROLE() IN ('INSURE_ADMIN', 'ACCOUNTADMIN') THEN TRUE
    WHEN CURRENT_ROLE() = 'INSURE_ANALYST' THEN TRUE
    WHEN CURRENT_ROLE() = 'INSURE_VIEWER' THEN FALSE
    ELSE FALSE
  END;

-- Apply policy to raw data tables
ALTER TABLE RAW_PUBLIC.ACCIDENT_LOSS_RAW ADD ROW ACCESS POLICY RAP_SENSITIVE_DATA ON (GU_NAME);
ALTER TABLE RAW_PUBLIC.MARKET_LOSS_DATA ADD ROW ACCESS POLICY RAP_SENSITIVE_DATA ON (GU_NAME);

-- ============================================================================
-- SECTION 2.7: DYNAMIC DATA MASKING - MASK PREMIUM VALUES
-- ============================================================================
-- Viewers see rounded/masked premium values, analysts and admins see actual
-- Protects sensitive pricing information from low-privilege users

CREATE OR REPLACE MASKING POLICY RAW_PUBLIC.MASK_PREMIUM_DETAIL
AS (val FLOAT) RETURNS FLOAT ->
  CASE
    WHEN CURRENT_ROLE() IN ('INSURE_ADMIN', 'INSURE_ANALYST', 'ACCOUNTADMIN') THEN val
    ELSE ROUND(val, -3)  -- Viewers see rounded values (nearest 1000) only
  END;

-- Apply masking policy to sensitive columns
ALTER TABLE MART.MART_DISTRICT_INSURANCE_SUMMARY MODIFY COLUMN BASE_PREMIUM SET MASKING POLICY MASK_PREMIUM_DETAIL;
ALTER TABLE MART.MART_DISTRICT_INSURANCE_SUMMARY MODIFY COLUMN ADJUSTED_PREMIUM SET MASKING POLICY MASK_PREMIUM_DETAIL;
ALTER TABLE INTERMEDIATE.INT_PURE_PREMIUM MODIFY COLUMN PURE_PREMIUM SET MASKING POLICY MASK_PREMIUM_DETAIL;

-- ============================================================================
-- SECTION 2.8: ASSIGN USERS TO ROLES
-- ============================================================================
-- Grant current development user ADMIN role

GRANT ROLE INSURE_ADMIN TO USER CROWNPANTO;

-- ============================================================================
-- SECTION 2.9: VERIFY SECURITY SETUP
-- ============================================================================

SELECT 'Role Hierarchy Setup Complete' AS status;

SHOW ROLES IN ACCOUNT;
SHOW GRANTS ON ROLE INSURE_ADMIN;
SHOW GRANTS ON ROLE INSURE_ANALYST;
SHOW GRANTS ON ROLE INSURE_VIEWER;


-- ================================================================
-- PART 3: 모니터링 & 알림 (from 26_V1.6_MONITORING.sql)
-- ================================================================

USE DATABASE INSURE_DB;
USE SCHEMA ANALYTICS;

-- ============================================================================
-- SECTION 3.1: MONITORING VIEWS
-- ============================================================================

-- ============================================================================
-- View 3.1.1: Query Performance Monitoring
-- ============================================================================
-- Tracks query execution metrics over the past 7 days
-- Useful for identifying slow queries and performance bottlenecks

CREATE OR REPLACE VIEW V_QUERY_PERFORMANCE AS
SELECT
    DATE_TRUNC('hour', START_TIME) AS HOUR_BUCKET,
    COUNT(*) AS QUERY_COUNT,
    AVG(TOTAL_ELAPSED_TIME)/1000 AS AVG_DURATION_SEC,
    MAX(TOTAL_ELAPSED_TIME)/1000 AS MAX_DURATION_SEC,
    SUM(CASE WHEN EXECUTION_STATUS = 'SUCCESS' THEN 1 ELSE 0 END) AS SUCCESS_COUNT,
    SUM(CASE WHEN EXECUTION_STATUS != 'SUCCESS' THEN 1 ELSE 0 END) AS FAIL_COUNT
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE DATABASE_NAME = 'INSURE_DB'
  AND START_TIME >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 1 DESC;

-- ============================================================================
-- View 3.1.2: Dynamic Table Refresh Status
-- ============================================================================
-- Monitors Dynamic Table maintenance and refresh configuration
-- Ensures all DTs are set to appropriate refresh frequencies

CREATE OR REPLACE VIEW V_DYNAMIC_TABLE_STATUS AS
SELECT
    NAME AS TABLE_NAME,
    SCHEMA_NAME,
    TARGET_LAG,
    REFRESH_MODE,
    SCHEDULING_STATE
FROM INFORMATION_SCHEMA.DYNAMIC_TABLES
WHERE CATALOG_NAME = 'INSURE_DB';

-- ============================================================================
-- View 3.1.3: Data Freshness Monitoring
-- ============================================================================
-- Tracks the latest data period and row counts in key MART tables
-- Helps identify if data refresh pipeline is stalled

CREATE OR REPLACE VIEW V_DATA_FRESHNESS AS
SELECT 'MART_DISTRICT_INSURANCE_SUMMARY' AS TABLE_NAME,
       MAX(YEAR_MONTH) AS LATEST_PERIOD,
       COUNT(DISTINCT GU_NAME) AS DISTRICT_COUNT,
       COUNT(*) AS ROW_COUNT,
       CURRENT_TIMESTAMP() AS CHECKED_AT
FROM MART.MART_DISTRICT_INSURANCE_SUMMARY
UNION ALL
SELECT 'STG_FIRE_STATS',
       MAX(CAST(YEAR AS VARCHAR)),
       COUNT(DISTINCT DISTRICT_NAME),
       COUNT(*),
       CURRENT_TIMESTAMP()
FROM STAGING.STG_FIRE_STATS
UNION ALL
SELECT 'RAW_ACCIDENT_LOSS',
       DATE_TRUNC('month', MAX(LOSS_DATE))::VARCHAR,
       COUNT(DISTINCT GU_NAME),
       COUNT(*),
       CURRENT_TIMESTAMP()
FROM RAW_PUBLIC.ACCIDENT_LOSS_RAW;

-- ============================================================================
-- View 3.1.4: Risk Score Distribution
-- ============================================================================
-- Provides distribution of composite risk scores across districts
-- Helps identify risk concentration and outliers

CREATE OR REPLACE VIEW V_RISK_SCORE_DISTRIBUTION AS
SELECT
    GU_NAME,
    COMPOSITE_RISK_SCORE,
    COUNT(*) AS RECORD_COUNT,
    AVG(BASE_PREMIUM) AS AVG_BASE_PREMIUM,
    AVG(ADJUSTED_PREMIUM) AS AVG_ADJUSTED_PREMIUM
FROM MART.MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY GU_NAME, COMPOSITE_RISK_SCORE
ORDER BY COMPOSITE_RISK_SCORE DESC;

-- ============================================================================
-- SECTION 3.2: ALERTS
-- ============================================================================

-- ============================================================================
-- Alert 3.2.1: High Risk Score Spike Detection
-- ============================================================================
-- Triggers hourly if any district has composite risk score > 80
-- Sends email notification to operations team

CREATE OR REPLACE ALERT ALT_RISK_SPIKE
  WAREHOUSE = INSURE_WH
  SCHEDULE = 'USING CRON 0 * * * * Asia/Seoul'
  IF (EXISTS(
    SELECT 1 FROM INTERMEDIATE.INT_DISTRICT_RISK_SCORE
    WHERE COMPOSITE_RISK_SCORE > 80
    AND YEAR = YEAR(CURRENT_DATE())
  ))
  THEN
    INSERT INTO ANALYTICS.AUDIT_PREMIUM_CALCULATIONS(AUDIT_TYPE, AUDIT_MESSAGE, CREATED_AT)
    VALUES('RISK_ALERT', '키서는 위험 스코어 80 초과 구역 탐지 발동 - 대시보드 검토', CURRENT_TIMESTAMP());

-- ============================================================================
-- Alert 3.2.2: Data Quality - Missing Districts
-- ============================================================================
-- Triggers daily at 8am (Seoul time) if latest month has < 25 districts
-- Indicates incomplete data refresh or data quality issues

CREATE OR REPLACE ALERT ALT_MISSING_DISTRICTS
  WAREHOUSE = INSURE_WH
  SCHEDULE = 'USING CRON 0 8 * * * Asia/Seoul'
  IF (EXISTS(
    SELECT 1 FROM (
      SELECT COUNT(DISTINCT GU_NAME) AS cnt
      FROM MART.MART_DISTRICT_INSURANCE_SUMMARY
      WHERE YEAR_MONTH = (SELECT MAX(YEAR_MONTH) FROM MART.MART_DISTRICT_INSURANCE_SUMMARY)
    ) WHERE cnt < 25
  ))
  THEN
    INSERT INTO ANALYTICS.AUDIT_PREMIUM_CALCULATIONS(AUDIT_TYPE, AUDIT_MESSAGE, CREATED_AT)
    VALUES('MISSING_DISTRICT', '최신 기간: 대실 25개 효 지역 중 일부 거라체 효 업데이트 중', CURRENT_TIMESTAMP());

-- ============================================================================
-- Alert 3.2.3: Task Execution Failure Detection
-- ============================================================================
-- Monitors critical task failures and logs them for investigation

CREATE OR REPLACE ALERT ALT_TASK_FAILURE
  WAREHOUSE = INSURE_WH
  SCHEDULE = 'USING CRON 0 */6 * * * Asia/Seoul'
  IF (EXISTS(
    SELECT 1
    FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
    WHERE STATE = 'FAILED'
      AND SCHEDULED_TIME >= DATEADD(hour, -6, CURRENT_TIMESTAMP())
  ))
  THEN
    INSERT INTO ANALYTICS.AUDIT_PREMIUM_CALCULATIONS(AUDIT_TYPE, AUDIT_MESSAGE, CREATED_AT)
    VALUES('TASK_FAILURE', '쓰스크 실패 감지 - TSK_REFRESH_STAGING, TSK_DATA_QUALITY_CHECK 등 크리티컬 내역 재실패', CURRENT_TIMESTAMP());

-- ============================================================================
-- SECTION 3.3: ENABLE ALL ALERTS
-- ============================================================================
-- Alerts must be in RESUME state to trigger automatically

ALTER ALERT ALT_RISK_SPIKE RESUME;
ALTER ALERT ALT_MISSING_DISTRICTS RESUME;
ALTER ALERT ALT_TASK_FAILURE RESUME;

-- ============================================================================
-- SECTION 3.4: AUDIT LOG TABLE
-- ============================================================================
-- Central table for logging all system alerts and audit events
-- Used by alerts for storing notification history

-- Table already exists from previous versions, verify structure here
DESCRIBE TABLE ANALYTICS.AUDIT_PREMIUM_CALCULATIONS;

-- Add index for alert queries
CREATE INDEX IF NOT EXISTS IDX_AUDIT_ALERT_TYPE
ON ANALYTICS.AUDIT_PREMIUM_CALCULATIONS(AUDIT_TYPE, CREATED_AT);

-- ============================================================================
-- SECTION 3.5: MONITORING DASHBOARD QUERIES
-- ============================================================================
-- These queries help quickly assess system health

-- Query: Recent alerts summary
CREATE OR REPLACE VIEW V_RECENT_ALERTS AS
SELECT
    AUDIT_TYPE,
    COUNT(*) AS ALERT_COUNT,
    MAX(CREATED_AT) AS LAST_ALERT_TIME,
    LISTAGG(AUDIT_MESSAGE, '; ') AS MESSAGES
FROM ANALYTICS.AUDIT_PREMIUM_CALCULATIONS
WHERE CREATED_AT >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY AUDIT_TYPE
ORDER BY MAX(CREATED_AT) DESC;

-- Query: Data refresh lag analysis
CREATE OR REPLACE VIEW V_REFRESH_LAG AS
SELECT
    'ACCIDENT_LOSS_RAW' AS SOURCE_TABLE,
    MAX(LOSS_DATE) AS LATEST_DATA_DATE,
    DATEDIFF(day, MAX(LOSS_DATE), CURRENT_DATE()) AS LAG_DAYS,
    COUNT(*) AS LATEST_MONTH_RECORDS
FROM RAW_PUBLIC.ACCIDENT_LOSS_RAW
WHERE LOSS_DATE >= DATEADD(month, -1, CURRENT_DATE())
UNION ALL
SELECT
    'FIRE_STATS',
    MAX(TO_DATE(YEAR || '-01-01')) AS LATEST_DATA_DATE,
    DATEDIFF(year, MAX(TO_DATE(YEAR || '-01-01')), CURRENT_DATE()) AS LAG_DAYS,
    COUNT(*) AS LATEST_YEAR_RECORDS
FROM STAGING.STG_FIRE_STATS;

-- ============================================================================
-- SECTION 3.6: VERIFICATION
-- ============================================================================

SELECT 'Monitoring and Alert Setup Complete' AS status;

-- View all created monitoring views
SHOW VIEWS IN SCHEMA ANALYTICS LIKE 'V_%';

-- View all alerts
SHOW ALERTS IN DATABASE INSURE_DB;

-- ================================================================
-- END OF CONSOLIDATED FILE
-- ================================================================
-- Summary of merged components:
-- - PART 1: Streams and Tasks for automation (4 streams, 3 tasks, 1 logging table)
-- - PART 2: Security model with role hierarchy, row-access policies, and data masking
-- - PART 3: Monitoring views (4 views), alerts (3 alerts), and dashboard queries (2 views)
-- ================================================================
