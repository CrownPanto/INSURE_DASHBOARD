-- ============================================================================
-- File: 25_V1.6_SECURITY.sql
-- Purpose: INSURE Dynamic Insurance Engine - Enhanced Role & Security Model
-- Project: Snowflake Hackathon - Dynamic Insurance Product Adaptation
-- Author: INSURE Development Team
-- Version: 1.6
-- Date: 2026-04-06
-- ============================================================================
-- OVERVIEW:
-- This script implements a comprehensive security model with role hierarchy,
-- granular permissions, row-level access policies, and data masking for
-- sensitive insurance information.
--
-- KEY COMPONENTS:
-- 1. Role Hierarchy: ADMIN > ANALYST > VIEWER with inheritance
-- 2. Schema-level permissions: READ/WRITE access by role
-- 3. Row Access Policy: restrict raw data to admin roles
-- 4. Dynamic Data Masking: mask premium details for viewers
-- 5. Warehouse permissions: execution rights by role level
-- ============================================================================

USE DATABASE INSURE_DB;
USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- SECTION 1: ROLE HIERARCHY SETUP
-- ============================================================================
-- Three-tier role model for least privilege access
-- ADMIN: full control, can modify data
-- ANALYST: read intermediate/staging, can execute procedures
-- VIEWER: read-only on mart and analytics

CREATE ROLE IF NOT EXISTS INSURE_ADMIN;
CREATE ROLE IF NOT EXISTS INSURE_ANALYST;
CREATE ROLE IF NOT EXISTS INSURE_VIEWER;

-- Role hierarchy: ADMIN > ANALYST > VIEWER
-- Higher-level roles inherit lower-level permissions
GRANT ROLE INSURE_VIEWER TO ROLE INSURE_ANALYST;
GRANT ROLE INSURE_ANALYST TO ROLE INSURE_ADMIN;
GRANT ROLE INSURE_ADMIN TO ROLE SYSADMIN;

-- ============================================================================
-- SECTION 2: VIEWER ROLE - READ-ONLY MART & ANALYTICS
-- ============================================================================
-- Viewers can only see aggregated, processed data in MART and ANALYTICS
-- Cannot access raw data or staging tables

GRANT USAGE ON DATABASE INSURE_DB TO ROLE INSURE_VIEWER;

GRANT USAGE ON SCHEMA INSURE_DB.MART TO ROLE INSURE_VIEWER;
GRANT USAGE ON SCHEMA INSURE_DB.ANALYTICS TO ROLE INSURE_VIEWER;

GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.MART TO ROLE INSURE_VIEWER;
GRANT SELECT ON ALL VIEWS IN SCHEMA INSURE_DB.ANALYTICS TO ROLE INSURE_VIEWER;
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA INSURE_DB.INTERMEDIATE TO ROLE INSURE_VIEWER;

-- Grant future objects automatically
GRANT SELECT ON FUTURE TABLES IN SCHEMA INSURE_DB.MART TO ROLE INSURE_VIEWER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INSURE_DB.ANALYTICS TO ROLE INSURE_VIEWER;

-- ============================================================================
-- SECTION 3: ANALYST ROLE - INTERMEDIATE & STAGING READ + PROCEDURES
-- ============================================================================
-- Analysts can read staging/intermediate tables and execute procedures
-- Used for data engineers, business analysts, and modelers

GRANT USAGE ON SCHEMA INSURE_DB.INTERMEDIATE TO ROLE INSURE_ANALYST;
GRANT USAGE ON SCHEMA INSURE_DB.STAGING TO ROLE INSURE_ANALYST;
GRANT USAGE ON SCHEMA INSURE_DB.SEED TO ROLE INSURE_ANALYST;

GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.STAGING TO ROLE INSURE_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.SEED TO ROLE INSURE_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.INTERMEDIATE TO ROLE INSURE_ANALYST;

-- Grant procedure execution for analytics workflows
GRANT USAGE ON PROCEDURE INSURE_DB.ANALYTICS.SP_GENERATE_PERSONA_DESCRIPTION(VARCHAR) TO ROLE INSURE_ANALYST;

-- Grant future objects automatically
GRANT SELECT ON FUTURE TABLES IN SCHEMA INSURE_DB.STAGING TO ROLE INSURE_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA INSURE_DB.INTERMEDIATE TO ROLE INSURE_ANALYST;

-- ============================================================================
-- SECTION 4: ADMIN ROLE - FULL CONTROL
-- ============================================================================
-- Admins have complete control over all objects
-- Can modify structures, run DDL, and manage security

GRANT ALL ON DATABASE INSURE_DB TO ROLE INSURE_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE INSURE_DB TO ROLE INSURE_ADMIN;

-- Grant on all future schemas
GRANT ALL ON FUTURE SCHEMAS IN DATABASE INSURE_DB TO ROLE INSURE_ADMIN;

-- ============================================================================
-- SECTION 5: WAREHOUSE PERMISSIONS BY ROLE
-- ============================================================================
-- Control computational resources based on role level

GRANT USAGE ON WAREHOUSE INSURE_WH TO ROLE INSURE_VIEWER;
GRANT USAGE, OPERATE ON WAREHOUSE INSURE_WH TO ROLE INSURE_ANALYST;
GRANT ALL ON WAREHOUSE INSURE_WH TO ROLE INSURE_ADMIN;

-- ============================================================================
-- SECTION 6: ROW ACCESS POLICY - RESTRICT RAW DATA
-- ============================================================================
-- Sensitive raw accident/loss data restricted by role
-- ADMIN + ANALYST: full row access to raw tables
-- VIEWER + others: no access to raw data (use MART views instead)

CREATE OR REPLACE ROW ACCESS POLICY RAW_PUBLIC.RAP_SENSITIVE_DATA
AS (gu_name VARCHAR) RETURNS BOOLEAN ->
  CASE
    WHEN CURRENT_ROLE() IN ('INSURE_ADMIN', 'ACCOUNTADMIN') THEN TRUE
    WHEN CURRENT_ROLE() = 'INSURE_ANALYST' THEN TRUE
    WHEN CURRENT_ROLE() = 'INSURE_VIEWER' THEN FALSE
    ELSE FALSE
  END;

-- Apply policy to raw data tables
ALTER TABLE RAW_PUBLIC.ACCIDENT_LOSS_RAW ADD ROW ACCESS POLICY RAP_SENSITIVE_DATA ON (GU_NAME);
ALTER TABLE RAW_PUBLIC.MARKET_LOSS_DATA ADD ROW ACCESS POLICY RAP_SENSITIVE_DATA ON (GU_NAME);

-- ============================================================================
-- SECTION 7: DYNAMIC DATA MASKING - MASK PREMIUM VALUES
-- ============================================================================
-- Viewers see rounded/masked premium values, analysts and admins see actual
-- Protects sensitive pricing information from low-privilege users

CREATE OR REPLACE MASKING POLICY RAW_PUBLIC.MASK_PREMIUM_DETAIL
AS (val FLOAT) RETURNS FLOAT ->
  CASE
    WHEN CURRENT_ROLE() IN ('INSURE_ADMIN', 'INSURE_ANALYST', 'ACCOUNTADMIN') THEN val
    ELSE ROUND(val, -3)  -- Viewers see rounded values (nearest 1000) only
  END;

-- Apply masking policy to sensitive columns
ALTER TABLE MART.MART_DISTRICT_INSURANCE_SUMMARY MODIFY COLUMN BASE_PREMIUM SET MASKING POLICY MASK_PREMIUM_DETAIL;
ALTER TABLE MART.MART_DISTRICT_INSURANCE_SUMMARY MODIFY COLUMN ADJUSTED_PREMIUM SET MASKING POLICY MASK_PREMIUM_DETAIL;
ALTER TABLE INTERMEDIATE.INT_PURE_PREMIUM MODIFY COLUMN PURE_PREMIUM SET MASKING POLICY MASK_PREMIUM_DETAIL;

-- ============================================================================
-- SECTION 8: ASSIGN USERS TO ROLES
-- ============================================================================
-- Grant current development user ADMIN role

GRANT ROLE INSURE_ADMIN TO USER CROWNPANTO;

-- ============================================================================
-- SECTION 9: VERIFY SECURITY SETUP
-- ============================================================================
-- Show created roles and their hierarchy

SELECT 'Role Hierarchy Setup Complete' AS status;

SHOW ROLES IN ACCOUNT;
SHOW GRANTS ON ROLE INSURE_ADMIN;
SHOW GRANTS ON ROLE INSURE_ANALYST;
SHOW GRANTS ON ROLE INSURE_VIEWER;

