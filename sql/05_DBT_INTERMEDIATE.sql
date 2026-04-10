-- ============================================================
-- INSURE dbt Layer 2: INTERMEDIATE
-- 세그먼트 분류 + 리스크 스코어 산출
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA INTERMEDIATE;

-- ─────────────────────────────────────────────
-- INT_SEGMENT_CLASSIFICATION
-- 21개 세그먼트 분류 로직 (ASSET_INCOME_INFO 기반)
-- 5개 대분류: A(생애주기), B(자산/소비), C(주거환경), D(직업/활동), E(리스크프로파일)
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE INT_SEGMENT_CLASSIFICATION AS
WITH base AS (
    SELECT * FROM INSURE_DB.STAGING.STG_ASSET_INCOME
),

-- A그룹: 생애주기형 세그먼트
lifecycle_segment AS (
    SELECT *,
        CASE
            WHEN AGE_GROUP IN ('20_24','25_29') THEN 'A1_사회초년생'
            WHEN AGE_GROUP IN ('25_29','30_34') AND MEDIAN_INCOME BETWEEN 25000000 AND 50000000 THEN 'A2_신혼'
            WHEN AGE_GROUP IN ('30_34','35_39') THEN 'A3_영유아가구'
            WHEN AGE_GROUP IN ('35_39','40_44','45_49') THEN 'A4_학령기가구'
            WHEN AGE_GROUP IN ('45_49','50_54','55_59') THEN 'A5_중년안정'
            WHEN AGE_GROUP IN ('60_64','65_69','70_74','75_OVER') THEN 'A6_은퇴시니어'
            ELSE 'A0_미분류'
        END AS SEGMENT_A
    FROM base
),

-- B그룹: 자산/소비형 세그먼트
asset_segment AS (
    SELECT *,
        CASE
            WHEN RATE_HIGH_END > 0.15 OR AVERAGE_ASSET_AMOUNT > 500000000 THEN 'B1_영리치'
            WHEN TOTAL_USAGE_AMOUNT < 500000 AND MEDIAN_INCOME < 30000000 THEN 'B2_알뜰형'
            WHEN ABROAD_SPEND_AMOUNT > 200000 OR RATE_INCOME_OVER_70M > 0.15 THEN 'B3_투자적극형'
            WHEN AVERAGE_ASSET_AMOUNT > 300000000 AND CREDIT_SCORE_AVG > 800 THEN 'B4_고자산보수형'
            WHEN TOTAL_USAGE_AMOUNT > 2000000 AND INSTALLMENT_AMOUNT > 500000 THEN 'B5_소비과다형'
            ELSE 'B0_표준소비형'
        END AS SEGMENT_B
    FROM lifecycle_segment
),

-- C그룹: 주거환경형 세그먼트
housing_segment AS (
    SELECT *,
        CASE
            WHEN LUXURY_UNIT_COUNT > LARGE_UNIT_COUNT AND LUXURY_UNIT_COUNT > MID_UNIT_COUNT THEN 'C1_신축대형'
            WHEN SMALL_UNIT_COUNT > MID_UNIT_COUNT * 2 THEN 'C4_오피스텔원룸'
            WHEN MID_UNIT_COUNT > LARGE_UNIT_COUNT THEN 'C3_중형아파트'
            WHEN LARGE_UNIT_COUNT > 0 THEN 'C2_노후빌라'
            ELSE 'C0_기타주거'
        END AS SEGMENT_C
    FROM asset_segment
),

-- D그룹: 직업/활동형 세그먼트
job_segment AS (
    SELECT *,
        CASE
            WHEN RATE_MODEL_GROUP_SME > 0.20 THEN 'D1_자영업소상공인'
            WHEN RATE_MODEL_GROUP_PROFESSIONAL > 0.15 THEN 'D2_전문직재택'
            WHEN RATE_MODEL_GROUP_LARGE_COMPANY_EMPLOYEE > 0.25 THEN 'D3_대기업밀집지역'
            ELSE 'D0_일반직장인'
        END AS SEGMENT_D
    FROM housing_segment
),

-- E그룹: 리스크 프로파일형 세그먼트
risk_segment AS (
    SELECT *,
        CASE
            WHEN CREDIT_HIGH_RATE > 0.60 AND DELINQUENT_1D_COUNT < 10 THEN 'E1_저위험안정'
            WHEN CREDIT_LOW_RATE > 0.30 OR DELINQUENT_90_COUNT > 50 THEN 'E3_고위험집중'
            ELSE 'E2_중위험표준'
        END AS SEGMENT_E
    FROM job_segment
)

SELECT
    DISTRICT_CODE,
    YEAR_MONTH,
    GENDER,
    AGE_GROUP,
    CUSTOMER_COUNT,
    -- 5개 세그먼트 분류
    SEGMENT_A,
    SEGMENT_B,
    SEGMENT_C,
    SEGMENT_D,
    SEGMENT_E,
    -- 복합 세그먼트 코드 (교차)
    SEGMENT_A || '|' || SEGMENT_B || '|' || SEGMENT_C AS COMPOSITE_SEGMENT,
    -- 원본 피처들 (리스크 산출용)
    MEDIAN_INCOME,
    AVERAGE_ASSET_AMOUNT,
    CREDIT_SCORE_AVG,
    CREDIT_HIGH_RATE,
    CREDIT_LOW_RATE,
    DELINQUENT_1D_COUNT,
    DELINQUENT_90_COUNT,
    AVERAGE_DELINQUENT_AMOUNT,
    TOTAL_USAGE_AMOUNT,
    INSTALLMENT_AMOUNT,
    ABROAD_SPEND_AMOUNT,
    OWN_HOUSING_COUNT,
    MULTIPLE_HOUSING_COUNT,
    SMALL_UNIT_COUNT,
    MID_UNIT_COUNT,
    LARGE_UNIT_COUNT,
    LUXURY_UNIT_COUNT,
    RATE_HIGH_END,
    FULL_PAY_AMOUNT
FROM risk_segment;


-- ─────────────────────────────────────────────
-- INT_DISTRICT_RISK_SCORE
-- 구별 복합 리스크 스코어 (화재+범죄+건물노후+기상+소방)
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE INT_DISTRICT_RISK_SCORE AS
WITH fire_risk AS (
    SELECT
        DISTRICT_NAME,
        YEAR,
        SUM(TOTAL_FIRES) AS total_fires,
        SUM(BUILDING_FIRES) AS building_fires,
        SUM(PROPERTY_DAMAGE_KRW) AS total_damage,
        -- 화재 위험도 (0~100)
        ROUND(
            (SUM(BUILDING_FIRES) / NULLIF(SUM(TOTAL_FIRES), 0)) * 40
            + LEAST(SUM(TOTAL_FIRES) / 250.0 * 30, 30)
            + LEAST(SUM(PROPERTY_DAMAGE_KRW) / 5000000000.0 * 30, 30)
        , 1) AS FIRE_RISK_SCORE
    FROM INSURE_DB.STAGING.STG_FIRE_STATS
    GROUP BY DISTRICT_NAME, YEAR
),

crime_risk AS (
    SELECT
        DISTRICT_NAME,
        YEAR,
        THEFT,
        BURGLARY,
        TOTAL_CRIMES,
        -- 도난 위험도 (0~100): 절도+침입절도 가중
        ROUND(
            LEAST(THEFT / 5000.0 * 50, 50)
            + LEAST(BURGLARY / 500.0 * 30, 30)
            + LEAST(TOTAL_CRIMES / 12000.0 * 20, 20)
        , 1) AS THEFT_RISK_SCORE
    FROM INSURE_DB.STAGING.STG_CRIME_STATS
),

building_risk AS (
    SELECT
        DISTRICT_NAME,
        YEAR,
        AVG_BUILDING_AGE,
        -- 건물 노후 위험도 (0~100)
        ROUND(
            LEAST(AVG_BUILDING_AGE / 40.0 * 40, 40)
            + CASE WHEN AGE_OVER_40Y > 0 THEN LEAST(AGE_OVER_40Y::FLOAT / NULLIF(TOTAL_BUILDINGS, 0) * 100 * 30, 30) ELSE 0 END
            + CASE WHEN WOODEN_BUILDINGS > 0 THEN LEAST(WOODEN_BUILDINGS::FLOAT / NULLIF(TOTAL_BUILDINGS, 0) * 100 * 30, 30) ELSE 0 END
        , 1) AS BUILDING_RISK_SCORE
    FROM INSURE_DB.STAGING.STG_BUILDING_AGE
),

weather_risk_agg AS (
    SELECT
        DISTRICT_NAME,
        LEFT(YEAR_MONTH, 4)::INT AS YEAR,
        AVG(FLOOD_RISK_SCORE) AS AVG_FLOOD_RISK,
        AVG(WIND_RISK_SCORE) AS AVG_WIND_RISK,
        -- 기상 위험도 (0~100)
        ROUND(AVG(FLOOD_RISK_SCORE) * 0.6 + AVG(WIND_RISK_SCORE) * 0.4, 1) AS WEATHER_RISK_SCORE
    FROM INSURE_DB.STAGING.STG_WEATHER_RISK
    GROUP BY DISTRICT_NAME, LEFT(YEAR_MONTH, 4)::INT
),

safety_score AS (
    SELECT
        DISTRICT_NAME,
        YEAR,
        -- 안전 인프라 점수 (0~100, 높을수록 안전)
        ROUND(FIRE_SAFETY_SCORE * 0.5
            + LEAST(FIRE_HYDRANTS / 600.0 * 25, 25)
            + LEAST(FIREFIGHTERS / 350.0 * 25, 25)
        , 1) AS SAFETY_INFRA_SCORE
    FROM INSURE_DB.STAGING.STG_FIRE_FACILITY
),

cctv_score AS (
    SELECT
        DISTRICT_NAME,
        YEAR,
        CCTV_PER_1000_PEOPLE,
        -- CCTV 보안 점수 (0~100)
        ROUND(LEAST(CCTV_PER_1000_PEOPLE / 10.0 * 100, 100), 1) AS CCTV_SECURITY_SCORE
    FROM INSURE_DB.STAGING.STG_CCTV
)

SELECT
    f.DISTRICT_NAME,
    f.YEAR,
    -- 개별 리스크 점수
    f.FIRE_RISK_SCORE,
    c.THEFT_RISK_SCORE,
    b.BUILDING_RISK_SCORE,
    w.WEATHER_RISK_SCORE,
    -- 안전 인프라 (감점 요소)
    s.SAFETY_INFRA_SCORE,
    cc.CCTV_SECURITY_SCORE,
    -- ★ 복합 리스크 스코어 (INSURE 핵심 KPI)
    ROUND(
        f.FIRE_RISK_SCORE * 0.25
        + c.THEFT_RISK_SCORE * 0.25
        + b.BUILDING_RISK_SCORE * 0.20
        + w.WEATHER_RISK_SCORE * 0.15
        - s.SAFETY_INFRA_SCORE * 0.08
        - cc.CCTV_SECURITY_SCORE * 0.07
    , 1) AS COMPOSITE_RISK_SCORE,
    -- 리스크 등급
    CASE
        WHEN (f.FIRE_RISK_SCORE * 0.25 + c.THEFT_RISK_SCORE * 0.25 + b.BUILDING_RISK_SCORE * 0.20
              + w.WEATHER_RISK_SCORE * 0.15 - s.SAFETY_INFRA_SCORE * 0.08 - cc.CCTV_SECURITY_SCORE * 0.07) >= 50
            THEN '고위험'
        WHEN (f.FIRE_RISK_SCORE * 0.25 + c.THEFT_RISK_SCORE * 0.25 + b.BUILDING_RISK_SCORE * 0.20
              + w.WEATHER_RISK_SCORE * 0.15 - s.SAFETY_INFRA_SCORE * 0.08 - cc.CCTV_SECURITY_SCORE * 0.07) >= 30
            THEN '중위험'
        ELSE '저위험'
    END AS RISK_GRADE
FROM fire_risk f
LEFT JOIN crime_risk c ON f.DISTRICT_NAME = c.DISTRICT_NAME AND f.YEAR = c.YEAR
LEFT JOIN building_risk b ON f.DISTRICT_NAME = b.DISTRICT_NAME AND f.YEAR = b.YEAR
LEFT JOIN weather_risk_agg w ON f.DISTRICT_NAME = w.DISTRICT_NAME AND f.YEAR = w.YEAR
LEFT JOIN safety_score s ON f.DISTRICT_NAME = s.DISTRICT_NAME AND f.YEAR = s.YEAR
LEFT JOIN cctv_score cc ON f.DISTRICT_NAME = cc.DISTRICT_NAME AND f.YEAR = cc.YEAR;


-- ─────────────────────────────────────────────
-- INT_MOVING_SIGNAL
-- 이사 신호 감지 (부동산 거래 + 유동인구 변동)
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE INT_MOVING_SIGNAL AS
WITH re AS (
    SELECT
        DISTRICT_NAME,
        YEAR_MONTH,
        TOTAL_TRANSACTIONS,
        MOVING_INDEX,
        APT_JEONSE_COUNT + APT_MONTHLY_RENT_COUNT AS RENTAL_TRANSACTIONS,
        LAG(TOTAL_TRANSACTIONS) OVER (PARTITION BY DISTRICT_NAME ORDER BY YEAR_MONTH) AS PREV_MONTH_TX,
        -- 전월 대비 거래 증가율
        ROUND(
            (TOTAL_TRANSACTIONS - LAG(TOTAL_TRANSACTIONS) OVER (PARTITION BY DISTRICT_NAME ORDER BY YEAR_MONTH))
            / NULLIF(LAG(TOTAL_TRANSACTIONS) OVER (PARTITION BY DISTRICT_NAME ORDER BY YEAR_MONTH), 0) * 100
        , 1) AS TX_GROWTH_RATE
    FROM INSURE_DB.STAGING.STG_REAL_ESTATE
),
moving AS (
    SELECT
        DISTRICT_NAME,
        YEAR_MONTH,
        TOTAL_TRANSACTIONS,
        RENTAL_TRANSACTIONS,
        TX_GROWTH_RATE,
        MOVING_INDEX,
        -- 이사 신호 강도 (0~100)
        ROUND(
            LEAST(ABS(COALESCE(TX_GROWTH_RATE, 0)) * 2, 40)
            + CASE WHEN RENTAL_TRANSACTIONS > 400 THEN 30 WHEN RENTAL_TRANSACTIONS > 250 THEN 20 ELSE 10 END
            + CASE WHEN MOVING_INDEX > 10 THEN 30 WHEN MOVING_INDEX > 5 THEN 20 WHEN MOVING_INDEX > 0 THEN 10 ELSE 0 END
        , 1) AS MOVING_SIGNAL_SCORE,
        CASE
            WHEN ABS(COALESCE(TX_GROWTH_RATE, 0)) > 15 THEN '급변동'
            WHEN ABS(COALESCE(TX_GROWTH_RATE, 0)) > 8 THEN '활발'
            ELSE '안정'
        END AS MOVING_STATUS
    FROM re
)
SELECT * FROM moving;


-- ─────────────────────────────────────────────
-- INT_CREDIT_RISK_PROFILE
-- 구별 신용 리스크 프로파일 (신규 인사이트 1,2 반영)
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW INT_CREDIT_RISK_PROFILE AS
SELECT
    DISTRICT_CODE,
    YEAR_MONTH,
    -- 구별 평균 신용점수
    AVG(CREDIT_SCORE_AVG) AS AVG_CREDIT_SCORE,
    -- 신용 등급 분포
    AVG(CREDIT_HIGH_RATE) AS HIGH_CREDIT_RATE,
    AVG(CREDIT_LOW_RATE) AS LOW_CREDIT_RATE,
    -- 연체 현황
    SUM(DELINQUENT_1D_COUNT) AS TOTAL_DELINQUENT_1D,
    SUM(DELINQUENT_90_COUNT) AS TOTAL_DELINQUENT_90D,
    AVG(AVERAGE_DELINQUENT_AMOUNT) AS AVG_DELINQUENT_AMT,
    -- ★ 인사이트1: 신용점수 기반 보험료 조정 계수
    CASE
        WHEN AVG(CREDIT_SCORE_AVG) >= 850 THEN 0.85  -- 15% 할인
        WHEN AVG(CREDIT_SCORE_AVG) >= 750 THEN 0.95  -- 5% 할인
        WHEN AVG(CREDIT_SCORE_AVG) >= 650 THEN 1.00  -- 기본
        WHEN AVG(CREDIT_SCORE_AVG) >= 550 THEN 1.10  -- 10% 할증
        ELSE 1.25  -- 25% 할증
    END AS PREMIUM_CREDIT_FACTOR,
    -- ★ 인사이트2: 연체율 = 해지 리스크 프록시
    CASE
        WHEN SUM(DELINQUENT_90_COUNT) > 100 THEN '고해지위험'
        WHEN SUM(DELINQUENT_90_COUNT) > 30 THEN '중해지위험'
        ELSE '저해지위험'
    END AS CHURN_RISK_GRADE,
    -- 해지 리스크 스코어 (0~100)
    ROUND(
        LEAST(SUM(DELINQUENT_90_COUNT) / 200.0 * 50, 50)
        + LEAST(AVG(AVERAGE_DELINQUENT_AMOUNT) / 5000000.0 * 30, 30)
        + (1 - AVG(CREDIT_HIGH_RATE)) * 20
    , 1) AS CHURN_RISK_SCORE
FROM INSURE_DB.STAGING.STG_ASSET_INCOME
GROUP BY DISTRICT_CODE, YEAR_MONTH;


-- ─────────────────────────────────────────────
-- INT_CROSS_SELL_OPPORTUNITY
-- 크로스셀 기회 (인사이트 3: 해외카드=여행자보험, 인사이트 4: 다주택/무주택)
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW INT_CROSS_SELL_OPPORTUNITY AS
SELECT
    DISTRICT_CODE,
    YEAR_MONTH,
    -- ★ 인사이트3: 해외소비 활발 → 여행자보험 번들
    AVG(ABROAD_SPEND_AMOUNT) AS AVG_ABROAD_SPEND,
    CASE
        WHEN AVG(ABROAD_SPEND_AMOUNT) > 300000 THEN '여행자보험_강추'
        WHEN AVG(ABROAD_SPEND_AMOUNT) > 100000 THEN '여행자보험_추천'
        ELSE '해당없음'
    END AS TRAVEL_INSURANCE_FLAG,
    -- ★ 인사이트4: 다주택 vs 무주택 양극화
    AVG(OWN_HOUSING_COUNT) AS AVG_OWN_HOUSING,
    AVG(MULTIPLE_HOUSING_COUNT) AS AVG_MULTI_HOUSING,
    CASE
        WHEN AVG(OWN_HOUSING_COUNT) < 50 THEN '무주택_임차인_패키지'      -- 동산보험 절실
        WHEN AVG(MULTIPLE_HOUSING_COUNT) > 30 THEN '다주택자_임대인_패키지'  -- 임대물건 보험
        ELSE '자가_표준_패키지'
    END AS HOUSING_INSURANCE_TYPE,
    -- ★ 인사이트5: 할부비율 → 가전 보유 패턴
    AVG(INSTALLMENT_AMOUNT) AS AVG_INSTALLMENT,
    AVG(FULL_PAY_AMOUNT) AS AVG_FULL_PAY,
    CASE
        WHEN AVG(INSTALLMENT_AMOUNT) > AVG(FULL_PAY_AMOUNT) * 0.5 THEN '고가가전_보유추정'
        ELSE '일반가전_보유추정'
    END AS APPLIANCE_VALUE_FLAG,
    -- 크로스셀 점수
    ROUND(
        CASE WHEN AVG(ABROAD_SPEND_AMOUNT) > 100000 THEN 30 ELSE 0 END
        + CASE WHEN AVG(INSTALLMENT_AMOUNT) > 300000 THEN 25 ELSE 10 END
        + CASE WHEN AVG(OWN_HOUSING_COUNT) < 50 THEN 25 WHEN AVG(MULTIPLE_HOUSING_COUNT) > 30 THEN 20 ELSE 10 END
    , 1) AS CROSS_SELL_SCORE
FROM INSURE_DB.STAGING.STG_ASSET_INCOME
GROUP BY DISTRICT_CODE, YEAR_MONTH;


SELECT 'INTERMEDIATE layer complete' AS status;
