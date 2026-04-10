-- ============================================================================
-- File: 26_V1.6_MONITORING.sql
-- Purpose: INSURE Dynamic Insurance Engine - Monitoring Views & Alerts
-- Project: Snowflake Hackathon - Dynamic Insurance Product Adaptation
-- Author: INSURE Development Team
-- Version: 1.6
-- Date: 2026-04-06
-- ============================================================================
-- OVERVIEW:
-- This script creates monitoring views and automated alerts for the INSURE
-- system. Provides visibility into query performance, data freshness, model
-- accuracy, and risk score anomalies.
--
-- KEY COMPONENTS:
-- 1. Query Performance View: query execution metrics and duration trends
-- 2. Dynamic Table Status View: refresh state and target lag tracking
-- 3. Data Freshness View: latest data periods and row counts
-- 4. Risk Score Spike Alert: hourly check for high-risk districts
-- 5. Data Quality Alert: daily check for missing districts
-- 6. Email notifications for alert conditions
-- ============================================================================

USE DATABASE INSURE_DB;
USE SCHEMA ANALYTICS;

-- ============================================================================
-- SECTION 1: MONITORING VIEWS
-- ============================================================================

-- ============================================================================
-- View 1: Query Performance Monitoring
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
-- View 2: Dynamic Table Refresh Status
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
-- View 3: Data Freshness Monitoring
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
-- View 4: Risk Score Distribution
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
-- SECTION 2: ALERTS
-- ============================================================================

-- ============================================================================
-- Alert 1: High Risk Score Spike Detection
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
    VALUES('RISK_ALERT', '\uD0A4\uC11C\uB294 \uC704\uD5D8 \uC2A4\uCF54\uC5B4 80 \uCD08\uACFC \uAD6C\uC5ED \uD0D0\uC9C0 \uBC1C\uB3D9 - \ub300\uc2dc\ubcf4\ub4dc \uac80\ud1a0', CURRENT_TIMESTAMP());

-- ============================================================================
-- Alert 2: Data Quality - Missing Districts
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
    VALUES('MISSING_DISTRICT', '\uCD5C\uC2E0 \uAE30\uAC04: \uB300\uC2E4 25\uAC1C \uD6A8 \uC9C0\uC5ED \uC911 \uC77C\uBD80 \uAC70\uB77C\uC9E4 \uD6A8 \uC5C5\ub370\uc774\ud2b8 \uc911', CURRENT_TIMESTAMP());

-- ============================================================================
-- Alert 3: Task Execution Failure Detection
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
    VALUES('TASK_FAILURE', '\uC4F0\uC2A4\uD06C \uc2e4\ud328 \uac10\uc9c0 - TSK_REFRESH_STAGING, TSK_DATA_QUALITY_CHECK \ub4f1 \ud06c\ub9ac\ud2f0\uceec \ub0b4\uc5ed \uc7ac\uc2e4\ud328', CURRENT_TIMESTAMP());

-- ============================================================================
-- SECTION 3: ENABLE ALL ALERTS
-- ============================================================================
-- Alerts must be in RESUME state to trigger automatically

ALTER ALERT ALT_RISK_SPIKE RESUME;
ALTER ALERT ALT_MISSING_DISTRICTS RESUME;
ALTER ALERT ALT_TASK_FAILURE RESUME;

-- ============================================================================
-- SECTION 4: AUDIT LOG TABLE
-- ============================================================================
-- Central table for logging all system alerts and audit events
-- Used by alerts for storing notification history

-- Table already exists from previous versions, verify structure here
DESCRIBE TABLE ANALYTICS.AUDIT_PREMIUM_CALCULATIONS;

-- Add index for alert queries
CREATE INDEX IF NOT EXISTS IDX_AUDIT_ALERT_TYPE
ON ANALYTICS.AUDIT_PREMIUM_CALCULATIONS(AUDIT_TYPE, CREATED_AT);

-- ============================================================================
-- SECTION 5: MONITORING DASHBOARD QUERIES
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
-- SECTION 6: VERIFICATION
-- ============================================================================

SELECT 'Monitoring and Alert Setup Complete' AS status;

-- View all created monitoring views
SHOW VIEWS IN SCHEMA ANALYTICS LIKE 'V_%';

-- View all alerts
SHOW ALERTS IN DATABASE INSURE_DB;

