-- ============================================================================
-- File: 20_V1.5_SNOWFLAKE_FEATURES.sql
-- Purpose: INSURE Dynamic Insurance Engine - Snowflake Native Features
-- Project: Snowflake Hackathon - Dynamic Insurance Product Adaptation
-- Author: INSURE Development Team
-- Version: 1.5
-- Date: 2026-04-06
-- ============================================================================
-- OVERVIEW:
-- This script implements advanced Snowflake features to replace basic views with
-- Dynamic Tables, fix the RAND() non-deterministic bug in risk classification,
-- and add Cortex ML/LLM capabilities for forecasting and personalization.
--
-- KEY COMPONENTS:
-- 1. Dynamic Tables (replacing views) with hourly refresh
-- 2. Deterministic risk classification based on composite risk scores
-- 3. Credit factor dynamic mapping from customer segments
-- 4. Cortex ML time-series forecasting for fire incidents
-- 5. Cortex LLM for personalized insurance descriptions
-- 6. Cortex AI sentiment analysis in feedback processing
-- 7. Alerts for high-risk districts with timezone support
-- ============================================================================

USE DATABASE INSURE_DB;
USE WAREHOUSE COMPUTE_WH;

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
        THEN '\uC704\uD5D8'  -- Korean: "위험" (Risk)
        ELSE '\uC815\uC0C1'  -- Korean: "정상" (Normal)
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
        WHEN sentiment_score > 0.5 THEN '\uB9CC\uC871'      -- Korean: "만족" (Satisfied)
        WHEN sentiment_score > -0.5 THEN '\uBCF4\uD1B5'     -- Korean: "보통" (Neutral)
        ELSE '\uBD88\uB9CC'                                 -- Korean: "불만" (Dissatisfied)
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
        '\uACE0\uC9C0\uC601\uC5ED_\uC704\uD5D8_\uC54C\uB9BC',  -- Korean: "고지영역_위험_알림" (High-Risk District Alert)
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

-- ============================================================================
-- SECTION 8: SUMMARY OF CHANGES
-- ============================================================================
-- IMPLEMENTATION SUMMARY:
--
-- 1. DYNAMIC TABLES (Sections 1.1-1.3):
--    - INT_PURE_PREMIUM: Calculates base premium from loss + district + market
--    - INT_EXPERIENCE_RATING: Applies credibility-weighted experience premium
--    - INT_RISK_ADJUSTED_PREMIUM: CRITICAL FIX - Deterministic risk classification
--      * Replaced RAND() with composite_risk_score mapping
--      * 8 risk classes (A++ to D) based on score bands
--    - All refresh hourly via TARGET_LAG = '1 hour'
--
-- 2. CREDIT FACTOR DYNAMIC (Section 2):
--    - MART_ACTUARIAL_PREMIUM_V14 updated with credit score bands
--    - 5 credit tiers (0.85 to 1.15) instead of hardcoded 0.95
--    - Sourced from INT_SEGMENT_CLASSIFICATION.CREDIT_SCORE_AVG
--
-- 3. CORTEX ML FORECASTING (Section 3):
--    - V_FIRE_TIMESERIES: Foundation view with lag columns (1-month, 12-month)
--    - insure_fire_forecast: Time-series model predicting fire incidents
--    - V_FIRE_FORECAST_OUTPUT: Predictions with confidence bounds and risk flags
--
-- 4. CORTEX LLM (Section 4):
--    - SP_GENERATE_INSURANCE_DESCRIPTION: Stored procedure using mistral-large2
--    - Generates personalized product descriptions per persona
--    - Accepts persona_id, type, and risk profile as inputs
--
-- 5. CORTEX SENTIMENT (Section 5):
--    - INT_FEEDBACK_SENTIMENT: Dynamic table with auto-sentiment scoring
--    - SNOWFLAKE.CORTEX.SENTIMENT() on customer feedback
--    - Classifications: \uB9CC\uC871 (Satisfied), \uBCF4\uD1B5 (Neutral), \uBD88\uB9CC (Dissatisfied)
--
-- 6. ALERTS (Section 6):
--    - ALERT_HIGH_RISK_DISTRICT: Daily trigger at 09:00 Asia/Seoul
--    - Detects composite_risk_score > 80 in current year
--    - Logs to ANALYTICS.ALERT_LOG with affected districts array
--
-- 7. VALIDATION (Section 7):
--    - V_DYNAMIC_TABLE_STATUS: Monitor all DT row counts and last refresh times
--
-- PERFORMANCE IMPACT:
--    - Dynamic Tables provide 1-hour SLA for downstream dependencies
--    - Cortex features run on-demand (no persistent model storage)
--    - Alert runs 1x daily (minimal compute impact)
--    - All queries target COMPUTE_WH for isolated performance
--
-- KOREAN TEXT ENCODING:
--    All Korean text uses \uXXXX unicode escapes for cross-region compatibility
--    Examples:
--      \u00C704\u00D5D8 = 위험 (Risk/Danger)
--      \u00C815\u00C0C1 = 정상 (Normal/OK)
--      \u00B9CC\u00C871 = 만족 (Satisfied)
--      \u00BDC4\u00D1B5 = 보통 (Neutral)
--      \u00BD88\u00B9CC = 불만 (Dissatisfied)
--      \u00ACE0\u00C9C0\u00C601\u00C5ED_\u00C704\u00D5D8_\u00C54C\u00B9BC = 고지영역_위험_알림 (District Risk Alert)
--
-- ============================================================================
-- END OF FILE
-- ============================================================================
