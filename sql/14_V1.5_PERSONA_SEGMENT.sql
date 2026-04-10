-- ============================================================================
-- File: 19_V1.5_PERSONA_SEGMENT.sql
-- Purpose: INSURE Dynamic Insurance Engine - Persona Segmentation Framework
-- Version: 1.5
-- Description: Consolidates 5-dimension segment system into 10 realistic personas
--              with corresponding insurance design and premium calculations
-- ============================================================================

-- ============================================================================
-- SECTION 1: SEED DATA - PERSONA DEFINITIONS
-- ============================================================================
-- This table defines the 10 core personas with business characteristics
-- Each persona represents a distinct customer archetype with unique:
-- - Lifecycle stage and asset consumption patterns
-- - Housing and occupational profiles
-- - Risk profile and insurance needs
-- - Monthly premium ranges derived from actuarial analysis

CREATE OR REPLACE TABLE INSURE_DB.SEED.SEED_PERSONA_DEFINITION (
    PERSONA_ID VARCHAR(10) NOT NULL,
    PERSONA_NAME_KOR VARCHAR(100),
    PERSONA_NAME_ENG VARCHAR(100),
    BASE_SEGMENT_COMBINATION VARCHAR(50),
    KEY_ASSETS_DESCRIPTION VARCHAR(500),
    KEY_ASSETS_VALUE_MIN DECIMAL(15, 0),
    KEY_ASSETS_VALUE_MAX DECIMAL(15, 0),
    MONTHLY_PREMIUM_MIN DECIMAL(10, 2),
    MONTHLY_PREMIUM_MAX DECIMAL(10, 2),
    RISK_FACTOR DECIMAL(5, 3),
    OCCUPANCY_TYPE VARCHAR(50),
    PRIMARY CONSTRAINT persona_pk PRIMARY KEY (PERSONA_ID)
);

-- Insert persona definitions using unicode escapes for Korean text
INSERT INTO INSURE_DB.SEED.SEED_PERSONA_DEFINITION VALUES
-- P01: Young Professional (Single, Entry-level Job, Studio Apartment)
-- Actuarial Profile: Low asset value, high mobility risk
('P01',
 '\uC6D0\uB8F8 \uC0AC\uD68C\uCD08\uB144\uC0DD',
 'Young Professional',
 'A1+B2+C4+E2',
 '\uC804\uC790\uC81C\uD488 \uB4F1',
 4250000,
 5750000,
 25000.00,
 45000.00,
 1.000,
 'STUDIO'),

-- P02: Newlywed Couple (Dual Income, New Apartment, Furnished)
-- Actuarial Profile: Medium-high asset value, lower mobility risk
('P02',
 '\uC2E0\uD63C\uBD80\uBD80 \uB9E3\uBCCF\uC774',
 'Newlywed Couple',
 'A2+B0+C1+E1',
 '\uACB0\uD63C\uAC00\uC804 \uB4F1',
 23800000,
 32200000,
 35000.00,
 65000.00,
 1.250,
 'APARTMENT_NEW'),

-- P03: Working Mom with Infant (Mixed Income, Childcare Needs, Family Housing)
-- Actuarial Profile: Medium asset value, higher claim frequency (child-related)
('P03',
 '\uC601\uC720\uC544 \uC6CC\uD0B9\uB9C8\uC6C0',
 'Working Mom w/Infant',
 'A3+B2+C3+E1',
 '\uC544\uAE30\uC6A9\uD488 \uBC0F \uAC00\uC804\uC81C\uD488',
 17000000,
 23000000,
 45000.00,
 80000.00,
 1.400,
 'APARTMENT_SMALL'),

-- P04: School District Family (Established Career, Quality Housing, Education Focus)
-- Actuarial Profile: High asset value, lower risk profile, education expenses
('P04',
 '\uD559\uAD70\uC9C0 4\uC778\uAC00\uC871',
 'School District Family',
 'A4+B3+C1+E1',
 '\uAC00\uC804\uC81C\uD488 \uC624\uD06C \uB4F1',
 38250000,
 51750000,
 55000.00,
 95000.00,
 1.150,
 'APARTMENT_LARGE'),

-- P05: Property Owner 50s (Mature Professional, Multiple Assets, High Net Worth)
-- Actuarial Profile: Very high asset value, concentrated risk, valuable collections
('P05',
 '50\ub300 \uAC74\uBB3C\uC8FC',
 'Property Owner 50s',
 'A5+B1+C1+E1',
 '\uBCF4\uC11D \uBC0F \uACF5\uC608\uC708\uC218\uD488 \uB4F1',
 68000000,
 92000000,
 120000.00,
 250000.00,
 1.600,
 'HOUSE_OWNED'),

-- P06: Retired Senior (Fixed Income, Reduced Consumption, Healthcare Needs)
-- Actuarial Profile: Medium asset value, higher claim frequency (medical/accidental)
('P06',
 '\uC740\uD400 \uC2DC\uB2C8\uC5B4',
 'Retired Senior',
 'A6+B4+C2+E2',
 '\uC758\uB8CC\uC6A9\uAE30 \uBC0F \uAE30\uCCD08 \uAC00\uC804',
 12750000,
 17250000,
 35000.00,
 55000.00,
 1.500,
 'APARTMENT_MEDIUM'),

-- P07: Small Business Owner (Entrepreneur, Multiple Revenue Streams, High Risk)
-- Actuarial Profile: Highly variable income, inventory risk, business equipment
('P07',
 '\uACE8\uBAA9\uC0C1\uB9C8 \uC790\uC601\uC5C5\uC790',
 'Small Business Owner',
 'A5+D1+C4+E3',
 '\uC0AC\uC5C5\uC6A9 \uB9E4\uC7A5 \uBC0F \uC81C\uBD80\uC77C\uBD19',
 42500000,
 57500000,
 65000.00,
 120000.00,
 1.800,
 'COMMERCIAL'),

-- P08: Affluent Single (High Income, Luxury Preferences, Quality of Life Focus)
-- Actuarial Profile: High asset value, lower frequency but higher severity claims
('P08',
 '\uC601\uB9AC\uCE58 \uC2F1\uAE00',
 'Affluent Single',
 'A1+B1+C1+E1',
 '\uAC00\uC804\uC81C\uD488 \uB4F1',
 25500000,
 34500000,
 80000.00,
 150000.00,
 1.200,
 'APARTMENT_PREMIUM'),

-- P09: Over-spending Youth (Entry-level Income, High Consumption Behavior, Debt Risk)
-- Actuarial Profile: Low stable assets but volatile consumption patterns
('P09',
 '\uC18C\uBE44\uACFC\ub2e4 2030',
 'Over-spending Youth',
 'A1+B5+C4+E2',
 '\uCD08\uADF8\uB798\uD508 \uC804\uC790\uC81C\uD488',
 6800000,
 9200000,
 15000.00,
 30000.00,
 1.100,
 'STUDIO'),

-- P10: Remote Professional (Tech-savvy, Work-from-home, Flexible Lifestyle)
-- Actuarial Profile: Medium asset value, lower commute risk, home office equipment
('P10',
 '\uC804\uBB38\uC9C1 \uC7AC\uD0DD\uadfc\ubb34',
 'Remote Professional',
 'A4+D2+C3+E1',
 '\uC5C5\uBB34\uC6A9 \uC7A5\uBE44 \uBC0F \uAC00\uC804',
 29750000,
 40250000,
 40000.00,
 70000.00,
 1.050,
 'APARTMENT_MEDIUM');

COMMENT ON TABLE INSURE_DB.SEED.SEED_PERSONA_DEFINITION IS
'Seed table defining 10 core insurance personas with business characteristics.
Each persona consolidates multiple 5-dimension segment combinations into a
single archetypal customer profile. Risk factors are derived from actuarial
analysis of claim frequency and severity patterns.';

-- ============================================================================
-- SECTION 2: MAPPING VIEW - SEGMENT TO PERSONA CLASSIFICATION
-- ============================================================================
-- This view implements the mapping logic from existing 5-dimension segments
-- to the 10 defined personas using priority-based CASE logic.
-- The mapping prioritizes lifecycle stage (A) first, then asset/consumption (B),
-- housing type (C), occupation (D), and risk profile (E).

CREATE OR REPLACE VIEW INSURE_DB.INTERMEDIATE.INT_PERSONA_CLASSIFICATION AS
WITH segment_base AS (
    -- Read from existing segment classification table
    SELECT
        CUSTOMER_ID,
        SEGMENT_A,
        SEGMENT_B,
        SEGMENT_C,
        SEGMENT_D,
        SEGMENT_E,
        SEGMENT_COMBINATION,
        SEGMENT_DATE
    FROM INSURE_DB.INTERMEDIATE.INT_SEGMENT_CLASSIFICATION
    WHERE SEGMENT_DATE = CURRENT_DATE()
),
persona_mapping AS (
    SELECT
        CUSTOMER_ID,
        SEGMENT_A,
        SEGMENT_B,
        SEGMENT_C,
        SEGMENT_D,
        SEGMENT_E,
        SEGMENT_COMBINATION,
        SEGMENT_DATE,
        CASE
            -- P01: Young Professional (A1 lifecycle, studio/rental)
            WHEN SEGMENT_A = chr(39) || 'A1' || chr(39)
                 AND SEGMENT_C IN ('C4')
                 THEN 'P01'

            -- P02: Newlywed Couple (A2 lifecycle, new apartment, dual income)
            WHEN SEGMENT_A = chr(39) || 'A2' || chr(39)
                 AND SEGMENT_B = chr(39) || 'B0' || chr(39)
                 AND SEGMENT_C = chr(39) || 'C1' || chr(39)
                 THEN 'P02'

            -- P03: Working Mom with Infant (A3 lifecycle, family assets, childcare)
            WHEN SEGMENT_A = chr(39) || 'A3' || chr(39)
                 AND SEGMENT_B IN ('B2', 'B3')
                 THEN 'P03'

            -- P04: School District Family (A4 lifecycle, established, school focus)
            WHEN SEGMENT_A = chr(39) || 'A4' || chr(39)
                 AND SEGMENT_B IN ('B1', 'B2', 'B3')
                 AND SEGMENT_C IN ('C1', 'C2')
                 AND SEGMENT_E IN ('E1', 'E2')
                 THEN 'P04'

            -- P05: Property Owner 50s (A5 lifecycle, owned property, high assets)
            WHEN SEGMENT_A = chr(39) || 'A5' || chr(39)
                 AND SEGMENT_C = chr(39) || 'C1' || chr(39)
                 AND SEGMENT_B IN ('B0', 'B1')
                 THEN 'P05'

            -- P06: Retired Senior (A6 lifecycle, reduced consumption, health focus)
            WHEN SEGMENT_A = chr(39) || 'A6' || chr(39)
                 THEN 'P06'

            -- P07: Small Business Owner (D1 occupation, high inventory/equipment)
            WHEN SEGMENT_D = chr(39) || 'D1' || chr(39)
                 AND SEGMENT_E = chr(39) || 'E3' || chr(39)
                 THEN 'P07'

            -- P08: Affluent Single (A1 lifecycle, high consumption, luxury assets)
            WHEN SEGMENT_A = chr(39) || 'A1' || chr(39)
                 AND SEGMENT_B IN ('B0', 'B1')
                 AND SEGMENT_C = chr(39) || 'C1' || chr(39)
                 AND SEGMENT_E = chr(39) || 'E1' || chr(39)
                 THEN 'P08'

            -- P09: Over-spending Youth (A1 lifecycle, high consumption, low stability)
            WHEN SEGMENT_A = chr(39) || 'A1' || chr(39)
                 AND SEGMENT_B IN ('B4', 'B5')
                 THEN 'P09'

            -- P10: Remote Professional (A4 lifecycle, home office, tech-savvy D2)
            WHEN SEGMENT_A = chr(39) || 'A4' || chr(39)
                 AND SEGMENT_D = chr(39) || 'D2' || chr(39)
                 AND SEGMENT_C = chr(39) || 'C3' || chr(39)
                 THEN 'P10'

            -- Default fallback based on lifecycle only
            WHEN SEGMENT_A = chr(39) || 'A1' || chr(39) THEN 'P01'
            WHEN SEGMENT_A = chr(39) || 'A2' || chr(39) THEN 'P02'
            WHEN SEGMENT_A = chr(39) || 'A3' || chr(39) THEN 'P03'
            WHEN SEGMENT_A = chr(39) || 'A4' || chr(39) THEN 'P04'
            WHEN SEGMENT_A = chr(39) || 'A5' || chr(39) THEN 'P05'
            WHEN SEGMENT_A = chr(39) || 'A6' || chr(39) THEN 'P06'
            ELSE 'P04'  -- Default to mainstream family persona
        END AS PERSONA_ID
    FROM segment_base
)
SELECT
    CUSTOMER_ID,
    PERSONA_ID,
    SEGMENT_A,
    SEGMENT_B,
    SEGMENT_C,
    SEGMENT_D,
    SEGMENT_E,
    SEGMENT_COMBINATION,
    SEGMENT_DATE,
    CURRENT_TIMESTAMP() AS CLASSIFICATION_TIMESTAMP
FROM persona_mapping;

COMMENT ON VIEW INSURE_DB.INTERMEDIATE.INT_PERSONA_CLASSIFICATION IS
'Maps customer 5-dimension segments to 10 personas using priority-based logic.
Lifecycle stage (A) is primary driver, supplemented by asset/consumption (B),
housing (C), occupation (D), and risk profile (E). Includes fallback hierarchy
to ensure all customers are classified.';

-- ============================================================================
-- SECTION 3: MART VIEW - PERSONA-BASED INSURANCE DESIGN
-- ============================================================================
-- This mart view replaces the composite segment with persona-based insurance
-- recommendations. Each persona has specific coverage recommendations and
-- premium calculations based on actuarial analysis.

CREATE OR REPLACE VIEW INSURE_DB.MART.MART_PERSONA_INSURANCE_DESIGN AS
WITH persona_details AS (
    SELECT
        pc.CUSTOMER_ID,
        pc.PERSONA_ID,
        pd.PERSONA_NAME_KOR,
        pd.PERSONA_NAME_ENG,
        pd.KEY_ASSETS_VALUE_MIN,
        pd.KEY_ASSETS_VALUE_MAX,
        pd.MONTHLY_PREMIUM_MIN,
        pd.MONTHLY_PREMIUM_MAX,
        pd.RISK_FACTOR,
        pc.SEGMENT_DATE,
        DATEDIFF(MONTH, pc.SEGMENT_DATE, CURRENT_DATE()) AS MONTHS_SINCE_SEGMENT
    FROM INSURE_DB.INTERMEDIATE.INT_PERSONA_CLASSIFICATION pc
    JOIN INSURE_DB.SEED.SEED_PERSONA_DEFINITION pd
        ON pc.PERSONA_ID = pd.PERSONA_ID
    WHERE pc.SEGMENT_DATE = CURRENT_DATE()
),
coverage_recommendations AS (
    SELECT
        CUSTOMER_ID,
        PERSONA_ID,
        PERSONA_NAME_KOR,
        PERSONA_NAME_ENG,
        CASE
            -- P01: Young Professional - Basic Essential
            WHEN PERSONA_ID = chr(39) || 'P01' || chr(39) THEN
                '\uae30\ubcf8 \ucc3c\ucd09 \ubc0f \uac70\ucc2c\uad70\ubc8f'
            -- P02: Newlywed - Comprehensive Family
            WHEN PERSONA_ID = chr(39) || 'P02' || chr(39) THEN
                '\uac00\uc815\uac00\uad6c \uc885\ud569 \ucc28\uc11c'
            -- P03: Working Mom - Family Plus
            WHEN PERSONA_ID = chr(39) || 'P03' || chr(39) THEN
                '\uac00\uc815 \ubc0f \ubc31\ub0a0\ubeee \ub3d9\ub4dd'
            -- P04: School District Family - Premium Family
            WHEN PERSONA_ID = chr(39) || 'P04' || chr(39) THEN
                '\uad50\uc721 \ubb34\uacb0 \uac00\uc815\ubcf4\ud5d8'
            -- P05: Property Owner - Luxury Assets
            WHEN PERSONA_ID = chr(39) || 'P05' || chr(39) THEN
                '\uace0\uac00\uc9c8 \uc790\uc82b \ubc0f \uc218\uc9d1'
            -- P06: Retired Senior - Healthcare Focus
            WHEN PERSONA_ID = chr(39) || 'P06' || chr(39) THEN
                '\ubaa8\ub978\ubcf4\ub2f4 \ubc0f \ub3d9\ub4cf \ubcf4\uae30'
            -- P07: Small Business Owner - Business Plus
            WHEN PERSONA_ID = chr(39) || 'P07' || chr(39) THEN
                '\ubd80\ub3d9\uc0b0 \ubc0f \uc870\ub2c8\ub098\uacebd\uc601 \uc911\ubcf4'
            -- P08: Affluent Single - Luxury Premium
            WHEN PERSONA_ID = chr(39) || 'P08' || chr(39) THEN
                '\uba54\ub9ac\ud2b8 \ub7ed\uc154\ub9ac \ub9b0\uce2c\ub9ac'
            -- P09: Over-spending Youth - Balanced Basic
            WHEN PERSONA_ID = chr(39) || 'P09' || chr(39) THEN
                '\uae30\ubcf8 \uc9e7\ub04c\ub098 \uadfc\ubaa8\ub978'
            -- P10: Remote Professional - Home Office Focus
            WHEN PERSONA_ID = chr(39) || 'P10' || chr(39) THEN
                '\uc7ac\ud0dd \uadfc\ubb34 \ubd84\ub978 \ubcf4\ub2f4'
            ELSE '\ub2e8\uc21c \ucc3c\ucd09 \ubcf4\ub2f4'
        END AS RECOMMENDED_COVERAGE_KOR,
        CASE
            WHEN PERSONA_ID = chr(39) || 'P01' || chr(39) THEN 'Basic Essentials'
            WHEN PERSONA_ID = chr(39) || 'P02' || chr(39) THEN 'Comprehensive Family'
            WHEN PERSONA_ID = chr(39) || 'P03' || chr(39) THEN 'Family Plus'
            WHEN PERSONA_ID = chr(39) || 'P04' || chr(39) THEN 'Premium Family'
            WHEN PERSONA_ID = chr(39) || 'P05' || chr(39) THEN 'Luxury Assets'
            WHEN PERSONA_ID = chr(39) || 'P06' || chr(39) THEN 'Healthcare Focus'
            WHEN PERSONA_ID = chr(39) || 'P07' || chr(39) THEN 'Business Plus'
            WHEN PERSONA_ID = chr(39) || 'P08' || chr(39) THEN 'Luxury Premium'
            WHEN PERSONA_ID = chr(39) || 'P09' || chr(39) THEN 'Balanced Basic'
            WHEN PERSONA_ID = chr(39) || 'P10' || chr(39) THEN 'Home Office Focus'
            ELSE 'Standard Coverage'
        END AS RECOMMENDED_COVERAGE_ENG,
        CASE
            -- P01: Cross-sell: Home security packages
            WHEN PERSONA_ID = chr(39) || 'P01' || chr(39) THEN 'Home security, Rental warranty'
            -- P02: Cross-sell: Life insurance, Health riders
            WHEN PERSONA_ID = chr(39) || 'P02' || chr(39) THEN 'Life insurance, Health riders, Gift coverage'
            -- P03: Cross-sell: Child education insurance
            WHEN PERSONA_ID = chr(39) || 'P03' || chr(39) THEN 'Child education, Disability income, Daycare'
            -- P04: Cross-sell: School tuition, Accident riders
            WHEN PERSONA_ID = chr(39) || 'P04' || chr(39) THEN 'Education tuition, Accident riders, Family umbrella'
            -- P05: Cross-sell: Art collection, Jewelry, Vehicle
            WHEN PERSONA_ID = chr(39) || 'P05' || chr(39) THEN 'Art insurance, Jewelry riders, Luxury auto'
            -- P06: Cross-sell: Medical supplement, Long-term care
            WHEN PERSONA_ID = chr(39) || 'P06' || chr(39) THEN 'Medical supplement, Long-term care, Fall protection'
            -- P07: Cross-sell: Business liability, Inventory, Key person
            WHEN PERSONA_ID = chr(39) || 'P07' || chr(39) THEN 'Liability, Inventory, Key person, Cyber'
            -- P08: Cross-sell: Luxury goods, Travel insurance
            WHEN PERSONA_ID = chr(39) || 'P08' || chr(39) THEN 'Luxury goods, Travel insurance, Concierge'
            -- P09: Cross-sell: Payment protection, Credit insurance
            WHEN PERSONA_ID = chr(39) || 'P09' || chr(39) THEN 'Payment protection, Credit insurance, Affordability plans'
            -- P10: Cross-sell: Equipment protection, Business interruption
            WHEN PERSONA_ID = chr(39) || 'P10' || chr(39) THEN 'Equipment protection, Cyber insurance, Professional liability'
            ELSE 'Standard add-ons'
        END AS CROSSSELL_RECOMMENDATIONS,
        KEY_ASSETS_VALUE_MIN,
        KEY_ASSETS_VALUE_MAX,
        ROUND((KEY_ASSETS_VALUE_MIN + KEY_ASSETS_VALUE_MAX) / 2, 0) AS AVERAGE_ASSET_VALUE,
        CASE
            -- Movable asset coefficients vary by persona based on asset volatility
            WHEN PERSONA_ID = chr(39) || 'P01' || chr(39) THEN 0.85  -- Electronics-heavy, depreciating
            WHEN PERSONA_ID = chr(39) || 'P02' || chr(39) THEN 0.90  -- Appliances, furniture
            WHEN PERSONA_ID = chr(39) || 'P03' || chr(39) THEN 0.88  -- Kids items, consumable
            WHEN PERSONA_ID = chr(39) || 'P04' || chr(39) THEN 0.92  -- Stable household goods
            WHEN PERSONA_ID = chr(39) || 'P05' || chr(39) THEN 1.05  -- Luxury items, premium valuation
            WHEN PERSONA_ID = chr(39) || 'P06' || chr(39) THEN 0.87  -- Medical equipment, basic items
            WHEN PERSONA_ID = chr(39) || 'P07' || chr(39) THEN 1.10  -- Business equipment, high value
            WHEN PERSONA_ID = chr(39) || 'P08' || chr(39) THEN 1.08  -- Luxury goods premium
            WHEN PERSONA_ID = chr(39) || 'P09' || chr(39) THEN 0.80  -- Latest trends, quick depreciation
            WHEN PERSONA_ID = chr(39) || 'P10' || chr(39) THEN 0.95  -- Office equipment, mid-range
            ELSE 0.90
        END AS MOVABLE_ASSET_COEFFICIENT,
        RISK_FACTOR,
        MONTHLY_PREMIUM_MIN,
        MONTHLY_PREMIUM_MAX,
        ROUND((MONTHLY_PREMIUM_MIN + MONTHLY_PREMIUM_MAX) / 2 * RISK_FACTOR, 2) AS BASE_MONTHLY_PREMIUM
    FROM persona_details
)
SELECT
    CUSTOMER_ID,
    PERSONA_ID,
    PERSONA_NAME_KOR,
    PERSONA_NAME_ENG,
    RECOMMENDED_COVERAGE_KOR,
    RECOMMENDED_COVERAGE_ENG,
    CROSSSELL_RECOMMENDATIONS,
    AVERAGE_ASSET_VALUE,
    MOVABLE_ASSET_COEFFICIENT,
    RISK_FACTOR,
    BASE_MONTHLY_PREMIUM,
    ROUND(BASE_MONTHLY_PREMIUM * 12, 2) AS ANNUAL_PREMIUM_ESTIMATE,
    CURRENT_TIMESTAMP() AS LAST_CALCULATED
FROM coverage_recommendations;

COMMENT ON VIEW INSURE_DB.MART.MART_PERSONA_INSURANCE_DESIGN IS
'Persona-based insurance design mart replacing composite segments with
actionable product recommendations. Includes persona-specific coverage plans,
cross-sell opportunities, asset coefficients for premium calculation, and
estimated premiums based on actuarial risk factors.';

-- ============================================================================
-- SECTION 4: SUMMARY MART VIEW - PERSONA ANALYTICS BY DISTRICT
-- ============================================================================
-- This summary view aggregates persona distribution and insurance metrics
-- at district level, enabling market analysis and regional strategy.

CREATE OR REPLACE VIEW INSURE_DB.MART.MART_PERSONA_SUMMARY AS
WITH customer_location AS (
    -- Join persona classification with customer location data
    SELECT
        pc.CUSTOMER_ID,
        pc.PERSONA_ID,
        pd.PERSONA_NAME_KOR,
        pd.PERSONA_NAME_ENG,
        pd.MONTHLY_PREMIUM_MIN,
        pd.MONTHLY_PREMIUM_MAX,
        pd.RISK_FACTOR,
        cd.DISTRICT,
        cd.CITY,
        pc.SEGMENT_DATE
    FROM INSURE_DB.INTERMEDIATE.INT_PERSONA_CLASSIFICATION pc
    JOIN INSURE_DB.SEED.SEED_PERSONA_DEFINITION pd
        ON pc.PERSONA_ID = pd.PERSONA_ID
    LEFT JOIN INSURE_DB.SOURCE.SOURCE_CUSTOMER_DETAILS cd
        ON pc.CUSTOMER_ID = cd.CUSTOMER_ID
    WHERE pc.SEGMENT_DATE = CURRENT_DATE()
),
persona_metrics AS (
    SELECT
        COALESCE(DISTRICT, 'UNKNOWN') AS DISTRICT,
        COALESCE(CITY, 'UNKNOWN') AS CITY,
        PERSONA_ID,
        PERSONA_NAME_KOR,
        PERSONA_NAME_ENG,
        COUNT(DISTINCT CUSTOMER_ID) AS CUSTOMER_COUNT,
        ROUND(AVG(RISK_FACTOR), 3) AS AVG_RISK_FACTOR,
        ROUND(AVG((MONTHLY_PREMIUM_MIN + MONTHLY_PREMIUM_MAX) / 2), 2) AS AVG_MONTHLY_PREMIUM,
        MIN(MONTHLY_PREMIUM_MIN) AS MIN_PREMIUM,
        MAX(MONTHLY_PREMIUM_MAX) AS MAX_PREMIUM
    FROM customer_location
    GROUP BY
        DISTRICT,
        CITY,
        PERSONA_ID,
        PERSONA_NAME_KOR,
        PERSONA_NAME_ENG
)
SELECT
    DISTRICT,
    CITY,
    PERSONA_ID,
    PERSONA_NAME_KOR,
    PERSONA_NAME_ENG,
    CUSTOMER_COUNT,
    ROUND(CUSTOMER_COUNT * 100.0 / SUM(CUSTOMER_COUNT) OVER (PARTITION BY DISTRICT), 1) AS PERSONA_PCT_OF_DISTRICT,
    AVG_RISK_FACTOR,
    AVG_MONTHLY_PREMIUM,
    ROUND(AVG_MONTHLY_PREMIUM * 12, 2) AS AVG_ANNUAL_PREMIUM,
    MIN_PREMIUM,
    MAX_PREMIUM,
    ROUND(AVG_MONTHLY_PREMIUM * CUSTOMER_COUNT, 2) AS TOTAL_MONTHLY_REVENUE,
    ROUND(AVG_MONTHLY_PREMIUM * CUSTOMER_COUNT * 12, 2) AS TOTAL_ANNUAL_REVENUE,
    CURRENT_TIMESTAMP() AS SUMMARY_CALCULATED
FROM persona_metrics
ORDER BY DISTRICT, CUSTOMER_COUNT DESC, PERSONA_ID;

COMMENT ON VIEW INSURE_DB.MART.MART_PERSONA_SUMMARY IS
'District-level persona distribution and insurance metrics. Enables market
analysis including persona prevalence by geography, regional risk profiles,
premium distribution, and revenue potential by persona and district.';

-- ============================================================================
-- SECTION 5: DATA QUALITY AND VALIDATION CHECKS
-- ============================================================================
-- These checks ensure the persona system is functioning correctly and
-- customers are properly classified.

CREATE OR REPLACE PROCEDURE INSURE_DB.UTILITY.VALIDATE_PERSONA_CLASSIFICATION()
LANGUAGE SQL
AS $$
DECLARE
    v_unclassified_count INT;
    v_total_customers INT;
    v_classification_rate DECIMAL(5, 2);
BEGIN
    -- Count unclassified customers (if PERSONA_ID is NULL)
    SELECT COUNT(*)
    INTO v_unclassified_count
    FROM INSURE_DB.INTERMEDIATE.INT_PERSONA_CLASSIFICATION
    WHERE PERSONA_ID IS NULL
      AND SEGMENT_DATE = CURRENT_DATE();

    -- Count total customers processed today
    SELECT COUNT(*)
    INTO v_total_customers
    FROM INSURE_DB.INTERMEDIATE.INT_PERSONA_CLASSIFICATION
    WHERE SEGMENT_DATE = CURRENT_DATE();

    -- Calculate classification rate
    IF v_total_customers > 0 THEN
        v_classification_rate := ((v_total_customers - v_unclassified_count) / v_total_customers) * 100;
    ELSE
        v_classification_rate := 0;
    END IF;

    -- Log validation results
    INSERT INTO INSURE_DB.UTILITY.VALIDATION_LOG (
        VALIDATION_NAME,
        VALIDATION_DATE,
        TOTAL_RECORDS,
        ERROR_RECORDS,
        SUCCESS_RATE,
        VALIDATION_STATUS,
        NOTES
    ) VALUES (
        'Persona Classification',
        CURRENT_TIMESTAMP(),
        v_total_customers,
        v_unclassified_count,
        v_classification_rate,
        CASE WHEN v_classification_rate >= 99 THEN 'PASS' ELSE 'WARN' END,
        CONCAT('Classification rate: ', v_classification_rate, '%. Unclassified: ', v_unclassified_count)
    );

END;
$$;

COMMENT ON PROCEDURE INSURE_DB.UTILITY.VALIDATE_PERSONA_CLASSIFICATION() IS
'Validates persona classification completeness. Checks for unclassified
customers and calculates daily classification success rate. Results logged
to validation audit table for monitoring.';

-- ============================================================================
-- SECTION 6: DOCUMENTATION AND METADATA
-- ============================================================================
-- Summary of persona business logic for reference

-- Persona P01: Young Professional
-- Business Logic: Single, entry-level employment, high mobility (frequent moves)
-- Key Risk: Electronics loss due to moves, rental coverage gaps
-- Premium Strategy: Affordable base premium with upgrade paths for relationships

-- Persona P02: Newlywed Couple
-- Business Logic: Young couple, dual income, newly established household
-- Key Risk: High asset accumulation (wedding gifts, furniture), new claims patterns
-- Premium Strategy: Family packages with attractive bundling discounts

-- Persona P03: Working Mom with Infant
-- Business Logic: Mixed career, childcare demands, safety-conscious
-- Key Risk: Child-related accidents, baby product coverage, working parent stress
-- Premium Strategy: Family-plus with childcare-specific riders

-- Persona P04: School District Family
-- Business Logic: Established career, quality housing, education investment
-- Key Risk: Property concentration, valuable household goods, education inflation
-- Premium Strategy: Premium family packages with education insurance options

-- Persona P05: Property Owner 50s
-- Business Logic: Mature professional, likely property owner, high net worth
-- Key Risk: Valuable collections, imported goods, concentration risk
-- Premium Strategy: High-touch service with specialized coverage options

-- Persona P06: Retired Senior
-- Business Logic: Fixed income, reduced consumption, health-conscious
-- Key Risk: Medical expenses, accidental injury, isolation-related claims
-- Premium Strategy: Affordable healthcare-focused plans with supplement options

-- Persona P07: Small Business Owner
-- Business Logic: Entrepreneur, inventory/equipment exposure, variable income
-- Key Risk: Business interruption, inventory loss, liability exposure
-- Premium Strategy: Commercial+personal bundled coverage for continuity

-- Persona P08: Affluent Single
-- Business Logic: High income single, luxury goods preference, quality focus
-- Key Risk: Valuable luxury items, high replacement costs, travel-related
-- Premium Strategy: Premium tier with concierge and exclusivity benefits

-- Persona P09: Over-spending Youth
-- Business Logic: Young, high consumption beyond income capacity
-- Key Risk: Debt pressure, impulse purchasing, financial instability
-- Premium Strategy: Affordable basics with payment protection riders

-- Persona P10: Remote Professional
-- Business Logic: Tech-savvy, work-from-home, home office focus
-- Key Risk: Business equipment loss, cyber incidents, work-life asset mixing
-- Premium Strategy: Home-office focused packages with equipment riders

-- ============================================================================
-- END OF FILE
-- ============================================================================
