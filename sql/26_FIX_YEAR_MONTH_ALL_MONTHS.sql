-- ============================================================
-- 26_FIX_YEAR_MONTH_ALL_MONTHS.sql
-- 기준년월 셀렉터 202512만 표시되는 문제 수정
--
-- [증상]
-- 대시보드 사이드바 기준 년월 셀렉터에 202512만 표시됨
-- 원래 202101 부터 여러 달이 표시되어야 함
--
-- [원인]
-- MART_DISTRICT_INSURANCE_SUMMARY가 재생성될 때
-- 소스(MART_INSURANCE_DESIGN)에 202512 데이터만 있었거나
-- 파이프라인 재구축 중 데이터 손실 발생
--
-- [보험료 공식]
-- 선형 공식 (1 + risk/200.0) 유지
-- utils.py, 06_DBT_MART.sql, 24_FIX_PREMIUM_DATA.sql 모두 동일하게 통일
--
-- [실행 순서]
-- STEP 0: 진단 쿼리 → 어느 레벨에서 데이터가 끊겼는지 확인
-- STEP 1: MART_INSURANCE_DESIGN 재구축 (필요시)
-- STEP 2: MART_DISTRICT_INSURANCE_SUMMARY 완전 재구축 (전체월 × 25구)
-- STEP 3: MART_PREMIUM_SIMULATION 뷰 재생성
-- STEP 4: 검증
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE INSURE_DB;


-- ============================================================
-- STEP 0: 진단 쿼리 (먼저 실행해서 어느 단계에서 끊겼는지 확인)
-- ============================================================

-- 0-1) INT_SEGMENT_CLASSIFICATION: 월별 데이터 존재 여부
SELECT
    YEAR_MONTH,
    COUNT(DISTINCT DISTRICT_CODE) AS district_count,
    SUM(CUSTOMER_COUNT) AS total_customers
FROM INSURE_DB.INTERMEDIATE.INT_SEGMENT_CLASSIFICATION
GROUP BY YEAR_MONTH
ORDER BY YEAR_MONTH;

-- 0-2) MART_INSURANCE_DESIGN: 월별 데이터 존재 여부
SELECT
    YEAR_MONTH,
    COUNT(*) AS row_count,
    COUNT(DISTINCT DISTRICT_CODE) AS district_count
FROM INSURE_DB.MART.MART_INSURANCE_DESIGN
GROUP BY YEAR_MONTH
ORDER BY YEAR_MONTH;

-- 0-3) MART_DISTRICT_INSURANCE_SUMMARY: 현재 상태 확인
SELECT
    YEAR_MONTH,
    COUNT(DISTINCT GU_NAME) AS gu_count
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY YEAR_MONTH
ORDER BY YEAR_MONTH;


-- ============================================================
-- STEP 1: MART_INSURANCE_DESIGN 재구축
-- (STEP 0에서 INT_SEGMENT_CLASSIFICATION은 여러 달인데
--  MART_INSURANCE_DESIGN은 202512만 있는 경우에만 필요)
-- ============================================================

USE SCHEMA MART;

CREATE OR REPLACE TABLE MART_INSURANCE_DESIGN AS
WITH segment_stats AS (
    SELECT
        DISTRICT_CODE,
        YEAR_MONTH,
        SEGMENT_A,
        SEGMENT_B,
        SEGMENT_C,
        SEGMENT_D,
        SEGMENT_E,
        SUM(CUSTOMER_COUNT) AS POPULATION,
        AVG(MEDIAN_INCOME) AS AVG_INCOME,
        AVG(AVERAGE_ASSET_AMOUNT) AS AVG_ASSET,
        AVG(CREDIT_SCORE_AVG) AS AVG_CREDIT,
        AVG(TOTAL_USAGE_AMOUNT) AS AVG_SPEND,
        AVG(INSTALLMENT_AMOUNT) AS AVG_INSTALLMENT,
        AVG(ABROAD_SPEND_AMOUNT) AS AVG_ABROAD,
        SUM(OWN_HOUSING_COUNT) AS TOTAL_OWNED,
        SUM(MULTIPLE_HOUSING_COUNT) AS TOTAL_MULTI
    FROM INSURE_DB.INTERMEDIATE.INT_SEGMENT_CLASSIFICATION
    GROUP BY DISTRICT_CODE, YEAR_MONTH, SEGMENT_A, SEGMENT_B, SEGMENT_C, SEGMENT_D, SEGMENT_E
)
SELECT
    s.DISTRICT_CODE,
    s.YEAR_MONTH,
    s.SEGMENT_A,
    s.SEGMENT_B,
    s.SEGMENT_C,
    s.SEGMENT_D,
    s.SEGMENT_E,
    s.SEGMENT_A || '|' || s.SEGMENT_B || '|' || s.SEGMENT_C AS COMPOSITE_SEGMENT,
    s.POPULATION,
    s.AVG_INCOME,
    s.AVG_ASSET,
    s.AVG_CREDIT,
    s.AVG_SPEND,
    ROUND(
        s.AVG_ASSET * 0.15
        + s.AVG_INCOME * 0.08
        + COALESCE(s.AVG_INSTALLMENT, 0) * 12 * 2
    , 0) AS ESTIMATED_MOVABLE_ASSET_VALUE,
    ROUND(
        (s.AVG_ASSET * 0.15 + s.AVG_INCOME * 0.08 + COALESCE(s.AVG_INSTALLMENT, 0) * 12 * 2)
        * CASE
            WHEN s.SEGMENT_E = 'E1_저위험안정' THEN 0.003
            WHEN s.SEGMENT_E = 'E2_중위험표준' THEN 0.005
            WHEN s.SEGMENT_E = 'E3_고위험집중' THEN 0.008
            ELSE 0.005
          END
    , 0) AS BASE_PREMIUM_MONTHLY,
    CASE
        WHEN s.AVG_CREDIT >= 850 THEN 0.85
        WHEN s.AVG_CREDIT >= 750 THEN 0.95
        WHEN s.AVG_CREDIT >= 650 THEN 1.00
        WHEN s.AVG_CREDIT >= 550 THEN 1.10
        ELSE 1.25
    END AS CREDIT_ADJUSTMENT,
    CASE s.SEGMENT_A
        WHEN 'A1_사회초년생' THEN '전자기기파손,도난,화재'
        WHEN 'A2_신혼'       THEN '가전파손,화재,수재,배상책임'
        WHEN 'A3_영유아가구' THEN '가전파손,화재,어린이안전,배상책임'
        WHEN 'A4_학령기가구' THEN '화재,도난,수재,가전파손'
        WHEN 'A5_중년안정'   THEN '화재,도난,수재,귀금속,고가가전'
        WHEN 'A6_은퇴시니어' THEN '화재,수재,의료기기,배상책임'
        ELSE '화재,도난,가전파손'
    END AS RECOMMENDED_COVERAGE,
    CASE
        WHEN s.AVG_ABROAD > 200000 THEN '여행자보험_번들추천'
        WHEN s.TOTAL_MULTI > 20 THEN '임대인패키지_추천'
        WHEN s.TOTAL_OWNED < 30 THEN '임차인전용_추천'
        ELSE '표준패키지'
    END AS CROSS_SELL_RECOMMENDATION,
    s.SEGMENT_E AS RISK_PROFILE
FROM segment_stats s;

-- 확인
SELECT YEAR_MONTH, COUNT(*) AS rows
FROM MART_INSURANCE_DESIGN
GROUP BY YEAR_MONTH
ORDER BY YEAR_MONTH;


-- ============================================================
-- STEP 2: MART_DISTRICT_INSURANCE_SUMMARY 완전 재구축
--         (전체 YEAR_MONTH × 서울 25개 구 보장)
--         ★ v2.5 비선형 공식 적용 (1 + risk²/8000.0)
-- ============================================================

USE SCHEMA MART;

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

-- (B) 서울 전체 통계 (YEAR_MONTH별 — 해당 월의 실데이터 기반 추정치)
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

-- (D) ★ 핵심: 25개 구 × 모든 YEAR_MONTH 전체 조합
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

-- (F) ★ 핵심: 누락된 구+월 조합 (모든 달 × 25구 기준)
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

-- (H) 누락 구+월에 대한 추정 데이터 (해당 월 서울 평균 기반)
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
        -- 선형 리스크 보정 공식: (1 + risk/200.0) + IQR 클램핑
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
    LEFT JOIN premium_bounds pb ON d.YEAR_MONTH = pb.YEAR_MONTH
    WHERE d.GU_NAME IS NOT NULL
)
SELECT * FROM assembled;


-- ============================================================
-- STEP 3: MART_PREMIUM_SIMULATION 뷰 재생성
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
-- STEP 4: 검증 쿼리
-- ============================================================

-- 4-1) ★ 핵심 검증: YEAR_MONTH별 구 수 (모두 25개 + 여러 달이어야 함)
SELECT
    YEAR_MONTH,
    COUNT(DISTINCT GU_NAME) AS gu_count,
    ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY), 0) AS avg_premium,
    ROUND(MIN(ADJUSTED_PREMIUM_MONTHLY), 0) AS min_premium,
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY), 0) AS max_premium
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY YEAR_MONTH
ORDER BY YEAR_MONTH;

-- 4-2) 전체 요약
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT YEAR_MONTH) AS distinct_months,
    COUNT(DISTINCT GU_NAME) AS distinct_gu,
    ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY), 0) AS avg_premium,
    ROUND(MIN(ADJUSTED_PREMIUM_MONTHLY), 0) AS min_premium,
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY), 0) AS max_premium,
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY) / NULLIF(MIN(ADJUSTED_PREMIUM_MONTHLY), 0), 1) AS max_min_ratio
FROM MART_DISTRICT_INSURANCE_SUMMARY;

-- 4-3) 동일값 검증 (같은 보험료를 가진 구가 5개 이상이면 문제)
SELECT
    YEAR_MONTH,
    ADJUSTED_PREMIUM_MONTHLY AS premium,
    COUNT(*) AS gu_count,
    LISTAGG(GU_NAME, ', ') WITHIN GROUP (ORDER BY GU_NAME) AS gu_list
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY YEAR_MONTH, ADJUSTED_PREMIUM_MONTHLY
HAVING COUNT(*) >= 5
ORDER BY YEAR_MONTH, gu_count DESC;

-- 4-4) 셀렉터 결과 미리보기 (main.py 쿼리와 동일)
SELECT DISTINCT YEAR_MONTH
FROM MART_DISTRICT_INSURANCE_SUMMARY
ORDER BY YEAR_MONTH DESC;

SELECT '✅ 26_FIX_YEAR_MONTH_ALL_MONTHS.sql 실행 완료' AS status;
