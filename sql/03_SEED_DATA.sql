-- ============================================================
-- INSURE: 공공데이터 시드 (서울 25개 구 실제 분포 기반)
-- 실제 통계청/소방청/경찰청 공개 데이터 분포를 반영한 현실적 데이터
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA RAW_PUBLIC;

-- ─────────────────────────────────────────────
-- 1. FIRE_STATS: 서울시 화재발생 통계 (2021~2024, 구별)
-- 실제 서울 연간 화재 ~4,500건 기준 분포
-- ─────────────────────────────────────────────
INSERT INTO FIRE_STATS (YEAR, DISTRICT_NAME, DONG_NAME, TOTAL_FIRES, BUILDING_FIRES, VEHICLE_FIRES, FOREST_FIRES, OTHER_FIRES, DEATHS, INJURIES, PROPERTY_DAMAGE_KRW, ELECTRICAL_CAUSE, MECHANICAL_CAUSE, GAS_CAUSE, CARELESS_CAUSE, ARSON_CAUSE)
WITH districts AS (
  SELECT column1 AS district_name, column2 AS fire_weight, column3 AS pop_weight
  FROM VALUES
    ('강남구', 1.15, 1.1), ('강동구', 0.95, 0.9), ('강북구', 1.05, 0.85),
    ('강서구', 1.10, 1.05), ('관악구', 1.08, 0.95), ('광진구', 0.88, 0.85),
    ('구로구', 1.12, 1.0), ('금천구', 0.92, 0.75), ('노원구', 1.05, 1.1),
    ('도봉구', 0.85, 0.8), ('동대문구', 1.02, 0.9), ('동작구', 0.90, 0.85),
    ('마포구', 0.95, 0.95), ('서대문구', 0.88, 0.8), ('서초구', 1.00, 0.95),
    ('성동구', 0.92, 0.85), ('성북구', 1.00, 1.0), ('송파구', 1.10, 1.15),
    ('양천구', 0.90, 0.95), ('영등포구', 1.18, 1.0), ('용산구', 0.85, 0.7),
    ('은평구', 0.95, 1.0), ('종로구', 0.90, 0.6), ('중구', 0.88, 0.55),
    ('중랑구', 0.98, 0.9)
),
years AS (SELECT column1 AS yr FROM VALUES (2021),(2022),(2023),(2024)),
dongs AS (
  SELECT d.district_name, d.fire_weight, d.pop_weight, y.yr,
         ROW_NUMBER() OVER (PARTITION BY d.district_name ORDER BY y.yr) AS rn
  FROM districts d CROSS JOIN years y
)
SELECT
  yr AS YEAR,
  district_name,
  district_name || ' 전체' AS DONG_NAME,
  ROUND(180 * fire_weight * (1 + (RANDOM() % 10) / 100.0))::INT AS TOTAL_FIRES,
  ROUND(108 * fire_weight * (1 + (RANDOM() % 10) / 100.0))::INT AS BUILDING_FIRES,
  ROUND(22 * fire_weight * (1 + (RANDOM() % 15) / 100.0))::INT AS VEHICLE_FIRES,
  ROUND(3 * fire_weight * (1 + (RANDOM() % 20) / 100.0))::INT AS FOREST_FIRES,
  ROUND(47 * fire_weight * (1 + (RANDOM() % 10) / 100.0))::INT AS OTHER_FIRES,
  ABS(RANDOM() % 4)::INT AS DEATHS,
  ROUND(12 * fire_weight * (1 + (RANDOM() % 20) / 100.0))::INT AS INJURIES,
  ROUND(2500000000 * fire_weight * (1 + (RANDOM() % 30) / 100.0))::BIGINT AS PROPERTY_DAMAGE_KRW,
  ROUND(65 * fire_weight * (1 + (RANDOM() % 10) / 100.0))::INT AS ELECTRICAL,
  ROUND(25 * fire_weight * (1 + (RANDOM() % 10) / 100.0))::INT AS MECHANICAL,
  ROUND(8 * fire_weight * (1 + (RANDOM() % 15) / 100.0))::INT AS GAS,
  ROUND(60 * fire_weight * (1 + (RANDOM() % 10) / 100.0))::INT AS CARELESS,
  ROUND(5 * fire_weight * (1 + (RANDOM() % 20) / 100.0))::INT AS ARSON
FROM dongs;

-- ─────────────────────────────────────────────
-- 2. CRIME_STATS: 서울시 5대범죄 (2021~2024, 구별)
-- 실제 서울 연간 범죄 ~27만건 기준
-- ─────────────────────────────────────────────
INSERT INTO CRIME_STATS (YEAR, DISTRICT_NAME, MURDER, ROBBERY, SEXUAL_ASSAULT, THEFT, VIOLENCE, TOTAL_CRIMES, BURGLARY, VEHICLE_THEFT, PICKPOCKET)
WITH districts AS (
  SELECT column1 AS dn, column2 AS cw -- crime_weight (강남/영등포 등 번화가 높음)
  FROM VALUES
    ('강남구',1.35),('강동구',0.90),('강북구',1.00),('강서구',1.05),('관악구',1.10),
    ('광진구',0.88),('구로구',1.15),('금천구',0.95),('노원구',1.00),('도봉구',0.78),
    ('동대문구',1.00),('동작구',0.85),('마포구',1.02),('서대문구',0.82),('서초구',1.00),
    ('성동구',0.85),('성북구',0.92),('송파구',1.08),('양천구',0.85),('영등포구',1.30),
    ('용산구',0.90),('은평구',0.88),('종로구',1.10),('중구',1.20),('중랑구',0.95)
),
years AS (SELECT column1 AS yr FROM VALUES (2021),(2022),(2023),(2024))
SELECT
  yr, dn,
  GREATEST(ABS(RANDOM() % 5)::INT, 1) AS MURDER,
  GREATEST(ABS(RANDOM() % 8)::INT * ROUND(cw)::INT, 1) AS ROBBERY,
  ROUND(120 * cw * (1 + (RANDOM() % 10)/100.0))::INT AS SEXUAL_ASSAULT,
  ROUND(4200 * cw * (1 + (RANDOM() % 10)/100.0))::INT AS THEFT,
  ROUND(3800 * cw * (1 + (RANDOM() % 10)/100.0))::INT AS VIOLENCE,
  0, -- 아래에서 UPDATE
  ROUND(380 * cw * (1 + (RANDOM() % 15)/100.0))::INT AS BURGLARY,
  ROUND(45 * cw * (1 + (RANDOM() % 20)/100.0))::INT AS VEHICLE_THEFT,
  ROUND(85 * cw * (1 + (RANDOM() % 20)/100.0))::INT AS PICKPOCKET
FROM districts CROSS JOIN years;

UPDATE CRIME_STATS SET TOTAL_CRIMES = MURDER + ROBBERY + SEXUAL_ASSAULT + THEFT + VIOLENCE;

-- ─────────────────────────────────────────────
-- 3. BUILDING_AGE: 노후기간별 주택현황 (2021~2024, 구별)
-- ─────────────────────────────────────────────
INSERT INTO BUILDING_AGE (YEAR, DISTRICT_NAME, TOTAL_BUILDINGS, AGE_UNDER_10Y, AGE_10_TO_20Y, AGE_20_TO_30Y, AGE_30_TO_40Y, AGE_OVER_40Y, AVG_BUILDING_AGE, WOODEN_BUILDINGS, CONCRETE_BUILDINGS, STEEL_BUILDINGS)
WITH districts AS (
  SELECT column1 AS dn, column2 AS total_b, column3 AS avg_age
  FROM VALUES
    ('강남구',38000,22.5),('강동구',28000,18.2),('강북구',22000,32.1),('강서구',35000,20.5),('관악구',30000,28.3),
    ('광진구',24000,25.7),('구로구',32000,26.8),('금천구',18000,24.3),('노원구',34000,25.0),('도봉구',22000,28.5),
    ('동대문구',26000,29.2),('동작구',25000,27.1),('마포구',29000,24.8),('서대문구',24000,30.2),('서초구',32000,21.3),
    ('성동구',25000,26.5),('성북구',28000,31.0),('송파구',40000,19.8),('양천구',27000,23.5),('영등포구',30000,25.5),
    ('용산구',20000,28.0),('은평구',30000,27.5),('종로구',16000,35.2),('중구',14000,33.8),('중랑구',26000,29.5)
),
years AS (SELECT column1 AS yr FROM VALUES (2021),(2022),(2023),(2024))
SELECT
  yr, dn,
  total_b + (yr - 2021) * ROUND(total_b * 0.008)::INT,
  ROUND(total_b * CASE WHEN avg_age < 22 THEN 0.25 WHEN avg_age < 26 THEN 0.18 ELSE 0.12 END)::INT,
  ROUND(total_b * CASE WHEN avg_age < 22 THEN 0.28 WHEN avg_age < 26 THEN 0.25 ELSE 0.20 END)::INT,
  ROUND(total_b * CASE WHEN avg_age < 26 THEN 0.22 ELSE 0.25 END)::INT,
  ROUND(total_b * CASE WHEN avg_age < 28 THEN 0.15 ELSE 0.22 END)::INT,
  ROUND(total_b * CASE WHEN avg_age > 30 THEN 0.25 WHEN avg_age > 28 THEN 0.18 ELSE 0.10 END)::INT,
  avg_age + (yr - 2021) * 0.8,
  ROUND(total_b * CASE WHEN avg_age > 30 THEN 0.08 ELSE 0.03 END)::INT,
  ROUND(total_b * 0.72)::INT,
  ROUND(total_b * 0.15)::INT
FROM districts CROSS JOIN years;

-- ─────────────────────────────────────────────
-- 4. WEATHER_RISK: 기상 위험도 (2021~2024, 구별/월별)
-- ─────────────────────────────────────────────
INSERT INTO WEATHER_RISK (YEAR_MONTH, DISTRICT_NAME, AVG_TEMPERATURE, MAX_TEMPERATURE, MIN_TEMPERATURE, TOTAL_RAINFALL_MM, MAX_DAILY_RAINFALL_MM, TYPHOON_AFFECTED_DAYS, HEAVY_RAIN_DAYS, SNOW_DAYS, FLOOD_RISK_SCORE, WIND_RISK_SCORE)
WITH districts AS (
  SELECT column1 AS dn, column2 AS flood_base -- 저지대 구는 침수위험 높음
  FROM VALUES
    ('강남구',45),('강동구',40),('강북구',35),('강서구',55),('관악구',42),
    ('광진구',50),('구로구',48),('금천구',52),('노원구',30),('도봉구',28),
    ('동대문구',35),('동작구',55),('마포구',50),('서대문구',32),('서초구',48),
    ('성동구',58),('성북구',30),('송파구',52),('양천구',50),('영등포구',60),
    ('용산구',45),('은평구',35),('종로구',30),('중구',42),('중랑구',38)
),
months AS (
  SELECT column1 AS yr, column2 AS mn,
         column3 AS avg_t, column4 AS rain_mm, column5 AS snow_d
  FROM VALUES
    (2021,1,-2.5,20,8),(2021,2,1.2,28,5),(2021,3,7.8,45,1),(2021,4,13.5,75,0),
    (2021,5,18.2,90,0),(2021,6,23.8,180,0),(2021,7,26.5,350,0),(2021,8,27.2,320,0),
    (2021,9,22.1,150,0),(2021,10,15.3,50,0),(2021,11,7.5,40,0),(2021,12,-0.8,18,6),
    (2022,1,-3.2,15,9),(2022,2,0.5,22,6),(2022,3,8.5,50,0),(2022,4,14.2,80,0),
    (2022,5,19.0,85,0),(2022,6,24.5,160,0),(2022,7,27.0,420,0),(2022,8,26.8,380,0),
    (2022,9,21.5,130,0),(2022,10,14.8,55,0),(2022,11,6.8,35,1),(2022,12,-1.5,20,7),
    (2023,1,-2.0,25,7),(2023,2,2.0,30,4),(2023,3,9.2,55,0),(2023,4,14.8,70,0),
    (2023,5,19.5,95,0),(2023,6,25.0,200,0),(2023,7,27.5,380,0),(2023,8,28.0,290,0),
    (2023,9,23.0,140,0),(2023,10,16.0,48,0),(2023,11,8.0,42,0),(2023,12,0.0,22,5),
    (2024,1,-1.8,18,8),(2024,2,1.5,26,5),(2024,3,8.0,48,1),(2024,4,13.8,82,0),
    (2024,5,18.8,88,0),(2024,6,24.0,190,0),(2024,7,27.8,400,0),(2024,8,27.5,310,0),
    (2024,9,22.5,145,0),(2024,10,15.5,52,0),(2024,11,7.2,38,1),(2024,12,-1.0,20,6)
)
SELECT
  LPAD(yr::VARCHAR,4,'0') || LPAD(mn::VARCHAR,2,'0'),
  dn,
  avg_t + (ABS(RANDOM() % 20) - 10) / 10.0,
  avg_t + 5 + ABS(RANDOM() % 30) / 10.0,
  avg_t - 5 - ABS(RANDOM() % 30) / 10.0,
  rain_mm * (1 + (ABS(RANDOM() % 20) - 10) / 100.0),
  rain_mm * 0.35 * (1 + ABS(RANDOM() % 30) / 100.0),
  CASE WHEN mn BETWEEN 7 AND 9 THEN ABS(RANDOM() % 3)::INT ELSE 0 END,
  CASE WHEN mn BETWEEN 6 AND 9 THEN ABS(RANDOM() % 5)::INT ELSE 0 END,
  snow_d,
  CASE WHEN mn BETWEEN 6 AND 9 THEN flood_base * rain_mm / 350.0 * (1 + ABS(RANDOM() % 20)/100.0)
       ELSE flood_base * 0.15 END,
  CASE WHEN mn BETWEEN 7 AND 9 THEN 15 + ABS(RANDOM() % 25)::INT
       WHEN mn IN (3,4,11,12) THEN 10 + ABS(RANDOM() % 15)::INT
       ELSE 5 + ABS(RANDOM() % 10)::INT END
FROM districts CROSS JOIN months;

-- ─────────────────────────────────────────────
-- 5. SINGLE_HOUSEHOLD: 1인가구 통계 (구별, 2021~2024)
-- 실제 서울 1인가구 비율 ~35% 기준
-- ─────────────────────────────────────────────
INSERT INTO SINGLE_HOUSEHOLD (YEAR, DISTRICT_NAME, DONG_NAME, TOTAL_HOUSEHOLDS, SINGLE_HOUSEHOLDS, SINGLE_HOUSEHOLD_RATE, SINGLE_MALE, SINGLE_FEMALE, SINGLE_AGE_20S, SINGLE_AGE_30S, SINGLE_AGE_40S, SINGLE_AGE_50S, SINGLE_AGE_60PLUS)
WITH districts AS (
  SELECT column1 AS dn, column2 AS total_hh, column3 AS single_rate
  FROM VALUES
    ('강남구',240000,33.5),('강동구',185000,31.2),('강북구',140000,38.5),('강서구',235000,34.0),('관악구',145000,48.2),
    ('광진구',155000,40.5),('구로구',175000,35.8),('금천구',108000,42.1),('노원구',210000,28.5),('도봉구',140000,29.0),
    ('동대문구',155000,37.2),('동작구',170000,38.0),('마포구',175000,42.8),('서대문구',145000,40.2),('서초구',180000,32.0),
    ('성동구',135000,36.5),('성북구',175000,35.0),('송파구',270000,30.5),('양천구',170000,26.8),('영등포구',175000,40.5),
    ('용산구',110000,38.8),('은평구',195000,33.0),('종로구',72000,45.5),('중구',62000,42.8),('중랑구',165000,34.5)
),
years AS (SELECT column1 AS yr FROM VALUES (2021),(2022),(2023),(2024))
SELECT
  yr, dn, dn || ' 전체',
  total_hh + (yr - 2021) * ROUND(total_hh * 0.005)::INT,
  ROUND((total_hh + (yr - 2021) * ROUND(total_hh * 0.005)::INT) * single_rate / 100)::INT,
  single_rate + (yr - 2021) * 0.3,
  ROUND((total_hh * single_rate / 100) * 0.48)::INT,
  ROUND((total_hh * single_rate / 100) * 0.52)::INT,
  ROUND((total_hh * single_rate / 100) * CASE WHEN single_rate > 42 THEN 0.32 ELSE 0.22 END)::INT,
  ROUND((total_hh * single_rate / 100) * 0.25)::INT,
  ROUND((total_hh * single_rate / 100) * 0.18)::INT,
  ROUND((total_hh * single_rate / 100) * 0.15)::INT,
  ROUND((total_hh * single_rate / 100) * CASE WHEN single_rate > 38 THEN 0.12 ELSE 0.18 END)::INT
FROM districts CROSS JOIN years;

-- ─────────────────────────────────────────────
-- 6. CCTV_INSTALLATION (구별, 2021~2024)
-- 실제 서울 CCTV ~8만대 기준
-- ─────────────────────────────────────────────
INSERT INTO CCTV_INSTALLATION (YEAR, DISTRICT_NAME, TOTAL_CCTV, CRIME_PREVENTION, TRAFFIC_CONTROL, FACILITY_SAFETY, FIRE_PREVENTION, CHILD_PROTECTION, CCTV_PER_1000_PEOPLE)
WITH districts AS (
  SELECT column1 AS dn, column2 AS base_cctv, column3 AS pop_1k
  FROM VALUES
    ('강남구',4200,560),('강동구',3100,450),('강북구',2500,300),('강서구',3800,580),('관악구',3200,500),
    ('광진구',2800,360),('구로구',3500,420),('금천구',2200,240),('노원구',3600,520),('도봉구',2300,330),
    ('동대문구',2800,350),('동작구',2700,400),('마포구',3200,380),('서대문구',2500,320),('서초구',3500,430),
    ('성동구',2600,310),('성북구',2900,440),('송파구',4000,680),('양천구',2800,460),('영등포구',3600,400),
    ('용산구',2400,240),('은평구',3000,480),('종로구',2200,150),('중구',2000,130),('중랑구',2700,400)
),
years AS (SELECT column1 AS yr FROM VALUES (2021),(2022),(2023),(2024))
SELECT
  yr, dn,
  base_cctv + (yr - 2021) * ROUND(base_cctv * 0.08)::INT,
  ROUND((base_cctv + (yr - 2021) * ROUND(base_cctv * 0.08)::INT) * 0.55)::INT,
  ROUND((base_cctv + (yr - 2021) * ROUND(base_cctv * 0.08)::INT) * 0.22)::INT,
  ROUND((base_cctv + (yr - 2021) * ROUND(base_cctv * 0.08)::INT) * 0.12)::INT,
  ROUND((base_cctv + (yr - 2021) * ROUND(base_cctv * 0.08)::INT) * 0.05)::INT,
  ROUND((base_cctv + (yr - 2021) * ROUND(base_cctv * 0.08)::INT) * 0.06)::INT,
  ROUND((base_cctv + (yr - 2021) * ROUND(base_cctv * 0.08)::INT) / (pop_1k * 1.0), 1)
FROM districts CROSS JOIN years;

-- ─────────────────────────────────────────────
-- 7. REAL_ESTATE_TRANSACTIONS (구별/월별, 2021~2024)
-- ─────────────────────────────────────────────
INSERT INTO REAL_ESTATE_TRANSACTIONS (YEAR_MONTH, DISTRICT_NAME, APT_SALES_COUNT, APT_JEONSE_COUNT, APT_MONTHLY_RENT_COUNT, OFFICETEL_SALES_COUNT, OFFICETEL_RENT_COUNT, VILLA_SALES_COUNT, VILLA_RENT_COUNT, TOTAL_TRANSACTIONS, AVG_APT_PRICE_10K, MOVING_INDEX)
WITH districts AS (
  SELECT column1 AS dn, column2 AS tx_weight, column3 AS avg_price_10k
  FROM VALUES
    ('강남구',1.8,180000),('강동구',1.2,95000),('강북구',0.7,45000),('강서구',1.3,75000),('관악구',0.9,55000),
    ('광진구',0.9,80000),('구로구',1.0,60000),('금천구',0.7,50000),('노원구',1.1,55000),('도봉구',0.8,45000),
    ('동대문구',0.9,60000),('동작구',1.0,75000),('마포구',1.2,95000),('서대문구',0.8,65000),('서초구',1.6,165000),
    ('성동구',1.0,90000),('성북구',0.9,55000),('송파구',1.5,120000),('양천구',1.0,80000),('영등포구',1.3,85000),
    ('용산구',1.1,130000),('은평구',1.0,55000),('종로구',0.6,80000),('중구',0.5,85000),('중랑구',0.8,48000)
),
months AS (
  SELECT column1 AS yr, column2 AS mn, column3 AS seasonal -- 계절성: 봄/가을 성수기
  FROM VALUES
    (2021,1,0.7),(2021,2,0.8),(2021,3,1.1),(2021,4,1.2),(2021,5,1.15),(2021,6,1.0),
    (2021,7,0.85),(2021,8,0.8),(2021,9,1.1),(2021,10,1.15),(2021,11,0.95),(2021,12,0.7),
    (2022,1,0.65),(2022,2,0.75),(2022,3,1.0),(2022,4,1.1),(2022,5,1.05),(2022,6,0.9),
    (2022,7,0.75),(2022,8,0.7),(2022,9,0.95),(2022,10,1.0),(2022,11,0.85),(2022,12,0.6),
    (2023,1,0.6),(2023,2,0.7),(2023,3,0.95),(2023,4,1.05),(2023,5,1.1),(2023,6,1.0),
    (2023,7,0.85),(2023,8,0.8),(2023,9,1.05),(2023,10,1.1),(2023,11,0.9),(2023,12,0.65),
    (2024,1,0.7),(2024,2,0.8),(2024,3,1.05),(2024,4,1.15),(2024,5,1.2),(2024,6,1.05),
    (2024,7,0.9),(2024,8,0.85),(2024,9,1.1),(2024,10,1.2),(2024,11,1.0),(2024,12,0.75)
)
SELECT
  LPAD(yr::VARCHAR,4,'0') || LPAD(mn::VARCHAR,2,'0'),
  dn,
  ROUND(180 * tx_weight * seasonal)::INT,
  ROUND(250 * tx_weight * seasonal)::INT,
  ROUND(320 * tx_weight * seasonal)::INT,
  ROUND(35 * tx_weight * seasonal)::INT,
  ROUND(120 * tx_weight * seasonal)::INT,
  ROUND(80 * tx_weight * seasonal)::INT,
  ROUND(150 * tx_weight * seasonal)::INT,
  0,
  avg_price_10k + ROUND(avg_price_10k * (yr - 2021) * 0.03 * (1 + (ABS(RANDOM() % 10) - 5)/100.0))::BIGINT,
  ROUND((seasonal - 1.0) * 100, 1)
FROM districts CROSS JOIN months;

UPDATE REAL_ESTATE_TRANSACTIONS
SET TOTAL_TRANSACTIONS = APT_SALES_COUNT + APT_JEONSE_COUNT + APT_MONTHLY_RENT_COUNT
                        + OFFICETEL_SALES_COUNT + OFFICETEL_RENT_COUNT
                        + VILLA_SALES_COUNT + VILLA_RENT_COUNT;

-- ─────────────────────────────────────────────
-- 8. FIRE_FACILITY (구별, 2021~2024)
-- ─────────────────────────────────────────────
INSERT INTO FIRE_FACILITY (YEAR, DISTRICT_NAME, FIRE_STATIONS, FIRE_SUBSTATIONS, FIRE_TRUCKS, AMBULANCES, FIRE_HYDRANTS, FIREFIGHTERS, AVG_RESPONSE_TIME_SEC, BUILDINGS_PER_STATION, FIRE_SAFETY_SCORE)
WITH districts AS (
  SELECT column1 AS dn, column2 AS stations, column3 AS substations, column4 AS buildings, column5 AS resp_time
  FROM VALUES
    ('강남구',2,8,38000,285),('강동구',1,6,28000,310),('강북구',1,5,22000,340),('강서구',2,7,35000,295),('관악구',1,6,30000,320),
    ('광진구',1,5,24000,315),('구로구',1,6,32000,305),('금천구',1,4,18000,325),('노원구',2,6,34000,300),('도봉구',1,5,22000,330),
    ('동대문구',1,5,26000,320),('동작구',1,5,25000,315),('마포구',2,6,29000,290),('서대문구',1,5,24000,325),('서초구',2,7,32000,280),
    ('성동구',1,5,25000,310),('성북구',1,6,28000,330),('송파구',2,8,40000,290),('양천구',1,6,27000,305),('영등포구',2,7,30000,300),
    ('용산구',1,5,20000,295),('은평구',1,6,30000,315),('종로구',1,5,16000,290),('중구',1,5,14000,275),('중랑구',1,5,26000,325)
),
years AS (SELECT column1 AS yr FROM VALUES (2021),(2022),(2023),(2024))
SELECT
  yr, dn, stations, substations + (yr - 2021),
  (stations + substations) * 3 + ABS(RANDOM() % 5)::INT,
  (stations + substations) * 2,
  ROUND(buildings * 0.015)::INT + (yr - 2021) * 20,
  stations * 85 + substations * 22 + (yr - 2021) * 5,
  resp_time - (yr - 2021) * 8 + ABS(RANDOM() % 20)::INT - 10,
  ROUND(buildings / (stations + substations + 0.0), 0),
  ROUND(100 - (resp_time / 400.0 * 30) - (buildings / (stations + substations + 0.0) / 5000.0 * 20) + (yr - 2021) * 2, 1)
FROM districts CROSS JOIN years;

-- ─────────────────────────────────────────────
-- 9. CONSUMER_ACCIDENT: CISS 가전사고 (2021~2024, 분기별)
-- Cortex LLM 분석용 텍스트 데이터 포함
-- ─────────────────────────────────────────────
INSERT INTO CONSUMER_ACCIDENT (YEAR, QUARTER, ACCIDENT_TYPE, PRODUCT_CATEGORY, PRODUCT_DETAIL, ACCIDENT_COUNT, INJURY_COUNT, DEATH_COUNT, PROPERTY_DAMAGE_YN, CAUSE_SUMMARY, DISTRICT_NAME)
SELECT * FROM (
  SELECT 2021 AS yr, 1 AS q, '화재' AS atype, '가전제품' AS pcat, '에어프라이어' AS pd, 42, 12, 0, 'Y', '과열로 인한 내부 발화. 장시간 사용 중 온도 조절 장치 오작동으로 기름때에 착화', '강남구'
  UNION ALL SELECT 2021, 1, '감전', '가전제품', '세탁기', 28, 18, 1, 'N', '접지 불량 상태에서 습기 유입으로 감전. 노후 배선과 결합하여 감전 위험 증가', '강서구'
  UNION ALL SELECT 2021, 2, '화재', '가전제품', '전기장판', 65, 8, 2, 'Y', '접힌 상태로 장기간 통전하여 과열 발화. 절연체 열화가 주요 원인', '노원구'
  UNION ALL SELECT 2021, 2, '폭발', '가전제품', '전자레인지', 18, 5, 0, 'Y', '금속 용기 사용으로 인한 아크 발생 및 내부 폭발. 사용자 부주의가 원인', '영등포구'
  UNION ALL SELECT 2021, 3, '화재', '가전제품', '에어컨', 38, 4, 0, 'Y', '실외기 콘덴서 과열 및 냉매 누출로 인한 발화. 청소 미흡이 주요 원인', '송파구'
  UNION ALL SELECT 2021, 3, '감전', '가전제품', '전기온수기', 22, 15, 1, 'N', '방수 처리 불량으로 물 유입 시 감전. 10년 이상 노후 제품에서 집중 발생', '관악구'
  UNION ALL SELECT 2021, 4, '화재', '가전제품', '건조기', 55, 10, 0, 'Y', '린트필터 미청소로 인한 과열 발화. 배기구 막힘과 복합 작용', '구로구'
  UNION ALL SELECT 2021, 4, '화재', '생활용품', '멀티탭', 120, 22, 1, 'Y', '문어발 콘센트 과부하로 인한 발열 및 발화. 최대 용량 초과 사용이 원인', '동대문구'
  UNION ALL SELECT 2022, 1, '화재', '가전제품', '공기청정기', 15, 3, 0, 'Y', '리튬이온 배터리 셀 불량으로 자연 발화. 충전 중 발생 비율 높음', '서초구'
  UNION ALL SELECT 2022, 1, '감전', '가전제품', '식기세척기', 20, 12, 0, 'N', '급수 호스 연결부 누수로 인한 감전. 설치 불량이 주요 원인', '마포구'
  UNION ALL SELECT 2022, 2, '화재', '가전제품', '전기밥솥', 32, 5, 0, 'Y', '내부 열선 단락으로 발화. 10년 이상 사용 제품에서 빈발', '성북구'
  UNION ALL SELECT 2022, 2, '화재', '가전제품', '냉장고', 25, 3, 0, 'Y', '컴프레서 과열 및 냉매 누출로 인한 발화. 방열판 먼지 축적이 원인', '강동구'
  UNION ALL SELECT 2022, 3, '화재', '가전제품', 'TV', 18, 2, 0, 'Y', '메인보드 콘덴서 폭발로 발화. 낙뢰 후 서지 전압이 원인', '중랑구'
  UNION ALL SELECT 2022, 3, '폭발', '가전제품', '전기압력밥솥', 28, 20, 0, 'Y', '안전밸브 고장으로 내부 압력 과다 상승. 패킹 열화가 근본 원인', '양천구'
  UNION ALL SELECT 2022, 4, '화재', '생활용품', '보조배터리', 85, 15, 0, 'Y', '리튬폴리머 배터리 팽창 후 발화. 물리적 충격 및 고온 노출이 원인', '강남구'
  UNION ALL SELECT 2022, 4, '화재', '가전제품', '로봇청소기', 22, 4, 0, 'Y', '충전 스테이션 과열로 발화. 충전 회로 설계 결함', '서초구'
  UNION ALL SELECT 2023, 1, '화재', '가전제품', '전기히터', 78, 18, 2, 'Y', '가연물 근접 상태에서 장시간 사용. 과열 방지 센서 미작동', '도봉구'
  UNION ALL SELECT 2023, 1, '감전', '가전제품', '비데', 35, 22, 0, 'N', '방수 패킹 열화로 내부 물 유입. 접지선 미연결 상태에서 감전', '은평구'
  UNION ALL SELECT 2023, 2, '화재', '가전제품', '인덕션', 25, 6, 0, 'Y', '조리용기 미감지 상태에서 공회전. 유리 상판 과열 후 하부 기판 발화', '용산구'
  UNION ALL SELECT 2023, 2, '화재', '가전제품', '드라이기', 40, 8, 0, 'Y', '흡입구 먼지 축적으로 모터 과열. 안전 차단 장치 미작동', '광진구'
  UNION ALL SELECT 2023, 3, '화재', '가전제품', '전기자전거배터리', 92, 25, 3, 'Y', '비정품 충전기 사용으로 과충전. 리튬이온 배터리 열폭주 연쇄반응', '영등포구'
  UNION ALL SELECT 2023, 3, '화재', '가전제품', '에어프라이어', 48, 10, 0, 'Y', '내부 코팅 박리 후 식재료 잔여물 착화. 열선 직접 노출이 원인', '송파구'
  UNION ALL SELECT 2023, 4, '화재', '생활용품', 'USB충전기', 55, 8, 0, 'Y', '비인증 저가 충전기 회로 단락. KC 미인증 제품에서 집중 발생', '구로구'
  UNION ALL SELECT 2023, 4, '감전', '가전제품', '음식물처리기', 15, 8, 0, 'N', '분쇄 모터 방수 불량으로 물 유입 시 감전. 싱크대 하부 습기가 원인', '동작구'
  UNION ALL SELECT 2024, 1, '화재', '가전제품', '전기장판', 72, 12, 1, 'Y', '접힘 사용으로 열선 단선 후 단락 발화. 5년 이상 사용 제품에서 집중', '노원구'
  UNION ALL SELECT 2024, 1, '화재', '가전제품', '김치냉장고', 18, 2, 0, 'Y', '배면부 릴레이 스위치 접촉 불량으로 스파크 발생. 10년 이상 노후 제품', '성동구'
  UNION ALL SELECT 2024, 2, '화재', '가전제품', '스타일러', 12, 3, 0, 'Y', '스팀 발생 장치 과열. 급수 시스템 고장으로 공연소 상태 발생', '강남구'
  UNION ALL SELECT 2024, 2, '폭발', '가전제품', '전동킥보드배터리', 68, 30, 2, 'Y', '충격 후 배터리 셀 변형으로 열폭주. 비정품 배터리 교체 후 발생', '마포구'
  UNION ALL SELECT 2024, 3, '화재', '가전제품', '에어컨', 42, 5, 0, 'Y', '실외기 배선 피복 열화로 단락. 직사광선 장기 노출과 청소 미흡 복합', '서대문구'
  UNION ALL SELECT 2024, 3, '화재', '가전제품', '세탁기', 30, 8, 0, 'Y', '베어링 마모로 드럼 과열 후 발화. 세제 찌꺼기 축적이 촉진제 역할', '금천구'
  UNION ALL SELECT 2024, 4, '화재', '생활용품', '멀티탭', 135, 28, 1, 'Y', '20년 이상 노후 멀티탭 과부하. 접촉 저항 증가로 발열 후 발화', '강북구'
  UNION ALL SELECT 2024, 4, '화재', '가전제품', '건조기', 62, 14, 0, 'Y', '배기 덕트 린트 축적으로 배기 불량. 과열 보호 장치 우회 사용이 원인', '송파구'
);

-- ─────────────────────────────────────────────
-- 최종 확인
-- ─────────────────────────────────────────────
SELECT 'FIRE_STATS' AS tbl, COUNT(*) AS rows FROM FIRE_STATS
UNION ALL SELECT 'CRIME_STATS', COUNT(*) FROM CRIME_STATS
UNION ALL SELECT 'BUILDING_AGE', COUNT(*) FROM BUILDING_AGE
UNION ALL SELECT 'WEATHER_RISK', COUNT(*) FROM WEATHER_RISK
UNION ALL SELECT 'SINGLE_HOUSEHOLD', COUNT(*) FROM SINGLE_HOUSEHOLD
UNION ALL SELECT 'CCTV_INSTALLATION', COUNT(*) FROM CCTV_INSTALLATION
UNION ALL SELECT 'REAL_ESTATE_TRANSACTIONS', COUNT(*) FROM REAL_ESTATE_TRANSACTIONS
UNION ALL SELECT 'FIRE_FACILITY', COUNT(*) FROM FIRE_FACILITY
UNION ALL SELECT 'CONSUMER_ACCIDENT', COUNT(*) FROM CONSUMER_ACCIDENT
ORDER BY tbl;
