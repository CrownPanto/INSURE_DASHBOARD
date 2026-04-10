-- ============================================================================
-- File: 27_V1.6_STREAMLIT_DEPLOY.sql
-- Purpose: INSURE Dynamic Insurance Engine - Streamlit v2 Deployment
-- Version: 1.6 (updated with 3-tier transparency + 7-layer actuarial)
-- Date: 2026-04-07
-- ============================================================================
-- DEPLOYMENT GUIDE FOR STREAMLIT v2 APP
-- ============================================================================
-- This script provides guidance and infrastructure for deploying
-- streamlit_app_v2.py to Snowflake Streamlit.
--
-- The app includes:
--   Pages:
--     1. My Neighborhood Safety (내 동네 안전도)
--     2. My Insurance Premium (내 보험료)
--     3. Future Prediction (미래 예측)
--     4. AI Insurance Advisor (AI 보험 어드바이저)
--     5. System & Architecture (시스템 & 아키텍처)
--
--   Architecture:
--     - 3-Tier Data Transparency (Composite, Component, Granular)
--     - 7-Layer Actuarial Model (Risk x Demographics x External)
--     - Real-time Snowflake Snowpark integration
--     - 564 lines of Python with extensive Korean localization
-- ============================================================================

USE DATABASE INSURE_DB;
USE SCHEMA ANALYTICS;

-- ============================================================================
-- METHOD 1: RECOMMENDED - Upload via Snowflake UI
-- ============================================================================
-- STEPS:
--   1. Open Snowflake Web UI
--   2. Navigate to: INSURE_DB > Streamlit Apps
--   3. Click "Create Streamlit App"
--   4. Configuration:
--      - Name: INSURE_v2
--      - Warehouse: COMPUTE_WH
--      - App File: streamlit_app_v2.py (from local system)
--   5. Click Create and Deploy
--
-- ADVANTAGES:
--   - Handles Korean character encoding automatically (UTF-8)
--   - No manual escaping or encoding transformations required
--   - Preserves Unicode escape sequences correctly
--   - Better error reporting in Snowflake UI
--   - Direct integration with Snowflake Streamlit container
--   - Simple rollback and versioning capabilities
--
-- STATUS: This is the RECOMMENDED and PRIMARY approach for this deployment
--
-- ESTIMATED TIME: 2-3 minutes for deployment and initialization

-- ============================================================================
-- IMPORTANT: Korean Character Encoding
-- ============================================================================
-- The Python source file (streamlit_app_v2.py) contains:
--   - 25 Korean Seoul district names (Unicode escaped as \uXXXX)
--   - Korean UI labels and page titles ("\ub0b4 \ub3d9\ub124..." format)
--   - Risk grade labels: "고위험", "중위험", "저위험"
--   - Navigation labels: "남추기" (Recommend)
--   - Demo district profile data with authentic Korean district characteristics
--
-- ENCODING HISTORY:
--   - Previous attempts with WRITE_RAW_FILE encountered encoding issues
--   - The Snowflake UI upload method handles these automatically
--   - Direct file upload preserves encoding without transformation
--
-- RECOMMENDATION: Use UI upload method to avoid encoding complications
-- ============================================================================

-- ============================================================================
-- Setup: Create Streamlit Stage and Configuration Infrastructure
-- ============================================================================

-- Create a dedicated stage for Streamlit files and versioning
CREATE STAGE IF NOT EXISTS ANALYTICS.STREAMLIT_STAGE
  DIRECTORY = (ENABLE = true)
  COMMENT = 'Deployment stage for INSURE Streamlit apps with version history';

-- Create configuration tracking table
CREATE TABLE IF NOT EXISTS ANALYTICS.STREAMLIT_APP_CONFIG (
  APP_ID VARCHAR(100),
  APP_NAME VARCHAR(200),
  VERSION VARCHAR(50),
  STATUS VARCHAR(50),
  DEPLOYMENT_METHOD VARCHAR(50),
  WAREHOUSE_NAME VARCHAR(100),
  CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  DEPLOYED_BY VARCHAR(100),
  NOTES VARCHAR(1000),
  PRIMARY KEY (APP_ID, VERSION)
);

-- Create deployment log table for auditing
CREATE TABLE IF NOT EXISTS ANALYTICS.STREAMLIT_DEPLOYMENT_LOG (
  LOG_ID BIGINT AUTOINCREMENT PRIMARY KEY,
  APP_ID VARCHAR(100),
  APP_VERSION VARCHAR(50),
  ACTION VARCHAR(50),
  DEPLOYMENT_METHOD VARCHAR(50),
  TIMESTAMP TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  STATUS VARCHAR(50),
  ERROR_MESSAGE VARCHAR(1000),
  COMMENTS VARCHAR(500)
);

-- ============================================================================
-- Insert Configuration for v1.6 Deployment
-- ============================================================================

INSERT INTO ANALYTICS.STREAMLIT_APP_CONFIG
  (APP_ID, APP_NAME, VERSION, STATUS, DEPLOYMENT_METHOD, WAREHOUSE_NAME, NOTES)
VALUES
  ('INSURE_v2', 'INSURE Dynamic Insurance Engine', '1.6', 'pending_deployment', 'UI_upload_recommended', 'COMPUTE_WH',
   'Status: Pending UI deployment. File: streamlit_app_v2.py (564 lines). Features: 3-tier transparency, 7-layer actuarial model, 5-page navigation. Contains 25 Korean Seoul districts with demo data profiles. Recommended: Use Snowflake UI for deployment to preserve Korean character encoding.');

-- Log the deployment configuration
INSERT INTO ANALYTICS.STREAMLIT_DEPLOYMENT_LOG
  (APP_ID, APP_VERSION, ACTION, DEPLOYMENT_METHOD, STATUS, COMMENTS)
VALUES
  ('INSURE_v2', '1.6', 'configure', 'UI_upload_recommended', 'prepared', 'Deployment infrastructure prepared. Ready for UI-based file upload.');

-- ============================================================================
-- METHOD 2 (ALTERNATIVE): SQL-based Deployment via PUT Command
-- ============================================================================
-- NOTE: This approach is provided for automated/CI-CD scenarios.
-- Given Korean character encoding concerns, the UI method is preferred.
--
-- MANUAL STEPS (using SnowSQL or Snowflake CLI):
--
--   1. From your local terminal, upload the file:
--      SnowSQL or Snowflake CLI:
--      $ snowsql -c myconnection -f /path/to/streamlit_app_v2.py
--
--      Or using PUT command in Snowflake:
--      PUT file:///path/to/streamlit_app_v2.py
--        @INSURE_DB.ANALYTICS.STREAMLIT_STAGE/
--        AUTO_COMPRESS = false
--        OVERWRITE = true;
--
--   2. After successful PUT, execute the CREATE STREAMLIT statement below
--      (currently commented out for safety)
--
-- ============================================================================

-- Step 1: Verify stage exists and list current contents
SELECT RELATIVE_PATH, FILE_SIZE, LAST_MODIFIED
FROM DIRECTORY('@ANALYTICS.STREAMLIT_STAGE')
ORDER BY LAST_MODIFIED DESC
LIMIT 10;

-- Step 2: Create Streamlit app from staged file (uncomment after successful PUT)
/*
CREATE OR REPLACE STREAMLIT ANALYTICS.INSURE_V2
  FROM '@ANALYTICS.STREAMLIT_STAGE'
  MAIN_FILE = 'streamlit_app_v2.py'
  QUERY_WAREHOUSE = 'COMPUTE_WH'
  COMMENT = 'INSURE Dynamic Insurance Engine v1.6 - 3-tier transparency + 7-layer actuarial model. Features: 5-page navigation with Korean UI, 25 Seoul districts, real-time risk analytics.';

-- Log successful deployment
INSERT INTO ANALYTICS.STREAMLIT_DEPLOYMENT_LOG
  (APP_ID, APP_VERSION, ACTION, DEPLOYMENT_METHOD, STATUS)
VALUES
  ('INSURE_v2', '1.6', 'deploy', 'SQL_PUT', 'success');
*/

-- ============================================================================
-- Data Source Verification
-- ============================================================================
-- The Streamlit app expects these tables to exist. Verify before deployment:

SELECT 'MART_DISTRICT_INSURANCE_SUMMARY' AS table_name, COUNT(*) AS row_count
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
UNION ALL
SELECT 'MART_RISK_COMPONENTS', COUNT(*)
FROM INSURE_DB.MART.MART_RISK_COMPONENTS;

-- ============================================================================
-- Expected Data Tables (required by the Streamlit app)
-- ============================================================================
-- Table 1: INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
--   Columns: GU_NAME, TOTAL_POPULATION, COMPOSITE_RISK_SCORE, RISK_GRADE,
--            AVG_BASE_PREMIUM, ADJUSTED_PREMIUM_MONTHLY, ESTIMATED_ANNUAL_MARKET_KRW,
--            FIRE_RISK_SCORE, THEFT_RISK_SCORE, BUILDING_RISK_SCORE,
--            WEATHER_RISK_SCORE, YEAR_MONTH
--
-- Table 2: INSURE_DB.MART.MART_RISK_COMPONENTS
--   Columns: DISTRICT_NAME, FIRE_RISK_SCORE, THEFT_RISK_SCORE,
--            BUILDING_RISK_SCORE, WEATHER_RISK_SCORE, SAFETY_INFRA_SCORE,
--            CCTV_SECURITY_SCORE, COMPOSITE_RISK_SCORE, RISK_GRADE
--
-- NOTE: If tables don't exist, the app falls back to demo data embedded
--       in the Python code with realistic Seoul district risk profiles.

-- ============================================================================
-- App Features Summary (from streamlit_app_v2.py)
-- ============================================================================
-- Page 1: My Neighborhood Safety (내 동네 안전도)
--   - District selection dropdown
--   - Composite risk score visualization
--   - Risk grade indicator (고위험/중위험/저위험)
--   - Comparison to Seoul average
--   - Component risk breakdown (fire, theft, building, weather)
--
-- Page 2: My Insurance Premium (내 보험료)
--   - Base premium calculation
--   - Risk-adjusted premium display
--   - Estimated annual market value
--   - Multi-period comparison
--
-- Page 3: Future Prediction (미래 예측)
--   - Forecasted risk trends
--   - Premium projection
--   - Market size estimation
--
-- Page 4: AI Insurance Advisor (AI 보험 어드바이저)
--   - Personalized recommendations
--   - Risk mitigation strategies
--   - Coverage suggestions based on district profile
--
-- Page 5: System & Architecture (시스템 & 아키텍처)
--   - 3-Tier transparency explanation
--   - 7-Layer actuarial model documentation
--   - Data flow and integration architecture
--   - Snowflake integration details

-- ============================================================================
-- Quick Health Check (Post-Deployment)
-- ============================================================================
-- Run this query after deployment to verify Streamlit app is accessible:

/*
SELECT
  object_id,
  object_name,
  object_type,
  query_warehouse,
  created_on,
  owner
FROM INFORMATION_SCHEMA.STREAMLIT_OBJECTS
WHERE database_name = 'INSURE_DB'
  AND schema_name = 'ANALYTICS'
  AND object_name = 'INSURE_V2';
*/

-- ============================================================================
-- Troubleshooting Guide
-- ============================================================================
-- Issue: App not appearing in UI
--   Solution: Verify COMPUTE_WH exists and has sufficient resources
--
-- Issue: Korean characters display incorrectly
--   Solution: Ensure using UI upload method (recommended)
--            If using SQL PUT, verify character set is UTF-8
--
-- Issue: Data tables not found
--   Solution: Check MART tables exist in INSURE_DB.MART schema
--            App includes fallback demo data for testing
--
-- Issue: Snowpark session fails to initialize
--   Solution: Verify warehouse is active and user has USE_WAREHOUSE grant
--            Check Snowflake version supports Snowpark for Streamlit

-- ============================================================================
-- Rollback Instructions
-- ============================================================================
-- To remove the deployed app:
/*
DROP STREAMLIT IF EXISTS INSURE_DB.ANALYTICS.INSURE_V2;

-- Log the rollback
INSERT INTO ANALYTICS.STREAMLIT_DEPLOYMENT_LOG
  (APP_ID, APP_VERSION, ACTION, STATUS)
VALUES
  ('INSURE_v2', '1.6', 'rollback', 'success');
*/

-- ============================================================================
-- Version History
-- ============================================================================
-- v1.6 (2026-04-07)
--   - Added 3-tier data transparency framework
--   - Implemented 7-layer actuarial model
--   - Enhanced Korean UI localization
--   - Demo district profiles with authentic Seoul data
--   - 564 lines of production-ready Python
--
-- v1.5 (2026-04-06)
--   - Snowpark integration improvements
--   - Cortex Analyst agent integration
--   - Enhanced data models
--
-- v1.4 (2026-04-06)
--   - Actuarial premium calculation
--   - Feedback redesign
--   - Streamlit initial deployment
--
-- v1.3 and earlier
--   - Core functionality and data layers

-- ============================================================================
-- End of Deployment Script
-- ============================================================================
-- Next Steps:
--   1. Review this script and verify all prerequisites are met
--   2. Use Snowflake UI to upload streamlit_app_v2.py
--   3. Navigate to: INSURE_DB > Streamlit Apps > INSURE_v2
--   4. Verify all 5 pages load correctly
--   5. Test with demo data first, then verify with actual database tables
-- ============================================================================
