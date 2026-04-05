-- ============================================================
-- INSURE dbt Layer 3: MART
-- 보험 설계 최종 테이블 (세그먼트 × 구 × 보험료)
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA MART;

-- ─────────────────────────────────────────────
-- MART_INSURANCE_DESIGN
-- 핵심 마트: 세그먼트별 × 구별 동적 보험 설계안
-- ─────────────────────────────────────────────
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
        s.AVG_ASSET * 0.15                              -- 총자산의 15%가 동산
        + s.AVG_INCOME * 0.08                            -- 연소득의 8%
        + COALESCE(s.AVG_INSTALLMENT, 0) * 12 * 2       -- 할부 연간 × 2 = 고가 가전
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

    -- ★ 신용 보정 계수
    CASE
        WHEN s.AVG_CREDIT >= 850 THEN 0.85
        WHEN s.AVG_CREDIT >= 750 THEN 0.95
        WHEN s.AVG_CREDIT >= 650 THEN 1.00
        WHEN s.AVG_CREDIT >= 550 THEN 1.10
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


-- ─────────────────────────────────────────────
-- MART_DISTRICT_INSURANCE_SUMMARY
-- 구별 보험 설계 요약 (대시보드 메인 뷰)
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE MART_DISTRICT_INSURANCE_SUMMARY AS
WITH district_design AS (
    SELECT
        m.DISTRICT_CODE,
        dm.DISTRICT_NAME,
        m.YEAR_MONTH,
        COUNT(DISTINCT m.COMPOSITE_SEGMENT) AS ACTIVE_SEGMENTS,
        SUM(m.POPULATION) AS TOTAL_POPULATION,
        AVG(m.AVG_INCOME) AS DISTRICT_AVG_INCOME,
        AVG(m.AVG_ASSET) AS DISTRICT_AVG_ASSET,
        AVG(m.ESTIMATED_MOVABLE_ASSET_VALUE) AS AVG_MOVABLE_ASSET,
        AVG(m.BASE_PREMIUM_MONTHLY) AS AVG_BASE_PREMIUM,
        AVG(m.AVG_CREDIT) AS AVG_CREDIT_SCORE
    FROM INSURE_DB.MART.MART_INSURANCE_DESIGN m
    LEFT JOIN INSURE_DB.STAGING.STG_DISTRICT_MASTER dm
        ON m.DISTRICT_CODE = dm.DISTRICT_CODE
    GROUP BY m.DISTRICT_CODE, dm.DISTRICT_NAME, m.YEAR_MONTH
),
risk AS (
    SELECT
        DISTRICT_NAME,
        YEAR,
        COMPOSITE_RISK_SCORE,
        RISK_GRADE,
        FIRE_RISK_SCORE,
        THEFT_RISK_SCORE,
        BUILDING_RISK_SCORE,
        WEATHER_RISK_SCORE
    FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE
)
SELECT
    d.DISTRICT_CODE,
    d.DISTRICT_NAME,
    d.YEAR_MONTH,
    d.ACTIVE_SEGMENTS,
    d.TOTAL_POPULATION,
    d.DISTRICT_AVG_INCOME,
    d.DISTRICT_AVG_ASSET,
    d.AVG_MOVABLE_ASSET,
    d.AVG_BASE_PREMIUM,
    d.AVG_CREDIT_SCORE,
    r.COMPOSITE_RISK_SCORE,
    r.RISK_GRADE,
    r.FIRE_RISK_SCORE,
    r.THEFT_RISK_SCORE,
    r.BUILDING_RISK_SCORE,
    r.WEATHER_RISK_SCORE,
    -- ★ 최종 조정 보험료 (기본 × 지역리스크 × 신용보정)
    ROUND(
        d.AVG_BASE_PREMIUM
        * (1 + COALESCE(r.COMPOSITE_RISK_SCORE, 30) / 200.0)    -- 리스크 가중
        * CASE
            WHEN d.AVG_CREDIT_SCORE >= 800 THEN 0.90
            WHEN d.AVG_CREDIT_SCORE >= 700 THEN 0.95
            ELSE 1.05
          END
    , 0) AS ADJUSTED_PREMIUM_MONTHLY,
    -- 연간 추정 보험 시장 규모 (구 단위)
    ROUND(
        d.TOTAL_POPULATION * 0.15               -- 가입률 15% 가정
        * d.AVG_BASE_PREMIUM * 12               -- 연간 보험료
    , 0) AS ESTIMATED_ANNUAL_MARKET_KRW
FROM district_design d
LEFT JOIN risk r ON d.DISTRICT_NAME = r.DISTRICT_NAME AND LEFT(d.YEAR_MONTH, 4)::INT = r.YEAR;


-- ─────────────────────────────────────────────
-- MART_SEGMENT_PERSONA
-- 세그먼트별 페르소나 카드 (Cortex Analyst 질의용)
-- ─────────────────────────────────────────────
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


-- ─────────────────────────────────────────────
-- MART_PREMIUM_SIMULATION
-- 보험료 시뮬레이션 테이블 (Streamlit 대시보드용)
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW MART_PREMIUM_SIMULATION AS
SELECT
    d.DISTRICT_CODE,
    d.DISTRICT_NAME,
    d.YEAR_MONTH,
    d.AVG_MOVABLE_ASSET,
    d.COMPOSITE_RISK_SCORE,
    d.RISK_GRADE,
    d.AVG_CREDIT_SCORE,
    d.ADJUSTED_PREMIUM_MONTHLY,
    -- 보장 금액별 시뮬레이션 (동산가치의 50%, 80%, 100%)
    ROUND(d.ADJUSTED_PREMIUM_MONTHLY * 0.5, 0) AS PREMIUM_50PCT_COVERAGE,
    ROUND(d.ADJUSTED_PREMIUM_MONTHLY * 0.8, 0) AS PREMIUM_80PCT_COVERAGE,
    d.ADJUSTED_PREMIUM_MONTHLY AS PREMIUM_100PCT_COVERAGE,
    -- 연간 보험료
    d.ADJUSTED_PREMIUM_MONTHLY * 12 AS ANNUAL_PREMIUM,
    d.ESTIMATED_ANNUAL_MARKET_KRW
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY d
WHERE d.YEAR_MONTH IS NOT NULL;


SELECT 'MART layer complete' AS status;
