-- ============================================================
-- INSURE MART: 성별 × 연령대 × 구 교차 상관분석용 뷰
-- 기존 파이프라인 무영향 — VIEW만 추가
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE INSURE_DB;
USE SCHEMA MART;

-- ─────────────────────────────────────────────
-- MART_GENDER_AGE_CORRELATION
-- 목적: 상관분석에 성별·연령 변수를 추가하기 위한 교차 집계 뷰
-- 소스: INT_SEGMENT_CLASSIFICATION + INT_DISTRICT_RISK_SCORE
-- 결과: ~500 데이터 포인트 (25구 × 2성별 × 10연령대)
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW MART_GENDER_AGE_CORRELATION AS
WITH base AS (
    SELECT
        seg.DISTRICT_CODE,
        g.GU_NAME,
        seg.GENDER,
        seg.AGE_GROUP,
        seg.YEAR_MONTH,
        seg.SEGMENT_A,
        seg.SEGMENT_B,
        seg.SEGMENT_E,
        SUM(seg.CUSTOMER_COUNT)              AS POPULATION,
        AVG(seg.MEDIAN_INCOME)               AS AVG_INCOME,
        AVG(seg.AVERAGE_ASSET_AMOUNT)        AS AVG_ASSET,
        AVG(seg.CREDIT_SCORE_AVG)            AS AVG_CREDIT,
        AVG(seg.TOTAL_USAGE_AMOUNT)          AS AVG_SPEND,
        AVG(seg.INSTALLMENT_AMOUNT)          AS AVG_INSTALLMENT,
        AVG(seg.ABROAD_SPEND_AMOUNT)         AS AVG_ABROAD,
        -- 추정 동산 가치 (기존 MART_INSURANCE_DESIGN 로직 동일)
        ROUND(
            AVG(seg.AVERAGE_ASSET_AMOUNT) * 0.15
            + AVG(seg.MEDIAN_INCOME) * 0.08
            + COALESCE(AVG(seg.INSTALLMENT_AMOUNT), 0) * 12 * 2
        , 0) AS ESTIMATED_MOVABLE_VALUE,
        -- 기본 보험료 (리스크 프로파일 반영)
        ROUND(
            (AVG(seg.AVERAGE_ASSET_AMOUNT) * 0.15
             + AVG(seg.MEDIAN_INCOME) * 0.08
             + COALESCE(AVG(seg.INSTALLMENT_AMOUNT), 0) * 12 * 2)
            * CASE
                WHEN seg.SEGMENT_E = 'E1_저위험안정' THEN 0.003
                WHEN seg.SEGMENT_E = 'E2_중위험표준' THEN 0.005
                WHEN seg.SEGMENT_E = 'E3_고위험집중' THEN 0.008
                ELSE 0.005
              END
        , 0) AS BASE_PREMIUM
    FROM INSURE_DB.INTERMEDIATE.INT_SEGMENT_CLASSIFICATION seg
    LEFT JOIN INSURE_DB.STAGING.GU_CODE_MAPPING g
        ON LEFT(seg.DISTRICT_CODE::VARCHAR, 5) = g.GU_CODE
    GROUP BY
        seg.DISTRICT_CODE, g.GU_NAME, seg.GENDER,
        seg.AGE_GROUP, seg.YEAR_MONTH,
        seg.SEGMENT_A, seg.SEGMENT_B, seg.SEGMENT_E
),

-- 구별 리스크 (최신 연도만)
latest_risk AS (
    SELECT
        TRIM(DISTRICT_NAME) AS GU_NAME,
        COMPOSITE_RISK_SCORE,
        FIRE_RISK_SCORE,
        THEFT_RISK_SCORE,
        BUILDING_RISK_SCORE,
        WEATHER_RISK_SCORE,
        SAFETY_INFRA_SCORE,
        CCTV_SECURITY_SCORE
    FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY TRIM(DISTRICT_NAME) ORDER BY YEAR DESC
    ) = 1
),

-- IQR 기반 이상값 경계 (기존 MART 로직 동일)
premium_bounds AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY BASE_PREMIUM) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY BASE_PREMIUM) AS q3
    FROM base
    WHERE BASE_PREMIUM > 0
)

SELECT
    b.DISTRICT_CODE,
    b.GU_NAME,
    b.GENDER,
    b.AGE_GROUP,
    b.YEAR_MONTH,
    b.SEGMENT_A,
    b.SEGMENT_B,
    b.SEGMENT_E,
    b.POPULATION,
    b.AVG_INCOME,
    b.AVG_ASSET,
    b.AVG_CREDIT,
    b.AVG_SPEND,
    b.AVG_INSTALLMENT,
    b.AVG_ABROAD,
    b.ESTIMATED_MOVABLE_VALUE,
    b.BASE_PREMIUM,

    -- 리스크 스코어 (구 단위 JOIN)
    COALESCE(r.COMPOSITE_RISK_SCORE, 30)    AS COMPOSITE_RISK_SCORE,
    COALESCE(r.FIRE_RISK_SCORE, 0)          AS FIRE_RISK_SCORE,
    COALESCE(r.THEFT_RISK_SCORE, 0)         AS THEFT_RISK_SCORE,
    COALESCE(r.BUILDING_RISK_SCORE, 0)      AS BUILDING_RISK_SCORE,
    COALESCE(r.WEATHER_RISK_SCORE, 0)       AS WEATHER_RISK_SCORE,
    COALESCE(r.SAFETY_INFRA_SCORE, 0)       AS SAFETY_INFRA_SCORE,
    COALESCE(r.CCTV_SECURITY_SCORE, 0)      AS CCTV_SECURITY_SCORE,

    -- ★ 조정 보험료 (IQR 클램핑 + 리스크 + 신용 보정, 기존 MART 로직 동일)
    ROUND(
        LEAST(
            GREATEST(b.BASE_PREMIUM, pb.q1 - 1.5 * (pb.q3 - pb.q1)),
            pb.q3 + 1.5 * (pb.q3 - pb.q1)
        )
        * (1 + COALESCE(r.COMPOSITE_RISK_SCORE, 30) / 200.0)
        * CASE
            WHEN b.AVG_CREDIT >= 850 THEN 0.85
            WHEN b.AVG_CREDIT >= 750 THEN 0.95
            WHEN b.AVG_CREDIT >= 650 THEN 1.00
            WHEN b.AVG_CREDIT >= 550 THEN 1.10
            ELSE 1.25
          END
    , 0) AS ADJUSTED_PREMIUM,

    -- ★ 연령 수치화 (피어슨 상관분석용)
    CASE
        WHEN b.AGE_GROUP = '20_24'   THEN 22
        WHEN b.AGE_GROUP = '25_29'   THEN 27
        WHEN b.AGE_GROUP = '30_34'   THEN 32
        WHEN b.AGE_GROUP = '35_39'   THEN 37
        WHEN b.AGE_GROUP = '40_44'   THEN 42
        WHEN b.AGE_GROUP = '45_49'   THEN 47
        WHEN b.AGE_GROUP = '50_54'   THEN 52
        WHEN b.AGE_GROUP = '55_59'   THEN 57
        WHEN b.AGE_GROUP = '60_64'   THEN 62
        WHEN b.AGE_GROUP = '65_69'   THEN 67
        WHEN b.AGE_GROUP = '70_74'   THEN 72
        WHEN b.AGE_GROUP = '75_OVER' THEN 78
        ELSE 40
    END AS AGE_NUMERIC,

    -- ★ 성별 수치화 (포인트 바이시리얼 상관분석용)
    CASE WHEN b.GENDER = 'M' THEN 1 ELSE 0 END AS GENDER_NUMERIC

FROM base b
LEFT JOIN latest_risk r ON TRIM(b.GU_NAME) = r.GU_NAME
CROSS JOIN premium_bounds pb
WHERE b.GU_NAME IS NOT NULL;


-- ─────────────────────────────────────────────
-- 검증 쿼리
-- ─────────────────────────────────────────────

-- 1) 데이터 포인트 수 확인 (목표: ~500)
SELECT
    COUNT(*)                                    AS TOTAL_ROWS,
    COUNT(DISTINCT GU_NAME)                     AS DISTINCT_GU,
    COUNT(DISTINCT GENDER)                      AS DISTINCT_GENDER,
    COUNT(DISTINCT AGE_GROUP)                   AS DISTINCT_AGE_GROUP,
    COUNT(DISTINCT GU_NAME || GENDER || AGE_GROUP) AS CROSS_COMBINATIONS,
    MIN(POPULATION)                             AS MIN_POP,
    AVG(POPULATION)                             AS AVG_POP,
    MAX(POPULATION)                             AS MAX_POP
FROM MART_GENDER_AGE_CORRELATION
WHERE YEAR_MONTH = (SELECT MAX(YEAR_MONTH) FROM MART_GENDER_AGE_CORRELATION);

-- 2) 성별 × 연령 분포 균형 확인
SELECT
    GENDER,
    AGE_GROUP,
    COUNT(DISTINCT GU_NAME) AS GU_COUNT,
    SUM(POPULATION) AS TOTAL_POP,
    ROUND(AVG(ADJUSTED_PREMIUM), 0) AS AVG_PREMIUM,
    ROUND(AVG(AVG_INCOME), 0) AS AVG_INCOME
FROM MART_GENDER_AGE_CORRELATION
WHERE YEAR_MONTH = (SELECT MAX(YEAR_MONTH) FROM MART_GENDER_AGE_CORRELATION)
GROUP BY GENDER, AGE_GROUP
ORDER BY GENDER, AGE_GROUP;

-- 3) 상관계수 프리뷰 (Snowflake CORR 함수 사용)
SELECT
    'AGE vs PREMIUM'        AS PAIR, ROUND(CORR(AGE_NUMERIC, ADJUSTED_PREMIUM), 3)        AS CORRELATION UNION ALL
SELECT
    'GENDER vs PREMIUM',                ROUND(CORR(GENDER_NUMERIC, ADJUSTED_PREMIUM), 3)              UNION ALL
SELECT
    'INCOME vs PREMIUM',                ROUND(CORR(AVG_INCOME, ADJUSTED_PREMIUM), 3)                  UNION ALL
SELECT
    'ASSET vs PREMIUM',                 ROUND(CORR(AVG_ASSET, ADJUSTED_PREMIUM), 3)                   UNION ALL
SELECT
    'CREDIT vs PREMIUM',                ROUND(CORR(AVG_CREDIT, ADJUSTED_PREMIUM), 3)                  UNION ALL
SELECT
    'RISK vs PREMIUM',                  ROUND(CORR(COMPOSITE_RISK_SCORE, ADJUSTED_PREMIUM), 3)        UNION ALL
SELECT
    'AGE vs INCOME',                    ROUND(CORR(AGE_NUMERIC, AVG_INCOME), 3)                       UNION ALL
SELECT
    'AGE vs ASSET',                     ROUND(CORR(AGE_NUMERIC, AVG_ASSET), 3)                        UNION ALL
SELECT
    'AGE vs RISK',                      ROUND(CORR(AGE_NUMERIC, COMPOSITE_RISK_SCORE), 3)
FROM MART_GENDER_AGE_CORRELATION
WHERE YEAR_MONTH = (SELECT MAX(YEAR_MONTH) FROM MART_GENDER_AGE_CORRELATION)
  AND POPULATION > 50;  -- 통계적 노이즈 필터

-- 4) NULL 비율 체크
SELECT
    COUNT(*) AS TOTAL,
    SUM(CASE WHEN GU_NAME IS NULL THEN 1 ELSE 0 END) AS NULL_GU,
    SUM(CASE WHEN GENDER IS NULL THEN 1 ELSE 0 END) AS NULL_GENDER,
    SUM(CASE WHEN AGE_GROUP IS NULL THEN 1 ELSE 0 END) AS NULL_AGE,
    SUM(CASE WHEN ADJUSTED_PREMIUM IS NULL OR ADJUSTED_PREMIUM = 0 THEN 1 ELSE 0 END) AS NULL_OR_ZERO_PREMIUM,
    SUM(CASE WHEN COMPOSITE_RISK_SCORE IS NULL THEN 1 ELSE 0 END) AS NULL_RISK
FROM MART_GENDER_AGE_CORRELATION;

SELECT 'MART_GENDER_AGE_CORRELATION created — run validation queries above' AS STATUS;
