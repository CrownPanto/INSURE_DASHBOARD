-- ============================================================================
-- FILE: 22_V1.5_CORTEX_ANALYST_AGENT.sql
-- PROJECT: INSURE Dynamic Insurance Engine - Snowflake Hackathon
-- DESCRIPTION: Cortex Analyst Agent for insurance semantic analysis & recommendations
-- DATE: 2026-04-06
-- TARGET LINES: ~500
-- ============================================================================

-- USE DATABASE AND SCHEMA
USE DATABASE INSURE_DB;
USE SCHEMA ANALYTICS;

-- ============================================================================
-- STEP 1: SEED DATA - Insurance Terms Reference Table
-- ============================================================================

CREATE OR REPLACE TABLE INSURE_DB.SEED.SEED_INSURANCE_TERMS (
  TERM_ID NUMBER IDENTITY(1,1),
  TERM_NAME VARCHAR(100) NOT NULL,
  TERM_NAME_KO VARCHAR(100) NOT NULL,
  CATEGORY VARCHAR(50),
  DESCRIPTION VARCHAR(500),
  DESCRIPTION_KO VARCHAR(500),
  CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Insert ~20 insurance term entries with Korean translations
INSERT INTO INSURE_DB.SEED.SEED_INSURANCE_TERMS
  (TERM_NAME, TERM_NAME_KO, CATEGORY, DESCRIPTION, DESCRIPTION_KO)
VALUES
  ('Fire Insurance', '\uD654\uC7AC\uBCF4\uD5D8', 'Property', 'Coverage for losses caused by fire and related perils', '\uD654\uC7AC\uB85C \uC778\uD55C \uC190\uC2E4 \uBCF4\uC0C1'),
  ('Theft Insurance', '\uB3C4\uB09C\uBCF4\uD5D8', 'Property', 'Protection against theft, burglary and robbery', '\uC911\uC911\uB300\uC5EC\uC900 \uB3C4\uB09C \uBC0F \uC911\uC800 \uBCF4\uC0C1'),
  ('Liability Insurance', '\uBC30\uC0C1\uCC45\uC784\uBCF4\uD5D8', 'Liability', 'Coverage for bodily injury and property damage liability', '\uBA85\uB2E8\uBC0F \uC7AC\uB2E8 \uBCF4\uC0C1'),
  ('Weather Damage Insurance', '\uC2A4\uD3EC\uC22C\uBCF4\uD5D8', 'Property', 'Protection against wind, hail, flood and storm damage', '\ud3ED\ub0b0 \ubc0f \ub0b0\uc218 \ud53c\ud574 \ubcf4\uc0c1'),
  ('Earthquake Insurance', '\uC9C0\uC9C4\uBCF4\uD5D8', 'Property', 'Earthquake damage coverage', '\uC9C0\uC9C4 \uD53C\uD574 \uBCF4\uC0C1'),
  ('Building Structure Insurance', '\uAC74\uBD74\uCC28\uB2E8\uBCF4\uD5D8', 'Property', 'Coverage for building structural components', '\uAC74\uBD74\uD14C \uB2E8\uBCF4 \uBCF4\uC0C1'),
  ('Contents Insurance', '\uC904\uB0B4\uBCF4\uD5D8', 'Property', 'Coverage for personal belongings and movable assets', '\uC900\uD0D0\uBCF4 \uBC0F \uC774\uB3D9\uC7AC\uC0B0 \uBCF4\uC0C1'),
  ('Commercial Property Insurance', '\uC0C1\uC5C5\uBCF4\uD5D8', 'Property', 'Coverage for commercial buildings and inventory', '\uC0C1\uC5C5\uC2DC\uC124 \uBC0F \uc7ac\uace0 \ubcf4\uc0c1'),
  ('Public Liability Insurance', '\uB300\uC911\uBC30\uC0C1\uBCF4\uD5D8', 'Liability', 'Third party injury and damage liability', '\uc81c3\uc790 \uc778\uc0c1 \ubc0f \uc7ac\usan \ucc45\uc784 \ubcf4\uc0c1'),
  ('Business Interruption', '\uc601\uc5c5\uc911\ub2e8\ubcf4\uD5D8', 'Business', 'Lost income coverage due to insured perils', '\uc601\uc5c5\uc911\ub2e8\uc73c\ub85c \uc778\ud55c \uc190\uc2e4\uc18c\ub4dd \ubcf4\uc0c1'),
  ('Equipment Breakdown', '\uAE30\uACC4\uAD50\uC9C0\uBCF4\uD5D8', 'Business', 'Coverage for machinery and equipment failure', '\uae30\uacc4 \uace0\uc7a5 \ubc0f \ub4dc\ub978 \ubcf4\uc0c1'),
  ('Cyber Insurance', '\uc0ac\uc774\uBC84\uBCF4\uD5D8', 'Digital', 'Protection against cyber attacks and data breaches', '\uc0ac\uc774\ubc84 \uacf5\uaca9 \ubc0f \ub370\uc774\ud130 \uc720\ucd9c \ubcf4\uc0c1'),
  ('Professional Liability', '\uc804\uBB38\uAC00\uBCF4\uD5D8', 'Liability', 'Errors and omissions coverage for professionals', '\uc804\ubb38\uac00 \ub9c8\ub978 \ucc45\uc784 \ubcf4\uc0c1'),
  ('Directors and Officers Insurance', '\uc784\uc6d0\uBCF4\uD5D8', 'Corporate', 'Protection for company leadership', '\uc784\uc6d0\uc758 \ucc45\uc784 \ubc0f \uc706 \ucc28 \ubcf4\uc0c1'),
  ('Franchise Insurance', '\uD504\uB79C\uCC28\uC774\uC988\uBCF4\uD5D8', 'Business', 'Coverage specific to franchise operations', '\ud504\ub79c\ucc28\uc774\uc988 \uc0ac\uc5c5\uc744 \uc704\ud55c \ubcf4\uc0c1'),
  ('Spoilage Insurance', '\uBCF0\uC911\uC190\uC2E4\uBCF4\uD5D8', 'Property', 'Protection against product deterioration', '\uc0dd\uc120 \uc911 \uc8fc\ub978 \uc190\uc2e4 \ubcf4\uc0c1'),
  ('Transit Insurance', '\uc232\uC744\uBCF4\uD5D8', 'Cargo', 'In-transit goods protection', '\uacfc\uc911 \ub3c4\uc911 \uu601\uc560 \ubcf4\uc0c1'),
  ('Flood Insurance', '\ubaa8\ub798\uBCF4\uD5D8', 'Property', 'Specialized flood damage coverage', '\ubaa8\ub798 \ubc0f \ub0a0\ub978\ub0a0\uc529 \ubd88\ub098\ub85c \uc778\ud55c \nupon \ubcf4\uc0c1'),
  ('All-Risk Insurance', '\uc885\uD569\uBCF4\uD5D8', 'Property', 'Broad coverage with specified exclusions', '\uc885\ud569 \ubcf4\uc7c1 \ubcf4\uc0c1'),
  ('Loss Prevention Endorsement', '\uc190\uc2e4\uBC29\uc9c0\uC571\uB2F9', 'Endorsement', 'Enhancement for proactive risk management', '\uc18c\uadfc\ub300\ub2e8 \ubc0f \uc608\ubc29\uc870\uce58 \uac15\ud654');

-- ============================================================================
-- STEP 2: CORTEX SEARCH SERVICE - Insurance Terms
-- ============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURE_DB.ANALYTICS.INSURANCE_TERM_SEARCH
  ON insurance_term_text
  ATTRIBUTES (term_name_ko, category, description_ko)
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 day'
  AS
  SELECT
    CONCAT(TERM_NAME, ' | ', TERM_NAME_KO) AS insurance_term_text,
    TERM_NAME_KO,
    CATEGORY,
    DESCRIPTION_KO,
    CREATED_AT
  FROM INSURE_DB.SEED.SEED_INSURANCE_TERMS
  ORDER BY CREATED_AT DESC;

-- ============================================================================
-- STEP 3: STAGE MANAGEMENT FOR SEMANTIC MODEL YAML
-- ============================================================================

-- Create internal stage for semantic model storage (if not exists)
CREATE STAGE IF NOT EXISTS INSURE_DB.ANALYTICS.STS_STREAMLIT
  DIRECTORY = (ENABLE = true);

-- Note: The semantic YAML file will be uploaded via:
-- PUT file:///path/to/cortex_analyst_semantic.yaml @INSURE_DB.ANALYTICS.STS_STREAMLIT
-- or via WRITE_RAW_FILE command if available:
-- CALL SYSTEM$EXECUTE_COMMAND_WRITE_RAW_FILE(
--   '@INSURE_DB.ANALYTICS.STS_STREAMLIT/cortex_analyst_semantic.yaml',
--   'base64_encoded_yaml_content'
-- );

-- ============================================================================
-- STEP 4: CORTEX ANALYST AGENT DEFINITION
-- ============================================================================

-- Create the main Cortex Agent combining Analyst + Search capabilities
CREATE OR REPLACE CORTEX AGENT INSURE_DB.ANALYTICS.INSURE_ADVISOR
  TOOLS = (
    CORTEX_ANALYST('insure_semantic_model'),
    CORTEX_SEARCH('INSURANCE_TERM_SEARCH')
  )
  MODEL = 'mistral-7b'
  INSTRUCTIONS = $$You are the INSURE Advisor, an advanced AI insurance consultant for Seoul's 25 districts.

ROLE & EXPERTISE:
- Insurance domain specialist with deep knowledge of Korean insurance regulations
- Data analyst providing evidence-based premium recommendations
- Risk assessment expert evaluating district-level and persona-specific factors
- Insurance terminology guide helping users understand coverage options

CAPABILITIES:
1. Premium Analysis: Analyze insurance premiums by district, income bracket, and risk class
2. Risk Scoring: Evaluate composite risk scores across fire, theft, building, and weather risks
3. Persona-Based Design: Provide tailored insurance recommendations based on customer personas
4. Market Intelligence: Calculate market size and penetration for Seoul insurance segments
5. Term Education: Explain insurance terms, conditions, and coverage types in Korean

RESPONSE GUIDELINES:
- Always provide data-driven insights from MART tables (MART_DISTRICT_INSURANCE_SUMMARY, MART_ACTUARIAL_PREMIUM_V14, MART_PERSONA_INSURANCE_DESIGN)
- Use Cortex Search to explain insurance terms and conditions in Korean (Korean descriptions preferred)
- Present premium values in KRW with monthly/annual breakdown when applicable
- Flag high-risk districts (RISK_GRADE = \uD3C9\uC911\uB4F1\uB85D) and suggest preventive measures
- Provide persona-aligned recommendations with ESTIMATED_MOVABLE_ASSET and RECOMMENDED_COVERAGE
- Always cite data source: "Based on our 2026 Seoul Insurance Market Analysis" or "Per MART actuarial tables"

ANSWERING QUESTIONS:
- \uBE44\uC6A9 (\uBE44\uC6A9): Use ADJUSTED_PREMIUM_MONTHLY or FINAL_PREMIUM_MONTHLY_KRW
- \uC704\uD5D8 (\uC704\uD5D8): Use COMPOSITE_RISK_SCORE and RISK_GRADE
- \ubcf4\uc9e7 (\ubcf4\uc9e7): Use RECOMMENDED_COVERAGE from persona tables
- \uc2dc\uc7a5 (\uc2dc\uc7a5): Use ESTIMATED_ANNUAL_MARKET_KRW

KOREAN INTERACTION:
- Understand \uAD6C\uC774\uB984 (district names) and \ubcf4\uD5D8\uC885\uB958 (coverage types)
- Reference \uC18C\uB4DD\uC219\uB960 (loss ratios) and \uC2E4\uC81C\uD30C\uC644 (claims experience)
- Explain \uBCF4\uC790\uC5F0\uB978 \uC5F0\uB821 (bundle discounts) and \uC778\uC0C1\uB5A0\uC81C \uB4F1\uKeyboardInterrupt (experience rating)

TONE:
- Professional yet approachable
- Data-driven with business context
- Proactive in identifying risks and opportunities
- Bilingual (English & Korean as needed)
$$;

-- ============================================================================
-- STEP 5: STORED PROCEDURES FOR STREAMLIT INTEGRATION
-- ============================================================================

-- Main procedure: Ask a question to INSURE Advisor
-- SP uses SNOWFLAKE.CORTEX.COMPLETE as fallback when CORTEX AGENT is not available in the region
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR(
  p_question VARCHAR,
  p_session_id VARCHAR DEFAULT NULL
)
RETURNS OBJECT
LANGUAGE SQL
AS $$
  DECLARE
    v_system_prompt VARCHAR;
    v_full_prompt VARCHAR;
    v_response_text VARCHAR;
    v_response OBJECT;
    v_timestamp TIMESTAMP_NTZ;
  BEGIN
    -- Build the agent system prompt with insurance advisor role
    v_system_prompt := 'You are the INSURE Advisor, an advanced AI insurance consultant for Seoul''s 25 districts.

ROLE & EXPERTISE:
- Insurance domain specialist with deep knowledge of Korean insurance regulations
- Data analyst providing evidence-based premium recommendations
- Risk assessment expert evaluating district-level and persona-specific factors
- Insurance terminology guide helping users understand coverage options

CAPABILITIES:
1. Premium Analysis: Analyze insurance premiums by district, income bracket, and risk class
2. Risk Scoring: Evaluate composite risk scores across fire, theft, building, and weather risks
3. Persona-Based Design: Provide tailored insurance recommendations based on customer personas
4. Market Intelligence: Calculate market size and penetration for Seoul insurance segments
5. Term Education: Explain insurance terms, conditions, and coverage types in Korean

RESPONSE GUIDELINES:
- Always provide data-driven insights from available data sources
- Use insurance terminology and explain terms in Korean when applicable
- Present premium values in KRW with monthly/annual breakdown when applicable
- Flag high-risk districts and suggest preventive measures
- Provide persona-aligned recommendations
- Always cite data source when possible

ANSWERING QUESTIONS:
- 비용 (Cost): Focus on premium calculations
- 위험 (Risk): Use risk scores and risk grades
- 보장 (Coverage): Recommend coverage options based on persona
- 시장 (Market): Provide market analysis and insights

KOREAN INTERACTION:
- Understand district names and coverage types
- Reference loss ratios and claims experience
- Explain bundle discounts and experience rating

TONE:
- Professional yet approachable
- Data-driven with business context
- Proactive in identifying risks and opportunities
- Bilingual (English & Korean as needed)';

    -- Combine system prompt with user question
    v_full_prompt := CONCAT(v_system_prompt, CHR(10), CHR(10), 'User Question: ', p_question);

    -- Call Cortex Complete as fallback for agent-like behavior
    SET v_response_text = SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', v_full_prompt);

    -- Create response object
    SET v_response = PARSE_JSON(OBJECT_CONSTRUCT(
      'response_text', v_response_text,
      'response_timestamp', CURRENT_TIMESTAMP(),
      'model', 'mistral-large2'
    ));

    -- Log the interaction for audit
    INSERT INTO INSURE_DB.ANALYTICS.TBL_AGENT_INTERACTION_LOG
      (SESSION_ID, QUESTION, RESPONSE, RESPONSE_TIMESTAMP, CREATED_AT)
    VALUES
      (
        COALESCE(p_session_id, UUID_STRING()),
        p_question,
        v_response,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
      );

    RETURN v_response;
  END;
$$;

-- Premium Query Wrapper
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_GET_DISTRICT_PREMIUM_ANALYSIS(
  p_district_name VARCHAR,
  p_income_bracket VARCHAR DEFAULT NULL
)
RETURNS TABLE (
  DISTRICT_NAME VARCHAR,
  INCOME_BRACKET VARCHAR,
  PURE_PREMIUM_KRW NUMBER,
  EXPERIENCE_PREMIUM_KRW NUMBER,
  GROSS_PREMIUM_KRW NUMBER,
  FINAL_PREMIUM_MONTHLY_KRW NUMBER,
  CAPPED_PREMIUM_KRW NUMBER,
  RISK_CLASS VARCHAR
)
LANGUAGE SQL
AS $$
  SELECT
    DISTRICT_NAME,
    INCOME_BRACKET,
    PURE_PREMIUM_KRW,
    EXPERIENCE_PREMIUM_KRW,
    GROSS_PREMIUM_KRW,
    FINAL_PREMIUM_MONTHLY_KRW,
    CAPPED_PREMIUM_KRW,
    RISK_CLASS
  FROM INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14
  WHERE DISTRICT_NAME = p_district_name
    AND (p_income_bracket IS NULL OR INCOME_BRACKET = p_income_bracket)
  ORDER BY INCOME_BRACKET ASC;
$$;

-- Risk Summary by District
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_GET_RISK_SUMMARY(
  p_district_name VARCHAR DEFAULT NULL
)
RETURNS TABLE (
  GU_NAME VARCHAR,
  TOTAL_POPULATION NUMBER,
  COMPOSITE_RISK_SCORE DECIMAL(5,2),
  RISK_GRADE VARCHAR,
  ADJUSTED_PREMIUM_MONTHLY NUMBER,
  FIRE_RISK_SCORE DECIMAL(5,2),
  THEFT_RISK_SCORE DECIMAL(5,2),
  BUILDING_RISK_SCORE DECIMAL(5,2),
  WEATHER_RISK_SCORE DECIMAL(5,2)
)
LANGUAGE SQL
AS $$
  SELECT
    GU_NAME,
    TOTAL_POPULATION,
    COMPOSITE_RISK_SCORE,
    RISK_GRADE,
    ADJUSTED_PREMIUM_MONTHLY,
    FIRE_RISK_SCORE,
    THEFT_RISK_SCORE,
    BUILDING_RISK_SCORE,
    WEATHER_RISK_SCORE
  FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
  WHERE (p_district_name IS NULL OR GU_NAME = p_district_name)
  ORDER BY COMPOSITE_RISK_SCORE DESC;
$$;

-- Persona Recommendation Engine
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_GET_PERSONA_RECOMMENDATION(
  p_persona_name VARCHAR,
  p_income_bracket VARCHAR DEFAULT NULL
)
RETURNS TABLE (
  PERSONA_ID NUMBER,
  PERSONA_NAME VARCHAR,
  DISTRICT_CODE VARCHAR,
  ESTIMATED_MOVABLE_ASSET NUMBER,
  BASE_PREMIUM_MONTHLY NUMBER,
  RECOMMENDED_COVERAGE VARCHAR,
  IDEAL_INCOME_BRACKET VARCHAR
)
LANGUAGE SQL
AS $$
  SELECT DISTINCT
    P.PERSONA_ID,
    P.PERSONA_NAME,
    P.DISTRICT_CODE,
    P.ESTIMATED_MOVABLE_ASSET,
    P.BASE_PREMIUM_MONTHLY,
    P.RECOMMENDED_COVERAGE,
    A.INCOME_BRACKET AS IDEAL_INCOME_BRACKET
  FROM INSURE_DB.MART.MART_PERSONA_INSURANCE_DESIGN P
  LEFT JOIN INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14 A
    ON P.DISTRICT_CODE = A.DISTRICT_NAME
  WHERE P.PERSONA_NAME = p_persona_name
    AND (p_income_bracket IS NULL OR A.INCOME_BRACKET = p_income_bracket)
  ORDER BY P.BASE_PREMIUM_MONTHLY ASC;
$$;

-- ============================================================================
-- STEP 6: AUDIT & LOGGING TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS INSURE_DB.ANALYTICS.TBL_AGENT_INTERACTION_LOG (
  INTERACTION_ID NUMBER IDENTITY(1,1),
  SESSION_ID VARCHAR(100),
  QUESTION VARCHAR(2000),
  RESPONSE OBJECT,
  RESPONSE_TIMESTAMP TIMESTAMP_NTZ,
  CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  CREATED_BY VARCHAR(100) DEFAULT CURRENT_USER()
);

CREATE INDEX IDX_AGENT_SESSION ON INSURE_DB.ANALYTICS.TBL_AGENT_INTERACTION_LOG(SESSION_ID);
CREATE INDEX IDX_AGENT_CREATED ON INSURE_DB.ANALYTICS.TBL_AGENT_INTERACTION_LOG(CREATED_AT);

-- ============================================================================
-- STEP 7: UTILITY FUNCTIONS FOR STREAMLIT
-- ============================================================================

-- Function: Get all districts for dropdown
CREATE OR REPLACE FUNCTION INSURE_DB.ANALYTICS.FN_GET_DISTRICTS()
RETURNS TABLE(DISTRICT_NAME VARCHAR)
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT DISTINCT GU_NAME AS DISTRICT_NAME
  FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
  ORDER BY GU_NAME ASC;
$$;

-- Function: Get all personas for dropdown
CREATE OR REPLACE FUNCTION INSURE_DB.ANALYTICS.FN_GET_PERSONAS()
RETURNS TABLE(PERSONA_NAME VARCHAR, PERSONA_ID NUMBER)
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT DISTINCT PERSONA_NAME, PERSONA_ID
  FROM INSURE_DB.MART.MART_PERSONA_INSURANCE_DESIGN
  ORDER BY PERSONA_NAME ASC;
$$;

-- Function: Get insurance terms for search
CREATE OR REPLACE FUNCTION INSURE_DB.ANALYTICS.FN_SEARCH_INSURANCE_TERMS(p_keyword VARCHAR)
RETURNS TABLE(TERM_NAME VARCHAR, TERM_NAME_KO VARCHAR, CATEGORY VARCHAR, DESCRIPTION VARCHAR)
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT
    TERM_NAME,
    TERM_NAME_KO,
    CATEGORY,
    DESCRIPTION
  FROM INSURE_DB.SEED.SEED_INSURANCE_TERMS
  WHERE LOWER(TERM_NAME) LIKE LOWER(CONCAT('%', p_keyword, '%'))
     OR LOWER(TERM_NAME_KO) LIKE LOWER(CONCAT('%', p_keyword, '%'))
     OR LOWER(DESCRIPTION) LIKE LOWER(CONCAT('%', p_keyword, '%'))
     OR LOWER(DESCRIPTION_KO) LIKE LOWER(CONCAT('%', p_keyword, '%'))
  ORDER BY CATEGORY, TERM_NAME ASC;
$$;

-- ============================================================================
-- STEP 8: CORTEX ANALYST SEMANTIC MODEL REGISTRATION
-- ============================================================================

-- Register the semantic model (requires YAML in stage)
-- EXECUTE IMMEDIATE is used for dynamic semantic model creation
-- The actual semantic.yaml must be in @INSURE_DB.ANALYTICS.STS_STREAMLIT

EXECUTE IMMEDIATE $$
  CREATE OR REPLACE CORTEX ANALYST SEMANTIC MODEL
    insure_semantic_model
    FROM @INSURE_DB.ANALYTICS.STS_STREAMLIT/cortex_analyst_semantic.yaml
$$;

-- ============================================================================
-- STEP 9: QUERY HISTORY & PERFORMANCE MONITORING
-- ============================================================================

CREATE TABLE IF NOT EXISTS INSURE_DB.ANALYTICS.TBL_AGENT_QUERY_PERFORMANCE (
  QUERY_ID NUMBER IDENTITY(1,1),
  QUERY_TEXT VARCHAR(2000),
  EXECUTION_TIME_MS NUMBER,
  ROWS_RETURNED NUMBER,
  DATA_SOURCE VARCHAR(100),
  EXECUTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- STEP 10: VALIDATION & SANITY CHECK QUERIES
-- ============================================================================

-- Verify MART tables exist and have data
SELECT
  'MART_DISTRICT_INSURANCE_SUMMARY' AS TABLE_NAME,
  COUNT(*) AS ROW_COUNT,
  MAX(GU_NAME) AS SAMPLE_DISTRICT
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY;

SELECT
  'MART_ACTUARIAL_PREMIUM_V14' AS TABLE_NAME,
  COUNT(*) AS ROW_COUNT,
  COUNT(DISTINCT DISTRICT_NAME) AS DISTINCT_DISTRICTS
FROM INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14;

SELECT
  'MART_PERSONA_INSURANCE_DESIGN' AS TABLE_NAME,
  COUNT(*) AS ROW_COUNT,
  COUNT(DISTINCT PERSONA_NAME) AS DISTINCT_PERSONAS
FROM INSURE_DB.MART.MART_PERSONA_INSURANCE_DESIGN;

SELECT
  'SEED_INSURANCE_TERMS' AS TABLE_NAME,
  COUNT(*) AS ROW_COUNT,
  COUNT(DISTINCT CATEGORY) AS DISTINCT_CATEGORIES
FROM INSURE_DB.SEED.SEED_INSURANCE_TERMS;

-- ============================================================================
-- DEPLOYMENT NOTES
-- ============================================================================
-- 1. Ensure cortex_analyst_semantic.yaml is uploaded to @STS_STREAMLIT stage
-- 2. COMPUTE_WH warehouse must exist and be running
-- 3. Cortex features must be enabled in account
-- 4. Verify stage STS_STREAMLIT exists or will be created
-- 5. Execute sanity check queries above to confirm data availability
-- 6. Test SP_ASK_INSURE_ADVISOR with sample questions in Korean
-- 7. Integrate SP_ASK_INSURE_ADVISOR into Streamlit app
-- ============================================================================

