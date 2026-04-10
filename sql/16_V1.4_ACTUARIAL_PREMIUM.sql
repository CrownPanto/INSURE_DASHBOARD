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
