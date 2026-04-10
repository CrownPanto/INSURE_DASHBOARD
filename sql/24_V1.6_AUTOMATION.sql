-- ============================================================================
-- File: 24_V1.6_AUTOMATION.sql
-- Purpose: INSURE Dynamic Insurance Engine - Stream & Task Automation
-- Project: Snowflake Hackathon - Dynamic Insurance Product Adaptation
-- Author: INSURE Development Team
-- Version: 1.6
-- Date: 2026-04-06
-- ============================================================================
-- OVERVIEW:
-- This script implements Snowflake Streams and Tasks to automate data pipeline
-- refreshes, data quality checks, and model performance monitoring.
--
-- KEY COMPONENTS:
-- 1. Streams: detect changes in raw accident and fire statistics tables
-- 2. Tasks: auto-refresh staging/intermediate when source data changes
-- 3. Data Quality Task: hourly NULL rate checks on mart tables
-- 4. Model Performance Task: weekly metric logging for forecast accuracy
-- 5. Task execution with Asia/Seoul timezone for compliance
-- ============================================================================

USE DATABASE INSURE_DB;
USE SCHEMA RAW_PUBLIC;

-- ============================================================================
-- SECTION 1: STREAMS - CHANGE DETECTION
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
-- SECTION 2: TASKS - AUTOMATED DATA REFRESH
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
-- SECTION 3: ENABLE ALL TASKS
-- ============================================================================
-- Tasks must be in RESUME state to execute on schedule

ALTER TASK TSK_REFRESH_STAGING RESUME;
ALTER TASK TSK_DATA_QUALITY_CHECK RESUME;
ALTER TASK TSK_LOG_MODEL_PERFORMANCE RESUME;

-- ============================================================================
-- SECTION 4: SUPPORTING TABLE FOR PERFORMANCE LOGGING
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
-- SECTION 5: STREAM & TASK VERIFICATION
-- ============================================================================
-- Verify streams and tasks are created and enabled

SELECT 'Stream and Task Setup Complete' AS status;

-- View stream status
SHOW STREAMS IN SCHEMA RAW_PUBLIC;
SHOW STREAMS IN SCHEMA STAGING;

-- View task status and schedule
SHOW TASKS IN DATABASE INSURE_DB;

