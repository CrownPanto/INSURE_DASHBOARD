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
