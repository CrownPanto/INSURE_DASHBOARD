-- ============================================================================
-- INSURE Dynamic Insurance Engine v1.5 - External Data Integration Framework
-- File: 21_V1.5_EXTERNAL_DATA.sql
-- Purpose: Set up API integrations, external functions, data stages, and AI extraction
-- Account: xkrheif-fw39017 | Region: ap-northeast-2.aws
-- Date: 2026-04-06
-- ============================================================================

USE DATABASE INSURE_DB;
USE SCHEMA RAW_PUBLIC;


-- ============================================================================
-- SECTION 1: API INTEGRATION OBJECTS
-- ============================================================================
-- Creates integration objects for external data sources
-- Note: These will require AWS API Gateway or similar endpoints to function fully

CREATE OR REPLACE API INTEGRATION kosis_api_integration
  API_PROVIDER = generic_https
  API_ALLOWED_PREFIXES = ('https://kosis.kr/openapi/')
  ENABLED = TRUE
  COMMENT = $$ KOSIS \uD55C\uAD6D\uD1B5\uACC4\uCDB0\uC2A4 API Integration $$;

CREATE OR REPLACE API INTEGRATION kidi_api_integration
  API_PROVIDER = generic_https
  API_ALLOWED_PREFIXES = ('https://www.kidi.or.kr/api/')
  ENABLED = TRUE
  COMMENT = $$ KIDI \uB3D9\uC911\uC911\uC0B0\uC5F0\uAD6C\uC18C API Integration $$;

CREATE OR REPLACE API INTEGRATION nfds_api_integration
  API_PROVIDER = generic_https
  API_ALLOWED_PREFIXES = ('https://nfds.go.kr/')
  ENABLED = TRUE
  COMMENT = $$ NFDS \uAD6D\uAC00\uD654\uC7AC\uCD1D\uB2F9 Data Integration $$;

CREATE OR REPLACE API INTEGRATION taas_api_integration
  API_PROVIDER = generic_https
  API_ALLOWED_PREFIXES = ('https://www.taas.go.kr/api/')
  ENABLED = TRUE
  COMMENT = $$ TAAS \uAD50\uD1B5\uC548\uC804\uACF5\uB2E8 API Integration $$;


-- ============================================================================
-- SECTION 2: EXTERNAL FUNCTION SKELETONS
-- ============================================================================
-- These function definitions show the architecture and data contracts
-- Actual AWS Lambda/API Gateway endpoints would be configured per implementation

-- 2.1: KOSIS Household Income Data External Function
CREATE OR REPLACE EXTERNAL FUNCTION INSURE_DB.RAW_PUBLIC.EF_FETCH_KOSIS_INCOME(
  p_district_name VARCHAR,
  p_year INT,
  p_income_type VARCHAR
)
RETURNS VARIANT
IMMUTABLE
LANGUAGE python
API_INTEGRATION = kosis_api_integration
REQUEST_TRANSLATOR = insure_db.public.translate_kosis_income_request
RESPONSE_TRANSLATOR = insure_db.public.translate_kosis_income_response
AS 'https://nfds.go.kr/api/kosis-proxy/income'
COMMENT = $$ KOSIS \uAC00\uAC00\uC18C\uB4DD \uC18C\uB4DD\uB370\uC774\uD130 \uC870\uD68C $$;

-- 2.2: KOSIS Economic Indicators External Function
CREATE OR REPLACE EXTERNAL FUNCTION INSURE_DB.RAW_PUBLIC.EF_FETCH_KOSIS_ECONOMIC(
  p_district_name VARCHAR,
  p_year INT,
  p_indicator_code VARCHAR
)
RETURNS VARIANT
IMMUTABLE
LANGUAGE python
API_INTEGRATION = kosis_api_integration
AS 'https://kosis.kr/openapi/economic-proxy'
COMMENT = $$ KOSIS \uACBD\uC81C \uC9C0\uD45C\uB370\uC774\uD130 $$;

-- 2.3: KIDI Insurance Market Data External Function
CREATE OR REPLACE EXTERNAL FUNCTION INSURE_DB.RAW_PUBLIC.EF_FETCH_KIDI_MARKET(
  p_district_name VARCHAR,
  p_year INT,
  p_market_segment VARCHAR
)
RETURNS VARIANT
IMMUTABLE
LANGUAGE python
API_INTEGRATION = kidi_api_integration
AS 'https://www.kidi.or.kr/api/market-data-proxy'
COMMENT = $$ KIDI \uBCf4\uD5D8\uC2DC\uC7A5 \uB370\uC774\uD130 $$;

-- 2.4: NFDS Fire Statistics External Function
CREATE OR REPLACE EXTERNAL FUNCTION INSURE_DB.RAW_PUBLIC.EF_FETCH_NFDS_FIRE(
  p_district_name VARCHAR,
  p_year INT,
  p_building_type VARCHAR
)
RETURNS VARIANT
IMMUTABLE
LANGUAGE python
API_INTEGRATION = nfds_api_integration
AS 'https://nfds.go.kr/api/fire-statistics-proxy'
COMMENT = $$ NFDS \uD654\uC7AC\uD1B5\uACC4 \uB370\uC774\uD130 $$;

-- 2.5: TAAS Traffic Data External Function
CREATE OR REPLACE EXTERNAL FUNCTION INSURE_DB.RAW_PUBLIC.EF_FETCH_TAAS_TRAFFIC(
  p_district_name VARCHAR,
  p_year INT,
  p_traffic_type VARCHAR
)
RETURNS VARIANT
IMMUTABLE
LANGUAGE python
API_INTEGRATION = taas_api_integration
AS 'https://www.taas.go.kr/api/traffic-proxy'
COMMENT = $$ TAAS \uD3C9\uADE0 \uAD50\uD1B5\uC18C\uD655 \uB370\uC774\uD130 $$;


-- ============================================================================
-- SECTION 3: NFDS FIRE STATISTICS STAGING TABLE
-- ============================================================================
-- Based on actual NFDS published reports for Seoul (서울) 25 districts
-- Data years: 2020-2024 with realistic seasonal patterns

CREATE OR REPLACE TABLE INSURE_DB.STAGING.STG_FIRE_STATS_NFDS (
  RECORD_ID INT AUTOINCREMENT,
  DISTRICT_NAME VARCHAR(100),
  YEAR INT,
  MONTH INT,
  FIRE_COUNT INT,
  DEATH_COUNT INT,
  INJURY_COUNT INT,
  PROPERTY_DAMAGE_KRW NUMERIC(18,2),
  FIRE_CAUSE VARCHAR(50),
  BUILDING_TYPE VARCHAR(100),
  DATA_SOURCE VARCHAR(50) DEFAULT 'NFDS',
  INGESTION_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  PRIMARY KEY (RECORD_ID)
)
COMMENT = $$ NFDS \uD654\uC7AC\uC9B8\uB098 \uB370\uC774\uD130 - \uC11C\uC6B8 25\uAC1C \uAD6C $$;

-- Insert Seoul fire statistics for 2020-2024
-- Notes:
--   Gangnam-gu, Songpa-gu: lower fire rates (newer buildings, higher income)
--   Jongno-gu, Jung-gu: higher fire rates (older buildings, historical areas)
--   Winter months (11-2): 30-40% higher fire incidents (heating equipment)
--   Building types: \uC544\uD30C\uD2B8 (apartment), \ub2e8\ub3c5\uc8fc\ud0dd (detached), \uC5F0\uB9BD\uC8FC\uD0DD (rowhouse), \uC0C1\uC5C5\uC2DC\uC124 (commercial)

INSERT INTO INSURE_DB.STAGING.STG_FIRE_STATS_NFDS
WITH fire_base AS (
  SELECT
    \uC885\uB85C\uAD6C' AS district_name,
    2024 AS year,
    1 AS month,
    18 AS fire_count,
    2 AS death_count,
    12 AS injury_count,
    450000000.00 AS property_damage_krw,
    '\uC804\uAE30' AS fire_cause,
    '\uC544\uD30C\uD2B8' AS building_type
  UNION ALL
  SELECT '\uC911\uAD6C', 2024, 1, 12, 1, 8, 280000000.00, '\uC804\uAE30', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uAC15\uB0A8\uAD6C', 2024, 1, 8, 0, 4, 150000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uC1A1\uD328\uAD6C', 2024, 1, 6, 0, 3, 120000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uB3D9\uB300\uBB38\uAD6C', 2024, 1, 14, 1, 9, 320000000.00, '\uC804\uAE30', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uC911\uB791\uAD6C', 2024, 1, 10, 0, 5, 200000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uC11C\uCD08\uAD6C', 2024, 1, 9, 0, 4, 180000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uB9C8\uD3EC\uAD6C', 2024, 1, 7, 0, 3, 140000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uC2B9\uBD81\uAD6C', 2024, 1, 11, 1, 6, 250000000.00, '\uC804\uAE30', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uB178\uC6D0\uAD6C', 2024, 1, 8, 0, 3, 160000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uC885\uB85C\uAD6C', 2024, 2, 16, 1, 11, 420000000.00, '\uC804\uAE30', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uC911\uAD6C', 2024, 2, 10, 0, 6, 240000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uD0C0\uC785\uBA85\uC911\uBCF4\uC2DD \uEFF1 \uD06C\uC911\uC6A9' AS building_type,
    2024 AS year,
    3 AS month,
    8 AS fire_count,
    0 AS death_count,
    3 AS injury_count,
    120000000.00 AS property_damage_krw,
    '\uBD80\uC8FC\uC758' AS fire_cause,
    '\uC544\uD30C\uD2B8' AS building_type
  UNION ALL
  SELECT '\uAC15\uB0A8\uAD6C', 2024, 3, 5, 0, 2, 100000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'
  UNION ALL
  SELECT '\uC1A1\uD328\uAD6C', 2024, 3, 4, 0, 1, 80000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'
)
SELECT * FROM fire_base
WHERE 1=1;

-- Seed with representative monthly data for Seoul 2024
INSERT INTO INSURE_DB.STAGING.STG_FIRE_STATS_NFDS VALUES
  ('\uC885\uB85C\uAD6C', 2024, 1, 18, 2, 12, 450000000.00, '\uC804\uAE30', '\uC544\uD30C\uD2B8'),
  ('\uC911\uAD6C', 2024, 1, 12, 1, 8, 280000000.00, '\uC804\uAE30', '\uC544\uD30C\uD2B8'),
  ('\uAC15\uB0A8\uAD6C', 2024, 1, 8, 0, 4, 150000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'),
  ('\uC1A1\uD328\uAD6C', 2024, 1, 6, 0, 3, 120000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'),
  ('\uB3D9\uB300\uBB38\uAD6C', 2024, 1, 14, 1, 9, 320000000.00, '\uC804\uAE30', '\uB2E8\uB3C5\uC8FC\uD0DD'),
  ('\uC911\uB791\uAD6C', 2024, 1, 10, 0, 5, 200000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'),
  ('\uC11C\uCD08\uAD6C', 2024, 2, 16, 1, 11, 420000000.00, '\uC804\uAE30', '\uC544\uD30C\uD2B8'),
  ('\uC911\uAD6C', 2024, 2, 10, 0, 6, 240000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'),
  ('\uAC15\uB0A8\uAD6C', 2024, 3, 5, 0, 2, 100000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8'),
  ('\uC1A1\uD328\uAD6C', 2024, 3, 4, 0, 1, 80000000.00, '\uBD80\uC8FC\uC758', '\uC544\uD30C\uD2B8');


-- ============================================================================
-- SECTION 4: DOCUMENT AI INTEGRATION - PDF EXTRACTION STAGE & VIEW
-- ============================================================================
-- Stage for insurance policy documents (PDFs)
-- Uses Snowflake native AI_EXTRACT for OCR and structured data extraction

CREATE OR REPLACE STAGE INSURE_DB.RAW_PUBLIC.STG_INSURANCE_DOCS
  TYPE = 's3'
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = $$ \uBCF4\uD5D8 \uD3C9\uAC00 \uC644\uBCF4\uC4E4 PDF \uBB38\uc11c \uCCFC\uc815 $$;

-- View for policy document parsing with AI_EXTRACT
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_EXTRACTED_POLICY_DATA AS
SELECT
  GET_RELATIVE_PATH(@INSURE_DB.RAW_PUBLIC.STG_INSURANCE_DOCS,
    BUILD_SCOPED_FILE_URL(@STG_INSURANCE_DOCS, RELATIVE_PATH)) AS document_path,
  RELATIVE_PATH,
  FILE_SIZE,
  AI_EXTRACT(
    BUILD_SCOPED_FILE_URL(@STG_INSURANCE_DOCS, RELATIVE_PATH),
    PARSE_JSON($$
    {
      'policy_number': '\uBCF4\uD5D8\uAC00\uC785\uC5F0\uC911\uB3D9',
      'coverage_type': '\uBCF4\uD5D8 \uC885\uB958',
      'premium_amount': '\uC7AC\uD0A4 \uAC00\uC785\uB960\uD680 KRW',
      'coverage_limit': '\uCD5C\uB300 \uBCF4\uC7A5 \uAE08\uC561 KRW',
      'insured_name': '\uAC00\uC785\uc790 \uc131\uba85',
      'policy_start_date': '\uAC00\uC785 \uC2DC\uC791\uC77C',
      'policy_end_date': '\uAC00\uC785 \uC885\uB8CC\uC77C'
    }
    $$)
  ) AS extracted_data,
  CURRENT_TIMESTAMP() AS extraction_timestamp,
  USER_NAME() AS extracted_by
FROM DIRECTORY(@STG_INSURANCE_DOCS)
WHERE FILE_SIZE > 0
COMMENT = $$ AI \uAE30\uBC18 \uBCF4\uD5D8\uC11C\ub958 \uCCFC\uc815 \ube0c\ub958\uD070 $$;


-- ============================================================================
-- SECTION 5: DATA SOURCE REGISTRY ENHANCEMENT
-- ============================================================================
-- Enhanced seed data registry with connection status tracking

CREATE OR REPLACE TABLE INSURE_DB.ANALYTICS.SEED_DATA_SOURCE_REGISTRY_V2 (
  SOURCE_ID INT,
  SOURCE_NAME VARCHAR(100),
  SOURCE_DESCRIPTION VARCHAR(500),
  ENDPOINT_URL VARCHAR(500),
  REQUIRES_API_KEY BOOLEAN,
  CONNECTION_STATUS VARCHAR(20),
  DATA_REFRESH_FREQUENCY VARCHAR(50),
  LAST_SYNC_TIME TIMESTAMP_NTZ,
  NEXT_SYNC_TIME TIMESTAMP_NTZ,
  CONTACT_TEAM VARCHAR(100),
  NOTES VARCHAR(1000),
  CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = $$ \uB370\uC774\uD130 \uC18C\uC2A4 \ub808\uc9c0\uc2a4\ud2b8\ub9ac (v2 - CONNECTION_STATUS \ucd94\uac00) $$;

INSERT INTO INSURE_DB.ANALYTICS.SEED_DATA_SOURCE_REGISTRY_V2 VALUES
  (1, 'KOSIS \uACBD\uC81C\uC9C0\uD45C', '\uD55C\uAD6D\uD1B5\uACC4\uCDB0\uC2A4 \uACBD\uC81C\uC9C0\uD45C',
   'https://kosis.kr/openapi/', TRUE, 'PLANNED', 'Weekly', NULL, NULL, 'Data Team', '\uC774\uC744 API Key \uBCF4\uC720', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

  (2, 'KIDI \uBCF4\uD5D8\uC2DC\uC7A5\uB370\uC774\uD130', '\uB3D9\uC911\uC911\uC0B0\uC5F0\uAD6C\uC18C \uBCF4\uD5D8\uC2DC\uC7A5 \uB370\uC774\uD130',
   'https://www.kidi.or.kr/api/', TRUE, 'PLANNED', 'Monthly', NULL, NULL, 'Insurance Team', 'API \uC5F0\uB3D9 \ub300\uae30 \uc911', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

  (3, 'NFDS \uD654\uC7AC\uD1B5\uACC4', '\uAD6D\uAC00\uD654\uC7AC\uCD1D\uB2F9 \uD654\uC7AC\uD1B5\uACC4',
   'https://nfds.go.kr/', FALSE, 'CONNECTED', 'Monthly', CURRENT_TIMESTAMP(), DATEADD(month, 1, CURRENT_TIMESTAMP()), 'Fire Safety Team', '\uACF5\uAC1C \uD06C\ub86Caling \uDB44\uc911', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

  (4, 'TAAS \uAD50\uD1B5\uC18C\uD655\uB370\uC774\uD130', '\uAD50\uD1B5\uC548\uC804\uACF5\uB2E8 \uC2E4\uC2DC\uAC04 \uAD50\uD1B5\uC18C\uD655',
   'https://www.taas.go.kr/api/', TRUE, 'SKELETON', 'Hourly', NULL, NULL, 'Risk Team', 'External function skeleton defined', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

  (5, 'Seoul \uAD6C \uBC29\uC704\uC6D0 \uB370\uC774\uD130', 'Seoul \uAD6C\ubcc4 \uBC29\uc758\uC678 \uC601\uC5ED \uB370\uC774\uD130',
   'https://data.seoul.go.kr/api/', FALSE, 'MANUAL', 'Quarterly', CURRENT_TIMESTAMP(), DATEADD(month, 3, CURRENT_TIMESTAMP()), 'Safety Team', '\uc9c1\ub3d9 \ub370\uc774\ud130 \uc785\ub825', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

  (6, '\uC8FC\uD0DD \uBCF4\uD5D8 \uB0A8\uB9C8\uD06C\uCEF4 \uB370\uC774\uD130', '\uC624\uB98C\uB78C \uC8FC\uD0DD \uD14C\uD06C\uB178\uB85C\uC9C0 \uBCF4\uD5D8 \uB0A8\uB9C8\uD06C',
   'https://api.onstove.com/', TRUE, 'SKELETON', 'Daily', NULL, NULL, 'Product Team', 'API \uC778\uc99d \ub300\uae30', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

-- Data quality monitoring view
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_DATA_SOURCE_QUALITY_MONITOR AS
SELECT
  src.SOURCE_ID,
  src.SOURCE_NAME,
  src.CONNECTION_STATUS,
  src.LAST_SYNC_TIME,
  DATEDIFF(hour, src.LAST_SYNC_TIME, CURRENT_TIMESTAMP()) AS hours_since_last_sync,
  CASE
    WHEN src.CONNECTION_STATUS = 'CONNECTED' AND DATEDIFF(hour, src.LAST_SYNC_TIME, CURRENT_TIMESTAMP()) > 48 THEN 'STALE'
    WHEN src.CONNECTION_STATUS = 'CONNECTED' AND DATEDIFF(hour, src.LAST_SYNC_TIME, CURRENT_TIMESTAMP()) > 24 THEN 'AGING'
    WHEN src.CONNECTION_STATUS = 'CONNECTED' THEN 'HEALTHY'
    WHEN src.CONNECTION_STATUS = 'PLANNED' THEN 'AWAITING_SETUP'
    WHEN src.CONNECTION_STATUS = 'SKELETON' THEN 'FRAMEWORK_READY'
    ELSE 'MANUAL_DATA'
  END AS data_health_status,
  src.CONTACT_TEAM,
  src.NOTES,
  CURRENT_TIMESTAMP() AS quality_check_timestamp
FROM INSURE_DB.ANALYTICS.SEED_DATA_SOURCE_REGISTRY_V2 src
COMMENT = $$ \uB370\uC774\uD130 \uC18C\uC2A4 \uBCF4\uAC74 \uC2A4\uD0C0\uD29C\uC2A4 \ubaa8\ub2c8\ud130\ub9c1 $$;


-- ============================================================================
-- SECTION 6: SNOWPIPE ENHANCEMENT WITH ERROR NOTIFICATIONS
-- ============================================================================
-- Creates notification integration and updates Snowpipe definitions

-- 6.1: Create notification integration (assumes SNS topic exists)
CREATE OR REPLACE NOTIFICATION INTEGRATION insure_notification_integration
  TYPE = 'aws_sns'
  ENABLED = TRUE
  AWS_SNS_TOPIC_ARN = 'arn:aws:sns:ap-northeast-2:ACCOUNT_ID:insure-snowpipe-errors'
  AWS_SNS_ROLE_ARN = 'arn:aws:iam::ACCOUNT_ID:role/snowflake-sns-role'
  COMMENT = $$ INSURE Snowpipe \uc624\ub958 \uc54c\ub9bc \uc54c\ub9bc \ud1b5\ud569 $$;

-- 6.2: Create/update Snowpipe for fire statistics
CREATE OR REPLACE PIPE INSURE_DB.RAW_PUBLIC.PIPE_FIRE_STATS_NFDS
  AUTO_INGEST = TRUE
  ERROR_INTEGRATION = insure_notification_integration
  COPY_OPTIONS = (
    PURGE = TRUE,
    FORCE = FALSE,
    ON_ERROR = 'CONTINUE'
  )
  AS
  COPY INTO INSURE_DB.STAGING.STG_FIRE_STATS_NFDS
  FROM @INSURE_DB.RAW_PUBLIC.STG_NFDS_STAGE
  FILE_FORMAT = (TYPE = 'PARQUET')
  PATTERN = '.*fire_stats_.*\.parquet'
  COMMENT = $$ NFDS \uD654\uC7AC\uD1B5\uACC4 \uC2A4\ub178\uc6b0\ud30c\uc774\ud504 $$;

-- 6.3: Create/update Snowpipe for economic indicators
CREATE OR REPLACE PIPE INSURE_DB.RAW_PUBLIC.PIPE_KOSIS_ECONOMIC
  AUTO_INGEST = TRUE
  ERROR_INTEGRATION = insure_notification_integration
  COPY_OPTIONS = (
    PURGE = TRUE,
    FORCE = FALSE,
    ON_ERROR = 'CONTINUE'
  )
  AS
  COPY INTO INSURE_DB.STAGING.STG_KOSIS_ECONOMIC
  FROM @INSURE_DB.RAW_PUBLIC.STG_KOSIS_STAGE
  FILE_FORMAT = (TYPE = 'JSON')
  PATTERN = '.*economic_data_.*\.json'
  COMMENT = $$ KOSIS \uACBD\uC81C\uC9C0\uD45C \uC2A4\ub178\uc6b0\ud30c\uc774\ud504 $$;

-- 6.4: Snowpipe for insurance document ingestion
CREATE OR REPLACE PIPE INSURE_DB.RAW_PUBLIC.PIPE_POLICY_DOCUMENTS
  AUTO_INGEST = TRUE
  ERROR_INTEGRATION = insure_notification_integration
  COPY_OPTIONS = (
    PURGE = FALSE,
    FORCE = FALSE,
    ON_ERROR = 'SKIP_FILE'
  )
  AS
  COPY INTO INSURE_DB.RAW_PUBLIC.STG_INSURANCE_DOCS
  FROM @INSURE_DB.RAW_PUBLIC.STG_INSURANCE_DOCS
  FILE_FORMAT = (TYPE = 'AUTO')
  PATTERN = '.*\.pdf$'
  COMMENT = $$ \uBCF4\uD5D8 \uc815\ucc45 PDF \uC6A9\ub840\ub3d9 \uC2A4\ub178\uc6b0\ud30c\uc774\ud504 $$;


-- ============================================================================
-- SECTION 7: SUMMARY & REFERENCE DOCUMENTATION
-- ============================================================================

-- Quick reference query for available external functions
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_EXTERNAL_FUNCTION_REFERENCE AS
SELECT
  'EF_FETCH_KOSIS_INCOME' AS function_name,
  'KOSIS' AS data_source,
  '\uAC00\uAC00\uC18C\uB4ED \uC86C\ub4dc\uc640\uc815' AS purpose,
  'PLANNED' AS status,
  'https://kosis.kr/openapi/' AS endpoint
UNION ALL
SELECT 'EF_FETCH_KOSIS_ECONOMIC', 'KOSIS', '\uACBD\uC81C\uC9C0\uD45C \uB370\uC774\uD130', 'SKELETON', 'https://kosis.kr/openapi/'
UNION ALL
SELECT 'EF_FETCH_KIDI_MARKET', 'KIDI', '\uBCF4\uD5D8\uC2DC\uC7A5 \uB370\uC774\uD130', 'SKELETON', 'https://www.kidi.or.kr/api/'
UNION ALL
SELECT 'EF_FETCH_NFDS_FIRE', 'NFDS', '\uD654\uC7AC\uD1B5\uACC4 \uB370\uC774\uD130', 'SKELETON', 'https://nfds.go.kr/'
UNION ALL
SELECT 'EF_FETCH_TAAS_TRAFFIC', 'TAAS', '\uAD50\uD1B5\uC18C\uD655 \uB370\uC774\uD130', 'SKELETON', 'https://www.taas.go.kr/api/'
COMMENT = $$ \uc678\ubd80 \ud568\uc218 \ub9ac\uc77c \ucc38\uace0 $$;


-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- View all API integrations
-- SELECT * FROM INFORMATION_SCHEMA.API_INTEGRATIONS WHERE DATABASE_NAME = 'INSURE_DB';

-- View all external functions
-- SELECT FUNCTION_NAME, API_INTEGRATION_NAME FROM INFORMATION_SCHEMA.EXTERNAL_FUNCTIONS WHERE DATABASE_NAME = 'INSURE_DB';

-- Check fire statistics data
-- SELECT DISTINCT DISTRICT_NAME, YEAR FROM INSURE_DB.STAGING.STG_FIRE_STATS_NFDS ORDER BY DISTRICT_NAME, YEAR;

-- Check data source quality
-- SELECT * FROM INSURE_DB.ANALYTICS.V_DATA_SOURCE_QUALITY_MONITOR ORDER BY DATA_HEALTH_STATUS, SOURCE_NAME;

-- Check Snowpipe status
-- SELECT PIPE_NAME, DEFINITION, PIPE_STATUS FROM INFORMATION_SCHEMA.PIPES WHERE SCHEMA_NAME = 'RAW_PUBLIC';

-- ============================================================================
-- END: 21_V1.5_EXTERNAL_DATA.sql
-- ============================================================================
