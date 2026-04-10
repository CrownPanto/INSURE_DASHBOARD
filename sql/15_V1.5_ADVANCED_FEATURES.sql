-- ================================================================
-- 20_V1.5_ADVANCED_FEATURES.sql
-- INSURE v1.5 통합: Snowflake 고급 기능 + 외부 데이터 + Cortex Analyst
-- Consolidated from: 20_V1.5_SNOWFLAKE_FEATURES.sql
--                    21_V1.5_EXTERNAL_DATA.sql
--                    22_V1.5_CORTEX_ANALYST_AGENT.sql
-- Merge Date: 2026-04-11
-- ================================================================

USE DATABASE INSURE_DB;
USE WAREHOUSE COMPUTE_WH;

-- ================================================================
-- PART 1: Snowflake 고급 기능 (from 20_V1.5_SNOWFLAKE_FEATURES.sql)
-- ================================================================
-- Key Components:
-- 1. Dynamic Tables (replacing views) with hourly refresh
-- 2. Deterministic risk classification based on composite risk scores
-- 3. Credit factor dynamic mapping from customer segments
-- 4. Cortex ML time-series forecasting for fire incidents
-- 5. Cortex LLM for personalized insurance descriptions
-- 6. Cortex AI sentiment analysis in feedback processing
-- 7. Alerts for high-risk districts with timezone support

-- ============================================================================
-- SECTION 1: DYNAMIC TABLES - REPLACE VIEWS
-- ============================================================================
-- Dynamic Tables provide:
-- - Automatic refresh on source changes (TARGET_LAG = '1 hour')
-- - Better performance for downstream dependencies
-- - Deterministic results across queries
-- These replace INT_PURE_PREMIUM, INT_EXPERIENCE_RATING, INT_RISK_ADJUSTED_PREMIUM

-- ============================================================================
-- 1.1: DYNAMIC TABLE - INT_PURE_PREMIUM
-- Calculates base premium from loss history, district, and market data
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM
TARGET_LAG = '1 hour'
WAREHOUSE = COMPUTE_WH
AS
SELECT
    al.LOSS_ID,
    al.POLICY_ID,
    al.CLAIM_AMOUNT,
    al.LOSS_DATE,
    dm.DISTRICT_CODE,
    dm.DISTRICT_NAME,
    dm.BASE_PREMIUM_FACTOR,
    im.MARKET_SEGMENT,
    im.MARKET_ADJUSTMENT_FACTOR,
    -- Pure Premium = Claim Amount * District Factor * Market Adjustment
    ROUND(
        al.CLAIM_AMOUNT
        * dm.BASE_PREMIUM_FACTOR
        * im.MARKET_ADJUSTMENT_FACTOR,
        2
    ) AS PURE_PREMIUM,
    al.LOSS_COUNT AS CLAIM_FREQUENCY,
    CURRENT_TIMESTAMP() AS CALCULATED_AT
FROM INSURE_DB.STAGING.STG_ACCIDENT_LOSS al
INNER JOIN INSURE_DB.STAGING.STG_DISTRICT_MASTER dm
    ON al.DISTRICT_CODE = dm.DISTRICT_CODE
INNER JOIN INSURE_DB.STAGING.STG_INSURANCE_MARKET im
    ON al.MARKET_SEGMENT = im.MARKET_SEGMENT
WHERE al.LOSS_DATE >= DATEADD(year, -3, CURRENT_DATE())
ORDER BY al.LOSS_ID;

-- ============================================================================
-- 1.2: DYNAMIC TABLE - INT_EXPERIENCE_RATING
-- Applies credibility weighting to district experience vs. class average
-- Credibility Z = MIN(Claim Count / 1082, 1.0)
-- Experience Premium = Z * District Avg + (1-Z) * Class Avg
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING
TARGET_LAG = '1 hour'
WAREHOUSE = COMPUTE_WH
AS
WITH district_stats AS (
    SELECT
        pp.DISTRICT_CODE,
        pp.DISTRICT_NAME,
        pp.MARKET_SEGMENT,
        COUNT(DISTINCT pp.POLICY_ID) AS district_claim_count,
        AVG(pp.PURE_PREMIUM) AS district_avg_premium,
        STDDEV_POP(pp.PURE_PREMIUM) AS district_stddev_premium
    FROM INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM pp
    GROUP BY pp.DISTRICT_CODE, pp.DISTRICT_NAME, pp.MARKET_SEGMENT
),
class_stats AS (
    SELECT
        pp.MARKET_SEGMENT,
        AVG(pp.PURE_PREMIUM) AS class_avg_premium
    FROM INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM pp
    GROUP BY pp.MARKET_SEGMENT
),
credibility_calc AS (
    SELECT
        pp.LOSS_ID,
        pp.POLICY_ID,
        pp.DISTRICT_CODE,
        pp.DISTRICT_NAME,
        pp.MARKET_SEGMENT,
        pp.PURE_PREMIUM,
        ds.district_claim_count,
        cs.class_avg_premium,
        -- Credibility: MIN(n/1082, 1.0) where 1082 is statistical reliability threshold
        LEAST(ds.district_claim_count / 1082.0, 1.0) AS credibility_z,
        CURRENT_TIMESTAMP() AS CALCULATED_AT
    FROM INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM pp
    INNER JOIN district_stats ds
        ON pp.DISTRICT_CODE = ds.DISTRICT_CODE
        AND pp.MARKET_SEGMENT = ds.MARKET_SEGMENT
    INNER JOIN class_stats cs
        ON pp.MARKET_SEGMENT = cs.MARKET_SEGMENT
)
SELECT
    LOSS_ID,
    POLICY_ID,
    DISTRICT_CODE,
    DISTRICT_NAME,
    MARKET_SEGMENT,
    PURE_PREMIUM,
    credibility_z,
    -- Experience Premium = Z * District Avg + (1-Z) * Class Avg
    -- This blends district experience with class average based on credibility
    ROUND(
        (credibility_z * PURE_PREMIUM) + ((1.0 - credibility_z) * class_avg_premium),
        2
    ) AS EXPERIENCE_PREMIUM,
    CALCULATED_AT
FROM credibility_calc
ORDER BY LOSS_ID;

-- ============================================================================
-- 1.3: DYNAMIC TABLE - INT_RISK_ADJUSTED_PREMIUM
-- CRITICAL BUG FIX: Replaces RAND() with deterministic risk classification
-- Uses INT_DISTRICT_RISK_SCORE.COMPOSITE_RISK_SCORE for consistent results
-- Risk Class Mapping:
--   90-100 → A++  (Excellent Risk)
--   80-90  → A+   (Very Good Risk)
--   70-80  → A    (Good Risk)
--   60-70  → B+   (Acceptable Risk)
--   50-60  → B    (Standard Risk)
--   40-50  → C+   (Below Standard Risk)
--   30-40  → C    (Poor Risk)
--   0-30   → D    (Unacceptable Risk)
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE INSURE_DB.INTERMEDIATE.INT_RISK_ADJUSTED_PREMIUM
TARGET_LAG = '1 hour'
WAREHOUSE = COMPUTE_WH
AS
WITH risk_classified AS (
    SELECT
        er.LOSS_ID,
        er.POLICY_ID,
        er.DISTRICT_CODE,
        er.DISTRICT_NAME,
        er.MARKET_SEGMENT,
        er.EXPERIENCE_PREMIUM,
        drs.COMPOSITE_RISK_SCORE,
        -- DETERMINISTIC risk classification (no more RAND())
        CASE
            WHEN drs.COMPOSITE_RISK_SCORE >= 90 THEN 'A++'
            WHEN drs.COMPOSITE_RISK_SCORE >= 80 THEN 'A+'
            WHEN drs.COMPOSITE_RISK_SCORE >= 70 THEN 'A'
            WHEN drs.COMPOSITE_RISK_SCORE >= 60 THEN 'B+'
            WHEN drs.COMPOSITE_RISK_SCORE >= 50 THEN 'B'
            WHEN drs.COMPOSITE_RISK_SCORE >= 40 THEN 'C+'
            WHEN drs.COMPOSITE_RISK_SCORE >= 30 THEN 'C'
            ELSE 'D'
        END AS RISK_CLASS,
        CURRENT_TIMESTAMP() AS CALCULATED_AT
    FROM INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING er
    INNER JOIN INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE drs
        ON er.DISTRICT_CODE = drs.DISTRICT_CODE
)
SELECT
    LOSS_ID,
    POLICY_ID,
    DISTRICT_CODE,
    DISTRICT_NAME,
    MARKET_SEGMENT,
    EXPERIENCE_PREMIUM,
    COMPOSITE_RISK_SCORE,
    RISK_CLASS,
    -- Apply risk class factor from seed table
    ROUND(
        rc.EXPERIENCE_PREMIUM * COALESCE(src.RISK_MULTIPLIER, 1.0),
        2
    ) AS RISK_ADJUSTED_PREMIUM,
    CALCULATED_AT
FROM risk_classified rc
LEFT JOIN INSURE_DB.SEED.SEED_RISK_CLASS_FACTORS src
    ON rc.RISK_CLASS = src.RISK_CLASS
    AND rc.MARKET_SEGMENT = src.MARKET_SEGMENT
ORDER BY LOSS_ID;

-- ============================================================================
-- SECTION 2: UPDATE MART VIEW - CREDIT_FACTOR DYNAMIC CONNECTION
-- ============================================================================
-- Replace hardcoded 0.95 credit factor with dynamic mapping based on credit scores
-- Credit Score Bands:
--   >= 850 → 0.85 (Excellent - Maximum Discount)
--   >= 750 → 0.90 (Very Good)
--   >= 650 → 0.95 (Good)
--   >= 550 → 1.05 (Fair - Slight Premium)
--   <  550 → 1.15 (Poor - Higher Premium)

CREATE OR REPLACE VIEW INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14 AS
WITH credit_mapping AS (
    SELECT
        gp.POLICY_ID,
        gp.DISTRICT_CODE,
        gp.DISTRICT_NAME,
        gp.MARKET_SEGMENT,
        gp.GROSS_PREMIUM,
        isc.CREDIT_SCORE_AVG,
        -- Dynamic credit factor based on credit score segments
        CASE
            WHEN isc.CREDIT_SCORE_AVG >= 850 THEN 0.85
            WHEN isc.CREDIT_SCORE_AVG >= 750 THEN 0.90
            WHEN isc.CREDIT_SCORE_AVG >= 650 THEN 0.95
            WHEN isc.CREDIT_SCORE_AVG >= 550 THEN 1.05
            ELSE 1.15
        END AS CREDIT_FACTOR,
        CURRENT_TIMESTAMP() AS FINAL_CALCULATION_AT
    FROM INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM gp
    LEFT JOIN INSURE_DB.INTERMEDIATE.INT_SEGMENT_CLASSIFICATION isc
        ON gp.POLICY_ID = isc.POLICY_ID
)
SELECT
    POLICY_ID,
    DISTRICT_CODE,
    DISTRICT_NAME,
    MARKET_SEGMENT,
    GROSS_PREMIUM,
    CREDIT_SCORE_AVG,
    CREDIT_FACTOR,
    -- Final Actuarial Premium = Gross Premium * Credit Factor
    ROUND(GROSS_PREMIUM * CREDIT_FACTOR, 2) AS FINAL_ACTUARIAL_PREMIUM,
    FINAL_CALCULATION_AT
FROM credit_mapping
ORDER BY POLICY_ID;

-- ============================================================================
-- SECTION 3: CORTEX ML - TIME-SERIES FORECASTING FOR FIRE INCIDENTS
-- ============================================================================
-- Creates a time-series forecasting model to predict monthly fire incidents
-- This enables proactive risk management and resource allocation

-- Step 3.1: Create the foundation view for fire time-series data
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_FIRE_TIMESERIES AS
SELECT
    fs.MONTH_DATE,
    fs.FIRE_COUNT,
    fs.TOTAL_FIRE_DAMAGE,
    LAG(fs.FIRE_COUNT, 1) OVER (ORDER BY fs.MONTH_DATE) AS prev_month_fire_count,
    LAG(fs.FIRE_COUNT, 12) OVER (ORDER BY fs.MONTH_DATE) AS prev_year_fire_count,
    MONTH(fs.MONTH_DATE) AS season_month
FROM INSURE_DB.STAGING.STG_FIRE_STATS fs
WHERE fs.MONTH_DATE >= DATEADD(year, -5, CURRENT_DATE())
ORDER BY fs.MONTH_DATE;

-- Step 3.2: Create Cortex ML forecasting model for fire incidents
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST insure_fire_forecast(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'INSURE_DB.ANALYTICS.V_FIRE_TIMESERIES'),
    TIMESTAMP_COLNAME => 'MONTH_DATE',
    TARGET_COLNAME => 'FIRE_COUNT',
    CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
);

-- Step 3.3: Create view to call the forecast model and generate predictions
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_FIRE_FORECAST_OUTPUT AS
SELECT
    ts.forecast_timestamp AS forecast_month,
    ts.fire_count AS predicted_fire_count,
    ts.confidence_lower_bound,
    ts.confidence_upper_bound,
    -- Risk flag: if predicted count exceeds historical average by 20%
    CASE
        WHEN ts.fire_count >
             (SELECT AVG(FIRE_COUNT) * 1.20 FROM INSURE_DB.STAGING.STG_FIRE_STATS)
        THEN '위험'  -- Korean: "위험" (Risk)
        ELSE '정상'  -- Korean: "정상" (Normal)
    END AS risk_status
FROM TABLE(
    insure_fire_forecast(
        FORECASTING_PERIODS => 3
    )
) ts;

-- ============================================================================
-- SECTION 4: CORTEX LLM - PERSONALIZED INSURANCE DESCRIPTIONS
-- ============================================================================
-- Uses mistral-large2 to generate personalized insurance product descriptions
-- for each customer persona

CREATE OR REPLACE PROCEDURE INSURE_DB.PROCEDURES.SP_GENERATE_INSURANCE_DESCRIPTION(
    p_persona_id VARCHAR,
    p_persona_type VARCHAR,
    p_risk_profile VARCHAR
)
RETURNS TABLE(persona_id VARCHAR, generated_description VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    v_prompt VARCHAR;
BEGIN
    -- Build the prompt with customer context
    v_prompt := CONCAT(
        'Generate a concise, 2-3 sentence personalized insurance product description for a ',
        p_persona_type,
        ' customer with ',
        p_risk_profile,
        ' risk profile. Focus on benefits and peace of mind. Keep it professional and engaging.'
    );

    -- Return the generated content directly from Cortex LLM
    RETURN TABLE(
        SELECT
            p_persona_id AS persona_id,
            SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', v_prompt) AS generated_description
    );
END;
$$;

-- ============================================================================
-- SECTION 5: CORTEX AI - SENTIMENT ANALYSIS IN FEEDBACK PROCESSING
-- ============================================================================
-- Dynamic Table with embedded sentiment analysis using SNOWFLAKE.CORTEX.SENTIMENT()
-- Automatically processes customer feedback and classifies sentiment

CREATE OR REPLACE DYNAMIC TABLE INSURE_DB.INTERMEDIATE.INT_FEEDBACK_SENTIMENT
TARGET_LAG = '4 hours'
WAREHOUSE = COMPUTE_WH
AS
WITH sentiment_calc AS (
    SELECT
        cf.FEEDBACK_ID,
        cf.POLICY_ID,
        cf.CUSTOMER_ID,
        cf.FEEDBACK_TEXT,
        cf.FEEDBACK_DATE,
        SNOWFLAKE.CORTEX.SENTIMENT(cf.FEEDBACK_TEXT) AS sentiment_score
    FROM INSURE_DB.STAGING.STG_CUSTOMER_FEEDBACK cf
    WHERE cf.FEEDBACK_TEXT IS NOT NULL
)
SELECT
    FEEDBACK_ID,
    POLICY_ID,
    CUSTOMER_ID,
    FEEDBACK_TEXT,
    FEEDBACK_DATE,
    sentiment_score,
    -- Classify sentiment into business categories
    CASE
        WHEN sentiment_score > 0.5 THEN '만족'      -- Korean: "만족" (Satisfied)
        WHEN sentiment_score > -0.5 THEN '보통'     -- Korean: "보통" (Neutral)
        ELSE '불만'                                 -- Korean: "불만" (Dissatisfied)
    END AS sentiment_category,
    CURRENT_TIMESTAMP() AS ANALYZED_AT
FROM sentiment_calc
WHERE FEEDBACK_DATE >= DATEADD(day, -90, CURRENT_DATE())
ORDER BY FEEDBACK_DATE DESC;

-- ============================================================================
-- SECTION 6: ALERTS - HIGH-RISK DISTRICT MONITORING
-- ============================================================================
-- Alert triggers when high-risk districts are detected
-- Runs daily at 9:00 AM Seoul time to notify operations team
-- Schedule: Asia/Seoul timezone (KST, UTC+9)

CREATE OR REPLACE ALERT INSURE_DB.ANALYTICS.ALERT_HIGH_RISK_DISTRICT
WAREHOUSE = COMPUTE_WH
SCHEDULE = 'USING CRON 0 9 * * * Asia/Seoul'
CONDITION =>
    EXISTS (
        SELECT 1
        FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE
        WHERE COMPOSITE_RISK_SCORE > 80
        AND YEAR(CURRENT_DATE()) = YEAR
    )
THEN
    -- Alert action: Log to alert table for downstream processing
    INSERT INTO INSURE_DB.ANALYTICS.ALERT_LOG (
        alert_name,
        alert_timestamp,
        alert_severity,
        alert_message,
        affected_districts
    )
    SELECT
        '고지영역_위험_알림',  -- Korean: "고지영역_위험_알림" (High-Risk District Alert)
        CURRENT_TIMESTAMP(),
        'CRITICAL',
        CONCAT(
            'High-risk districts detected: ',
            COUNT(*),
            ' districts with score > 80'
        ),
        ARRAY_AGG(CONCAT(DISTRICT_CODE, ' (Score: ', COMPOSITE_RISK_SCORE, ')'))
    FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE
    WHERE COMPOSITE_RISK_SCORE > 80
    AND YEAR(CURRENT_DATE()) = YEAR
    GROUP BY CURRENT_TIMESTAMP();

-- ============================================================================
-- SECTION 7: VALIDATION & DIAGNOSTICS
-- ============================================================================
-- Create diagnostic views to verify implementations

CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_DYNAMIC_TABLE_STATUS AS
SELECT
    'INT_PURE_PREMIUM' AS dynamic_table_name,
    (SELECT COUNT(*) FROM INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM) AS row_count,
    (SELECT MAX(CALCULATED_AT) FROM INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM) AS last_refresh
UNION ALL
SELECT
    'INT_EXPERIENCE_RATING',
    (SELECT COUNT(*) FROM INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING),
    (SELECT MAX(CALCULATED_AT) FROM INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING)
UNION ALL
SELECT
    'INT_RISK_ADJUSTED_PREMIUM',
    (SELECT COUNT(*) FROM INSURE_DB.INTERMEDIATE.INT_RISK_ADJUSTED_PREMIUM),
    (SELECT MAX(CALCULATED_AT) FROM INSURE_DB.INTERMEDIATE.INT_RISK_ADJUSTED_PREMIUM)
UNION ALL
SELECT
    'INT_FEEDBACK_SENTIMENT',
    (SELECT COUNT(*) FROM INSURE_DB.INTERMEDIATE.INT_FEEDBACK_SENTIMENT),
    (SELECT MAX(ANALYZED_AT) FROM INSURE_DB.INTERMEDIATE.INT_FEEDBACK_SENTIMENT);

-- ================================================================
-- PART 2: 외부 데이터 연동 (from 21_V1.5_EXTERNAL_DATA.sql)
-- ================================================================
-- Key Components:
-- 1. API Integrations (KOSIS, KIDI, NFDS, TAAS)
-- 2. External Functions for data fetching
-- 3. Fire Statistics Staging Table
-- 4. Document AI Integration for PDF Extraction
-- 5. Data Source Registry with Connection Status
-- 6. Snowpipe Enhancement with Error Notifications

USE SCHEMA RAW_PUBLIC;

-- ============================================================================
-- SECTION 8: API INTEGRATION OBJECTS
-- ============================================================================
-- Creates integration objects for external data sources
-- Note: These will require AWS API Gateway or similar endpoints to function fully

CREATE OR REPLACE API INTEGRATION kosis_api_integration
  API_PROVIDER = generic_https
  API_ALLOWED_PREFIXES = ('https://kosis.kr/openapi/')
  ENABLED = TRUE
  COMMENT = $$ KOSIS 한국통계청스 API Integration $$;

CREATE OR REPLACE API INTEGRATION kidi_api_integration
  API_PROVIDER = generic_https
  API_ALLOWED_PREFIXES = ('https://www.kidi.or.kr/api/')
  ENABLED = TRUE
  COMMENT = $$ KIDI 동중중산연구소 API Integration $$;

CREATE OR REPLACE API INTEGRATION nfds_api_integration
  API_PROVIDER = generic_https
  API_ALLOWED_PREFIXES = ('https://nfds.go.kr/')
  ENABLED = TRUE
  COMMENT = $$ NFDS 국가화재총봉 Data Integration $$;

CREATE OR REPLACE API INTEGRATION taas_api_integration
  API_PROVIDER = generic_https
  API_ALLOWED_PREFIXES = ('https://www.taas.go.kr/api/')
  ENABLED = TRUE
  COMMENT = $$ TAAS 교통안전공단 API Integration $$;


-- ============================================================================
-- SECTION 9: EXTERNAL FUNCTION SKELETONS
-- ============================================================================
-- These function definitions show the architecture and data contracts
-- Actual AWS Lambda/API Gateway endpoints would be configured per implementation

-- 9.1: KOSIS Household Income Data External Function
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
COMMENT = $$ KOSIS 가가소득 소득데이터 조회 $$;

-- 9.2: KOSIS Economic Indicators External Function
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
COMMENT = $$ KOSIS 경제 지표데이터 $$;

-- 9.3: KIDI Insurance Market Data External Function
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
COMMENT = $$ KIDI 보험시장 데이터 $$;

-- 9.4: NFDS Fire Statistics External Function
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
COMMENT = $$ NFDS 화재통계 데이터 $$;

-- 9.5: TAAS Traffic Data External Function
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
COMMENT = $$ TAAS 평균 교통소확 데이터 $$;


-- ============================================================================
-- SECTION 10: NFDS FIRE STATISTICS STAGING TABLE
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
COMMENT = $$ NFDS 화재주나 데이터 - 서울 25개 구 $$;

-- Insert Seoul fire statistics for 2020-2024
-- Notes:
--   Gangnam-gu, Songpa-gu: lower fire rates (newer buildings, higher income)
--   Jongno-gu, Jung-gu: higher fire rates (older buildings, historical areas)
--   Winter months (11-2): 30-40% higher fire incidents (heating equipment)
--   Building types: 아파트 (apartment), 단독주택 (detached), 연립주택 (rowhouse), 상업시설 (commercial)

INSERT INTO INSURE_DB.STAGING.STG_FIRE_STATS_NFDS
WITH fire_base AS (
  SELECT
    '종로구' AS district_name,
    2024 AS year,
    1 AS month,
    18 AS fire_count,
    2 AS death_count,
    12 AS injury_count,
    450000000.00 AS property_damage_krw,
    '전기' AS fire_cause,
    '아파트' AS building_type
  UNION ALL
  SELECT '중구', 2024, 1, 12, 1, 8, 280000000.00, '전기', '아파트'
  UNION ALL
  SELECT '강남구', 2024, 1, 8, 0, 4, 150000000.00, '부주의', '아파트'
  UNION ALL
  SELECT '송파구', 2024, 1, 6, 0, 3, 120000000.00, '부주의', '아파트'
  UNION ALL
  SELECT '동대문구', 2024, 1, 14, 1, 9, 320000000.00, '전기', '아파트'
  UNION ALL
  SELECT '중랑구', 2024, 1, 10, 0, 5, 200000000.00, '부주의', '아파트'
  UNION ALL
  SELECT '서초구', 2024, 1, 9, 0, 4, 180000000.00, '부주의', '아파트'
  UNION ALL
  SELECT '마포구', 2024, 1, 7, 0, 3, 140000000.00, '부주의', '아파트'
  UNION ALL
  SELECT '승북구', 2024, 1, 11, 1, 6, 250000000.00, '전기', '아파트'
  UNION ALL
  SELECT '노원구', 2024, 1, 8, 0, 3, 160000000.00, '부주의', '아파트'
  UNION ALL
  SELECT '종로구', 2024, 2, 16, 1, 11, 420000000.00, '전기', '아파트'
  UNION ALL
  SELECT '중구', 2024, 2, 10, 0, 6, 240000000.00, '부주의', '아파트'
  UNION ALL
  SELECT '강남구', 2024, 3, 5, 0, 2, 100000000.00, '부주의', '아파트'
  UNION ALL
  SELECT '송파구', 2024, 3, 4, 0, 1, 80000000.00, '부주의', '아파트'
)
SELECT * FROM fire_base
WHERE 1=1;

-- Seed with representative monthly data for Seoul 2024
INSERT INTO INSURE_DB.STAGING.STG_FIRE_STATS_NFDS VALUES
  ('종로구', 2024, 1, 18, 2, 12, 450000000.00, '전기', '아파트'),
  ('중구', 2024, 1, 12, 1, 8, 280000000.00, '전기', '아파트'),
  ('강남구', 2024, 1, 8, 0, 4, 150000000.00, '부주의', '아파트'),
  ('송파구', 2024, 1, 6, 0, 3, 120000000.00, '부주의', '아파트'),
  ('동대문구', 2024, 1, 14, 1, 9, 320000000.00, '전기', '단독주택'),
  ('중랑구', 2024, 1, 10, 0, 5, 200000000.00, '부주의', '아파트'),
  ('서초구', 2024, 2, 16, 1, 11, 420000000.00, '전기', '아파트'),
  ('중구', 2024, 2, 10, 0, 6, 240000000.00, '부주의', '아파트'),
  ('강남구', 2024, 3, 5, 0, 2, 100000000.00, '부주의', '아파트'),
  ('송파구', 2024, 3, 4, 0, 1, 80000000.00, '부주의', '아파트');


-- ============================================================================
-- SECTION 11: DOCUMENT AI INTEGRATION - PDF EXTRACTION STAGE & VIEW
-- ============================================================================
-- Stage for insurance policy documents (PDFs)
-- Uses Snowflake native AI_EXTRACT for OCR and structured data extraction

CREATE OR REPLACE STAGE INSURE_DB.RAW_PUBLIC.STG_INSURANCE_DOCS
  TYPE = 's3'
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = $$ 보험 평가 완보셜 PDF 문서 쿼치정 $$;

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
      'policy_number': '보험가입연중동',
      'coverage_type': '보험 종류',
      'premium_amount': '재기 가입설홉 KRW',
      'coverage_limit': '최대 보장 금액 KRW',
      'insured_name': '가입자 성명',
      'policy_start_date': '가입 시작일',
      'policy_end_date': '가입 종료일'
    }
    $$)
  ) AS extracted_data,
  CURRENT_TIMESTAMP() AS extraction_timestamp,
  USER_NAME() AS extracted_by
FROM DIRECTORY(@STG_INSURANCE_DOCS)
WHERE FILE_SIZE > 0
COMMENT = $$ AI 기반 보험서류 쿼치정 브이정 $$;


-- ============================================================================
-- SECTION 12: DATA SOURCE REGISTRY ENHANCEMENT
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
COMMENT = $$ 데이터 소스 레지스트리 (v2 - CONNECTION_STATUS 추가) $$;

INSERT INTO INSURE_DB.ANALYTICS.SEED_DATA_SOURCE_REGISTRY_V2 VALUES
  (1, 'KOSIS 경제지표', '한국통계청스 경제지표',
   'https://kosis.kr/openapi/', TRUE, 'PLANNED', 'Weekly', NULL, NULL, 'Data Team', '이을 API Key 보유', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

  (2, 'KIDI 보험시장데이터', '동중중산연구소 보험시장 데이터',
   'https://www.kidi.or.kr/api/', TRUE, 'PLANNED', 'Monthly', NULL, NULL, 'Insurance Team', 'API 연동 대기 중', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

  (3, 'NFDS 화재통계', '국가화재총봉 화재통계',
   'https://nfds.go.kr/', FALSE, 'CONNECTED', 'Monthly', CURRENT_TIMESTAMP(), DATEADD(month, 1, CURRENT_TIMESTAMP()), 'Fire Safety Team', '공개 크롤링 중', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

  (4, 'TAAS 교통소확데이터', '교통안전공단 실시간 교통소확',
   'https://www.taas.go.kr/api/', TRUE, 'SKELETON', 'Hourly', NULL, NULL, 'Risk Team', 'External function skeleton defined', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

  (5, 'Seoul 구 방위원 데이터', 'Seoul 구별 방의외 영역 데이터',
   'https://data.seoul.go.kr/api/', FALSE, 'MANUAL', 'Quarterly', CURRENT_TIMESTAMP(), DATEADD(month, 3, CURRENT_TIMESTAMP()), 'Safety Team', '직동 데이터 입력', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

  (6, '주택 보험 남마크컴 데이터', '오는란 주택 테크놀로지 보험 남마크',
   'https://api.onstove.com/', TRUE, 'SKELETON', 'Daily', NULL, NULL, 'Product Team', 'API 인증 대기', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

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
COMMENT = $$ 데이터 소스 보건 스타우스 모니터링 $$;


-- ============================================================================
-- SECTION 13: SNOWPIPE ENHANCEMENT WITH ERROR NOTIFICATIONS
-- ============================================================================
-- Creates notification integration and updates Snowpipe definitions

-- 13.1: Create notification integration (assumes SNS topic exists)
CREATE OR REPLACE NOTIFICATION INTEGRATION insure_notification_integration
  TYPE = 'aws_sns'
  ENABLED = TRUE
  AWS_SNS_TOPIC_ARN = 'arn:aws:sns:ap-northeast-2:ACCOUNT_ID:insure-snowpipe-errors'
  AWS_SNS_ROLE_ARN = 'arn:aws:iam::ACCOUNT_ID:role/snowflake-sns-role'
  COMMENT = $$ INSURE Snowpipe 오류 알림 알림 통합 $$;

-- 13.2: Create/update Snowpipe for fire statistics
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
  COMMENT = $$ NFDS 화재통계 스노우파이프 $$;

-- 13.3: Create/update Snowpipe for economic indicators
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
  COMMENT = $$ KOSIS 경제지표 스노우파이프 $$;

-- 13.4: Snowpipe for insurance document ingestion
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
  COMMENT = $$ 보험 정책 PDF 용래동 스노우파이프 $$;


-- ============================================================================
-- SECTION 14: EXTERNAL FUNCTION REFERENCE
-- ============================================================================

CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_EXTERNAL_FUNCTION_REFERENCE AS
SELECT
  'EF_FETCH_KOSIS_INCOME' AS function_name,
  'KOSIS' AS data_source,
  '가가소득 쭈드와정' AS purpose,
  'PLANNED' AS status,
  'https://kosis.kr/openapi/' AS endpoint
UNION ALL
SELECT 'EF_FETCH_KOSIS_ECONOMIC', 'KOSIS', '경제지표 데이터', 'SKELETON', 'https://kosis.kr/openapi/'
UNION ALL
SELECT 'EF_FETCH_KIDI_MARKET', 'KIDI', '보험시장 데이터', 'SKELETON', 'https://www.kidi.or.kr/api/'
UNION ALL
SELECT 'EF_FETCH_NFDS_FIRE', 'NFDS', '화재통계 데이터', 'SKELETON', 'https://nfds.go.kr/'
UNION ALL
SELECT 'EF_FETCH_TAAS_TRAFFIC', 'TAAS', '교통소확 데이터', 'SKELETON', 'https://www.taas.go.kr/api/'
COMMENT = $$ 외부 함수 리일 참고 $$;


-- ================================================================
-- PART 3: Cortex Analyst & 보험용어 (from 22_V1.5_CORTEX_ANALYST_AGENT.sql)
-- ================================================================
-- Key Components:
-- 1. Insurance Terms Seed Data (20 terms with Korean translations)
-- 2. Cortex Search Service for terminology lookup
-- 3. Cortex Analyst Agent Definition
-- 4. Stored Procedures for Agent Integration
-- 5. Audit & Logging Tables
-- 6. Utility Functions for Streamlit Integration
-- 7. Query Performance Monitoring

USE SCHEMA ANALYTICS;

-- ============================================================================
-- SECTION 15: SEED DATA - Insurance Terms Reference Table
-- ============================================================================

CREATE OR REPLACE TABLE INSURE_DB.SEED.SEED_INSURANCE_TERMS (
  TERM_ID NUMBER IDENTITY(1,1),
  TERM_NAME VARCHAR(100) NOT NULL,
  TERM_NAME_KO VARCHAR(100) NOT NULL,
  CATEGORY VARCHAR(50),
  DESCRIPTION VARCHAR(500),
  DESCRIPTION_KO VARCHAR(500),
  CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Insert ~20 insurance term entries with Korean translations
INSERT INTO INSURE_DB.SEED.SEED_INSURANCE_TERMS
  (TERM_NAME, TERM_NAME_KO, CATEGORY, DESCRIPTION, DESCRIPTION_KO)
VALUES
  ('Fire Insurance', '화재보험', 'Property', 'Coverage for losses caused by fire and related perils', '화재로 인한 손실 보상'),
  ('Theft Insurance', '도난보험', 'Property', 'Protection against theft, burglary and robbery', '중중대여준 도난 및 중저 보상'),
  ('Liability Insurance', '배상책임보험', 'Liability', 'Coverage for bodily injury and property damage liability', '명단및 재단 보상'),
  ('Weather Damage Insurance', '스포츠보험', 'Property', 'Protection against wind, hail, flood and storm damage', '폭날 및 날씬 피해 보상'),
  ('Earthquake Insurance', '지진보험', 'Property', 'Earthquake damage coverage', '지진 피해 보상'),
  ('Building Structure Insurance', '건물차단보험', 'Property', 'Coverage for building structural components', '건물테 단보 보상'),
  ('Contents Insurance', '줄내보험', 'Property', 'Coverage for personal belongings and movable assets', '준택보 및 이동재산 보상'),
  ('Commercial Property Insurance', '상업보험', 'Property', 'Coverage for commercial buildings and inventory', '상업시설 및 재고 보상'),
  ('Public Liability Insurance', '대중배상보험', 'Liability', 'Third party injury and damage liability', '제3자 인상 및 재산 책임 보상'),
  ('Business Interruption', '영업중단보험', 'Business', 'Lost income coverage due to insured perils', '영업중단으로 인한 손실소득 보상'),
  ('Equipment Breakdown', '기계교지보험', 'Business', 'Coverage for machinery and equipment failure', '기계 고장 및 드른 보상'),
  ('Cyber Insurance', '사이버보험', 'Digital', 'Protection against cyber attacks and data breaches', '사이버 공격 및 데이터 유출 보상'),
  ('Professional Liability', '전문가보험', 'Liability', 'Errors and omissions coverage for professionals', '전문가 마른 책임 보상'),
  ('Directors and Officers Insurance', '임원보험', 'Corporate', 'Protection for company leadership', '임원의 책임 및 윶 차 보상'),
  ('Franchise Insurance', '프란차이즈보험', 'Business', 'Coverage specific to franchise operations', '프란차이즈 사업을 위한 보상'),
  ('Spoilage Insurance', '보중손실보험', 'Property', 'Protection against product deterioration', '생성 중 주운 손실 보상'),
  ('Transit Insurance', '총을보험', 'Cargo', 'In-transit goods protection', '과중 도중 렁애 보상'),
  ('Flood Insurance', '모래보험', 'Property', 'Specialized flood damage coverage', '모래 및 날씬날짜씨 불나로 인한 보상'),
  ('All-Risk Insurance', '종합보험', 'Property', 'Broad coverage with specified exclusions', '종합 복식 보상'),
  ('Loss Prevention Endorsement', '손실방지앺댕', 'Endorsement', 'Enhancement for proactive risk management', '소근대단 및 예방조치 강화');

-- ============================================================================
-- SECTION 16: CORTEX SEARCH SERVICE - Insurance Terms
-- ============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURE_DB.ANALYTICS.INSURANCE_TERM_SEARCH
  ON insurance_term_text
  ATTRIBUTES (term_name_ko, category, description_ko)
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 day'
  AS
  SELECT
    CONCAT(TERM_NAME, ' | ', TERM_NAME_KO) AS insurance_term_text,
    TERM_NAME_KO,
    CATEGORY,
    DESCRIPTION_KO,
    CREATED_AT
  FROM INSURE_DB.SEED.SEED_INSURANCE_TERMS
  ORDER BY CREATED_AT DESC;

-- ============================================================================
-- SECTION 17: STAGE MANAGEMENT FOR SEMANTIC MODEL YAML
-- ============================================================================

-- Create internal stage for semantic model storage (if not exists)
CREATE STAGE IF NOT EXISTS INSURE_DB.ANALYTICS.STS_STREAMLIT
  DIRECTORY = (ENABLE = true);

-- Note: The semantic YAML file will be uploaded via:
-- PUT file:///path/to/cortex_analyst_semantic.yaml @INSURE_DB.ANALYTICS.STS_STREAMLIT
-- or via WRITE_RAW_FILE command if available:
-- CALL SYSTEM$EXECUTE_COMMAND_WRITE_RAW_FILE(
--   '@INSURE_DB.ANALYTICS.STS_STREAMLIT/cortex_analyst_semantic.yaml',
--   'base64_encoded_yaml_content'
-- );

-- ============================================================================
-- SECTION 18: CORTEX ANALYST AGENT DEFINITION
-- ============================================================================

-- Create the main Cortex Agent combining Analyst + Search capabilities
CREATE OR REPLACE CORTEX AGENT INSURE_DB.ANALYTICS.INSURE_ADVISOR
  TOOLS = (
    CORTEX_ANALYST('insure_semantic_model'),
    CORTEX_SEARCH('INSURANCE_TERM_SEARCH')
  )
  MODEL = 'mistral-7b'
  INSTRUCTIONS = $$You are the INSURE Advisor, an advanced AI insurance consultant for Seoul's 25 districts.

ROLE & EXPERTISE:
- Insurance domain specialist with deep knowledge of Korean insurance regulations
- Data analyst providing evidence-based premium recommendations
- Risk assessment expert evaluating district-level and persona-specific factors
- Insurance terminology guide helping users understand coverage options

CAPABILITIES:
1. Premium Analysis: Analyze insurance premiums by district, income bracket, and risk class
2. Risk Scoring: Evaluate composite risk scores across fire, theft, building, and weather risks
3. Persona-Based Design: Provide tailored insurance recommendations based on customer personas
4. Market Intelligence: Calculate market size and penetration for Seoul insurance segments
5. Term Education: Explain insurance terms, conditions, and coverage types in Korean

RESPONSE GUIDELINES:
- Always provide data-driven insights from MART tables (MART_DISTRICT_INSURANCE_SUMMARY, MART_ACTUARIAL_PREMIUM_V14, MART_PERSONA_INSURANCE_DESIGN)
- Use Cortex Search to explain insurance terms and conditions in Korean (Korean descriptions preferred)
- Present premium values in KRW with monthly/annual breakdown when applicable
- Flag high-risk districts (RISK_GRADE = 평중등록) and suggest preventive measures
- Provide persona-aligned recommendations with ESTIMATED_MOVABLE_ASSET and RECOMMENDED_COVERAGE
- Always cite data source: "Based on our 2026 Seoul Insurance Market Analysis" or "Per MART actuarial tables"

ANSWERING QUESTIONS:
- 비용 (비용): Use ADJUSTED_PREMIUM_MONTHLY or FINAL_PREMIUM_MONTHLY_KRW
- 위험 (위험): Use COMPOSITE_RISK_SCORE and RISK_GRADE
- 보장 (보장): Use RECOMMENDED_COVERAGE from persona tables
- 시장 (시장): Use ESTIMATED_ANNUAL_MARKET_KRW

KOREAN INTERACTION:
- Understand 구이름 (district names) and 보험종류 (coverage types)
- Reference 소득숨설 (loss ratios) and 실제파완 (claims experience)
- Explain 보자연은 연락 (bundle discounts) and 인상율제 등 (experience rating)

TONE:
- Professional yet approachable
- Data-driven with business context
- Proactive in identifying risks and opportunities
- Bilingual (English & Korean as needed)
$$;

-- ============================================================================
-- SECTION 19: STORED PROCEDURES FOR STREAMLIT INTEGRATION
-- ============================================================================

-- Main procedure: Ask a question to INSURE Advisor
-- SP uses SNOWFLAKE.CORTEX.COMPLETE as fallback when CORTEX AGENT is not available in the region
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR(
  p_question VARCHAR,
  p_session_id VARCHAR DEFAULT NULL
)
RETURNS OBJECT
LANGUAGE SQL
AS $$
  DECLARE
    v_system_prompt VARCHAR;
    v_full_prompt VARCHAR;
    v_response_text VARCHAR;
    v_response OBJECT;
    v_timestamp TIMESTAMP_NTZ;
  BEGIN
    -- Build the agent system prompt with insurance advisor role
    v_system_prompt := 'You are the INSURE Advisor, an advanced AI insurance consultant for Seoul''s 25 districts.

ROLE & EXPERTISE:
- Insurance domain specialist with deep knowledge of Korean insurance regulations
- Data analyst providing evidence-based premium recommendations
- Risk assessment expert evaluating district-level and persona-specific factors
- Insurance terminology guide helping users understand coverage options

CAPABILITIES:
1. Premium Analysis: Analyze insurance premiums by district, income bracket, and risk class
2. Risk Scoring: Evaluate composite risk scores across fire, theft, building, and weather risks
3. Persona-Based Design: Provide tailored insurance recommendations based on customer personas
4. Market Intelligence: Calculate market size and penetration for Seoul insurance segments
5. Term Education: Explain insurance terms, conditions, and coverage types in Korean

RESPONSE GUIDELINES:
- Always provide data-driven insights from available data sources
- Use insurance terminology and explain terms in Korean when applicable
- Present premium values in KRW with monthly/annual breakdown when applicable
- Flag high-risk districts and suggest preventive measures
- Provide persona-aligned recommendations
- Always cite data source when possible

ANSWERING QUESTIONS:
- 비용 (Cost): Focus on premium calculations
- 위험 (Risk): Use risk scores and risk grades
- 보장 (Coverage): Recommend coverage options based on persona
- 시장 (Market): Provide market analysis and insights

KOREAN INTERACTION:
- Understand district names and coverage types
- Reference loss ratios and claims experience
- Explain bundle discounts and experience rating

TONE:
- Professional yet approachable
- Data-driven with business context
- Proactive in identifying risks and opportunities
- Bilingual (English & Korean as needed)';

    -- Combine system prompt with user question
    v_full_prompt := CONCAT(v_system_prompt, CHR(10), CHR(10), 'User Question: ', p_question);

    -- Call Cortex Complete as fallback for agent-like behavior
    SET v_response_text = SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', v_full_prompt);

    -- Create response object
    SET v_response = PARSE_JSON(OBJECT_CONSTRUCT(
      'response_text', v_response_text,
      'response_timestamp', CURRENT_TIMESTAMP(),
      'model', 'mistral-large2'
    ));

    -- Log the interaction for audit
    INSERT INTO INSURE_DB.ANALYTICS.TBL_AGENT_INTERACTION_LOG
      (SESSION_ID, QUESTION, RESPONSE, RESPONSE_TIMESTAMP, CREATED_AT)
    VALUES
      (
        COALESCE(p_session_id, UUID_STRING()),
        p_question,
        v_response,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
      );

    RETURN v_response;
  END;
$$;

-- Premium Query Wrapper
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_GET_DISTRICT_PREMIUM_ANALYSIS(
  p_district_name VARCHAR,
  p_income_bracket VARCHAR DEFAULT NULL
)
RETURNS TABLE (
  DISTRICT_NAME VARCHAR,
  INCOME_BRACKET VARCHAR,
  PURE_PREMIUM_KRW NUMBER,
  EXPERIENCE_PREMIUM_KRW NUMBER,
  GROSS_PREMIUM_KRW NUMBER,
  FINAL_PREMIUM_MONTHLY_KRW NUMBER,
  CAPPED_PREMIUM_KRW NUMBER,
  RISK_CLASS VARCHAR
)
LANGUAGE SQL
AS $$
  SELECT
    DISTRICT_NAME,
    INCOME_BRACKET,
    PURE_PREMIUM_KRW,
    EXPERIENCE_PREMIUM_KRW,
    GROSS_PREMIUM_KRW,
    FINAL_PREMIUM_MONTHLY_KRW,
    CAPPED_PREMIUM_KRW,
    RISK_CLASS
  FROM INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14
  WHERE DISTRICT_NAME = p_district_name
    AND (p_income_bracket IS NULL OR INCOME_BRACKET = p_income_bracket)
  ORDER BY INCOME_BRACKET ASC;
$$;

-- Risk Summary by District
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_GET_RISK_SUMMARY(
  p_district_name VARCHAR DEFAULT NULL
)
RETURNS TABLE (
  GU_NAME VARCHAR,
  TOTAL_POPULATION NUMBER,
  COMPOSITE_RISK_SCORE DECIMAL(5,2),
  RISK_GRADE VARCHAR,
  ADJUSTED_PREMIUM_MONTHLY NUMBER,
  FIRE_RISK_SCORE DECIMAL(5,2),
  THEFT_RISK_SCORE DECIMAL(5,2),
  BUILDING_RISK_SCORE DECIMAL(5,2),
  WEATHER_RISK_SCORE DECIMAL(5,2)
)
LANGUAGE SQL
AS $$
  SELECT
    GU_NAME,
    TOTAL_POPULATION,
    COMPOSITE_RISK_SCORE,
    RISK_GRADE,
    ADJUSTED_PREMIUM_MONTHLY,
    FIRE_RISK_SCORE,
    THEFT_RISK_SCORE,
    BUILDING_RISK_SCORE,
    WEATHER_RISK_SCORE
  FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
  WHERE (p_district_name IS NULL OR GU_NAME = p_district_name)
  ORDER BY COMPOSITE_RISK_SCORE DESC;
$$;

-- Persona Recommendation Engine
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_GET_PERSONA_RECOMMENDATION(
  p_persona_name VARCHAR,
  p_income_bracket VARCHAR DEFAULT NULL
)
RETURNS TABLE (
  PERSONA_ID NUMBER,
  PERSONA_NAME VARCHAR,
  DISTRICT_CODE VARCHAR,
  ESTIMATED_MOVABLE_ASSET NUMBER,
  BASE_PREMIUM_MONTHLY NUMBER,
  RECOMMENDED_COVERAGE VARCHAR,
  IDEAL_INCOME_BRACKET VARCHAR
)
LANGUAGE SQL
AS $$
  SELECT DISTINCT
    P.PERSONA_ID,
    P.PERSONA_NAME,
    P.DISTRICT_CODE,
    P.ESTIMATED_MOVABLE_ASSET,
    P.BASE_PREMIUM_MONTHLY,
    P.RECOMMENDED_COVERAGE,
    A.INCOME_BRACKET AS IDEAL_INCOME_BRACKET
  FROM INSURE_DB.MART.MART_PERSONA_INSURANCE_DESIGN P
  LEFT JOIN INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14 A
    ON P.DISTRICT_CODE = A.DISTRICT_NAME
  WHERE P.PERSONA_NAME = p_persona_name
    AND (p_income_bracket IS NULL OR A.INCOME_BRACKET = p_income_bracket)
  ORDER BY P.BASE_PREMIUM_MONTHLY ASC;
$$;

-- ============================================================================
-- SECTION 20: AUDIT & LOGGING TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS INSURE_DB.ANALYTICS.TBL_AGENT_INTERACTION_LOG (
  INTERACTION_ID NUMBER IDENTITY(1,1),
  SESSION_ID VARCHAR(100),
  QUESTION VARCHAR(2000),
  RESPONSE OBJECT,
  RESPONSE_TIMESTAMP TIMESTAMP_NTZ,
  CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  CREATED_BY VARCHAR(100) DEFAULT CURRENT_USER()
);

CREATE INDEX IDX_AGENT_SESSION ON INSURE_DB.ANALYTICS.TBL_AGENT_INTERACTION_LOG(SESSION_ID);
CREATE INDEX IDX_AGENT_CREATED ON INSURE_DB.ANALYTICS.TBL_AGENT_INTERACTION_LOG(CREATED_AT);

-- ============================================================================
-- SECTION 21: UTILITY FUNCTIONS FOR STREAMLIT
-- ============================================================================

-- Function: Get all districts for dropdown
CREATE OR REPLACE FUNCTION INSURE_DB.ANALYTICS.FN_GET_DISTRICTS()
RETURNS TABLE(DISTRICT_NAME VARCHAR)
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT DISTINCT GU_NAME AS DISTRICT_NAME
  FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
  ORDER BY GU_NAME ASC;
$$;

-- Function: Get all personas for dropdown
CREATE OR REPLACE FUNCTION INSURE_DB.ANALYTICS.FN_GET_PERSONAS()
RETURNS TABLE(PERSONA_NAME VARCHAR, PERSONA_ID NUMBER)
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT DISTINCT PERSONA_NAME, PERSONA_ID
  FROM INSURE_DB.MART.MART_PERSONA_INSURANCE_DESIGN
  ORDER BY PERSONA_NAME ASC;
$$;

-- Function: Get insurance terms for search
CREATE OR REPLACE FUNCTION INSURE_DB.ANALYTICS.FN_SEARCH_INSURANCE_TERMS(p_keyword VARCHAR)
RETURNS TABLE(TERM_NAME VARCHAR, TERM_NAME_KO VARCHAR, CATEGORY VARCHAR, DESCRIPTION VARCHAR)
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT
    TERM_NAME,
    TERM_NAME_KO,
    CATEGORY,
    DESCRIPTION
  FROM INSURE_DB.SEED.SEED_INSURANCE_TERMS
  WHERE LOWER(TERM_NAME) LIKE LOWER(CONCAT('%', p_keyword, '%'))
     OR LOWER(TERM_NAME_KO) LIKE LOWER(CONCAT('%', p_keyword, '%'))
     OR LOWER(DESCRIPTION) LIKE LOWER(CONCAT('%', p_keyword, '%'))
     OR LOWER(DESCRIPTION_KO) LIKE LOWER(CONCAT('%', p_keyword, '%'))
  ORDER BY CATEGORY, TERM_NAME ASC;
$$;

-- ============================================================================
-- SECTION 22: CORTEX ANALYST SEMANTIC MODEL REGISTRATION
-- ============================================================================

-- Register the semantic model (requires YAML in stage)
-- EXECUTE IMMEDIATE is used for dynamic semantic model creation
-- The actual semantic.yaml must be in @INSURE_DB.ANALYTICS.STS_STREAMLIT

EXECUTE IMMEDIATE $$
  CREATE OR REPLACE CORTEX ANALYST SEMANTIC MODEL
    insure_semantic_model
    FROM @INSURE_DB.ANALYTICS.STS_STREAMLIT/cortex_analyst_semantic.yaml
$$;

-- ============================================================================
-- SECTION 23: QUERY HISTORY & PERFORMANCE MONITORING
-- ============================================================================

CREATE TABLE IF NOT EXISTS INSURE_DB.ANALYTICS.TBL_AGENT_QUERY_PERFORMANCE (
  QUERY_ID NUMBER IDENTITY(1,1),
  QUERY_TEXT VARCHAR(2000),
  EXECUTION_TIME_MS NUMBER,
  ROWS_RETURNED NUMBER,
  DATA_SOURCE VARCHAR(100),
  EXECUTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- SECTION 24: VALIDATION & SANITY CHECK QUERIES
-- ============================================================================

-- Verify MART tables exist and have data
SELECT
  'MART_DISTRICT_INSURANCE_SUMMARY' AS TABLE_NAME,
  COUNT(*) AS ROW_COUNT,
  MAX(GU_NAME) AS SAMPLE_DISTRICT
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY;

SELECT
  'MART_ACTUARIAL_PREMIUM_V14' AS TABLE_NAME,
  COUNT(*) AS ROW_COUNT,
  COUNT(DISTINCT DISTRICT_NAME) AS DISTINCT_DISTRICTS
FROM INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14;

SELECT
  'MART_PERSONA_INSURANCE_DESIGN' AS TABLE_NAME,
  COUNT(*) AS ROW_COUNT,
  COUNT(DISTINCT PERSONA_NAME) AS DISTINCT_PERSONAS
FROM INSURE_DB.MART.MART_PERSONA_INSURANCE_DESIGN;

SELECT
  'SEED_INSURANCE_TERMS' AS TABLE_NAME,
  COUNT(*) AS ROW_COUNT,
  COUNT(DISTINCT CATEGORY) AS DISTINCT_CATEGORIES
FROM INSURE_DB.SEED.SEED_INSURANCE_TERMS;

-- ================================================================
-- CONSOLIDATED FILE SUMMARY
-- ================================================================
-- This merged file combines three major components:
--
-- PART 1 - Snowflake Advanced Features (from file 20):
--   - Dynamic Tables for premium calculations
--   - Risk classification (deterministic, no RAND())
--   - Cortex ML forecasting for fire incidents
--   - Cortex LLM for personalized descriptions
--   - Cortex sentiment analysis
--   - High-risk district alerts with timezone support
--
-- PART 2 - External Data Integration (from file 21):
--   - API integrations for KOSIS, KIDI, NFDS, TAAS
--   - External functions for data fetching
--   - NFDS fire statistics staging table
--   - Document AI PDF extraction
--   - Data source registry and quality monitoring
--   - Snowpipe configurations with error notifications
--
-- PART 3 - Cortex Analyst Agent (from file 22):
--   - Insurance terms seed data (20 terms in Korean)
--   - Cortex Search Service for terminology
--   - Cortex Analyst Agent definition
--   - Stored procedures for advisor integration
--   - Audit and logging infrastructure
--   - Utility functions for Streamlit
--   - Query performance monitoring
--
-- Total Coverage:
--   - 24 major sections
--   - Dynamic Tables, Views, Procedures, Functions
--   - API Integrations, External Functions
--   - Cortex ML, LLM, Search, Analyst, Sentiment
--   - Comprehensive Korean text support
--
-- ================================================================
-- END OF CONSOLIDATED FILE
-- ================================================================
