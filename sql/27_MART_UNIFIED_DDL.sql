-- ⚠️ 실행 전 PM(Jun) 승인 필요 — PROJECT_GUIDELINES 준수
-- ============================================================
-- INSURE MART Unified DDL
-- 최종 MART 테이블 통합 빌드 (06, 10, 12, 13, 14 통합)
-- 작성일: 2026-04-11
-- 목적: 모든 버그 수정을 포함한 최종 MART 계층 재구성
-- ============================================================

USE DATABASE INSURE_DB;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA MART;

-- ============================================================
-- Step 1: MART_INSURANCE_DESIGN (기본 설계 테이블)
-- 출처: 06_DBT_MART.sql + 버그 수정
-- 세그먼트별 × 구별 동적 보험 설계안
-- ============================================================

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
    -- ★ 추정 동산 가치 (소득 + 자산 + 소비 패턴 기반)
    ROUND(
        s.AVG_ASSET * 0.15
        + s.AVG_INCOME * 0.08
        + COALESCE(s.AVG_INSTALLMENT, 0) * 12 * 2
    , 0) AS ESTIMATED_MOVABLE_ASSET_VALUE,
    -- ★ 기본 보험료 (동산 가치의 0.3~0.8%)
    ROUND(
        (s.AVG_ASSET * 0.15 + s.AVG_INCOME * 0.08 + COALESCE(s.AVG_INSTALLMENT, 0) * 12 * 2)
        * CASE
            WHEN s.SEGMENT_E = 'E1_저위험안정' THEN 0.003
            WHEN s.SEGMENT_E = 'E2_중위험표준' THEN 0.005
            WHEN s.SEGMENT_E = 'E3_고위험집중' THEN 0.008
            ELSE 0.005
          END
    , 0) AS BASE_PREMIUM_MONTHLY,
    -- ★ 신용 보정 계수 (M-3 수정: 5단계 기준)
    CASE
        WHEN s.AVG_CREDIT >= 800 THEN 0.85
        WHEN s.AVG_CREDIT >= 700 THEN 0.93
        WHEN s.AVG_CREDIT >= 600 THEN 1.00
        WHEN s.AVG_CREDIT >= 500 THEN 1.10
        ELSE 1.25
    END AS CREDIT_ADJUSTMENT,
    -- ★ 추천 보장 항목 (세그먼트 기반)
    CASE s.SEGMENT_A
        WHEN 'A1_사회초년생' THEN '전자기기파손,도난,화재'
        WHEN 'A2_신혼'       THEN '가전파손,화재,수재,배상책임'
        WHEN 'A3_영유아가구' THEN '가전파손,화재,어린이안전,배상책임'
        WHEN 'A4_학령기가구' THEN '화재,도난,수재,가전파손'
        WHEN 'A5_중년안정'   THEN '화재,도난,수재,귀금속,고가가전'
        WHEN 'A6_은퇴시니어' THEN '화재,수재,의료기기,배상책임'
        ELSE '화재,도난,가전파손'
    END AS RECOMMENDED_COVERAGE,
    -- ★ 크로스셀 추천
    CASE
        WHEN s.AVG_ABROAD > 200000 THEN '여행자보험_번들추천'
        WHEN s.TOTAL_MULTI > 20 THEN '임대인패키지_추천'
        WHEN s.TOTAL_OWNED < 30 THEN '임차인전용_추천'
        ELSE '표준패키지'
    END AS CROSS_SELL_RECOMMENDATION,
    -- ★ 해지 리스크 등급
    s.SEGMENT_E AS RISK_PROFILE
FROM segment_stats s;

-- Verification: MART_INSURANCE_DESIGN
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT COMPOSITE_SEGMENT) AS distinct_segments,
    COUNT(DISTINCT DISTRICT_CODE) AS distinct_districts,
    AVG(POPULATION) AS avg_population,
    AVG(BASE_PREMIUM_MONTHLY) AS avg_base_premium
FROM MART_INSURANCE_DESIGN;


-- ============================================================
-- Step 2: GU_CODE_MAPPING (구 코드 매핑)
-- 출처: 10_FIX_MART_GU_JOIN.sql
-- 동(8자리) → 구(5자리) 변환용 마스터
-- ============================================================

CREATE OR REPLACE TABLE INSURE_DB.STAGING.GU_CODE_MAPPING (
    GU_CODE VARCHAR,
    GU_NAME VARCHAR
);

INSERT INTO INSURE_DB.STAGING.GU_CODE_MAPPING VALUES
('11110','종로구'),('11140','중구'),('11170','용산구'),('11200','성동구'),
('11215','광진구'),('11230','동대문구'),('11260','중랑구'),('11290','성북구'),
('11305','강북구'),('11320','도봉구'),('11350','노원구'),('11380','은평구'),
('11410','서대문구'),('11440','마포구'),('11470','양천구'),('11500','강서구'),
('11530','구로구'),('11545','금천구'),('11560','영등포구'),('11590','동작구'),
('11620','관악구'),('11650','서초구'),('11680','강남구'),('11710','송파구'),
('11740','강동구');

-- Verification: GU_CODE_MAPPING
SELECT COUNT(*) AS gu_count FROM INSURE_DB.STAGING.GU_CODE_MAPPING;


-- ============================================================
-- Step 3: MART_DISTRICT_INSURANCE_SUMMARY (구별 요약)
-- 출처: 06 + 10 + 12 + 13
-- 구별 보험 설계 요약 (TRIM 적용, APT_PRICE 통합)
-- ============================================================

CREATE OR REPLACE TABLE MART_DISTRICT_INSURANCE_SUMMARY AS
WITH
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
        MEDIAN(m.BASE_PREMIUM_MONTHLY) AS AVG_BASE_PREMIUM,  -- ★ AVG→MEDIAN (이상값 강건)
        AVG(m.AVG_CREDIT) AS AVG_CREDIT_SCORE
    FROM INSURE_DB.MART.MART_INSURANCE_DESIGN m
    LEFT JOIN INSURE_DB.STAGING.STG_DISTRICT_MASTER dm
        ON m.DISTRICT_CODE = dm.DISTRICT_CODE
    LEFT JOIN INSURE_DB.STAGING.GU_CODE_MAPPING g
        ON LEFT(m.DISTRICT_CODE::VARCHAR, 5) = g.GU_CODE
    GROUP BY m.DISTRICT_CODE, dm.DISTRICT_KOR_NAME, COALESCE(g.GU_NAME, dm.CITY_KOR_NAME), m.YEAR_MONTH
),
seoul_avg AS (
    SELECT
        AVG(DISTRICT_AVG_INCOME) AS avg_income,
        AVG(DISTRICT_AVG_ASSET) AS avg_asset,
        AVG(AVG_MOVABLE_ASSET) AS avg_movable,
        MEDIAN(AVG_BASE_PREMIUM) AS avg_premium,  -- ★ MEDIAN
        AVG(AVG_CREDIT_SCORE) AS avg_credit
    FROM real_data
),
covered_gu AS (
    SELECT DISTINCT GU_NAME FROM real_data WHERE GU_NAME IS NOT NULL
),
missing_gu AS (
    SELECT g.GU_CODE, g.GU_NAME, '202512' AS YEAR_MONTH
    FROM INSURE_DB.STAGING.GU_CODE_MAPPING g
    WHERE g.GU_NAME NOT IN (SELECT GU_NAME FROM covered_gu)
),
estimated_pop AS (
    SELECT dm.CITY_KOR_NAME AS GU_NAME, COUNT(DISTINCT dm.DISTRICT_CODE) * 8500 AS EST_POPULATION
    FROM INSURE_DB.STAGING.STG_DISTRICT_MASTER dm
    WHERE dm.PROVINCE_KOR_NAME = '서울특별시'
    GROUP BY dm.CITY_KOR_NAME
),
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
    CROSS JOIN seoul_avg sa
    LEFT JOIN estimated_pop ep ON mg.GU_NAME = ep.GU_NAME
),
all_districts AS (
    SELECT * FROM real_data WHERE GU_NAME IS NOT NULL
    UNION ALL
    SELECT * FROM estimated_data
),
-- ★ 최신 연도 리스크만 사용 (ROW_NUMBER로 연도 불일치 해결)
risk_ranked AS (
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
risk AS (
    SELECT * FROM risk_ranked WHERE rn = 1
),
apt_price AS (
    SELECT
        SGG AS GU_NAME,
        ROUND(AVG(SALE_PRICE_PER_PYEONG), 0) AS AVG_SALE_PRICE_PYEONG,
        ROUND(AVG(JEONSE_PRICE_PER_PYEONG), 0) AS AVG_JEONSE_PRICE_PYEONG
    FROM INSURE_DB.STAGING.STG_APT_PRICE
    GROUP BY SGG
),
seoul_apt_avg AS (
    SELECT
        ROUND(AVG(SALE_PRICE_PER_PYEONG), 0) AS avg_sale,
        ROUND(AVG(JEONSE_PRICE_PER_PYEONG), 0) AS avg_jeonse
    FROM INSURE_DB.STAGING.STG_APT_PRICE
),
-- ★ IQR 기반 이상값 클램핑
premium_bounds AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY AVG_BASE_PREMIUM) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY AVG_BASE_PREMIUM) AS q3
    FROM all_districts
)
SELECT
    d.DISTRICT_CODE,
    d.DISTRICT_NAME,
    d.GU_NAME,
    d.YEAR_MONTH,
    d.ACTIVE_SEGMENTS,
    d.TOTAL_POPULATION,
    d.DISTRICT_AVG_INCOME,
    d.DISTRICT_AVG_ASSET,
    d.AVG_MOVABLE_ASSET,
    d.AVG_BASE_PREMIUM,
    d.AVG_CREDIT_SCORE,
    -- Risk Scores (M-2 수정: 저위험 임계값 25)
    COALESCE(r.COMPOSITE_RISK_SCORE, 30) AS COMPOSITE_RISK_SCORE,
    COALESCE(r.RISK_GRADE, '미산정') AS RISK_GRADE,
    COALESCE(r.FIRE_RISK_SCORE, 0) AS FIRE_RISK_SCORE,
    COALESCE(r.THEFT_RISK_SCORE, 0) AS THEFT_RISK_SCORE,
    COALESCE(r.BUILDING_RISK_SCORE, 0) AS BUILDING_RISK_SCORE,
    COALESCE(r.WEATHER_RISK_SCORE, 0) AS WEATHER_RISK_SCORE,
    -- APT_PRICE Integration (v1.2)
    COALESCE(ap.AVG_SALE_PRICE_PYEONG, sa.avg_sale) AS AVG_SALE_PRICE_PYEONG,
    COALESCE(ap.AVG_JEONSE_PRICE_PYEONG, sa.avg_jeonse) AS AVG_JEONSE_PRICE_PYEONG,
    -- ★ Final Adjusted Premium (IQR 클램핑 + 비선형 리스크 보정)
    ROUND(
        LEAST(
            GREATEST(d.AVG_BASE_PREMIUM, pb.q1 - 1.5 * (pb.q3 - pb.q1)),
            pb.q3 + 1.5 * (pb.q3 - pb.q1)
        )
        * (1 + POWER(COALESCE(r.COMPOSITE_RISK_SCORE, 30), 2) / 8000.0)
        * CASE
            WHEN d.AVG_CREDIT_SCORE >= 800 THEN 0.90
            WHEN d.AVG_CREDIT_SCORE >= 700 THEN 0.95
            ELSE 1.05
          END
    , 0) AS ADJUSTED_PREMIUM_MONTHLY,
    -- Estimated Annual Market Size
    ROUND(
        d.TOTAL_POPULATION * 0.15 * d.AVG_BASE_PREMIUM * 12
    , 0) AS ESTIMATED_ANNUAL_MARKET_KRW
FROM all_districts d
-- ★ 최신 연도 리스크만 JOIN (연도 매칭 제거)
LEFT JOIN risk r ON TRIM(d.GU_NAME) = r.DISTRICT_NAME
LEFT JOIN apt_price ap ON TRIM(d.GU_NAME) = TRIM(ap.GU_NAME)
CROSS JOIN seoul_apt_avg sa
CROSS JOIN premium_bounds pb
WHERE d.GU_NAME IS NOT NULL;

-- Verification: MART_DISTRICT_INSURANCE_SUMMARY
SELECT
    COUNT(DISTINCT GU_NAME) AS gu_count,
    COUNT(*) AS total_rows,
    ROUND(AVG(COMPOSITE_RISK_SCORE), 1) AS avg_risk_score,
    ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY), 0) AS avg_adjusted_premium,
    ROUND(SUM(ESTIMATED_ANNUAL_MARKET_KRW), 0) AS total_market_size
FROM MART_DISTRICT_INSURANCE_SUMMARY;


-- ============================================================
-- Step 4: MART_SEGMENT_PERSONA (세그먼트 페르소나)
-- 출처: 06_DBT_MART.sql
-- 세그먼트별 고객 페르소나 카드
-- ============================================================

CREATE OR REPLACE TABLE MART_SEGMENT_PERSONA AS
SELECT * FROM (
  VALUES
    ('A1_사회초년생','20대 직장인','노트북, 태블릿, 스마트폰, 이어폰','전자기기파손, 도난','오피스텔/원룸 거주, 1인가구, 고가 전자기기 의존도 높음'),
    ('A2_신혼','30대 초반 맞벌이','가전세트, 혼수용품, 가구','화재, 가전파손, 배상책임','신혼집 가전 일괄 구매, 고가 혼수용품 보유, 맞벌이로 외출 빈번'),
    ('A3_영유아가구','30대 중반 부부+유아','유모차, 카시트, 가전, 가구','화재, 어린이안전, 가전파손','안전 관련 니즈 높음, 생활가전 다수 보유, 배상책임 중요'),
    ('A4_학령기가구','40대 가족','가전, 가구, 자녀학용품, PC','화재, 도난, 수재','대형 가전 보유, 주거 안정기, 종합 보장 선호'),
    ('A5_중년안정','50대 자산축적기','고가가전, 귀금속, 미술품, 골프용품','화재, 도난, 귀금속, 고가품','자산 가치 최고점, 고가 동산 다수, 포괄적 보장 필요'),
    ('A6_은퇴시니어','60대 이상 은퇴','가전, 건강기기, 의료기기','화재, 수재, 의료기기','전자기기 사용 제한적, 건강/의료 관련 동산 중심'),
    ('B1_영리치','고소득 자산가','명품가전, 예술품, 귀금속, 와인','도난, 화재, 고가품특약','VIP 맞춤 설계, 고보장 프리미엄 상품'),
    ('B2_알뜰형','절약형 소비자','기본가전, 생활용품','화재, 기본보장','최소 보장 저가형, 가성비 중시'),
    ('B5_소비과다형','과소비 성향','최신가전, 전자기기, 구독서비스','파손, 도난, 할부보장','할부 비중 높음, 교체 주기 빠름, 파손 리스크 높음'),
    ('C4_오피스텔원룸','1인 소형주거','소형가전, 전자기기','화재, 도난, 전기안전','건물 노후도 높은 편, 화재/도난 취약, 전기 안전 이슈'),
    ('D1_자영업소상공인','자영업자','사업용기기, 재고자산','화재, 도난, 영업손실','사업장 동산 포함, 영업중단 보장 필요'),
    ('E3_고위험집중','신용 취약층','기본가전','화재, 기본보장','보험료 부담 고려, 최소보장 설계, 해지 리스크 관리')
) AS t(SEGMENT_CODE, PERSONA_NAME, KEY_ASSETS, COVERAGE_NEEDS, DESCRIPTION);

-- Verification: MART_SEGMENT_PERSONA
SELECT COUNT(*) AS persona_count FROM MART_SEGMENT_PERSONA;


-- ============================================================
-- Step 5: MART_PREMIUM_SIMULATION (보험료 시뮬레이션)
-- 출처: 06_DBT_MART.sql + 13_V1.2_IMPROVEMENTS.sql
-- 보장 비율별 보험료 시뮬레이션
-- ============================================================

CREATE OR REPLACE VIEW MART_PREMIUM_SIMULATION AS
SELECT
    d.DISTRICT_CODE,
    d.DISTRICT_NAME,
    d.GU_NAME,
    d.YEAR_MONTH,
    d.AVG_MOVABLE_ASSET,
    d.COMPOSITE_RISK_SCORE,
    d.RISK_GRADE,
    d.AVG_CREDIT_SCORE,
    d.ADJUSTED_PREMIUM_MONTHLY,
    -- ★ Coverage Simulation (동산가치 50%, 80%, 100%)
    ROUND(d.ADJUSTED_PREMIUM_MONTHLY * 0.5, 0) AS PREMIUM_50PCT_COVERAGE,
    ROUND(d.ADJUSTED_PREMIUM_MONTHLY * 0.8, 0) AS PREMIUM_80PCT_COVERAGE,
    d.ADJUSTED_PREMIUM_MONTHLY AS PREMIUM_100PCT_COVERAGE,
    -- Annual Premium
    d.ADJUSTED_PREMIUM_MONTHLY * 12 AS ANNUAL_PREMIUM,
    d.ESTIMATED_ANNUAL_MARKET_KRW,
    d.AVG_SALE_PRICE_PYEONG,
    d.AVG_JEONSE_PRICE_PYEONG
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY d
WHERE d.YEAR_MONTH IS NOT NULL;

-- Verification: MART_PREMIUM_SIMULATION
SELECT
    COUNT(*) AS simulation_rows,
    AVG(ADJUSTED_PREMIUM_MONTHLY) AS avg_premium,
    MIN(ADJUSTED_PREMIUM_MONTHLY) AS min_premium,
    MAX(ADJUSTED_PREMIUM_MONTHLY) AS max_premium
FROM MART_PREMIUM_SIMULATION;


-- ============================================================
-- Step 6: MART_APT_PRICE_SUMMARY (아파트 시세 요약)
-- 출처: 13_V1.2_IMPROVEMENTS.sql
-- 구별 아파트 평당가 정보
-- ============================================================

CREATE OR REPLACE VIEW MART_APT_PRICE_SUMMARY AS
SELECT
    SGG AS GU_NAME,
    ROUND(AVG(SALE_PRICE_PER_PYEONG), 0) AS AVG_SALE_PRICE_PER_PYEONG,
    ROUND(AVG(JEONSE_PRICE_PER_PYEONG), 0) AS AVG_JEONSE_PRICE_PER_PYEONG,
    ROUND(AVG(CASE WHEN YEAR_MONTH >= '202301' THEN SALE_PRICE_PER_PYEONG END), 0) AS RECENT_SALE_PRICE,
    ROUND(AVG(CASE WHEN YEAR_MONTH >= '202301' THEN JEONSE_PRICE_PER_PYEONG END), 0) AS RECENT_JEONSE_PRICE,
    COUNT(*) AS DATA_POINTS,
    MIN(YEAR_MONTH) AS DATA_FROM,
    MAX(YEAR_MONTH) AS DATA_TO
FROM INSURE_DB.STAGING.STG_APT_PRICE
GROUP BY SGG;

-- Verification: MART_APT_PRICE_SUMMARY
SELECT
    COUNT(*) AS gu_count,
    AVG(AVG_SALE_PRICE_PER_PYEONG) AS avg_sale_price,
    AVG(AVG_JEONSE_PRICE_PER_PYEONG) AS avg_jeonse_price
FROM MART_APT_PRICE_SUMMARY;


-- ============================================================
-- Final Verification: MART 레이어 통합 검증
-- ============================================================

SELECT
    'MART_INSURANCE_DESIGN' AS table_name,
    COUNT(*) AS row_count,
    NULL AS check_detail
FROM MART_INSURANCE_DESIGN
UNION ALL
SELECT
    'MART_DISTRICT_INSURANCE_SUMMARY',
    COUNT(*),
    CONCAT(COUNT(DISTINCT GU_NAME), ' gu')
FROM MART_DISTRICT_INSURANCE_SUMMARY
UNION ALL
SELECT
    'MART_SEGMENT_PERSONA',
    COUNT(*),
    CONCAT(COUNT(DISTINCT SEGMENT_CODE), ' segments')
FROM MART_SEGMENT_PERSONA
UNION ALL
SELECT
    'MART_PREMIUM_SIMULATION',
    COUNT(*),
    NULL
FROM MART_PREMIUM_SIMULATION
UNION ALL
SELECT
    'MART_APT_PRICE_SUMMARY',
    COUNT(*),
    CONCAT(COUNT(DISTINCT GU_NAME), ' gu')
FROM MART_APT_PRICE_SUMMARY;

-- ============================================================
-- MART Unified Build Complete
-- ============================================================
-- 생성된 테이블:
--   1. MART_INSURANCE_DESIGN (세그먼트 × 구 × 설계)
--   2. MART_DISTRICT_INSURANCE_SUMMARY (구별 요약)
--   3. MART_SEGMENT_PERSONA (페르소나)
--
-- 생성된 뷰:
--   4. MART_PREMIUM_SIMULATION (보험료 시뮬레이션)
--   5. MART_APT_PRICE_SUMMARY (아파트 시세)
--
-- 포함된 버그 수정:
--   - M-3: 신용등급 5단계 통일
--   - M-2: 저위험 임계값 조정
--   - C-5: 컬럼명 검증
--   - 기타: 10, 12, 13 파일의 모든 개선사항
-- ============================================================
