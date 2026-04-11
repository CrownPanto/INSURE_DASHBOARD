-- ============================================================
-- 25_EXPAND_REGION_ALL_MONTHS.sql
-- 모든 YEAR_MONTH에 서울 25개 구 데이터 확장
--
-- [문제]
-- 24번 실행 후 MART_DISTRICT_INSURANCE_SUMMARY에서
-- YEAR_MONTH='202512'만 25개 구가 존재하고,
-- 나머지 월에는 실제 데이터가 있는 3개 구만 존재
--
-- [원인]
-- missing_gu CTE에서 YEAR_MONTH='202512'를 하드코딩
-- → 다른 월의 누락 구가 보충되지 않음
--
-- [해결]
-- missing_gu를 모든 YEAR_MONTH × 25개 구 조합으로 확장
-- → 실제 데이터가 없는 구+월 조합에 서울 평균 기반 추정치 삽입
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE INSURE_DB;
USE SCHEMA MART;


-- ============================================================
-- STEP 0: 현재 상태 진단
-- ============================================================

-- 0-1) YEAR_MONTH별 구 수 확인 (3개만 나오는 월 확인)
SELECT YEAR_MONTH, COUNT(DISTINCT GU_NAME) AS gu_count
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY YEAR_MONTH
ORDER BY YEAR_MONTH;

-- 0-2) 실제 데이터가 있는 구 목록 확인
SELECT DISTINCT GU_NAME
FROM MART_DISTRICT_INSURANCE_SUMMARY
WHERE YEAR_MONTH != '202512'
ORDER BY GU_NAME;


-- ============================================================
-- STEP 1: MART_DISTRICT_INSURANCE_SUMMARY 재구축
--         (모든 YEAR_MONTH에 25개 구 보장)
-- ============================================================

CREATE OR REPLACE TABLE MART_DISTRICT_INSURANCE_SUMMARY AS
WITH
-- (A) 실제 설계 데이터를 구 단위로 집계
real_data AS (
    SELECT
        m.DISTRICT_CODE,
        dm.DISTRICT_KOR_NAME AS DISTRICT_NAME,
        COALESCE(g.GU_NAME, dm.CITY_KOR_NAME) AS GU_NAME,
        m.YEAR_MONTH,
        COUNT(DISTINCT m.COMPOSITE_SEGMENT) AS ACTIVE_SEGMENTS,
        SUM(m.POPULATION) AS TOTAL_POPULATION,
        AVG(m.AVG_INCOME) AS DISTRICT_AVG_INCOME,
        AVG(m.AVG_ASSET) AS DISTRICT_AVG_ASSET,
        AVG(m.ESTIMATED_MOVABLE_ASSET_VALUE) AS AVG_MOVABLE_ASSET,
        MEDIAN(m.BASE_PREMIUM_MONTHLY) AS AVG_BASE_PREMIUM,
        AVG(m.AVG_CREDIT) AS AVG_CREDIT_SCORE
    FROM INSURE_DB.MART.MART_INSURANCE_DESIGN m
    LEFT JOIN INSURE_DB.STAGING.STG_DISTRICT_MASTER dm ON m.DISTRICT_CODE = dm.DISTRICT_CODE
    LEFT JOIN INSURE_DB.STAGING.GU_CODE_MAPPING g ON LEFT(m.DISTRICT_CODE::VARCHAR, 5) = g.GU_CODE
    GROUP BY m.DISTRICT_CODE, dm.DISTRICT_KOR_NAME, COALESCE(g.GU_NAME, dm.CITY_KOR_NAME), m.YEAR_MONTH
),

-- (B) 서울 전체 통계 (YEAR_MONTH별로 계산 → 월별 추정치가 해당 월 실데이터 기반)
seoul_avg_by_month AS (
    SELECT
        YEAR_MONTH,
        AVG(DISTRICT_AVG_INCOME) AS avg_income,
        AVG(DISTRICT_AVG_ASSET) AS avg_asset,
        AVG(AVG_MOVABLE_ASSET) AS avg_movable,
        MEDIAN(AVG_BASE_PREMIUM) AS avg_premium,
        AVG(AVG_CREDIT_SCORE) AS avg_credit
    FROM real_data
    WHERE GU_NAME IS NOT NULL
    GROUP BY YEAR_MONTH
),

-- (C) 전체 YEAR_MONTH 목록
all_months AS (
    SELECT DISTINCT YEAR_MONTH FROM real_data WHERE YEAR_MONTH IS NOT NULL
),

-- (D) ★ 핵심 수정: 25개 구 × 모든 YEAR_MONTH 전체 조합 생성
full_grid AS (
    SELECT g.GU_NAME, am.YEAR_MONTH
    FROM INSURE_DB.STAGING.GU_CODE_MAPPING g
    CROSS JOIN all_months am
),

-- (E) 실제 데이터가 있는 구+월 조합
covered AS (
    SELECT DISTINCT GU_NAME, YEAR_MONTH
    FROM real_data
    WHERE GU_NAME IS NOT NULL
),

-- (F) ★ 핵심 수정: 누락된 구+월 조합 (모든 월에 대해)
missing_gu_months AS (
    SELECT fg.GU_NAME, fg.YEAR_MONTH
    FROM full_grid fg
    LEFT JOIN covered c ON fg.GU_NAME = c.GU_NAME AND fg.YEAR_MONTH = c.YEAR_MONTH
    WHERE c.GU_NAME IS NULL
),

-- (G) 인구 추정 (구 단위)
est_pop AS (
    SELECT dm.CITY_KOR_NAME AS GU_NAME,
           COUNT(DISTINCT dm.DISTRICT_CODE) * 8500 AS EST_POPULATION
    FROM INSURE_DB.STAGING.STG_DISTRICT_MASTER dm
    WHERE dm.PROVINCE_KOR_NAME = '서울특별시'
    GROUP BY dm.CITY_KOR_NAME
),

-- (H) 누락 구+월에 대한 추정 데이터
estimated_data AS (
    SELECT
        NULL AS DISTRICT_CODE,
        mg.GU_NAME AS DISTRICT_NAME,
        mg.GU_NAME,
        mg.YEAR_MONTH,
        5 AS ACTIVE_SEGMENTS,
        COALESCE(ep.EST_POPULATION, 80000) AS TOTAL_POPULATION,
        sa.avg_income AS DISTRICT_AVG_INCOME,
        sa.avg_asset AS DISTRICT_AVG_ASSET,
        sa.avg_movable AS AVG_MOVABLE_ASSET,
        sa.avg_premium AS AVG_BASE_PREMIUM,
        sa.avg_credit AS AVG_CREDIT_SCORE
    FROM missing_gu_months mg
    -- ★ 월별 서울 평균으로 JOIN (해당 월의 실데이터 기반 추정)
    JOIN seoul_avg_by_month sa ON mg.YEAR_MONTH = sa.YEAR_MONTH
    LEFT JOIN est_pop ep ON mg.GU_NAME = ep.GU_NAME
),

-- (I) 전체 구 통합 (실제 + 추정)
all_districts AS (
    SELECT * FROM real_data WHERE GU_NAME IS NOT NULL
    UNION ALL
    SELECT * FROM estimated_data
),

-- (J) 리스크: 가장 최근 연도 매칭
risk AS (
    SELECT
        TRIM(DISTRICT_NAME) AS DISTRICT_NAME,
        YEAR,
        COMPOSITE_RISK_SCORE,
        RISK_GRADE,
        FIRE_RISK_SCORE,
        THEFT_RISK_SCORE,
        BUILDING_RISK_SCORE,
        WEATHER_RISK_SCORE,
        ROW_NUMBER() OVER (PARTITION BY TRIM(DISTRICT_NAME) ORDER BY YEAR DESC) AS rn
    FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE
),
latest_risk AS (
    SELECT * FROM risk WHERE rn = 1
),

-- (K) 아파트 가격
apt_price AS (
    SELECT SGG AS GU_NAME,
        ROUND(AVG(SALE_PRICE_PER_PYEONG), 0) AS AVG_SALE_PRICE_PYEONG,
        ROUND(AVG(JEONSE_PRICE_PER_PYEONG), 0) AS AVG_JEONSE_PRICE_PYEONG
    FROM INSURE_DB.STAGING.STG_APT_PRICE
    GROUP BY SGG
),
seoul_apt_avg AS (
    SELECT ROUND(AVG(SALE_PRICE_PER_PYEONG), 0) AS avg_sale,
           ROUND(AVG(JEONSE_PRICE_PER_PYEONG), 0) AS avg_jeonse
    FROM INSURE_DB.STAGING.STG_APT_PRICE
),

-- (L) 보험료 IQR 기반 상한/하한 (월별로 계산)
premium_bounds AS (
    SELECT
        YEAR_MONTH,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY AVG_BASE_PREMIUM) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY AVG_BASE_PREMIUM) AS q3
    FROM all_districts
    GROUP BY YEAR_MONTH
),

-- (M) 최종 조합
assembled AS (
    SELECT
        d.DISTRICT_CODE, d.DISTRICT_NAME, d.GU_NAME, d.YEAR_MONTH,
        d.ACTIVE_SEGMENTS, d.TOTAL_POPULATION,
        d.DISTRICT_AVG_INCOME, d.DISTRICT_AVG_ASSET,
        d.AVG_MOVABLE_ASSET, d.AVG_BASE_PREMIUM, d.AVG_CREDIT_SCORE,
        COALESCE(lr.COMPOSITE_RISK_SCORE, 30) AS COMPOSITE_RISK_SCORE,
        COALESCE(lr.RISK_GRADE, '미산정') AS RISK_GRADE,
        COALESCE(lr.FIRE_RISK_SCORE, 0) AS FIRE_RISK_SCORE,
        COALESCE(lr.THEFT_RISK_SCORE, 0) AS THEFT_RISK_SCORE,
        COALESCE(lr.BUILDING_RISK_SCORE, 0) AS BUILDING_RISK_SCORE,
        COALESCE(lr.WEATHER_RISK_SCORE, 0) AS WEATHER_RISK_SCORE,
        COALESCE(ap.AVG_SALE_PRICE_PYEONG, sa.avg_sale) AS AVG_SALE_PRICE_PYEONG,
        COALESCE(ap.AVG_JEONSE_PRICE_PYEONG, sa.avg_jeonse) AS AVG_JEONSE_PRICE_PYEONG,
        -- IQR 클램핑 (월별 IQR 적용)
        ROUND(
            LEAST(
                GREATEST(d.AVG_BASE_PREMIUM, pb.q1 - 1.5 * (pb.q3 - pb.q1)),
                pb.q3 + 1.5 * (pb.q3 - pb.q1)
            )
            * (1 + COALESCE(lr.COMPOSITE_RISK_SCORE, 30) / 200.0)
            * CASE
                WHEN d.AVG_CREDIT_SCORE >= 800 THEN 0.90
                WHEN d.AVG_CREDIT_SCORE >= 700 THEN 0.95
                ELSE 1.05
              END
        , 0) AS ADJUSTED_PREMIUM_MONTHLY,
        ROUND(d.TOTAL_POPULATION * 0.15 * d.AVG_BASE_PREMIUM * 12, 0) AS ESTIMATED_ANNUAL_MARKET_KRW
    FROM all_districts d
    LEFT JOIN latest_risk lr ON TRIM(d.GU_NAME) = lr.DISTRICT_NAME
    LEFT JOIN apt_price ap ON TRIM(d.GU_NAME) = TRIM(ap.GU_NAME)
    CROSS JOIN seoul_apt_avg sa
    -- ★ 월별 IQR JOIN
    LEFT JOIN premium_bounds pb ON d.YEAR_MONTH = pb.YEAR_MONTH
    WHERE d.GU_NAME IS NOT NULL
)
SELECT * FROM assembled;


-- ============================================================
-- STEP 2: MART_PREMIUM_SIMULATION 뷰 재생성
-- ============================================================

CREATE OR REPLACE VIEW MART_PREMIUM_SIMULATION AS
SELECT d.*,
    ROUND(d.ADJUSTED_PREMIUM_MONTHLY * 0.5, 0) AS PREMIUM_50PCT,
    ROUND(d.ADJUSTED_PREMIUM_MONTHLY * 0.8, 0) AS PREMIUM_80PCT,
    d.ADJUSTED_PREMIUM_MONTHLY AS PREMIUM_100PCT,
    d.ADJUSTED_PREMIUM_MONTHLY * 12 AS ANNUAL_PREMIUM
FROM MART_DISTRICT_INSURANCE_SUMMARY d
WHERE d.YEAR_MONTH IS NOT NULL;


-- ============================================================
-- STEP 3: 검증 쿼리
-- ============================================================

-- 3-1) ★ 핵심 검증: YEAR_MONTH별 구 수 (모두 25개여야 함)
SELECT
    YEAR_MONTH,
    COUNT(DISTINCT GU_NAME) AS gu_count,
    ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY), 0) AS avg_premium,
    ROUND(MIN(ADJUSTED_PREMIUM_MONTHLY), 0) AS min_premium,
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY), 0) AS max_premium
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY YEAR_MONTH
ORDER BY YEAR_MONTH;

-- 3-2) 전체 요약
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT YEAR_MONTH) AS distinct_months,
    COUNT(DISTINCT GU_NAME) AS distinct_gu,
    ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY), 0) AS avg_premium,
    ROUND(MIN(ADJUSTED_PREMIUM_MONTHLY), 0) AS min_premium,
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY), 0) AS max_premium,
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY) / NULLIF(MIN(ADJUSTED_PREMIUM_MONTHLY), 0), 1) AS max_min_ratio
FROM MART_DISTRICT_INSURANCE_SUMMARY;

-- 3-3) 실제 vs 추정 데이터 비율 확인
SELECT
    YEAR_MONTH,
    SUM(CASE WHEN DISTRICT_CODE IS NOT NULL THEN 1 ELSE 0 END) AS real_data_count,
    SUM(CASE WHEN DISTRICT_CODE IS NULL THEN 1 ELSE 0 END) AS estimated_count,
    COUNT(*) AS total
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY YEAR_MONTH
ORDER BY YEAR_MONTH;

-- 3-4) 동일값 검증 (같은 보험료를 가진 구가 3개 이상이면 문제)
SELECT
    YEAR_MONTH,
    ADJUSTED_PREMIUM_MONTHLY AS premium,
    COUNT(*) AS gu_count,
    LISTAGG(GU_NAME, ', ') WITHIN GROUP (ORDER BY GU_NAME) AS gu_list
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY YEAR_MONTH, ADJUSTED_PREMIUM_MONTHLY
HAVING COUNT(*) >= 5
ORDER BY YEAR_MONTH, gu_count DESC;

-- 3-5) 리스크 JOIN 성공 여부
SELECT
    GU_NAME,
    RISK_GRADE,
    COMPOSITE_RISK_SCORE,
    CASE WHEN RISK_GRADE = '미산정' THEN '❌ JOIN 실패' ELSE '✅ 정상' END AS join_status
FROM MART_DISTRICT_INSURANCE_SUMMARY
WHERE YEAR_MONTH = (SELECT MAX(YEAR_MONTH) FROM MART_DISTRICT_INSURANCE_SUMMARY)
ORDER BY GU_NAME;

SELECT '✅ 25_EXPAND_REGION_ALL_MONTHS.sql 실행 완료' AS status;
