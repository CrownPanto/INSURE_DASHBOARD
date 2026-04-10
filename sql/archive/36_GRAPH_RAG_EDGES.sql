-- ============================================================================
-- INSURE Graph RAG Edges Insertion
-- Purpose: Insert ~30 edges representing relationships between graph nodes
-- Edge Types: REFERENCES | CALCULATES | COVERS | LIMITS | APPLIES | PREDICTS
-- Date: 2026-04-09
-- ============================================================================

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
