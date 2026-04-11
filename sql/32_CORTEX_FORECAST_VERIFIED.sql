-- ============================================================
-- 32_CORTEX_FORECAST_VERIFIED.sql
-- Cortex ML FORECAST + ANOMALY_DETECTION 실행 검증 통합본
-- 08번(주석) + 15번(활성) 불일치 해소
-- Date: 2026-04-11
-- ============================================================
--
-- 문제점 정리:
--   08번: FORECAST/ANOMALY 모두 주석 처리, 수동 대안만 활성
--   15번: FORECAST 활성이나 컬럼명(MONTH_DATE)이 08번(DATE_KEY)과 불일치
--   본 파일: 두 버전을 통합하여 실행 가능한 최종본 제공
--
-- 실행 순서:
--   1. V_FIRE_TIMESERIES_V2 (통합 시계열 뷰)
--   2. insure_fire_forecast_v2 (FORECAST 모델)
--   3. V_FIRE_FORECAST_V2 (예측 결과 뷰)
--   4. V_TRANSACTION_TIMESERIES_V2 (거래량 시계열)
--   5. insure_tx_anomaly_v2 (ANOMALY 모델)
--   6. V_TRANSACTION_ANOMALY_V2 (이상치 결과 뷰)
--   7. 검증 쿼리
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA ANALYTICS;

-- ============================================================
-- PART 1: CORTEX FORECAST - 화재 예측
-- ============================================================

-- 1.1 통합 시계열 뷰 (08번 DATE_KEY + 15번 MONTH_DATE 통합)
-- 구별 시계열(08번) + 단일 시계열(15번) 모두 지원
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_FIRE_TIMESERIES_V2 AS
SELECT
    DISTRICT_NAME,
    TO_DATE(YEAR::VARCHAR || '-07-01', 'YYYY-MM-DD') AS DATE_KEY,
    SUM(TOTAL_FIRES) AS FIRE_COUNT,
    SUM(BUILDING_FIRES) AS BUILDING_FIRE_COUNT,
    SUM(PROPERTY_DAMAGE_KRW) AS TOTAL_DAMAGE
FROM INSURE_DB.RAW_PUBLIC.FIRE_STATS
GROUP BY DISTRICT_NAME, YEAR
ORDER BY DISTRICT_NAME, DATE_KEY;

-- 1.2 FORECAST 모델 생성 (구별 시계열)
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST insure_fire_forecast_v2(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'INSURE_DB.ANALYTICS.V_FIRE_TIMESERIES_V2'),
    SERIES_COLNAME => 'DISTRICT_NAME',
    TIMESTAMP_COLNAME => 'DATE_KEY',
    TARGET_COLNAME => 'FIRE_COUNT',
    CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
);

-- 1.3 예측 결과 뷰 (2025-2026, 95% 신뢰구간)
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_FIRE_FORECAST_V2 AS
SELECT
    series AS DISTRICT_NAME,
    ts AS FORECAST_DATE,
    forecast AS PREDICTED_FIRE_COUNT,
    lower_bound AS CONFIDENCE_LOWER,
    upper_bound AS CONFIDENCE_UPPER,
    CASE
        WHEN forecast > (
            SELECT AVG(FIRE_COUNT) * 1.20
            FROM INSURE_DB.ANALYTICS.V_FIRE_TIMESERIES_V2
            WHERE DISTRICT_NAME = series
        ) THEN 'HIGH_RISK'
        ELSE 'NORMAL'
    END AS RISK_STATUS
FROM TABLE(insure_fire_forecast_v2!FORECAST(
    FORECASTING_PERIODS => 2,
    CONFIG_OBJECT => {'prediction_interval': 0.95}
));


-- ============================================================
-- PART 2: CORTEX ANOMALY_DETECTION - 이사 시즌 감지
-- ============================================================

-- 2.1 부동산 거래량 시계열 뷰
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_TRANSACTION_TIMESERIES_V2 AS
SELECT
    DISTRICT_NAME,
    TO_DATE(YEAR_MONTH || '01', 'YYYYMMDD') AS DATE_KEY,
    TOTAL_TRANSACTIONS,
    APT_SALES_COUNT,
    APT_JEONSE_COUNT
FROM INSURE_DB.RAW_PUBLIC.REAL_ESTATE_TRANSACTIONS
ORDER BY DISTRICT_NAME, DATE_KEY;

-- 2.2 ANOMALY_DETECTION 모델 생성
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION insure_tx_anomaly_v2(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'INSURE_DB.ANALYTICS.V_TRANSACTION_TIMESERIES_V2'),
    SERIES_COLNAME => 'DISTRICT_NAME',
    TIMESTAMP_COLNAME => 'DATE_KEY',
    TARGET_COLNAME => 'TOTAL_TRANSACTIONS',
    CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
);

-- 2.3 이상치 탐지 결과 뷰
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_TRANSACTION_ANOMALY_V2 AS
SELECT
    series AS DISTRICT_NAME,
    ts AS DATE_KEY,
    y AS ACTUAL_TRANSACTIONS,
    forecast AS EXPECTED_TRANSACTIONS,
    is_anomaly,
    percentile,
    distance,
    CASE
        WHEN is_anomaly = TRUE AND y > forecast THEN 'SURGE_MOVING_SEASON'
        WHEN is_anomaly = TRUE AND y < forecast THEN 'DROP_OFF_SEASON'
        ELSE 'NORMAL'
    END AS ANOMALY_TYPE
FROM TABLE(insure_tx_anomaly_v2!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'INSURE_DB.ANALYTICS.V_TRANSACTION_TIMESERIES_V2'),
    SERIES_COLNAME => 'DISTRICT_NAME',
    TIMESTAMP_COLNAME => 'DATE_KEY',
    TARGET_COLNAME => 'TOTAL_TRANSACTIONS',
    CONFIG_OBJECT => {'prediction_interval': 0.99}
));


-- ============================================================
-- PART 3: 08번 수동 대안 유지 (FORECAST 실패 시 fallback)
-- ============================================================
-- 08번의 V_FIRE_FORECAST_MANUAL, V_TRANSACTION_ANOMALY_MANUAL은
-- Cortex ML 미지원 환경에서 fallback으로 사용 가능.
-- 별도 수정 불필요.


-- ============================================================
-- PART 4: 실행 검증 쿼리
-- ============================================================

-- 4.1 FORECAST 모델 존재 확인
SHOW SNOWFLAKE.ML.FORECAST LIKE 'insure_fire_forecast_v2' IN SCHEMA INSURE_DB.ANALYTICS;

-- 4.2 예측 결과 확인 (상위 10건)
SELECT * FROM INSURE_DB.ANALYTICS.V_FIRE_FORECAST_V2 LIMIT 10;

-- 4.3 ANOMALY 모델 존재 확인
SHOW SNOWFLAKE.ML.ANOMALY_DETECTION LIKE 'insure_tx_anomaly_v2' IN SCHEMA INSURE_DB.ANALYTICS;

-- 4.4 이상치 탐지 결과 확인
SELECT * FROM INSURE_DB.ANALYTICS.V_TRANSACTION_ANOMALY_V2
WHERE is_anomaly = TRUE
ORDER BY DATE_KEY DESC
LIMIT 10;

-- 4.5 통합 상태 확인
SELECT 'FORECAST_VIEW' AS component, COUNT(*) AS rows FROM INSURE_DB.ANALYTICS.V_FIRE_TIMESERIES_V2
UNION ALL
SELECT 'ANOMALY_VIEW', COUNT(*) FROM INSURE_DB.ANALYTICS.V_TRANSACTION_TIMESERIES_V2;

SELECT '32_CORTEX_FORECAST_VERIFIED: Complete' AS status;
