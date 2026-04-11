-- ============================================================
-- 25_EXPAND_REGION_ALL_MONTHS.sql  (v3 — RAW_PUBLIC + Marketplace 통합)
--
-- [기존 문제]
-- v1: 22개 누락 구에 서울 평균 일괄 복사 → 깡통
-- v2: RAW_PUBLIC 프록시만 사용 → 마켓플레이스 미연결
--
-- [v3 개선]
-- FACT_GU_ASSET_PROFILE (카드매출 + 아정당 렌탈 + 유동인구)을
-- 기존 RAW_PUBLIC 프록시와 결합하여 구별 추정 정교화
--
-- 핵심 로직:
--   1) 부동산 평균매매가 → 자산 프록시 (50%)
--   2) FACT_GU_ASSET_PROFILE 자산가액 → 마켓플레이스 자산 프록시 (50%)
--   3) 1인가구 비율·가구수 → 소득·인구 프록시
--   4) 건물노후도 70% + 가전 소비비중 30% → 보험료 가산
--   5) 3개 구 실데이터 분포를 기준 앵커로 사용
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE INSURE_DB;
USE SCHEMA MART;


-- ============================================================
-- STEP 0: 현재 상태 진단
-- ============================================================

-- 0-1) YEAR_MONTH별 구 수 확인
SELECT YEAR_MONTH, COUNT(DISTINCT GU_NAME) AS gu_count
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY YEAR_MONTH
ORDER BY YEAR_MONTH;

-- 0-2) 실제 데이터가 있는 구 목록
SELECT DISTINCT GU_NAME
FROM MART_DISTRICT_INSURANCE_SUMMARY
WHERE DISTRICT_CODE IS NOT NULL
ORDER BY GU_NAME;


-- ============================================================
-- STEP 1: MART_DISTRICT_INSURANCE_SUMMARY 재구축
--         (구별 RAW_PUBLIC 프록시 기반 차등 추정)
-- ============================================================

CREATE OR REPLACE TABLE MART_DISTRICT_INSURANCE_SUMMARY AS
WITH
-- ────────────────────────────────────────────
-- (A) 실제 설계 데이터 (GRANDATA 3개 구)
-- ────────────────────────────────────────────
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
    GROUP BY m.DISTRICT_CODE, dm.DISTRICT_KOR_NAME,
             COALESCE(g.GU_NAME, dm.CITY_KOR_NAME), m.YEAR_MONTH
),

-- ────────────────────────────────────────────
-- (B) 3개 구 월별 기준값 (앵커)
--     22개 구 추정치의 스케일링 기준점
-- ────────────────────────────────────────────
anchor_by_month AS (
    SELECT
        YEAR_MONTH,
        AVG(DISTRICT_AVG_INCOME)  AS anchor_income,
        AVG(DISTRICT_AVG_ASSET)   AS anchor_asset,
        AVG(AVG_MOVABLE_ASSET)    AS anchor_movable,
        MEDIAN(AVG_BASE_PREMIUM)  AS anchor_premium,
        AVG(AVG_CREDIT_SCORE)     AS anchor_credit
    FROM real_data
    WHERE GU_NAME IS NOT NULL
    GROUP BY YEAR_MONTH
),

-- ────────────────────────────────────────────
-- (C) 전체 YEAR_MONTH 목록
-- ────────────────────────────────────────────
all_months AS (
    SELECT DISTINCT YEAR_MONTH FROM real_data WHERE YEAR_MONTH IS NOT NULL
),

-- ────────────────────────────────────────────
-- (D) 25개 구 × 모든 YEAR_MONTH 풀 그리드
-- ────────────────────────────────────────────
full_grid AS (
    SELECT g.GU_NAME, am.YEAR_MONTH
    FROM INSURE_DB.STAGING.GU_CODE_MAPPING g
    CROSS JOIN all_months am
),

-- ────────────────────────────────────────────
-- (E) 실제 데이터가 있는 구+월 조합
-- ────────────────────────────────────────────
covered AS (
    SELECT DISTINCT GU_NAME, YEAR_MONTH
    FROM real_data
    WHERE GU_NAME IS NOT NULL
),

-- ────────────────────────────────────────────
-- (F) 누락된 구+월 조합 (추정 대상)
-- ────────────────────────────────────────────
missing_gu_months AS (
    SELECT fg.GU_NAME, fg.YEAR_MONTH
    FROM full_grid fg
    LEFT JOIN covered c ON fg.GU_NAME = c.GU_NAME AND fg.YEAR_MONTH = c.YEAR_MONTH
    WHERE c.GU_NAME IS NULL
),

-- ────────────────────────────────────────────
-- (G) ★ 구별 프록시 1: 부동산 — 자산 수준 지표
--     avg_apt_price가 높은 구 = 자산·소득 높음
-- ────────────────────────────────────────────
gu_realestate AS (
    SELECT
        DISTRICT_NAME AS GU_NAME,
        AVG(AVG_APT_PRICE_10K) AS avg_apt_price,
        AVG(TOTAL_TRANSACTIONS) AS avg_tx_volume
    FROM INSURE_DB.RAW_PUBLIC.REAL_ESTATE_TRANSACTIONS
    GROUP BY DISTRICT_NAME
),
-- 서울 전체 평균 (정규화 기준)
seoul_re_avg AS (
    SELECT AVG(avg_apt_price) AS seoul_avg_price
    FROM gu_realestate
),
-- 구별 자산 배율: 해당 구 아파트가 / 서울 평균 아파트가
gu_asset_ratio AS (
    SELECT
        r.GU_NAME,
        r.avg_apt_price / NULLIF(s.seoul_avg_price, 0) AS asset_ratio
    FROM gu_realestate r
    CROSS JOIN seoul_re_avg s
),

-- ────────────────────────────────────────────
-- (H) ★ 구별 프록시 2: 1인가구 — 소득·인구 지표
--     1인가구 비율 높으면 → 가구 소득 낮은 경향
--     가구수 → 인구 프록시
-- ────────────────────────────────────────────
gu_household AS (
    SELECT
        DISTRICT_NAME AS GU_NAME,
        AVG(TOTAL_HOUSEHOLDS) AS avg_households,
        AVG(SINGLE_HOUSEHOLD_RATE) AS avg_single_rate
    FROM INSURE_DB.RAW_PUBLIC.SINGLE_HOUSEHOLD
    GROUP BY DISTRICT_NAME
),
seoul_hh_avg AS (
    SELECT
        AVG(avg_single_rate) AS seoul_avg_single_rate,
        AVG(avg_households) AS seoul_avg_hh
    FROM gu_household
),
-- 1인가구 비율이 서울 평균보다 높으면 소득 하향 보정
gu_income_ratio AS (
    SELECT
        h.GU_NAME,
        -- 역비례: 1인가구 비율 높을수록 소득 낮음 (가중치 0.5로 완화)
        1.0 - 0.5 * ((h.avg_single_rate - s.seoul_avg_single_rate) / NULLIF(s.seoul_avg_single_rate, 0))
            AS income_adj_factor,
        h.avg_households
    FROM gu_household h
    CROSS JOIN seoul_hh_avg s
),

-- ────────────────────────────────────────────
-- (I) ★ 구별 프록시 3: 건물 노후도 — 보험료 가산
--     평균 건물연한 높으면 → 리스크↑ → 보험료↑
-- ────────────────────────────────────────────
gu_building AS (
    SELECT
        DISTRICT_NAME AS GU_NAME,
        AVG(AVG_BUILDING_AGE) AS avg_age,
        AVG(TOTAL_BUILDINGS) AS avg_buildings
    FROM INSURE_DB.RAW_PUBLIC.BUILDING_AGE
    GROUP BY DISTRICT_NAME
),
seoul_bld_avg AS (
    SELECT AVG(avg_age) AS seoul_avg_age FROM gu_building
),
-- 건물연한이 서울 평균보다 높으면 보험료 가산
gu_premium_adj AS (
    SELECT
        b.GU_NAME,
        -- 노후 정도에 비례하여 ±15% 범위 보정
        1.0 + 0.15 * ((b.avg_age - s.seoul_avg_age) / NULLIF(s.seoul_avg_age, 0))
            AS premium_age_factor
    FROM gu_building b
    CROSS JOIN seoul_bld_avg s
),

-- ────────────────────────────────────────────
-- (I2) ★ 마켓플레이스 프록시: FACT_GU_ASSET_PROFILE
--      카드매출 + 아정당 렌탈 + 유동인구 기반 구별 자산 프로파일
--      19번, 22번 SQL에서 구축된 데이터 활용
-- ────────────────────────────────────────────
gu_marketplace AS (
    SELECT
        GU_NAME,
        -- 구별 총 추정 자산가액 (6개 카테고리 합산)
        SUM(ESTIMATED_AVG_VALUE) AS total_asset_value,
        -- 구별 가전+전자기기 소비 비중 (보험 핵심 카테고리)
        SUM(CASE WHEN CATEGORY_ID IN (1, 2) THEN CONSUMPTION_RATIO ELSE 0 END) AS electronics_ratio,
        -- 데이터 품질: MEASURED 비율 (실측 데이터 신뢰도)
        AVG(CASE WHEN DATA_QUALITY = 'MEASURED' THEN 1.0 ELSE 0.0 END) AS measured_pct
    FROM INSURE_DB.INTERMEDIATE.FACT_GU_ASSET_PROFILE
    GROUP BY GU_NAME
),
seoul_mp_avg AS (
    SELECT
        AVG(total_asset_value) AS seoul_avg_asset_value,
        AVG(electronics_ratio) AS seoul_avg_elec_ratio
    FROM gu_marketplace
),
-- 마켓플레이스 기반 자산 배율: 해당 구 자산가액 / 서울 평균
gu_mp_ratio AS (
    SELECT
        mp.GU_NAME,
        mp.total_asset_value / NULLIF(sa.seoul_avg_asset_value, 0) AS mp_asset_ratio,
        -- 가전 비중 높으면 동산보험 수요↑ → 보험료 소폭 가산
        1.0 + 0.1 * ((mp.electronics_ratio - sa.seoul_avg_elec_ratio)
                      / NULLIF(sa.seoul_avg_elec_ratio, 0)) AS mp_premium_factor,
        mp.measured_pct
    FROM gu_marketplace mp
    CROSS JOIN seoul_mp_avg sa
),

-- ────────────────────────────────────────────
-- (J) 구별 프록시 통합 (RAW_PUBLIC + 마켓플레이스)
-- ────────────────────────────────────────────
gu_profile AS (
    SELECT
        mg.GU_NAME,
        mg.YEAR_MONTH,
        -- 자산 배율: 부동산 50% + 마켓플레이스 50% 가중 평균
        COALESCE(ar.asset_ratio, 1.0) * 0.5
          + COALESCE(mpr.mp_asset_ratio, 1.0) * 0.5 AS asset_ratio,
        -- 소득 보정 (1인가구 기반) — 기본 1.0
        COALESCE(ir.income_adj_factor, 1.0) AS income_factor,
        -- 보험료 가산: 건물노후 70% + 마켓플레이스 가전비중 30%
        COALESCE(pa.premium_age_factor, 1.0) * 0.7
          + COALESCE(mpr.mp_premium_factor, 1.0) * 0.3 AS premium_age_factor,
        -- 인구 추정: 가구수 × 1.8 (평균 가구원)
        COALESCE(ROUND(ir.avg_households * 1.8), 80000) AS est_population
    FROM missing_gu_months mg
    LEFT JOIN gu_asset_ratio ar ON mg.GU_NAME = ar.GU_NAME
    LEFT JOIN gu_income_ratio ir ON mg.GU_NAME = ir.GU_NAME
    LEFT JOIN gu_premium_adj pa ON mg.GU_NAME = pa.GU_NAME
    LEFT JOIN gu_mp_ratio mpr ON mg.GU_NAME = mpr.GU_NAME
),

-- ────────────────────────────────────────────
-- (K) ★ 핵심: 구별 차등 추정 데이터 생성
--     앵커(3개구 평균) × 구별 프록시 배율
-- ────────────────────────────────────────────
estimated_data AS (
    SELECT
        NULL AS DISTRICT_CODE,
        gp.GU_NAME AS DISTRICT_NAME,
        gp.GU_NAME,
        gp.YEAR_MONTH,

        -- 활성 세그먼트: 인구 규모에 비례 (3~8 범위)
        GREATEST(3, LEAST(8, ROUND(5 * (gp.est_population / 80000.0)))) AS ACTIVE_SEGMENTS,

        -- 인구: 가구 기반 추정
        gp.est_population AS TOTAL_POPULATION,

        -- 소득 = 앵커 × 자산배율(부동산) × 소득보정(1인가구)
        ROUND(anc.anchor_income * gp.asset_ratio * gp.income_factor, 0) AS DISTRICT_AVG_INCOME,

        -- 자산 = 앵커 × 자산배율(부동산)^1.3 (자산은 부동산 가격에 더 민감)
        ROUND(anc.anchor_asset * POWER(gp.asset_ratio, 1.3), 0) AS DISTRICT_AVG_ASSET,

        -- 동산 = 앵커 × 자산배율
        ROUND(anc.anchor_movable * gp.asset_ratio, 0) AS AVG_MOVABLE_ASSET,

        -- 보험료 = 앵커 × 자산배율 × 노후가산
        ROUND(anc.anchor_premium * gp.asset_ratio * gp.premium_age_factor, 0) AS AVG_BASE_PREMIUM,

        -- 신용점수: 자산 높으면 약간 높음 (650~780 범위)
        ROUND(LEAST(780, GREATEST(650,
            anc.anchor_credit * (0.9 + 0.1 * gp.asset_ratio)
        )), 0) AS AVG_CREDIT_SCORE

    FROM gu_profile gp
    JOIN anchor_by_month anc ON gp.YEAR_MONTH = anc.YEAR_MONTH
),

-- ────────────────────────────────────────────
-- (L) 전체 구 통합 (실제 3개 + 추정 22개)
-- ────────────────────────────────────────────
all_districts AS (
    SELECT * FROM real_data WHERE GU_NAME IS NOT NULL
    UNION ALL
    SELECT * FROM estimated_data
),

-- ────────────────────────────────────────────
-- (M) 리스크: 최근 연도 매칭
-- ────────────────────────────────────────────
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

-- ────────────────────────────────────────────
-- (N) 아파트 가격
-- ────────────────────────────────────────────
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

-- ────────────────────────────────────────────
-- (O) 보험료 IQR 기반 상한/하한 (월별)
-- ────────────────────────────────────────────
premium_bounds AS (
    SELECT
        YEAR_MONTH,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY AVG_BASE_PREMIUM) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY AVG_BASE_PREMIUM) AS q3
    FROM all_districts
    GROUP BY YEAR_MONTH
),

-- ────────────────────────────────────────────
-- (P) 최종 조합
-- ────────────────────────────────────────────
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
        -- IQR 클램핑 + 리스크 보정 + 신용 보정
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

-- 3-1) ★ 핵심: YEAR_MONTH별 구 수 (모두 25개여야 함)
SELECT
    YEAR_MONTH,
    COUNT(DISTINCT GU_NAME) AS gu_count,
    ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY), 0) AS avg_premium,
    ROUND(MIN(ADJUSTED_PREMIUM_MONTHLY), 0) AS min_premium,
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY), 0) AS max_premium
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY YEAR_MONTH
ORDER BY YEAR_MONTH;

-- 3-2) ★ 구별 차등 검증 (같은 월에서 구별 보험료가 달라야 함)
SELECT
    GU_NAME,
    ROUND(AVG(DISTRICT_AVG_INCOME), 0) AS avg_income,
    ROUND(AVG(DISTRICT_AVG_ASSET), 0) AS avg_asset,
    ROUND(AVG(AVG_BASE_PREMIUM), 0) AS avg_premium,
    ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY), 0) AS avg_adj_premium,
    ROUND(AVG(AVG_CREDIT_SCORE), 0) AS avg_credit,
    CASE WHEN MAX(DISTRICT_CODE) IS NOT NULL THEN '실데이터' ELSE '추정' END AS data_type
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY GU_NAME
ORDER BY avg_adj_premium DESC;

-- 3-3) 동일값 검증 (같은 보험료 구가 5개 이상이면 여전히 깡통)
SELECT
    YEAR_MONTH,
    ADJUSTED_PREMIUM_MONTHLY AS premium,
    COUNT(*) AS gu_count,
    LISTAGG(GU_NAME, ', ') WITHIN GROUP (ORDER BY GU_NAME) AS gu_list
FROM MART_DISTRICT_INSURANCE_SUMMARY
GROUP BY YEAR_MONTH, ADJUSTED_PREMIUM_MONTHLY
HAVING COUNT(*) >= 5
ORDER BY YEAR_MONTH, gu_count DESC;

-- 3-4) 추정치 범위 합리성 검증
SELECT
    '실데이터' AS type,
    COUNT(*) AS rows,
    ROUND(MIN(ADJUSTED_PREMIUM_MONTHLY), 0) AS min_prem,
    ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY), 0) AS avg_prem,
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY), 0) AS max_prem,
    ROUND(STDDEV(ADJUSTED_PREMIUM_MONTHLY), 0) AS std_prem
FROM MART_DISTRICT_INSURANCE_SUMMARY
WHERE DISTRICT_CODE IS NOT NULL
UNION ALL
SELECT
    '추정' AS type,
    COUNT(*),
    ROUND(MIN(ADJUSTED_PREMIUM_MONTHLY), 0),
    ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY), 0),
    ROUND(MAX(ADJUSTED_PREMIUM_MONTHLY), 0),
    ROUND(STDDEV(ADJUSTED_PREMIUM_MONTHLY), 0)
FROM MART_DISTRICT_INSURANCE_SUMMARY
WHERE DISTRICT_CODE IS NULL;

-- 3-5) 리스크 JOIN 성공 여부
SELECT
    GU_NAME,
    RISK_GRADE,
    COMPOSITE_RISK_SCORE,
    CASE WHEN RISK_GRADE = '미산정' THEN '❌ JOIN 실패' ELSE '✅ 정상' END AS join_status
FROM MART_DISTRICT_INSURANCE_SUMMARY
WHERE YEAR_MONTH = (SELECT MAX(YEAR_MONTH) FROM MART_DISTRICT_INSURANCE_SUMMARY)
ORDER BY GU_NAME;

-- 3-6) ★ 마켓플레이스 연결 검증: FACT_GU_ASSET_PROFILE 데이터 반영 확인
SELECT
    mpr.GU_NAME,
    ROUND(mpr.mp_asset_ratio, 3) AS marketplace_asset_ratio,
    ROUND(mpr.mp_premium_factor, 3) AS marketplace_premium_factor,
    ROUND(mpr.measured_pct * 100, 0) AS measured_pct,
    ROUND(m.ADJUSTED_PREMIUM_MONTHLY, 0) AS final_premium
FROM (
    SELECT
        mp.GU_NAME,
        mp.total_asset_value / NULLIF(sa.seoul_avg_asset_value, 0) AS mp_asset_ratio,
        1.0 + 0.1 * ((mp.electronics_ratio - sa.seoul_avg_elec_ratio)
                      / NULLIF(sa.seoul_avg_elec_ratio, 0)) AS mp_premium_factor,
        mp.measured_pct
    FROM (
        SELECT GU_NAME,
            SUM(ESTIMATED_AVG_VALUE) AS total_asset_value,
            SUM(CASE WHEN CATEGORY_ID IN (1,2) THEN CONSUMPTION_RATIO ELSE 0 END) AS electronics_ratio,
            AVG(CASE WHEN DATA_QUALITY = 'MEASURED' THEN 1.0 ELSE 0.0 END) AS measured_pct
        FROM INSURE_DB.INTERMEDIATE.FACT_GU_ASSET_PROFILE
        GROUP BY GU_NAME
    ) mp
    CROSS JOIN (
        SELECT AVG(total_asset_value) AS seoul_avg_asset_value,
               AVG(electronics_ratio) AS seoul_avg_elec_ratio
        FROM (
            SELECT GU_NAME,
                SUM(ESTIMATED_AVG_VALUE) AS total_asset_value,
                SUM(CASE WHEN CATEGORY_ID IN (1,2) THEN CONSUMPTION_RATIO ELSE 0 END) AS electronics_ratio
            FROM INSURE_DB.INTERMEDIATE.FACT_GU_ASSET_PROFILE
            GROUP BY GU_NAME
        )
    ) sa
) mpr
LEFT JOIN MART_DISTRICT_INSURANCE_SUMMARY m
    ON mpr.GU_NAME = m.GU_NAME
    AND m.YEAR_MONTH = (SELECT MAX(YEAR_MONTH) FROM MART_DISTRICT_INSURANCE_SUMMARY)
ORDER BY mpr.mp_asset_ratio DESC;

SELECT '✅ 25_EXPAND_REGION_ALL_MONTHS.sql (v3 — RAW_PUBLIC + Marketplace 통합) 실행 완료' AS status;
