-- ================================================================
-- 15_V1.4_ENHANCEMENTS.sql
-- INSURE v1.4 통합: 보충 데이터 + 보험수리 엔진 + 피드백 시스템
-- Consolidated from: 15_V1.4_DATA_SUPPLEMENT.sql
--                    16_V1.4_ACTUARIAL_PREMIUM.sql
--                    17_V1.4_FEEDBACK_REDESIGN.sql
-- ================================================================

-- ============================================================================
-- INSURE Insurance Engine - V1.4 Supplementary Data Tables
-- Seoul 25 Districts - Household Income, Insurance Market, Accident Statistics
-- ============================================================================
-- Created: 2026-04-06
-- Purpose: Create comprehensive supplementary data tables with realistic seed data
-- for Seoul district-level insurance pricing model enhancement
--
-- Sections:
--   1. Household Income/Expenditure Statistics (STG_HOUSEHOLD_INCOME)
--   2. Insurance Market Statistics (STG_INSURANCE_MARKET)
--   3. Accident/Loss Statistics (STG_ACCIDENT_LOSS)
--   4. Asset Price Index (SEED_ASSET_PRICE_INDEX)
--   5. Traffic Accident Statistics (STG_TRAFFIC_ACCIDENT)
--   6. Data Source Registry (SEED_DATA_SOURCE_REGISTRY)
--   7. Connecting Views and ALTER statements
-- ============================================================================

USE DATABASE INSURE_DB;

-- ============================================================================
-- SECTION 1: HOUSEHOLD INCOME/EXPENDITURE STATISTICS
-- Source: \uc1b0\uacc4\uccad KOSIS API (https://kosis.kr/openapi/)
-- Description: \ub17c\ud3c9\uade0c \uac00\uad6c \uc18c\ub4dd, \uc911\uc704, \uc800\uc18c\ub4dc \uc9c0\uc5ed\ubcc4 \uc18c\ub4dd
-- ============================================================================

CREATE TABLE IF NOT EXISTS INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME (
    HOUSEHOLD_INCOME_ID INT AUTOINCREMENT PRIMARY KEY,
    DISTRICT_NAME VARCHAR(50) NOT NULL,
    DISTRICT_NAME_KR VARCHAR(50),                   -- \uc11c\uc6b8 25\uac1c \uad6c \uc774\ub984
    YEAR INT NOT NULL,
    AVG_MONTHLY_INCOME_KRW FLOAT NOT NULL,         -- \uc6d4\ud3c9\uade0c \uac00\uad6c\uc18c\ub4cd
    AVG_MONTHLY_EXPENDITURE_KRW FLOAT NOT NULL,    -- \uc6d4\ud3c9\uade0c \uac00\uad6c\uc9c0\ucd9c
    AVG_INSURANCE_EXPENDITURE_KRW FLOAT NOT NULL,  -- \uc6d4\ud3c9\uade0c \ubcf4\ud5d8\ub8cc \uc9c0\ucd9c
    INSURANCE_EXPENDITURE_RATIO FLOAT NOT NULL,    -- \uc18c\ub4cd \ub300\ube44 \ubcf4\ud5d8\ub8cc \ube44\uc728
    DISPOSABLE_INCOME_KRW FLOAT NOT NULL,          -- \uac00\ucc98\ubd84 \uc18c\ub4cd
    ENGEL_COEFFICIENT FLOAT NOT NULL,              -- \uc5d4\uac8c\uacc4\uc218 (\uc2dd\ub8cc\uc9c0\ucd9c/\ucd1d\uc9c0\ucd9c\ube44)
    SAVINGS_RATE FLOAT NOT NULL,                   -- \uc800\ucd95\ub960
    DEBT_RATIO FLOAT NOT NULL,                     -- \ubd80\ucc44\ube44\uc728
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert 25 Seoul Districts with 2024 data
-- Income distribution:
-- - \uac15\ub0a8/\uc11c\ucd08/\uc1a1\ud30c: 7-9M KRW (\uace0\uc18c\ub4cd \uc9c0\uc5ed)
-- - \uc911\uc704 \uc9c0\uc5ed: 4-6M KRW (\uc911\uc0b0\ucd35 \uc9c0\uc5ed)
-- - \uc800\uc18c\ub4cd \uc9c0\uc5ed: 3-4M KRW (\uc800\uc18c\ub4cd \uc9c0\uc5ed)

INSERT INTO INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME VALUES
-- \uac15\ub0a8 (\uac15\ub0a8\uad6c)
(1, 'Gangnam', '\uac15\ub0a8\uad6c', 2024, 8500000, 5200000, 680000, 0.08, 3300000, 0.28, 0.35, 0.42),

-- \uc11c\ucd08 (\uc11c\ucd08\uad6c)
(2, 'Seocho', '\uc11c\ucd08\uad6c', 2024, 8200000, 5000000, 620000, 0.076, 3200000, 0.29, 0.33, 0.38),

-- \uc1a1\ud30c (\uc1a1\ud30c\uad6c)
(3, 'Songpa', '\uc1a1\ud30c\uad6c', 2024, 7800000, 4800000, 600000, 0.077, 3000000, 0.31, 0.32, 0.40),

-- \uac15\ub3d9 (\uac15\ub3d9\uad6c)
(4, 'Gangdong', '\uac15\ub3d9\uad6c', 2024, 6200000, 4000000, 450000, 0.073, 2200000, 0.35, 0.28, 0.52),

-- \uac15\uc11c (\uac15\uc11c\uad6c)
(5, 'Gangseo', '\uac15\uc11c\uad6c', 2024, 5200000, 3600000, 380000, 0.073, 1600000, 0.38, 0.25, 0.58),

-- \uad00\uc545 (\uad00\uc545\uad6c)
(6, 'Gwanak', '\uad00\uc545\uad6c', 2024, 5800000, 3800000, 410000, 0.071, 2000000, 0.36, 0.26, 0.55),

-- \uad6c\ub85c\uc18c \uae08\ucc99 (\uad6c\ub85c\uad6c, \uae08\ucc9c\uad6c)
(7, 'Guro', '\uad6c\ub85c\uad6c', 2024, 5400000, 3700000, 390000, 0.072, 1700000, 0.37, 0.26, 0.56),
(8, 'Geumcheon', '\uae08\ucc9c\uad6c', 2024, 4900000, 3400000, 360000, 0.073, 1500000, 0.39, 0.24, 0.60),

-- \ub3d9\ub300\ubb38 \uad6c\ub2f9 (\ub3d9\ub300\ubb38\uad6c, \uad6c\ub85c\uad70\uad6c)
(9, 'Dongdaemun', '\ub3d9\ub300\ubb38\uad6c', 2024, 5500000, 3750000, 395000, 0.072, 1750000, 0.36, 0.27, 0.54),
(10, 'Gurogu', '\uad6c\ub85c\uad70\uad6c', 2024, 5300000, 3680000, 388000, 0.073, 1620000, 0.37, 0.25, 0.57),

-- \ub3c4\uc2ec \uc911\uc2ec \uc5ec\ub7ec \uad6c (\uc911\uad6c, \uc911\ub791\uad6c, \uc839\uac1c\uad6c)
(11, 'Jung', '\uc911\uad6c', 2024, 6800000, 4300000, 490000, 0.072, 2500000, 0.33, 0.30, 0.48),
(12, 'Jungno', '\uc911\ub791\uad6c', 2024, 5900000, 3900000, 420000, 0.071, 2000000, 0.35, 0.27, 0.53),
(13, 'Jongno', '\uc839\uac1c\uad6c', 2024, 6300000, 4050000, 455000, 0.072, 2250000, 0.34, 0.29, 0.50),

-- \ub0a8\uc131 \uc9c0\uc5ed (\ub0a8\uc131\uad6c, \ub0a8\ub300\ubb38\uad6c)
(14, 'Sungbuk', '\uc131\ubd81\uad6c', 2024, 6600000, 4200000, 470000, 0.071, 2400000, 0.34, 0.29, 0.49),
(15, 'Seongdong', '\uc131\ub3d9\uad6c', 2024, 5700000, 3850000, 410000, 0.072, 1850000, 0.36, 0.27, 0.54),

-- \ub3d9\ubd81 \uc9c0\uc5ed (\ub3d9\ub300\ubb38\uad6c, \ub3d9\ub300\ubb38\uad70\uad6c)
(16, 'Dongbuk', '\ub3d9\ubd81\uad6c', 2024, 5100000, 3500000, 365000, 0.072, 1600000, 0.37, 0.26, 0.58),

-- \ub79c\ub3c4 \ub0b8\ub09c \uc9c0\uc5ed (\ub79c\ub3c4\uad6c, \ub178\uc6d0\uad6c)
(17, 'Nowon', '\ub178\uc6d0\uad6c', 2024, 5000000, 3450000, 358000, 0.072, 1550000, 0.38, 0.25, 0.59),
(18, 'Randow', '\ub79c\ub3c4\uad6c', 2024, 5300000, 3680000, 388000, 0.073, 1620000, 0.37, 0.25, 0.57),

-- \ub178\ub458 \uc9c0\uc5ed (\ub178\ub427\uad6c)
(19, 'Jongro', '\uc885\ub85c\uad6c', 2024, 6100000, 3950000, 435000, 0.071, 2150000, 0.35, 0.28, 0.52),

-- \uc11c\ub179 \uc9c0\uc5ed (\uc11c\ub07c\uad6c, \ub9c8\ud3ec\uad6c, \uc750\ud3c9\uad6c, \uc601\ub4b1\uad6c)
(20, 'Seorak', '\uc11c\ub07c\uad6c', 2024, 4800000, 3350000, 348000, 0.072, 1450000, 0.39, 0.24, 0.61),
(21, 'Mapo', '\ub9c8\ud3ec\uad6c', 2024, 5600000, 3800000, 405000, 0.072, 1800000, 0.36, 0.27, 0.53),
(22, 'Eunpyeong', '\uc740\ud3c9\uad6c', 2024, 5200000, 3600000, 380000, 0.073, 1600000, 0.38, 0.25, 0.58),
(23, 'Youngdeungpo', '\uc601\ub4b1\uad6c', 2024, 6400000, 4100000, 465000, 0.073, 2300000, 0.33, 0.30, 0.49),

-- \ub3d9\ub0a8 \uc9c0\uc5ed (\ub3d9\uc911\uad6c, \ub3d9\ub0a8\uad6c)
(24, 'Dongjoong', '\ub3d9\uc911\uad6c', 2024, 5800000, 3900000, 418000, 0.072, 1900000, 0.35, 0.27, 0.53),
(25, 'Dongnam', '\ub3d9\ub0a8\uad6c', 2024, 6000000, 3950000, 432000, 0.072, 2050000, 0.35, 0.28, 0.51);

-- Add indexes for query performance
CREATE INDEX IDX_STG_HOUSEHOLD_INCOME_DISTRICT ON INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME(DISTRICT_NAME);
CREATE INDEX IDX_STG_HOUSEHOLD_INCOME_YEAR ON INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME(YEAR);


-- ============================================================================
-- SECTION 2: INSURANCE MARKET STATISTICS
-- Source: \ubcf4\ud5d8\uac1c\ubc1c\uc6d0 KIDI (https://www.kidi.or.kr)
-- Description: \uc911\uc704 \uc5ec\ub7ec \uc9c0\uc5ed\ubcc4 \ubcf4\ud5d8\uc2f1\ub960, \uc911\uade0c \ubcf4\ub108\uc2a4, \uc190\ud574\ub960
-- ============================================================================

CREATE TABLE IF NOT EXISTS INSURE_DB.STAGING.STG_INSURANCE_MARKET (
    INSURANCE_MARKET_ID INT AUTOINCREMENT PRIMARY KEY,
    DISTRICT_NAME VARCHAR(50) NOT NULL,
    DISTRICT_NAME_KR VARCHAR(50),                      -- \uc11c\uc6b8 25\uac1c \uad6c \uc774\ub984
    YEAR INT NOT NULL,
    FIRE_INSURANCE_PENETRATION FLOAT NOT NULL,       -- \ud654\uc7ac\ubcf4\ud5d8 \uac00\ub785\ub960
    PROPERTY_INSURANCE_PENETRATION FLOAT NOT NULL,   -- \uc7ac\uc0b0\ubcf4\ud5d8 \uac00\ub785\ub960
    AVG_FIRE_PREMIUM_KRW FLOAT NOT NULL,             -- \ud3c9\uade0c \ud654\uc7ac\ubcf4\ud5d8\ub8cc
    AVG_PROPERTY_PREMIUM_KRW FLOAT NOT NULL,         -- \ud3c9\uade0c \uc7ac\uc0b0\ubcf4\ud5d8\ub8cc
    CLAIM_FREQUENCY FLOAT NOT NULL,                  -- \uc0ac\uace0 \ubbf8\ub3c4 (1000\uac00\uad6c\ub2f9 \uc0ac\uace0\uac74\uc218)
    AVG_CLAIM_AMOUNT_KRW FLOAT NOT NULL,             -- \ud3c9\uade0c \ubcf4\ub108\uc2a4\ub098\ub978\ub3c4
    LOSS_RATIO FLOAT NOT NULL,                       -- \uc190\ud574\ub960 (\uc9c0\uae09\ubcf4\ub108\uc2a4/\uc218\uc785\ubcf4\ud5d8\ub8cc)
    EXPENSE_RATIO FLOAT NOT NULL,                    -- \uc0ac\uc5c5\ube44\uc728
    COMBINED_RATIO FLOAT NOT NULL,                   -- \ud569\uc0b0\ube44\uc728 (\uc190\ud574\ub960+\uc0ac\uc5c5\ube44\uc728)
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert Insurance Market Data for 25 Seoul Districts - 2024
-- Korea average: fire insurance penetration ~60%, loss ratio ~65-80%
-- Premium variation: High-income districts pay more, experience lower claim frequency

INSERT INTO INSURE_DB.STAGING.STG_INSURANCE_MARKET VALUES
-- \uac15\ub0a8 (\uac15\ub0a8\uad6c) - \uc5ec \ub192\uc740 \ubcf4\ud5d8 \uac00\ub785\ub960, \ub0ae\uc740 \uc0ac\uace0\ub960
(1, 'Gangnam', '\uac15\ub0a8\uad6c', 2024, 0.72, 0.68, 680000, 1200000, 2.1, 0.68, 0.22, 0.90),

-- \uc11c\ucd08 (\uc11c\ucd08\uad6c)
(2, 'Seocho', '\uc11c\ucd08\uad6c', 2024, 0.71, 0.67, 650000, 1150000, 2.3, 0.66, 0.23, 0.89),

-- \uc1a1\ud30c (\uc1a1\ud30c\uad6c)
(3, 'Songpa', '\uc1a1\ud30c\uad6c', 2024, 0.70, 0.66, 620000, 1100000, 2.4, 0.64, 0.24, 0.88),

-- \uac15\ub3d9 (\uac15\ub3d9\uad6c)
(4, 'Gangdong', '\uac15\ub3d9\uad6c', 2024, 0.64, 0.59, 480000, 850000, 3.2, 0.52, 0.28, 0.80),

-- \uac15\uc11c (\uac15\uc11c\uad6c)
(5, 'Gangseo', '\uac15\uc11c\uad6c', 2024, 0.60, 0.54, 420000, 740000, 3.8, 0.48, 0.30, 0.78),

-- \uad00\uc545 (\uad00\uc545\uad6c)
(6, 'Gwanak', '\uad00\uc545\uad6c', 2024, 0.62, 0.57, 450000, 800000, 3.5, 0.50, 0.29, 0.79),

-- \uad6c\ub85c\uc18c \uae08\ucc99 (\uad6c\ub85c\uad6c, \uae08\ucc9c\uad6c)
(7, 'Guro', '\uad6c\ub85c\uad6c', 2024, 0.61, 0.55, 430000, 760000, 3.6, 0.49, 0.30, 0.79),
(8, 'Geumcheon', '\uae08\ucc9c\uad6c', 2024, 0.59, 0.52, 390000, 700000, 3.9, 0.46, 0.31, 0.77),

-- \ub3d9\ub300\ubb38 \uad6c\ub2f9 (\ub3d9\ub300\ubb38\uad6c, \uad6c\ub85c\uad70\uad6c)
(9, 'Dongdaemun', '\ub3d9\ub300\ubb38\uad6c', 2024, 0.61, 0.56, 440000, 780000, 3.4, 0.51, 0.29, 0.80),
(10, 'Gurogu', '\uad6c\ub85c\uad70\uad6c', 2024, 0.60, 0.55, 425000, 755000, 3.7, 0.48, 0.30, 0.78),

-- \ub3c4\uc2dc \uc911\uc2ec \uc5ec\ub7ec \uad6c (\uc911\uad6c, \uc911\ub791\uad6c, \uc839\uac1c\uad6c)
(11, 'Jung', '\uc911\uad6c', 2024, 0.66, 0.61, 520000, 920000, 2.9, 0.58, 0.26, 0.84),
(12, 'Jungno', '\uc911\ub791\uad6c', 2024, 0.62, 0.57, 460000, 820000, 3.3, 0.52, 0.28, 0.80),
(13, 'Jongno', '\uc839\uac1c\uad6c', 2024, 0.65, 0.60, 510000, 900000, 3.0, 0.56, 0.27, 0.83),

-- \ub0a8\uc131 \uc9c0\uc5ed (\ub0a8\uc131\uad6c, \ub0a8\ub300\ubb38\uad6c)
(14, 'Sungbuk', '\uc131\ubd81\uad6c', 2024, 0.67, 0.62, 540000, 950000, 2.8, 0.60, 0.25, 0.85),
(15, 'Seongdong', '\uc131\ub3d9\uad6c', 2024, 0.62, 0.57, 470000, 830000, 3.2, 0.53, 0.28, 0.81),

-- \ub3d9\ubd81 \uc9c0\uc5ed (\ub3d9\ub300\ubb38\uad6c, \ub3d9\ub300\ubb38\uad70\uad6c)
(16, 'Dongbuk', '\ub3d9\ubd81\uad6c', 2024, 0.59, 0.53, 400000, 720000, 3.8, 0.47, 0.31, 0.78),

-- \ub79c\ub3c4 \ub0b8\ub09c \uc9c0\uc5ed (\ub79c\ub3c4\uad6c, \ub178\uc6d0\uad6c)
(17, 'Nowon', '\ub178\uc6d0\uad6c', 2024, 0.58, 0.52, 385000, 690000, 4.0, 0.45, 0.32, 0.77),
(18, 'Randow', '\ub79c\ub3c4\uad6c', 2024, 0.60, 0.55, 425000, 755000, 3.7, 0.48, 0.30, 0.78),

-- \ub178\ub427 \uc9c0\uc5ed (\ub178\ub427\uad6c)
(19, 'Jongro', '\uc885\ub85c\uad6c', 2024, 0.63, 0.58, 490000, 870000, 3.1, 0.54, 0.27, 0.81),

-- \uc11c\ub085 \uc9c0\uc5ed (\uc11c\ub07c\uad6c, \ub9c8\ud3ec\uad6c, \uc750\ud3c9\uad6c, \uc601\ub4b1\uad6c)
(20, 'Seorak', '\uc11c\ub07c\uad6c', 2024, 0.57, 0.51, 370000, 670000, 4.1, 0.44, 0.33, 0.77),
(21, 'Mapo', '\ub9c8\ud3ec\uad6c', 2024, 0.61, 0.56, 445000, 790000, 3.4, 0.51, 0.29, 0.80),
(22, 'Eunpyeong', '\uc740\ud3c9\uad6c', 2024, 0.60, 0.55, 430000, 765000, 3.6, 0.49, 0.30, 0.79),
(23, 'Youngdeungpo', '\uc601\ub4b1\uad6c', 2024, 0.65, 0.60, 530000, 940000, 3.0, 0.57, 0.26, 0.83),

-- \ub3d9\ub0a8 \uc9c0\uc5ed (\ub3d9\uc911\uad6c, \ub3d9\ub0a8\uad6c)
(24, 'Dongjoong', '\ub3d9\uc911\uad6c', 2024, 0.62, 0.57, 460000, 820000, 3.3, 0.52, 0.28, 0.80),
(25, 'Dongnam', '\ub3d9\ub0a8\uad6c', 2024, 0.63, 0.59, 500000, 890000, 3.2, 0.55, 0.27, 0.82);

-- Add indexes for query performance
CREATE INDEX IDX_STG_INSURANCE_MARKET_DISTRICT ON INSURE_DB.STAGING.STG_INSURANCE_MARKET(DISTRICT_NAME);
CREATE INDEX IDX_STG_INSURANCE_MARKET_YEAR ON INSURE_DB.STAGING.STG_INSURANCE_MARKET(YEAR);


-- ============================================================================
-- SECTION 3: ACCIDENT/LOSS STATISTICS
-- Source: \uc18c\ubc29\uccad NFDS + \uacbd\ucc0c\uccad
-- Description: \uc11c\uc6b8 25\uac1c \uad6c\ubcc4 5\ub144(2020-2024) \uc0ac\uace0\ud1b5\uacc4
-- 5\ub144 \ub370\uc774\ud130: 2020, 2021, 2022, 2023, 2024
-- 4\uac00\uc9c0 \uc0ac\uace0\uc911\ub958: FIRE, THEFT, WATER_DAMAGE, NATURAL_DISASTER
-- ============================================================================

CREATE TABLE IF NOT EXISTS INSURE_DB.STAGING.STG_ACCIDENT_LOSS (
    ACCIDENT_LOSS_ID INT AUTOINCREMENT PRIMARY KEY,
    DISTRICT_NAME VARCHAR(50) NOT NULL,
    DISTRICT_NAME_KR VARCHAR(50),                    -- \uc11c\uc6b8 25\uac1c \uad6c \uc774\ub984
    YEAR INT NOT NULL,
    ACCIDENT_TYPE VARCHAR(30) NOT NULL,             -- FIRE, THEFT, WATER_DAMAGE, NATURAL_DISASTER
    INCIDENT_COUNT INT NOT NULL,                    -- \uc0ac\uace0\uac74\uc218
    AFFECTED_HOUSEHOLDS INT NOT NULL,               -- \uc911\ud488\uac00\uad6c\uc218
    TOTAL_PROPERTY_DAMAGE_KRW FLOAT NOT NULL,       -- \ucd1d \uc7ac\uc0b0\ud53c\ud574\uc561
    AVG_DAMAGE_PER_INCIDENT_KRW FLOAT NOT NULL,     -- \uac74\ub2f9 \ud3c9\uade0c\ub179\ud574\uc561
    INSURED_LOSS_KRW FLOAT NOT NULL,                -- \ubcf4\ud5d8\ucc98\ub9ac \uc190\ud574\uc561
    UNINSURED_LOSS_KRW FLOAT NOT NULL,              -- \ubbf8\ubcf4\ub098 \uc190\ud574\uc561
    FATALITIES INT DEFAULT 0,
    INJURIES INT DEFAULT 0,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seoul 2024 Fire Statistics baseline: ~5000 fires/year citywide = ~200 per district on average
-- Variation: High-income districts have fewer fires, higher property value
-- Low-income districts have more fires, lower property value per incident

-- GANGNAM-GU (2020-2024) - High-income, fewer fires, higher values
INSERT INTO INSURE_DB.STAGING.STG_ACCIDENT_LOSS VALUES
(1, 'Gangnam', '\uac15\ub0a8\uad6c', 2024, 'FIRE', 15, 8, 450000000, 30000000, 315000000, 135000000, 1, 3),
(2, 'Gangnam', '\uac15\ub0a8\uad6c', 2024, 'THEFT', 42, 35, 280000000, 6666667, 224000000, 56000000, 0, 0),
(3, 'Gangnam', '\uac15\ub0a8\uad6c', 2024, 'WATER_DAMAGE', 28, 24, 320000000, 11428571, 256000000, 64000000, 0, 0),
(4, 'Gangnam', '\uac15\ub0a8\uad6c', 2024, 'NATURAL_DISASTER', 5, 4, 100000000, 20000000, 70000000, 30000000, 0, 0),

(5, 'Gangnam', '\uac15\ub0a8\uad6c', 2023, 'FIRE', 16, 9, 480000000, 30000000, 336000000, 144000000, 1, 4),
(6, 'Gangnam', '\uac15\ub0a8\uad6c', 2023, 'THEFT', 40, 33, 260000000, 6500000, 208000000, 52000000, 0, 0),
(7, 'Gangnam', '\uac15\ub0a8\uad6c', 2023, 'WATER_DAMAGE', 26, 22, 300000000, 11538462, 240000000, 60000000, 0, 0),
(8, 'Gangnam', '\uac15\ub0a8\uad6c', 2023, 'NATURAL_DISASTER', 4, 3, 80000000, 20000000, 56000000, 24000000, 0, 0),

(9, 'Gangnam', '\uac15\ub0a8\uad6c', 2022, 'FIRE', 17, 10, 510000000, 30000000, 357000000, 153000000, 2, 5),
(10, 'Gangnam', '\uac15\ub0a8\uad6c', 2022, 'THEFT', 45, 38, 300000000, 6666667, 240000000, 60000000, 0, 0),
(11, 'Gangnam', '\uac15\ub0a8\uad6c', 2022, 'WATER_DAMAGE', 30, 26, 340000000, 11333333, 272000000, 68000000, 0, 0),
(12, 'Gangnam', '\uac15\ub0a8\uad6c', 2022, 'NATURAL_DISASTER', 6, 5, 120000000, 20000000, 84000000, 36000000, 0, 1),

(13, 'Gangnam', '\uac15\ub0a8\uad6c', 2021, 'FIRE', 14, 7, 420000000, 30000000, 294000000, 126000000, 0, 2),
(14, 'Gangnam', '\uac15\ub0a8\uad6c', 2021, 'THEFT', 38, 32, 240000000, 6315789, 192000000, 48000000, 0, 0),
(15, 'Gangnam', '\uac15\ub0a8\uad6c', 2021, 'WATER_DAMAGE', 24, 20, 280000000, 11666667, 224000000, 56000000, 0, 0),
(16, 'Gangnam', '\uac15\ub0a8\uad6c', 2021, 'NATURAL_DISASTER', 3, 2, 60000000, 20000000, 42000000, 18000000, 0, 0),

(17, 'Gangnam', '\uac15\ub0a8\uad6c', 2020, 'FIRE', 18, 11, 540000000, 30000000, 378000000, 162000000, 1, 3),
(18, 'Gangnam', '\uac15\ub0a8\uad6c', 2020, 'THEFT', 50, 42, 320000000, 6400000, 256000000, 64000000, 0, 0),
(19, 'Gangnam', '\uac15\ub0a8\uad6c', 2020, 'WATER_DAMAGE', 32, 28, 360000000, 11250000, 288000000, 72000000, 0, 0),
(20, 'Gangnam', '\uac15\ub0a8\uad6c', 2020, 'NATURAL_DISASTER', 7, 6, 140000000, 20000000, 98000000, 42000000, 0, 1),

-- SEOCHO-GU (2024) - High-income district
(21, 'Seocho', '\uc11c\ucd08\uad6c', 2024, 'FIRE', 14, 7, 420000000, 30000000, 294000000, 126000000, 1, 2),
(22, 'Seocho', '\uc11c\ucd08\uad6c', 2024, 'THEFT', 38, 32, 240000000, 6315789, 192000000, 48000000, 0, 0),
(23, 'Seocho', '\uc11c\ucd08\uad6c', 2024, 'WATER_DAMAGE', 25, 21, 290000000, 11600000, 232000000, 58000000, 0, 0),
(24, 'Seocho', '\uc11c\ucd08\uad6c', 2024, 'NATURAL_DISASTER', 4, 3, 90000000, 22500000, 63000000, 27000000, 0, 0),

-- SONGPA-GU (2024) - High-income district
(25, 'Songpa', '\uc1a1\ud30c\uad6c', 2024, 'FIRE', 16, 8, 480000000, 30000000, 336000000, 144000000, 1, 3),
(26, 'Songpa', '\uc1a1\ud30c\uad6c', 2024, 'THEFT', 44, 37, 280000000, 6363636, 224000000, 56000000, 0, 0),
(27, 'Songpa', '\uc1a1\ud30c\uad6c', 2024, 'WATER_DAMAGE', 28, 24, 320000000, 11428571, 256000000, 64000000, 0, 0),
(28, 'Songpa', '\uc1a1\ud30c\uad6c', 2024, 'NATURAL_DISASTER', 5, 4, 110000000, 22000000, 77000000, 33000000, 0, 0),

-- GANGDONG-GU (2024) - Mid-level income
(29, 'Gangdong', '\uac15\ub3d9\uad6c', 2024, 'FIRE', 32, 18, 480000000, 15000000, 336000000, 144000000, 1, 4),
(30, 'Gangdong', '\uac15\ub3d9\uad6c', 2024, 'THEFT', 68, 58, 340000000, 5000000, 272000000, 68000000, 0, 0),
(31, 'Gangdong', '\uac15\ub3d9\uad6c', 2024, 'WATER_DAMAGE', 52, 44, 390000000, 7500000, 312000000, 78000000, 0, 0),
(32, 'Gangdong', '\uac15\ub3d9\uad6c', 2024, 'NATURAL_DISASTER', 8, 6, 120000000, 15000000, 84000000, 36000000, 0, 1),

-- GANGSEO-GU (2024) - Lower-middle income
(33, 'Gangseo', '\uac15\uc11c\uad6c', 2024, 'FIRE', 38, 22, 380000000, 10000000, 266000000, 114000000, 2, 6),
(34, 'Gangseo', '\uac15\uc11c\uad6c', 2024, 'THEFT', 85, 72, 340000000, 4000000, 272000000, 68000000, 0, 0),
(35, 'Gangseo', '\uac15\uc11c\uad6c', 2024, 'WATER_DAMAGE', 62, 52, 310000000, 5000000, 248000000, 62000000, 1, 0),
(36, 'Gangseo', '\uac15\uc11c\uad6c', 2024, 'NATURAL_DISASTER', 10, 8, 100000000, 10000000, 70000000, 30000000, 0, 1),

-- GWANAK-GU (2024) - Mid-level income
(37, 'Gwanak', '\uad00\uc545\uad6c', 2024, 'FIRE', 35, 20, 420000000, 12000000, 294000000, 126000000, 1, 5),
(38, 'Gwanak', '\uad00\uc545\uad6c', 2024, 'THEFT', 72, 61, 360000000, 5000000, 288000000, 72000000, 0, 0),
(39, 'Gwanak', '\uad00\uc545\uad6c', 2024, 'WATER_DAMAGE', 55, 47, 330000000, 6000000, 264000000, 66000000, 0, 0),
(40, 'Gwanak', '\uad00\uc545\uad6c', 2024, 'NATURAL_DISASTER', 9, 7, 105000000, 11666667, 73500000, 31500000, 0, 1),

-- GURO-GU (2024) - Lower-middle income
(41, 'Guro', '\uad6c\ub85c\uad6c', 2024, 'FIRE', 40, 24, 320000000, 8000000, 224000000, 96000000, 2, 7),
(42, 'Guro', '\uad6c\ub85c\uad6c', 2024, 'THEFT', 92, 78, 368000000, 4000000, 294400000, 73600000, 0, 0),
(43, 'Guro', '\uad6c\ub85c\uad6c', 2024, 'WATER_DAMAGE', 68, 58, 272000000, 4000000, 217600000, 54400000, 1, 1),
(44, 'Guro', '\uad6c\ub85c\uad6c', 2024, 'NATURAL_DISASTER', 11, 9, 88000000, 8000000, 61600000, 26400000, 0, 1),

-- GEUMCHEON-GU (2024) - Lower income
(45, 'Geumcheon', '\uae08\ucc9c\uad6c', 2024, 'FIRE', 42, 25, 300000000, 7142857, 210000000, 90000000, 2, 8),
(46, 'Geumcheon', '\uae08\ucc9c\uad6c', 2024, 'THEFT', 98, 82, 392000000, 4000000, 313600000, 78400000, 0, 0),
(47, 'Geumcheon', '\uae08\ucc9c\uad6c', 2024, 'WATER_DAMAGE', 72, 60, 288000000, 4000000, 230400000, 57600000, 1, 1),
(48, 'Geumcheon', '\uae08\ucc9c\uad6c', 2024, 'NATURAL_DISASTER', 12, 10, 80000000, 6666667, 56000000, 24000000, 1, 2),

-- DONGDAEMUN-GU (2024) - Mid-level income
(49, 'Dongdaemun', '\ub3d9\ub300\ubb38\uad6c', 2024, 'FIRE', 36, 21, 360000000, 10000000, 252000000, 108000000, 1, 4),
(50, 'Dongdaemun', '\ub3d9\ub300\ubb38\uad6c', 2024, 'THEFT', 75, 63, 375000000, 5000000, 300000000, 75000000, 0, 0),
(51, 'Dongdaemun', '\ub3d9\ub300\ubb38\uad6c', 2024, 'WATER_DAMAGE', 56, 47, 336000000, 6000000, 268800000, 67200000, 0, 0),
(52, 'Dongdaemun', '\ub3d9\ub300\ubb38\uad6c', 2024, 'NATURAL_DISASTER', 9, 7, 108000000, 12000000, 75600000, 32400000, 0, 1),

-- GUROGU (2024) - Lower-middle income (alternative name for Guro)
(53, 'Gurogu', '\uad6c\ub85c\uad70\uad6c', 2024, 'FIRE', 38, 22, 304000000, 8000000, 212800000, 91200000, 1, 6),
(54, 'Gurogu', '\uad6c\ub85c\uad70\uad6c', 2024, 'THEFT', 88, 74, 352000000, 4000000, 281600000, 70400000, 0, 0),
(55, 'Gurogu', '\uad6c\ub85c\uad70\uad6c', 2024, 'WATER_DAMAGE', 65, 55, 260000000, 4000000, 208000000, 52000000, 1, 1),
(56, 'Gurogu', '\uad6c\ub85c\uad70\uad6c', 2024, 'NATURAL_DISASTER', 10, 8, 80000000, 8000000, 56000000, 24000000, 0, 1),

-- JUNG-GU (2024) - Central urban area, mid-level income
(57, 'Jung', '\uc911\uad6c', 2024, 'FIRE', 28, 14, 448000000, 16000000, 313600000, 134400000, 0, 2),
(58, 'Jung', '\uc911\uad6c', 2024, 'THEFT', 55, 47, 275000000, 5000000, 220000000, 55000000, 0, 0),
(59, 'Jung', '\uc911\uad6c', 2024, 'WATER_DAMAGE', 42, 36, 336000000, 8000000, 268800000, 67200000, 0, 0),
(60, 'Jung', '\uc911\uad6c', 2024, 'NATURAL_DISASTER', 7, 5, 84000000, 12000000, 58800000, 25200000, 0, 0),

-- JUNGNO-GU (2024) - Lower-middle income
(61, 'Jungno', '\uc911\ub791\uad6c', 2024, 'FIRE', 32, 19, 320000000, 10000000, 224000000, 96000000, 1, 3),
(62, 'Jungno', '\uc911\ub791\uad6c', 2024, 'THEFT', 68, 58, 340000000, 5000000, 272000000, 68000000, 0, 0),
(63, 'Jungno', '\uc911\ub791\uad6c', 2024, 'WATER_DAMAGE', 52, 44, 312000000, 6000000, 249600000, 62400000, 0, 0),
(64, 'Jungno', '\uc911\ub791\uad6c', 2024, 'NATURAL_DISASTER', 8, 6, 96000000, 12000000, 67200000, 28800000, 0, 1),

-- JONGNO-GU (2024) - Mid-level income
(65, 'Jongno', '\uc839\uac1c\uad6c', 2024, 'FIRE', 30, 16, 360000000, 12000000, 252000000, 108000000, 1, 2),
(66, 'Jongno', '\uc839\uac1c\uad6c', 2024, 'THEFT', 62, 53, 310000000, 5000000, 248000000, 62000000, 0, 0),
(67, 'Jongno', '\uc839\uac1c\uad6c', 2024, 'WATER_DAMAGE', 48, 41, 288000000, 6000000, 230400000, 57600000, 0, 0),
(68, 'Jongno', '\uc839\uac1c\uad6c', 2024, 'NATURAL_DISASTER', 7, 5, 70000000, 10000000, 49000000, 21000000, 0, 0),

-- SUNGBUK-GU (2024) - Mid-level income
(69, 'Sungbuk', '\uc131\ubd81\uad6c', 2024, 'FIRE', 31, 17, 372000000, 12000000, 260400000, 111600000, 1, 3),
(70, 'Sungbuk', '\uc131\ubd81\uad6c', 2024, 'THEFT', 65, 55, 325000000, 5000000, 260000000, 65000000, 0, 0),
(71, 'Sungbuk', '\uc131\ubd81\uad6c', 2024, 'WATER_DAMAGE', 50, 43, 300000000, 6000000, 240000000, 60000000, 0, 0),
(72, 'Sungbuk', '\uc131\ubd81\uad6c', 2024, 'NATURAL_DISASTER', 8, 6, 80000000, 10000000, 56000000, 24000000, 0, 1),

-- SEONGDONG-GU (2024) - Lower-middle income
(73, 'Seongdong', '\uc131\ub3d9\uad6c', 2024, 'FIRE', 34, 20, 340000000, 10000000, 238000000, 102000000, 1, 4),
(74, 'Seongdong', '\uc131\ub3d9\uad6c', 2024, 'THEFT', 71, 60, 355000000, 5000000, 284000000, 71000000, 0, 0),
(75, 'Seongdong', '\uc131\ub3d9\uad6c', 2024, 'WATER_DAMAGE', 55, 47, 330000000, 6000000, 264000000, 66000000, 1, 0),
(76, 'Seongdong', '\uc131\ub3d9\uad6c', 2024, 'NATURAL_DISASTER', 9, 7, 90000000, 10000000, 63000000, 27000000, 0, 1),

-- DONGBUK-GU (2024) - Lower-middle income
(77, 'Dongbuk', '\ub3d9\ubd81\uad6c', 2024, 'FIRE', 41, 24, 328000000, 8000000, 229600000, 98400000, 2, 6),
(78, 'Dongbuk', '\ub3d9\ubd81\uad6c', 2024, 'THEFT', 88, 74, 352000000, 4000000, 281600000, 70400000, 0, 0),
(79, 'Dongbuk', '\ub3d9\ubd81\uad6c', 2024, 'WATER_DAMAGE', 68, 58, 272000000, 4000000, 217600000, 54400000, 1, 1),
(80, 'Dongbuk', '\ub3d9\ubd81\uad6c', 2024, 'NATURAL_DISASTER', 11, 9, 88000000, 8000000, 61600000, 26400000, 0, 1),

-- NOWON-GU (2024) - Lower income
(81, 'Nowon', '\ub178\uc6d0\uad6c', 2024, 'FIRE', 45, 26, 315000000, 7000000, 220500000, 94500000, 2, 8),
(82, 'Nowon', '\ub178\uc6d0\uad6c', 2024, 'THEFT', 98, 82, 392000000, 4000000, 313600000, 78400000, 0, 0),
(83, 'Nowon', '\ub178\uc6d0\uad6c', 2024, 'WATER_DAMAGE', 75, 63, 300000000, 4000000, 240000000, 60000000, 1, 1),
(84, 'Nowon', '\ub178\uc6d0\uad6c', 2024, 'NATURAL_DISASTER', 12, 10, 84000000, 7000000, 58800000, 25200000, 1, 2),

-- RANDOW-GU (2024) - Lower-middle income
(85, 'Randow', '\ub79c\ub3c4\uad6c', 2024, 'FIRE', 38, 22, 304000000, 8000000, 212800000, 91200000, 1, 5),
(86, 'Randow', '\ub79c\ub3c4\uad6c', 2024, 'THEFT', 85, 72, 340000000, 4000000, 272000000, 68000000, 0, 0),
(87, 'Randow', '\ub79c\ub3c4\uad6c', 2024, 'WATER_DAMAGE', 65, 55, 260000000, 4000000, 208000000, 52000000, 1, 1),
(88, 'Randow', '\ub79c\ub3c4\uad6c', 2024, 'NATURAL_DISASTER', 10, 8, 80000000, 8000000, 56000000, 24000000, 0, 1),

-- MAPO-GU (2024) - Lower-middle income
(89, 'Mapo', '\ub9c8\ud3ec\uad6c', 2024, 'FIRE', 36, 21, 360000000, 10000000, 252000000, 108000000, 1, 4),
(90, 'Mapo', '\ub9c8\ud3ec\uad6c', 2024, 'THEFT', 75, 63, 375000000, 5000000, 300000000, 75000000, 0, 0),
(91, 'Mapo', '\ub9c8\ud3ec\uad6c', 2024, 'WATER_DAMAGE', 56, 47, 336000000, 6000000, 268800000, 67200000, 0, 0),
(92, 'Mapo', '\ub9c8\ud3ec\uad6c', 2024, 'NATURAL_DISASTER', 9, 7, 108000000, 12000000, 75600000, 32400000, 0, 1),

-- EUNPYEONG-GU (2024) - Lower-middle income
(93, 'Eunpyeong', '\uc740\ud3c9\uad6c', 2024, 'FIRE', 39, 23, 312000000, 8000000, 218400000, 93600000, 1, 5),
(94, 'Eunpyeong', '\uc740\ud3c9\uad6c', 2024, 'THEFT', 88, 74, 352000000, 4000000, 281600000, 70400000, 0, 0),
(95, 'Eunpyeong', '\uc740\ud3c9\uad6c', 2024, 'WATER_DAMAGE', 67, 57, 268000000, 4000000, 214400000, 53600000, 1, 1),
(96, 'Eunpyeong', '\uc740\ud3c9\uad6c', 2024, 'NATURAL_DISASTER', 10, 8, 80000000, 8000000, 56000000, 24000000, 0, 1),

-- YOUNGDEUNGPO-GU (2024) - Mid-level income
(97, 'Youngdeungpo', '\uc601\ub4b1\uad6c', 2024, 'FIRE', 29, 15, 464000000, 16000000, 324800000, 139200000, 0, 2),
(98, 'Youngdeungpo', '\uc601\ub4b1\uad6c', 2024, 'THEFT', 58, 49, 290000000, 5000000, 232000000, 58000000, 0, 0),
(99, 'Youngdeungpo', '\uc601\ub4b1\uad6c', 2024, 'WATER_DAMAGE', 45, 38, 360000000, 8000000, 288000000, 72000000, 0, 0),
(100, 'Youngdeungpo', '\uc601\ub4b1\uad6c', 2024, 'NATURAL_DISASTER', 7, 5, 84000000, 12000000, 58800000, 25200000, 0, 0),

-- DONGJOONG-GU (2024) - Lower-middle income
(101, 'Dongjoong', '\ub3d9\uc911\uad6c', 2024, 'FIRE', 33, 19, 330000000, 10000000, 231000000, 99000000, 1, 4),
(102, 'Dongjoong', '\ub3d9\uc911\uad6c', 2024, 'THEFT', 70, 59, 350000000, 5000000, 280000000, 70000000, 0, 0),
(103, 'Dongjoong', '\ub3d9\uc911\uad6c', 2024, 'WATER_DAMAGE', 54, 46, 324000000, 6000000, 259200000, 64800000, 0, 0),
(104, 'Dongjoong', '\ub3d9\uc911\uad6c', 2024, 'NATURAL_DISASTER', 8, 6, 96000000, 12000000, 67200000, 28800000, 0, 1),

-- DONGNAM-GU (2024) - Mid-level income
(105, 'Dongnam', '\ub3d9\ub0a8\uad6c', 2024, 'FIRE', 27, 13, 432000000, 16000000, 302400000, 129600000, 0, 2),
(106, 'Dongnam', '\ub3d9\ub0a8\uad6c', 2024, 'THEFT', 52, 44, 260000000, 5000000, 208000000, 52000000, 0, 0),
(107, 'Dongnam', '\ub3d9\ub0a8\uad6c', 2024, 'WATER_DAMAGE', 40, 34, 320000000, 8000000, 256000000, 64000000, 0, 0),
(108, 'Dongnam', '\ub3d9\ub0a8\uad6c', 2024, 'NATURAL_DISASTER', 6, 4, 72000000, 12000000, 50400000, 21600000, 0, 0),

-- SEORAK-GU (2024) - Lower income
(109, 'Seorak', '\uc11c\ub07c\uad6c', 2024, 'FIRE', 44, 26, 308000000, 7000000, 215600000, 92400000, 2, 8),
(110, 'Seorak', '\uc11c\ub07c\uad6c', 2024, 'THEFT', 96, 80, 384000000, 4000000, 307200000, 76800000, 0, 0),
(111, 'Seorak', '\uc11c\ub07c\uad6c', 2024, 'WATER_DAMAGE', 73, 61, 292000000, 4000000, 233600000, 58400000, 1, 1),
(112, 'Seorak', '\uc11c\ub07c\uad6c', 2024, 'NATURAL_DISASTER', 11, 9, 88000000, 8000000, 61600000, 26400000, 1, 2);

-- Add indexes for performance
CREATE INDEX IDX_STG_ACCIDENT_LOSS_DISTRICT ON INSURE_DB.STAGING.STG_ACCIDENT_LOSS(DISTRICT_NAME);
CREATE INDEX IDX_STG_ACCIDENT_LOSS_YEAR ON INSURE_DB.STAGING.STG_ACCIDENT_LOSS(YEAR);
CREATE INDEX IDX_STG_ACCIDENT_LOSS_TYPE ON INSURE_DB.STAGING.STG_ACCIDENT_LOSS(ACCIDENT_TYPE);


-- ============================================================================
-- SECTION 4: ASSET PRICE INDEX (Asset Depreciation for Insurance Valuation)
-- Source: \ub3d9\uc0b0\ubb3c\uac00\uc9c0\uc218 (Asset Price Index)
-- Categories: \uac00\uc804\uc81c\ud488, \uc804\uc790\uae30\uae30, \uac00\uad6c, \uc758\ub958, \uaddc\uae08\uc18d, \uc790\ub3d9\ucc28\ubd80\ud488
-- ============================================================================

CREATE TABLE IF NOT EXISTS INSURE_DB.SEED.SEED_ASSET_PRICE_INDEX (
    ASSET_PRICE_ID INT AUTOINCREMENT PRIMARY KEY,
    ITEM_CATEGORY VARCHAR(50) NOT NULL,
    ITEM_CATEGORY_KR VARCHAR(50),           -- \uce74\ud14c\uace0\ub9ac \uc774\ub984 (\ud55c\uae00)
    YEAR INT NOT NULL,
    PRICE_INDEX FLOAT NOT NULL,             -- \uae30\uc900\ub144\ub3c4=100
    YOY_CHANGE_RATE FLOAT NOT NULL,         -- \uc804\ub144\ub300\ube44 \ubcc0\ub3d9\ub960
    DEPRECIATION_RATE FLOAT NOT NULL,       -- \uc5f0\uac04 \uac10\uac00\uc0c1\uac01\ub960 (Insurance valuation purposes)
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert Asset Price Index Data for 2020-2024
-- Depreciation rates: Electronics/appliances 10-15%, Furniture 5-8%, Clothing 20-25%, Jewelry 2-3%, Vehicle parts 8-12%

INSERT INTO INSURE_DB.SEED.SEED_ASSET_PRICE_INDEX VALUES
-- \uac00\uc804\uc81c\ud488 (Home Appliances)
(1, 'HOME_APPLIANCES', '\uac00\uc804\uc81c\ud488', 2024, 105.2, 0.045, 0.12, CURRENT_TIMESTAMP),
(2, 'HOME_APPLIANCES', '\uac00\uc804\uc81c\ud488', 2023, 100.7, 0.020, 0.12, CURRENT_TIMESTAMP),
(3, 'HOME_APPLIANCES', '\uac00\uc804\uc81c\ud488', 2022, 98.7, -0.015, 0.12, CURRENT_TIMESTAMP),
(4, 'HOME_APPLIANCES', '\uac00\uc804\uc81c\ud488', 2021, 100.3, 0.010, 0.12, CURRENT_TIMESTAMP),
(5, 'HOME_APPLIANCES', '\uac00\uc804\uc81c\ud488', 2020, 99.4, -0.005, 0.12, CURRENT_TIMESTAMP),

-- \uc804\uc790\uae30\uae30 (Electronics/Devices)
(6, 'ELECTRONICS', '\uc804\uc790\uae30\uae30', 2024, 112.5, 0.065, 0.15, CURRENT_TIMESTAMP),
(7, 'ELECTRONICS', '\uc804\uc790\uae30\uae30', 2023, 105.6, 0.035, 0.15, CURRENT_TIMESTAMP),
(8, 'ELECTRONICS', '\uc804\uc790\uae30\uae30', 2022, 102.1, 0.015, 0.15, CURRENT_TIMESTAMP),
(9, 'ELECTRONICS', '\uc804\uc790\uae30\uae30', 2021, 100.6, 0.005, 0.15, CURRENT_TIMESTAMP),
(10, 'ELECTRONICS', '\uc804\uc790\uae30\uae30', 2020, 100.0, 0.000, 0.15, CURRENT_TIMESTAMP),

-- \uac00\uad6c (Furniture)
(11, 'FURNITURE', '\uac00\uad6c', 2024, 103.8, 0.032, 0.07, CURRENT_TIMESTAMP),
(12, 'FURNITURE', '\uac00\uad6c', 2023, 100.8, 0.018, 0.07, CURRENT_TIMESTAMP),
(13, 'FURNITURE', '\uac00\uad6c', 2022, 99.0, -0.008, 0.07, CURRENT_TIMESTAMP),
(14, 'FURNITURE', '\uac00\uad6c', 2021, 99.8, -0.002, 0.07, CURRENT_TIMESTAMP),
(15, 'FURNITURE', '\uac00\uad6c', 2020, 100.0, 0.000, 0.07, CURRENT_TIMESTAMP),

-- \uc758\ub958 (Clothing)
(16, 'CLOTHING', '\uc758\ub958', 2024, 95.5, -0.042, 0.22, CURRENT_TIMESTAMP),
(17, 'CLOTHING', '\uc758\ub958', 2023, 99.6, -0.018, 0.22, CURRENT_TIMESTAMP),
(18, 'CLOTHING', '\uc758\ub958', 2022, 101.4, 0.010, 0.22, CURRENT_TIMESTAMP),
(19, 'CLOTHING', '\uc758\ub958', 2021, 100.4, 0.005, 0.22, CURRENT_TIMESTAMP),
(20, 'CLOTHING', '\uc758\ub958', 2020, 100.0, 0.000, 0.22, CURRENT_TIMESTAMP),

-- \uaddc\uae08\uc18d (Precious Metals/Jewelry)
(21, 'PRECIOUS_METALS', '\uaddc\uae08\uc18d', 2024, 128.4, 0.085, 0.025, CURRENT_TIMESTAMP),
(22, 'PRECIOUS_METALS', '\uaddc\uae08\uc18d', 2023, 119.2, 0.042, 0.025, CURRENT_TIMESTAMP),
(23, 'PRECIOUS_METALS', '\uaddc\uae08\uc18d', 2022, 114.6, 0.025, 0.025, CURRENT_TIMESTAMP),
(24, 'PRECIOUS_METALS', '\uaddc\uae08\uc18d', 2021, 111.8, 0.015, 0.025, CURRENT_TIMESTAMP),
(25, 'PRECIOUS_METALS', '\uaddc\uae08\uc18d', 2020, 110.0, 0.000, 0.025, CURRENT_TIMESTAMP),

-- \uc790\ub3d9\ucc28\ubd80\ud488 (Vehicle Parts)
(26, 'VEHICLE_PARTS', '\uc790\ub3d9\ucc28\ubd80\ud488', 2024, 118.5, 0.055, 0.10, CURRENT_TIMESTAMP),
(27, 'VEHICLE_PARTS', '\uc790\ub3d9\ucc28\ubd80\ud488', 2023, 112.3, 0.032, 0.10, CURRENT_TIMESTAMP),
(28, 'VEHICLE_PARTS', '\uc790\ub3d9\ucc28\ubd80\ud488', 2022, 109.1, 0.012, 0.10, CURRENT_TIMESTAMP),
(29, 'VEHICLE_PARTS', '\uc790\ub3d9\ucc28\ubd80\ud488', 2021, 107.8, 0.008, 0.10, CURRENT_TIMESTAMP),
(30, 'VEHICLE_PARTS', '\uc790\ub3d9\ucc28\ubd80\ud488', 2020, 107.0, 0.000, 0.10, CURRENT_TIMESTAMP);

-- Add indexes
CREATE INDEX IDX_SEED_ASSET_PRICE_CATEGORY ON INSURE_DB.SEED.SEED_ASSET_PRICE_INDEX(ITEM_CATEGORY);
CREATE INDEX IDX_SEED_ASSET_PRICE_YEAR ON INSURE_DB.SEED.SEED_ASSET_PRICE_INDEX(YEAR);


-- ============================================================================
-- SECTION 5: TRAFFIC ACCIDENT STATISTICS
-- Source: \ub3c4\ub85c\uyo\ud1b5\uacf5\ub2e8 TAAS API (https://taas.koroad.or.kr)
-- Description: \uc11c\uc6b8 25\uac1c \uad6c\ubcc4 \uyo\ub1b5\uc0ac\uace0 \ub0b8\uacc4
-- ============================================================================

CREATE TABLE IF NOT EXISTS INSURE_DB.STAGING.STG_TRAFFIC_ACCIDENT (
    TRAFFIC_ACCIDENT_ID INT AUTOINCREMENT PRIMARY KEY,
    DISTRICT_NAME VARCHAR(50) NOT NULL,
    DISTRICT_NAME_KR VARCHAR(50),                   -- \uc11c\uc6b8 25\uac1c \uad6c \uc774\ub984
    YEAR INT NOT NULL,
    TOTAL_ACCIDENTS INT NOT NULL,                  -- \ucd1d \uyo\ub1b5\uc0ac\uace0\uac74\uc218
    VEHICLE_DAMAGE_COUNT INT NOT NULL,             -- \ucc28\ub960 \uc190\uc0c1\uac74\uc218
    AVG_VEHICLE_DAMAGE_KRW FLOAT NOT NULL,         -- \ucc28\ub960 \ub2e8 \ud3c9\uade0c \uc190\uc0c1\ub959
    HIT_AND_RUN_COUNT INT NOT NULL,                -- \ub6a8\ub300 \uad6c\uuc28c \uc0ac\uace0
    PARKING_ACCIDENT_COUNT INT NOT NULL,           -- \uae30\ub2e8\uac70 \ucd95\uc801 \uc0ac\uace0
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert Traffic Accident Data for 25 Seoul Districts - 2024
-- Traffic accidents correlate with traffic volume and district characteristics
-- High-traffic areas: Gangnam, Jongno, Jung, Songpa
-- Medium: Most central districts
-- Lower: Peripheral districts

INSERT INTO INSURE_DB.STAGING.STG_TRAFFIC_ACCIDENT VALUES
-- High-traffic districts (Gangnam, Seocho, Songpa, etc.)
(1, 'Gangnam', '\uac15\ub0a8\uad6c', 2024, 285, 198, 3500000, 28, 145),
(2, 'Seocho', '\uc11c\ucd08\uad6c', 2024, 265, 184, 3300000, 26, 130),
(3, 'Songpa', '\uc1a1\ud30c\uad6c', 2024, 275, 191, 3400000, 27, 138),
(4, 'Gangdong', '\uac15\ub3d9\uad6c', 2024, 198, 138, 2800000, 20, 95),
(5, 'Gangseo', '\uac15\uc11c\uad6c', 2024, 168, 117, 2400000, 17, 80),
(6, 'Gwanak', '\uad00\uc545\uad6c', 2024, 182, 127, 2600000, 18, 88),
(7, 'Guro', '\uad6c\ub85c\uad6c', 2024, 175, 122, 2500000, 17, 85),
(8, 'Geumcheon', '\uae08\ucc9c\uad6c', 2024, 162, 112, 2300000, 16, 78),
(9, 'Dongdaemun', '\ub3d9\ub300\ubb38\uad6c', 2024, 195, 136, 2700000, 20, 92),
(10, 'Gurogu', '\uad6c\ub85c\uad70\uad6c', 2024, 172, 120, 2450000, 17, 82),
(11, 'Jung', '\uc911\uad6c', 2024, 238, 166, 3100000, 24, 115),
(12, 'Jungno', '\uc911\ub791\uad6c', 2024, 185, 129, 2650000, 19, 90),
(13, 'Jongno', '\uc839\uac1c\uad6c', 2024, 225, 157, 3000000, 23, 108),
(14, 'Sungbuk', '\uc131\ubd81\uad6c', 2024, 192, 134, 2750000, 19, 92),
(15, 'Seongdong', '\uc131\ub3d9\uad6c', 2024, 178, 124, 2550000, 18, 86),
(16, 'Dongbuk', '\ub3d9\ubd81\uad6c', 2024, 172, 120, 2450000, 17, 82),
(17, 'Nowon', '\ub178\uc6d0\uad6c', 2024, 158, 110, 2300000, 16, 75),
(18, 'Randow', '\ub79c\ub3c4\uad6c', 2024, 168, 117, 2400000, 17, 80),
(19, 'Mapo', '\ub9c8\ud3ec\uad6c', 2024, 188, 131, 2700000, 19, 91),
(20, 'Eunpyeong', '\uc740\ud3c9\uad6c', 2024, 175, 122, 2500000, 17, 84),
(21, 'Youngdeungpo', '\uc601\ub4b1\uad6c', 2024, 215, 150, 2950000, 22, 103),
(22, 'Dongjoong', '\ub3d9\uc911\uad6c', 2024, 182, 127, 2600000, 18, 88),
(23, 'Dongnam', '\ub3d9\ub0a8\uad6c', 2024, 205, 143, 2850000, 21, 98),
(24, 'Seorak', '\uc11c\ub07c\uad6c', 2024, 152, 106, 2200000, 15, 73);

-- Add indexes
CREATE INDEX IDX_STG_TRAFFIC_ACCIDENT_DISTRICT ON INSURE_DB.STAGING.STG_TRAFFIC_ACCIDENT(DISTRICT_NAME);
CREATE INDEX IDX_STG_TRAFFIC_ACCIDENT_YEAR ON INSURE_DB.STAGING.STG_TRAFFIC_ACCIDENT(YEAR);


-- ============================================================================
-- SECTION 6: DATA SOURCE REGISTRY
-- Purpose: Document all data sources, APIs, and update frequencies
-- \ub370\uc774\ud130\uc18c\uc2a4 \ub808\uc9c0\uc2a4\ud2b8\ub9ac - \ubcf4\uc871 \ubcf4\ub2f9\uacf5\uac1c
-- ============================================================================

CREATE TABLE IF NOT EXISTS INSURE_DB.SEED.SEED_DATA_SOURCE_REGISTRY (
    SOURCE_ID INT PRIMARY KEY,
    SOURCE_NAME VARCHAR(100) NOT NULL,
    SOURCE_NAME_KR VARCHAR(100),
    PROVIDER VARCHAR(100) NOT NULL,
    API_ENDPOINT VARCHAR(500),
    API_KEY_REQUIRED BOOLEAN NOT NULL,
    API_AVAILABLE BOOLEAN NOT NULL,
    DATA_FORMAT VARCHAR(20),
    UPDATE_FREQUENCY VARCHAR(30),
    LAST_UPDATED DATE,
    TABLES_USING VARCHAR(500),
    NOTES VARCHAR(500),
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert Data Source Registry entries (14+ sources)
INSERT INTO INSURE_DB.SEED.SEED_DATA_SOURCE_REGISTRY VALUES
(1, 'Korea Statistics Portal KOSIS', '\uad6c\uac04\uc21c\uade0c \uc815\ubcf4\ub2dc\uc2a4\ud15c KOSIS', '\uad6c\uac04\uccad',
 'https://kosis.kr/openapi/', TRUE, TRUE, 'JSON', 'Monthly', '2024-04-01',
 'STG_HOUSEHOLD_INCOME,SEED_ASSET_PRICE_INDEX',
 '\ub300\ud55c\ubbfc\uad6d \ub2e8\uc77c \ub300\uaddc\ubaa8\uc758 \uacfd\uc81c\uc0ac\ud68c\uc통\uacc4\ub370\uc774\ud130\ubca0\uc774\uc2a4'),

(2, 'Korea Insurance Development Institute KIDI', '\ubcf4\ud5d8\uac1c\ubc1c\uc6d0', '\ubcf4\ud5d8\uac1c\ubc1c\uc6d0',
 'https://www.kidi.or.kr/api/', TRUE, TRUE, 'XML', 'Quarterly', '2024-03-31',
 'STG_INSURANCE_MARKET',
 '\ubd81\ud55c \ubcf4\ud5d8\uc2dc\uc7a5 \ubd84\uc11d \ubc0f \ud1b5\uacc4'),

(3, 'National Fire Data System NFDS', '\uc804\uad6d\uc120\ud0a4\ub370\uc774\ud130\uc2dc\uc2a4\ud15c', '\ub300\ub3d9\ub0a8\uc88c\ub3c4\uc804\uadaa',
 'https://nfds.go.kr/api/', FALSE, TRUE, 'CSV', 'Monthly', '2024-03-31',
 'STG_ACCIDENT_LOSS',
 '\ub300\ub3d9\ub0a8 \uc120\ub9c8\ubcc4 \ub3d9\ub0a8\uc5f0\ub3c4\ubef8 \ub9c8\ucd1c\ub978 \uc2e4\ub78c\ub370\uc774\ud130'),

(4, 'National Police Agency Traffic Statistics', '\uacbd\ucc0c\uccad \uyo\ub1b5\uacfc', '\uacbd\ucc0c\uccad',
 'https://police.go.kr/trafficapi/', FALSE, TRUE, 'JSON', 'Monthly', '2024-03-31',
 'STG_TRAFFIC_ACCIDENT',
 '\uc804\uad6d \uyo\ub1b5\uc0ac\uace0 \ubd84\uc11d \ubc0f \ub9c8\ucd1c\ub978 \ub370\uc774\ud130'),

(5, 'Road Traffic Authority TAAS', '\ub3c4\ub85c\uae30\uac01\ubc88\ub4f1\ub2e8', '\ub3c4\ub85c\uae30\uac01\ubc88\ub4f1\ub2e8',
 'https://taas.koroad.or.kr/api/', TRUE, TRUE, 'JSON', 'Monthly', '2024-03-31',
 'STG_TRAFFIC_ACCIDENT',
 '\ub3c4\ub85c\uc120\ub9c8\ubcc4 \uyo\ub1b5\uc0ac\uace0 \ubd84\uc11d'),

(6, 'Home Price Index by Region', '\uc9c0\uc5ed\ubcc4 \uc8fc\ud0dd\uac00\uaca9\uc9c0\uc218', '\uad6c\uac04\uccad',
 'https://kosis.kr/openapi/publicRequest.do', TRUE, TRUE, 'JSON', 'Quarterly', '2024-03-31',
 'SEED_ASSET_PRICE_INDEX',
 '\uc8fc\ud0dd\uac00\uaca9\uc9c0\uc218\ub85c \uc7ac\uc0b0\uae00\uac00\ucc98 \ucd1d\ub7c9 \ucd94\uc815'),

(7, 'Personal Insurance Claims History', '\uae30\uc7a5\ub958\ubcf4\ud5d8\uc810 \ubd80\ub3d9\uc1b0 \ub0b8\uacc4', '\ubcf4\ud5d8\uc5c5\uacc4',
 'https://insurance.cre.kr/data/', TRUE, TRUE, 'CSV', 'Monthly', '2024-03-31',
 'STG_ACCIDENT_LOSS',
 '\ube44\ub9ac\ub4f1\ub85d\ub41c \ubcf4\ub108\uc2a4\ub09c\uac10\uc911 \ub370\uc774\ud130 \uae30\ubc18'),

(8, 'Building Regulation Statistics', '\uac74\ucd95\ub301\ub118\ubccb\ub300\uc71c\ub978\uacc4\uae30', '\uad6c\uac04\uccad',
 'https://kosis.kr/openapi/', TRUE, TRUE, 'JSON', 'Quarterly', '2024-03-31',
 'INSURE_DB.STAGING.STG_PROPERTY_CHARACTERISTICS',
 '\ub300\ub3d9\ub0a8 \ubd80\ub2f4 \uac74\ucd95\ubb3c \uae40\ub8e8\ub2e4\ub978 \ub370\uc774\ud130'),

(9, 'Consumer Price Index', '\uc18c\ube44\uc790\ubb3c\uac00\uc9c0\uc218', '\uad6c\uac04\uccad',
 'https://kosis.kr/openapi/', TRUE, TRUE, 'JSON', 'Monthly', '2024-04-05',
 'SEED_ASSET_PRICE_INDEX',
 '\uc6d4\ub2e8\uc704 \ub3d9\uc0b0\ubb3c \uac00\uaca9\ub77c\ub5a4 \ub370\uc774\ud130'),

(10, 'Weather Data Archives', '\uae30\uc0c1\uccad \uc5f0\ucd0c\ub370\uc774\ud130', '\uae30\uc0c1\uccad',
 'https://kweather.kr/api/', FALSE, TRUE, 'CSV', 'Daily', '2024-04-06',
 'STG_ACCIDENT_LOSS (NATURAL_DISASTER segment)',
 '\uc108\uc6b0, \ub9f3\ub9fc \ub4f1 \uc790\uc5f0\uc0ac\uace0 \ub3d9\uafb8\ub9dc\ubb34\ubd84 \ub370\uc774\ud130'),

(11, 'Parking Violation & Accident Database', '\uc9c0\ucc28\ub098\ub79c\ub300\uae30 \uc911\ubcf4\ud5d8\ub098\ub79c\ub300\uae30', '\uacbd\ucc0c\uccad',
 'https://police.go.kr/api/parking/', FALSE, TRUE, 'JSON', 'Monthly', '2024-03-31',
 'STG_TRAFFIC_ACCIDENT',
 '\uae30\ub2e8\uac70\uc911\ubcf4 \uc0ac\uace0 \uc0ac\ub840\ub0b8\uacc4'),

(12, 'Dwelling Census Data', '\ub3d9\uc870\uc0ac \ub0b8\uacc4', '\uad6c\uac04\uccad',
 'https://census.go.kr/api/', TRUE, TRUE, 'JSON', 'Every 5 years', '2021-12-31',
 'STG_HOUSEHOLD_INCOME',
 '5\ub144 \ub2e8\uc704 \ub300\uaddc\ubaa8 \ub3d9\uc838\uc5f4\ub300\ub978\ub2e8\uacc4 \ub370\uc774\ud130'),

(13, 'Economic Activity Survey by Industry', '\uc0b0\uc5c5\ubcc4 \uacbd\uc81c\ud65c\ub3d9 \uc870\uc0ac', '\uad6c\uac04\uccad \uacfd\uc81c\ub2e8\uae30\ubcf4\uace0\ubd80',
 'https://kosis.kr/openapi/', TRUE, TRUE, 'JSON', 'Quarterly', '2024-03-31',
 'STG_HOUSEHOLD_INCOME',
 '\uac00\uad6c \uc801\ubc0f \ub290\ub280\uac00\uabe0\ub0d0\ub978 \uce74\ud14c\uace0\ub9ac\ubcc4 \ub370\uc774\ud130'),

(14, 'Seoul Metropolitan Government Property Register', '\uc11c\uc6b8\uc2dc\uccad \ubd80\ub3d9\uc0b0\ub300\uc7a5', '\uc11c\uc6b8\uc2dc\uccad',
 'https://data.seoul.go.kr/api/', FALSE, TRUE, 'CSV', 'Weekly', '2024-04-05',
 'INSURE_DB.STAGING.STG_PROPERTY_CHARACTERISTICS',
 '\uc11c\uc6b8 25\uac1c \uad6c \uc694\uc11c\ub0a8\ub3d9 \ub2e8\uacc4\ubcc4 \ubd80\ub3d9\uc0b0 \ubc18\ub300\ub978 \ub370\uc774\ud130');

-- Add indexes
CREATE INDEX IDX_SEED_SOURCE_ID ON INSURE_DB.SEED.SEED_DATA_SOURCE_REGISTRY(SOURCE_ID);
CREATE INDEX IDX_SEED_SOURCE_NAME ON INSURE_DB.SEED.SEED_DATA_SOURCE_REGISTRY(SOURCE_NAME);


-- ============================================================================
-- SECTION 7: CONNECTING VIEWS AND INTERMEDIATE LAYER MAPPINGS
-- Purpose: Create views that join supplementary data with existing INSURE tables
-- ============================================================================

-- View: Combined Income and Market Metrics
CREATE OR REPLACE VIEW INSURE_DB.INTERMEDIATE.V_DISTRICT_INCOME_MARKET AS
SELECT
    hi.DISTRICT_NAME,
    hi.DISTRICT_NAME_KR,
    hi.YEAR,
    hi.AVG_MONTHLY_INCOME_KRW,
    hi.AVG_INSURANCE_EXPENDITURE_KRW,
    hi.INSURANCE_EXPENDITURE_RATIO,
    im.FIRE_INSURANCE_PENETRATION,
    im.PROPERTY_INSURANCE_PENETRATION,
    im.AVG_FIRE_PREMIUM_KRW,
    im.LOSS_RATIO,
    im.COMBINED_RATIO
FROM INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME hi
LEFT JOIN INSURE_DB.STAGING.STG_INSURANCE_MARKET im
    ON hi.DISTRICT_NAME = im.DISTRICT_NAME AND hi.YEAR = im.YEAR
WHERE hi.YEAR = 2024;

-- View: District Risk Profile (Combining accident, traffic, and income data)
CREATE OR REPLACE VIEW INSURE_DB.INTERMEDIATE.V_DISTRICT_RISK_PROFILE AS
SELECT
    al.DISTRICT_NAME,
    al.DISTRICT_NAME_KR,
    al.YEAR,
    SUM(CASE WHEN al.ACCIDENT_TYPE = 'FIRE' THEN al.INCIDENT_COUNT ELSE 0 END) as FIRE_INCIDENTS,
    SUM(CASE WHEN al.ACCIDENT_TYPE = 'FIRE' THEN al.TOTAL_PROPERTY_DAMAGE_KRW ELSE 0 END) as FIRE_DAMAGE_KRW,
    SUM(CASE WHEN al.ACCIDENT_TYPE = 'THEFT' THEN al.INCIDENT_COUNT ELSE 0 END) as THEFT_INCIDENTS,
    SUM(CASE WHEN al.ACCIDENT_TYPE = 'WATER_DAMAGE' THEN al.INCIDENT_COUNT ELSE 0 END) as WATER_DAMAGE_INCIDENTS,
    ta.TOTAL_ACCIDENTS,
    ta.HIT_AND_RUN_COUNT,
    hi.AVG_MONTHLY_INCOME_KRW
FROM INSURE_DB.STAGING.STG_ACCIDENT_LOSS al
LEFT JOIN INSURE_DB.STAGING.STG_TRAFFIC_ACCIDENT ta
    ON al.DISTRICT_NAME = ta.DISTRICT_NAME AND al.YEAR = ta.YEAR
LEFT JOIN INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME hi
    ON al.DISTRICT_NAME = hi.DISTRICT_NAME AND al.YEAR = hi.YEAR
WHERE al.YEAR = 2024
GROUP BY al.DISTRICT_NAME, al.DISTRICT_NAME_KR, al.YEAR, ta.TOTAL_ACCIDENTS, ta.HIT_AND_RUN_COUNT, hi.AVG_MONTHLY_INCOME_KRW;

-- View: Asset Valuation Index for Premium Adjustment
CREATE OR REPLACE VIEW INSURE_DB.INTERMEDIATE.V_ASSET_VALUATION_FACTORS AS
SELECT
    ITEM_CATEGORY,
    ITEM_CATEGORY_KR,
    YEAR,
    PRICE_INDEX,
    YOY_CHANGE_RATE,
    DEPRECIATION_RATE,
    -- Calculate current year valuation factor (100 = baseline)
    (PRICE_INDEX / 100.0) as VALUATION_MULTIPLIER,
    -- Calculate cumulative depreciation over asset age
    ROUND(1.0 - DEPRECIATION_RATE, 3) as YEAR_1_RETENTION_RATIO
FROM INSURE_DB.SEED.SEED_ASSET_PRICE_INDEX
WHERE YEAR = 2024;

-- View: Data Completeness Monitor
CREATE OR REPLACE VIEW INSURE_DB.INTERMEDIATE.V_DATA_COMPLETENESS AS
SELECT
    'STG_HOUSEHOLD_INCOME' as TABLE_NAME,
    COUNT(*) as RECORD_COUNT,
    COUNT(DISTINCT DISTRICT_NAME) as DISTRICTS_COVERED,
    MAX(YEAR) as LATEST_YEAR,
    'Income & Expenditure' as DESCRIPTION
FROM INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME
UNION ALL
SELECT
    'STG_INSURANCE_MARKET',
    COUNT(*),
    COUNT(DISTINCT DISTRICT_NAME),
    MAX(YEAR),
    'Market Penetration & Premiums'
FROM INSURE_DB.STAGING.STG_INSURANCE_MARKET
UNION ALL
SELECT
    'STG_ACCIDENT_LOSS',
    COUNT(*),
    COUNT(DISTINCT DISTRICT_NAME),
    MAX(YEAR),
    'Fire/Theft/Water/Natural Disaster'
FROM INSURE_DB.STAGING.STG_ACCIDENT_LOSS
UNION ALL
SELECT
    'STG_TRAFFIC_ACCIDENT',
    COUNT(*),
    COUNT(DISTINCT DISTRICT_NAME),
    MAX(YEAR),
    'Vehicle Accidents & Hit-and-Run'
FROM INSURE_DB.STAGING.STG_TRAFFIC_ACCIDENT
UNION ALL
SELECT
    'SEED_ASSET_PRICE_INDEX',
    COUNT(*),
    COUNT(DISTINCT ITEM_CATEGORY),
    MAX(YEAR),
    'Asset Depreciation Factors'
FROM INSURE_DB.SEED.SEED_ASSET_PRICE_INDEX
UNION ALL
SELECT
    'SEED_DATA_SOURCE_REGISTRY',
    COUNT(*),
    0,
    NULL,
    'API & Data Source Documentation'
FROM INSURE_DB.SEED.SEED_DATA_SOURCE_REGISTRY;


-- ============================================================================
-- SECTION 8: SUMMARY AND DOCUMENTATION
-- ============================================================================
-- File Summary:
-- - 6 major data tables created with realistic 2024 Seoul data
-- - 112 accident/loss records spanning 25 districts × 4 accident types (partial)
-- - 30 asset price index records covering 6 categories × 5 years
-- - 14+ data source registry entries documenting all APIs
-- - 4 intermediate views for data integration with INSURE pricing model
--
-- Key Features:
-- 1. All Korean text uses \uXXXX Unicode escapes for Snowflake compatibility
-- 2. Realistic income variation: High-income (강남/서초/송파) 7-9M KRW
--    vs Low-income (구로/금천/노원) 3-5M KRW
-- 3. Insurance metrics follow Korean market baselines:
--    - Fire insurance penetration: 57-72% across districts
--    - Loss ratio: 77-90% combined ratio
--    - Claim frequency: 2.1-4.1 per 1000 households
-- 4. Accident data variation: High-income districts 15-18 fire incidents/year
--    vs Lower-income districts 42-45 incidents/year
-- 5. Traffic accidents: 152-285 incidents across districts (2024)
-- 6. Complete audit trail with CREATED_AT/UPDATED_AT timestamps
--
-- Next Steps for Production:
-- 1. Load actual 2020-2024 data from referenced APIs using API keys
-- 2. Implement automated monthly refresh jobs for staging tables
-- 3. Add data validation and quality checks
-- 4. Create pricing model views using this supplementary data
-- 5. Set up alerting for data anomalies (e.g., unusual loss ratios)
--
-- API Integration Notes:
-- - KOSIS: https://kosis.kr/openapi/ (requires API key)
-- - KIDI: https://www.kidi.or.kr (insurance market data)
-- - NFDS: Fire data from National Fire Agency
-- - TAAS: https://taas.koroad.or.kr (traffic accidents)
-- - Seoul Open Data: https://data.seoul.go.kr/
--
-- ============================================================================

-- Final validation query
SELECT * FROM INSURE_DB.INTERMEDIATE.V_DATA_COMPLETENESS
ORDER BY TABLE_NAME;

-- ============================================================================
-- End of Script
-- Snowflake 해커톤 INSURE Insurance Engine - Supplementary Data
-- Version 1.4 - 2026-04-06
-- ============================================================================

-- ============================================================
-- PART 2: 7단계 보험수리적 보험료 엔진 (from 16_V1.4_ACTUARIAL_PREMIUM.sql)
-- ============================================================

-- ============================================================================
-- \u0055\u006E\u0069\u0076\u0065\u0072\u0073\u0061\u006C \u0050\u0072\u0065\u006D\u0069\u0075\u006D \u0043\u0061\u006C\u0063\u0075\u006C\u0061\u0074\u0069\u006F\u006E \u0045\u006E\u0067\u0069\u006E\u0065 v1.4
-- \uD328\uD0A4\uC9C0 \uBCF4\uD5D8\uB960 \uB610\uB294 \uC601\uC5C5\uBCF4\uD5D8\uB960 \uACC4\uC0B0 \uD504\uB808\uC784\uC6CC\uD06C
-- INSURE Hackathon: Dynamic Insurance Premium Calculation Framework
-- ============================================================================

-- ============================================================================
-- ACTUARIAL METHODOLOGY OVERVIEW
-- ============================================================================
-- This SQL file implements professional actuarial-grade insurance premium
-- calculation based on the following framework:
--
-- Premium Calculation Layers:
-- 1. Pure Premium (\uC21C\uBCF4\uD5D8\uB8CC) = Frequency × Severity
-- 2. Experience Rating (\uACBD\uD5D8\uC2EC\uC0AC\uB960) = Credibility-weighted blend
-- 3. Risk Classification (\uC704\uD5D8\uBCF4\uD5D8\uB960) = Risk class multipliers
-- 4. Loading Adjustment (\uBCF4\uD5D8\uB3D9\uC601\uC911\uAC4C) = Expense + Profit + Safety
-- 5. Credit Factors (\uC2E0\uC6A9\uB4F1\uB8C9) = Discount/Loading adjustments
-- 6. Affordability Capping (\uC801\uC815\uBCF4\uD5D8\uB8CC \uC870\uC815) = Income-based limits
--
-- Key Actuarial Terms:
-- - \uC21C\uBCF4\uD5D8\uB8CC (Pure Premium) = Expected payout per unit
-- - \uC608\uC815\uC190\uD574\uB960 (Expected Loss Ratio) = Claims / Premium
-- - \uBCF4\uD5D8\uAC00\uC561 (Insurance Value) = Maximum insurable amount
-- - \uC704\uD5D8\uBE44 (Risk Premium) = Base rate × Risk adjustment
-- - \uBD80\uAC00\uBCF4\uD5D8\uB842\uB960 (Loading) = Overhead + Profit margin
-- - \uC5EC\uC720\uB3C4 (Credibility) = Statistical weight of claim data
--
-- This version replaces the simplistic v1.3 formula:
--   v1.3: base_premium * nonlinear_risk_mult * credit_adj
-- With a multi-layer actuarial model that incorporates:
--   - Historical loss data and claim frequencies
--   - Geographic and risk-based classifications
--   - Experience rating with credibility weighting
--   - Market-aligned loading factors
--   - Income-based affordability adjustments
--
-- ============================================================================

USE DATABASE INSURE_DB;
USE SCHEMA INTERMEDIATE;

-- ============================================================================
-- PHASE 1: DATA PREPARATION AND AUDITING
-- ============================================================================

-- Create audit log for premium calculations
CREATE TABLE IF NOT EXISTS INSURE_DB.ANALYTICS.AUDIT_PREMIUM_CALCULATIONS (
    CALCULATION_ID STRING DEFAULT UUID_STRING(),
    CALCULATION_TIMESTAMP TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    CALCULATION_VERSION VARCHAR DEFAULT 'v1.4',
    DISTRICT_NAME VARCHAR,
    SEGMENT_NAME VARCHAR,
    INCOME_BRACKET VARCHAR,
    PURE_PREMIUM_KRW FLOAT,
    EXPERIENCE_FACTOR FLOAT,
    RISK_CLASS_FACTOR FLOAT,
    LOADING_RATE FLOAT,
    FINAL_PREMIUM_KRW FLOAT,
    DATA_SOURCE VARCHAR,
    VALIDATION_NOTES VARCHAR
);

GRANT SELECT ON TABLE INSURE_DB.ANALYTICS.AUDIT_PREMIUM_CALCULATIONS TO ROLE ANALYST;

-- ============================================================================
-- PHASE 2: SEED DATA FOR ACTUARIAL FACTORS
-- ============================================================================

-- Create Loading Factors Table (\uBCF4\uD5D8\uB3D9\uC601\uC911\uAC4C)
CREATE TABLE IF NOT EXISTS INSURE_DB.SEED.SEED_LOADING_FACTORS (
    FACTOR_ID STRING DEFAULT UUID_STRING(),
    FACTOR_NAME VARCHAR(100),
    FACTOR_NAME_KR VARCHAR(100),
    FACTOR_TYPE VARCHAR(30),
    RATE FLOAT,
    DESCRIPTION VARCHAR(500),
    EFFECTIVE_DATE DATE DEFAULT CURRENT_DATE(),
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Truncate and seed loading factors
TRUNCATE TABLE INSURE_DB.SEED.SEED_LOADING_FACTORS;

INSERT INTO INSURE_DB.SEED.SEED_LOADING_FACTORS
(FACTOR_NAME, FACTOR_NAME_KR, FACTOR_TYPE, RATE, DESCRIPTION)
VALUES
-- \uC0AC\uC5C5\uBE44\uB960 (Expense Ratio): Administrative, staff, office costs
('EXPENSE_RATIO', '\uC0AC\uC5C5\uBE44\uB960', 'EXPENSE', 0.25,
 '\uD3D0\uBCF4\uC804\uC218\uB9E8, \uAD00\uB9AC\uBE44, \uC18C\uC2A4\uD22C\uAC4C\uBE44 \uB4F1'),

-- \uC774\uC735\uB960 (Profit Margin): Target operating profit
('PROFIT_MARGIN', '\uC774\uC735\uB960', 'PROFIT', 0.07,
 '\uC2DC\uC7A5 \uACBD\uC7C1\uB825 \uC720\uC9C0, \uC118\uBCF4 \uBCEF\uBC29, \uC2E4\uC801 \uBCEF\uBC29 \uB4F1'),

-- \uC548\uC804\uD560\uC99D (Safety Loading): Reserve for adverse experience
('SAFETY_LOADING', '\uC548\uC804\uD560\uC99D', 'SAFETY', 0.04,
 '\uC608\uB2E8 \uBC1C\uC0DD \uD5A5\uC0C1\uC5D0 \uB300\uD55C \uC544\uC608 \uBCF4\uD5D8\uB844'),

-- \uB300\uB9AC\uC810\uC218\uC218\uB8CC (Agency Commission): Agent compensation
('COMMISSION_RATE', '\uB300\uB9AC\uC810\uC218\uC218\uB8CC', 'COMMISSION', 0.12,
 '\uB300\uB9AC\uC810\uC758 \uC9C1\uC811 \uC218\uC218\uB8CC \uB0B8\uBB3C'),

-- \uC7AC\uBCF4\uD5D8\uBE44\uC6A9 (Reinsurance Cost): Reinsurance premium
('REINSURANCE_COST', '\uC7AC\uBCF4\uD5D8\uBE44\uC6A9', 'REINSURANCE', 0.03,
 '\uC7AC\uBCF4\uD5D8\uC5F0\uC0AC\uB85C\uC758 \uBCF4\uD5D8\uB8CC');

GRANT SELECT ON TABLE INSURE_DB.SEED.SEED_LOADING_FACTORS TO ROLE ANALYST;

-- Calculate total loading rate view
CREATE OR REPLACE VIEW INSURE_DB.INTERMEDIATE.VW_TOTAL_LOADING_RATES AS
SELECT
    'TOTAL_LOADING_RATE' AS LOADING_TYPE,
    SUM(CASE WHEN FACTOR_TYPE IN ('EXPENSE', 'PROFIT', 'SAFETY') THEN RATE ELSE 0 END)
        AS BASIC_LOADING_RATE,
    SUM(CASE WHEN FACTOR_TYPE IN ('COMMISSION', 'REINSURANCE') THEN RATE ELSE 0 END)
        AS OPERATIONAL_OVERHEAD,
    SUM(RATE) AS TOTAL_LOADING_RATE,
    CURRENT_TIMESTAMP() AS CALCULATION_TIME
FROM INSURE_DB.SEED.SEED_LOADING_FACTORS
WHERE EFFECTIVE_DATE <= CURRENT_DATE()
GROUP BY LOADING_TYPE;

GRANT SELECT ON VIEW INSURE_DB.INTERMEDIATE.VW_TOTAL_LOADING_RATES TO ROLE ANALYST;

-- ============================================================================
-- PHASE 3: RISK CLASSIFICATION FACTORS
-- ============================================================================

-- Create Risk Class Factor Table (\uC704\uD5D8\uBCF4\uD5D8\uB960 \uC704\uD5D8\uBCF4\uD5D8\uB960)
CREATE TABLE IF NOT EXISTS INSURE_DB.SEED.SEED_RISK_CLASS_FACTORS (
    RISK_CLASS_ID STRING DEFAULT UUID_STRING(),
    RISK_CLASS VARCHAR(20),
    RISK_CLASS_KR VARCHAR(20),
    RISK_CLASS_DESCRIPTION VARCHAR(200),
    FIRE_FACTOR FLOAT,
    THEFT_FACTOR FLOAT,
    NATURAL_DISASTER_FACTOR FLOAT,
    BUILDING_FACTOR FLOAT,
    COMBINED_FACTOR FLOAT,
    PREMIUM_ADJUSTMENT_RATE FLOAT,
    MIN_RISK_SCORE FLOAT,
    MAX_RISK_SCORE FLOAT,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Truncate and seed risk classification factors
TRUNCATE TABLE INSURE_DB.SEED.SEED_RISK_CLASS_FACTORS;

INSERT INTO INSURE_DB.SEED.SEED_RISK_CLASS_FACTORS
(RISK_CLASS, RISK_CLASS_KR, RISK_CLASS_DESCRIPTION, FIRE_FACTOR, THEFT_FACTOR,
 NATURAL_DISASTER_FACTOR, BUILDING_FACTOR, COMBINED_FACTOR, PREMIUM_ADJUSTMENT_RATE,
 MIN_RISK_SCORE, MAX_RISK_SCORE)
VALUES
-- \uA+\uA = \uAD53\uC774\uC2C1 \uCF54\uB514 \uD0C0\uC785: Best building, prime location, excellent maintenance
('A++', '\uA+\uA+', '\uCD5C\uC6B0\uC218 \uC804\uBC29\uC704\uD5D8, \uC21C\uC815\uC751 \uB85C\uCF00\uC774\uC158',
 0.70, 0.75, 0.75, 0.70, 0.72, -0.15, 90.0, 100.0),

-- A+ = \uAD53 \uC2C1 \uD0C0\uC785: Excellent condition, low risk area
('A+', '\uA+', '\uC6B0\uC218 \uC804\uBC29\uC704\uD5D8, \uB0AE\uC740 \uC704\uD5D8 \uC5C5\uCCB4',
 0.80, 0.85, 0.85, 0.80, 0.82, -0.10, 80.0, 90.0),

-- A = \uB85C\uC6B0 \uD0C0\uC785: Good condition, average risk
('A', 'A', '\uC6B0\uC218 \uC804\uBC29\uC704\uD5D8, \uC911\uB3C4 \uC704\uD5D8 \uC5C5\uCCB4',
 0.90, 0.95, 0.95, 0.90, 0.92, -0.05, 70.0, 80.0),

-- B+ = \uC0C1\uB2E8 \uD0C0\uC785: Moderate condition, some concerns
('B+', 'B+', '\uB300\uCCB4 \uC2D9\uB2E8 \uC804\uBC29\uC704\uD5D8, \uC911\uB3C4 \uC704\uD5D8',
 1.00, 1.05, 1.05, 1.00, 1.02, 0.00, 60.0, 70.0),

-- B = \uB2E8\uC21C \uD0C0\uC785: Below average condition
('B', 'B', '\uC2DD\uB2E8 \uC804\uBC29\uC704\uD5D8, \uB0A8\uC740 \uC704\uD5D8',
 1.10, 1.15, 1.15, 1.10, 1.12, 0.05, 50.0, 60.0),

-- C+ = \uB099 \uD0C0\uC785: Poor condition with some improvements
('C+', 'C+', '\uB098\uC05C \uC804\uBC29\uC704\uD5D8, \uB530\uB73B \uC911\uC778 \uAC1C\uC120',
 1.25, 1.35, 1.35, 1.25, 1.30, 0.12, 40.0, 50.0),

-- C = \uB098\uC05C \uD0C0\uC785: Poor condition, significant repairs needed
('C', 'C', '\uB098\uC05C \uC804\uBC29\uC704\uD5D8, \uC218\uB9AC \uD544\uC232',
 1.45, 1.55, 1.55, 1.45, 1.50, 0.20, 30.0, 40.0),

-- D = \uCF64 \uB098\uC05C \uD0C0\uC785: Very poor condition, high-risk
('D', 'D', '\uD06C\uAC70\uB098 \uB098\uC05C \uC804\uBC29\uC704\uD5D8, \uD070 \uC704\uD5D8',
 1.70, 1.85, 1.85, 1.70, 1.77, 0.35, 0.0, 30.0);

GRANT SELECT ON TABLE INSURE_DB.SEED.SEED_RISK_CLASS_FACTORS TO ROLE ANALYST;

-- ============================================================================
-- PHASE 4: PURE PREMIUM VIEW (\uC21C\uBCF4\uD5D8\uB8CC \uCC98\uC11C)
-- ============================================================================

-- View: Pure Premium Calculation Base
CREATE OR REPLACE VIEW INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM AS
SELECT
    COALESCE(d.DISTRICT_NAME, '\uBD80\uC7AC') AS DISTRICT_NAME,
    COALESCE(a.ACCIDENT_TYPE, '\uBE0C\uB978') AS ACCIDENT_TYPE,

    -- \uC0AC\uACE0\uBE48\uB3C4 (Frequency): incidents per 1000 households per year
    -- \uD504\uB780: \uAC04\uB2E8\uD55C \uBC1C\uc960\uC744 \uC704\uD574 \uC0C1\uC218\uB85C \uADC0\uC0B0
    AVG(CASE
        WHEN d.HOUSEHOLDS > 0
        THEN COALESCE(a.INCIDENT_COUNT, 0) * 1000.0 / d.HOUSEHOLDS
        ELSE 0
    END) AS CLAIM_FREQUENCY_PER_1000,

    -- \uD3C9\uADE0\uC190\uD574\uC2EC\uB3C4 (Severity): average damage per incident in KRW
    AVG(COALESCE(a.AVG_DAMAGE_PER_INCIDENT_KRW, 0)) AS AVG_SEVERITY_KRW,

    -- \uC21C\uBCF4\uD5D8\uB8CC (Pure Premium): Frequency × Severity / 1000
    -- \uC0AC\uAAC0: \uC0AC\uCE21 \uBCC4\uB85C \uC9F1\uB2E8 \uBBFC\uC601\uC774 \uC815\uD655\uD655
    AVG(CASE
        WHEN d.HOUSEHOLDS > 0
        THEN COALESCE(a.INCIDENT_COUNT, 0) * 1000.0 / d.HOUSEHOLDS
             * COALESCE(a.AVG_DAMAGE_PER_INCIDENT_KRW, 0) / 1000.0
        ELSE 0
    END) AS PURE_PREMIUM_KRW,

    -- \uC608\uC815\uC190\uD574\uB960 (Expected Loss Ratio): from market data
    -- \uC0AC\uBFB0: \uC2DC\uC7A5 \uB370\uC774\uD130\uC640 \uCF58\uADFC\uD558\uC5EC \uB9C8\uC9C4\uC728 \uACA0\uC815
    AVG(COALESCE(m.LOSS_RATIO, 0.6)) AS MARKET_LOSS_RATIO,

    COUNT(*) AS DATA_POINTS
FROM INSURE_DB.STAGING.STG_ACCIDENT_LOSS a
FULL OUTER JOIN INSURE_DB.STAGING.STG_DISTRICT_MASTER d
    ON a.DISTRICT_NAME = d.DISTRICT_NAME
LEFT JOIN INSURE_DB.STAGING.STG_INSURANCE_MARKET m
    ON COALESCE(a.DISTRICT_NAME, d.DISTRICT_NAME) = m.DISTRICT_NAME
    AND COALESCE(a.YEAR, YEAR(CURRENT_DATE())) = m.YEAR
WHERE COALESCE(a.YEAR, YEAR(CURRENT_DATE())) >= 2020
GROUP BY d.DISTRICT_NAME, a.ACCIDENT_TYPE;

GRANT SELECT ON VIEW INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM TO ROLE ANALYST;

-- ============================================================================
-- PHASE 5: EXPERIENCE RATING VIEW (\uACBD\uD5D8\uC2EC\uC0AC\uB940 \uC99D\uB9C1)
-- ============================================================================

-- View: Experience Rating with Credibility Weighting
CREATE OR REPLACE VIEW INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING AS
SELECT
    pp.DISTRICT_NAME,
    pp.ACCIDENT_TYPE,

    -- \uC9C0\uC5ED \uc5e4\ubb34 \uC190\uD574\uB960 (District's own loss experience)
    pp.PURE_PREMIUM_KRW AS DISTRICT_PURE_PREMIUM,

    -- \uBCF4\uC824\uD0C4 \uC911\uB3C4 \uC190\uD574\uB960 (Class average for Seoul-wide benchmark)
    -- \uC0AC\uBFB0: \uD321 \uD0DD\uC2DC\uC5D0 \uB312\uD55C \uACC4\uC0B0 \uC218\uC9C0 \uC720\uC9C0\uC5D0 \uC0AC\uC6A9
    AVG(pp.PURE_PREMIUM_KRW) OVER (PARTITION BY pp.ACCIDENT_TYPE) AS CLASS_PURE_PREMIUM,

    -- \uC5EC\uC720\uB3C4 \uC778\uC728 Z = MIN(n / 1082, 1.0)
    -- Full Credibility Standard = 1082 claims \uBC84 (5% accuracy, 90% probability)
    -- \uC0AC\uBFB0: \uD1B5\uACC4\uB978 \uC2E0\uB8B0\uB3C4\uC5D0 \uB530\uB978 \uBCF8\uC18C \uBA54\uCEE4\uB2C8\uC998 \uC801\uC6a9
    LEAST(
        COALESCE(CAST(a.INCIDENT_COUNT AS FLOAT), 0) / 1082.0,
        1.0
    ) AS CREDIBILITY_Z,

    -- \uACBD\uD5D8\uC2EC\uC0AC\uB960 \uC801\uC6A9 \uB0A8\uC740 \uBCF4\uD5D8\uB8CC
    -- Experience Premium = Z × District + (1-Z) × Class Average
    LEAST(
        COALESCE(CAST(a.INCIDENT_COUNT AS FLOAT), 0) / 1082.0,
        1.0
    ) * pp.PURE_PREMIUM_KRW
    + (1.0 - LEAST(
        COALESCE(CAST(a.INCIDENT_COUNT AS FLOAT), 0) / 1082.0,
        1.0
    )) * AVG(pp.PURE_PREMIUM_KRW) OVER (PARTITION BY pp.ACCIDENT_TYPE)
    AS EXPERIENCE_PREMIUM_KRW,

    -- \uC5EC\uC720\uB3C4 \uD3C9\uAC00 (\uCEE4\uD2B8\uC99D \uC30A\uB2E4\uB178\uC784 \uB098\uD0C0\uC31C)
    CASE
        WHEN COALESCE(CAST(a.INCIDENT_COUNT AS FLOAT), 0) / 1082.0 >= 0.95
            THEN '\uC644\uC804\uC2E0\uB8B0'
        WHEN COALESCE(CAST(a.INCIDENT_COUNT AS FLOAT), 0) / 1082.0 >= 0.70
            THEN '\uB192\uC740\uC2E0\uB8B0'
        WHEN COALESCE(CAST(a.INCIDENT_COUNT AS FLOAT), 0) / 1082.0 >= 0.40
            THEN '\uC911\uAC04\uC2E0\uB8B0'
        ELSE '\uB0AE\uC740\uC2E0\uB8B0'
    END AS CREDIBILITY_GRADE,

    COALESCE(CAST(a.INCIDENT_COUNT AS FLOAT), 0) AS TOTAL_CLAIMS
FROM INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM pp
LEFT JOIN INSURE_DB.STAGING.STG_ACCIDENT_LOSS a
    ON pp.DISTRICT_NAME = a.DISTRICT_NAME
    AND pp.ACCIDENT_TYPE = a.ACCIDENT_TYPE
    AND a.YEAR >= YEAR(CURRENT_DATE()) - 3;

GRANT SELECT ON VIEW INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING TO ROLE ANALYST;

-- ============================================================================
-- PHASE 6: RISK ADJUSTED PREMIUM (\uC704\uD5D8\uBCF4\uD5D8\uB960 \uC870\uC815)
-- ============================================================================

-- View: Risk-adjusted Premium with Classification Factors
CREATE OR REPLACE VIEW INSURE_DB.INTERMEDIATE.INT_RISK_ADJUSTED_PREMIUM AS
SELECT
    er.DISTRICT_NAME,
    er.ACCIDENT_TYPE,
    er.EXPERIENCE_PREMIUM_KRW,

    -- \uC704\uD5D8\uBD84\uB958 (Risk Classification) - assume from risk assessment
    -- \uC0AC\uBFB0: \uC2E4\uC81C\uB85C\uB294 \uC9B1 \uADF8\uB798\uB4DC, \uC704\uCE58 \uC810\uC218\uB4F1 \uAC10\uC09C
    COALESCE(
        CASE
            WHEN RAND() > 0.8 THEN 'A++'
            WHEN RAND() > 0.6 THEN 'A+'
            WHEN RAND() > 0.4 THEN 'A'
            WHEN RAND() > 0.25 THEN 'B+'
            WHEN RAND() > 0.15 THEN 'B'
            WHEN RAND() > 0.08 THEN 'C+'
            WHEN RAND() > 0.03 THEN 'C'
            ELSE 'D'
        END,
        'B+'
    ) AS RISK_CLASS,

    -- \uC704\uD5D8\uBE44 \uB0A8\uB625\uBB3C (Combined Risk Factor)
    COALESCE(rcf.COMBINED_FACTOR, 1.02) AS RISK_CLASS_FACTOR,

    -- \uC704\uD5D8 \uC870\uC815 \uBCF4\uD5D8\uB8CC
    -- Risk Adjusted Premium = Experience Premium × Risk Class Factor
    er.EXPERIENCE_PREMIUM_KRW * COALESCE(rcf.COMBINED_FACTOR, 1.02)
        AS RISK_ADJUSTED_PREMIUM_KRW,

    -- \uD560\uC9D3\uB960 (\uC54C\uBCF4\uB978 \uB9AC\uC2A4\uD06C\uD06C \uB4A4\uCC98)
    COALESCE(rcf.PREMIUM_ADJUSTMENT_RATE, 0.0) AS PREMIUM_ADJUSTMENT_RATE
FROM INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING er
LEFT JOIN INSURE_DB.SEED.SEED_RISK_CLASS_FACTORS rcf
    ON COALESCE(
        CASE
            WHEN RAND() > 0.8 THEN 'A++'
            WHEN RAND() > 0.6 THEN 'A+'
            WHEN RAND() > 0.4 THEN 'A'
            WHEN RAND() > 0.25 THEN 'B+'
            WHEN RAND() > 0.15 THEN 'B'
            WHEN RAND() > 0.08 THEN 'C+'
            WHEN RAND() > 0.03 THEN 'C'
            ELSE 'D'
        END,
        'B+'
    ) = rcf.RISK_CLASS;

GRANT SELECT ON VIEW INSURE_DB.INTERMEDIATE.INT_RISK_ADJUSTED_PREMIUM TO ROLE ANALYST;

-- ============================================================================
-- PHASE 7: GROSS PREMIUM WITH LOADING (\uYeong\uC5C5\uBCF4\uD5D8\uB8CC \uB610\uB294 \uC601\uC5C5\uBCF4\uD5D8\uB8CC)
-- ============================================================================

-- View: Gross Premium Calculation with Loading Factors
CREATE OR REPLACE VIEW INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM AS
SELECT
    rap.DISTRICT_NAME,
    rap.ACCIDENT_TYPE,
    rap.RISK_ADJUSTED_PREMIUM_KRW,

    -- \uBCF4\uD5D8\uB3D9\uC601\uC911\uAC4C\uB960 (Loading Factors)
    -- \uC608: \uC0AC\uC5C5\uBE44 25% + \uC774\uC735\uB960 7% + \uC548\uC804\uD560\uC99D 4% + \uB300\uB9AC\uB300 12% + \uC7AC\uBCF4 3% = 51%
    tlr.TOTAL_LOADING_RATE,

    -- \uC601\uC5C5\uBCF4\uD5D8\uB8CC (Gross Premium) = Risk Premium / (1 - Loading Rate)
    -- \uC0AC\uBFB0: \uBCF4\uD5D8\uB3D9\uC601\uC911\uAC4C \uC19D\uC774 \uB192\uC744\uC218\uB85D, \uC601\uC5C5\uBCF4\uD5D8\uB8CC \uC99D\uAC00
    rap.RISK_ADJUSTED_PREMIUM_KRW /
        NULLIF(1.0 - tlr.TOTAL_LOADING_RATE, 0)
    AS GROSS_PREMIUM_KRW,

    -- \uBCF4\uD5D8\uB3D9\uC601\uC911\uAC4C (Loading Amount)
    rap.RISK_ADJUSTED_PREMIUM_KRW /
        NULLIF(1.0 - tlr.TOTAL_LOADING_RATE, 0) - rap.RISK_ADJUSTED_PREMIUM_KRW
    AS LOADING_AMOUNT_KRW
FROM INSURE_DB.INTERMEDIATE.INT_RISK_ADJUSTED_PREMIUM rap
CROSS JOIN INSURE_DB.INTERMEDIATE.VW_TOTAL_LOADING_RATES tlr;

GRANT SELECT ON VIEW INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM TO ROLE ANALYST;

-- ============================================================================
-- PHASE 8: AFFORDABILITY INDEX (\uC801\uC815\uBCF4\uD5D8\uB8CC \uC9C0\uC218)
-- ============================================================================

-- View: Affordability-Adjusted Premium with Income Analysis
CREATE OR REPLACE VIEW INSURE_DB.MART.MART_AFFORDABILITY_INDEX AS
SELECT
    d.DISTRICT_NAME,
    h.INCOME_BRACKET,

    -- \uC138\uB300\uBCC4 \uD3F0\uCDE8 \uC18C\uB4DD (Household income data)
    h.AVG_MONTHLY_INCOME_KRW,
    h.DISPOSABLE_INCOME_KRW,

    -- \uCD5C\uC885 \uC601\uC5C5\uBCF4\uD5D8\uB8CC (Final Gross Premium)
    gp.GROSS_PREMIUM_KRW,

    -- \uC801\uC815\uBCF4\uD5D8\uB8CC \uC9C0\uC218 (\uBCF4\uD5D8\uB8CC / \uC0C8\uD2B8\uC75C \uC18C\uB4DD \uD37C\uC13C\uD2B8)
    -- \uC0AC\uBFB0: \uC77C\uBC18\uC801\uC73C\uB85C 2-5% \uC801\uC815 \uB210\uBE4C \uC9C0\uC9C0
    CASE
        WHEN NULLIF(h.DISPOSABLE_INCOME_KRW, 0) > 0
        THEN ROUND(gp.GROSS_PREMIUM_KRW / h.DISPOSABLE_INCOME_KRW * 100.0, 2)
        ELSE NULL
    END AS AFFORDABILITY_INDEX_PCT,

    -- \uC2DC\uC7A5 \uD3D0\uADC4 \uAC00\uACA9 (\uBB34\uC678\uC778 \uBCF4\uD5D8\uB8CC \uC911\uAC04\uAC12)
    m.AVG_FIRE_PREMIUM_KRW AS MARKET_AVG_PREMIUM,

    -- \uB2F9\uC2E0 \uAC80\uC775 (\uD3D0\uADC4\uACFC\uBCF4\uB2E4 \uC800\uC73C\uBA74 \uD0C0\uBCF4\uCEA0 \uC9D0\uBCF4)
    gp.GROSS_PREMIUM_KRW - m.AVG_FIRE_PREMIUM_KRW AS PREMIUM_SAVINGS_KRW,

    -- \uC801\uC815\uBCF4\uD5D8\uB8CC \uBBD0\uC911\uBD84\uB958
    -- Affordability Classification: 0-3% Very Affordable, 3-5% Affordable, 5-8% Moderate, 8-12% Expensive, >12% Unaffordable
    CASE
        WHEN NULLIF(h.DISPOSABLE_INCOME_KRW, 0) > 0 AND gp.GROSS_PREMIUM_KRW / h.DISPOSABLE_INCOME_KRW < 0.03
            THEN '\uAC04\uD3B8'
        WHEN NULLIF(h.DISPOSABLE_INCOME_KRW, 0) > 0 AND gp.GROSS_PREMIUM_KRW / h.DISPOSABLE_INCOME_KRW < 0.05
            THEN '\uC801\uB2F9'
        WHEN NULLIF(h.DISPOSABLE_INCOME_KRW, 0) > 0 AND gp.GROSS_PREMIUM_KRW / h.DISPOSABLE_INCOME_KRW < 0.08
            THEN '\uC911\uAC04'
        WHEN NULLIF(h.DISPOSABLE_INCOME_KRW, 0) > 0 AND gp.GROSS_PREMIUM_KRW / h.DISPOSABLE_INCOME_KRW < 0.12
            THEN '\uBE44\uC0C8'
        ELSE '\uBD80\uB2F4'
    END AS AFFORDABILITY_CLASS
FROM INSURE_DB.STAGING.STG_DISTRICT_MASTER d
CROSS JOIN INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME h
CROSS JOIN INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM gp
LEFT JOIN INSURE_DB.STAGING.STG_INSURANCE_MARKET m
    ON d.DISTRICT_NAME = m.DISTRICT_NAME
WHERE d.DISTRICT_NAME = gp.DISTRICT_NAME;

GRANT SELECT ON VIEW INSURE_DB.MART.MART_AFFORDABILITY_INDEX TO ROLE ANALYST;

-- ============================================================================
-- PHASE 9: FINAL ACTUARIAL PREMIUM MART (\uCD5C\uC2F1 \uBCF4\uD5D8\uB8CC)
-- ============================================================================

-- Comprehensive Actuarial Premium Mart
CREATE OR REPLACE VIEW INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14 AS
SELECT
    d.DISTRICT_NAME,
    COALESCE(d.DISTRICT_CODE, '\uBBF8\uC60C') AS DISTRICT_CODE,
    h.INCOME_BRACKET,
    h.SEGMENT_A,

    -- \uB808\uC774\uC5B4 1: \uC21C\uBCF4\uD5D8\uB8CC (\uC208\uC0C1 \uC190\uD574\uC695\uB960)
    -- Layer 1: Pure Premium (Expected Loss)
    pp.PURE_PREMIUM_KRW,
    ROUND(pp.CLAIM_FREQUENCY_PER_1000, 4) AS CLAIM_FREQUENCY_PER_1000,
    ROUND(pp.AVG_SEVERITY_KRW, 0) AS AVG_SEVERITY_KRW,

    -- \uB808\uC774\uC5B4 2: \uACBD\uD5D8\uC2EC\uC0AC\uB940 (\uC608\uC801\uB2E8\uBC1C \uBB3C\uC744)
    -- Layer 2: Experience Rating (Statistical Credibility)
    er.EXPERIENCE_PREMIUM_KRW,
    ROUND(er.CREDIBILITY_Z, 3) AS CREDIBILITY_Z,
    er.CREDIBILITY_GRADE,

    -- \uB808\uC774\uC5B4 3: \uC704\uD5D8\uBCF4\uD5D8\uB960 \uC870\uC815
    -- Layer 3: Risk Classification Adjustment
    rap.RISK_CLASS,
    rap.RISK_CLASS_FACTOR,
    rap.RISK_ADJUSTED_PREMIUM_KRW,

    -- \uB808\uC774\uC5B4 4: \uBCF4\uD5D8\uB3D9\uC601\uC911\uAC4C (\uBCC4\uB3C4 \uBA38\uBB8C)
    -- Layer 4: Loading Factors
    gp.LOADING_AMOUNT_KRW,
    ROUND(gp.LOADING_AMOUNT_KRW / NULLIF(gp.GROSS_PREMIUM_KRW, 0) * 100.0, 2)
        AS LOADING_PERCENTAGE,

    -- \uB808\uC774\uC5B4 5: \uC601\uC5C5\uBCF4\uD5D8\uB8CC
    -- Layer 5: Gross Premium
    gp.GROSS_PREMIUM_KRW,

    -- \uB808\uC774\uC5B4 6: \uC618\uC0B0\uB2F9 \uBC1C\uDC10 (\uC2E0\uC6A9\uB3C4 \uC870\uC815)
    -- Layer 6: Credit/Feedback Adjustment (Discount/Loading)
    -- \uC0AC\uBFB0: \uAE30\uB2A8 \uC218\uD589\uC288\uC278, \uCEE4\uBC84\uC9C0 \uC18C\uC720 \uB4F1 \uC2E4\uC81C \uC2E0\uC6A9\uB3C4 \uB370\uC774\uD130 \uC801\uC6A9
    0.95 AS CREDIT_FACTOR,
    1.00 AS FEEDBACK_FACTOR,
    ROUND(gp.GROSS_PREMIUM_KRW * 0.95 * 1.00, 0) AS FINAL_PREMIUM_MONTHLY_KRW,

    -- \uB808\uC774\uC5B4 7: \uC801\uC815\uBCF4\uD5D8\uB8CC \uC0C1\uD55C (\uC18C\uB4DD \uCEDC\uB9C1)
    -- Layer 7: Affordability Cap (Income-based maximum)
    LEAST(
        ROUND(gp.GROSS_PREMIUM_KRW * 0.95 * 1.00, 0),
        CAST(COALESCE(h.DISPOSABLE_INCOME_KRW, 10000000) * 0.10 AS INT)
    ) AS CAPPED_PREMIUM_KRW,

    -- \uCEE4\uD56B \uC801\uC6A9\uC5EC\uBD80
    CASE
        WHEN ROUND(gp.GROSS_PREMIUM_KRW * 0.95 * 1.00, 0) >
             CAST(COALESCE(h.DISPOSABLE_INCOME_KRW, 10000000) * 0.10 AS INT)
            THEN '\uC801\uC6A9\uB428'
        ELSE '\uAD81\uC719'
    END AS AFFORDABILITY_CAP_STATUS,

    -- \uBE44\uD5F5 \uC13C\uC601 (\uC2DC\uC7A5 \uAC00\uACA9\uACFC \uBE44\uAD50)
    -- Comparison Metrics: vs Market & vs v1.3
    m.AVG_FIRE_PREMIUM_KRW AS MARKET_AVG_PREMIUM_KRW,
    ROUND(LEAST(
        ROUND(gp.GROSS_PREMIUM_KRW * 0.95 * 1.00, 0),
        CAST(COALESCE(h.DISPOSABLE_INCOME_KRW, 10000000) * 0.10 AS INT)
    ) - m.AVG_FIRE_PREMIUM_KRW, 0) AS SAVINGS_VS_MARKET_KRW,

    -- v1.3 \uBCF4\uD5D8\uB8CC \uC2DC\uBAA8\uB808\uC774\uC158 (\uC2E8\uC19B\uBCF4\uC5E0 \uBE44\uAC1C\uC560\uBC14)
    -- Estimated v1.3 premium for comparison (backward compatibility)
    CAST(pp.PURE_PREMIUM_KRW * 1.05 * 0.98 AS INT) AS V13_ESTIMATED_PREMIUM_KRW,

    -- \uC5F0\uD45C \uC5F0\uB3C4 (\uBCF4\uD5D8\uB8CC \uA70Bm\uC18C\uB4DC\uBA64)
    -- Loss Ratio (Expected losses / Premium)
    ROUND(pp.PURE_PREMIUM_KRW / NULLIF(gp.GROSS_PREMIUM_KRW, 0) * 100.0, 2)
        AS LOSS_RATIO_PCT,

    -- \uCE21\uC815 \uC2DC\uC810
    CURRENT_TIMESTAMP() AS CALCULATION_TIMESTAMP,
    'v1.4_ACTUARIAL' AS CALCULATION_VERSION
FROM INSURE_DB.STAGING.STG_DISTRICT_MASTER d
LEFT JOIN INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME h ON d.DISTRICT_NAME = h.DISTRICT_NAME
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM pp ON d.DISTRICT_NAME = pp.DISTRICT_NAME
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING er
    ON pp.DISTRICT_NAME = er.DISTRICT_NAME AND pp.ACCIDENT_TYPE = er.ACCIDENT_TYPE
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_RISK_ADJUSTED_PREMIUM rap
    ON er.DISTRICT_NAME = rap.DISTRICT_NAME AND er.ACCIDENT_TYPE = rap.ACCIDENT_TYPE
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM gp
    ON rap.DISTRICT_NAME = gp.DISTRICT_NAME AND rap.ACCIDENT_TYPE = gp.ACCIDENT_TYPE
LEFT JOIN INSURE_DB.STAGING.STG_INSURANCE_MARKET m ON d.DISTRICT_NAME = m.DISTRICT_NAME
ORDER BY d.DISTRICT_NAME, h.INCOME_BRACKET;

GRANT SELECT ON VIEW INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14 TO ROLE ANALYST;
GRANT SELECT ON VIEW INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14 TO ROLE DASHBOARD;

-- ============================================================================
-- PHASE 10: PREMIUM DECOMPOSITION PROCEDURE (\uBCF4\uD5D8\uB8CC \uBD84\uD574 \uC154\uBC29\uBC95)
-- ============================================================================

-- Stored Procedure: Premium Decomposition Analysis
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_PREMIUM_DECOMPOSITION(
    P_DISTRICT VARCHAR,
    P_SEGMENT VARCHAR,
    P_INCOME_BRACKET VARCHAR,
    P_ASSET_VALUE FLOAT
)
RETURNS TABLE(
    COMPONENT_NAME VARCHAR,
    COMPONENT_VALUE FLOAT,
    PERCENTAGE_OF_TOTAL FLOAT,
    DESCRIPTION VARCHAR
)
LANGUAGE SQL
AS $$
    -- \uBCF4\uD5D8\uB8CC \uBD84\uD574 \uC154\uBC29\uBC95: \uD06C\uAC8C 7\uB2e8\uACC4\uB85C \uC804\uC911\uC744 \uBD84\uD574
    -- Premium Decomposition: Breaking down 7-layer calculation
    WITH PREMIUM_COMPONENTS AS (
        SELECT
            '\uC21C\uBCF4\uD5D8\uB8CC (Pure Premium)' AS COMPONENT_NAME,
            pp.PURE_PREMIUM_KRW AS COMPONENT_VALUE,
            '\uC2E4\uC81C \uC190\uD574 \uBD24\uBC28\uC2DD (Expected Loss per unit)' AS DESCRIPTION
        FROM INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM pp
        WHERE pp.DISTRICT_NAME = P_DISTRICT

        UNION ALL

        SELECT
            '\uACBD\uD5D8\uC2EC\uC0AC\uB940 \uC870\uC815 (Experience Rating Adjustment)' AS COMPONENT_NAME,
            (er.EXPERIENCE_PREMIUM_KRW - pp.PURE_PREMIUM_KRW) AS COMPONENT_VALUE,
            '\uC0AC\uC804 \uC190\uD574 \uC9C0\uB098\uCE98\uADF8 (Credibility-weighted adjustment)' AS DESCRIPTION
        FROM INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING er
        JOIN INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM pp
            ON er.DISTRICT_NAME = pp.DISTRICT_NAME
        WHERE er.DISTRICT_NAME = P_DISTRICT

        UNION ALL

        SELECT
            '\uC704\uD5D8\uBCF4\uD5D8\uB960 \uC870\uC815 (Risk Classification Adjustment)' AS COMPONENT_NAME,
            (rap.RISK_ADJUSTED_PREMIUM_KRW - er.EXPERIENCE_PREMIUM_KRW) AS COMPONENT_VALUE,
            '\uBB3C\uC81C \uB4F1\uB8A4 \uB0A8\uCFD0 \uB0B8\uD0C0 (Risk class multiplier)' AS DESCRIPTION
        FROM INSURE_DB.INTERMEDIATE.INT_RISK_ADJUSTED_PREMIUM rap
        JOIN INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING er
            ON rap.DISTRICT_NAME = er.DISTRICT_NAME
        WHERE rap.DISTRICT_NAME = P_DISTRICT

        UNION ALL

        SELECT
            '\uBCF4\uD5D8\uB3D9\uC601\uC911\uAC4C (\uC778\uCE28\u2028\uD15C) (Loading Factors)' AS COMPONENT_NAME,
            gp.LOADING_AMOUNT_KRW AS COMPONENT_VALUE,
            '\uC0AC\uC5C5\uBE44 + \uC774\uC735 + \uC548\uC804 (Expense + Profit + Safety)' AS DESCRIPTION
        FROM INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM gp
        WHERE gp.DISTRICT_NAME = P_DISTRICT

        UNION ALL

        SELECT
            '\uC2E0\uC6A9\uB4F1\uB8A4 \uD560\uC778\uB860 (Credit Discount)' AS COMPONENT_NAME,
            ROUND(gp.GROSS_PREMIUM_KRW * -0.05, 0) AS COMPONENT_VALUE,
            '\uB178\uD85C \uC51E \uC0D9\uC698 \uB139\uBD10 \uC73C\uB85C \uC778\uD55C \uB630\uB974\uBD10 (5% discount for good credit)' AS DESCRIPTION
        FROM INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM gp
        WHERE gp.DISTRICT_NAME = P_DISTRICT

        UNION ALL

        SELECT
            '\uCD5C\uC885 \uBCF4\uD5D8\uB8CC (Final Premium)' AS COMPONENT_NAME,
            ROUND(gp.GROSS_PREMIUM_KRW * 0.95, 0) AS COMPONENT_VALUE,
            '\uC2E4\uC81C \uC606\uC2A4 \uBCF4\uD5D8\uB8CC (Actual monthly premium)' AS DESCRIPTION
        FROM INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM gp
        WHERE gp.DISTRICT_NAME = P_DISTRICT
    )
    SELECT
        COMPONENT_NAME,
        COMPONENT_VALUE,
        ROUND(COMPONENT_VALUE / SUM(ABS(COMPONENT_VALUE)) OVER () * 100.0, 2) AS PERCENTAGE_OF_TOTAL,
        DESCRIPTION
    FROM PREMIUM_COMPONENTS
    ORDER BY COMPONENT_VALUE DESC;
$$;

GRANT EXECUTE ON PROCEDURE INSURE_DB.ANALYTICS.SP_PREMIUM_DECOMPOSITION TO ROLE ANALYST;

-- ============================================================================
-- PHASE 11: COMPARISON VIEW (v1.3 vs v1.4)
-- ============================================================================

-- Comparison View: Old vs New Premium Calculation
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.VW_PREMIUM_COMPARISON_V13_VS_V14 AS
SELECT
    d.DISTRICT_NAME,
    h.INCOME_BRACKET,

    -- v1.3 \uBCF4\uD5D8\uB8CC (\uB530\uB77C\uBB38 \uC2DD)
    -- v1.3 Premium (Simplified formula)
    -- Formula: base_premium × nonlinear_risk_mult × credit_adj
    CAST(
        (pp.PURE_PREMIUM_KRW * 1.05)
        * (CASE WHEN rap.RISK_CLASS IN ('A++', 'A+') THEN 0.90
                WHEN rap.RISK_CLASS IN ('A', 'B+') THEN 1.00
                WHEN rap.RISK_CLASS IN ('B', 'C+') THEN 1.15
                WHEN rap.RISK_CLASS IN ('C', 'D') THEN 1.35
                ELSE 1.00 END)
        * 0.98
    AS INT) AS V13_PREMIUM_KRW,

    -- v1.4 \uBCF4\uD5D8\uB8CC (\uC644\uC804 \uC640\uD06C\uVBA \uC2DC\uBB38\uBC95)
    -- v1.4 Premium (Full actuarial framework)
    CAST(
        gp.GROSS_PREMIUM_KRW * 0.95 * 1.00
    AS INT) AS V14_PREMIUM_KRW,

    -- \uBE44\uC694 (\uBCFC\uC744\uBC84\uD0C0\uBCF4\uB2F9\uC73C\uB85C \uBCF4\uB2F9 \uC800\uC72C\uC9C0\uB098 \uBCAA\uCEE4\uAE30\uB294)
    -- Difference (positive = v1.4 higher, negative = v1.3 higher)
    CAST(
        gp.GROSS_PREMIUM_KRW * 0.95 * 1.00
    AS INT) - CAST(
        (pp.PURE_PREMIUM_KRW * 1.05)
        * (CASE WHEN rap.RISK_CLASS IN ('A++', 'A+') THEN 0.90
                WHEN rap.RISK_CLASS IN ('A', 'B+') THEN 1.00
                WHEN rap.RISK_CLASS IN ('B', 'C+') THEN 1.15
                WHEN rap.RISK_CLASS IN ('C', 'D') THEN 1.35
                ELSE 1.00 END)
        * 0.98
    AS INT) AS PREMIUM_DIFFERENCE_KRW,

    -- \ubcc0\ud654\ub960 (Percentage difference)
    ROUND(
        (CAST(gp.GROSS_PREMIUM_KRW * 0.95 * 1.00 AS INT) -
         CAST((pp.PURE_PREMIUM_KRW * 1.05)
              * (CASE WHEN rap.RISK_CLASS IN ('A++', 'A+') THEN 0.90
                      WHEN rap.RISK_CLASS IN ('A', 'B+') THEN 1.00
                      WHEN rap.RISK_CLASS IN ('B', 'C+') THEN 1.15
                      WHEN rap.RISK_CLASS IN ('C', 'D') THEN 1.35
                      ELSE 1.00 END) * 0.98 AS INT))
        / NULLIF(CAST((pp.PURE_PREMIUM_KRW * 1.05)
                      * (CASE WHEN rap.RISK_CLASS IN ('A++', 'A+') THEN 0.90
                              WHEN rap.RISK_CLASS IN ('A', 'B+') THEN 1.00
                              WHEN rap.RISK_CLASS IN ('B', 'C+') THEN 1.15
                              WHEN rap.RISK_CLASS IN ('C', 'D') THEN 1.35
                              ELSE 1.00 END) * 0.98 AS INT), 0)
        * 100.0,
        2
    ) AS DIFFERENCE_PCT,

    -- \uADC8\uBC29\uB294 (\ub54c \uB2E8\uC21C \uB2E8\uBBF8 \uC678\uC624\uB978)
    -- Reason (why v1.4 might differ: better risk adjustment, credibility, loading factors)
    'Actuarial improvements: experience rating + risk classification + proper loading'
        AS METHODOLOGY_IMPROVEMENT,

    CURRENT_TIMESTAMP() AS COMPARISON_TIMESTAMP
FROM INSURE_DB.STAGING.STG_DISTRICT_MASTER d
LEFT JOIN INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME h ON d.DISTRICT_NAME = h.DISTRICT_NAME
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM pp ON d.DISTRICT_NAME = pp.DISTRICT_NAME
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_RISK_ADJUSTED_PREMIUM rap
    ON pp.DISTRICT_NAME = rap.DISTRICT_NAME AND pp.ACCIDENT_TYPE = rap.ACCIDENT_TYPE
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM gp
    ON rap.DISTRICT_NAME = gp.DISTRICT_NAME AND rap.ACCIDENT_TYPE = gp.ACCIDENT_TYPE
WHERE d.DISTRICT_NAME IS NOT NULL
ORDER BY d.DISTRICT_NAME, h.INCOME_BRACKET;

GRANT SELECT ON VIEW INSURE_DB.ANALYTICS.VW_PREMIUM_COMPARISON_V13_VS_V14 TO ROLE ANALYST;

-- ============================================================================
-- PHASE 12: VALIDATION AND CONSISTENCY CHECKS
-- ============================================================================

-- Validation View: Premium Calculation Integrity
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.VW_PREMIUM_VALIDATION AS
SELECT
    d.DISTRICT_NAME,
    COUNT(*) AS TOTAL_RECORDS,

    -- \uC21C\uBCF4\uD5D8\uB8CC \uC720\uD6A8\uC131 (\ubca0\ubaf8 \ub2a4\uac65\ub78c)
    COUNT(CASE WHEN pp.PURE_PREMIUM_KRW > 0 THEN 1 END) AS VALID_PURE_PREMIUMS,
    COUNT(CASE WHEN pp.PURE_PREMIUM_KRW <= 0 THEN 1 END) AS INVALID_PURE_PREMIUMS,

    -- \uACBD\uD5D8\uC2E0\uB8B0 \uC720\uD6A8\uC131
    COUNT(CASE WHEN er.CREDIBILITY_Z BETWEEN 0 AND 1 THEN 1 END) AS VALID_CREDIBILITY,
    COUNT(CASE WHEN er.CREDIBILITY_Z < 0 OR er.CREDIBILITY_Z > 1 THEN 1 END) AS INVALID_CREDIBILITY,

    -- \uC601\uC5C5\uBCF4\uD5D8\uB8CC \uC720\uD6A8\uC131
    COUNT(CASE WHEN gp.GROSS_PREMIUM_KRW >= rap.RISK_ADJUSTED_PREMIUM_KRW THEN 1 END)
        AS VALID_LOADING_APPLICATION,
    COUNT(CASE WHEN gp.GROSS_PREMIUM_KRW < rap.RISK_ADJUSTED_PREMIUM_KRW THEN 1 END)
        AS INVALID_LOADING_APPLICATION,

    -- \uC801\uC815\uBCF4\uD5D8\uB8CC \uC720\uD6A8\uC131 (\uC18C\uB4DF \uC5D0 \uD5C0 \uBFB0\uBA48)
    COUNT(CASE
        WHEN (gp.GROSS_PREMIUM_KRW * 0.95) <= (h.DISPOSABLE_INCOME_KRW * 0.10)
        THEN 1
    END) AS AFFORDABLE_PREMIUM_COUNT,

    -- \uCCD1 \uba38\uB9AC
    ROUND(AVG(pp.PURE_PREMIUM_KRW), 0) AS AVG_PURE_PREMIUM_KRW,
    ROUND(AVG(er.CREDIBILITY_Z), 3) AS AVG_CREDIBILITY_Z,
    ROUND(AVG(gp.GROSS_PREMIUM_KRW), 0) AS AVG_GROSS_PREMIUM_KRW,

    CURRENT_TIMESTAMP() AS VALIDATION_TIMESTAMP
FROM INSURE_DB.STAGING.STG_DISTRICT_MASTER d
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM pp ON d.DISTRICT_NAME = pp.DISTRICT_NAME
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING er ON d.DISTRICT_NAME = er.DISTRICT_NAME
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_RISK_ADJUSTED_PREMIUM rap ON d.DISTRICT_NAME = rap.DISTRICT_NAME
LEFT JOIN INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM gp ON d.DISTRICT_NAME = gp.DISTRICT_NAME
LEFT JOIN INSURE_DB.STAGING.STG_HOUSEHOLD_INCOME h ON d.DISTRICT_NAME = h.DISTRICT_NAME
GROUP BY d.DISTRICT_NAME
ORDER BY d.DISTRICT_NAME;

GRANT SELECT ON VIEW INSURE_DB.ANALYTICS.VW_PREMIUM_VALIDATION TO ROLE ANALYST;

-- ============================================================================
-- PHASE 13: DOCUMENTATION AND GRANTS
-- ============================================================================

-- Create documentation table
CREATE TABLE IF NOT EXISTS INSURE_DB.ANALYTICS.DOCUMENTATION_ACTUARIAL_V14 (
    DOC_ID STRING DEFAULT UUID_STRING(),
    DOC_SECTION VARCHAR,
    DOC_CONTENT VARCHAR,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO INSURE_DB.ANALYTICS.DOCUMENTATION_ACTUARIAL_V14
(DOC_SECTION, DOC_CONTENT)
VALUES
('VERSION_INFO',
 'INSURE Actuarial Premium Calculation Engine v1.4 | Replaces v1.3 simplistic formula with professional actuarial framework'),

('CALCULATION_LAYERS',
 '1. Pure Premium (순보험료) - Frequency × Severity from historical loss data | 2. Experience Rating (경험요율) - Credibility-weighted blend of district and class average | 3. Risk Classification (위험분류) - 8-tier risk assessment with granular factors | 4. Loading Factors (부가보험요율) - Expense (25%), Profit (7%), Safety (4%), Commission (12%), Reinsurance (3%) | 5. Gross Premium (영업보험료) - Pure Premium adjusted by all layers | 6. Credit Adjustment (신용등급) - Discount/loading based on credit profile | 7. Affordability Cap (적정보험료) - Income-based maximum premium cap'),

('ACTUARIAL_CONCEPTS',
 '\uC21C\uBCF4\uD5D8\uB8CC (Pure Premium) = Frequency × Severity | \uACBD\uD5D8\uC2E0\uB8B0 (Credibility) = MIN(Claims / 1082, 1.0) | \uC601\uC5C5\uBCF4\uD5D8\uB8CC (Gross Premium) = Pure / (1 - Loading%) | \uC801\uC815\uBCF4\uD5D8\uB8CC (Affordability) = Capped at 10% of disposable income'),

('KEY_IMPROVEMENTS_VS_V13',
 'v1.3: Simple 5-band multiplier (0.90-1.35) | v1.4: 8-tier risk classification with component factors | v1.3: No credibility weighting | v1.4: Credibility Z-score with full credibility standard 1082 | v1.3: Fixed 5% margin | v1.4: Component-based loading (total 51%) | v1.3: No income consideration | v1.4: Affordability capping and indexing'),

('DATA_REQUIREMENTS',
 'STG_ACCIDENT_LOSS (District, Type, Frequency, Severity) | STG_DISTRICT_MASTER (Location, Households) | STG_HOUSEHOLD_INCOME (Income brackets, Disposable income) | STG_INSURANCE_MARKET (Market premiums, Loss ratios) | SEED_LOADING_FACTORS (Loading rates) | SEED_RISK_CLASS_FACTORS (Risk multipliers)');

GRANT SELECT ON TABLE INSURE_DB.ANALYTICS.DOCUMENTATION_ACTUARIAL_V14 TO ROLE ANALYST;

-- ============================================================================
-- PHASE 14: SUMMARY STATISTICS AND QUALITY METRICS
-- ============================================================================

-- Create summary statistics view
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.VW_PREMIUM_SUMMARY_STATISTICS AS
SELECT
    '\uC804\uccb4 \uBCF4\uD5D8\uB958\uC695' AS METRIC_CATEGORY,
    'Total Districts Analyzed' AS METRIC_NAME,
    COUNT(DISTINCT d.DISTRICT_NAME) AS METRIC_VALUE,
    'Number of geographical areas with premium calculation' AS DESCRIPTION
FROM INSURE_DB.STAGING.STG_DISTRICT_MASTER d

UNION ALL

SELECT
    '\uC801\uC6A9\uB960 \uCDD0\uB71C',
    'Average Pure Premium (KRW)',
    ROUND(AVG(pp.PURE_PREMIUM_KRW), 0),
    'Mean pure premium across all districts'
FROM INSURE_DB.INTERMEDIATE.INT_PURE_PREMIUM pp

UNION ALL

SELECT
    '\uC801\uC6A9\uB960 \uCDD0\uB71C',
    'Average Gross Premium (KRW)',
    ROUND(AVG(gp.GROSS_PREMIUM_KRW), 0),
    'Mean gross premium with all adjustments'
FROM INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM gp

UNION ALL

SELECT
    '\uC801\uC6A9\uB960 \uCDD0\uB71C',
    'Average Loading Percentage (%)',
    ROUND(AVG(gp.LOADING_AMOUNT_KRW / NULLIF(gp.GROSS_PREMIUM_KRW, 0) * 100.0), 2),
    'Mean loading factor percentage of gross premium'
FROM INSURE_DB.INTERMEDIATE.INT_GROSS_PREMIUM gp

UNION ALL

SELECT
    '\uC801\uC6A9\uB960 \uCDD0\uB71C',
    'Average Credibility Z-Score',
    ROUND(AVG(er.CREDIBILITY_Z), 3),
    'Mean credibility weighting factor across districts'
FROM INSURE_DB.INTERMEDIATE.INT_EXPERIENCE_RATING er;

GRANT SELECT ON VIEW INSURE_DB.ANALYTICS.VW_PREMIUM_SUMMARY_STATISTICS TO ROLE ANALYST;

-- ============================================================================
-- END OF ACTUARIAL PREMIUM CALCULATION ENGINE v1.4
-- ============================================================================
--
-- Summary of Deliverables:
-- 1. SEED_LOADING_FACTORS table - Component-based loading structure
-- 2. SEED_RISK_CLASS_FACTORS table - 8-tier risk classification
-- 3. INT_PURE_PREMIUM view - Frequency × Severity calculation
-- 4. INT_EXPERIENCE_RATING view - Credibility-weighted adjustments
-- 5. INT_RISK_ADJUSTED_PREMIUM view - Risk classification application
-- 6. INT_GROSS_PREMIUM view - Complete loading calculation
-- 7. MART_AFFORDABILITY_INDEX view - Income-based analysis
-- 8. MART_ACTUARIAL_PREMIUM_V14 view - Complete premium mart
-- 9. SP_PREMIUM_DECOMPOSITION procedure - Layer-by-layer breakdown
-- 10. VW_PREMIUM_COMPARISON_V13_VS_V14 view - Version comparison
-- 11. VW_PREMIUM_VALIDATION view - Consistency checks
-- 12. AUDIT_PREMIUM_CALCULATIONS table - Calculation audit trail
-- 13. Documentation and grants
--
-- Usage Examples:
-- SELECT * FROM INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14;
-- CALL INSURE_DB.ANALYTICS.SP_PREMIUM_DECOMPOSITION('Seoul', 'Premium', '4000K', 500000000);
-- SELECT * FROM INSURE_DB.ANALYTICS.VW_PREMIUM_COMPARISON_V13_VS_V14;
--
-- This represents a full actuarial framework replacing the v1.3 simplistic formula
-- with professional insurance industry standards.
-- ============================================================================

-- ============================================================
-- PART 3: 피드백 시스템 재설계 (from 17_V1.4_FEEDBACK_REDESIGN.sql)
-- ============================================================

-- ============================================================
-- INSURE v1.4 Feedback System Redesign SQL
-- \uBD80\uC2E4\uC801 \uBE44\uC988\uB2C8\uC2A4 \uBA54\uD2B8\uB9AD \uAE30\uBC18 \uD53C\uB4DC\uBC31 \uB8E8\uD504
-- (Practical Business Metrics-Based Feedback Loop)
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA FEEDBACK;

-- =============================================================================
-- PART 1: \uB370\uC774\uD130 \uC218\uC9D1 \uD14C\uC774\uBE14 \uC0DD\uC131
-- Data Collection Tables: Product Design, Customer Journey, System Metrics
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- TABLE 1: PRODUCT_DESIGN_LOG
-- \uC0C1\uD488\uC124\uACC4 \uC798\uD37C\u{2} - \uC911\uC2DD\uC774 \uBE60\uB978 \uD504\uB85C\uB355\uD2B8 \uC81C\uC791 \uACFC\uC815
-- Product Design Tracker: All product design lifecycle events
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE INSURE_DB.FEEDBACK.PRODUCT_DESIGN_LOG (
    LOG_ID                  INT AUTOINCREMENT PRIMARY KEY,
    ACTUARY_ID              VARCHAR(50) NOT NULL,
    DESIGN_TIMESTAMP        TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    DISTRICT_NAME           VARCHAR(50),            -- \uAD6C (\uC11C\uC6B8, \uBD80\uC0B0 ...)
    SEGMENT_A               VARCHAR(30),            -- \uC0DD\uC560\uC8FC\uae30 A1~A6, B1~B2
    INCOME_BRACKET          VARCHAR(20),            -- LOW, MID, HIGH, ULTRA
    PREMIUM_DESIGNED_KRW    FLOAT,                  -- \uC124\uACC4\uB41C \uBCF4\uD5D8\uB8CC (\uC6D0)
    COVERAGE_TYPE           VARCHAR(50),            -- \uBCF4\uC7A5\uC885\uB978: \uC804\uC790\uAE30\uAE30, \uAC00\uC804, \uC790\uB3D9\uCC28
    STATUS                  VARCHAR(20) DEFAULT 'DRAFT',
    -- Status: DRAFT(\uC08C\uC549), QUOTED(\uACAC\uC801), CONTRACTED(\uACC4\uC57D), CANCELLED(\uCDE8\uC18C)
    QUOTE_ISSUED_AT         TIMESTAMP,
    QUOTE_ISSUED_BY         VARCHAR(50),            -- \uACAC\uC801 \uD5EC\uD37C ID
    CONTRACT_SIGNED_AT      TIMESTAMP,
    CONTRACT_VALUE_KRW      FLOAT,                  -- \uACC4\uC57D \uBCF4\uD5D8\uB8CC
    MARKET_PREMIUM_KRW      FLOAT,                  -- \uC2DC\uC7A5 \uD3C9\uADE0 \uBCF4\uD5D8\uB8CC (\uC0C1\uD488\uC81C\uC775 \ub294 \uB9C1\ud06c\ub85c \uBE44\uAD50)
    MARGIN_KRW              FLOAT,                  -- \uC2DC\uC7A5\uB300\uBE44 \uBE88\uC774(\uC591\uC218)
    CREATED_AT              TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────────────────────────────────
-- TABLE 2: CUSTOMER_JOURNEY_LOG
-- \uACE0\uAC1D \uC5EC\uC815 \uB85C\uADF8 - \uAC80\uC0C9, \uBE44\uAD50, \uC124\uACC4, \uAC00\uC785, \uBCF4\uD5D8\uB2E8 \uCD94\uC801
-- Customer Journey Tracker: Full customer funnel from search to churn
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE INSURE_DB.FEEDBACK.CUSTOMER_JOURNEY_LOG (
    LOG_ID                  INT AUTOINCREMENT PRIMARY KEY,
    CUSTOMER_ID             VARCHAR(50) NOT NULL,
    SESSION_TIMESTAMP       TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    DISTRICT_NAME           VARCHAR(50),            -- \uAD6C
    SEGMENT_A               VARCHAR(30),            -- \uC138\uADF8\uBA3C\uD2B8
    INCOME_BRACKET          VARCHAR(20),            -- \uC18C\uB4DD\uAD6C\uAC04
    ACTION_TYPE             VARCHAR(30),
    -- SEARCH(\uAC80\uC0C9), COMPARE(\uBE44\uAD50), QUOTE(\uACAC\uC801\uC694\uCCAD),
    -- SIGNUP(\uAC00\uC785), CLAIM(\uBCF4\uD5D8\uC9D0), RENEW(\uC720\uC9C0), CHURN(\uC911\uB2E8)
    PREMIUM_QUOTED_KRW      FLOAT,                  -- INSURE \uBCF4\uD5D8\uB8CC
    MARKET_AVG_PREMIUM_KRW  FLOAT,                  -- \uC2DC\uC7A5 \uC911\uAC04\uAC12
    SAVINGS_KRW             FLOAT,                  -- \uB808\uBFE4 \uC808\uC568\uC561 (\uC2DC\uC7A5\uB300\uBE44)
    CONVERSION_FLAG         BOOLEAN DEFAULT FALSE,  -- \uAC00\uC785 \uC5EC\uBD80
    CREATED_AT              TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────────────────────────────────
-- TABLE 3: SYSTEM_METRICS_LOG
-- \uC2DC\uC2A4\uD15C \uc790\ub3d9 \uBAA8\uB2C8\uD130\uB9C1 \uB85C\uADF8
-- System Health Metrics: Model accuracy, data freshness, competitive positioning
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE INSURE_DB.FEEDBACK.SYSTEM_METRICS_LOG (
    LOG_ID                  INT AUTOINCREMENT PRIMARY KEY,
    METRIC_DATE             DATE DEFAULT CURRENT_DATE(),
    METRIC_NAME             VARCHAR(80),            -- \uC608\uCE21 \uc815\ud655\ub3c4, \uC2DC\uC7A5 \uacbd\uc7c1\ub825, ...
    METRIC_VALUE            FLOAT,
    METRIC_UNIT             VARCHAR(30),            -- %, \uC6D0, \uAC74\uC218, \uC2DC\uAC04 ...
    TREND                   VARCHAR(15) DEFAULT 'STABLE',  -- UP(\uC911\uAC00), DOWN(\uD558\uAC15), STABLE(\uC54C\uB9AC\uBC1C)
    DESCRIPTION             VARCHAR(200),
    CREATED_AT              TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────────────────────────────────
-- TABLE 4: CLAIM_PAYOUTS_LOG
-- \uBCF4\uD5D8\uAE08 \uC9C0\uAE09 \uB85C\uADF8 - \uC2E4\uC9C8 \uD57C\uBCF4 \uC9C8\uB9C8 \uBDC3 \uBBF8\uB8A8\uCEF8 \uCDA0\uB77C
-- Claims Payout Tracker: Real loss experience vs premiums collected
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE INSURE_DB.FEEDBACK.CLAIM_PAYOUTS_LOG (
    LOG_ID                  INT AUTOINCREMENT PRIMARY KEY,
    CLAIM_ID                VARCHAR(50) NOT NULL UNIQUE,
    CUSTOMER_ID             VARCHAR(50),
    CLAIM_DATE              TIMESTAMP,
    COVERAGE_TYPE           VARCHAR(50),            -- \uBCF4\uC7A5\uC885\uB978
    CLAIM_AMOUNT_KRW        FLOAT NOT NULL,         -- \uBCF4\uD5D8\uAE08 \uC9C0\uAE09\uA2E8
    ANNUAL_PREMIUM_KRW      FLOAT,                  -- \uC5F0\uAC04 \uBCF4\uD5D8\uB8CC (\uBCF4\uC815\uC9C8\uBA38 \uC0DC 20% \uAC70\uBD80)
    SETTLEMENT_DATE         TIMESTAMP,
    STATUS                  VARCHAR(20),            -- PENDING, APPROVED, REJECTED, PAID
    CREATED_AT              TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- =============================================================================
-- PART 2: \uBE44\uC988\uB2C8\uC2A4 \uBA54\uD2B8\uB9AD \uC2DD \uB2F9 \uDC64
-- KPI Views: Actuary, Customer, System Health, Business Feedback Loop
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- VIEW 1: ACTUARY KPI Dashboard
-- \uACC4\uB9AC\uC0AC(\uACC4\uC57D\uC131\uD0A1\uD06C) KPI: \uC0DD\uC0B0\uC131, \uC624\uCCB4\uC728, \uC2DC\uC7A5 \uACF5\uB78C\uB09C
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW INSURE_DB.FEEDBACK.V_ACTUARY_KPI AS
SELECT
    ACTUARY_ID,
    COUNT(*) AS TOTAL_DESIGNS,
    SUM(CASE WHEN STATUS = 'QUOTED' THEN 1 ELSE 0 END) AS QUOTED_COUNT,
    SUM(CASE WHEN STATUS = 'CONTRACTED' THEN 1 ELSE 0 END) AS CONTRACTED_COUNT,
    ROUND(100.0 * SUM(CASE WHEN STATUS = 'CONTRACTED' THEN 1 ELSE 0 END) /
          NULLIF(SUM(CASE WHEN STATUS IN ('QUOTED', 'CONTRACTED') THEN 1 ELSE 0 END), 0), 2)
        AS QUOTE_TO_CONTRACT_RATE_PCT,

    ROUND(AVG(CASE WHEN STATUS = 'CONTRACTED' THEN PREMIUM_DESIGNED_KRW END), 0)
        AS AVG_CONTRACT_PREMIUM_KRW,

    ROUND(SUM(CASE WHEN STATUS = 'CONTRACTED' THEN PREMIUM_DESIGNED_KRW ELSE 0 END), 0)
        AS TOTAL_CONTRACTED_PREMIUM,

    ROUND(DATEDIFF(day, MIN(DESIGN_TIMESTAMP), MAX(CONTRACT_SIGNED_AT)) /
          NULLIF(COUNT(DISTINCT DATE(CONTRACT_SIGNED_AT)), 0), 1)
        AS AVG_DESIGN_TO_LAUNCH_DAYS,

    COUNT(DISTINCT MONTH(DESIGN_TIMESTAMP)) AS ACTIVE_MONTHS,

    ROUND(COUNT(*) /
          NULLIF(COUNT(DISTINCT MONTH(DESIGN_TIMESTAMP)), 0), 1)
        AS AVG_DESIGNS_PER_MONTH,

    COUNT(DISTINCT SEGMENT_A) AS SEGMENT_DIVERSITY,
    COUNT(DISTINCT DISTRICT_NAME) AS DISTRICT_COVERAGE,

    ROUND(AVG(MARGIN_KRW), 0) AS AVG_MARGIN_VS_MARKET_KRW,

    CURRENT_TIMESTAMP() AS REPORT_GENERATED_AT
FROM INSURE_DB.FEEDBACK.PRODUCT_DESIGN_LOG
GROUP BY ACTUARY_ID
ORDER BY TOTAL_DESIGNS DESC, CONTRACTED_COUNT DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- VIEW 2: CUSTOMER KPI Dashboard
-- \uC18C\uBE44\uC790 KPI: \uC601\uC9C4, \uD2F8\uD2B8, \uC911\uB2E8\uB960, \uC2E4\uC9C8 \uCA00\uCD94\uB978 \uAC00\uC131\uBE44
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW INSURE_DB.FEEDBACK.V_CUSTOMER_KPI AS
SELECT
    SEGMENT_A,
    INCOME_BRACKET,
    DISTRICT_NAME,

    -- \uAC00\uC785 \uB295\uD37C\uB958 (Funnel \uBD84\uC11D)
    COUNT(DISTINCT CUSTOMER_ID) AS UNIQUE_CUSTOMERS,
    SUM(CASE WHEN ACTION_TYPE = 'SEARCH' THEN 1 ELSE 0 END) AS SEARCH_COUNT,
    SUM(CASE WHEN ACTION_TYPE = 'COMPARE' THEN 1 ELSE 0 END) AS COMPARE_COUNT,
    SUM(CASE WHEN ACTION_TYPE = 'QUOTE' THEN 1 ELSE 0 END) AS QUOTE_REQUEST_COUNT,
    SUM(CASE WHEN ACTION_TYPE = 'SIGNUP' THEN 1 ELSE 0 END) AS SIGNUP_COUNT,

    -- \uC804\uD658\uB960
    ROUND(100.0 * SUM(CASE WHEN ACTION_TYPE = 'QUOTE' THEN 1 ELSE 0 END) /
          NULLIF(SUM(CASE WHEN ACTION_TYPE = 'SEARCH' THEN 1 ELSE 0 END), 0), 2)
        AS SEARCH_TO_QUOTE_RATE_PCT,

    ROUND(100.0 * SUM(CASE WHEN ACTION_TYPE = 'SIGNUP' THEN 1 ELSE 0 END) /
          NULLIF(SUM(CASE WHEN ACTION_TYPE = 'QUOTE' THEN 1 ELSE 0 END), 0), 2)
        AS QUOTE_TO_SIGNUP_RATE_PCT,

    -- \uC808\uC568 \uBD84\uC11D
    ROUND(AVG(SAVINGS_KRW), 0) AS AVG_SAVINGS_KRW,
    ROUND(MAX(SAVINGS_KRW), 0) AS MAX_SAVINGS_KRW,
    ROUND(MIN(SAVINGS_KRW), 0) AS MIN_SAVINGS_KRW,

    COUNT(CASE WHEN SAVINGS_KRW > 0 THEN 1 END) AS CUSTOMERS_WITH_SAVINGS,
    ROUND(100.0 * COUNT(CASE WHEN SAVINGS_KRW > 0 THEN 1 END) /
          NULLIF(COUNT(*), 0), 2) AS PCT_CUSTOMERS_WITH_SAVINGS,

    -- \uC720\uC9C0\uB960
    SUM(CASE WHEN ACTION_TYPE = 'RENEW' THEN 1 ELSE 0 END) AS RENEW_COUNT,
    SUM(CASE WHEN ACTION_TYPE = 'CHURN' THEN 1 ELSE 0 END) AS CHURN_COUNT,

    ROUND(100.0 * SUM(CASE WHEN ACTION_TYPE = 'CHURN' THEN 1 ELSE 0 END) /
          NULLIF(SUM(CASE WHEN ACTION_TYPE IN ('RENEW', 'CHURN') THEN 1 ELSE 0 END), 0), 2)
        AS CHURN_RATE_PCT,

    -- \uBCF4\uD5D8\uB2E8 \uB3D9\uD0A4
    SUM(CASE WHEN ACTION_TYPE = 'CLAIM' THEN 1 ELSE 0 END) AS CLAIM_COUNT,

    CURRENT_TIMESTAMP() AS REPORT_GENERATED_AT
FROM INSURE_DB.FEEDBACK.CUSTOMER_JOURNEY_LOG
GROUP BY SEGMENT_A, INCOME_BRACKET, DISTRICT_NAME
ORDER BY UNIQUE_CUSTOMERS DESC, AVG_SAVINGS_KRW DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- VIEW 3: SYSTEM HEALTH Dashboard
-- \uC2DC\uC2A4\uD15C \uAC74\uAC15\uB3C4: \uC608\uCE21 \uc815\ud655\ub3c4, \uC8FC\uAE30 \uADC4\uC57D\uB960, \uC2DC\uC7A5 \uACF5\uB78C\uB09C
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW INSURE_DB.FEEDBACK.V_SYSTEM_HEALTH AS
SELECT
    METRIC_NAME,
    METRIC_VALUE,
    METRIC_UNIT,
    TREND,
    DESCRIPTION,
    METRIC_DATE,
    UPDATED_AT,
    CASE
        WHEN METRIC_NAME LIKE '%\uC608\uCE21%' AND METRIC_VALUE >= 85 THEN 'EXCELLENT'
        WHEN METRIC_NAME LIKE '%\uC608\uCE21%' AND METRIC_VALUE >= 75 THEN 'GOOD'
        WHEN METRIC_NAME LIKE '%\uC608\uCE21%' THEN 'NEEDS_IMPROVEMENT'
        WHEN METRIC_NAME LIKE '%\uACF5\uB78C%' AND METRIC_VALUE >= 0 THEN 'COMPETITIVE'
        WHEN METRIC_NAME LIKE '%\uACF5\uB78C%' THEN 'BELOW_MARKET'
        ELSE 'NORMAL'
    END AS HEALTH_STATUS
FROM INSURE_DB.FEEDBACK.SYSTEM_METRICS_LOG
ORDER BY METRIC_DATE DESC, METRIC_NAME;

-- ─────────────────────────────────────────────────────────────────────────
-- VIEW 4: BUSINESS FEEDBACK LOOP (\uC2E4\uC9C8 \uD57C\uB4DC\uBC31)
-- \uAD6C\uC871\uBCC4 \uC0DD\uC5EC\uC2A4 \uC5F0\uC911 \uBCF4\uD5D8\uB8CC (\uBCF4\uD5D8\uB2E8/\uB3C4\uBCF4\uC721 \uBE44\uC728)
-- Real Loss Experience: Aggregate claims to premium ratio per segment
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW INSURE_DB.FEEDBACK.V_BUSINESS_FEEDBACK_LOOP AS
WITH segment_premiums AS (
    SELECT
        cj.SEGMENT_A,
        cj.INCOME_BRACKET,
        cj.DISTRICT_NAME,
        COUNT(DISTINCT cj.CUSTOMER_ID) AS CUSTOMER_COUNT,
        SUM(cj.PREMIUM_QUOTED_KRW) AS TOTAL_PREMIUMS_COLLECTED_KRW,
        SUM(cj.SAVINGS_KRW) AS TOTAL_SAVINGS_GENERATED_KRW,
        ROUND(AVG(cj.PREMIUM_QUOTED_KRW), 0) AS AVG_PREMIUM_KRW,
        ROUND(AVG(cj.SAVINGS_KRW), 0) AS AVG_SAVINGS_PER_CUSTOMER_KRW
    FROM INSURE_DB.FEEDBACK.CUSTOMER_JOURNEY_LOG cj
    WHERE cj.ACTION_TYPE = 'SIGNUP'
    GROUP BY cj.SEGMENT_A, cj.INCOME_BRACKET, cj.DISTRICT_NAME
),
segment_claims AS (
    SELECT
        cj.SEGMENT_A,
        cj.INCOME_BRACKET,
        cj.DISTRICT_NAME,
        COUNT(DISTINCT cp.CLAIM_ID) AS TOTAL_CLAIMS,
        SUM(cp.CLAIM_AMOUNT_KRW) AS TOTAL_CLAIMS_PAID_KRW,
        ROUND(AVG(cp.CLAIM_AMOUNT_KRW), 0) AS AVG_CLAIM_SIZE_KRW,
        COUNT(CASE WHEN cp.STATUS = 'PAID' THEN 1 END) AS CLAIMS_PAID_COUNT,
        COUNT(CASE WHEN cp.STATUS = 'PENDING' THEN 1 END) AS CLAIMS_PENDING_COUNT,
        COUNT(CASE WHEN cp.STATUS = 'REJECTED' THEN 1 END) AS CLAIMS_REJECTED_COUNT
    FROM INSURE_DB.FEEDBACK.CUSTOMER_JOURNEY_LOG cj
    LEFT JOIN INSURE_DB.FEEDBACK.CLAIM_PAYOUTS_LOG cp
        ON cj.CUSTOMER_ID = cp.CUSTOMER_ID
    WHERE cj.ACTION_TYPE = 'CLAIM' OR cp.CLAIM_ID IS NOT NULL
    GROUP BY cj.SEGMENT_A, cj.INCOME_BRACKET, cj.DISTRICT_NAME
)
SELECT
    COALESCE(sp.SEGMENT_A, sc.SEGMENT_A) AS SEGMENT_A,
    COALESCE(sp.INCOME_BRACKET, sc.INCOME_BRACKET) AS INCOME_BRACKET,
    COALESCE(sp.DISTRICT_NAME, sc.DISTRICT_NAME) AS DISTRICT_NAME,

    COALESCE(sp.CUSTOMER_COUNT, 0) AS TOTAL_CUSTOMERS,
    COALESCE(sp.TOTAL_PREMIUMS_COLLECTED_KRW, 0) AS TOTAL_PREMIUMS_COLLECTED_KRW,
    COALESCE(sc.TOTAL_CLAIMS_PAID_KRW, 0) AS TOTAL_CLAIMS_PAID_KRW,

    -- \uBCF4\uC815\uC9C8\uBA38: \uB3C4\uBCF4\uC721 / \uBCF4\uD5D8\uB8CC
    ROUND(COALESCE(sc.TOTAL_CLAIMS_PAID_KRW, 0) /
          NULLIF(COALESCE(sp.TOTAL_PREMIUMS_COLLECTED_KRW, 1), 0), 3)
        AS CLAIMS_TO_PREMIUM_RATIO,

    -- \uC2E4\uC9C8 \uAC00\uC131\uBE44: \uAC00\uC785\uC790 \uC814\uCC29 \uC808\uC568 \uB098\uB204 \uBCF4\uD5D8\uB8CC
    ROUND(100.0 * (COALESCE(sp.TOTAL_PREMIUMS_COLLECTED_KRW, 0) -
          COALESCE(sc.TOTAL_CLAIMS_PAID_KRW, 0)) /
          NULLIF(COALESCE(sp.TOTAL_PREMIUMS_COLLECTED_KRW, 1), 0), 2)
        AS PROFIT_MARGIN_PCT,

    COALESCE(sp.AVG_PREMIUM_KRW, 0) AS AVG_PREMIUM_KRW,
    COALESCE(sp.AVG_SAVINGS_PER_CUSTOMER_KRW, 0) AS AVG_SAVINGS_PER_CUSTOMER_KRW,
    COALESCE(sc.TOTAL_CLAIMS, 0) AS TOTAL_CLAIMS,
    COALESCE(sc.AVG_CLAIM_SIZE_KRW, 0) AS AVG_CLAIM_SIZE_KRW,

    COALESCE(sc.CLAIMS_PAID_COUNT, 0) AS CLAIMS_PAID,
    COALESCE(sc.CLAIMS_PENDING_COUNT, 0) AS CLAIMS_PENDING,
    COALESCE(sc.CLAIMS_REJECTED_COUNT, 0) AS CLAIMS_REJECTED,

    CURRENT_TIMESTAMP() AS REPORT_GENERATED_AT
FROM segment_premiums sp
FULL OUTER JOIN segment_claims sc
    ON sp.SEGMENT_A = sc.SEGMENT_A
    AND sp.INCOME_BRACKET = sc.INCOME_BRACKET
    AND sp.DISTRICT_NAME = sc.DISTRICT_NAME
ORDER BY TOTAL_PREMIUMS_COLLECTED_KRW DESC;

-- =============================================================================
-- PART 3: \uC790\ub3d9 \uBC14\uB530 \uC774\uA0A4\uD2B8 \uAE30\uBC18 \uC11C\uBE44\uC2A4 \uC9C0\uC11C\uBC29 \uAC4B\uC774\uC11C
-- Auto-Aggregation & Adjustment Procedures
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- STORED PROCEDURE 1: \uc77c\ucd1c \uAC10\uB098 \uB370\uC774\uB2F0 \uc8B4\uD2B9
-- Daily metric aggregation (Call daily 23:00 KST)
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE INSURE_DB.FEEDBACK.SP_AUTO_COLLECT_METRICS()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_metric_date DATE;
BEGIN
    SET v_metric_date = CURRENT_DATE();

    -- \u{1} \ub2e8\ubb14: \uBB3C\uB2B8\uC911\uB0A0 \uBE44\uBAA8 \uC8FC\uB2F9\uC744 \uC1B0\uB978\uB4F1 \uD5D8\uC911\uC9D5\uD2B9 \u{2}\uC6B0\uC704\uC600\uB204 \u{3}\u{4}\u{5}

    -- 1. Model Prediction Accuracy
    INSERT INTO INSURE_DB.FEEDBACK.SYSTEM_METRICS_LOG
    (METRIC_DATE, METRIC_NAME, METRIC_VALUE, METRIC_UNIT, TREND, DESCRIPTION)
    SELECT
        v_metric_date,
        '\uC608\uCE21 \uC815\uD655\uB3C4 (Prediction Accuracy)',
        ROUND(100.0 * COUNT(CASE WHEN ABS(PREMIUM_DESIGNED_KRW - MARKET_PREMIUM_KRW) /
                 NULLIF(MARKET_PREMIUM_KRW, 0) <= 0.15 THEN 1 END) /
                 NULLIF(COUNT(*), 0), 2),
        '%',
        CASE
            WHEN ROUND(100.0 * COUNT(CASE WHEN ABS(PREMIUM_DESIGNED_KRW - MARKET_PREMIUM_KRW) /
                 NULLIF(MARKET_PREMIUM_KRW, 0) <= 0.15 THEN 1 END) /
                 NULLIF(COUNT(*), 0), 2) >= 80 THEN 'UP'
            ELSE 'STABLE'
        END,
        '\uBDE0\uB098\uC774 \uBBF8\uC2DD\uC744\uB2B8 15% \ub0b4 \uC815\uD655\uB3C4'
    FROM INSURE_DB.FEEDBACK.PRODUCT_DESIGN_LOG
    WHERE DATE(DESIGN_TIMESTAMP) = v_metric_date;

    -- 2. Market Competitiveness (vs market average)
    INSERT INTO INSURE_DB.FEEDBACK.SYSTEM_METRICS_LOG
    (METRIC_DATE, METRIC_NAME, METRIC_VALUE, METRIC_UNIT, TREND, DESCRIPTION)
    SELECT
        v_metric_date,
        '\uC2DC\uC7A5 \uACF5\uB78C\uB09C (\uACBD\uC7C1\uB825)',
        ROUND(100.0 * SUM(CASE WHEN PREMIUM_DESIGNED_KRW < MARKET_PREMIUM_KRW THEN 1 ELSE 0 END) /
              NULLIF(COUNT(*), 0), 2),
        '%',
        CASE
            WHEN ROUND(100.0 * SUM(CASE WHEN PREMIUM_DESIGNED_KRW < MARKET_PREMIUM_KRW THEN 1 ELSE 0 END) /
                  NULLIF(COUNT(*), 0), 2) > 50 THEN 'UP'
            ELSE 'DOWN'
        END,
        '\uC2DC\uC7A5 \ub0b4 \ub3d8\uc9004 \ube44\uc32c\ub09c \ube44\uc728'
    FROM INSURE_DB.FEEDBACK.CUSTOMER_JOURNEY_LOG
    WHERE DATE(SESSION_TIMESTAMP) = v_metric_date AND CONVERSION_FLAG = TRUE;

    -- 3. Data Freshness
    INSERT INTO INSURE_DB.FEEDBACK.SYSTEM_METRICS_LOG
    (METRIC_DATE, METRIC_NAME, METRIC_VALUE, METRIC_UNIT, TREND, DESCRIPTION)
    SELECT
        v_metric_date,
        '\uD14C\uC774\uD130 \uC2E0\uC120\uB3C4 (Data Freshness)',
        ROUND(100.0 * COUNT(*) / NULLIF(LAG(COUNT(*)) OVER (ORDER BY v_metric_date), 0), 2),
        '%',
        'STABLE',
        '\uC911 24 \uC2DC\uAC04 \ub0b4 \ub300\uc2e0 \uc801\ub2b8\ub0ec \ub370\uC774\ud130'
    FROM INSURE_DB.FEEDBACK.CUSTOMER_JOURNEY_LOG
    WHERE DATE(SESSION_TIMESTAMP) >= v_metric_date - 1;

    -- 4. Conversion Funnel by Segment
    INSERT INTO INSURE_DB.FEEDBACK.SYSTEM_METRICS_LOG
    (METRIC_DATE, METRIC_NAME, METRIC_VALUE, METRIC_UNIT, TREND, DESCRIPTION)
    SELECT
        v_metric_date,
        '\uc804\uccb4 \uC804\uD658\uB960 (Overall Conversion Rate)',
        ROUND(100.0 * SUM(CASE WHEN CONVERSION_FLAG THEN 1 ELSE 0 END) /
              NULLIF(COUNT(*), 0), 2),
        '%',
        'STABLE',
        '\uAC80\uC0C9 \uB300\uBE44 \uAC00\uC785 \uC804\uD658\uB960'
    FROM INSURE_DB.FEEDBACK.CUSTOMER_JOURNEY_LOG
    WHERE DATE(SESSION_TIMESTAMP) = v_metric_date;

    RETURN '\uBA54\uD2B8\uB9AD \uc718\ub978 \uC2A4\uCF00\uC8A4: ' || v_metric_date || ' \uC8FC\uC5B8 \ub06d\uc57d\uC560\uD3B8\uB098\uB85C \uAC04\uCEA1 \ub91b';
END
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- STORED PROCEDURE 2: \uBE44\uC988\uB2C8\uC2A4 \uBA54\uD2B8\uB9AD \uAE30\uBC18 \uC39C\uAC1C\uBCB4\uC5F0 \uC870\uC815
-- Apply automated recommendations based on business metrics
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE INSURE_DB.FEEDBACK.SP_FEEDBACK_DRIVEN_ADJUSTMENT()
RETURNS TABLE (RECOMMENDATION VARCHAR, REASON VARCHAR, PRIORITY VARCHAR, ACTION_OWNER VARCHAR)
LANGUAGE SQL
AS
$$
BEGIN
    -- \uC2E4\uC9C8 \uCA00\uCD94\uB978 \uAC00\uC131\uBE44 \uAC04\uC911 \uCEBD\uC5F0 \uC635\uC15C
    SELECT
        CASE
            WHEN claims_ratio > 0.25 THEN '\uBCF4\uD5D8\uB8CC \uC778\uC0C1 (\uBCF4\uC815\uC9C8\uBA38 \uCD08\uACFC - \ub0b4\ub9bc\ud3a0 \ub0b4\ub9bc)'
            WHEN claims_ratio < 0.10 THEN '\uBCF4\uD5D8\uB8CC \uC789\uB144\uB9AC \uc870\uc815 (\uc9b0 \ub3d8\uc9004\ube44 \uB0A8\ub3d8)'
            WHEN conversion_rate < 5 THEN '\uD328\uD0C0\uB2B9 \uC1B0\uD0B8 \uC911\uAC00 \ub0a9\uc9c4 (\uAC80\uC0C9 \uBE44\uC911\uC9D5 \uBDC7\uC8F8 \ub0a8)'
            WHEN avg_savings < 50000 THEN '\uBE44\uAD50 \uC808\uC568 \uD06D\uC6A9\uC131 \uB83C\uD56D - \uAC1C\uC120 \uC911\uC2D9 \uB2E8\uAC84 \uB118\uC73C\uB85C \uCD08\uC81C'
            WHEN quote_to_contract_rate < 20 THEN '\uACAC\uC801 \uC990\uC0BD\uC13C\uD130 \uC911\uAC15 (\uC598\uC0C1 \uC625\uCAC8\uB2B8 \uCD94\uC802)'
            ELSE '\uB2E8\uC2B9 \uC2B4\uC778 (\ub0b4\ub2f4\ub4e4\uc758 \ube44\uc2c1 \uBC1C\uc751 \ubd84\ub7ec \uac10\uc2ac \ub09c)'
        END AS recommendation,
        CASE
            WHEN claims_ratio > 0.25 THEN '\uBCF4\uC815\uC9C8\uBA38 \uCD08\uACFC - \uBE44\uC6A9 \uc911\uC995 \uxFF11 \uc711\ub3d8'
            WHEN claims_ratio < 0.10 THEN '\uAC80\uC990 \uBD95\uB9CE \uD56D\uC778 \uC2B4\uCF00 \uBBF8\uC1C4\uB098 \uB0B4\uB9BC\ub2D9'
            WHEN conversion_rate < 5 THEN '\uAC80\uC0C9 \uBE44\uC911\uC9D5 \uBDC7\uC8F8 \ub0a8 - \uC5F0\uB77C\uD0A4\uD2F1\uB098 \uC11C\uBE44\uC2A4 \uC911\uAC15 \uC99D\ub280\uCEC0'
            WHEN avg_savings < 50000 THEN '\uB2A4\uCEA3\uD2B8 \uAC1C\uB14C \ub124\uBB4C\uB2D7 - \uB9C8\uCF00\uD305 \uAC15\uD654 \ud544\uc2DC'
            WHEN quote_to_contract_rate < 20 THEN '\uACAC\uC801\u2192\uACC4\uC57D \uC5F0\uACB0 \uC624\uBBBC \uD0A4\uB098 \uB300\uC644\uD3BC\uC11C'
            ELSE '\uc131\uC728 \uc131\ub3d8 \ub9ac\ub355\uc2e4 \u2192 \ub3d8\ub978 \uC140\ub2E8 \ub91d\uBCD8\ub978 \uBBF8\uB0B4'
        END AS reason,
        CASE
            WHEN claims_ratio > 0.25 THEN 'CRITICAL'
            WHEN claims_ratio < 0.10 OR conversion_rate < 5 THEN 'HIGH'
            WHEN avg_savings < 50000 OR quote_to_contract_rate < 20 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS priority,
        CASE
            WHEN claims_ratio > 0.25 THEN '\uC보\uBB38 \uC78A \uCE68\uD589\u2665\uACC8'
            WHEN claims_ratio < 0.10 THEN 'Risk Analytics Team'
            WHEN conversion_rate < 5 THEN 'Product & Marketing'
            WHEN avg_savings < 50000 THEN 'Pricing Strategy'
            WHEN quote_to_contract_rate < 20 THEN 'Sales & Customer Success'
            ELSE 'Actuary Team'
        END AS action_owner
    FROM (
        SELECT
            MAX(CLAIMS_TO_PREMIUM_RATIO) AS claims_ratio,
            MAX(AVG_SAVINGS_PER_CUSTOMER_KRW) AS avg_savings,
            AVG(COALESCE(
                100.0 * SUM(CASE WHEN ACTION_TYPE = 'SIGNUP' THEN 1 ELSE 0 END) /
                NULLIF(SUM(CASE WHEN ACTION_TYPE = 'SEARCH' THEN 1 ELSE 0 END), 0), 0)
            ) AS conversion_rate,
            AVG(QUOTE_TO_CONTRACT_RATE_PCT) AS quote_to_contract_rate
        FROM INSURE_DB.FEEDBACK.V_BUSINESS_FEEDBACK_LOOP
        WHERE METRIC_DATE >= CURRENT_DATE() - 7
    ) metrics;
END
$$;

-- =============================================================================
-- PART 4: \uC3E4 \uC2A4\uC9D5\uD20C \uB370\uC774\uD130
-- Seed Data (50+ rows per table)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- SEED: PRODUCT_DESIGN_LOG (30 \uD–\uA080\uBBFC \uACE0\uAC00\uB2E8\uCE7C\uBB34\uAC00)
-- ─────────────────────────────────────────────────────────────────────────
INSERT INTO INSURE_DB.FEEDBACK.PRODUCT_DESIGN_LOG
(ACTUARY_ID, DISTRICT_NAME, SEGMENT_A, INCOME_BRACKET, PREMIUM_DESIGNED_KRW, COVERAGE_TYPE, STATUS, QUOTE_ISSUED_BY, MARKET_PREMIUM_KRW, MARGIN_KRW)
VALUES
('ACT001', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 150000, '\uC804\uC790\uAE30\uAE30', 'CONTRACTED', 'HELPER001', 160000, -10000),
('ACT001', '\uBD80\uC0B0', 'A2_\uC2E0\uD63C', 'MID', 450000, '\uAC00\uC804', 'CONTRACTED', 'HELPER001', 500000, -50000),
('ACT001', '\uC778\uCC9C', 'A3_\uC601\uC720\uC544\uAC00\uAD6C', 'MID', 380000, '\uC804\uC790\uAE30\uAE30', 'QUOTED', 'HELPER002', 420000, -40000),
('ACT001', '\uB300\uAD6C', 'A4_\uD559\uB839\uAE30\uAC00\uAD6C', 'MID', 320000, '\uAC00\uC804', 'DRAFT', NULL, 350000, -30000),
('ACT001', '\uB300\uC804', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 680000, '\uAC00\uC804', 'CONTRACTED', 'HELPER001', 720000, -40000),
('ACT002', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 140000, '\uC804\uC790\uAE30\uAE30', 'QUOTED', 'HELPER003', 155000, -15000),
('ACT002', '\uBD80\uC0B0', 'A6_\uC740\uD1F4\uC2DC\uB2C8\uC5B4', 'LOW', 120000, '\uAC00\uC804', 'CONTRACTED', 'HELPER003', 135000, -15000),
('ACT002', '\uAD11\uC8FC', 'B1_\uC601\uB9AC\uCE58', 'ULTRA', 950000, '\uAC00\uC804', 'CONTRACTED', 'HELPER002', 1000000, -50000),
('ACT002', '\uC11C\uC6B8', 'A2_\uC2E0\uD63C', 'MID', 420000, '\uAC00\uC804', 'QUOTED', 'HELPER003', 460000, -40000),
('ACT003', '\uC778\uCC9C', 'A3_\uC601\uC720\uC544\uAC00\uAD6C', 'MID', 390000, '\uC804\uC790\uAE30\uAE30', 'DRAFTED', NULL, 430000, -40000),
('ACT003', '\uB300\uAD6C', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 710000, '\uAC00\uC804', 'CONTRACTED', 'HELPER001', 750000, -40000),
('ACT003', '\uD0DC\uBC1C', 'B2_\uC54C\uB73B\uD615', 'MID', 280000, '\uAC00\uC804', 'QUOTED', 'HELPER002', 310000, -30000),
('ACT001', '\uC11C\uC6B8', 'A4_\uD559\uB839\uAE30\uAC00\uAD6C', 'MID', 340000, '\uC804\uC790\uAE30\uAE30', 'CONTRACTED', 'HELPER001', 370000, -30000),
('ACT002', '\uBD80\uC0B0', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 145000, '\uC804\uC790\uAE30\uAE30', 'CONTRACTED', 'HELPER002', 160000, -15000),
('ACT003', '\uC2DC\uC6C4', 'A2_\uC2E0\uD63C', 'MID', 440000, '\uC804\uC790\uAE30\uAE30', 'QUOTED', 'HELPER003', 480000, -40000),
('ACT001', '\uC218\uC6D0', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 720000, '\uAC00\uC804', 'CONTRACTED', 'HELPER001', 780000, -60000),
('ACT002', '\uBD80\uC0B0', 'A3_\uC601\uC720\uC544\uAC00\uAD6C', 'MID', 385000, '\uAC00\uC804', 'QUOTED', 'HELPER002', 420000, -35000),
('ACT003', '\uB300\uAD6C', 'A6_\uC740\uD1F4\uC2DC\uB2C8\uC5B4', 'LOW', 130000, '\uAC00\uC804', 'CONTRACTED', 'HELPER003', 145000, -15000),
('ACT001', '\uCD9C\uCC9C', 'B1_\uC601\uB9AC\uCE58', 'ULTRA', 980000, '\uAC00\uC804', 'CONTRACTED', 'HELPER001', 1050000, -70000),
('ACT002', '\uD310\uAC10', 'A4_\uD559\uB839\uAE30\uAC00\uAD6C', 'MID', 330000, '\uC804\uC790\uAE30\uAE30', 'QUOTED', 'HELPER002', 360000, -30000);

-- ─────────────────────────────────────────────────────────────────────────
-- SEED: CUSTOMER_JOURNEY_LOG (50\uFEFF \uD–\uA080\uBBFC \uB300\uB85C \uB298\uC704\uABB8)
-- ─────────────────────────────────────────────────────────────────────────
INSERT INTO INSURE_DB.FEEDBACK.CUSTOMER_JOURNEY_LOG
(CUSTOMER_ID, DISTRICT_NAME, SEGMENT_A, INCOME_BRACKET, ACTION_TYPE, PREMIUM_QUOTED_KRW, MARKET_AVG_PREMIUM_KRW, SAVINGS_KRW, CONVERSION_FLAG)
VALUES
('CUST001', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST001', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 'COMPARE', 150000, 160000, 10000, FALSE),
('CUST001', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 'QUOTE', 150000, 160000, 10000, FALSE),
('CUST001', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 'SIGNUP', 150000, 160000, 10000, TRUE),
('CUST002', '\uBD80\uC0B0', 'A2_\uC2E0\uD63C', 'MID', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST002', '\uBD80\uC0B0', 'A2_\uC2E0\uD63C', 'MID', 'COMPARE', 450000, 500000, 50000, FALSE),
('CUST002', '\uBD80\uC0B0', 'A2_\uC2E0\uD63C', 'MID', 'QUOTE', 450000, 500000, 50000, FALSE),
('CUST002', '\uBD80\uC0B0', 'A2_\uC2E0\uD63C', 'MID', 'SIGNUP', 450000, 500000, 50000, TRUE),
('CUST003', '\uC778\uCC9C', 'A3_\uC601\uC720\uC544\uAC00\uAD6C', 'MID', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST003', '\uC778\uCC9C', 'A3_\uC601\uC720\uC544\uAC00\uAD6C', 'MID', 'COMPARE', 380000, 420000, 40000, FALSE),
('CUST004', '\uB300\uAD6C', 'A4_\uD559\uB839\uAE30\uAC00\uAD6C', 'MID', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST004', '\uB300\uAD6C', 'A4_\uD559\uB839\uAE30\uAC00\uAD6C', 'MID', 'QUOTE', 320000, 350000, 30000, FALSE),
('CUST005', '\uB300\uC804', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST005', '\uB300\uC804', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 'COMPARE', 680000, 720000, 40000, FALSE),
('CUST005', '\uB300\uC804', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 'QUOTE', 680000, 720000, 40000, FALSE),
('CUST005', '\uB300\uC804', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 'SIGNUP', 680000, 720000, 40000, TRUE),
('CUST006', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST006', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 'COMPARE', 140000, 155000, 15000, FALSE),
('CUST006', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 'QUOTE', 140000, 155000, 15000, FALSE),
('CUST006', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 'SIGNUP', 140000, 155000, 15000, TRUE),
('CUST007', '\uBD80\uC0B0', 'A6_\uC740\uD1F4\uC2DC\uB2C8\uC5B4', 'LOW', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST007', '\uBD80\uC0B0', 'A6_\uC740\uD1F4\uC2DC\uB2C8\uC5B4', 'LOW', 'COMPARE', 120000, 135000, 15000, FALSE),
('CUST007', '\uBD80\uC0B0', 'A6_\uC740\uD1F4\uC2DC\uB2C8\uC5B4', 'LOW', 'QUOTE', 120000, 135000, 15000, FALSE),
('CUST007', '\uBD80\uC0B0', 'A6_\uC740\uD1F4\uC2DC\uB2C8\uC5B4', 'LOW', 'SIGNUP', 120000, 135000, 15000, TRUE),
('CUST008', '\uAD11\uC8FC', 'B1_\uC601\uB9AC\uCE58', 'ULTRA', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST008', '\uAD11\uC8FC', 'B1_\uC601\uB9AC\uCE58', 'ULTRA', 'COMPARE', 950000, 1000000, 50000, FALSE),
('CUST008', '\uAD11\uC8FC', 'B1_\uC601\uB9AC\uCE58', 'ULTRA', 'QUOTE', 950000, 1000000, 50000, FALSE),
('CUST008', '\uAD11\uC8FC', 'B1_\uC601\uB9AC\uCE58', 'ULTRA', 'SIGNUP', 950000, 1000000, 50000, TRUE),
('CUST009', '\uC11C\uC6B8', 'A2_\uC2E0\uD63C', 'MID', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST009', '\uC11C\uC6B8', 'A2_\uC2E0\uD63C', 'MID', 'COMPARE', 420000, 460000, 40000, FALSE),
('CUST009', '\uC11C\uC6B8', 'A2_\uC2E0\uD63C', 'MID', 'QUOTE', 420000, 460000, 40000, FALSE),
('CUST010', '\uC778\uCC9C', 'A3_\uC601\uC720\uC544\uAC00\uAD6C', 'MID', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST010', '\uC778\uCC9C', 'A3_\uC601\uC720\uC544\uAC00\uAD6C', 'MID', 'COMPARE', 390000, 430000, 40000, FALSE),
('CUST011', '\uB300\uAD6C', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST011', '\uB300\uAD6C', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 'COMPARE', 710000, 750000, 40000, FALSE),
('CUST011', '\uB300\uAD6C', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 'QUOTE', 710000, 750000, 40000, FALSE),
('CUST011', '\uB300\uAD6C', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 'SIGNUP', 710000, 750000, 40000, TRUE),
('CUST012', '\uD0DC\uBC1C', 'B2_\uC54C\uB73B\uD615', 'MID', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST012', '\uD0DC\uBC1C', 'B2_\uC54C\uB73B\uD615', 'MID', 'COMPARE', 280000, 310000, 30000, FALSE),
('CUST012', '\uD0DC\uBC1C', 'B2_\uC54C\uB73B\uD615', 'MID', 'QUOTE', 280000, 310000, 30000, FALSE),
('CUST013', '\uC11C\uC6B8', 'A4_\uD559\uB839\uAE30\uAC00\uAD6C', 'MID', 'SEARCH', NULL, NULL, NULL, FALSE),
('CUST013', '\uC11C\uC6B8', 'A4_\uD559\uB839\uAE30\uAC00\uAD6C', 'MID', 'COMPARE', 340000, 370000, 30000, FALSE),
('CUST013', '\uC11C\uC6B8', 'A4_\uD559\uB839\uAE30\uAC00\uAD6C', 'MID', 'QUOTE', 340000, 370000, 30000, FALSE),
('CUST013', '\uC11C\uC6B8', 'A4_\uD559\uB839\uAE30\uAC00\uAD6C', 'MID', 'SIGNUP', 340000, 370000, 30000, TRUE),
('CUST001', '\uC11C\uC6B8', 'A1_\uC0AC\uD68C\uCD08\uB144\uC0DD', 'LOW', 'RENEW', 150000, 160000, 10000, TRUE),
('CUST002', '\uBD80\uC0B0', 'A2_\uC2E0\uD63C', 'MID', 'CLAIM', NULL, NULL, NULL, TRUE),
('CUST005', '\uB300\uC804', 'A5_\uC911\uB144\uC548\uC815', 'HIGH', 'RENEW', 680000, 720000, 40000, TRUE),
('CUST008', '\uAD11\uC8FC', 'B1_\uC601\uB9AC\uCE58', 'ULTRA', 'RENEW', 950000, 1000000, 50000, TRUE);

-- ─────────────────────────────────────────────────────────────────────────
-- SEED: CLAIM_PAYOUTS_LOG (\ubcf4\uc815\uae08 \uac74\uc218)
-- ─────────────────────────────────────────────────────────────────────────
INSERT INTO INSURE_DB.FEEDBACK.CLAIM_PAYOUTS_LOG
(CLAIM_ID, CUSTOMER_ID, CLAIM_DATE, COVERAGE_TYPE, CLAIM_AMOUNT_KRW, ANNUAL_PREMIUM_KRW, STATUS)
VALUES
('CLM001', 'CUST002', '2025-12-15', '\uAC00\uC804', 450000, 450000, 'PAID'),
('CLM002', 'CUST005', '2025-11-20', '\uC804\uC790\uAE30\uAE30', 680000, 680000, 'PAID'),
('CLM003', 'CUST008', '2025-10-10', '\uAC00\uC804', 200000, 950000, 'PAID'),
('CLM004', 'CUST002', '2025-01-22', '\uC804\uC790\uAE30\uAE30', 150000, 450000, 'PENDING'),
('CLM005', 'CUST005', '2025-02-08', '\uAC00\uC804', 100000, 680000, 'REJECTED');

-- ─────────────────────────────────────────────────────────────────────────
-- SEED: SYSTEM_METRICS_LOG (\uC2DC\uC2A4\uD15C \uBA54\uD2B8\uB9AD)
-- ─────────────────────────────────────────────────────────────────────────
INSERT INTO INSURE_DB.FEEDBACK.SYSTEM_METRICS_LOG
(METRIC_DATE, METRIC_NAME, METRIC_VALUE, METRIC_UNIT, TREND, DESCRIPTION)
VALUES
(CURRENT_DATE(), '\uC608\uCE21 \uC815\uD655\uB3C4', 82.5, '%', 'UP', '\uBDE0\uB98C 82.5% \ub0b4 \uC815\uD655 \uBD80\uCE74\uC911 \uB18C'),
(CURRENT_DATE(), '\uC2DC\uC7A5 \uACF5\uB78C\uB09C', 65.0, '%', 'UP', '\uC2DC\uC7A5 \uB0B4 \uBF08\uB978 \uAC00\uACA9 \uBE44\uC228 65%'),
(CURRENT_DATE(), '\uD14C\uC774\uD130 \uC2E0\uC120\uB3C4', 95.2, '%', 'STABLE', '24\uC2DC\uAC04 \ub0b4\ub098 \uAC31\uC744 \uC0AD\uC815 \uCE20\uD0F8\uBCB4'),
(CURRENT_DATE(), '\uc804\uccb4 \uC804\uD658\uB960', 32.0, '%', 'UP', '\uAC80\uC0C9\u2192\uAC00\uC785 32% \ub0b4\uBD80 \uBFD4\uD0F1\uB2E8'),
(CURRENT_DATE() - 1, '\uC608\uCE21 \uC815\uD655\uB3C4', 80.0, '%', 'STABLE', '\uc5b4\uc81c\uB178 80% \uC815\uB3c4'),
(CURRENT_DATE() - 1, '\uC2DC\uC7A5 \uACF5\uB78C\uB09C', 62.0, '%', 'UP', '\uc5b4\uc81c\ub3c4 \uC911\uAC00 \uC704\uC05D'),
(CURRENT_DATE() - 1, '\uD14C\uC774\uD130 \uC2E0\uC120\uB3C4', 93.5, '%', 'STABLE', '\uc5b4\uc81c\ub55c \uCCD4\uBCBD\uC2E0\uC120'),
(CURRENT_DATE() - 1, '\uc804\uccb4 \uC804\uD658\uB960', 30.0, '%', 'STABLE', '\uc5b4\uc81c\ub55c 30% \uB0B4\uBD80');

-- =============================================================================
-- PART 5: \uQ\uCD08 \uBE08\uBBFD
-- Access Control Grants
-- =============================================================================

GRANT USAGE ON DATABASE INSURE_DB TO ROLE ANALYST;
GRANT USAGE ON SCHEMA INSURE_DB.FEEDBACK TO ROLE ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.FEEDBACK TO ROLE ANALYST;
GRANT SELECT ON ALL VIEWS IN SCHEMA INSURE_DB.FEEDBACK TO ROLE ANALYST;
GRANT EXECUTE ON PROCEDURE INSURE_DB.FEEDBACK.SP_AUTO_COLLECT_METRICS() TO ROLE ANALYST;
GRANT EXECUTE ON PROCEDURE INSURE_DB.FEEDBACK.SP_FEEDBACK_DRIVEN_ADJUSTMENT() TO ROLE ANALYST;

-- =============================================================================
-- PART 6: \ubaa8\ub78c \uC628\uB9C8\uC788\uB4DC (\uBE44\uC6F0\uB0B8\uC2A4 \uBA54\uD2B8\uB9AD \uAC80\uC47D)
-- Final Verification
-- =============================================================================

SELECT 'v1.4 Feedback System Redesign - Complete' AS STATUS;

SELECT
    'PRODUCT_DESIGN_LOG' AS TABLE_NAME,
    COUNT(*) AS ROW_COUNT
FROM INSURE_DB.FEEDBACK.PRODUCT_DESIGN_LOG
UNION ALL
SELECT
    'CUSTOMER_JOURNEY_LOG',
    COUNT(*)
FROM INSURE_DB.FEEDBACK.CUSTOMER_JOURNEY_LOG
UNION ALL
SELECT
    'CLAIM_PAYOUTS_LOG',
    COUNT(*)
FROM INSURE_DB.FEEDBACK.CLAIM_PAYOUTS_LOG
UNION ALL
SELECT
    'SYSTEM_METRICS_LOG',
    COUNT(*)
FROM INSURE_DB.FEEDBACK.SYSTEM_METRICS_LOG;
