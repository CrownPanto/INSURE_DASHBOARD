-- ============================================================
-- INSURE: External Stage + Snowpipe 설정
-- 프로덕션 환경 공공데이터 자동 적재 파이프라인
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA RAW_PUBLIC;

-- ─────────────────────────────────────────────
-- 1. File Format 정의
-- ─────────────────────────────────────────────
CREATE OR REPLACE FILE FORMAT CSV_KR
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'N/A', '-')
    ENCODING = 'UTF-8'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    COMMENT = '한국 공공데이터 CSV (UTF-8, 헤더 있음)';

CREATE OR REPLACE FILE FORMAT JSON_KR
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    ALLOW_DUPLICATE = TRUE
    COMMENT = '공공데이터 API JSON 응답';

-- ─────────────────────────────────────────────
-- 2. Internal Stage (데모용 - 수동 업로드)
-- ─────────────────────────────────────────────
CREATE OR REPLACE STAGE STG_PUBLIC_DATA
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = '공공데이터 수동 업로드용 Internal Stage';

-- 사용법 (SnowSQL 또는 UI):
-- PUT file:///path/to/fire_stats.csv @STG_PUBLIC_DATA/fire/;
-- PUT file:///path/to/crime_stats.csv @STG_PUBLIC_DATA/crime/;
-- PUT file:///path/to/building_age.csv @STG_PUBLIC_DATA/building/;

-- ─────────────────────────────────────────────
-- 3. External Stage (프로덕션 - S3/Azure Blob)
-- ─────────────────────────────────────────────
-- 프로덕션 환경에서는 AWS S3 또는 Azure Blob에 공공데이터를 적재 후 연결
/*
-- AWS S3 예시
CREATE OR REPLACE STAGE STG_PUBLIC_DATA_S3
    URL = 's3://insure-public-data/seoul/'
    STORAGE_INTEGRATION = insure_s3_integration
    FILE_FORMAT = CSV_KR
    COMMENT = '서울 공공데이터 S3 External Stage';

-- Azure Blob 예시
CREATE OR REPLACE STAGE STG_PUBLIC_DATA_AZURE
    URL = 'azure://insuredata.blob.core.windows.net/public/'
    STORAGE_INTEGRATION = insure_azure_integration
    FILE_FORMAT = CSV_KR;
*/

-- ─────────────────────────────────────────────
-- 4. Snowpipe 자동 적재 파이프라인
-- ─────────────────────────────────────────────

-- 4-1. 화재 데이터 Snowpipe
CREATE OR REPLACE PIPE PIPE_FIRE_STATS
    AUTO_INGEST = TRUE
    COMMENT = '서울시 화재통계 자동 적재 (소방청 NFDS)'
AS
COPY INTO FIRE_STATS (YEAR, DISTRICT_NAME, DONG_NAME, TOTAL_FIRES, BUILDING_FIRES,
                       VEHICLE_FIRES, FOREST_FIRES, OTHER_FIRES, DEATHS, INJURIES,
                       PROPERTY_DAMAGE_KRW, ELECTRICAL_CAUSE, MECHANICAL_CAUSE,
                       GAS_CAUSE, CARELESS_CAUSE, ARSON_CAUSE)
FROM @STG_PUBLIC_DATA/fire/
FILE_FORMAT = CSV_KR
ON_ERROR = 'CONTINUE';

-- 4-2. 범죄 데이터 Snowpipe
CREATE OR REPLACE PIPE PIPE_CRIME_STATS
    AUTO_INGEST = TRUE
    COMMENT = '서울시 5대범죄 자동 적재 (경찰청)'
AS
COPY INTO CRIME_STATS (YEAR, DISTRICT_NAME, MURDER, ROBBERY, SEXUAL_ASSAULT,
                        THEFT, VIOLENCE, TOTAL_CRIMES, BURGLARY, VEHICLE_THEFT, PICKPOCKET)
FROM @STG_PUBLIC_DATA/crime/
FILE_FORMAT = CSV_KR
ON_ERROR = 'CONTINUE';

-- 4-3. 건물 노후도 Snowpipe
CREATE OR REPLACE PIPE PIPE_BUILDING_AGE
    AUTO_INGEST = TRUE
    COMMENT = '서울시 건물노후도 자동 적재 (건축물대장)'
AS
COPY INTO BUILDING_AGE (YEAR, DISTRICT_NAME, TOTAL_BUILDINGS, AGE_UNDER_10Y,
                         AGE_10_TO_20Y, AGE_20_TO_30Y, AGE_30_TO_40Y, AGE_OVER_40Y,
                         AVG_BUILDING_AGE, WOODEN_BUILDINGS, CONCRETE_BUILDINGS, STEEL_BUILDINGS)
FROM @STG_PUBLIC_DATA/building/
FILE_FORMAT = CSV_KR
ON_ERROR = 'CONTINUE';

-- 4-4. 기상 데이터 Snowpipe
CREATE OR REPLACE PIPE PIPE_WEATHER_RISK
    AUTO_INGEST = TRUE
    COMMENT = '기상청 기상위험도 자동 적재'
AS
COPY INTO WEATHER_RISK (YEAR_MONTH, DISTRICT_NAME, AVG_TEMPERATURE, MAX_TEMPERATURE,
                         MIN_TEMPERATURE, TOTAL_RAINFALL_MM, MAX_DAILY_RAINFALL_MM,
                         TYPHOON_AFFECTED_DAYS, HEAVY_RAIN_DAYS, SNOW_DAYS,
                         FLOOD_RISK_SCORE, WIND_RISK_SCORE)
FROM @STG_PUBLIC_DATA/weather/
FILE_FORMAT = CSV_KR
ON_ERROR = 'CONTINUE';

-- 4-5. 부동산 거래 Snowpipe
CREATE OR REPLACE PIPE PIPE_REAL_ESTATE
    AUTO_INGEST = TRUE
    COMMENT = '국토부 실거래가 자동 적재'
AS
COPY INTO REAL_ESTATE_TRANSACTIONS (YEAR_MONTH, DISTRICT_NAME, APT_SALES_COUNT,
    APT_JEONSE_COUNT, APT_MONTHLY_RENT_COUNT, OFFICETEL_SALES_COUNT,
    OFFICETEL_RENT_COUNT, VILLA_SALES_COUNT, VILLA_RENT_COUNT,
    TOTAL_TRANSACTIONS, AVG_APT_PRICE_10K, MOVING_INDEX)
FROM @STG_PUBLIC_DATA/realestate/
FILE_FORMAT = CSV_KR
ON_ERROR = 'CONTINUE';

-- 4-6. CISS 가전사고 Snowpipe (JSON)
CREATE OR REPLACE PIPE PIPE_CONSUMER_ACCIDENT
    AUTO_INGEST = TRUE
    COMMENT = '한국소비자원 CISS 가전사고 자동 적재'
AS
COPY INTO CONSUMER_ACCIDENT (YEAR, QUARTER, ACCIDENT_TYPE, PRODUCT_CATEGORY,
    PRODUCT_DETAIL, ACCIDENT_COUNT, INJURY_COUNT, DEATH_COUNT,
    PROPERTY_DAMAGE_YN, CAUSE_SUMMARY, DISTRICT_NAME)
FROM @STG_PUBLIC_DATA/ciss/
FILE_FORMAT = CSV_KR
ON_ERROR = 'CONTINUE';


-- ─────────────────────────────────────────────
-- 5. Task: 데이터 갱신 후 자동 파이프라인 실행 (DAG)
-- ─────────────────────────────────────────────

-- Root Task: 매주 월요일 02:00 KST 실행
CREATE OR REPLACE TASK TASK_INSURE_REFRESH_ROOT
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 2 * * 1 Asia/Seoul'
    COMMENT = 'INSURE 주간 데이터 갱신 트리거'
AS
SELECT 'INSURE weekly refresh triggered' AS status;

-- Child Task 1: Intermediate 재계산
-- 05_DBT_INTERMEDIATE.sql 로직을 SP로 호출하여 재계산
CREATE OR REPLACE TASK TASK_REFRESH_INTERMEDIATE
    WAREHOUSE = COMPUTE_WH
    AFTER TASK_INSURE_REFRESH_ROOT
    COMMENT = 'Intermediate 레이어 재계산 (세그먼트 + 리스크) — C-4 수정: LIMIT 0 제거'
AS
BEGIN
    -- 세그먼트 분류: STG_ASSET_INCOME → INT_SEGMENT_CLASSIFICATION 재계산
    EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE INSURE_DB.INTERMEDIATE.INT_SEGMENT_CLASSIFICATION AS
        SELECT * FROM INSURE_DB.INTERMEDIATE.V_INT_SEGMENT_CLASSIFICATION
    ';
    -- 리스크 스코어: 공공데이터 5종 → INT_DISTRICT_RISK_SCORE 재계산
    EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE AS
        SELECT * FROM INSURE_DB.INTERMEDIATE.V_INT_DISTRICT_RISK_SCORE
    ';
END;

-- Child Task 2: Mart 재계산
-- 06_DBT_MART.sql 로직을 SP로 호출하여 재계산
CREATE OR REPLACE TASK TASK_REFRESH_MART
    WAREHOUSE = COMPUTE_WH
    AFTER TASK_REFRESH_INTERMEDIATE
    COMMENT = 'Mart 레이어 재계산 (보험 설계) — C-4 수정: LIMIT 0 제거'
AS
BEGIN
    EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE INSURE_DB.MART.MART_INSURANCE_DESIGN AS
        SELECT * FROM INSURE_DB.MART.V_MART_INSURANCE_DESIGN
    ';
    EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY AS
        SELECT * FROM INSURE_DB.MART.V_MART_DISTRICT_INSURANCE_SUMMARY
    ';
END;

-- Task DAG 활성화 (실행 시 주석 해제)
-- ALTER TASK TASK_REFRESH_MART RESUME;
-- ALTER TASK TASK_REFRESH_INTERMEDIATE RESUME;
-- ALTER TASK TASK_INSURE_REFRESH_ROOT RESUME;


-- ─────────────────────────────────────────────
-- 6. 상담 피드백 루프 테이블 (Phase 4 설계)
-- ─────────────────────────────────────────────
USE SCHEMA FEEDBACK;

CREATE OR REPLACE TABLE CONSULTATION_LOG (
    LOG_ID              NUMBER AUTOINCREMENT,
    SESSION_ID          VARCHAR(50),
    TIMESTAMP           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    DISTRICT_CODE       VARCHAR(10),
    SEGMENT_CODE        VARCHAR(100),
    CUSTOMER_AGE_GROUP  VARCHAR(20),
    CUSTOMER_GENDER     VARCHAR(5),
    -- 상담 내용
    INTERESTED_COVERAGE ARRAY      COMMENT '관심 보장항목 배열',
    REJECTED_COVERAGE   ARRAY      COMMENT '거절한 보장항목 배열',
    QUOTED_PREMIUM      NUMBER     COMMENT '제시된 보험료',
    CUSTOMER_REACTION   VARCHAR(20) COMMENT '반응 (긍정/부정/보류/가입)',
    -- 피드백
    FEEDBACK_TEXT       VARCHAR(1000) COMMENT '고객 피드백 원문',
    FEEDBACK_SENTIMENT  FLOAT       COMMENT 'Cortex SENTIMENT 점수 (-1~1)',
    -- 결과
    CONVERSION_YN       VARCHAR(1)  COMMENT '가입 전환 여부 (Y/N)',
    CONVERSION_AMOUNT   NUMBER      COMMENT '가입 보험료 (전환 시)'
);

-- 상담 피드백 집계 뷰
CREATE OR REPLACE VIEW V_FEEDBACK_SUMMARY AS
SELECT
    SEGMENT_CODE,
    DISTRICT_CODE,
    COUNT(*) AS TOTAL_CONSULTATIONS,
    SUM(CASE WHEN CONVERSION_YN = 'Y' THEN 1 ELSE 0 END) AS CONVERSIONS,
    ROUND(SUM(CASE WHEN CONVERSION_YN = 'Y' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100, 1) AS CONVERSION_RATE,
    AVG(FEEDBACK_SENTIMENT) AS AVG_SENTIMENT,
    AVG(QUOTED_PREMIUM) AS AVG_QUOTED_PREMIUM,
    AVG(CASE WHEN CONVERSION_YN = 'Y' THEN CONVERSION_AMOUNT END) AS AVG_CONVERTED_PREMIUM
FROM CONSULTATION_LOG
GROUP BY SEGMENT_CODE, DISTRICT_CODE;

-- 상담 100건 누적 시 재학습 트리거 (Stream + Task)
CREATE OR REPLACE STREAM STREAM_NEW_CONSULTATIONS
    ON TABLE CONSULTATION_LOG
    COMMENT = '신규 상담 로그 감지 스트림';

/*
CREATE OR REPLACE TASK TASK_RETRAIN_ON_FEEDBACK
    WAREHOUSE = COMPUTE_WH
    COMMENT = '상담 100건 누적 시 모델 재학습'
    WHEN SYSTEM$STREAM_HAS_DATA('STREAM_NEW_CONSULTATIONS')
AS
BEGIN
    -- 100건 이상 누적 확인
    IF ((SELECT COUNT(*) FROM STREAM_NEW_CONSULTATIONS) >= 100) THEN
        -- Feature Store 업데이트
        -- Mart 테이블 재계산
        -- 알림 발송
        INSERT INTO INSURE_DB.FEEDBACK.RETRAIN_LOG VALUES (CURRENT_TIMESTAMP(), 'auto_retrain', 'triggered');
    END IF;
END;
*/

-- 샘플 상담 데이터 (데모용)
INSERT INTO CONSULTATION_LOG (SESSION_ID, DISTRICT_CODE, SEGMENT_CODE, CUSTOMER_AGE_GROUP, CUSTOMER_GENDER, INTERESTED_COVERAGE, REJECTED_COVERAGE, QUOTED_PREMIUM, CUSTOMER_REACTION, FEEDBACK_TEXT, FEEDBACK_SENTIMENT, CONVERSION_YN, CONVERSION_AMOUNT)
SELECT * FROM (
    SELECT 'S001','1168010','A1_사회초년생|B2_알뜰형|C4_오피스텔원룸','20_24','M',
           PARSE_JSON('["전자기기파손","도난"]'), PARSE_JSON('["화재"]'),
           15000,'긍정','노트북이랑 태블릿 보장되면 좋겠어요. 화재는 건물보험 있지 않나요?',0.3,'Y',12000
    UNION ALL
    SELECT 'S002','1150010','A2_신혼|B0_표준소비형|C3_중형아파트','30_34','F',
           PARSE_JSON('["화재","가전파손","배상책임"]'), PARSE_JSON('["귀금속"]'),
           35000,'보류','혼수 가전이 많아서 걱정되긴 한데, 한 달에 3만원은 좀 부담돼요',−0.1,'N',NULL
    UNION ALL
    SELECT 'S003','1156010','A5_중년안정|B1_영리치|C1_신축대형','50_54','M',
           PARSE_JSON('["화재","도난","귀금속","고가가전","미술품"]'), PARSE_JSON('[]'),
           85000,'긍정','종합적으로 다 보장되면 좋겠습니다. 골프용품도 되나요?',0.6,'Y',92000
    UNION ALL
    SELECT 'S004','1174010','A6_은퇴시니어|B4_고자산보수형|C3_중형아파트','65_69','F',
           PARSE_JSON('["화재","수재","의료기기"]'), PARSE_JSON('["전자기기파손"]'),
           28000,'긍정','혈압기랑 산소발생기가 비싸서요. 수재 보장도 중요해요',0.4,'Y',25000
    UNION ALL
    SELECT 'S005','1135010','A3_영유아가구|B0_표준소비형|C3_중형아파트','35_39','F',
           PARSE_JSON('["어린이안전","가전파손","배상책임"]'), PARSE_JSON('["도난"]'),
           32000,'긍정','아이가 TV 밀어서 깨진 적 있어서... 배상책임도 필요해요',0.5,'Y',30000
);

SELECT 'External Stage + Snowpipe + Feedback Loop complete' AS status;
