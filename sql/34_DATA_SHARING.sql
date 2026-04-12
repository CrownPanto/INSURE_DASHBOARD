-- ============================================================
-- 34_DATA_SHARING.sql
-- Snowflake Data Sharing: 보험사 파트너 데이터 공유
-- "보험사가 INSURE 위험도 데이터를 자사 시스템에서 직접 구독"
-- Date: 2026-04-12
-- ============================================================
--
-- 활용 목적:
--   B2B2C 비즈니스 모델에서 보험사 파트너(손해보험사)에게
--   서울시 구별 위험도 데이터를 Snowflake Data Share로 제공.
--   보험사는 별도 ETL 없이 자사 Snowflake 계정에서 직접 조회 가능.
--
-- 공유 대상 (읽기 전용):
--   1) MART_DISTRICT_INSURANCE_SUMMARY  — 구별 보험료/위험도 요약
--   2) MART_PREMIUM_LAYER               — 7단계 보험료 레이어 (익명화)
--   3) V_FIRE_FORECAST_V13              — Cortex Forecast 예측 결과
--
-- 보안:
--   - Row Access Policy: 계정별 접근 구 제한 가능 (향후 확장)
--   - PII 컬럼 (개인 식별 정보) 포함 안 됨 (구 단위 집계만 공유)
-- ============================================================

USE DATABASE INSURE_DB;
USE ROLE ACCOUNTADMIN;  -- Share 생성은 ACCOUNTADMIN 필요


-- ============================================================
-- STEP 1: Share 객체 생성
-- ============================================================
CREATE SHARE IF NOT EXISTS INSURE_RISK_SHARE
    COMMENT = 'INSURE 서울시 구별 위험도 및 보험료 데이터 공유 (Team 까레이스키, Snowflake Hackathon 2026)';


-- ============================================================
-- STEP 2: 공유 대상 DB/스키마 권한 부여
-- ============================================================
GRANT USAGE ON DATABASE INSURE_DB TO SHARE INSURE_RISK_SHARE;
GRANT USAGE ON SCHEMA INSURE_DB.MART TO SHARE INSURE_RISK_SHARE;
GRANT USAGE ON SCHEMA INSURE_DB.ANALYTICS TO SHARE INSURE_RISK_SHARE;


-- ============================================================
-- STEP 3: 테이블/뷰 공유 등록
-- ============================================================

-- 3-1. 구별 보험료/위험도 요약 (핵심 데이터)
GRANT SELECT ON TABLE INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
    TO SHARE INSURE_RISK_SHARE;

-- 3-2. 보험료 레이어 분해 (7단계 파이프라인 결과)
GRANT SELECT ON TABLE INSURE_DB.MART.MART_PREMIUM_LAYER
    TO SHARE INSURE_RISK_SHARE;

-- 3-3. Cortex FORECAST 예측 결과 뷰 (화재 발생 예측)
GRANT SELECT ON VIEW INSURE_DB.ANALYTICS.V_FIRE_FORECAST_V13
    TO SHARE INSURE_RISK_SHARE;


-- ============================================================
-- STEP 4: 공유 전용 요약 뷰 생성 (PII 제거 + 익명화)
-- ============================================================

-- 보험사 파트너용 집계 뷰: 개인 정보 없이 구 단위 집계만 제공
CREATE OR REPLACE SECURE VIEW INSURE_DB.MART.V_SHARED_RISK_SUMMARY
    COMMENT = 'Data Share용 익명화 위험도 요약 — PII 없음, 구 단위 집계'
AS
SELECT
    DISTRICT_NAME                           AS 구명,
    YEAR_MONTH                              AS 기준월,
    ROUND(COMPOSITE_RISK_SCORE, 2)          AS 종합위험점수,
    RISK_GRADE                              AS 위험등급,
    ROUND(FIRE_RISK_SCORE, 2)               AS 화재위험점수,
    ROUND(THEFT_RISK_SCORE, 2)              AS 도난위험점수,
    ROUND(BUILDING_RISK_SCORE, 2)           AS 건물위험점수,
    ROUND(WEATHER_RISK_SCORE, 2)            AS 기상위험점수,
    ROUND(ADJUSTED_PREMIUM_MONTHLY, 0)      AS 월평균보험료_원,
    ROUND(ESTIMATED_ANNUAL_MARKET_KRW / 1e8, 1) AS 연간시장규모_억원
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
WHERE YEAR_MONTH >= DATEADD('month', -12, CURRENT_DATE());  -- 최근 12개월만

GRANT SELECT ON VIEW INSURE_DB.MART.V_SHARED_RISK_SUMMARY
    TO SHARE INSURE_RISK_SHARE;


-- ============================================================
-- STEP 5: 보험사 파트너 계정 등록 (예시 — 실제 계정명으로 교체)
-- ============================================================

-- 예시: 삼성화재 Snowflake 계정에 공유 활성화
-- ALTER SHARE INSURE_RISK_SHARE ADD ACCOUNTS = samsung_fire_account;

-- 예시: DB Insurance 파트너 계정
-- ALTER SHARE INSURE_RISK_SHARE ADD ACCOUNTS = partner_insurer_account;

-- 현재는 데모 환경이므로 자체 계정 내 공유 확인용 주석 처리


-- ============================================================
-- STEP 6: 공유 현황 확인
-- ============================================================
SHOW SHARES LIKE 'INSURE_RISK_SHARE';


-- ============================================================
-- STEP 7: Consumer 측 사용 예시 (보험사 계정에서 실행)
-- ============================================================
-- -- 보험사 Snowflake 계정에서 Share 구독
-- CREATE DATABASE INSURE_RISK_DATA FROM SHARE <INSURE_PROVIDER_ACCOUNT>.INSURE_RISK_SHARE;
--
-- -- 구독 후 즉시 조회 가능 (별도 ETL 없음)
-- SELECT * FROM INSURE_RISK_DATA.MART.V_SHARED_RISK_SUMMARY
-- WHERE 위험등급 = 'HIGH'
-- ORDER BY 종합위험점수 DESC;


SELECT '34_DATA_SHARING: INSURE_RISK_SHARE 생성 완료' AS status;
