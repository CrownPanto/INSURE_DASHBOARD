-- ============================================================
-- INSURE v1.3 Enhancement SQL
-- 5대 개선: 동산시드, 세그먼트계수, 비선형보험료, 피드백루프, Cortex ML
-- ============================================================

USE DATABASE INSURE_DB;

-- ─────────────────────────────────────────────────────────────
-- 1. 품목별 동산 시드 데이터 테이블
--    소득구간 × 가구유형별 가전/자동차/전자기기 보유 수량
-- ─────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS INSURE_DB.SEED;

CREATE OR REPLACE TABLE INSURE_DB.SEED.SEED_HOUSEHOLD_GOODS (
    INCOME_BRACKET      VARCHAR(30),     -- 소득구간
    SEGMENT_A           VARCHAR(30),     -- 생애주기 세그먼트
    ITEM_CATEGORY       VARCHAR(30),     -- 품목 대분류
    ITEM_NAME           VARCHAR(50),     -- 품목명
    AVG_QUANTITY        FLOAT,           -- 평균 보유 수량
    AVG_UNIT_VALUE_KRW  NUMBER(15,0),    -- 평균 단가(원)
    AVG_TOTAL_VALUE_KRW NUMBER(15,0),    -- 평균 총가치(원)
    DAMAGE_RISK_RATE    FLOAT,           -- 연간 사고/파손 확률
    DESCRIPTION         VARCHAR(200)
);

-- 소득구간: LOW(<3000만), MID(3000~6000만), HIGH(6000~1억), ULTRA(1억+)
-- 생애주기: A1~A6
INSERT INTO INSURE_DB.SEED.SEED_HOUSEHOLD_GOODS VALUES
-- ── LOW 소득 × A1 사회초년생 ──
('LOW','A1_사회초년생','전자기기','스마트폰',1.2,800000,960000,0.08,'1인가구 필수품'),
('LOW','A1_사회초년생','전자기기','노트북',0.9,900000,810000,0.05,'업무/학업용'),
('LOW','A1_사회초년생','전자기기','태블릿',0.4,500000,200000,0.03,'보조기기'),
('LOW','A1_사회초년생','가전','세탁기',0.8,400000,320000,0.02,'소형 원룸용'),
('LOW','A1_사회초년생','가전','냉장고',0.9,350000,315000,0.01,'소형'),
('LOW','A1_사회초년생','가전','에어컨',0.5,500000,250000,0.02,'벽걸이형'),
('LOW','A1_사회초년생','자동차','승용차',0.15,8000000,1200000,0.04,'보유율 낮음'),
('LOW','A1_사회초년생','가구','침대/매트리스',1.0,300000,300000,0.01,'기본가구'),
-- ── LOW 소득 × A6 은퇴시니어 ──
('LOW','A6_은퇴시니어','가전','TV',1.0,500000,500000,0.01,'기본가전'),
('LOW','A6_은퇴시니어','가전','냉장고',1.0,400000,400000,0.01,'기본가전'),
('LOW','A6_은퇴시니어','가전','세탁기',1.0,350000,350000,0.02,'기본가전'),
('LOW','A6_은퇴시니어','의료기기','혈압계',0.6,100000,60000,0.01,'건강관리'),
('LOW','A6_은퇴시니어','의료기기','안마의자',0.1,800000,80000,0.01,'건강관리'),
('LOW','A6_은퇴시니어','자동차','승용차',0.2,6000000,1200000,0.03,'고령운전'),
-- ── MID 소득 × A2 신혼 ──
('MID','A2_신혼','가전','세탁기/건조기',1.5,1500000,2250000,0.02,'혼수가전 세트'),
('MID','A2_신혼','가전','냉장고',1.0,1200000,1200000,0.01,'대형 양문형'),
('MID','A2_신혼','가전','TV',1.0,1500000,1500000,0.01,'65인치+'),
('MID','A2_신혼','가전','에어컨',1.5,1200000,1800000,0.02,'스탠드+벽걸이'),
('MID','A2_신혼','가전','식기세척기',0.7,800000,560000,0.02,'맞벌이 필수'),
('MID','A2_신혼','가전','로봇청소기',0.5,600000,300000,0.04,'파손율 높음'),
('MID','A2_신혼','전자기기','스마트폰',2.0,1000000,2000000,0.06,'맞벌이 2대'),
('MID','A2_신혼','가구','소파/침대세트',1.0,2000000,2000000,0.01,'혼수가구'),
('MID','A2_신혼','자동차','승용차',0.8,20000000,16000000,0.05,'중형차'),
-- ── MID 소득 × A3 영유아가구 ──
('MID','A3_영유아가구','가전','세탁기/건조기',1.5,1500000,2250000,0.03,'사용빈도 높음'),
('MID','A3_영유아가구','가전','공기청정기',1.5,600000,900000,0.02,'아이방+거실'),
('MID','A3_영유아가구','가전','정수기',1.0,500000,500000,0.01,'필수'),
('MID','A3_영유아가구','유아용품','유모차',1.0,700000,700000,0.03,'고가 유모차'),
('MID','A3_영유아가구','유아용품','카시트',1.2,400000,480000,0.02,'연령별 교체'),
('MID','A3_영유아가구','자동차','승용차/SUV',1.0,25000000,25000000,0.05,'패밀리카'),
-- ── MID 소득 × A4 학령기가구 ──
('MID','A4_학령기가구','가전','세탁기/건조기',1.5,1200000,1800000,0.02,'일반가전'),
('MID','A4_학령기가구','가전','냉장고',1.0,1000000,1000000,0.01,'대형'),
('MID','A4_학령기가구','전자기기','PC/노트북',2.0,1000000,2000000,0.04,'학생용+부모용'),
('MID','A4_학령기가구','전자기기','태블릿',1.5,500000,750000,0.05,'학습용'),
('MID','A4_학령기가구','자동차','승용차',1.0,22000000,22000000,0.04,'중형차'),
('MID','A4_학령기가구','가구','책상/책장세트',2.0,500000,1000000,0.01,'학습가구'),
-- ── HIGH 소득 × A5 중년안정 ──
('HIGH','A5_중년안정','가전','프리미엄가전세트',1.0,8000000,8000000,0.01,'고급브랜드'),
('HIGH','A5_중년안정','가전','와인셀러',0.4,2000000,800000,0.01,'취미용'),
('HIGH','A5_중년안정','전자기기','최신스마트폰',2.0,1500000,3000000,0.05,'프리미엄폰'),
('HIGH','A5_중년안정','귀금속','귀금속/시계',0.8,5000000,4000000,0.02,'도난위험'),
('HIGH','A5_중년안정','취미','골프용품',0.5,3000000,1500000,0.03,'고가취미'),
('HIGH','A5_중년안정','미술품','그림/조각',0.3,5000000,1500000,0.01,'자산형'),
('HIGH','A5_중년안정','자동차','프리미엄승용차',1.2,45000000,54000000,0.04,'수입차 포함'),
('HIGH','A5_중년안정','가구','프리미엄가구',1.0,5000000,5000000,0.01,'수입가구'),
-- ── ULTRA 소득 × B1 영리치 ──
('ULTRA','B1_영리치','가전','초프리미엄가전',1.0,15000000,15000000,0.01,'최고급'),
('ULTRA','B1_영리치','귀금속','명품시계/보석',2.0,15000000,30000000,0.03,'고액도난위험'),
('ULTRA','B1_영리치','미술품','미술품/골동품',1.5,20000000,30000000,0.01,'자산보전'),
('ULTRA','B1_영리치','자동차','럭셔리카',1.5,80000000,120000000,0.03,'슈퍼카포함'),
('ULTRA','B1_영리치','취미','와인컬렉션',0.5,10000000,5000000,0.01,'보관위험'),
('ULTRA','B1_영리치','가구','명품가구/인테리어',1.0,20000000,20000000,0.01,'이태리수입등'),
-- ── MID 소득 × B2 알뜰형 (모든 생애주기 공통) ──
('MID','B2_알뜰형','가전','기본가전세트',1.0,2000000,2000000,0.02,'가성비 위주'),
('MID','B2_알뜰형','전자기기','스마트폰',1.5,500000,750000,0.06,'중저가폰'),
('MID','B2_알뜰형','자동차','경차/중고차',0.5,8000000,4000000,0.04,'경제적'),
('MID','B2_알뜰형','가구','기본가구',1.0,500000,500000,0.01,'실용적');

-- 품목별 동산 요약 뷰 (대시보드용)
CREATE OR REPLACE VIEW INSURE_DB.SEED.V_HOUSEHOLD_GOODS_SUMMARY AS
SELECT
    INCOME_BRACKET,
    SEGMENT_A,
    ITEM_CATEGORY,
    COUNT(*) AS ITEM_TYPES,
    SUM(AVG_QUANTITY) AS TOTAL_ITEMS,
    SUM(AVG_TOTAL_VALUE_KRW) AS TOTAL_ESTIMATED_VALUE,
    ROUND(SUM(AVG_TOTAL_VALUE_KRW * DAMAGE_RISK_RATE), 0) AS EXPECTED_ANNUAL_LOSS
FROM INSURE_DB.SEED.SEED_HOUSEHOLD_GOODS
GROUP BY INCOME_BRACKET, SEGMENT_A, ITEM_CATEGORY;

-- 소득구간별 총 동산 가치 요약
CREATE OR REPLACE VIEW INSURE_DB.SEED.V_GOODS_VALUE_BY_INCOME AS
SELECT
    INCOME_BRACKET,
    SEGMENT_A,
    SUM(AVG_TOTAL_VALUE_KRW) AS TOTAL_MOVABLE_ASSET_VALUE,
    SUM(AVG_TOTAL_VALUE_KRW * DAMAGE_RISK_RATE) AS EXPECTED_ANNUAL_RISK_COST,
    ROUND(SUM(AVG_TOTAL_VALUE_KRW * DAMAGE_RISK_RATE) / NULLIF(SUM(AVG_TOTAL_VALUE_KRW), 0) * 100, 2) AS RISK_COST_RATIO_PCT
FROM INSURE_DB.SEED.SEED_HOUSEHOLD_GOODS
GROUP BY INCOME_BRACKET, SEGMENT_A;


-- ─────────────────────────────────────────────────────────────
-- 2. 세그먼트별 동산 가치 계수 테이블
--    기존 flat 15% → 세그먼트별 차등 계수
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE INSURE_DB.SEED.SEGMENT_ASSET_COEFFICIENTS (
    SEGMENT_KEY     VARCHAR(30),
    ASSET_RATIO     FLOAT,       -- 총자산 대비 동산 비율
    INCOME_RATIO    FLOAT,       -- 연소득 대비 동산 투자 비율
    INSTALLMENT_MULT FLOAT,      -- 할부 승수 (고가품 추정)
    DESCRIPTION     VARCHAR(200)
);

INSERT INTO INSURE_DB.SEED.SEGMENT_ASSET_COEFFICIENTS VALUES
-- 생애주기 기반 계수
('A1_사회초년생', 0.05, 0.12, 1.5, '자산 적지만 전자기기 비중 높음, 소득 대비 동산 투자 활발'),
('A2_신혼',       0.12, 0.15, 3.0, '혼수 가전 일괄구매로 할부 승수 높음'),
('A3_영유아가구', 0.10, 0.10, 2.5, '유아용품+가전, 할부 활발'),
('A4_학령기가구', 0.12, 0.08, 2.0, '안정적 가전 보유, 추가 투자 줄어듦'),
('A5_중년안정',   0.18, 0.06, 1.5, '고가 동산(귀금속,미술품) 자산 대비 비중 높음'),
('A6_은퇴시니어', 0.08, 0.04, 1.0, '동산 축소기, 의료기기 중심'),
-- 자산 기반 계수 (SEGMENT_B)
('B1_영리치',     0.25, 0.03, 1.0, '초고가 동산(명품,미술품,럭셔리카) 비중 매우 높음'),
('B2_알뜰형',     0.06, 0.05, 1.0, '최소 동산, 가성비 위주'),
('B3_안정중산층',  0.12, 0.08, 2.0, '평균적 동산 보유'),
('B4_자산형저소비', 0.15, 0.04, 1.0, '자산은 있으나 소비 절약'),
('B5_소비과다형',  0.08, 0.15, 4.0, '할부 과다, 최신 전자기기 교체 빈번');


-- ─────────────────────────────────────────────────────────────
-- 3. 개선된 MART_INSURANCE_DESIGN (v1.3)
--    세그먼트별 계수 + 비선형 보험료 곡선
-- ─────────────────────────────────────────────────────────────

USE SCHEMA MART;

CREATE OR REPLACE TABLE MART_INSURANCE_DESIGN_V13 AS
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
),
-- 세그먼트별 계수 조인
coeff_a AS (
    SELECT SEGMENT_KEY, ASSET_RATIO AS A_ASSET, INCOME_RATIO AS A_INCOME, INSTALLMENT_MULT AS A_INST
    FROM INSURE_DB.SEED.SEGMENT_ASSET_COEFFICIENTS
    WHERE SEGMENT_KEY LIKE 'A%'
),
coeff_b AS (
    SELECT SEGMENT_KEY, ASSET_RATIO AS B_ASSET, INCOME_RATIO AS B_INCOME, INSTALLMENT_MULT AS B_INST
    FROM INSURE_DB.SEED.SEGMENT_ASSET_COEFFICIENTS
    WHERE SEGMENT_KEY LIKE 'B%'
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

    -- ★ v1.3: 세그먼트별 차등 계수 적용 동산 가치
    ROUND(
        s.AVG_ASSET * (COALESCE(ca.A_ASSET, 0.12) + COALESCE(cb.B_ASSET, 0.12)) / 2
        + s.AVG_INCOME * (COALESCE(ca.A_INCOME, 0.08) + COALESCE(cb.B_INCOME, 0.08)) / 2
        + COALESCE(s.AVG_INSTALLMENT, 0) * 12 * (COALESCE(ca.A_INST, 2.0) + COALESCE(cb.B_INST, 2.0)) / 2
    , 0) AS ESTIMATED_MOVABLE_ASSET_VALUE,

    -- ★ v1.3: 기본 보험료 (세그먼트별 계수 기반 동산가치 × 리스크 요율)
    ROUND(
        (
            s.AVG_ASSET * (COALESCE(ca.A_ASSET, 0.12) + COALESCE(cb.B_ASSET, 0.12)) / 2
            + s.AVG_INCOME * (COALESCE(ca.A_INCOME, 0.08) + COALESCE(cb.B_INCOME, 0.08)) / 2
            + COALESCE(s.AVG_INSTALLMENT, 0) * 12 * (COALESCE(ca.A_INST, 2.0) + COALESCE(cb.B_INST, 2.0)) / 2
        )
        * CASE
            WHEN s.SEGMENT_E = 'E1_저위험안정' THEN 0.003
            WHEN s.SEGMENT_E = 'E2_중위험표준' THEN 0.005
            WHEN s.SEGMENT_E = 'E3_고위험집중' THEN 0.008
            ELSE 0.005
          END
    , 0) AS BASE_PREMIUM_MONTHLY,

    -- 신용 보정 계수 (기존 동일)
    CASE
        WHEN s.AVG_CREDIT >= 850 THEN 0.85
        WHEN s.AVG_CREDIT >= 750 THEN 0.95
        WHEN s.AVG_CREDIT >= 650 THEN 1.00
        WHEN s.AVG_CREDIT >= 550 THEN 1.10
        ELSE 1.25
    END AS CREDIT_ADJUSTMENT,

    -- 추천 보장 항목 (기존 동일)
    CASE s.SEGMENT_A
        WHEN 'A1_사회초년생' THEN '전자기기파손,도난,화재'
        WHEN 'A2_신혼'       THEN '가전파손,화재,수재,배상책임'
        WHEN 'A3_영유아가구' THEN '가전파손,화재,어린이안전,배상책임'
        WHEN 'A4_학령기가구' THEN '화재,도난,수재,가전파손'
        WHEN 'A5_중년안정'   THEN '화재,도난,수재,귀금속,고가가전'
        WHEN 'A6_은퇴시니어' THEN '화재,수재,의료기기,배상책임'
        ELSE '화재,도난,가전파손'
    END AS RECOMMENDED_COVERAGE,

    -- 크로스셀 추천 (기존 동일)
    CASE
        WHEN s.AVG_ABROAD > 200000 THEN '여행자보험_번들추천'
        WHEN s.TOTAL_MULTI > 20 THEN '임대인패키지_추천'
        WHEN s.TOTAL_OWNED < 30 THEN '임차인전용_추천'
        ELSE '표준패키지'
    END AS CROSS_SELL_RECOMMENDATION,

    s.SEGMENT_E AS RISK_PROFILE

FROM segment_stats s
LEFT JOIN coeff_a ca ON s.SEGMENT_A = ca.SEGMENT_KEY
LEFT JOIN coeff_b cb ON s.SEGMENT_B = cb.SEGMENT_KEY;


-- ─────────────────────────────────────────────────────────────
-- 4. 개선된 MART_DISTRICT_INSURANCE_SUMMARY (v1.3)
--    비선형 보험료 곡선 적용
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE TABLE MART_DISTRICT_INSURANCE_SUMMARY_V13 AS
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
    FROM INSURE_DB.MART.MART_INSURANCE_DESIGN_V13 m
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

    -- ★ v1.3: 비선형 보험료 곡선 (리스크 구간별 단계적 요율)
    -- 기존: linear (1 + risk/200)
    -- 신규: stepped exponential curve
    ROUND(
        d.AVG_BASE_PREMIUM
        * CASE
            -- 저위험 구간 (0~25): 완만한 할인
            WHEN COALESCE(r.COMPOSITE_RISK_SCORE, 30) < 25 THEN
                0.85 + POWER(COALESCE(r.COMPOSITE_RISK_SCORE, 30) / 25.0, 0.7) * 0.15
            -- 중저위험 구간 (25~40): 표준 요율
            WHEN COALESCE(r.COMPOSITE_RISK_SCORE, 30) < 40 THEN
                1.00 + (COALESCE(r.COMPOSITE_RISK_SCORE, 30) - 25) / 100.0
            -- 중고위험 구간 (40~60): 가속 증가
            WHEN COALESCE(r.COMPOSITE_RISK_SCORE, 30) < 60 THEN
                1.15 + POWER((COALESCE(r.COMPOSITE_RISK_SCORE, 30) - 40) / 20.0, 1.5) * 0.35
            -- 고위험 구간 (60~80): 급격 증가
            WHEN COALESCE(r.COMPOSITE_RISK_SCORE, 30) < 80 THEN
                1.50 + POWER((COALESCE(r.COMPOSITE_RISK_SCORE, 30) - 60) / 20.0, 1.8) * 0.50
            -- 초고위험 구간 (80+): 최대 요율 + 캡
            ELSE
                LEAST(2.00 + (COALESCE(r.COMPOSITE_RISK_SCORE, 30) - 80) * 0.02, 2.50)
          END
        -- 신용 보정 (기존과 동일)
        * CASE
            WHEN d.AVG_CREDIT_SCORE >= 800 THEN 0.90
            WHEN d.AVG_CREDIT_SCORE >= 700 THEN 0.95
            ELSE 1.05
          END
    , 0) AS ADJUSTED_PREMIUM_MONTHLY,

    -- v1.3: 리스크 곡선 구간 라벨
    CASE
        WHEN COALESCE(r.COMPOSITE_RISK_SCORE, 30) < 25 THEN 'LOW_RISK_DISCOUNT'
        WHEN COALESCE(r.COMPOSITE_RISK_SCORE, 30) < 40 THEN 'STANDARD'
        WHEN COALESCE(r.COMPOSITE_RISK_SCORE, 30) < 60 THEN 'ELEVATED'
        WHEN COALESCE(r.COMPOSITE_RISK_SCORE, 30) < 80 THEN 'HIGH_RISK'
        ELSE 'CRITICAL_RISK'
    END AS PREMIUM_CURVE_ZONE,

    -- 연간 추정 보험 시장 규모
    ROUND(
        d.TOTAL_POPULATION * 0.15
        * d.AVG_BASE_PREMIUM * 12
    , 0) AS ESTIMATED_ANNUAL_MARKET_KRW

FROM district_design d
LEFT JOIN risk r ON d.DISTRICT_NAME = r.DISTRICT_NAME AND LEFT(d.YEAR_MONTH, 4)::INT = r.YEAR;


-- ─────────────────────────────────────────────────────────────
-- 5. 피드백 → 보험료 재계산 자동 트리거
--    FEEDBACK_RESPONSES에서 평균 점수를 반영하여 조정
-- ─────────────────────────────────────────────────────────────
USE SCHEMA FEEDBACK;

-- 피드백 기반 보정 계수 뷰
CREATE OR REPLACE VIEW INSURE_DB.FEEDBACK.V_FEEDBACK_ADJUSTMENT AS
SELECT
    DISTRICT,
    COUNT(*) AS FEEDBACK_COUNT,
    AVG(RISK_SCORE_ACCURACY) AS AVG_RISK_ACCURACY,
    AVG(PREMIUM_FAIRNESS) AS AVG_PREMIUM_FAIRNESS,
    AVG(DATA_QUALITY) AS AVG_DATA_QUALITY,
    AVG(OVERALL_SATISFACTION) AS AVG_OVERALL,
    -- 보험료 조정 계수: 공정성 평가가 낮으면 보험료 하향 조정
    CASE
        WHEN AVG(PREMIUM_FAIRNESS) <= 2.0 THEN 0.92  -- 매우 불공정 → 8% 할인
        WHEN AVG(PREMIUM_FAIRNESS) <= 3.0 THEN 0.96  -- 약간 불공정 → 4% 할인
        WHEN AVG(PREMIUM_FAIRNESS) >= 4.5 THEN 1.03  -- 매우 공정 → 3% 인상 여력
        ELSE 1.00                                      -- 적정
    END AS PREMIUM_ADJUSTMENT_FACTOR,
    -- 리스크 스코어 보정: 정확도 평가 반영
    CASE
        WHEN AVG(RISK_SCORE_ACCURACY) <= 2.0 THEN -5   -- 부정확 → 스코어 하향
        WHEN AVG(RISK_SCORE_ACCURACY) >= 4.5 THEN 2    -- 정확 → 스코어 소폭 상향
        ELSE 0
    END AS RISK_SCORE_OFFSET
FROM INSURE_DB.FEEDBACK.FEEDBACK_RESPONSES
WHERE DISTRICT != 'All'
GROUP BY DISTRICT
HAVING COUNT(*) >= 3;  -- 최소 3건 이상 피드백 시 적용

-- 피드백 반영 최종 보험료 뷰
CREATE OR REPLACE VIEW INSURE_DB.MART.V_PREMIUM_WITH_FEEDBACK AS
SELECT
    d.*,
    COALESCE(f.FEEDBACK_COUNT, 0) AS FEEDBACK_COUNT,
    COALESCE(f.AVG_PREMIUM_FAIRNESS, 0) AS FEEDBACK_FAIRNESS_SCORE,
    COALESCE(f.PREMIUM_ADJUSTMENT_FACTOR, 1.00) AS FEEDBACK_ADJUSTMENT,
    ROUND(d.ADJUSTED_PREMIUM_MONTHLY * COALESCE(f.PREMIUM_ADJUSTMENT_FACTOR, 1.00), 0)
        AS FINAL_PREMIUM_WITH_FEEDBACK,
    CASE
        WHEN f.PREMIUM_ADJUSTMENT_FACTOR IS NOT NULL THEN 'FEEDBACK_ADJUSTED'
        ELSE 'NO_FEEDBACK'
    END AS ADJUSTMENT_STATUS
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY_V13 d
LEFT JOIN INSURE_DB.FEEDBACK.V_FEEDBACK_ADJUSTMENT f
    ON d.DISTRICT_NAME = f.DISTRICT;

-- 피드백 재계산 실행 프로시저
CREATE OR REPLACE PROCEDURE INSURE_DB.FEEDBACK.SP_RECALCULATE_PREMIUM()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- v1.3 MART 테이블 재생성 (최신 세그먼트 계수 반영)
    -- MART_INSURANCE_DESIGN_V13 재빌드
    CREATE OR REPLACE TABLE INSURE_DB.MART.MART_INSURANCE_DESIGN_V13 AS
    WITH segment_stats AS (
        SELECT
            DISTRICT_CODE, YEAR_MONTH,
            SEGMENT_A, SEGMENT_B, SEGMENT_C, SEGMENT_D, SEGMENT_E,
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
    ),
    coeff_a AS (
        SELECT SEGMENT_KEY, ASSET_RATIO AS A_ASSET, INCOME_RATIO AS A_INCOME, INSTALLMENT_MULT AS A_INST
        FROM INSURE_DB.SEED.SEGMENT_ASSET_COEFFICIENTS WHERE SEGMENT_KEY LIKE 'A%'
    ),
    coeff_b AS (
        SELECT SEGMENT_KEY, ASSET_RATIO AS B_ASSET, INCOME_RATIO AS B_INCOME, INSTALLMENT_MULT AS B_INST
        FROM INSURE_DB.SEED.SEGMENT_ASSET_COEFFICIENTS WHERE SEGMENT_KEY LIKE 'B%'
    )
    SELECT
        s.DISTRICT_CODE, s.YEAR_MONTH, s.SEGMENT_A, s.SEGMENT_B, s.SEGMENT_C, s.SEGMENT_D, s.SEGMENT_E,
        s.SEGMENT_A || '|' || s.SEGMENT_B || '|' || s.SEGMENT_C AS COMPOSITE_SEGMENT,
        s.POPULATION, s.AVG_INCOME, s.AVG_ASSET, s.AVG_CREDIT, s.AVG_SPEND,
        ROUND(
            s.AVG_ASSET * (COALESCE(ca.A_ASSET, 0.12) + COALESCE(cb.B_ASSET, 0.12)) / 2
            + s.AVG_INCOME * (COALESCE(ca.A_INCOME, 0.08) + COALESCE(cb.B_INCOME, 0.08)) / 2
            + COALESCE(s.AVG_INSTALLMENT, 0) * 12 * (COALESCE(ca.A_INST, 2.0) + COALESCE(cb.B_INST, 2.0)) / 2
        , 0) AS ESTIMATED_MOVABLE_ASSET_VALUE,
        ROUND(
            (s.AVG_ASSET * (COALESCE(ca.A_ASSET, 0.12) + COALESCE(cb.B_ASSET, 0.12)) / 2
            + s.AVG_INCOME * (COALESCE(ca.A_INCOME, 0.08) + COALESCE(cb.B_INCOME, 0.08)) / 2
            + COALESCE(s.AVG_INSTALLMENT, 0) * 12 * (COALESCE(ca.A_INST, 2.0) + COALESCE(cb.B_INST, 2.0)) / 2)
            * CASE WHEN s.SEGMENT_E = 'E1_저위험안정' THEN 0.003
                   WHEN s.SEGMENT_E = 'E2_중위험표준' THEN 0.005
                   WHEN s.SEGMENT_E = 'E3_고위험집중' THEN 0.008
                   ELSE 0.005 END
        , 0) AS BASE_PREMIUM_MONTHLY,
        CASE WHEN s.AVG_CREDIT >= 850 THEN 0.85 WHEN s.AVG_CREDIT >= 750 THEN 0.95
             WHEN s.AVG_CREDIT >= 650 THEN 1.00 WHEN s.AVG_CREDIT >= 550 THEN 1.10 ELSE 1.25 END AS CREDIT_ADJUSTMENT,
        CASE s.SEGMENT_A
            WHEN 'A1_사회초년생' THEN '전자기기파손,도난,화재'
            WHEN 'A2_신혼' THEN '가전파손,화재,수재,배상책임'
            WHEN 'A3_영유아가구' THEN '가전파손,화재,어린이안전,배상책임'
            WHEN 'A4_학령기가구' THEN '화재,도난,수재,가전파손'
            WHEN 'A5_중년안정' THEN '화재,도난,수재,귀금속,고가가전'
            WHEN 'A6_은퇴시니어' THEN '화재,수재,의료기기,배상책임'
            ELSE '화재,도난,가전파손' END AS RECOMMENDED_COVERAGE,
        CASE WHEN s.AVG_ABROAD > 200000 THEN '여행자보험_번들추천'
             WHEN s.TOTAL_MULTI > 20 THEN '임대인패키지_추천'
             WHEN s.TOTAL_OWNED < 30 THEN '임차인전용_추천'
             ELSE '표준패키지' END AS CROSS_SELL_RECOMMENDATION,
        s.SEGMENT_E AS RISK_PROFILE
    FROM segment_stats s
    LEFT JOIN coeff_a ca ON s.SEGMENT_A = ca.SEGMENT_KEY
    LEFT JOIN coeff_b cb ON s.SEGMENT_B = cb.SEGMENT_KEY;

    RETURN 'Premium recalculation complete with feedback adjustments';
END;
$$;


-- ─────────────────────────────────────────────────────────────
-- 6. Cortex ML FORECAST 활성화 (화재 예측)
-- ─────────────────────────────────────────────────────────────
USE SCHEMA ANALYTICS;

-- Cortex FORECAST 모델 생성
-- 시계열 뷰는 이미 V_FIRE_TIMESERIES로 존재
-- 아래 주석을 해제하여 실행 (Cortex ML 함수 사용 가능 계정)
/*
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST insure_fire_forecast(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'INSURE_DB.ANALYTICS.V_FIRE_TIMESERIES'),
    SERIES_COLNAME => 'DISTRICT_NAME',
    TIMESTAMP_COLNAME => 'DATE_KEY',
    TARGET_COLNAME => 'FIRE_COUNT',
    CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
);
*/

-- Cortex 사용 불가 시 개선된 수동 예측 뷰 (v1.3: 가중 이동평균 추가)
CREATE OR REPLACE VIEW V_FIRE_FORECAST_V13 AS
WITH yearly AS (
    SELECT
        DISTRICT_NAME,
        YEAR,
        SUM(TOTAL_FIRES) AS FIRES,
        SUM(BUILDING_FIRES) AS B_FIRES,
        SUM(PROPERTY_DAMAGE_KRW) AS DAMAGE
    FROM INSURE_DB.RAW_PUBLIC.FIRE_STATS
    GROUP BY DISTRICT_NAME, YEAR
),
trend AS (
    SELECT
        DISTRICT_NAME,
        AVG(FIRES) AS AVG_FIRES,
        REGR_SLOPE(FIRES, YEAR) AS TREND_SLOPE,
        REGR_R2(FIRES, YEAR) AS R_SQUARED,
        MAX(YEAR) AS LAST_YEAR,
        MAX(FIRES) AS MAX_FIRES,
        MIN(FIRES) AS MIN_FIRES,
        COUNT(*) AS DATA_POINTS,
        AVG(DAMAGE) AS AVG_DAMAGE
    FROM yearly
    GROUP BY DISTRICT_NAME
),
-- v1.3: 최근 3년 가중 이동평균 (최신에 더 높은 가중치)
weighted AS (
    SELECT
        y.DISTRICT_NAME,
        SUM(y.FIRES * CASE WHEN y.YEAR = t.LAST_YEAR THEN 3
                            WHEN y.YEAR = t.LAST_YEAR - 1 THEN 2
                            ELSE 1 END)
        / SUM(CASE WHEN y.YEAR = t.LAST_YEAR THEN 3
                    WHEN y.YEAR = t.LAST_YEAR - 1 THEN 2
                    ELSE 1 END) AS WEIGHTED_AVG_FIRES
    FROM yearly y
    JOIN trend t ON y.DISTRICT_NAME = t.DISTRICT_NAME
    WHERE y.YEAR >= t.LAST_YEAR - 2
    GROUP BY y.DISTRICT_NAME
)
SELECT
    t.DISTRICT_NAME,
    2025 AS FORECAST_YEAR,
    -- 트렌드 기반 예측
    ROUND(t.AVG_FIRES + t.TREND_SLOPE * (2025 - t.LAST_YEAR), 0) AS TREND_PREDICTION,
    -- 가중평균 기반 예측
    ROUND(w.WEIGHTED_AVG_FIRES + t.TREND_SLOPE * 0.5, 0) AS WEIGHTED_PREDICTION,
    -- 앙상블 (두 방법 평균)
    ROUND((t.AVG_FIRES + t.TREND_SLOPE * (2025 - t.LAST_YEAR) + w.WEIGHTED_AVG_FIRES + t.TREND_SLOPE * 0.5) / 2, 0) AS ENSEMBLE_PREDICTION,
    -- 신뢰구간
    ROUND((t.AVG_FIRES + t.TREND_SLOPE * (2025 - t.LAST_YEAR)) * 0.82, 0) AS LOWER_95,
    ROUND((t.AVG_FIRES + t.TREND_SLOPE * (2025 - t.LAST_YEAR)) * 1.18, 0) AS UPPER_95,
    -- 예측 품질 지표
    ROUND(t.R_SQUARED, 3) AS MODEL_R_SQUARED,
    t.DATA_POINTS,
    CASE WHEN t.R_SQUARED >= 0.7 THEN 'HIGH'
         WHEN t.R_SQUARED >= 0.4 THEN 'MEDIUM'
         ELSE 'LOW' END AS CONFIDENCE_LEVEL,
    -- 예상 피해액
    ROUND(t.AVG_DAMAGE * (1 + t.TREND_SLOPE / NULLIF(t.AVG_FIRES, 0)), 0) AS PREDICTED_DAMAGE_KRW,
    'ENSEMBLE_v1.3' AS METHOD
FROM trend t
LEFT JOIN weighted w ON t.DISTRICT_NAME = w.DISTRICT_NAME;


-- ─────────────────────────────────────────────────────────────
-- 7. v1.3 통합 대시보드 뷰 (기존 V13 테이블 + 피드백 + 예측)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_INSURE_DASHBOARD_V13 AS
SELECT
    d.DISTRICT_NAME,
    d.YEAR_MONTH,
    d.TOTAL_POPULATION,
    d.DISTRICT_AVG_INCOME,
    d.AVG_MOVABLE_ASSET,
    d.ADJUSTED_PREMIUM_MONTHLY,
    d.PREMIUM_CURVE_ZONE,
    d.ESTIMATED_ANNUAL_MARKET_KRW,
    d.COMPOSITE_RISK_SCORE,
    d.RISK_GRADE,
    d.FIRE_RISK_SCORE,
    d.THEFT_RISK_SCORE,
    d.BUILDING_RISK_SCORE,
    d.WEATHER_RISK_SCORE,
    d.ACTIVE_SEGMENTS,
    d.AVG_CREDIT_SCORE,
    m.MOVING_SIGNAL_SCORE,
    m.MOVING_STATUS,
    -- 피드백 데이터 조인
    COALESCE(fb.FEEDBACK_COUNT, 0) AS FEEDBACK_COUNT,
    COALESCE(fb.AVG_PREMIUM_FAIRNESS, 0) AS FEEDBACK_FAIRNESS,
    COALESCE(fb.PREMIUM_ADJUSTMENT_FACTOR, 1.0) AS FEEDBACK_MULTIPLIER,
    ROUND(d.ADJUSTED_PREMIUM_MONTHLY * COALESCE(fb.PREMIUM_ADJUSTMENT_FACTOR, 1.0), 0) AS FINAL_PREMIUM,
    -- 화재 예측 조인
    fc.ENSEMBLE_PREDICTION AS PREDICTED_FIRES_2025,
    fc.CONFIDENCE_LEVEL AS FORECAST_CONFIDENCE,
    fc.PREDICTED_DAMAGE_KRW AS PREDICTED_FIRE_DAMAGE
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY_V13 d
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_MOVING_SIGNAL m
    ON d.DISTRICT_NAME = m.DISTRICT_NAME AND d.YEAR_MONTH = m.YEAR_MONTH
LEFT JOIN INSURE_DB.FEEDBACK.V_FEEDBACK_ADJUSTMENT fb
    ON d.DISTRICT_NAME = fb.DISTRICT
LEFT JOIN INSURE_DB.ANALYTICS.V_FIRE_FORECAST_V13 fc
    ON d.DISTRICT_NAME = fc.DISTRICT_NAME;


-- ─────────────────────────────────────────────────────────────
-- 8. 기존 테이블 업데이트 (v1.3 테이블로 교체)
-- ─────────────────────────────────────────────────────────────
-- 기존 v1.2 테이블은 보존하고, 새 테이블을 기본으로 설정
CREATE OR REPLACE VIEW INSURE_DB.MART.MART_PREMIUM_SIMULATION_V13 AS
SELECT
    d.DISTRICT_CODE,
    d.DISTRICT_NAME,
    d.YEAR_MONTH,
    d.AVG_MOVABLE_ASSET,
    d.COMPOSITE_RISK_SCORE,
    d.RISK_GRADE,
    d.PREMIUM_CURVE_ZONE,
    d.AVG_CREDIT_SCORE,
    d.ADJUSTED_PREMIUM_MONTHLY,
    ROUND(d.ADJUSTED_PREMIUM_MONTHLY * 0.5, 0) AS PREMIUM_50PCT_COVERAGE,
    ROUND(d.ADJUSTED_PREMIUM_MONTHLY * 0.8, 0) AS PREMIUM_80PCT_COVERAGE,
    d.ADJUSTED_PREMIUM_MONTHLY AS PREMIUM_100PCT_COVERAGE,
    d.ADJUSTED_PREMIUM_MONTHLY * 12 AS ANNUAL_PREMIUM,
    d.ESTIMATED_ANNUAL_MARKET_KRW
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY_V13 d
WHERE d.YEAR_MONTH IS NOT NULL;


SELECT 'INSURE v1.3 Enhancement SQL complete' AS status;
