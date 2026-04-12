-- ============================================================
-- 34_DATA_SHARING.sql
-- INSURE 프로젝트: Snowflake Data Sharing 설정
-- DB: INSURE_DB | Role: ACCOUNTADMIN
-- Date: 2026-04-12
-- ============================================================
--
-- 목적:
--   외부 소비자(Consumer) 또는 내부 계정에
--   구별 위험도 · 보험료 · 예측 데이터를 공유
--
-- 포함 객체:
--   SHARE          : INSURE_RISK_SHARE
--   공유 테이블/뷰  : MART_DISTRICT_INSURANCE_SUMMARY
--                    MART_PREMIUM_LAYER
--                    V_FIRE_FORECAST_V13 (뷰)
--   익명 요약 뷰    : V_SHARED_RISK_SUMMARY
--
-- 실행 권한: ACCOUNTADMIN
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE INSURE_DB;
USE WAREHOUSE COMPUTE_WH;


-- ============================================================
-- STEP 1: Share 생성
-- ============================================================

CREATE SHARE IF NOT EXISTS INSURE_RISK_SHARE
    COMMENT = 'INSURE 프로젝트 - 서울 25구 동산보험 위험도 공유 (2026)';


-- ============================================================
-- STEP 2: Share에 Database 추가
-- ============================================================

GRANT USAGE ON DATABASE INSURE_DB TO SHARE INSURE_RISK_SHARE;
GRANT USAGE ON SCHEMA INSURE_DB.MART TO SHARE INSURE_RISK_SHARE;
GRANT USAGE ON SCHEMA INSURE_DB.ANALYTICS TO SHARE INSURE_RISK_SHARE;


-- ============================================================
-- STEP 3: 공유 테이블 등록
-- ============================================================

-- 3-1. 구별 보험 요약 (핵심 지표)
GRANT SELECT ON TABLE INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
    TO SHARE INSURE_RISK_SHARE;

-- 3-2. 보험료 계층 데이터
GRANT SELECT ON TABLE INSURE_DB.MART.MART_PREMIUM_LAYER
    TO SHARE INSURE_RISK_SHARE;

-- 3-3. 화재 예측 결과 뷰 (V13 기준)
-- 뷰가 존재할 경우에만 GRANT (없으면 주석 해제 후 실행)
GRANT SELECT ON VIEW INSURE_DB.ANALYTICS.V_FIRE_FORECAST_V13
    TO SHARE INSURE_RISK_SHARE;


-- ============================================================
-- STEP 4: 익명 공개용 요약 뷰 생성 (V_SHARED_RISK_SUMMARY)
-- ============================================================
-- 외부 소비자에게 민감 컬럼(소득, 자산액 등)을 노출하지 않고
-- 위험도 지표와 등급만 제공하는 익명화 뷰

CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_SHARED_RISK_SUMMARY AS
SELECT
    m.GU_NAME                                               AS 자치구명,
    m.YEAR_MONTH                                            AS 기준연월,
    m.COMPOSITE_RISK_SCORE                                  AS 종합위험점수,
    m.RISK_GRADE                                            AS 위험등급,
    m.FIRE_RISK_SCORE                                       AS 화재위험점수,
    m.THEFT_RISK_SCORE                                      AS 절도위험점수,
    m.BUILDING_RISK_SCORE                                   AS 건물위험점수,
    m.WEATHER_RISK_SCORE                                    AS 기상위험점수,
    -- 보험료는 범위(구간)로만 노출 (개인정보 보호)
    CASE
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 30000  THEN '3만원 미만'
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 50000  THEN '3~5만원'
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 70000  THEN '5~7만원'
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 100000 THEN '7~10만원'
        ELSE '10만원 이상'
    END                                                     AS 월보험료구간,
    -- 시장 규모는 억원 단위로 반올림
    ROUND(m.ESTIMATED_ANNUAL_MARKET_KRW / 1e8, 1)          AS 연간시장규모_억원,
    CURRENT_TIMESTAMP()                                     AS 데이터기준시각
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY m
WHERE m.YEAR_MONTH = (
    SELECT MAX(YEAR_MONTH)
    FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
);

-- V_SHARED_RISK_SUMMARY도 Share에 추가
GRANT USAGE ON SCHEMA INSURE_DB.ANALYTICS TO SHARE INSURE_RISK_SHARE;
GRANT SELECT ON VIEW INSURE_DB.ANALYTICS.V_SHARED_RISK_SUMMARY
    TO SHARE INSURE_RISK_SHARE;


-- ============================================================
-- STEP 5: 검증 쿼리
-- ============================================================

-- 5-1. Share 생성 확인
SHOW SHARES LIKE 'INSURE_RISK_SHARE';

-- 5-2. Share 포함 객체 목록
SHOW GRANTS TO SHARE INSURE_RISK_SHARE;

-- 5-3. 익명 요약 뷰 미리보기
SELECT * FROM INSURE_DB.ANALYTICS.V_SHARED_RISK_SUMMARY
ORDER BY 종합위험점수 DESC
LIMIT 10;


-- ============================================================
-- STEP 6: Consumer 계정 추가 (필요 시)
-- ============================================================
-- 내부 또는 외부 Snowflake 계정에 Share를 전달할 때 사용
-- Consumer 계정 locator를 확인 후 주석 해제:
--
-- ALTER SHARE INSURE_RISK_SHARE
--     ADD ACCOUNTS = <consumer_account_locator>;
--
-- 예: ALTER SHARE INSURE_RISK_SHARE ADD ACCOUNTS = XY12345;


-- ============================================================
-- STEP 7: Share 삭제 (롤백용, 필요 시만 사용)
-- ============================================================
-- DROP SHARE INSURE_RISK_SHARE;
-- DROP VIEW IF EXISTS INSURE_DB.ANALYTICS.V_SHARED_RISK_SUMMARY;


SELECT '34_DATA_SHARING: Complete' AS status;
