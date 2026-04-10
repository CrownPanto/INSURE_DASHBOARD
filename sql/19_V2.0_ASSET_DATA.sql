-- ================================================================
-- 28_V2.0_ASSET_DATA.sql
-- INSURE v2.0 통합: 자산 카테고리 + 실측 데이터 연동
-- Consolidated from: 28_V2.0_ASSET_CATEGORY_TABLES.sql
--                    29_V2.0_REAL_DATA_INTEGRATION.sql
-- ================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE INSURE_DB;


-- ================================================================
-- PART 1: 자산 카테고리 테이블
-- From 28_V2.0_ASSET_CATEGORY_TABLES.sql
-- ================================================================

-- ═══════════════════════════════════════════════════════════
-- PART 1.1: RAW 공공데이터 업데이트 (수집된 CSV 기반)
-- 기존 RAW_PUBLIC 테이블에 2024년 데이터 보강
-- ═══════════════════════════════════════════════════════════

USE SCHEMA RAW_PUBLIC;

-- 1.1-1. 절도 통계 보강 (CRIME_STATS)
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

-- 1.1-2. 화재 통계 보강 (FIRE_STATS - 구 단위 집계)
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

-- 1.1-3. CCTV 설치현황 보강
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
-- PART 1.2: 신규 침수 피해 데이터 (RAW_PUBLIC에 테이블 추가)
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
-- PART 1.3: STAGING 뷰 추가
-- ═══════════════════════════════════════════════════════════

USE SCHEMA STAGING;

CREATE OR REPLACE VIEW STG_FLOOD_DAMAGE AS
SELECT
    YEAR,
    TRIM(DISTRICT_NAME) AS DISTRICT_NAME,
    FLOOD_DAMAGE_COUNT
FROM INSURE_DB.RAW_PUBLIC.FLOOD_DAMAGE;


-- ═══════════════════════════════════════════════════════════
-- PART 1.4: DIM_ASSET_CATEGORY (INTERMEDIATE)
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
-- PART 1.5: FACT_GU_ASSET_PROFILE (INTERMEDIATE)
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
-- PART 1.6: FACT_GU_RISK_BY_CATEGORY (INTERMEDIATE)
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


-- ================================================================
-- PART 2: 실측 데이터 연동
-- From 29_V2.0_REAL_DATA_INTEGRATION.sql
-- ================================================================

-- ═══════════════════════════════════════════════════════════
-- PART 2.1: 데이터소스 현황 확인 (실행 전 검증)
-- 실제 테이블/뷰에 데이터가 있는지 먼저 확인
-- ═══════════════════════════════════════════════════════════

-- 2.1-1. SPH 카드매출 — 최신 기준년월 및 업종 목록 확인
SELECT
    MAX(BASE_YM)        AS LATEST_YM,
    COUNT(DISTINCT BSNS_TPNM) AS BSNS_TYPE_CNT,
    COUNT(DISTINCT ADDR_GU)   AS GU_CNT,
    SUM(SALE_AMT)             AS TOTAL_SALES_AMT
FROM GRANDATA.CARD_SALES_INFO
WHERE BASE_YM >= '202401';

-- 2.1-2. 아정당 렌탈 뷰 — 렌탈 카테고리 구성 확인
SELECT
    RENTAL_CATEGORY,
    COUNT(DISTINCT GU_NAME) AS GU_CNT,
    SUM(SUBSCRIBER_CNT)     AS TOTAL_SUBSCRIBERS
FROM TELECOM_INSIGHTS.V06_RENTAL_CATEGORY_TRENDS
WHERE BASE_YM = (SELECT MAX(BASE_YM) FROM TELECOM_INSIGHTS.V06_RENTAL_CATEGORY_TRENDS)
GROUP BY RENTAL_CATEGORY
ORDER BY TOTAL_SUBSCRIBERS DESC;

-- 2.1-3. 유동인구 — 구별 최신 유동인구 분포 확인
SELECT
    ADDR_GU,
    SUM(POP_CNT) AS TOTAL_FLOATING_POP
FROM GRANDATA.FLOATING_POPULATION_INFO
WHERE BASE_YM = (SELECT MAX(BASE_YM) FROM GRANDATA.FLOATING_POPULATION_INFO)
GROUP BY ADDR_GU
ORDER BY TOTAL_FLOATING_POP DESC
LIMIT 10;


-- ═══════════════════════════════════════════════════════════
-- PART 2.2: SPH 카드매출 → FACT_GU_ASSET_PROFILE 갱신
-- 대상 카테고리: 2(가전대형), 3(가전소형/렌탈), 4(가구/인테리어), 5(귀금속/시계)
-- 업종명(BSNS_TPNM) → CATEGORY_ID 매핑 후 구별 소비 비중 재계산
-- ═══════════════════════════════════════════════════════════

USE SCHEMA INTERMEDIATE;

-- 2.2-1. 카드매출 업종 → 동산 카테고리 매핑 (임시 CTE용 매핑 정의)
-- 업종코드/업종명 기반 매핑: 카드사 업종 분류 → DIM_ASSET_CATEGORY
--   CATEGORY_ID 2 → 가전(대형): 대형가전, 전자제품, 가전제품
--   CATEGORY_ID 3 → 가전(소형/렌탈): 소형가전, 렌탈, 안마기기, 생활가전
--   CATEGORY_ID 4 → 가구/인테리어: 가구, 인테리어, 홈데코, 생활용품
--   CATEGORY_ID 5 → 귀금속/시계: 귀금속, 시계, 보석, 명품잡화

MERGE INTO FACT_GU_ASSET_PROFILE tgt
USING (
    WITH
    -- 업종 → 카테고리 매핑 테이블
    bsns_category_map AS (
        SELECT column1 AS BSNS_KEYWORD, column2::INT AS CATEGORY_ID
        FROM VALUES
            -- 가전(대형) CATEGORY_ID=2
            ('대형가전',     2), ('가전제품',     2), ('전자제품',     2),
            ('냉장고',       2), ('세탁기',       2), ('에어컨',       2),
            ('TV',           2), ('텔레비전',     2), ('전자양판',     2),
            -- 가전(소형/렌탈) CATEGORY_ID=3
            ('소형가전',     3), ('생활가전',     3), ('청소기',       3),
            ('조명기기',     3), ('렌탈',         3), ('정수기',       3),
            ('공기청정기',   3), ('비데',         3), ('안마기기',     3),
            -- 가구/인테리어 CATEGORY_ID=4
            ('가구',         4), ('인테리어',     4), ('홈데코',       4),
            ('침구',         4), ('커튼',         4), ('생활용품',     4),
            ('홈퍼니싱',     4), ('주방용품',     4), ('욕실용품',     4),
            -- 귀금속/시계 CATEGORY_ID=5
            ('귀금속',       5), ('시계',         5), ('보석',         5),
            ('명품',         5), ('주얼리',       5), ('골드',         5)
    ),
    -- GRANDATA 카드매출에서 업종 키워드 매칭 후 구별 카테고리별 매출 집계
    -- BASE_YM: 최근 12개월 합산 (2024년 기준)
    card_raw AS (
        SELECT
            cs.ADDR_GU                           AS GU_NAME,
            m.CATEGORY_ID,
            SUM(cs.SALE_AMT)                     AS CATEGORY_SALES_AMT,
            SUM(cs.SALE_CNT)                     AS CATEGORY_SALES_CNT
        FROM GRANDATA.CARD_SALES_INFO cs
        INNER JOIN bsns_category_map m
            ON cs.BSNS_TPNM LIKE '%' || m.BSNS_KEYWORD || '%'
        WHERE cs.BASE_YM BETWEEN '202401' AND '202412'
          AND cs.ADDR_GU IS NOT NULL
        GROUP BY cs.ADDR_GU, m.CATEGORY_ID
    ),
    -- 구별 전체 카드매출 합계 (카테고리 합산)
    gu_total_sales AS (
        SELECT
            GU_NAME,
            SUM(CATEGORY_SALES_AMT) AS TOTAL_SALES_AMT
        FROM card_raw
        GROUP BY GU_NAME
    ),
    -- 구별 카테고리 소비 비중 + 추정 보유가액 계산
    card_profile AS (
        SELECT
            cr.GU_NAME,
            cr.CATEGORY_ID,
            -- 소비 비중: 해당 카테고리 매출 / 구 전체 카드매출 합계
            ROUND(cr.CATEGORY_SALES_AMT / NULLIF(gt.TOTAL_SALES_AMT, 0), 4)
                AS CONSUMPTION_RATIO,
            -- 추정 평균 보유가액: 카테고리별 단가 범위 중간값 × 지역 소비 강도 보정
            ROUND(
                CASE cr.CATEGORY_ID
                    WHEN 2 THEN 1500000  -- 가전(대형) 기준 단가
                    WHEN 3 THEN  400000  -- 가전(소형/렌탈) 기준 단가
                    WHEN 4 THEN 1200000  -- 가구/인테리어 기준 단가
                    WHEN 5 THEN 3000000  -- 귀금속/시계 기준 단가
                    ELSE         800000
                END
                -- 지역 소비 강도: 해당 카테고리 1인당 매출 기준 정규화
                * (cr.CATEGORY_SALES_AMT / NULLIF(cr.CATEGORY_SALES_CNT, 0))
                / NULLIF(
                    AVG(cr.CATEGORY_SALES_AMT / NULLIF(cr.CATEGORY_SALES_CNT, 0))
                        OVER (PARTITION BY cr.CATEGORY_ID),
                    0
                  )
            ) AS ESTIMATED_AVG_VALUE
        FROM card_raw cr
        JOIN gu_total_sales gt ON cr.GU_NAME = gt.GU_NAME
    )
    SELECT
        p.GU_NAME,
        p.CATEGORY_ID,
        p.CONSUMPTION_RATIO,
        p.ESTIMATED_AVG_VALUE
    FROM card_profile p
    -- 카드매출 갱신 대상 카테고리만: 2(가전대형), 3(가전소형렌탈), 4(가구), 5(귀금속)
    WHERE p.CATEGORY_ID IN (2, 3, 4, 5)
) src
ON  tgt.GU_NAME     = src.GU_NAME
AND tgt.CATEGORY_ID = src.CATEGORY_ID
WHEN MATCHED THEN UPDATE SET
    tgt.CONSUMPTION_RATIO   = src.CONSUMPTION_RATIO,
    tgt.ESTIMATED_AVG_VALUE = src.ESTIMATED_AVG_VALUE,
    tgt.DATA_SOURCE         = 'CARD_SALES',
    tgt.DATA_QUALITY        = 'MEASURED',
    tgt.LOAD_TIMESTAMP      = CURRENT_TIMESTAMP();

-- 2.2-2. 카드매출 갱신 결과 확인
SELECT
    CATEGORY_ID,
    DATA_SOURCE,
    DATA_QUALITY,
    COUNT(*)                                AS ROW_CNT,
    ROUND(AVG(CONSUMPTION_RATIO), 4)        AS AVG_CONSUMPTION_RATIO,
    ROUND(AVG(ESTIMATED_AVG_VALUE))         AS AVG_ASSET_VALUE
FROM FACT_GU_ASSET_PROFILE
WHERE CATEGORY_ID IN (2, 3, 4, 5)
GROUP BY CATEGORY_ID, DATA_SOURCE, DATA_QUALITY
ORDER BY CATEGORY_ID, DATA_SOURCE;


-- ═══════════════════════════════════════════════════════════
-- PART 2.3: 아정당 렌탈 뷰 → FACT_GU_ASSET_PROFILE 갱신
-- 대상 카테고리: 3 (가전소형/렌탈) 전용
-- 뷰: TELECOM_INSIGHTS.V06_RENTAL_CATEGORY_TRENDS
-- 렌탈 카테고리: 정수기 / 에어컨 / 공기청정기 / 비데
-- 렌탈 구독자 수 기반으로 구별 렌탈 소비 비중 재산정
-- ═══════════════════════════════════════════════════════════

-- 2.3-1. 렌탈 뷰 기반 구별 CATEGORY_ID=3 레코드 갱신
-- 렌탈 4개 품목 합산 구독자 수 → 전체 대비 구별 비중으로 CONSUMPTION_RATIO 갱신
MERGE INTO FACT_GU_ASSET_PROFILE tgt
USING (
    WITH
    -- 최신 기준년월 (최근 분기 기준) 렌탈 구독자 집계
    rental_latest AS (
        SELECT BASE_YM
        FROM TELECOM_INSIGHTS.V06_RENTAL_CATEGORY_TRENDS
        ORDER BY BASE_YM DESC
        LIMIT 1
    ),
    -- 구별 렌탈 4개 품목 합계 구독자 수
    rental_by_gu AS (
        SELECT
            v.GU_NAME,
            SUM(v.SUBSCRIBER_CNT)        AS TOTAL_RENTAL_SUBS,
            -- 품목별 비중 (세분화 참고용 컬럼)
            SUM(CASE WHEN v.RENTAL_CATEGORY = '정수기'     THEN v.SUBSCRIBER_CNT ELSE 0 END)
                AS PURIFIER_SUBS,
            SUM(CASE WHEN v.RENTAL_CATEGORY = '에어컨'     THEN v.SUBSCRIBER_CNT ELSE 0 END)
                AS AC_SUBS,
            SUM(CASE WHEN v.RENTAL_CATEGORY = '공기청정기' THEN v.SUBSCRIBER_CNT ELSE 0 END)
                AS AIRPURIFIER_SUBS,
            SUM(CASE WHEN v.RENTAL_CATEGORY = '비데'       THEN v.SUBSCRIBER_CNT ELSE 0 END)
                AS BIDET_SUBS
        FROM TELECOM_INSIGHTS.V06_RENTAL_CATEGORY_TRENDS v
        JOIN rental_latest rl ON v.BASE_YM = rl.BASE_YM
        WHERE v.RENTAL_CATEGORY IN ('정수기', '에어컨', '공기청정기', '비데')
        GROUP BY v.GU_NAME
    ),
    -- 서울 전체 렌탈 구독자 합계
    rental_total AS (
        SELECT SUM(TOTAL_RENTAL_SUBS) AS SEOUL_TOTAL_SUBS
        FROM rental_by_gu
    ),
    -- 구별 렌탈 소비 비중 + 추정 보유가액 계산
    -- 보유가액: 렌탈 단가 × 품목별 가중평균 (정수기 35만, 에어컨 90만, 공청기 40만, 비데 25만)
    rental_profile AS (
        SELECT
            rg.GU_NAME,
            3                                                     AS CATEGORY_ID,
            -- 소비 비중: 구별 렌탈 구독자 수 / 서울 전체 렌탈 구독자 합계
            ROUND(rg.TOTAL_RENTAL_SUBS / NULLIF(rt.SEOUL_TOTAL_SUBS, 0), 4)
                AS CONSUMPTION_RATIO,
            -- 렌탈 추정 보유가액: 월 렌탈료 × 계약 기간(36개월) × 품목 가중 단가
            ROUND(
                (
                    rg.PURIFIER_SUBS     * 350000
                    + rg.AC_SUBS         * 900000
                    + rg.AIRPURIFIER_SUBS* 400000
                    + rg.BIDET_SUBS      * 250000
                ) / NULLIF(rg.TOTAL_RENTAL_SUBS, 0)
            ) AS ESTIMATED_AVG_VALUE
        FROM rental_by_gu rg
        CROSS JOIN rental_total rt
    )
    SELECT GU_NAME, CATEGORY_ID, CONSUMPTION_RATIO, ESTIMATED_AVG_VALUE
    FROM rental_profile
) src
ON  tgt.GU_NAME     = src.GU_NAME
AND tgt.CATEGORY_ID = src.CATEGORY_ID
WHEN MATCHED THEN UPDATE SET
    tgt.CONSUMPTION_RATIO   = src.CONSUMPTION_RATIO,
    tgt.ESTIMATED_AVG_VALUE = src.ESTIMATED_AVG_VALUE,
    tgt.DATA_SOURCE         = 'RENTAL',
    tgt.DATA_QUALITY        = 'MEASURED',
    tgt.LOAD_TIMESTAMP      = CURRENT_TIMESTAMP();

-- 2.3-2. 렌탈 뷰 기반 갱신 결과 확인
SELECT
    GU_NAME,
    CATEGORY_ID,
    CONSUMPTION_RATIO,
    ESTIMATED_AVG_VALUE,
    DATA_SOURCE,
    DATA_QUALITY
FROM FACT_GU_ASSET_PROFILE
WHERE CATEGORY_ID = 3
ORDER BY CONSUMPTION_RATIO DESC;

-- 2.3-3. 렌탈 품목별 구별 분포 참고 쿼리 (세부 분석용)
SELECT
    v.GU_NAME,
    v.RENTAL_CATEGORY,
    v.SUBSCRIBER_CNT,
    ROUND(v.SUBSCRIBER_CNT / SUM(v.SUBSCRIBER_CNT) OVER (PARTITION BY v.GU_NAME), 4)
        AS INTRA_GU_RATIO
FROM TELECOM_INSIGHTS.V06_RENTAL_CATEGORY_TRENDS v
WHERE v.BASE_YM = (SELECT MAX(BASE_YM) FROM TELECOM_INSIGHTS.V06_RENTAL_CATEGORY_TRENDS)
  AND v.RENTAL_CATEGORY IN ('정수기', '에어컨', '공기청정기', '비데')
ORDER BY v.GU_NAME, v.SUBSCRIBER_CNT DESC;


-- ═══════════════════════════════════════════════════════════
-- PART 2.4: 유동인구 → FACT_GU_RISK_BY_CATEGORY EXPOSURE_SCORE 갱신
-- 기존: (절도+화재+침수 정규화 평균) 간접 추정값
-- 갱신: GRANDATA.FLOATING_POPULATION_INFO 실측 유동인구 정규화
-- 정규화 방식: 구별 유동인구 / 서울 최대 유동인구 구
-- ═══════════════════════════════════════════════════════════

-- 2.4-1. 유동인구 기반 EXPOSURE_SCORE 갱신
-- 유동인구가 많을수록 사고 노출 빈도 상승 → 리스크 스코어 상승
-- 전체 카테고리(CATEGORY_ID 1~6)에 동일하게 적용
MERGE INTO FACT_GU_RISK_BY_CATEGORY tgt
USING (
    WITH
    -- 최신 기준년월 (최근 3개월 평균으로 계절성 완화)
    fp_recent AS (
        SELECT DISTINCT BASE_YM
        FROM GRANDATA.FLOATING_POPULATION_INFO
        ORDER BY BASE_YM DESC
        LIMIT 3
    ),
    -- 구별 유동인구 합계 (최근 3개월 평균, 성별/연령 무관 전체 합산)
    fp_by_gu AS (
        SELECT
            fp.ADDR_GU                          AS GU_NAME,
            AVG(fp.POP_CNT)                     AS AVG_FLOATING_POP
        FROM GRANDATA.FLOATING_POPULATION_INFO fp
        JOIN fp_recent fr ON fp.BASE_YM = fr.BASE_YM
        WHERE fp.ADDR_GU IS NOT NULL
        GROUP BY fp.ADDR_GU
    ),
    -- 서울 최대 유동인구 구 기준 정규화 (0~1)
    fp_max AS (
        SELECT MAX(AVG_FLOATING_POP) AS MAX_POP
        FROM fp_by_gu
    ),
    -- 구별 정규화 EXPOSURE_SCORE
    fp_normalized AS (
        SELECT
            fg.GU_NAME,
            ROUND(fg.AVG_FLOATING_POP / NULLIF(fm.MAX_POP, 0), 4) AS EXPOSURE_SCORE_NEW
        FROM fp_by_gu fg
        CROSS JOIN fp_max fm
    ),
    -- 모든 카테고리(1~6)에 걸쳐 갱신할 행 목록
    update_targets AS (
        SELECT
            fn.GU_NAME,
            d.CATEGORY_ID,
            fn.EXPOSURE_SCORE_NEW
        FROM fp_normalized fn
        CROSS JOIN (SELECT CATEGORY_ID FROM DIM_ASSET_CATEGORY) d
    )
    SELECT GU_NAME, CATEGORY_ID, EXPOSURE_SCORE_NEW
    FROM update_targets
) src
ON  tgt.GU_NAME     = src.GU_NAME
AND tgt.CATEGORY_ID = src.CATEGORY_ID
WHEN MATCHED THEN UPDATE SET
    -- EXPOSURE_SCORE만 갱신 (절도/화재/침수/건물노후/CCTV는 기존 공공데이터 유지)
    tgt.EXPOSURE_SCORE        = src.EXPOSURE_SCORE_NEW,
    -- COMPOSITE_RISK_SCORE 재계산: 기존 공식에서 EXPOSURE 반영 비중 추가 (10% 반영)
    tgt.COMPOSITE_RISK_SCORE  = ROUND(
        tgt.FIRE_RISK_SCORE   * (SELECT RISK_WEIGHT_FIRE   FROM DIM_ASSET_CATEGORY WHERE CATEGORY_ID = src.CATEGORY_ID)
        + tgt.THEFT_RISK_SCORE  * (SELECT RISK_WEIGHT_THEFT  FROM DIM_ASSET_CATEGORY WHERE CATEGORY_ID = src.CATEGORY_ID)
        + tgt.FLOOD_RISK_SCORE  * (SELECT RISK_WEIGHT_FLOOD  FROM DIM_ASSET_CATEGORY WHERE CATEGORY_ID = src.CATEGORY_ID)
        + tgt.BUILDING_AGE_SCORE * (SELECT RISK_WEIGHT_DAMAGE FROM DIM_ASSET_CATEGORY WHERE CATEGORY_ID = src.CATEGORY_ID) * 0.5
        + src.EXPOSURE_SCORE_NEW * 0.10     -- 실측 유동인구 노출도 10% 반영
        - tgt.CCTV_SAFETY_SCORE * 0.10
    , 3),
    tgt.DATA_QUALITY          = 'MEASURED',
    tgt.LOAD_TIMESTAMP        = CURRENT_TIMESTAMP();

-- 2.4-2. EXPOSURE_SCORE 갱신 결과 확인 (기존 추정값과 비교)
-- 갱신 전 추정값: (절도+화재+침수 정규화) / 3
-- 갱신 후 실측값: 유동인구 정규화
SELECT
    r.GU_NAME,
    -- 기존 간접 추정값 (절도/화재/침수 평균) — 참고용 재계산
    ROUND((r.THEFT_RISK_SCORE + r.FIRE_RISK_SCORE + r.FLOOD_RISK_SCORE) / 3, 3)
        AS OLD_EXPOSURE_ESTIMATE,
    -- 신규 유동인구 실측값
    r.EXPOSURE_SCORE          AS NEW_EXPOSURE_MEASURED,
    -- 차이값 (양수면 실측이 더 높음)
    ROUND(r.EXPOSURE_SCORE - (r.THEFT_RISK_SCORE + r.FIRE_RISK_SCORE + r.FLOOD_RISK_SCORE) / 3, 3)
        AS DELTA,
    r.DATA_QUALITY
FROM FACT_GU_RISK_BY_CATEGORY r
WHERE r.CATEGORY_ID = 1   -- 전자기기 대표 카테고리로 비교
ORDER BY NEW_EXPOSURE_MEASURED DESC;


-- ═══════════════════════════════════════════════════════════
-- PART 2.5: DATA_QUALITY 플래그 최종 정리
-- 실측 데이터가 없는 구(갱신 미대상)는 ESTIMATED 유지 확인
-- ═══════════════════════════════════════════════════════════

-- 2.5-1. FACT_GU_ASSET_PROFILE 데이터 품질 현황
SELECT
    DATA_QUALITY,
    DATA_SOURCE,
    COUNT(*)                            AS ROW_CNT,
    COUNT(DISTINCT GU_NAME)             AS GU_CNT,
    ROUND(AVG(CONSUMPTION_RATIO), 4)    AS AVG_CONSUMPTION_RATIO,
    ROUND(AVG(ESTIMATED_AVG_VALUE))     AS AVG_ASSET_VALUE
FROM FACT_GU_ASSET_PROFILE
GROUP BY DATA_QUALITY, DATA_SOURCE
ORDER BY DATA_QUALITY, DATA_SOURCE;

-- 2.5-2. FACT_GU_RISK_BY_CATEGORY 데이터 품질 현황
SELECT
    DATA_QUALITY,
    COUNT(*)                              AS ROW_CNT,
    COUNT(DISTINCT GU_NAME)               AS GU_CNT,
    ROUND(AVG(EXPOSURE_SCORE), 4)         AS AVG_EXPOSURE,
    ROUND(AVG(COMPOSITE_RISK_SCORE), 4)   AS AVG_COMPOSITE_RISK
FROM FACT_GU_RISK_BY_CATEGORY
GROUP BY DATA_QUALITY
ORDER BY DATA_QUALITY;

-- 2.5-3. 갱신 대상 누락 구 확인 (카드매출/렌탈/유동인구 모두 없는 구)
SELECT p.GU_NAME, p.CATEGORY_ID, p.DATA_QUALITY, p.DATA_SOURCE
FROM FACT_GU_ASSET_PROFILE p
WHERE p.DATA_QUALITY = 'ESTIMATED'
  AND p.CATEGORY_ID IN (2, 3, 4, 5)
ORDER BY p.GU_NAME, p.CATEGORY_ID;


-- ═══════════════════════════════════════════════════════════
-- PART 2.6: 통합 검증 쿼리
-- 28번과 동일한 형식으로 갱신 후 결과 비교
-- ═══════════════════════════════════════════════════════════

-- 2.6-1. 구별 소비 프로파일: 실측 데이터 반영 전/후 비교 (서초/중구/영등포 중심)
SELECT
    p.GU_NAME,
    c.CATEGORY_NAME,
    p.CONSUMPTION_RATIO,
    p.ESTIMATED_AVG_VALUE,
    p.DATA_SOURCE,
    p.DATA_QUALITY
FROM FACT_GU_ASSET_PROFILE p
JOIN DIM_ASSET_CATEGORY c ON p.CATEGORY_ID = c.CATEGORY_ID
WHERE p.GU_NAME IN ('서초구', '중구', '영등포구', '강남구', '관악구')
ORDER BY p.GU_NAME, p.CATEGORY_ID;

-- 2.6-2. 리스크 매트릭스: 유동인구 EXPOSURE_SCORE 반영 후 비교
SELECT
    r.GU_NAME,
    c.CATEGORY_NAME,
    r.THEFT_RISK_SCORE,
    r.FIRE_RISK_SCORE,
    r.FLOOD_RISK_SCORE,
    r.EXPOSURE_SCORE,        -- 유동인구 실측값으로 갱신됨
    r.CCTV_SAFETY_SCORE,
    r.COMPOSITE_RISK_SCORE,  -- 노출도 재반영 후 재계산됨
    r.DATA_QUALITY
FROM FACT_GU_RISK_BY_CATEGORY r
JOIN DIM_ASSET_CATEGORY c ON r.CATEGORY_ID = c.CATEGORY_ID
WHERE r.GU_NAME IN ('서초구', '중구', '영등포구')
ORDER BY r.GU_NAME, c.CATEGORY_ID;

-- 2.6-3. 카테고리별 리스크 전체 통계 (갱신 후)
SELECT
    c.CATEGORY_NAME,
    ROUND(AVG(r.EXPOSURE_SCORE), 3)         AS AVG_EXPOSURE_SCORE,
    ROUND(AVG(r.COMPOSITE_RISK_SCORE), 3)   AS AVG_COMPOSITE_RISK,
    ROUND(MIN(r.COMPOSITE_RISK_SCORE), 3)   AS MIN_RISK,
    ROUND(MAX(r.COMPOSITE_RISK_SCORE), 3)   AS MAX_RISK,
    -- MEASURED 비율: 실측 데이터로 채워진 비중
    ROUND(SUM(CASE WHEN r.DATA_QUALITY = 'MEASURED' THEN 1 ELSE 0 END)
          / COUNT(*), 2)                    AS MEASURED_RATIO
FROM FACT_GU_RISK_BY_CATEGORY r
JOIN DIM_ASSET_CATEGORY c ON r.CATEGORY_ID = c.CATEGORY_ID
GROUP BY c.CATEGORY_NAME
ORDER BY AVG_COMPOSITE_RISK DESC;

-- 2.6-4. 전체 행 수 및 데이터 품질 최종 확인
SELECT 'FACT_GU_ASSET_PROFILE'      AS TBL,
       COUNT(*)                      AS TOTAL_ROWS,
       SUM(CASE WHEN DATA_QUALITY = 'MEASURED'  THEN 1 ELSE 0 END) AS MEASURED_ROWS,
       SUM(CASE WHEN DATA_QUALITY = 'ESTIMATED' THEN 1 ELSE 0 END) AS ESTIMATED_ROWS
FROM FACT_GU_ASSET_PROFILE
UNION ALL
SELECT 'FACT_GU_RISK_BY_CATEGORY',
       COUNT(*),
       SUM(CASE WHEN DATA_QUALITY = 'MEASURED'  THEN 1 ELSE 0 END),
       SUM(CASE WHEN DATA_QUALITY = 'ESTIMATED' THEN 1 ELSE 0 END)
FROM FACT_GU_RISK_BY_CATEGORY;
