-- ================================================================
-- 34_GRAPH_RAG_SYSTEM.sql
-- Graph RAG 시스템 통합: 스키마 + 노드 + 엣지 + 검색
-- Consolidated from: 34_GRAPH_RAG_SCHEMA.sql
--                    35_GRAPH_RAG_NODES.sql
--                    36_GRAPH_RAG_EDGES.sql
--                    37_GRAPH_RAG_SEARCH.sql
-- Insurance Policy Clause and Data Dependency Graph System
-- Date: 2026-04-09
-- ================================================================


-- ================================================================
-- PART 1: Graph 스키마 (from 34_GRAPH_RAG_SCHEMA.sql)
-- ================================================================

-- Create GRAPH schema if not exists
CREATE SCHEMA IF NOT EXISTS INSURE_DB.GRAPH
COMMENT = 'Graph RAG structures for INSURE insurance policy clauses and data dependencies';

-- ============================================================================
-- GRAPH_NODES Table: Graph nodes (Clauses, Data, Rules, ML Models)
-- ============================================================================
CREATE OR REPLACE TABLE INSURE_DB.GRAPH.GRAPH_NODES (
    node_id VARCHAR(10) PRIMARY KEY,
    node_type VARCHAR(20) NOT NULL COMMENT 'CLAUSE | DATA | RULE | MODEL',
    name VARCHAR(255) NOT NULL COMMENT 'Node display name',
    description VARCHAR(1000),
    chapter VARCHAR(100) COMMENT 'For CLAUSE: 총칙, 보험금지급, 보험료, 보험계약, 품목별보장한도, 분쟁해결',
    schema_name VARCHAR(100) COMMENT 'For DATA: schema name (INSURE_DB.MART, INSURE_DB.RAW, etc.)',
    table_name VARCHAR(255) COMMENT 'For DATA: actual table/view name',
    rule_version VARCHAR(20) COMMENT 'For RULE: version string',
    model_type VARCHAR(100) COMMENT 'For MODEL: Cortex ML, Agent, etc.',
    metadata VARIANT COMMENT 'Additional metadata as JSON',
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- GRAPH_EDGES Table: Relationships between nodes
-- ============================================================================
CREATE OR REPLACE TABLE INSURE_DB.GRAPH.GRAPH_EDGES (
    edge_id VARCHAR(20) PRIMARY KEY,
    source_node_id VARCHAR(10) NOT NULL,
    target_node_id VARCHAR(10) NOT NULL,
    edge_type VARCHAR(30) NOT NULL COMMENT 'REFERENCES | CALCULATES | COVERS | LIMITS | APPLIES | PREDICTS',
    weight FLOAT DEFAULT 0.5 COMMENT 'Edge weight: 0.0 ~ 1.0 (importance/strength)',
    description VARCHAR(1000),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (source_node_id) REFERENCES INSURE_DB.GRAPH.GRAPH_NODES(node_id),
    FOREIGN KEY (target_node_id) REFERENCES INSURE_DB.GRAPH.GRAPH_NODES(node_id)
);

-- Create indexes for graph traversal performance
CREATE INDEX IF NOT EXISTS IDX_EDGES_SOURCE ON INSURE_DB.GRAPH.GRAPH_EDGES(source_node_id);
CREATE INDEX IF NOT EXISTS IDX_EDGES_TARGET ON INSURE_DB.GRAPH.GRAPH_EDGES(target_node_id);
CREATE INDEX IF NOT EXISTS IDX_EDGES_TYPE ON INSURE_DB.GRAPH.GRAPH_EDGES(edge_type);
CREATE INDEX IF NOT EXISTS IDX_NODES_TYPE ON INSURE_DB.GRAPH.GRAPH_NODES(node_type);

-- ============================================================================
-- GRAPH_PATHS Table: Cached paths for query optimization
-- ============================================================================
CREATE OR REPLACE TABLE INSURE_DB.GRAPH.GRAPH_PATHS (
    path_id VARCHAR(30) PRIMARY KEY,
    source_node_id VARCHAR(10) NOT NULL,
    target_node_id VARCHAR(10) NOT NULL,
    hop_count INT,
    path_nodes ARRAY COMMENT 'Sequence of node IDs',
    path_edges ARRAY COMMENT 'Sequence of edge types',
    total_weight FLOAT COMMENT 'Product of edge weights',
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- GRAPH_TRAVERSAL_LOG Table: Track graph query patterns
-- ============================================================================
CREATE OR REPLACE TABLE INSURE_DB.GRAPH.GRAPH_TRAVERSAL_LOG (
    log_id VARCHAR(50) PRIMARY KEY DEFAULT UUID_STRING(),
    query_type VARCHAR(100) COMMENT 'clause_references, backward_lookup, path_search, etc.',
    source_node_id VARCHAR(10),
    target_node_id VARCHAR(10),
    hops INT,
    result_count INT,
    execution_time_ms INT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    query_text VARCHAR(2000)
);

-- ============================================================================
-- Grants for roles
-- ============================================================================
GRANT USAGE ON SCHEMA INSURE_DB.GRAPH TO ROLE ANALYTICS_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.GRAPH TO ROLE ANALYTICS_ROLE;
GRANT INSERT, UPDATE ON TABLE INSURE_DB.GRAPH.GRAPH_NODES TO ROLE ANALYTICS_ROLE;
GRANT INSERT, UPDATE ON TABLE INSURE_DB.GRAPH.GRAPH_EDGES TO ROLE ANALYTICS_ROLE;
GRANT INSERT ON TABLE INSURE_DB.GRAPH.GRAPH_TRAVERSAL_LOG TO ROLE ANALYTICS_ROLE;

COMMENT ON TABLE INSURE_DB.GRAPH.GRAPH_NODES IS 'All nodes in the INSURE Graph RAG: 14 clauses, 11 data sources, 4 rules, 2 ML models';
COMMENT ON TABLE INSURE_DB.GRAPH.GRAPH_EDGES IS 'Relationships between graph nodes with edge types and weights';


-- ================================================================
-- PART 2: 그래프 노드 (from 35_GRAPH_RAG_NODES.sql)
-- ================================================================

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

-- Node insertion verification
SELECT NODE_TYPE, COUNT(*) AS CNT FROM INSURE_DB.GRAPH.GRAPH_NODES GROUP BY NODE_TYPE ORDER BY NODE_TYPE;


-- ================================================================
-- PART 3: 그래프 엣지 (from 36_GRAPH_RAG_EDGES.sql)
-- ================================================================

-- Clear existing edges to avoid duplicates
TRUNCATE TABLE INSURE_DB.GRAPH.GRAPH_EDGES;

-- ============================================================================
-- Core CLAUSE → DATA edges (REFERENCES type)
-- ============================================================================
INSERT INTO INSURE_DB.GRAPH.GRAPH_EDGES VALUES
('E001', 'CL_02', 'DT_01', 'REFERENCES', 0.9, '보장범위가 자치구별 보험요약 데이터 참조', CURRENT_TIMESTAMP()),
('E002', 'CL_02', 'DT_03', 'REFERENCES', 0.8, '보장범위가 가구동산 품목 데이터 참조', CURRENT_TIMESTAMP()),
('E003', 'CL_04', 'DT_02', 'REFERENCES', 0.9, '위험평가가 자치구별 위험점수 데이터 참조', CURRENT_TIMESTAMP()),
('E004', 'CL_04', 'DT_04', 'REFERENCES', 0.7, '위험평가가 화재통계 데이터 참조', CURRENT_TIMESTAMP()),
('E005', 'CL_04', 'DT_05', 'REFERENCES', 0.7, '위험평가가 범죄통계 데이터 참조', CURRENT_TIMESTAMP()),
('E006', 'CL_04', 'DT_06', 'REFERENCES', 0.6, '위험평가가 건물노후도 데이터 참조', CURRENT_TIMESTAMP()),
('E007', 'CL_04', 'DT_07', 'REFERENCES', 0.6, '위험평가가 기상위험 지수 참조', CURRENT_TIMESTAMP()),
('E008', 'CL_07', 'DT_08', 'REFERENCES', 0.8, '보험료조정이 프리미엄 레이어 데이터 참조', CURRENT_TIMESTAMP()),
('E009', 'CL_12', 'DT_03', 'REFERENCES', 0.9, '품목별한도가 가구동산 품목 데이터 참조', CURRENT_TIMESTAMP()),

-- ============================================================================
-- CLAUSE → RULE edges (LIMITS type)
-- ============================================================================
('E010', 'CL_03', 'RL_02', 'LIMITS', 1.0, '보험금산출이 7단계 보험료 산출 파이프라인 정의', CURRENT_TIMESTAMP()),
('E011', 'CL_06', 'RL_01', 'LIMITS', 1.0, '보험료산정이 5구간 비선형 리스크 커브 정의', CURRENT_TIMESTAMP()),

-- ============================================================================
-- RULE → DATA edges (CALCULATES type)
-- ============================================================================
('E012', 'RL_01', 'DT_02', 'CALCULATES', 0.9, '5구간 리스크 커브가 위험점수 데이터 사용', CURRENT_TIMESTAMP()),
('E013', 'RL_02', 'DT_01', 'APPLIES', 1.0, '7단계 파이프라인이 자치구별 보험요약에 적용', CURRENT_TIMESTAMP()),
('E014', 'RL_02', 'DT_08', 'APPLIES', 0.9, '7단계 파이프라인이 프리미엄 레이어에 적용', CURRENT_TIMESTAMP()),
('E015', 'RL_03', 'DT_01', 'CALCULATES', 0.7, '신뢰도조정이 보험요약 데이터의 신뢰도 계산', CURRENT_TIMESTAMP()),
('E016', 'RL_04', 'DT_11', 'CALCULATES', 0.6, '부담능력 상한이 고객 세그먼트 소득 데이터 사용', CURRENT_TIMESTAMP()),

-- ============================================================================
-- MODEL → DATA edges (PREDICTS & CALCULATES type)
-- ============================================================================
('E017', 'ML_01', 'DT_10', 'PREDICTS', 0.9, 'Cortex ML FORECAST가 화재예측 분석 뷰 생성', CURRENT_TIMESTAMP()),
('E018', 'ML_01', 'DT_04', 'CALCULATES', 0.8, 'Cortex ML FORECAST가 화재통계를 입력 데이터로 사용', CURRENT_TIMESTAMP()),
('E019', 'ML_02', 'DT_09', 'CALCULATES', 0.8, 'Cortex Agent가 RAG 청크 데이터 활용', CURRENT_TIMESTAMP()),
('E020', 'ML_02', 'DT_01', 'CALCULATES', 0.9, 'Cortex Agent가 보험요약 데이터 조회', CURRENT_TIMESTAMP()),

-- ============================================================================
-- CLAUSE → CLAUSE edges (COVERS type)
-- ============================================================================
('E021', 'CL_02', 'CL_12', 'COVERS', 0.7, '보장범위(CL_02)가 품목별한도(CL_12)를 포함', CURRENT_TIMESTAMP()),
('E022', 'CL_03', 'CL_06', 'COVERS', 0.8, '보험금산출(CL_03)이 보험료산정(CL_06)과 상호 연결', CURRENT_TIMESTAMP()),
('E023', 'CL_02', 'CL_04', 'COVERS', 0.7, '보장범위(CL_02)와 위험평가(CL_04)가 상호 관련', CURRENT_TIMESTAMP()),

-- ============================================================================
-- Additional connecting edges for complete graph (총 ~30개 목표)
-- ============================================================================
('E024', 'CL_03', 'DT_08', 'REFERENCES', 0.6, '보험금산출이 프리미엄 레이어 참조 (손실률 기반)', CURRENT_TIMESTAMP()),
('E025', 'CL_06', 'DT_02', 'REFERENCES', 0.85, '보험료산정이 위험점수 데이터 참조', CURRENT_TIMESTAMP()),
('E026', 'RL_02', 'DT_02', 'APPLIES', 0.8, '7단계 파이프라인이 위험점수에 기반', CURRENT_TIMESTAMP()),
('E027', 'CL_04', 'DT_10', 'REFERENCES', 0.5, '위험평가가 화재예측 분석 참조 (미래위험)', CURRENT_TIMESTAMP()),
('E028', 'ML_01', 'DT_06', 'CALCULATES', 0.7, 'Cortex ML FORECAST가 건물노후도 입력데이터 사용', CURRENT_TIMESTAMP()),
('E029', 'ML_01', 'DT_07', 'CALCULATES', 0.7, 'Cortex ML FORECAST가 기상위험 입력데이터 사용', CURRENT_TIMESTAMP()),
('E030', 'ML_02', 'DT_02', 'CALCULATES', 0.7, 'Cortex Agent가 위험점수 조회 및 활용', CURRENT_TIMESTAMP()),
('E031', 'CL_07', 'RL_03', 'LIMITS', 0.8, '보험료조정이 신뢰도조정 규칙 적용', CURRENT_TIMESTAMP()),
('E032', 'CL_06', 'RL_04', 'LIMITS', 0.8, '보험료산정이 부담능력 상한 규칙 적용', CURRENT_TIMESTAMP()),
('E033', 'CL_05', 'DT_02', 'REFERENCES', 0.5, '면책사항이 위험점수 기반 제외 조건 참조', CURRENT_TIMESTAMP()),
('E034', 'RL_01', 'DT_08', 'APPLIES', 0.85, '5구간 리스크 커브가 프리미엄 레이어 생성', CURRENT_TIMESTAMP());

-- ============================================================================
-- Verify insertion
-- ============================================================================
SELECT COUNT(*) as TOTAL_EDGES FROM INSURE_DB.GRAPH.GRAPH_EDGES;
SELECT
    edge_type,
    COUNT(*) as EDGE_COUNT
FROM INSURE_DB.GRAPH.GRAPH_EDGES
GROUP BY edge_type
ORDER BY edge_type;


-- ================================================================
-- PART 4: 그래프 검색 (from 37_GRAPH_RAG_SEARCH.sql)
-- ================================================================

-- ============================================================================
-- Query 1: 특정 약관 조항에서 참조하는 모든 데이터 노드 찾기
-- 예: CL_04 (제4조 위험평가) → 참조 데이터 목록
-- ============================================================================
-- 설명: CLAUSE 노드에서 출발하여 REFERENCES 엣지를 따라 DATA 노드를 찾음
SELECT
    source.node_id as CLAUSE_ID,
    source.name as CLAUSE_NAME,
    source.chapter as CHAPTER,
    edge.edge_type,
    target.node_id as DATA_ID,
    target.name as DATA_NAME,
    target.schema_name || '.' || target.table_name as FULL_TABLE_NAME,
    edge.weight as REFERENCE_STRENGTH,
    edge.description as RELATIONSHIP
FROM INSURE_DB.GRAPH.GRAPH_NODES source
INNER JOIN INSURE_DB.GRAPH.GRAPH_EDGES edge
    ON source.node_id = edge.source_node_id
INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES target
    ON edge.target_node_id = target.node_id
WHERE source.node_type = 'CLAUSE'
  AND target.node_type = 'DATA'
  AND edge.edge_type = 'REFERENCES'
  AND source.node_id = 'CL_04'  -- 위험평가 조항
ORDER BY edge.weight DESC, target.node_id;

-- ============================================================================
-- Query 2: 특정 데이터 노드를 참조하는 모든 약관/규칙 찾기
-- 예: DT_02 (위험점수) → 참조하는 CLAUSE/RULE 목록
-- ============================================================================
-- 설명: DATA 노드를 TARGET으로 하는 모든 REFERENCES/CALCULATES 엣지를 역추적
SELECT
    source.node_id as SOURCE_ID,
    source.node_type as SOURCE_TYPE,
    source.name as SOURCE_NAME,
    CASE
        WHEN source.node_type = 'CLAUSE' THEN source.chapter
        WHEN source.node_type = 'RULE' THEN source.rule_version
        ELSE NULL
    END as SOURCE_DETAIL,
    edge.edge_type,
    target.node_id as DATA_ID,
    target.name as DATA_NAME,
    edge.weight as RELATIONSHIP_STRENGTH,
    edge.description as RELATIONSHIP
FROM INSURE_DB.GRAPH.GRAPH_EDGES edge
INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES source
    ON edge.source_node_id = source.node_id
INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES target
    ON edge.target_node_id = target.node_id
WHERE target.node_type = 'DATA'
  AND target.node_id = 'DT_02'  -- 위험점수 데이터
  AND edge.edge_type IN ('REFERENCES', 'CALCULATES')
ORDER BY source.node_type, edge.weight DESC;

-- ============================================================================
-- Query 3: 약관 → 데이터 → 규칙 2-hop 탐색
-- 예: CL_02 (보장범위) → DT_01 (보험요약) → RL_02 (7단계 파이프라인)
-- ============================================================================
-- 설명: 중간에 DATA 노드를 거쳐 CLAUSE에서 RULE까지의 2-hop 경로 찾기
WITH FIRST_HOP AS (
    SELECT
        e1.source_node_id as START_CLAUSE,
        e1.target_node_id as INTERMEDIATE_DATA,
        e1.edge_type as FIRST_EDGE_TYPE,
        e1.weight as FIRST_WEIGHT,
        n_data.name as DATA_NAME
    FROM INSURE_DB.GRAPH.GRAPH_EDGES e1
    INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES n_data
        ON e1.target_node_id = n_data.node_id
    WHERE e1.edge_type = 'REFERENCES'
      AND e1.source_node_id LIKE 'CL_%'
)
SELECT
    n_clause.node_id as START_CLAUSE_ID,
    n_clause.name as START_CLAUSE_NAME,
    fh.INTERMEDIATE_DATA as DATA_ID,
    fh.DATA_NAME as DATA_NAME,
    n_target.node_id as END_NODE_ID,
    n_target.name as END_NODE_NAME,
    n_target.node_type as END_NODE_TYPE,
    e2.edge_type as SECOND_EDGE_TYPE,
    (fh.FIRST_WEIGHT * e2.weight) as COMBINED_WEIGHT,
    CONCAT(fh.FIRST_EDGE_TYPE, ' → ', e2.edge_type) as HOP_PATH
FROM FIRST_HOP fh
INNER JOIN INSURE_DB.GRAPH.GRAPH_EDGES e2
    ON fh.INTERMEDIATE_DATA = e2.source_node_id
INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES n_clause
    ON fh.START_CLAUSE = n_clause.node_id
INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES n_target
    ON e2.target_node_id = n_target.node_id
WHERE fh.START_CLAUSE = 'CL_02'  -- 보장범위
  AND (n_target.node_type = 'RULE' OR n_target.node_type = 'DATA')
ORDER BY COMBINED_WEIGHT DESC;

-- ============================================================================
-- Query 4: CL_06 (보험료산정)에서 출발하는 전체 경로 분석
-- 설명: BFS(너비 우선 탐색) 방식으로 모든 도달 가능 노드 찾기
-- ============================================================================
WITH RECURSIVE PATH_TRAVERSAL AS (
    -- Base case: Start from CL_06
    SELECT
        source.node_id as SOURCE_ID,
        source.name as SOURCE_NAME,
        source.node_type as SOURCE_TYPE,
        target.node_id as TARGET_ID,
        target.name as TARGET_NAME,
        target.node_type as TARGET_TYPE,
        edge.edge_type,
        edge.weight,
        1 as HOP_COUNT,
        ARRAY_CONSTRUCT(source.node_id, target.node_id) as PATH_NODES,
        ARRAY_CONSTRUCT(edge.edge_type) as PATH_EDGES,
        edge.weight as PATH_WEIGHT
    FROM INSURE_DB.GRAPH.GRAPH_EDGES edge
    INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES source
        ON edge.source_node_id = source.node_id
    INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES target
        ON edge.target_node_id = target.node_id
    WHERE source.node_id = 'CL_06'  -- 보험료산정

    UNION ALL

    -- Recursive case: Continue traversal up to 3 hops
    SELECT
        pt.SOURCE_ID,
        pt.SOURCE_NAME,
        pt.SOURCE_TYPE,
        target.node_id,
        target.name,
        target.node_type,
        edge.edge_type,
        edge.weight,
        pt.HOP_COUNT + 1,
        ARRAY_APPEND(pt.PATH_NODES, target.node_id),
        ARRAY_APPEND(pt.PATH_EDGES, edge.edge_type),
        pt.PATH_WEIGHT * edge.weight
    FROM PATH_TRAVERSAL pt
    INNER JOIN INSURE_DB.GRAPH.GRAPH_EDGES edge
        ON pt.TARGET_ID = edge.source_node_id
    INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES target
        ON edge.target_node_id = target.node_id
    WHERE pt.HOP_COUNT < 3  -- Limit to 3 hops
      AND NOT ARRAY_CONTAINS(target.node_id, pt.PATH_NODES)  -- Avoid cycles
)
SELECT
    HOP_COUNT,
    TARGET_ID,
    TARGET_NAME,
    TARGET_TYPE,
    PATH_WEIGHT as ACCUMULATED_WEIGHT,
    PATH_NODES,
    PATH_EDGES
FROM PATH_TRAVERSAL
ORDER BY HOP_COUNT, PATH_WEIGHT DESC;

-- ============================================================================
-- Query 5: 그래프 전체 구조 분석 - 노드 연결성 통계
-- ============================================================================
SELECT
    n.node_id,
    n.name,
    n.node_type,
    (SELECT COUNT(*) FROM INSURE_DB.GRAPH.GRAPH_EDGES e WHERE e.source_node_id = n.node_id) as OUTGOING_EDGES,
    (SELECT COUNT(*) FROM INSURE_DB.GRAPH.GRAPH_EDGES e WHERE e.target_node_id = n.node_id) as INCOMING_EDGES,
    (SELECT COUNT(*) FROM INSURE_DB.GRAPH.GRAPH_EDGES e WHERE e.source_node_id = n.node_id) +
    (SELECT COUNT(*) FROM INSURE_DB.GRAPH.GRAPH_EDGES e WHERE e.target_node_id = n.node_id) as TOTAL_CONNECTIONS,
    ROUND((SELECT AVG(weight) FROM INSURE_DB.GRAPH.GRAPH_EDGES e
           WHERE e.source_node_id = n.node_id OR e.target_node_id = n.node_id), 2) as AVG_EDGE_WEIGHT
FROM INSURE_DB.GRAPH.GRAPH_NODES n
ORDER BY TOTAL_CONNECTIONS DESC, n.node_type, n.node_id;

-- ============================================================================
-- Query 6: 엣지 타입별 분포 및 가중치 통계
-- ============================================================================
SELECT
    edge_type,
    COUNT(*) as EDGE_COUNT,
    ROUND(AVG(weight), 3) as AVG_WEIGHT,
    MIN(weight) as MIN_WEIGHT,
    MAX(weight) as MAX_WEIGHT,
    ROUND(SUM(weight), 2) as TOTAL_WEIGHT
FROM INSURE_DB.GRAPH.GRAPH_EDGES
GROUP BY edge_type
ORDER BY EDGE_COUNT DESC, AVG_WEIGHT DESC;

-- ============================================================================
-- Query 7: 핵심 규칙(RL)의 영향도 분석
-- 설명: 각 규칙이 몇 개의 DATA와 CLAUSE를 연결하는지 분석
-- ============================================================================
SELECT
    rule.node_id,
    rule.name,
    rule.rule_version,
    (SELECT COUNT(DISTINCT e.target_node_id)
     FROM INSURE_DB.GRAPH.GRAPH_EDGES e
     WHERE e.source_node_id = rule.node_id AND e.edge_type IN ('APPLIES', 'CALCULATES')) as TARGET_DATA_COUNT,
    (SELECT COUNT(DISTINCT e.source_node_id)
     FROM INSURE_DB.GRAPH.GRAPH_EDGES e
     WHERE e.target_node_id = rule.node_id AND e.edge_type IN ('LIMITS', 'CALCULATES')) as SOURCE_CLAUSE_COUNT,
    (SELECT ROUND(AVG(e.weight), 3)
     FROM INSURE_DB.GRAPH.GRAPH_EDGES e
     WHERE (e.source_node_id = rule.node_id OR e.target_node_id = rule.node_id)) as AVG_EDGE_STRENGTH
FROM INSURE_DB.GRAPH.GRAPH_NODES rule
WHERE rule.node_type = 'RULE'
ORDER BY TARGET_DATA_COUNT + SOURCE_CLAUSE_COUNT DESC;

-- ============================================================================
-- Query 8: 모든 경로 요약 (간단한 연결 리스트)
-- ============================================================================
SELECT
    CONCAT(source.node_id, ' (', source.node_type, ')') as FROM_NODE,
    CONCAT(target.node_id, ' (', target.node_type, ')') as TO_NODE,
    edge.edge_type as RELATIONSHIP_TYPE,
    edge.weight as STRENGTH,
    edge.description as DESCRIPTION
FROM INSURE_DB.GRAPH.GRAPH_EDGES edge
INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES source ON edge.source_node_id = source.node_id
INNER JOIN INSURE_DB.GRAPH.GRAPH_NODES target ON edge.target_node_id = target.node_id
ORDER BY edge.weight DESC, source.node_id, edge.edge_type;
