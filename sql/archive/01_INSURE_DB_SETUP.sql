-- ============================================================
-- INSURE 프로젝트: 데이터베이스 및 스키마 초기 설정
-- 동산보험 동적 설계 데이터 엔진 (CrownPanto)
-- ============================================================

-- 1. 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS INSURE_DB
  COMMENT = 'INSURE: 동산보험 동적 설계 데이터 엔진 - Snowflake Hackathon 2025Q2';

USE DATABASE INSURE_DB;

-- 2. 스키마 생성 (dbt 3계층 + 공공데이터 + 분석)
CREATE SCHEMA IF NOT EXISTS RAW_PUBLIC
  COMMENT = '공공데이터 원본 적재 (화재/범죄/건물노후/기상/CCTV/1인가구/실거래/소방/가전사고)';

CREATE SCHEMA IF NOT EXISTS STAGING
  COMMENT = 'dbt staging: 원본 테이블 정규화 뷰';

CREATE SCHEMA IF NOT EXISTS INTERMEDIATE
  COMMENT = 'dbt intermediate: 세그먼트 분류 + 리스크 스코어 산출';

CREATE SCHEMA IF NOT EXISTS MART
  COMMENT = 'dbt mart: 보험 설계 최종 테이블 (세그먼트 x 구 x 보험료)';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
  COMMENT = 'Cortex Analyst + ML 분석용 뷰/테이블';

CREATE SCHEMA IF NOT EXISTS FEEDBACK
  COMMENT = '상담 피드백 루프 데이터';

-- 3. 웨어하우스 확인
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA RAW_PUBLIC;

SELECT 'INSURE_DB setup complete' AS status;
