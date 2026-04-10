-- ============================================================================
-- INSURE Graph RAG Nodes Insertion
-- Purpose: Insert all 31 nodes (14 CLAUSE + 11 DATA + 4 RULE + 2 MODEL)
-- Date: 2026-04-09
-- Note: INSERT INTO ... SELECT ... UNION ALL (Snowflake VALUES절 함수 제한 우회)
-- ============================================================================

-- Insert CLAUSE nodes (14개)
INSERT INTO INSURE_DB.GRAPH.GRAPH_NODES
SELECT * FROM (
SELECT 'CL_01' AS NODE_ID, 'CLAUSE' AS NODE_TYPE, '제1조 목적' AS NODE_NAME,
       '보험계약의 목적과 기본 원칙을 정의' AS DESCRIPTION, '총칙' AS CATEGORY,
       NULL AS SCHEMA_NAME, NULL AS TABLE_NAME, NULL AS VERSION, NULL AS FRAMEWORK,
       PARSE_JSON('{"article": 1, "mandatory": true}') AS METADATA,
       CURRENT_TIMESTAMP() AS CREATED_AT, CURRENT_TIMESTAMP() AS UPDATED_AT
UNION ALL
SELECT 'CL_02', 'CLAUSE', '제2조 보장범위',
       '동산보험의 구체적 보장 범위와 대상 물품을 명시', '총칙',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 2, "references_data": true, "mandatory": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_03', 'CLAUSE', '제3조 보험금산출',
       '보험금 지급 규칙 및 산출 방법론', '보험금지급',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 3, "references_rule": true, "mandatory": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_04', 'CLAUSE', '제4조 위험평가',
       '자치구별 위험도 평가 및 계산 방식', '보험금지급',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 4, "references_data": true, "data_sources": ["STG_FIRE_STATS", "STG_CRIME_STATS", "STG_BUILDING_AGE", "STG_WEATHER_RISK"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_05', 'CLAUSE', '제5조 면책사항',
       '보험금 지급 제외 사항 및 조건', '보험금지급',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 5, "mandatory": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_06', 'CLAUSE', '제6조 보험료산정',
       '5구간 비선형 리스크 커브를 적용한 보험료 계산', '보험료',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 6, "references_rule": true, "rule": "RL_01_v1.3", "mandatory": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_07', 'CLAUSE', '제7조 보험료조정',
       '계약 이후 위험도 변화에 따른 보험료 조정 방식', '보험료',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 7, "references_data": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_08', 'CLAUSE', '제8조 계약체결',
       '보험계약의 성립 요건 및 절차', '보험계약',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 8, "mandatory": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_09', 'CLAUSE', '제9조 해지환급',
       '보험계약 해지 시 환급금 계산 및 지급 방식', '보험계약',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 9, "mandatory": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_10', 'CLAUSE', '제10조 갱신',
       '보험계약의 갱신 및 연장 조건', '보험계약',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 10, "mandatory": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_11', 'CLAUSE', '제11조 통지의무',
       '계약자의 통지 의무 및 고지 사항', '보험계약',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 11, "mandatory": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_12', 'CLAUSE', '제12조 품목별한도',
       '품목(화재, 도난, 파손 등)별 보장한도 설정', '품목별보장한도',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 12, "references_data": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_13', 'CLAUSE', '제13조 분쟁해결',
       '보험금 청구 분쟁의 해결 절차', '분쟁해결',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 13, "mandatory": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'CL_14', 'CLAUSE', '제14조 관할법원',
       '계약 관련 소송의 관할법원 지정', '분쟁해결',
       NULL, NULL, NULL, NULL,
       PARSE_JSON('{"article": 14, "mandatory": true}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

-- Insert DATA nodes (11개)
INSERT INTO INSURE_DB.GRAPH.GRAPH_NODES
SELECT * FROM (
SELECT 'DT_01' AS NODE_ID, 'DATA' AS NODE_TYPE, 'MART_DISTRICT_INSURANCE_SUMMARY' AS NODE_NAME,
       '자치구별 보험요약 데이터 (보험료, 청구액, 손실률 등)' AS DESCRIPTION, NULL AS CATEGORY,
       'INSURE_DB.MART' AS SCHEMA_NAME, 'MART_DISTRICT_INSURANCE_SUMMARY' AS TABLE_NAME,
       NULL AS VERSION, NULL AS FRAMEWORK,
       PARSE_JSON('{"rows": "25", "frequency": "DAILY", "key_columns": ["GU_ID", "INSURANCE_YEAR", "PREMIUM_AMOUNT", "CLAIM_AMOUNT"]}') AS METADATA,
       CURRENT_TIMESTAMP() AS CREATED_AT, CURRENT_TIMESTAMP() AS UPDATED_AT
UNION ALL
SELECT 'DT_02', 'DATA', 'INT_DISTRICT_RISK_SCORE',
       '자치구별 위험점수 (화재, 범죄, 기상 등 통합)', NULL,
       'INSURE_DB.INTERMEDIATE', 'INT_DISTRICT_RISK_SCORE', NULL, NULL,
       PARSE_JSON('{"rows": "25", "frequency": "WEEKLY", "key_columns": ["GU_ID", "RISK_SCORE", "FIRE_RISK", "CRIME_RISK", "WEATHER_RISK"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'DT_03', 'DATA', 'SEED_HOUSEHOLD_GOODS',
       '가구 동산 품목 및 표준 가격 정보', NULL,
       'INSURE_DB.RAW', 'SEED_HOUSEHOLD_GOODS', NULL, NULL,
       PARSE_JSON('{"rows": "3000", "frequency": "MONTHLY", "key_columns": ["ITEM_ID", "ITEM_NAME", "CATEGORY", "STANDARD_PRICE"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'DT_04', 'DATA', 'STG_FIRE_STATS',
       '화재 통계 및 발생률 데이터', NULL,
       'INSURE_DB.STAGING', 'STG_FIRE_STATS', NULL, NULL,
       PARSE_JSON('{"rows": "10000", "frequency": "WEEKLY", "key_columns": ["GU_ID", "FIRE_COUNT", "FIRE_RATE", "AVG_LOSS"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'DT_05', 'DATA', 'STG_CRIME_STATS',
       '범죄 통계 및 발생률 데이터', NULL,
       'INSURE_DB.STAGING', 'STG_CRIME_STATS', NULL, NULL,
       PARSE_JSON('{"rows": "10000", "frequency": "WEEKLY", "key_columns": ["GU_ID", "CRIME_COUNT", "CRIME_RATE", "AVG_LOSS"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'DT_06', 'DATA', 'STG_BUILDING_AGE',
       '건물 노후도 및 건축 연도 통계', NULL,
       'INSURE_DB.STAGING', 'STG_BUILDING_AGE', NULL, NULL,
       PARSE_JSON('{"rows": "50000", "frequency": "QUARTERLY", "key_columns": ["GU_ID", "BUILDING_AGE_BUCKET", "AVG_AGE", "OLDER_BUILDING_PCT"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'DT_07', 'DATA', 'STG_WEATHER_RISK',
       '기상 위험 지수 및 변동 추이', NULL,
       'INSURE_DB.STAGING', 'STG_WEATHER_RISK', NULL, NULL,
       PARSE_JSON('{"rows": "10000", "frequency": "DAILY", "key_columns": ["GU_ID", "WEATHER_RISK_SCORE", "TEMPERATURE_VOLATILITY", "TYPHOON_RISK"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'DT_08', 'DATA', 'MART_PREMIUM_LAYER',
       '보험료 계층화 및 세분화 데이터', NULL,
       'INSURE_DB.MART', 'MART_PREMIUM_LAYER', NULL, NULL,
       PARSE_JSON('{"rows": "10000", "frequency": "DAILY", "key_columns": ["GU_ID", "RISK_TIER", "PREMIUM_RANGE", "ADJUSTMENT_FACTOR"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'DT_09', 'DATA', 'RAG_CHUNKS',
       'RAG 기반 약관 청크 및 임베딩', NULL,
       'INSURE_DB.RAG', 'RAG_CHUNKS', NULL, NULL,
       PARSE_JSON('{"rows": "5000", "frequency": "WEEKLY", "key_columns": ["CHUNK_ID", "CLAUSE_ID", "TEXT", "EMBEDDING"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'DT_10', 'DATA', 'V_FIRE_FORECAST_V13',
       '화재 예측 분석 뷰 (Cortex ML v1.3)', NULL,
       'INSURE_DB.ANALYTICS', 'V_FIRE_FORECAST_V13', NULL, NULL,
       PARSE_JSON('{"rows": "25", "frequency": "WEEKLY", "key_columns": ["GU_ID", "FORECAST_FIRE_RATE", "CONFIDENCE_SCORE", "FORECAST_DATE"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'DT_11', 'DATA', 'SEED_PERSONA_SEGMENTS',
       '고객 세그먼트 및 페르소나 정보', NULL,
       'INSURE_DB.RAW', 'SEED_PERSONA_SEGMENTS', NULL, NULL,
       PARSE_JSON('{"rows": "1000", "frequency": "MONTHLY", "key_columns": ["SEGMENT_ID", "SEGMENT_NAME", "AFFORDABILITY_INDEX", "AVG_MONTHLY_INCOME"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

-- Insert RULE nodes (4개)
INSERT INTO INSURE_DB.GRAPH.GRAPH_NODES
SELECT * FROM (
SELECT 'RL_01' AS NODE_ID, 'RULE' AS NODE_TYPE, '5구간 비선형 리스크 커브 v1.3' AS NODE_NAME,
       '위험점수에 따른 5구간(매우저-저-중-고-매우고) 비선형 프리미엄 산출' AS DESCRIPTION,
       NULL AS CATEGORY, NULL AS SCHEMA_NAME, NULL AS TABLE_NAME,
       'v1.3' AS VERSION, NULL AS FRAMEWORK,
       PARSE_JSON('{"segments": 5, "curve_type": "nonlinear", "updated": "2026-03-15", "implementation": "SQL_CASE_WHEN"}') AS METADATA,
       CURRENT_TIMESTAMP() AS CREATED_AT, CURRENT_TIMESTAMP() AS UPDATED_AT
UNION ALL
SELECT 'RL_02', 'RULE', '7단계 보험료 산출 파이프라인',
       '기본료 → 위험조정 → 신뢰도조정 → 부담능력한정 → 경쟁조정 → 최종승인 → 지급', NULL,
       NULL, NULL, 'v1.2', NULL,
       PARSE_JSON('{"stages": 7, "workflow": ["base_premium", "risk_adjustment", "credibility", "affordability", "competition", "approval", "payment"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'RL_03', 'RULE', 'Credibility Adjustment (Z = min(n/1082, 1.0))',
       '표본 크기 기반 신뢰도 조정 계수', NULL,
       NULL, NULL, 'v1.0', NULL,
       PARSE_JSON('{"formula": "Z = min(n/1082, 1.0)", "base_sample_size": 1082, "purpose": "experience_credibility"}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
UNION ALL
SELECT 'RL_04', 'RULE', '부담능력 상한 (월소득 0.5%)',
       '고객 월소득 기반 보험료 상한선 설정', NULL,
       NULL, NULL, 'v1.0', NULL,
       PARSE_JSON('{"percentage": 0.5, "basis": "MONTHLY_INCOME", "purpose": "affordability_protection"}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

-- Insert MODEL nodes (2개)
INSERT INTO INSURE_DB.GRAPH.GRAPH_NODES
SELECT * FROM (
SELECT 'ML_01' AS NODE_ID, 'MODEL' AS NODE_TYPE, 'Cortex ML FORECAST (화재 예측)' AS NODE_NAME,
       '화재 발생률 및 손실 예측 머신러닝 모델' AS DESCRIPTION,
       NULL AS CATEGORY, NULL AS SCHEMA_NAME, NULL AS TABLE_NAME,
       NULL AS VERSION, 'Cortex ML' AS FRAMEWORK,
       PARSE_JSON('{"framework": "Cortex", "model_type": "FORECAST", "input_features": ["DT_04", "DT_06", "DT_07"], "output": ["DT_10"]}') AS METADATA,
       CURRENT_TIMESTAMP() AS CREATED_AT, CURRENT_TIMESTAMP() AS UPDATED_AT
UNION ALL
SELECT 'ML_02', 'MODEL', 'Cortex Agent SP_ASK_INSURE_ADVISOR',
       '약관 질의응답 및 RAG 기반 상담 에이전트', NULL,
       NULL, NULL, NULL, 'Cortex Agent',
       PARSE_JSON('{"framework": "Cortex", "agent_type": "QA_ADVISOR", "knowledge_base": "DT_09", "outputs": ["recommendations", "clause_references"]}'),
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
);

-- 확인
SELECT NODE_TYPE, COUNT(*) AS CNT FROM INSURE_DB.GRAPH.GRAPH_NODES GROUP BY NODE_TYPE ORDER BY NODE_TYPE;
