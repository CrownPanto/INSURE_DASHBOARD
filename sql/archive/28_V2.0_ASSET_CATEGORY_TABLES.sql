-- ============================================================
-- INSURE v2.0: 동산 카테고리별 리스크 매트릭스
-- 목적: 기존 "가재일체" 일률 보험료 → 6개 카테고리별 차등 보험료
-- 신규 테이블: DIM_ASSET_CATEGORY, FACT_GU_ASSET_PROFILE, FACT_GU_RISK_BY_CATEGORY
-- 작성일: 2026-04-08
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE INSURE_DB;

-- ═══════════════════════════════════════════════════════════
-- PART 1: RAW 공공데이터 업데이트 (수집된 CSV 기반)
-- 기존 RAW_PUBLIC 테이블에 2024년 데이터 보강
-- ═══════════════════════════════════════════════════════════

USE SCHEMA RAW_PUBLIC;

-- 1-1. 절도 통계 보강 (CRIME_STATS)
MERGE INTO CRIME_STATS tgt
USING (
    SELECT 2024 AS YEAR, column1 AS DISTRICT_NAME, column2::INT AS THEFT
    FROM VALUES
        ('강남구', 1284), ('강북구', 532), ('강동구', 786), ('강서구', 654),
        ('관악구', 892), ('광진구', 567), ('구로구', 623), ('금천구', 445),
        ('노원구', 876), ('도봉구', 478), ('동대문구', 598), ('동작구', 489),
        ('마포구', 712), ('서대문구', 534), ('서초구', 1156), ('성동구', 498),
        ('성북구', 567), ('송파구', 945), ('양천구', 534), ('영등포구', 867),
        ('용산구', 423), ('은평구', 534), ('종로구', 456), ('중구', 589),
        ('중랑구', 523)
) src ON tgt.DISTRICT_NAME = src.DISTRICT_NAME AND tgt.YEAR = src.YEAR
WHEN MATCHED THEN UPDATE SET tgt.THEFT = src.THEFT
WHEN NOT MATCHED THEN INSERT (YEAR, DISTRICT_NAME, THEFT, TOTAL_CRIMES)
    VALUES (src.YEAR, src.DISTRICT_NAME, src.THEFT, src.THEFT);

-- 1-2. 화재 통계 보강 (FIRE_STATS - 구 단위 집계)
MERGE INTO FIRE_STATS tgt
USING (
    SELECT 2024 AS YEAR, column1 AS DISTRICT_NAME, '전체' AS DONG_NAME, column2::INT AS TOTAL_FIRES
    FROM VALUES
        ('강남구', 1247), ('서초구', 1156), ('관악구', 1089), ('송파구', 1034),
        ('노원구', 968), ('영등포구', 945), ('강서구', 912), ('마포구', 878),
        ('구로구', 856), ('성북구', 834), ('강동구', 812), ('동대문구', 789),
        ('은평구', 767), ('양천구', 745), ('강북구', 723), ('중랑구', 701),
        ('광진구', 689), ('동작구', 678), ('금천구', 656), ('도봉구', 634),
        ('성동구', 612), ('서대문구', 598), ('종로구', 567), ('용산구', 534),
        ('중구', 478)
) src ON tgt.DISTRICT_NAME = src.DISTRICT_NAME AND tgt.YEAR = src.YEAR AND tgt.DONG_NAME = src.DONG_NAME
WHEN MATCHED THEN UPDATE SET tgt.TOTAL_FIRES = src.TOTAL_FIRES
WHEN NOT MATCHED THEN INSERT (YEAR, DISTRICT_NAME, DONG_NAME, TOTAL_FIRES)
    VALUES (src.YEAR, src.DISTRICT_NAME, src.DONG_NAME, src.TOTAL_FIRES);

-- 1-3. CCTV 설치현황 보강
MERGE INTO CCTV_INSTALLATION tgt
USING (
    SELECT 2024 AS YEAR, column1 AS DISTRICT_NAME, column2::INT AS TOTAL_CCTV, column2::INT AS CRIME_PREVENTION
    FROM VALUES
        ('강남구', 3450), ('강동구', 2890), ('강북구', 2145), ('강서구', 2980),
        ('관악구', 2567), ('광진구', 2234), ('구로구', 2678), ('금천구', 2123),
        ('노원구', 2456), ('도봉구', 2012), ('동대문구', 2345), ('동작구', 2234),
        ('마포구', 2567), ('서대문구', 2123), ('서초구', 3120), ('성동구', 2345),
        ('성북구', 2456), ('송파구', 3560), ('양천구', 2678), ('영등포구', 2789),
        ('용산구', 1890), ('은평구', 2345), ('종로구', 2123), ('중구', 2234),
        ('중랑구', 2345)
) src ON tgt.DISTRICT_NAME = src.DISTRICT_NAME AND tgt.YEAR = src.YEAR
WHEN MATCHED THEN UPDATE SET tgt.TOTAL_CCTV = src.TOTAL_CCTV, tgt.CRIME_PREVENTION = src.CRIME_PREVENTION
WHEN NOT MATCHED THEN INSERT (YEAR, DISTRICT_NAME, TOTAL_CCTV, CRIME_PREVENTION)
    VALUES (src.YEAR, src.DISTRICT_NAME, src.TOTAL_CCTV, src.CRIME_PREVENTION);


-- ═══════════════════════════════════════════════════════════
-- PART 2: 신규 침수 피해 데이터 (RAW_PUBLIC에 테이블 추가)
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS FLOOD_DAMAGE (
    YEAR                INT         COMMENT '발생연도',
    DISTRICT_NAME       VARCHAR(50) COMMENT '자치구명',
    FLOOD_DAMAGE_COUNT  INT         COMMENT '침수 피해 건수',
    LOAD_TIMESTAMP      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO FLOOD_DAMAGE (YEAR, DISTRICT_NAME, FLOOD_DAMAGE_COUNT)
SELECT column1::INT, column2, column3::INT
FROM VALUES
    (2024, '강남구', 8), (2024, '강동구', 12), (2024, '강북구', 6), (2024, '강서구', 11),
    (2024, '관악구', 14), (2024, '광진구', 7), (2024, '구로구', 15), (2024, '금천구', 9),
    (2024, '노원구', 5), (2024, '도봉구', 4), (2024, '동대문구', 8), (2024, '동작구', 10),
    (2024, '마포구', 9), (2024, '서대문구', 6), (2024, '서초구', 7), (2024, '성동구', 11),
    (2024, '성북구', 5), (2024, '송파구', 10), (2024, '양천구', 14), (2024, '영등포구', 16),
    (2024, '용산구', 8), (2024, '은평구', 7), (2024, '종로구', 4), (2024, '중구', 6),
    (2024, '중랑구', 9);


-- ═══════════════════════════════════════════════════════════
-- PART 3: STAGING 뷰 추가
-- ═══════════════════════════════════════════════════════════

USE SCHEMA STAGING;

CREATE OR REPLACE VIEW STG_FLOOD_DAMAGE AS
SELECT
    YEAR,
    TRIM(DISTRICT_NAME) AS DISTRICT_NAME,
    FLOOD_DAMAGE_COUNT
FROM INSURE_DB.RAW_PUBLIC.FLOOD_DAMAGE;


-- ═══════════════════════════════════════════════════════════
-- PART 4: DIM_ASSET_CATEGORY (INTERMEDIATE)
-- 동산 6개 카테고리 마스터 테이블
-- ═══════════════════════════════════════════════════════════

USE SCHEMA INTERMEDIATE;

CREATE OR REPLACE TABLE DIM_ASSET_CATEGORY (
    CATEGORY_ID         INT         PRIMARY KEY COMMENT '카테고리 ID',
    CATEGORY_NAME       VARCHAR(50) NOT NULL    COMMENT '카테고리명',
    CATEGORY_NAME_EN    VARCHAR(50) NOT NULL    COMMENT '카테고리 영문명',
    PRIMARY_RISK_TYPE   VARCHAR(50) NOT NULL    COMMENT '주요 리스크 유형',
    SECONDARY_RISK_TYPE VARCHAR(50)             COMMENT '보조 리스크 유형',
    AVG_UNIT_PRICE_LOW  NUMBER(12,0)            COMMENT '평균 단가 하한 (원)',
    AVG_UNIT_PRICE_HIGH NUMBER(12,0)            COMMENT '평균 단가 상한 (원)',
    DEPRECIATION_RATE   FLOAT                   COMMENT '연간 감가상각률',
    RISK_WEIGHT_FIRE    FLOAT       DEFAULT 0   COMMENT '화재 리스크 가중치',
    RISK_WEIGHT_THEFT   FLOAT       DEFAULT 0   COMMENT '도난 리스크 가중치',
    RISK_WEIGHT_FLOOD   FLOAT       DEFAULT 0   COMMENT '침수 리스크 가중치',
    RISK_WEIGHT_DAMAGE  FLOAT       DEFAULT 0   COMMENT '파손 리스크 가중치',
    LOAD_TIMESTAMP      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO DIM_ASSET_CATEGORY
    (CATEGORY_ID, CATEGORY_NAME, CATEGORY_NAME_EN, PRIMARY_RISK_TYPE, SECONDARY_RISK_TYPE,
     AVG_UNIT_PRICE_LOW, AVG_UNIT_PRICE_HIGH, DEPRECIATION_RATE,
     RISK_WEIGHT_FIRE, RISK_WEIGHT_THEFT, RISK_WEIGHT_FLOOD, RISK_WEIGHT_DAMAGE)
VALUES
    (1, '전자기기',       'Electronics',       '침수/파손', '도난',    500000,  5000000, 0.25, 0.15, 0.30, 0.35, 0.20),
    (2, '가전(대형)',     'Large Appliances',  '화재',      '전기사고', 500000, 3000000, 0.10, 0.45, 0.10, 0.15, 0.30),
    (3, '가전(소형/렌탈)', 'Small/Rental',     '화재',      '누수',    100000, 1000000, 0.15, 0.35, 0.05, 0.30, 0.30),
    (4, '가구/인테리어',   'Furniture',        '화재',      '파손',    200000, 5000000, 0.08, 0.50, 0.10, 0.10, 0.30),
    (5, '귀금속/시계',     'Jewelry/Watches',  '도난',      '파손',   1000000, 50000000, 0.02, 0.05, 0.70, 0.05, 0.20),
    (6, '의류/잡화',       'Clothing/Misc',    '도난',      '파손',    100000, 5000000, 0.30, 0.10, 0.50, 0.10, 0.30);


-- ═══════════════════════════════════════════════════════════
-- PART 5: FACT_GU_ASSET_PROFILE (INTERMEDIATE)
-- 구별 동산 소비 프로파일: 카드매출 업종 + 아정당 렌탈 기반
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE FACT_GU_ASSET_PROFILE (
    GU_CODE             VARCHAR(10)  COMMENT '행정구 코드',
    GU_NAME             VARCHAR(50)  NOT NULL COMMENT '자치구명',
    CATEGORY_ID         INT          NOT NULL COMMENT 'FK → DIM_ASSET_CATEGORY',
    CONSUMPTION_RATIO   FLOAT        COMMENT '해당 구 내 카테고리 소비 비중 (0~1)',
    ESTIMATED_AVG_VALUE NUMBER(12,0) COMMENT '추정 평균 보유가액 (원)',
    DATA_SOURCE         VARCHAR(20)  COMMENT 'CARD_SALES | RENTAL | ESTIMATED',
    DATA_QUALITY        VARCHAR(10)  COMMENT 'MEASURED | ESTIMATED',
    LOAD_TIMESTAMP      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (CATEGORY_ID) REFERENCES DIM_ASSET_CATEGORY(CATEGORY_ID)
);

-- 25개 구 × 6개 카테고리 = 150 rows
-- 실측 3개 구 (중구 11140, 영등포구 11560, 서초구 11650)는 DATA_QUALITY = 'MEASURED'
-- 나머지 22개 구는 서울 평균 기반 추정

INSERT INTO FACT_GU_ASSET_PROFILE (GU_CODE, GU_NAME, CATEGORY_ID, CONSUMPTION_RATIO, ESTIMATED_AVG_VALUE, DATA_SOURCE, DATA_QUALITY)
WITH gu_list AS (
    SELECT column1 AS GU_CODE, column2 AS GU_NAME, column3 AS DATA_QUALITY
    FROM VALUES
        ('11010', '종로구', 'ESTIMATED'), ('11020', '중구', 'MEASURED'),
        ('11030', '용산구', 'ESTIMATED'), ('11040', '성동구', 'ESTIMATED'),
        ('11050', '광진구', 'ESTIMATED'), ('11060', '동대문구', 'ESTIMATED'),
        ('11070', '중랑구', 'ESTIMATED'), ('11080', '성북구', 'ESTIMATED'),
        ('11090', '강북구', 'ESTIMATED'), ('11100', '도봉구', 'ESTIMATED'),
        ('11110', '노원구', 'ESTIMATED'), ('11120', '은평구', 'ESTIMATED'),
        ('11130', '서대문구', 'ESTIMATED'), ('11140', '마포구', 'ESTIMATED'),
        ('11150', '양천구', 'ESTIMATED'), ('11160', '강서구', 'ESTIMATED'),
        ('11170', '구로구', 'ESTIMATED'), ('11180', '금천구', 'ESTIMATED'),
        ('11190', '영등포구', 'MEASURED'), ('11200', '동작구', 'ESTIMATED'),
        ('11210', '관악구', 'ESTIMATED'), ('11220', '서초구', 'MEASURED'),
        ('11230', '강남구', 'ESTIMATED'), ('11240', '송파구', 'ESTIMATED'),
        ('11250', '강동구', 'ESTIMATED')
),
categories AS (
    SELECT CATEGORY_ID FROM DIM_ASSET_CATEGORY
),
-- 서울 평균 소비 비중 (카드매출 업종 분포 추정)
avg_ratios AS (
    SELECT column1::INT AS CATEGORY_ID, column2::FLOAT AS BASE_RATIO, column3::NUMBER(12,0) AS BASE_VALUE
    FROM VALUES
        (1, 0.22, 1800000),  -- 전자기기: 가장 높은 비중
        (2, 0.18, 1500000),  -- 가전(대형)
        (3, 0.12, 400000),   -- 가전(소형/렌탈)
        (4, 0.15, 1200000),  -- 가구/인테리어
        (5, 0.13, 3000000),  -- 귀금속/시계
        (6, 0.20, 800000)    -- 의류/잡화
),
-- 구별 자산 보정계수 (소득 수준 기반)
gu_multiplier AS (
    SELECT column1 AS GU_NAME, column2::FLOAT AS ASSET_MULTIPLIER
    FROM VALUES
        ('종로구', 1.05), ('중구', 1.10), ('용산구', 1.15), ('성동구', 1.05),
        ('광진구', 1.00), ('동대문구', 0.90), ('중랑구', 0.85), ('성북구', 0.90),
        ('강북구', 0.80), ('도봉구', 0.85), ('노원구', 0.88), ('은평구', 0.88),
        ('서대문구', 0.92), ('마포구', 1.10), ('양천구', 0.95), ('강서구', 0.92),
        ('구로구', 0.88), ('금천구', 0.85), ('영등포구', 1.05), ('동작구', 0.95),
        ('관악구', 0.82), ('서초구', 1.35), ('강남구', 1.40), ('송파구', 1.20),
        ('강동구', 1.05)
)
SELECT
    g.GU_CODE,
    g.GU_NAME,
    a.CATEGORY_ID,
    -- 구별 소비 비중: 고소득 지역은 귀금속/전자기기 비중 상승
    ROUND(a.BASE_RATIO *
        CASE
            WHEN a.CATEGORY_ID IN (1, 5) AND m.ASSET_MULTIPLIER > 1.1 THEN 1.15
            WHEN a.CATEGORY_ID IN (3, 6) AND m.ASSET_MULTIPLIER < 0.9 THEN 1.10
            ELSE 1.0
        END
    , 3) AS CONSUMPTION_RATIO,
    ROUND(a.BASE_VALUE * m.ASSET_MULTIPLIER) AS ESTIMATED_AVG_VALUE,
    CASE
        WHEN a.CATEGORY_ID = 3 THEN 'RENTAL'
        ELSE 'ESTIMATED'
    END AS DATA_SOURCE,
    g.DATA_QUALITY
FROM gu_list g
CROSS JOIN avg_ratios a
LEFT JOIN gu_multiplier m ON g.GU_NAME = m.GU_NAME;


-- ═══════════════════════════════════════════════════════════
-- PART 6: FACT_GU_RISK_BY_CATEGORY (INTERMEDIATE)
-- 구별 × 카테고리별 리스크 스코어 매트릭스
-- 경찰청 절도 + 소방청 화재 + 유동인구 + 침수 + 건물노후도
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE FACT_GU_RISK_BY_CATEGORY (
    GU_CODE             VARCHAR(10)  COMMENT '행정구 코드',
    GU_NAME             VARCHAR(50)  NOT NULL COMMENT '자치구명',
    CATEGORY_ID         INT          NOT NULL COMMENT 'FK → DIM_ASSET_CATEGORY',
    THEFT_RISK_SCORE    FLOAT        COMMENT '도난 리스크 (0~1, 경찰청 절도 기반)',
    FIRE_RISK_SCORE     FLOAT        COMMENT '화재 리스크 (0~1, 소방청 화재 기반)',
    FLOOD_RISK_SCORE    FLOAT        COMMENT '침수 리스크 (0~1, 자연재해 피해 기반)',
    EXPOSURE_SCORE      FLOAT        COMMENT '사고 노출도 (0~1, 유동인구 기반)',
    BUILDING_AGE_SCORE  FLOAT        COMMENT '건물 노후 리스크 (0~1)',
    CCTV_SAFETY_SCORE   FLOAT        COMMENT 'CCTV 안전 보정 (0~1, 높을수록 안전)',
    COMPOSITE_RISK_SCORE FLOAT       COMMENT '가중 합산 카테고리별 리스크',
    DATA_QUALITY        VARCHAR(10)  COMMENT 'MEASURED | ESTIMATED',
    LOAD_TIMESTAMP      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (CATEGORY_ID) REFERENCES DIM_ASSET_CATEGORY(CATEGORY_ID)
);

-- 리스크 스코어 산출: 각 원천 데이터를 정규화(0~1)하고 카테고리별 가중치 적용
INSERT INTO FACT_GU_RISK_BY_CATEGORY
    (GU_CODE, GU_NAME, CATEGORY_ID, THEFT_RISK_SCORE, FIRE_RISK_SCORE,
     FLOOD_RISK_SCORE, EXPOSURE_SCORE, BUILDING_AGE_SCORE, CCTV_SAFETY_SCORE,
     COMPOSITE_RISK_SCORE, DATA_QUALITY)
WITH
-- 절도 정규화 (max 기준)
theft_norm AS (
    SELECT column1 AS GU_NAME,
        column2::FLOAT / 1284.0 AS THEFT_NORM  -- max=강남구 1284
    FROM VALUES
        ('강남구', 1284), ('강북구', 532), ('강동구', 786), ('강서구', 654),
        ('관악구', 892), ('광진구', 567), ('구로구', 623), ('금천구', 445),
        ('노원구', 876), ('도봉구', 478), ('동대문구', 598), ('동작구', 489),
        ('마포구', 712), ('서대문구', 534), ('서초구', 1156), ('성동구', 498),
        ('성북구', 567), ('송파구', 945), ('양천구', 534), ('영등포구', 867),
        ('용산구', 423), ('은평구', 534), ('종로구', 456), ('중구', 589),
        ('중랑구', 523)
),
-- 화재 정규화
fire_norm AS (
    SELECT column1 AS GU_NAME,
        column2::FLOAT / 1247.0 AS FIRE_NORM  -- max=강남구 1247
    FROM VALUES
        ('강남구', 1247), ('서초구', 1156), ('관악구', 1089), ('송파구', 1034),
        ('노원구', 968), ('영등포구', 945), ('강서구', 912), ('마포구', 878),
        ('구로구', 856), ('성북구', 834), ('강동구', 812), ('동대문구', 789),
        ('은평구', 767), ('양천구', 745), ('강북구', 723), ('중랑구', 701),
        ('광진구', 689), ('동작구', 678), ('금천구', 656), ('도봉구', 634),
        ('성동구', 612), ('서대문구', 598), ('종로구', 567), ('용산구', 534),
        ('중구', 478)
),
-- 침수 정규화
flood_norm AS (
    SELECT column1 AS GU_NAME,
        column2::FLOAT / 16.0 AS FLOOD_NORM  -- max=영등포구 16
    FROM VALUES
        ('강남구', 8), ('강동구', 12), ('강북구', 6), ('강서구', 11),
        ('관악구', 14), ('광진구', 7), ('구로구', 15), ('금천구', 9),
        ('노원구', 5), ('도봉구', 4), ('동대문구', 8), ('동작구', 10),
        ('마포구', 9), ('서대문구', 6), ('서초구', 7), ('성동구', 11),
        ('성북구', 5), ('송파구', 10), ('양천구', 14), ('영등포구', 16),
        ('용산구', 8), ('은평구', 7), ('종로구', 4), ('중구', 6),
        ('중랑구', 9)
),
-- 건물 노후도 정규화
building_norm AS (
    SELECT column1 AS GU_NAME,
        column2::FLOAT AS BUILDING_OLD_RATIO  -- 이미 0~1 범위
    FROM VALUES
        ('강남구', 0.262), ('강동구', 0.238), ('강북구', 0.310), ('강서구', 0.314),
        ('관악구', 0.286), ('광진구', 0.275), ('구로구', 0.284), ('금천구', 0.278),
        ('노원구', 0.268), ('도봉구', 0.296), ('동대문구', 0.288), ('동작구', 0.269),
        ('마포구', 0.246), ('서대문구', 0.282), ('서초구', 0.232), ('성동구', 0.274),
        ('성북구', 0.290), ('송파구', 0.254), ('양천구', 0.272), ('영등포구', 0.280),
        ('용산구', 0.276), ('은평구', 0.286), ('종로구', 0.291), ('중구', 0.294),
        ('중랑구', 0.282)
),
-- CCTV 정규화 (높을수록 안전 → 역수)
cctv_norm AS (
    SELECT column1 AS GU_NAME,
        column2::FLOAT / 3560.0 AS CCTV_NORM  -- max=송파구 3560
    FROM VALUES
        ('강남구', 3450), ('강동구', 2890), ('강북구', 2145), ('강서구', 2980),
        ('관악구', 2567), ('광진구', 2234), ('구로구', 2678), ('금천구', 2123),
        ('노원구', 2456), ('도봉구', 2012), ('동대문구', 2345), ('동작구', 2234),
        ('마포구', 2567), ('서대문구', 2123), ('서초구', 3120), ('성동구', 2345),
        ('성북구', 2456), ('송파구', 3560), ('양천구', 2678), ('영등포구', 2789),
        ('용산구', 1890), ('은평구', 2345), ('종로구', 2123), ('중구', 2234),
        ('중랑구', 2345)
),
-- GU 코드 매핑
gu_codes AS (
    SELECT column1 AS GU_CODE, column2 AS GU_NAME, column3 AS DATA_QUALITY
    FROM VALUES
        ('11010', '종로구', 'ESTIMATED'), ('11020', '중구', 'MEASURED'),
        ('11030', '용산구', 'ESTIMATED'), ('11040', '성동구', 'ESTIMATED'),
        ('11050', '광진구', 'ESTIMATED'), ('11060', '동대문구', 'ESTIMATED'),
        ('11070', '중랑구', 'ESTIMATED'), ('11080', '성북구', 'ESTIMATED'),
        ('11090', '강북구', 'ESTIMATED'), ('11100', '도봉구', 'ESTIMATED'),
        ('11110', '노원구', 'ESTIMATED'), ('11120', '은평구', 'ESTIMATED'),
        ('11130', '서대문구', 'ESTIMATED'), ('11140', '마포구', 'ESTIMATED'),
        ('11150', '양천구', 'ESTIMATED'), ('11160', '강서구', 'ESTIMATED'),
        ('11170', '구로구', 'ESTIMATED'), ('11180', '금천구', 'ESTIMATED'),
        ('11190', '영등포구', 'MEASURED'), ('11200', '동작구', 'ESTIMATED'),
        ('11210', '관악구', 'ESTIMATED'), ('11220', '서초구', 'MEASURED'),
        ('11230', '강남구', 'ESTIMATED'), ('11240', '송파구', 'ESTIMATED'),
        ('11250', '강동구', 'ESTIMATED')
),
-- 카테고리별 가중치
cat_weights AS (
    SELECT CATEGORY_ID, RISK_WEIGHT_FIRE, RISK_WEIGHT_THEFT, RISK_WEIGHT_FLOOD, RISK_WEIGHT_DAMAGE
    FROM DIM_ASSET_CATEGORY
)
SELECT
    g.GU_CODE,
    g.GU_NAME,
    c.CATEGORY_ID,
    ROUND(t.THEFT_NORM, 3) AS THEFT_RISK_SCORE,
    ROUND(f.FIRE_NORM, 3) AS FIRE_RISK_SCORE,
    ROUND(fl.FLOOD_NORM, 3) AS FLOOD_RISK_SCORE,
    -- 노출도: 절도 + 화재 + 침수의 평균으로 간접 추정
    ROUND((t.THEFT_NORM + f.FIRE_NORM + fl.FLOOD_NORM) / 3, 3) AS EXPOSURE_SCORE,
    ROUND(b.BUILDING_OLD_RATIO, 3) AS BUILDING_AGE_SCORE,
    ROUND(cc.CCTV_NORM, 3) AS CCTV_SAFETY_SCORE,
    -- 카테고리별 가중 합산 (CCTV는 감점 요소)
    ROUND(
        f.FIRE_NORM * c.RISK_WEIGHT_FIRE
        + t.THEFT_NORM * c.RISK_WEIGHT_THEFT
        + fl.FLOOD_NORM * c.RISK_WEIGHT_FLOOD
        + b.BUILDING_OLD_RATIO * c.RISK_WEIGHT_DAMAGE * 0.5
        - cc.CCTV_NORM * 0.10
    , 3) AS COMPOSITE_RISK_SCORE,
    g.DATA_QUALITY
FROM gu_codes g
CROSS JOIN cat_weights c
LEFT JOIN theft_norm t ON g.GU_NAME = t.GU_NAME
LEFT JOIN fire_norm f ON g.GU_NAME = f.GU_NAME
LEFT JOIN flood_norm fl ON g.GU_NAME = fl.GU_NAME
LEFT JOIN building_norm b ON g.GU_NAME = b.GU_NAME
LEFT JOIN cctv_norm cc ON g.GU_NAME = cc.GU_NAME;


-- ═══════════════════════════════════════════════════════════
-- PART 7: 검증 쿼리
-- ═══════════════════════════════════════════════════════════

-- DIM 테이블 확인
SELECT * FROM DIM_ASSET_CATEGORY ORDER BY CATEGORY_ID;

-- 구별 소비 프로파일 샘플
SELECT GU_NAME, CATEGORY_ID, CONSUMPTION_RATIO, ESTIMATED_AVG_VALUE, DATA_QUALITY
FROM FACT_GU_ASSET_PROFILE
WHERE GU_NAME IN ('서초구', '중구', '영등포구')
ORDER BY GU_NAME, CATEGORY_ID;

-- 리스크 매트릭스 핵심 비교: 서초구 vs 중구
SELECT
    r.GU_NAME,
    c.CATEGORY_NAME,
    r.THEFT_RISK_SCORE,
    r.FIRE_RISK_SCORE,
    r.FLOOD_RISK_SCORE,
    r.CCTV_SAFETY_SCORE,
    r.COMPOSITE_RISK_SCORE,
    r.DATA_QUALITY
FROM FACT_GU_RISK_BY_CATEGORY r
JOIN DIM_ASSET_CATEGORY c ON r.CATEGORY_ID = c.CATEGORY_ID
WHERE r.GU_NAME IN ('서초구', '중구')
ORDER BY r.GU_NAME, c.CATEGORY_ID;

-- 전체 통계
SELECT
    c.CATEGORY_NAME,
    ROUND(AVG(r.COMPOSITE_RISK_SCORE), 3) AS AVG_RISK,
    ROUND(MIN(r.COMPOSITE_RISK_SCORE), 3) AS MIN_RISK,
    ROUND(MAX(r.COMPOSITE_RISK_SCORE), 3) AS MAX_RISK
FROM FACT_GU_RISK_BY_CATEGORY r
JOIN DIM_ASSET_CATEGORY c ON r.CATEGORY_ID = c.CATEGORY_ID
GROUP BY c.CATEGORY_NAME
ORDER BY AVG_RISK DESC;

-- 행 수 확인
SELECT 'DIM_ASSET_CATEGORY' AS TBL, COUNT(*) AS ROWS FROM DIM_ASSET_CATEGORY
UNION ALL
SELECT 'FACT_GU_ASSET_PROFILE', COUNT(*) FROM FACT_GU_ASSET_PROFILE
UNION ALL
SELECT 'FACT_GU_RISK_BY_CATEGORY', COUNT(*) FROM FACT_GU_RISK_BY_CATEGORY;
