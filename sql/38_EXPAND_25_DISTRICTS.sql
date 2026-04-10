-- ============================================================
-- 25개 서울 자치구 전체 데이터 확장 (GRANDATA 3개 → 25개)
-- utils.py DISTRICT_PROFILES 기반 시드 데이터
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA RAW_PUBLIC;

-- ─────────────────────────────────────────────
-- 1. FIRE_STATS 확장 (2024년 기준)
-- ─────────────────────────────────────────────
DELETE FROM FIRE_STATS WHERE YEAR = 2024;

INSERT INTO FIRE_STATS (YEAR, DISTRICT_NAME, DONG_NAME, TOTAL_FIRES, BUILDING_FIRES, VEHICLE_FIRES, FOREST_FIRES, OTHER_FIRES, DEATHS, INJURIES, PROPERTY_DAMAGE_KRW, ELECTRICAL_CAUSE, MECHANICAL_CAUSE, GAS_CAUSE, CARELESS_CAUSE, ARSON_CAUSE)
WITH districts AS (
  SELECT * FROM (VALUES
    ('강남구', 1.15, 547000),('강동구', 0.95, 453000),('강북구', 1.05, 303000),('강서구', 1.10, 576000),
    ('관악구', 1.08, 498000),('광진구', 0.88, 352000),('구로구', 1.12, 411000),('금천구', 0.92, 234000),
    ('노원구', 1.05, 519000),('도봉구', 0.85, 326000),('동대문구', 1.02, 352000),('동작구', 0.90, 395000),
    ('마포구', 0.95, 376000),('서대문구', 0.88, 314000),('서초구', 1.00, 432000),('성동구', 0.92, 305000),
    ('성북구', 1.00, 440000),('송파구', 1.10, 667000),('양천구', 0.90, 454000),('영등포구', 1.18, 399000),
    ('용산구', 0.85, 229000),('은평구', 0.95, 480000),('종로구', 0.90, 152000),('중구', 0.88, 133000),
    ('중랑구', 0.98, 393000)
  ) AS t(gu, fire_weight, pop)
)
SELECT
  2024,
  gu,
  gu || ' 전체',
  ROUND(180 * fire_weight)::INT,
  ROUND(108 * fire_weight)::INT,
  ROUND(22 * fire_weight)::INT,
  ROUND(3 * fire_weight)::INT,
  ROUND(47 * fire_weight)::INT,
  1 + (RANDOM() % 3)::INT,
  ROUND(12 * fire_weight)::INT,
  ROUND(2500000000 * fire_weight)::BIGINT,
  ROUND(65 * fire_weight)::INT,
  ROUND(25 * fire_weight)::INT,
  ROUND(8 * fire_weight)::INT,
  ROUND(60 * fire_weight)::INT,
  ROUND(5 * fire_weight)::INT
FROM districts;

-- ─────────────────────────────────────────────
-- 2. CRIME_STATS 확장 (2024년 기준)
-- ─────────────────────────────────────────────
DELETE FROM CRIME_STATS WHERE YEAR = 2024;

INSERT INTO CRIME_STATS (YEAR, DISTRICT_NAME, MURDER, ROBBERY, SEXUAL_ASSAULT, THEFT, VIOLENCE, TOTAL_CRIMES, BURGLARY, VEHICLE_THEFT, PICKPOCKET)
WITH districts AS (
  SELECT * FROM (VALUES
    ('강남구', 1.35),('강동구', 0.90),('강북구', 1.00),('강서구', 1.05),('관악구', 1.10),
    ('광진구', 0.88),('구로구', 1.15),('금천구', 0.95),('노원구', 1.00),('도봉구', 0.78),
    ('동대문구', 1.00),('동작구', 0.85),('마포구', 1.02),('서대문구', 0.82),('서초구', 1.00),
    ('성동구', 0.85),('성북구', 0.92),('송파구', 1.08),('양천구', 0.85),('영등포구', 1.30),
    ('용산구', 0.90),('은평구', 0.88),('종로구', 1.10),('중구', 1.20),('중랑구', 0.95)
  ) AS t(gu, cw)
)
SELECT
  2024,
  gu,
  1 + (RANDOM() % 4)::INT,
  GREATEST(1, ROUND(5 * cw)::INT),
  ROUND(120 * cw)::INT,
  ROUND(4200 * cw)::INT,
  ROUND(3800 * cw)::INT,
  0,
  ROUND(380 * cw)::INT,
  ROUND(45 * cw)::INT,
  ROUND(85 * cw)::INT
FROM districts;

UPDATE CRIME_STATS SET TOTAL_CRIMES = MURDER + ROBBERY + SEXUAL_ASSAULT + THEFT + VIOLENCE WHERE YEAR = 2024;

-- ─────────────────────────────────────────────
-- 3. BUILDING_AGE 확장 (2024년 기준)
-- ─────────────────────────────────────────────
DELETE FROM BUILDING_AGE WHERE YEAR = 2024;

INSERT INTO BUILDING_AGE (YEAR, DISTRICT_NAME, TOTAL_BUILDINGS, AGE_UNDER_10Y, AGE_10_TO_20Y, AGE_20_TO_30Y, AGE_30_TO_40Y, AGE_OVER_40Y, AVG_BUILDING_AGE, WOODEN_BUILDINGS, CONCRETE_BUILDINGS, STEEL_BUILDINGS)
WITH districts AS (
  SELECT * FROM (VALUES
    ('강남구', 18500, 0.25),('강동구', 16200, 0.20),('강북구', 10800, 0.18),('강서구', 20500, 0.22),
    ('관악구', 17800, 0.19),('광진구', 12600, 0.17),('구로구', 14700, 0.21),('금천구', 8400, 0.16),
    ('노원구', 18600, 0.20),('도봉구', 11700, 0.15),('동대문구', 12600, 0.18),('동작구', 14200, 0.19),
    ('마포구', 13500, 0.20),('서대문구', 11300, 0.17),('서초구', 15500, 0.23),('성동구', 10900, 0.18),
    ('성북구', 15800, 0.19),('송파구', 23900, 0.24),('양천구', 16300, 0.19),('영등포구', 14300, 0.20),
    ('용산구', 8200, 0.21),('은평구', 17200, 0.18),('종로구', 5500, 0.16),('중구', 4800, 0.15),
    ('중랑구', 14100, 0.17)
  ) AS t(gu, total, new_ratio)
)
SELECT
  2024,
  gu,
  total,
  ROUND(total * new_ratio)::INT,
  ROUND(total * 0.20)::INT,
  ROUND(total * 0.18)::INT,
  ROUND(total * 0.22)::INT,
  ROUND(total * (1 - new_ratio - 0.20 - 0.18 - 0.22))::INT,
  22.5 + (RANDOM() % 15)::INT,
  ROUND(total * 0.05)::INT,
  ROUND(total * 0.75)::INT,
  ROUND(total * 0.20)::INT
FROM districts;

-- ─────────────────────────────────────────────
-- 4. WEATHER_RISK 확장 (202412 기준)
-- ─────────────────────────────────────────────
DELETE FROM WEATHER_RISK WHERE YEAR_MONTH = '202412';

INSERT INTO WEATHER_RISK (YEAR_MONTH, DISTRICT_NAME, AVG_TEMPERATURE, MAX_TEMPERATURE, MIN_TEMPERATURE, TOTAL_RAINFALL_MM, MAX_DAILY_RAINFALL_MM, TYPHOON_AFFECTED_DAYS, HEAVY_RAIN_DAYS, SNOW_DAYS, FLOOD_RISK_SCORE, WIND_RISK_SCORE)
SELECT '202412', gu, -3.2, 5.1, -8.5, 25.0, 8.5, 0, 0, 8, flood_risk, wind_risk
FROM (SELECT * FROM (VALUES
  ('강남구', 35.0, 28.0),('강동구', 32.0, 25.0),('강북구', 42.0, 35.0),('강서구', 38.0, 32.0),
  ('관악구', 40.0, 33.0),('광진구', 30.0, 24.0),('구로구', 38.0, 31.0),('금천구', 36.0, 30.0),
  ('노원구', 33.0, 27.0),('도봉구', 28.0, 22.0),('동대문구', 40.0, 34.0),('동작구', 35.0, 29.0),
  ('마포구', 32.0, 26.0),('서대문구', 30.0, 24.0),('서초구', 28.0, 22.0),('성동구', 35.0, 29.0),
  ('성북구', 38.0, 32.0),('송파구', 32.0, 26.0),('양천구', 34.0, 28.0),('영등포구', 40.0, 33.0),
  ('용산구', 32.0, 26.0),('은평구', 36.0, 30.0),('종로구', 38.0, 31.0),('중구', 45.0, 38.0),
  ('중랑구', 38.0, 31.0)
) AS t(gu, flood_risk, wind_risk));

-- ─────────────────────────────────────────────
-- 5. CCTV_INSTALLATION 확장 (2024년 기준)
-- ─────────────────────────────────────────────
DELETE FROM CCTV_INSTALLATION WHERE YEAR = 2024;

INSERT INTO CCTV_INSTALLATION (YEAR, DISTRICT_NAME, TOTAL_CCTV, CRIME_PREVENTION, TRAFFIC_CONTROL, FACILITY_SAFETY, FIRE_PREVENTION, CHILD_PROTECTION, CCTV_PER_1000_PEOPLE)
SELECT 2024, gu, total_cctv,
  ROUND(total_cctv * 0.45)::INT,
  ROUND(total_cctv * 0.25)::INT,
  ROUND(total_cctv * 0.15)::INT,
  ROUND(total_cctv * 0.10)::INT,
  ROUND(total_cctv * 0.05)::INT,
  cctv_per_1000
FROM (SELECT * FROM (VALUES
  ('강남구', 2800, 5.1),('강동구', 2100, 4.6),('강북구', 1600, 5.3),('강서구', 2400, 4.2),
  ('관악구', 2200, 4.4),('광진구', 1850, 5.3),('구로구', 2000, 4.9),('금천구', 1200, 5.1),
  ('노원구', 2300, 4.4),('도봉구', 1400, 4.3),('동대문구', 1900, 5.4),('동작구', 1800, 4.6),
  ('마포구', 1900, 5.1),('서대문구', 1500, 4.8),('서초구', 2200, 5.1),('성동구', 1600, 5.2),
  ('성북구', 2000, 4.5),('송파구', 2800, 4.2),('양천구', 2100, 4.6),('영등포구', 2000, 5.0),
  ('용산구', 1400, 6.1),('은평구', 1900, 4.0),('종로구', 1200, 7.9),('중구', 1100, 8.3),
  ('중랑구', 1700, 4.3)
) AS t(gu, total_cctv, cctv_per_1000));

-- ─────────────────────────────────────────────
-- 6. FIRE_FACILITY 확장 (2024년 기준)
-- ─────────────────────────────────────────────
DELETE FROM FIRE_FACILITY WHERE YEAR = 2024;

INSERT INTO FIRE_FACILITY (YEAR, DISTRICT_NAME, FIRE_STATIONS, FIRE_SUBSTATIONS, FIRE_TRUCKS, AMBULANCES, FIRE_HYDRANTS, FIREFIGHTERS, AVG_RESPONSE_TIME_SEC, BUILDINGS_PER_STATION, FIRE_SAFETY_SCORE)
SELECT 2024, gu, stations, subs, trucks, ambulances, hydrants, fighters,
  ROUND((pop / (stations * 10000.0)) * 60.0)::INT,
  ROUND(buildings / GREATEST(stations, 1))::FLOAT,
  ROUND(75.0 + (RANDOM() % 15) - (RANDOM() % 10))::INT
FROM (SELECT * FROM (VALUES
  ('강남구', 547000, 5, 12, 8, 6, 320, 180),('강동구', 453000, 4, 10, 6, 5, 260, 145),
  ('강북구', 303000, 3, 8, 5, 4, 180, 105),('강서구', 576000, 5, 13, 8, 6, 330, 190),
  ('관악구', 498000, 4, 11, 7, 5, 290, 165),('광진구', 352000, 3, 9, 6, 4, 200, 125),
  ('구로구', 411000, 4, 10, 6, 5, 240, 140),('금천구', 234000, 2, 6, 4, 3, 140, 75),
  ('노원구', 519000, 4, 12, 7, 5, 310, 175),('도봉구', 326000, 3, 8, 5, 4, 190, 110),
  ('동대문구', 352000, 3, 9, 6, 4, 210, 130),('동작구', 395000, 3, 10, 6, 4, 230, 135),
  ('마포구', 376000, 3, 10, 6, 4, 220, 130),('서대문구', 314000, 3, 8, 5, 4, 185, 110),
  ('서초구', 432000, 4, 10, 6, 5, 250, 150),('성동구', 305000, 3, 8, 5, 4, 180, 110),
  ('성북구', 440000, 4, 10, 6, 5, 260, 145),('송파구', 667000, 5, 14, 9, 7, 390, 215),
  ('양천구', 454000, 4, 10, 6, 5, 270, 150),('영등포구', 399000, 4, 10, 6, 5, 235, 140),
  ('용산구', 229000, 2, 6, 4, 3, 135, 75),('은평구', 480000, 4, 11, 7, 5, 280, 160),
  ('종로구', 152000, 2, 5, 3, 2, 90, 50),('중구', 133000, 2, 5, 3, 2, 80, 45),
  ('중랑구', 393000, 3, 10, 6, 4, 230, 135)
) AS t(pop, gu, stations, subs, trucks, ambulances, hydrants, fighters))
CROSS JOIN (SELECT 18500 AS buildings) b;

-- ─────────────────────────────────────────────
-- 검증
-- ─────────────────────────────────────────────
SELECT '✅ 모든 테이블 업데이트 완료' AS status;

SELECT 'FIRE_STATS' AS table_name, COUNT(DISTINCT DISTRICT_NAME) AS gu_count, COUNT(*) AS row_count FROM FIRE_STATS WHERE YEAR = 2024
UNION ALL
SELECT 'CRIME_STATS', COUNT(DISTINCT DISTRICT_NAME), COUNT(*) FROM CRIME_STATS WHERE YEAR = 2024
UNION ALL
SELECT 'BUILDING_AGE', COUNT(DISTINCT DISTRICT_NAME), COUNT(*) FROM BUILDING_AGE WHERE YEAR = 2024
UNION ALL
SELECT 'WEATHER_RISK', COUNT(DISTINCT DISTRICT_NAME), COUNT(*) FROM WEATHER_RISK WHERE YEAR_MONTH = '202412'
UNION ALL
SELECT 'CCTV_INSTALLATION', COUNT(DISTINCT DISTRICT_NAME), COUNT(*) FROM CCTV_INSTALLATION WHERE YEAR = 2024
UNION ALL
SELECT 'FIRE_FACILITY', COUNT(DISTINCT DISTRICT_NAME), COUNT(*) FROM FIRE_FACILITY WHERE YEAR = 2024
ORDER BY table_name;
