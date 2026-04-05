-- ============================================================
-- INSURE: 공공데이터 테이블 DDL (9개 테이블)
-- 서울 25개 구, 118개 동 기준
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA RAW_PUBLIC;

-- ─────────────────────────────────────────────
-- 1. 서울시 화재발생 동별 통계
-- 출처: 서울 열린데이터광장 / 소방청 NFDS
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE FIRE_STATS (
    YEAR                    INT         COMMENT '발생연도',
    DISTRICT_NAME           VARCHAR(50) COMMENT '자치구명 (예: 강남구)',
    DONG_NAME               VARCHAR(50) COMMENT '행정동명 (예: 역삼동)',
    TOTAL_FIRES             INT         COMMENT '총 화재건수',
    BUILDING_FIRES          INT         COMMENT '건물 화재건수',
    VEHICLE_FIRES           INT         COMMENT '차량 화재건수',
    FOREST_FIRES            INT         COMMENT '산림 화재건수',
    OTHER_FIRES             INT         COMMENT '기타 화재건수',
    DEATHS                  INT         COMMENT '사망자수',
    INJURIES                INT         COMMENT '부상자수',
    PROPERTY_DAMAGE_KRW     BIGINT      COMMENT '재산피해액(원)',
    ELECTRICAL_CAUSE        INT         COMMENT '전기적 원인 건수',
    MECHANICAL_CAUSE        INT         COMMENT '기계적 원인 건수',
    GAS_CAUSE               INT         COMMENT '가스 원인 건수',
    CARELESS_CAUSE          INT         COMMENT '부주의 원인 건수',
    ARSON_CAUSE             INT         COMMENT '방화 원인 건수',
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────
-- 2. 서울시 5대범죄 발생현황 (구별)
-- 출처: 경찰청 범죄통계
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE CRIME_STATS (
    YEAR                    INT         COMMENT '발생연도',
    DISTRICT_NAME           VARCHAR(50) COMMENT '자치구명',
    MURDER                  INT         COMMENT '살인 건수',
    ROBBERY                 INT         COMMENT '강도 건수',
    SEXUAL_ASSAULT          INT         COMMENT '성폭력 건수',
    THEFT                   INT         COMMENT '절도 건수',
    VIOLENCE                INT         COMMENT '폭력 건수',
    TOTAL_CRIMES            INT         COMMENT '5대범죄 합계',
    BURGLARY                INT         COMMENT '침입절도 건수 (절도 중 세분류)',
    VEHICLE_THEFT           INT         COMMENT '차량절도 건수',
    PICKPOCKET              INT         COMMENT '소매치기 건수',
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────
-- 3. 서울시 노후기간별 주택현황 (구별)
-- 출처: 국토부 건축물대장 / 서울시 통계
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE BUILDING_AGE (
    YEAR                    INT         COMMENT '기준연도',
    DISTRICT_NAME           VARCHAR(50) COMMENT '자치구명',
    TOTAL_BUILDINGS         INT         COMMENT '총 건물수',
    AGE_UNDER_10Y           INT         COMMENT '10년 미만',
    AGE_10_TO_20Y           INT         COMMENT '10~20년',
    AGE_20_TO_30Y           INT         COMMENT '20~30년',
    AGE_30_TO_40Y           INT         COMMENT '30~40년',
    AGE_OVER_40Y            INT         COMMENT '40년 이상',
    AVG_BUILDING_AGE        FLOAT       COMMENT '평균 건물연한(년)',
    WOODEN_BUILDINGS        INT         COMMENT '목조 건물수',
    CONCRETE_BUILDINGS      INT         COMMENT '철근콘크리트 건물수',
    STEEL_BUILDINGS         INT         COMMENT '철골 건물수',
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────
-- 4. 기상 위험도 데이터 (구별/월별)
-- 출처: 기상청 기상자료개방포털
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE WEATHER_RISK (
    YEAR_MONTH              VARCHAR(6)  COMMENT '기준월 (YYYYMM)',
    DISTRICT_NAME           VARCHAR(50) COMMENT '자치구명',
    AVG_TEMPERATURE         FLOAT       COMMENT '평균기온(℃)',
    MAX_TEMPERATURE         FLOAT       COMMENT '최고기온(℃)',
    MIN_TEMPERATURE         FLOAT       COMMENT '최저기온(℃)',
    TOTAL_RAINFALL_MM       FLOAT       COMMENT '총강수량(mm)',
    MAX_DAILY_RAINFALL_MM   FLOAT       COMMENT '일최대강수량(mm)',
    TYPHOON_AFFECTED_DAYS   INT         COMMENT '태풍영향일수',
    HEAVY_RAIN_DAYS         INT         COMMENT '호우특보일수',
    SNOW_DAYS               INT         COMMENT '적설일수',
    FLOOD_RISK_SCORE        FLOAT       COMMENT '침수위험도 (0~100)',
    WIND_RISK_SCORE         FLOAT       COMMENT '풍해위험도 (0~100)',
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────
-- 5. 서울시 1인가구 통계 (동별)
-- 출처: 행정안전부 주민등록 인구통계
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE SINGLE_HOUSEHOLD (
    YEAR                    INT         COMMENT '기준연도',
    DISTRICT_NAME           VARCHAR(50) COMMENT '자치구명',
    DONG_NAME               VARCHAR(50) COMMENT '행정동명',
    TOTAL_HOUSEHOLDS        INT         COMMENT '총 가구수',
    SINGLE_HOUSEHOLDS       INT         COMMENT '1인가구수',
    SINGLE_HOUSEHOLD_RATE   FLOAT       COMMENT '1인가구 비율(%)',
    SINGLE_MALE             INT         COMMENT '1인가구 남성',
    SINGLE_FEMALE           INT         COMMENT '1인가구 여성',
    SINGLE_AGE_20S          INT         COMMENT '1인가구 20대',
    SINGLE_AGE_30S          INT         COMMENT '1인가구 30대',
    SINGLE_AGE_40S          INT         COMMENT '1인가구 40대',
    SINGLE_AGE_50S          INT         COMMENT '1인가구 50대',
    SINGLE_AGE_60PLUS       INT         COMMENT '1인가구 60대 이상',
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────
-- 6. 서울시 CCTV 설치현황 (구별)
-- 출처: 서울 열린데이터광장
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE CCTV_INSTALLATION (
    YEAR                    INT         COMMENT '기준연도',
    DISTRICT_NAME           VARCHAR(50) COMMENT '자치구명',
    TOTAL_CCTV              INT         COMMENT '총 CCTV 대수',
    CRIME_PREVENTION        INT         COMMENT '범죄예방용',
    TRAFFIC_CONTROL         INT         COMMENT '교통단속용',
    FACILITY_SAFETY         INT         COMMENT '시설안전용',
    FIRE_PREVENTION         INT         COMMENT '화재감시용',
    CHILD_PROTECTION        INT         COMMENT '어린이보호용',
    CCTV_PER_1000_PEOPLE    FLOAT       COMMENT '인구 1000명당 CCTV',
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────
-- 7. 서울시 부동산 실거래 건수 (구별/월별)
-- 출처: 국토부 실거래가 공개시스템
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE REAL_ESTATE_TRANSACTIONS (
    YEAR_MONTH              VARCHAR(6)  COMMENT '기준월 (YYYYMM)',
    DISTRICT_NAME           VARCHAR(50) COMMENT '자치구명',
    APT_SALES_COUNT         INT         COMMENT '아파트 매매 건수',
    APT_JEONSE_COUNT        INT         COMMENT '아파트 전세 건수',
    APT_MONTHLY_RENT_COUNT  INT         COMMENT '아파트 월세 건수',
    OFFICETEL_SALES_COUNT   INT         COMMENT '오피스텔 매매 건수',
    OFFICETEL_RENT_COUNT    INT         COMMENT '오피스텔 임대 건수',
    VILLA_SALES_COUNT       INT         COMMENT '연립다세대 매매 건수',
    VILLA_RENT_COUNT        INT         COMMENT '연립다세대 임대 건수',
    TOTAL_TRANSACTIONS      INT         COMMENT '총 거래건수',
    AVG_APT_PRICE_10K       BIGINT      COMMENT '아파트 평균매매가(만원)',
    MOVING_INDEX            FLOAT       COMMENT '이사지수 (전월대비 거래증감률)',
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────
-- 8. 소방시설 현황 (구별)
-- 출처: 소방청 / 서울시 소방재난본부
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE FIRE_FACILITY (
    YEAR                    INT         COMMENT '기준연도',
    DISTRICT_NAME           VARCHAR(50) COMMENT '자치구명',
    FIRE_STATIONS           INT         COMMENT '소방서 수',
    FIRE_SUBSTATIONS        INT         COMMENT '119안전센터 수',
    FIRE_TRUCKS             INT         COMMENT '소방차 대수',
    AMBULANCES              INT         COMMENT '구급차 대수',
    FIRE_HYDRANTS           INT         COMMENT '소화전 수',
    FIREFIGHTERS            INT         COMMENT '소방공무원 수',
    AVG_RESPONSE_TIME_SEC   FLOAT       COMMENT '평균 출동시간(초)',
    BUILDINGS_PER_STATION   FLOAT       COMMENT '소방서 1개당 건물수',
    FIRE_SAFETY_SCORE       FLOAT       COMMENT '소방안전도 점수(0~100)',
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────
-- 9. 한국소비자원 CISS 가전사고 데이터
-- 출처: 소비자위해감시시스템 (CISS)
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE CONSUMER_ACCIDENT (
    YEAR                    INT         COMMENT '발생연도',
    QUARTER                 INT         COMMENT '분기 (1~4)',
    ACCIDENT_TYPE           VARCHAR(50) COMMENT '사고유형 (화재/폭발/감전/낙상 등)',
    PRODUCT_CATEGORY        VARCHAR(100) COMMENT '제품분류 (가전/가구/생활용품 등)',
    PRODUCT_DETAIL          VARCHAR(200) COMMENT '세부품목 (세탁기/에어컨/TV 등)',
    ACCIDENT_COUNT          INT         COMMENT '사고건수',
    INJURY_COUNT            INT         COMMENT '부상건수',
    DEATH_COUNT             INT         COMMENT '사망건수',
    PROPERTY_DAMAGE_YN      VARCHAR(1)  COMMENT '재산피해여부 (Y/N)',
    CAUSE_SUMMARY           VARCHAR(500) COMMENT '원인요약 (Cortex LLM 분석용 텍스트)',
    DISTRICT_NAME           VARCHAR(50) COMMENT '발생지역 자치구 (서울 한정)',
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

SELECT 'All 9 public data tables created successfully' AS status;
