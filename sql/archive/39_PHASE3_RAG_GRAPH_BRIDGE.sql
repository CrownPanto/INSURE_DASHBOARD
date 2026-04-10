-- ============================================================================
-- 38_PHASE3_RAG_GRAPH_BRIDGE.sql
-- Phase 3: RAG ↔ Graph 브릿지 레이어
-- 목적: RAG_CHUNKS(chunk_id) ↔ GRAPH_NODES(node_id) 매핑 테이블 생성
-- 의존: 30-33 (RAG), 34-37 (Graph) 실행 완료 후
-- ============================================================================

USE DATABASE INSURE_DB;

-- ============================================================================
-- 1. 매핑 테이블 생성
-- RAG chunk_id (예: INSURE_동산종합보험_01_제3조)
--   ↔ Graph node_id (예: CL_02)
-- 하나의 chunk가 여러 Graph node에 매핑될 수 있음 (제1조~제2조 병합 청크)
-- ============================================================================
CREATE OR REPLACE TABLE INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE (
    bridge_id       INT AUTOINCREMENT PRIMARY KEY,
    chunk_id        VARCHAR(200) NOT NULL,      -- RAG.RAG_CHUNKS.CHUNK_ID
    graph_node_id   VARCHAR(10) NOT NULL,       -- GRAPH.GRAPH_NODES.NODE_ID
    match_type      VARCHAR(20) DEFAULT 'ARTICLE_MAP',  -- ARTICLE_MAP | SQL_REF | MANUAL
    confidence      FLOAT DEFAULT 1.0,          -- 매핑 신뢰도 (0~1)
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (graph_node_id) REFERENCES INSURE_DB.GRAPH.GRAPH_NODES(node_id)
);

-- ============================================================================
-- 2. INSURE 특화약관 chunk → CLAUSE 노드 매핑 (직접 매핑)
-- 약관 조항 번호로 매핑: 제N조 → CL_0N
-- ============================================================================
INSERT INTO INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE (chunk_id, graph_node_id, match_type, confidence)
VALUES
-- 제1조~제2조 병합 청크 → CL_01 (목적)
('INSURE_동산종합보험_00_제1조제2조', 'CL_01', 'ARTICLE_MAP', 1.0),
-- 제2조는 용어정의인데 Graph에서 CL_02=보장범위. 실제 약관 구조에 맞게 매핑
-- Graph 35번 기준: CL_01=제1조목적, CL_02=제2조보장범위, CL_03=제3조보험금산출 ...
-- 특화약관 TASK 기준: 제1조목적, 제2조용어정의, 제3조보장범위, 제4조보험금산출 ...
-- → Graph 노드명과 특화약관 조항 번호가 다름! Graph가 내용 기반으로 매핑됨

-- 정확한 매핑 (Graph 노드의 실제 의미 기반):
-- CL_01 = 제1조 목적 → 특화약관 제1조~제2조 (목적+용어)
('INSURE_동산종합보험_01_제3조', 'CL_02', 'ARTICLE_MAP', 1.0),   -- 제3조 보장범위 → CL_02 보장범위
('INSURE_동산종합보험_02_제4조', 'CL_03', 'ARTICLE_MAP', 1.0),   -- 제4조 보험금산출 → CL_03 보험금산출
('INSURE_동산종합보험_02_제4조', 'CL_04', 'ARTICLE_MAP', 0.8),   -- 제4조에 위험평가 내용도 포함
('INSURE_동산종합보험_03_제5조', 'CL_05', 'ARTICLE_MAP', 1.0),   -- 제5조 면책사항 → CL_05 면책사항
('INSURE_동산종합보험_04_제6조', 'CL_06', 'ARTICLE_MAP', 1.0),   -- 제6조 보험료산정 → CL_06 보험료산정
('INSURE_동산종합보험_05_제7조', 'CL_07', 'ARTICLE_MAP', 1.0),   -- 제7조 할인/할증 → CL_07 보험료조정
('INSURE_동산종합보험_06_제8조', 'CL_08', 'ARTICLE_MAP', 1.0),   -- 제8조 보험료납부 → CL_08 계약체결
('INSURE_동산종합보험_07_제9조', 'CL_09', 'ARTICLE_MAP', 1.0),   -- 제9조 계약체결 → CL_09 해지환급
('INSURE_동산종합보험_08_제10조', 'CL_10', 'ARTICLE_MAP', 1.0),  -- 제10조 계약기간 → CL_10 갱신
('INSURE_동산종합보험_09_제11조', 'CL_11', 'ARTICLE_MAP', 1.0),  -- 제11조 해약및환급 → CL_11 통지의무
('INSURE_동산종합보험_10_제12조_p1', 'CL_12', 'ARTICLE_MAP', 1.0), -- 제12조 품목별한도 (파트1)
('INSURE_동산종합보험_10_제12조_p2', 'CL_12', 'ARTICLE_MAP', 1.0), -- 제12조 품목별한도 (파트2)
('INSURE_동산종합보험_11_제13조', 'CL_13', 'ARTICLE_MAP', 1.0),  -- 제13조 분쟁조정
('INSURE_동산종합보험_12_제14조', 'CL_14', 'ARTICLE_MAP', 1.0);  -- 제14조 소비자보호

-- ============================================================================
-- 3. sql_references 기반 DATA 노드 매핑 (자동 생성)
-- 특화약관 청크의 sql_references → Graph DATA 노드 연결
-- ============================================================================

-- 제3조 (보장범위) → DT_02 (INT_DISTRICT_RISK_SCORE - FIRE/THEFT/WEATHER/BUILDING_RISK_SCORE)
INSERT INTO INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE (chunk_id, graph_node_id, match_type, confidence)
VALUES
('INSURE_동산종합보험_01_제3조', 'DT_02', 'SQL_REF', 0.9),   -- FIRE/THEFT/WEATHER/BUILDING_RISK_SCORE
('INSURE_동산종합보험_02_제4조', 'DT_02', 'SQL_REF', 0.9),   -- COMPOSITE_RISK_SCORE
('INSURE_동산종합보험_02_제4조', 'DT_03', 'SQL_REF', 0.8),   -- SEGMENT_ASSET_COEFFICIENTS → 간접 SEED_HOUSEHOLD_GOODS
('INSURE_동산종합보험_04_제6조', 'DT_02', 'SQL_REF', 0.9),   -- COMPOSITE_RISK_SCORE, FIRE/THEFT/WEATHER/BUILDING
('INSURE_동산종합보험_04_제6조', 'DT_08', 'SQL_REF', 0.7),   -- AVG_BASE_PREMIUM → MART_PREMIUM_LAYER
('INSURE_동산종합보험_05_제7조', 'DT_08', 'SQL_REF', 0.8),   -- V_FEEDBACK_ADJUSTMENT → MART_PREMIUM_LAYER
('INSURE_동산종합보험_05_제7조', 'DT_02', 'SQL_REF', 0.7),   -- COMPOSITE_RISK_SCORE
('INSURE_동산종합보험_00_제1조제2조', 'DT_03', 'SQL_REF', 0.8), -- SEED_HOUSEHOLD_GOODS
('INSURE_동산종합보험_10_제12조_p1', 'DT_03', 'SQL_REF', 0.9), -- SEED_HOUSEHOLD_GOODS (DAMAGE_RISK_RATE)
('INSURE_동산종합보험_10_제12조_p2', 'DT_03', 'SQL_REF', 0.9); -- SEED_HOUSEHOLD_GOODS (DAMAGE_RISK_RATE)

-- ============================================================================
-- 4. 실제 보험사 약관 chunk → CLAUSE 매핑 (키워드 기반 간접 매핑)
-- 실제 보험사 약관은 조항 번호가 다르므로 CHAPTER/내용으로 유사 매핑
-- match_type = 'KEYWORD' / confidence 낮게 설정
-- ============================================================================

-- KB손해보험 주택종합보험 - 보장범위 관련 청크 → CL_02
INSERT INTO INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE (chunk_id, graph_node_id, match_type, confidence)
SELECT
    rc.CHUNK_ID,
    'CL_02',
    'KEYWORD',
    0.6
FROM INSURE_DB.RAG.RAG_CHUNKS rc
WHERE rc.INSURER != 'INSURE'
  AND (rc.ARTICLE_TITLE LIKE '%보장%' OR rc.ARTICLE_TITLE LIKE '%목적%')
  AND NOT EXISTS (
    SELECT 1 FROM INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE b
    WHERE b.chunk_id = rc.CHUNK_ID AND b.graph_node_id = 'CL_02'
  );

-- 보험금/산출 관련 → CL_03
INSERT INTO INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE (chunk_id, graph_node_id, match_type, confidence)
SELECT
    rc.CHUNK_ID,
    'CL_03',
    'KEYWORD',
    0.6
FROM INSURE_DB.RAG.RAG_CHUNKS rc
WHERE rc.INSURER != 'INSURE'
  AND (rc.ARTICLE_TITLE LIKE '%보험금%' OR rc.ARTICLE_TITLE LIKE '%산출%' OR rc.ARTICLE_TITLE LIKE '%지급%')
  AND NOT EXISTS (
    SELECT 1 FROM INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE b
    WHERE b.chunk_id = rc.CHUNK_ID AND b.graph_node_id = 'CL_03'
  );

-- 면책/제외 관련 → CL_05
INSERT INTO INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE (chunk_id, graph_node_id, match_type, confidence)
SELECT
    rc.CHUNK_ID,
    'CL_05',
    'KEYWORD',
    0.6
FROM INSURE_DB.RAG.RAG_CHUNKS rc
WHERE rc.INSURER != 'INSURE'
  AND (rc.ARTICLE_TITLE LIKE '%면책%' OR rc.ARTICLE_TITLE LIKE '%제외%' OR rc.CHUNK_TEXT LIKE '%보상하지%')
  AND NOT EXISTS (
    SELECT 1 FROM INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE b
    WHERE b.chunk_id = rc.CHUNK_ID AND b.graph_node_id = 'CL_05'
  );

-- 보험료/할인/할증 관련 → CL_06, CL_07
INSERT INTO INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE (chunk_id, graph_node_id, match_type, confidence)
SELECT
    rc.CHUNK_ID,
    'CL_06',
    'KEYWORD',
    0.5
FROM INSURE_DB.RAG.RAG_CHUNKS rc
WHERE rc.INSURER != 'INSURE'
  AND (rc.ARTICLE_TITLE LIKE '%보험료%' OR rc.ARTICLE_TITLE LIKE '%할인%' OR rc.ARTICLE_TITLE LIKE '%할증%')
  AND NOT EXISTS (
    SELECT 1 FROM INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE b
    WHERE b.chunk_id = rc.CHUNK_ID AND b.graph_node_id = 'CL_06'
  );

-- 해지/환급 관련 → CL_09
INSERT INTO INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE (chunk_id, graph_node_id, match_type, confidence)
SELECT
    rc.CHUNK_ID,
    'CL_09',
    'KEYWORD',
    0.5
FROM INSURE_DB.RAG.RAG_CHUNKS rc
WHERE rc.INSURER != 'INSURE'
  AND (rc.ARTICLE_TITLE LIKE '%해지%' OR rc.ARTICLE_TITLE LIKE '%환급%' OR rc.ARTICLE_TITLE LIKE '%해약%')
  AND NOT EXISTS (
    SELECT 1 FROM INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE b
    WHERE b.chunk_id = rc.CHUNK_ID AND b.graph_node_id = 'CL_09'
  );

-- ============================================================================
-- 5. 검증
-- ============================================================================

-- 매핑 통계
SELECT
    match_type,
    COUNT(*) AS mapping_count,
    ROUND(AVG(confidence), 2) AS avg_confidence
FROM INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE
GROUP BY match_type
ORDER BY match_type;

-- INSURE 특화약관 매핑 확인 (모든 14개 청크가 매핑되었는지)
SELECT
    b.chunk_id,
    b.graph_node_id,
    gn.name AS graph_node_name,
    b.match_type,
    b.confidence
FROM INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE b
JOIN INSURE_DB.GRAPH.GRAPH_NODES gn ON b.graph_node_id = gn.node_id
WHERE b.chunk_id LIKE 'INSURE%'
ORDER BY b.chunk_id, b.confidence DESC;

-- 매핑되지 않은 Graph 노드 확인
SELECT gn.node_id, gn.name, gn.node_type
FROM INSURE_DB.GRAPH.GRAPH_NODES gn
WHERE gn.node_type = 'CLAUSE'
  AND NOT EXISTS (
    SELECT 1 FROM INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE b WHERE b.graph_node_id = gn.node_id
  );
