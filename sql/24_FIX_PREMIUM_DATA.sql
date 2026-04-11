-- ============================================================
-- 24_FIX_PREMIUM_DATA.sql
-- 보험료 대시보드 데이터 이상값 수정
--
-- [문제 진단]
-- 1. 리스크 JOIN 실패: YEAR_MONTH='202512' → YEAR=2025인데,
--    INT_DISTRICT_RISK_SCORE에 2025년 데이터 없음 (시드 데이터는 2021~2024)
--    → 모든 구가 COALESCE fallback 값(30)을 받음
-- 2. missing_gu 추정치: 실제 데이터가 없는 구들이 서울 평균으로 대체되어
--    완전히 동일한 보험료 산출 (예: 강남구=중랑구=강북구 = ₩74,410)
-- 3. 서초구 이상값: AVG_BASE_PREMIUM이 자산 기반으로 과도하게 높게 산출됨
--    (자산이 높은 구일수록 base premium이 비례적으로 커짐)
--
-- [해결 방안]
-- A. 리스크 JOIN을 '가장 최근 연도' 매칭으로 변경
-- B. missing_gu 제거 + GU_CODE_MAPPING 기반 전체 구 커버리지 보장
-- C. ADJUSTED_PREMIUM에 IQR 기반 이상값 보정 적용
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE INSURE_DB;
USE SCHEMA INTERMEDIATE;


-- ============================================================
-- STEP 0: 진단 쿼리 (문제 확인용 — 실행 후 결과 확인)
-- ============================================================

-- 0-1) 리스크 테이블에 어떤 연도가 있는지 확인
SELECT DISTINCT YEAR, COUNT(*) AS rows_per_year
FROM INT_DISTRICT_RISK_SCORE
GROUP BY YEAR ORDER BY YEAR;

-- 0-2) 리스크 테이블의 DISTRICT_NAME 목록 확인 (JOIN 매칭 검증)
SELECT DISTINCT TRIM(DISTRICT_NAME) AS district_name
FROM INT_DISTRICT_RISK_SCORE
ORDER BY district_name;

-- 0-3) GU_CODE_MAPPING과 리스크 테이블 매칭 테스트
SELECT g.GU_NAME, r.DISTRICT_NAME,
       CASE WHEN r.DISTRICT_NAME IS NOT NULL THEN '✅ 매칭' ELSE '❌ 미매칭' END AS status
FROM INSURE_DB.STAGING.GU_CODE_MAPPING g
LEFT JOIN (SELECT DISTINCT TRIM(DISTRICT_NAME) AS DISTRICT_NAME FROM INT_DISTRICT_RISK_SCORE) r
    ON TRIM(g.GU_NAME) = r.DISTRICT_NAME
ORDER BY g.GU_NAME;

-- 0-4) MART_INSURANCE_DESIGN의 구별 AVG_BASE_PREMIUM 분포 확인
SELECT g.GU_NAME,
       COUNT(*) AS row_count,
       ROUND(AVG(m.BASE_PREMIUM_MONTHLY), 0) AS avg_base,
       ROUND(MIN(m.BASE_PREMIUM_MONTHLY), 0) AS min_base,
       ROUND(MAX(m.BASE_PREMIUM_MONTHLY), 0) AS max_base,
       ROUND(MEDIAN(m.BASE_PREMIUM_MONTHLY), 0) AS median_base
FROM INSURE_DB.MART.MART_INSURANCE_DESIGN m
LEFT JOIN INSURE_DB.STAGING.GU_CODE_MAPPING g
    ON LEFT(m.DISTRICT_CODE::VARCHAR, 5) = g.GU_CODE
GROUP BY g.GU_NAME
ORDER BY avg_base DESC;


-- ============================================================
-- STEP 1: 리스크 테이블에 2025년 데이터 보충
-- (가장 최근 연도 데이터를 2025년으로 복제)
-- ============================================================

USE SCHEMA INTERMEDIATE;

-- 기존 2025 데이터가 없는 경우에만 최신 연도 데이터를 복제
INSERT INTO INT_DISTRICT_RISK_SCORE
SELECT
    DISTRICT_NAME,
    2025 AS YEAR,
    COMPOSITE_RISK_SCORE,
    RISK_GRADE,
    FIRE_RISK_SCORE,
    THEFT_RISK_SCORE,
    BUILDING_RISK_SCORE,
    WEATHER_RISK_SCORE
FROM INT_DISTRICT_RISK_SCORE
WHERE YEAR = (SELECT MAX(YEAR) FROM INT_DISTRICT_RISK_SCORE)
  AND NOT EXISTS (
    SELECT 1 FROM INT_DISTRICT_RISK_SCORE r2
    WHERE r2.YEAR = 2025 AND TRIM(r2.DISTRICT_NAME) = TRIM(INT_DISTRICT_RISK_SCORE.DISTRICT_NAME)
  );

-- 확인
SELECT YEAR, COUNT(*) AS cnt FROM INT_DISTRICT_RISK_SCORE GROUP BY YEAR ORDER BY YEAR;


-- ============================================================
-- STEP 2: MART_DISTRICT_INSURANCE_SUMMARY 재구축
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
        -- ★ 핵심 수정: MEDIAN 사용으로 이상값 영향 완화
        MEDIAN(m.BASE_PREMIUM_MONTHLY) AS AVG_BASE_PREMIUM,
        AVG(m.AVG_CREDIT) AS AVG_CREDIT_SCORE
    FROM INSURE_DB.MART.MART_INSURANCE_DESIGN m
    LEFT JOIN INSURE_DB.STAGING.STG_DISTRICT_MASTER dm ON m.DISTRICT_CODE = dm.DISTRICT_CODE
    LEFT JOIN INSURE_DB.STAGING.GU_CODE_MAPPING g ON LEFT(m.DISTRICT_CODE::VARCHAR, 5) = g.GU_CODE
    GROUP BY m.DISTRICT_CODE, dm.DISTRICT_KOR_NAME, COALESCE(g.GU_NAME, dm.CITY_KOR_NAME), m.YEAR_MONTH
),

-- (B) 서울 전체 통계 — YEAR_MONTH별 평균 (missing 구 대체용)
-- ★ v2.5 FIX: 전체 평균이 아닌 월별 평균으로 계산해야 다른 달도 올바른 값 사용
seoul_avg AS (
    SELECT YEAR_MONTH,
        AVG(DISTRICT_AVG_INCOME) AS avg_income,
        AVG(DISTRICT_AVG_ASSET) AS avg_asset,
        AVG(AVG_MOVABLE_ASSET) AS avg_movable,
        MEDIAN(AVG_BASE_PREMIUM) AS avg_premium,
        AVG(AVG_CREDIT_SCORE) AS avg_credit
    FROM real_data
    GROUP BY YEAR_MONTH
),

-- (C) 실제 데이터가 있는 구 목록
covered_gu AS (SELECT DISTINCT GU_NAME FROM real_data WHERE GU_NAME IS NOT NULL),

-- (D) 누락된 구 처리 — ★ v2.5 FIX: '202512' 하드코딩 제거, 모든 YEAR_MONTH에 대해 생성
missing_gu AS (
    SELECT g.GU_NAME, ym.YEAR_MONTH
    FROM INSURE_DB.STAGING.GU_CODE_MAPPING g
    CROSS JOIN (SELECT DISTINCT YEAR_MONTH FROM real_data) ym
    WHERE g.GU_NAME NOT IN (SELECT GU_NAME FROM covered_gu)
),

-- (E) 누락 구에 대한 추정 데이터 (해당 월 서울 평균 기반)
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
    FROM missing_gu mg
    -- ★ v2.5 FIX: CROSS JOIN → YEAR_MONTH 기준 JOIN (월별 서울 평균 사용)
    JOIN seoul_avg sa ON mg.YEAR_MONTH = sa.YEAR_MONTH
    LEFT JOIN (
        SELECT dm.CITY_KOR_NAME AS GU_NAME, COUNT(DISTINCT dm.DISTRICT_CODE) * 8500 AS EST_POPULATION
        FROM INSURE_DB.STAGING.STG_DISTRICT_MASTER dm
        WHERE dm.PROVINCE_KOR_NAME = '서울특별시'
        GROUP BY dm.CITY_KOR_NAME
    ) ep ON mg.GU_NAME = ep.GU_NAME
),

-- (F) 전체 구 통합
all_districts AS (
    SELECT * FROM real_data WHERE GU_NAME IS NOT NULL
    UNION ALL
    SELECT * FROM estimated_data
),

-- (G) 리스크: ★ 핵심 수정 — 가장 가까운 연도 매칭
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

-- (H) 아파트 가격
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

-- (I) 보험료 IQR 기반 상한/하한 — ★ v2.5 FIX: YEAR_MONTH별로 계산
premium_bounds AS (
    SELECT YEAR_MONTH,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY d.AVG_BASE_PREMIUM) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY d.AVG_BASE_PREMIUM) AS q3
    FROM all_districts d
    GROUP BY YEAR_MONTH
),

-- (J) 최종 조합
assembled AS (
    SELECT
        d.DISTRICT_CODE, d.DISTRICT_NAME, d.GU_NAME, d.YEAR_MONTH,
        d.ACTIVE_SEGMENTS, d.TOTAL_POPULATION,
        d.DISTRICT_AVG_INCOME, d.DISTRICT_AVG_ASSET,
        d.AVG_MOVABLE_ASSET, d.AVG_BASE_PREMIUM, d.AVG_CREDIT_SCORE,
        -- ★ 수정: latest_risk 사용 (연도 제약 없이 가장 최근 리스크)
        COALESCE(lr.COMPOSITE_RISK_SCORE, 30) AS COMPOSITE_RISK_SCORE,
        COALESCE(lr.RISK_GRADE, '미산정') AS RISK_GRADE,
        COALESCE(lr.FIRE_RISK_SCORE, 0) AS FIRE_RISK_SCORE,
        COALESCE(lr.THEFT_RISK_SCORE, 0) AS THEFT_RISK_SCORE,
        COALESCE(lr.BUILDING_RISK_SCORE, 0) AS BUILDING_RISK_SCORE,
        COALESCE(lr.WEATHER_RISK_SCORE, 0) AS WEATHER_RISK_SCORE,
        COALESCE(ap.AVG_SALE_PRICE_PYEONG, sa.avg_sale) AS AVG_SALE_PRICE_PYEONG,
        COALESCE(ap.AVG_JEONSE_PRICE_PYEONG, sa.avg_jeonse) AS AVG_JEONSE_PRICE_PYEONG,
        -- ★ 핵심 수정: base premium을 IQR 범위로 클램핑 (Q1 - 1.5*IQR ~ Q3 + 1.5*IQR)
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
    -- ★ 수정: 연도 제약 제거, 가장 최근 리스크만 사용
    LEFT JOIN latest_risk lr ON TRIM(d.GU_NAME) = lr.DISTRICT_NAME
    LEFT JOIN apt_price ap ON TRIM(d.GU_NAME) = TRIM(ap.GU_NAME)
    CROSS JOIN seoul_apt_avg sa
    -- ★ v2.5 FIX: CROSS JOIN → YEAR_MONTH 기준 JOIN (월별 IQR 적용)
    JOIN premium_bounds pb ON d.YEAR_MONTH = pb.YEAR_MONTH
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

-- 4-1) 전체 요약
SELECT
    COUNT(DISTINCT GU_NAME) AS DISTINCT_GU_COUNT,
    SUM(TOTAL_POPULATION) AS TOTAL_POP,
    ROUND(AVG(COMPOSITE_RISK_SCORE), 1) AS AVG_RISK,
    ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY), 0) AS AVG_PREMIUM,
    ROUND(MIN(ADJUSTED_PREMIUM_MONTHLY), 0) AS MIN_PREMIUM,
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY), 0) AS MAX_PREMIUM,
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY) / NULLIF(MIN(ADJUSTED_PREMIUM_MONTHLY), 0), 1) AS MAX_MIN_RATIO
FROM MART_DISTRICT_INSURANCE_SUMMARY;

-- 4-2) 구별 상세 (보험료 순)
SELECT
    GU_NAME AS "자치구",
    ROUND(ADJUSTED_PREMIUM_MONTHLY, 0) AS "월보험료",
    ROUND(AVG_BASE_PREMIUM, 0) AS "기본보험료",
    ROUND(COMPOSITE_RISK_SCORE, 1) AS "위험도",
    RISK_GRADE AS "등급",
    ROUND(AVG_CREDIT_SCORE, 0) AS "신용점수",
    ROUND((ADJUSTED_PREMIUM_MONTHLY - AVG(ADJUSTED_PREMIUM_MONTHLY) OVER())
          / AVG(ADJUSTED_PREMIUM_MONTHLY) OVER() * 100, 0) AS "평균대비%"
FROM MART_DISTRICT_INSURANCE_SUMMARY
ORDER BY ADJUSTED_PREMIUM_MONTHLY DESC;

-- 4-3) 리스크 JOIN 성공 여부 확인 (RISK_GRADE = '미산정'이면 JOIN 실패)
SELECT
    GU_NAME,
    RISK_GRADE,
    COMPOSITE_RISK_SCORE,
    CASE WHEN RISK_GRADE = '미산정' THEN '❌ JOIN 실패' ELSE '✅ 정상' END AS join_status
FROM MART_DISTRICT_INSURANCE_SUMMARY
ORDER BY GU_NAME;

-- 4-4) 동일값 검증 (같은 보험료를 가진 구가 3개 이상이면 문제)
SELECT
    ADJUSTED_PREMIUM_MONTHLY AS premium,
    COUNT(*) AS gu_count,
    LISTAGG(GU_NAME, ', ') WITHIN GROUP (ORDER BY GU_NAME) AS gu_list
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY ADJUSTED_PREMIUM_MONTHLY
HAVING COUNT(*) >= 3
ORDER BY gu_count DESC;

-- 4-5) Top 3 vs Bottom 3 미리보기
SELECT '🔴 높은 구' AS category, GU_NAME, ADJUSTED_PREMIUM_MONTHLY
FROM (SELECT *, ROW_NUMBER() OVER (ORDER BY ADJUSTED_PREMIUM_MONTHLY DESC) AS rn FROM MART_DISTRICT_INSURANCE_SUMMARY) WHERE rn <= 3
UNION ALL
SELECT '🟢 낮은 구', GU_NAME, ADJUSTED_PREMIUM_MONTHLY
FROM (SELECT *, ROW_NUMBER() OVER (ORDER BY ADJUSTED_PREMIUM_MONTHLY ASC) AS rn FROM MART_DISTRICT_INSURANCE_SUMMARY) WHERE rn <= 3
ORDER BY category, ADJUSTED_PREMIUM_MONTHLY DESC;

SELECT '✅ 24_FIX_PREMIUM_DATA.sql 실행 완료' AS status;
