-- ================================================================
-- 39_PHASE3_INTEGRATION.sql
-- Phase 3 통합: RAG-Graph 브릿지 + 통합 검색 + Agent 연동
-- Consolidated from: 39_PHASE3_RAG_GRAPH_BRIDGE.sql
--                    40_PHASE3_ENHANCED_SEARCH.sql
--                    41_PHASE3_AGENT_INTEGRATION.sql
-- ================================================================

USE DATABASE INSURE_DB;

-- ================================================================
-- PART 1: RAG-Graph 브릿지 (from 39_PHASE3_RAG_GRAPH_BRIDGE.sql)
-- ================================================================

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


-- ================================================================
-- PART 2: 통합 검색 (from 40_PHASE3_ENHANCED_SEARCH.sql)
-- ================================================================

-- ============================================================================
-- 1. enhanced_search 프로시저
-- 입력: 자연어 질의
-- 동작: 벡터 검색 → 브릿지로 Graph 노드 찾기 → 엣지 탐색 → 관련 청크 확장
-- 출력: 원본 RAG 결과 + Graph 확장 결과 (통합, 중복제거, 재순위)
-- ============================================================================

CREATE OR REPLACE PROCEDURE INSURE_DB.GRAPH.SP_ENHANCED_SEARCH(
    QUERY_TEXT VARCHAR,
    TOP_K INT DEFAULT 5,
    EXPAND_HOPS INT DEFAULT 2,
    MIN_WEIGHT FLOAT DEFAULT 0.3
)
RETURNS TABLE (
    CHUNK_ID VARCHAR,
    CONTEXT VARCHAR,
    CHUNK_TEXT VARCHAR,
    SOURCE_TYPE VARCHAR,
    SCORE FLOAT,
    GRAPH_PATH VARCHAR,
    RELATED_NODES ARRAY
)
LANGUAGE SQL
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (
        WITH
        -- ================================================================
        -- Step 1: 벡터 유사도 검색 (기존 RAG)
        -- ================================================================
        vector_hits AS (
            SELECT
                rc.CHUNK_ID,
                rc.CONTEXT,
                rc.CHUNK_TEXT,
                'VECTOR' AS SOURCE_TYPE,
                VECTOR_COSINE_SIMILARITY(
                    rc.CHUNK_EMBEDDING,
                    SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', :QUERY_TEXT)
                ) AS SCORE,
                NULL AS GRAPH_PATH,
                rc.SQL_REFERENCES AS RELATED_NODES
            FROM INSURE_DB.RAG.RAG_CHUNKS rc
            WHERE rc.CHUNK_EMBEDDING IS NOT NULL
            ORDER BY SCORE DESC
            LIMIT :TOP_K
        ),

        -- ================================================================
        -- Step 2: 벡터 히트 → 브릿지 → Graph 노드 찾기
        -- ================================================================
        matched_graph_nodes AS (
            SELECT DISTINCT
                b.graph_node_id,
                vh.SCORE AS origin_score,
                b.confidence AS bridge_confidence
            FROM vector_hits vh
            JOIN INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE b
                ON vh.CHUNK_ID = b.chunk_id
            WHERE b.confidence >= 0.5
        ),

        -- ================================================================
        -- Step 3: Graph 엣지 탐색 (1-2홉 확장)
        -- ================================================================
        graph_neighbors AS (
            -- 1홉: 직접 연결된 노드
            SELECT
                mgn.graph_node_id AS origin_node,
                e.target_node_id AS expanded_node,
                e.edge_type,
                e.weight AS edge_weight,
                mgn.origin_score,
                mgn.bridge_confidence,
                1 AS hop_count,
                CONCAT(mgn.graph_node_id, ' -[', e.edge_type, ']-> ', e.target_node_id) AS graph_path
            FROM matched_graph_nodes mgn
            JOIN INSURE_DB.GRAPH.GRAPH_EDGES e
                ON mgn.graph_node_id = e.source_node_id
            WHERE e.weight >= :MIN_WEIGHT

            UNION ALL

            -- 역방향 1홉: 이 노드를 참조하는 노드
            SELECT
                mgn.graph_node_id AS origin_node,
                e.source_node_id AS expanded_node,
                e.edge_type,
                e.weight AS edge_weight,
                mgn.origin_score,
                mgn.bridge_confidence,
                1 AS hop_count,
                CONCAT(e.source_node_id, ' -[', e.edge_type, ']-> ', mgn.graph_node_id) AS graph_path
            FROM matched_graph_nodes mgn
            JOIN INSURE_DB.GRAPH.GRAPH_EDGES e
                ON mgn.graph_node_id = e.target_node_id
            WHERE e.weight >= :MIN_WEIGHT
        ),

        -- ================================================================
        -- Step 4: 확장된 Graph 노드 → 브릿지 역매핑 → RAG 청크
        -- ================================================================
        graph_expanded_chunks AS (
            SELECT
                rc.CHUNK_ID,
                rc.CONTEXT,
                rc.CHUNK_TEXT,
                'GRAPH_EXPAND' AS SOURCE_TYPE,
                -- 점수: 원본벡터점수 × 엣지가중치 × 브릿지신뢰도 × 감쇠(0.7)
                gn.origin_score * gn.edge_weight * gn.bridge_confidence * 0.7 AS SCORE,
                gn.graph_path AS GRAPH_PATH,
                rc.SQL_REFERENCES AS RELATED_NODES
            FROM graph_neighbors gn
            -- 확장된 Graph 노드가 CLAUSE인 경우: 브릿지로 RAG 청크 찾기
            JOIN INSURE_DB.GRAPH.RAG_GRAPH_BRIDGE b2
                ON gn.expanded_node = b2.graph_node_id
            JOIN INSURE_DB.RAG.RAG_CHUNKS rc
                ON b2.chunk_id = rc.CHUNK_ID
            WHERE rc.CHUNK_ID NOT IN (SELECT CHUNK_ID FROM vector_hits)
              AND b2.confidence >= 0.5

            UNION ALL

            -- 확장된 Graph 노드가 DATA/RULE/MODEL인 경우: 노드 정보를 직접 반환
            SELECT
                CONCAT('GRAPH:', gn.expanded_node) AS CHUNK_ID,
                CONCAT('[Graph Node] ', nd.name) AS CONTEXT,
                CONCAT(
                    nd.name, ' (', nd.node_type, ')\n',
                    COALESCE(nd.description, ''),
                    CASE WHEN nd.table_name IS NOT NULL
                        THEN CONCAT('\n테이블: ', nd.schema_name, '.', nd.table_name)
                        ELSE ''
                    END,
                    CASE WHEN nd.rule_version IS NOT NULL
                        THEN CONCAT('\n버전: ', nd.rule_version)
                        ELSE ''
                    END
                ) AS CHUNK_TEXT,
                'GRAPH_NODE' AS SOURCE_TYPE,
                gn.origin_score * gn.edge_weight * 0.6 AS SCORE,
                gn.graph_path AS GRAPH_PATH,
                NULL AS RELATED_NODES
            FROM graph_neighbors gn
            JOIN INSURE_DB.GRAPH.GRAPH_NODES nd
                ON gn.expanded_node = nd.node_id
            WHERE nd.node_type IN ('DATA', 'RULE', 'MODEL')
        ),

        -- ================================================================
        -- Step 5: 통합 + 중복제거 + 재순위
        -- ================================================================
        merged_results AS (
            SELECT * FROM vector_hits
            UNION ALL
            SELECT * FROM graph_expanded_chunks
        ),

        deduplicated AS (
            SELECT
                *,
                ROW_NUMBER() OVER (PARTITION BY CHUNK_ID ORDER BY SCORE DESC) AS rn
            FROM merged_results
        )

        SELECT
            CHUNK_ID,
            CONTEXT,
            CHUNK_TEXT,
            SOURCE_TYPE,
            ROUND(SCORE, 4) AS SCORE,
            GRAPH_PATH,
            RELATED_NODES
        FROM deduplicated
        WHERE rn = 1
        ORDER BY SCORE DESC
        LIMIT :TOP_K * 3
    );
    RETURN TABLE(res);
END;
$$;

-- ============================================================================
-- 2. 간소화된 래퍼 함수 (Cortex Agent Tool용)
-- Agent가 호출하기 쉬운 단일 VARCHAR 반환
-- ============================================================================

CREATE OR REPLACE FUNCTION INSURE_DB.GRAPH.AGENT_ENHANCED_SEARCH(QUERY_TEXT VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
SELECT LISTAGG(
    CONCAT(
        '### [', CHUNK_ID, '] (', SOURCE_TYPE, ' | score: ', ROUND(SCORE, 3), ')\n',
        CONTEXT, '\n',
        LEFT(CHUNK_TEXT, 500),
        CASE WHEN GRAPH_PATH IS NOT NULL
            THEN CONCAT('\n📊 Graph 경로: ', GRAPH_PATH)
            ELSE ''
        END,
        '\n'
    ),
    '\n---\n'
) WITHIN GROUP (ORDER BY SCORE DESC)
FROM TABLE(INSURE_DB.GRAPH.SP_ENHANCED_SEARCH(QUERY_TEXT, 5, 2, 0.3))
$$;

-- ============================================================================
-- 3. 테스트 쿼리
-- ============================================================================

-- 테스트 1: "화재 보장 범위" (벡터 + Graph 확장 비교)
CALL INSURE_DB.GRAPH.SP_ENHANCED_SEARCH('화재로 인한 손해 보장 범위가 어떻게 되나요?', 5, 2, 0.3);

-- 테스트 2: "보험료 산정 기준" (RULE/DATA 노드까지 확장되는지 확인)
CALL INSURE_DB.GRAPH.SP_ENHANCED_SEARCH('보험료는 어떤 기준으로 산정되나요?', 5, 2, 0.3);

-- 테스트 3: "강남구 위험도" (DATA 노드 참조 확인)
CALL INSURE_DB.GRAPH.SP_ENHANCED_SEARCH('강남구의 화재 위험도와 보험료 관계는?', 5, 2, 0.3);

-- 테스트 4: Agent 래퍼 함수 테스트
SELECT INSURE_DB.GRAPH.AGENT_ENHANCED_SEARCH('냉장고가 화재로 파손되면 보상금은 얼마인가요?');

-- 테스트 5: Plain RAG vs Enhanced Search 비교
-- Plain RAG 결과
SELECT '--- PLAIN RAG ---' AS SECTION;
WITH qe AS (
    SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m',
        '면책사항에 해당하는 경우는?') AS emb
)
SELECT CHUNK_ID, CONTEXT, ROUND(VECTOR_COSINE_SIMILARITY(CHUNK_EMBEDDING, qe.emb), 4) AS score
FROM INSURE_DB.RAG.RAG_CHUNKS, qe
ORDER BY score DESC LIMIT 5;

-- Enhanced Search 결과 (Graph 확장 포함)
SELECT '--- ENHANCED SEARCH ---' AS SECTION;
CALL INSURE_DB.GRAPH.SP_ENHANCED_SEARCH('면책사항에 해당하는 경우는?', 5, 2, 0.3);


-- ================================================================
-- PART 3: Agent 연동 (from 41_PHASE3_AGENT_INTEGRATION.sql)
-- ================================================================

-- ============================================================================
-- 1. Cortex Search Service 생성 (벡터 검색 가속화)
-- ============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURE_DB.RAG.TERMS_SEARCH_SERVICE
    ON (CHUNK_TEXT)
    ATTRIBUTES INSURER, PRODUCT, CATEGORY, ARTICLE_NUMBER, DOMAIN_PRIORITY
    WAREHOUSE = 'COMPUTE_WH'
    TARGET_LAG = '1 minute'
    AS (
        SELECT
            CHUNK_ID,
            CHUNK_TEXT,
            CONTEXT,
            INSURER,
            PRODUCT,
            CATEGORY,
            ARTICLE_NUMBER,
            ARTICLE_TITLE,
            DOMAIN_PRIORITY
        FROM INSURE_DB.RAG.RAG_CHUNKS
    );

-- ============================================================================
-- 2. Graph 탐색 전용 Tool 함수 (Agent가 직접 호출)
-- ============================================================================

-- Tool 1: 특정 조항의 관련 조항/데이터 탐색
CREATE OR REPLACE FUNCTION INSURE_DB.GRAPH.AGENT_TRACE_CLAUSE(CLAUSE_NAME VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
SELECT LISTAGG(
    CONCAT(
        gn_target.name, ' (', gn_target.node_type, ')',
        ' | 관계: ', e.edge_type,
        ' | 강도: ', ROUND(e.weight, 2),
        ' | ', COALESCE(e.description, '')
    ),
    '\n'
) WITHIN GROUP (ORDER BY e.weight DESC)
FROM INSURE_DB.GRAPH.GRAPH_NODES gn_source
JOIN INSURE_DB.GRAPH.GRAPH_EDGES e
    ON gn_source.node_id = e.source_node_id
JOIN INSURE_DB.GRAPH.GRAPH_NODES gn_target
    ON e.target_node_id = gn_target.node_id
WHERE gn_source.name ILIKE CONCAT('%', CLAUSE_NAME, '%')
   OR gn_source.node_id = CLAUSE_NAME
$$;

-- Tool 2: 데이터 테이블의 약관 근거 역추적
CREATE OR REPLACE FUNCTION INSURE_DB.GRAPH.AGENT_DATA_LINEAGE(TABLE_NAME_QUERY VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
SELECT LISTAGG(
    CONCAT(
        '약관 근거: ', gn_source.name,
        ' (', gn_source.chapter, ')',
        ' | 관계: ', e.edge_type,
        ' | 강도: ', ROUND(e.weight, 2)
    ),
    '\n'
) WITHIN GROUP (ORDER BY e.weight DESC)
FROM INSURE_DB.GRAPH.GRAPH_NODES gn_target
JOIN INSURE_DB.GRAPH.GRAPH_EDGES e
    ON gn_target.node_id = e.target_node_id
JOIN INSURE_DB.GRAPH.GRAPH_NODES gn_source
    ON e.source_node_id = gn_source.node_id
WHERE gn_target.node_type = 'DATA'
  AND (gn_target.table_name ILIKE CONCAT('%', TABLE_NAME_QUERY, '%')
       OR gn_target.name ILIKE CONCAT('%', TABLE_NAME_QUERY, '%'))
  AND gn_source.node_type = 'CLAUSE'
$$;

-- Tool 3: 보험료 계산 경로 전체 추적 (고정 시나리오)
CREATE OR REPLACE FUNCTION INSURE_DB.GRAPH.AGENT_PREMIUM_FLOW()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
WITH RECURSIVE premium_path AS (
    SELECT
        n.node_id, n.name, n.node_type,
        e.edge_type, e.weight,
        1 AS hop,
        ARRAY_CONSTRUCT(n.node_id) AS visited,
        n.name AS path_display
    FROM INSURE_DB.GRAPH.GRAPH_NODES n
    JOIN INSURE_DB.GRAPH.GRAPH_EDGES e ON n.node_id = e.source_node_id
    WHERE n.node_id = 'CL_06'  -- 보험료산정 출발

    UNION ALL

    SELECT
        n2.node_id, n2.name, n2.node_type,
        e2.edge_type, e2.weight,
        pp.hop + 1,
        ARRAY_APPEND(pp.visited, n2.node_id),
        CONCAT(pp.path_display, ' → ', n2.name)
    FROM premium_path pp
    JOIN INSURE_DB.GRAPH.GRAPH_EDGES e2 ON pp.node_id = e2.source_node_id
    JOIN INSURE_DB.GRAPH.GRAPH_NODES n2 ON e2.target_node_id = n2.node_id
    WHERE pp.hop < 3
      AND NOT ARRAY_CONTAINS(n2.node_id, pp.visited)
)
SELECT LISTAGG(
    CONCAT('Hop ', hop, ': ', path_display, ' (', edge_type, ', weight=', ROUND(weight,2), ')'),
    '\n'
) WITHIN GROUP (ORDER BY hop, weight DESC)
FROM premium_path
$$;

-- ============================================================================
-- 3. Agent System Prompt (SP_ASK_INSURE_ADVISOR 수정용 참고)
-- ============================================================================

/*
아래 시스템 프롬프트를 기존 SP_ASK_INSURE_ADVISOR의 system_prompt에 추가/교체합니다.

=== SYSTEM PROMPT ===

당신은 INSURE 동산종합보험 전문 어시스턴트입니다.
사용자의 보험 관련 질문에 정확하고 근거 있는 답변을 제공합니다.

## 사용 가능한 도구

1. **AGENT_ENHANCED_SEARCH(질의)**: 약관 검색 + 관련 조항 자동 확장
   - 벡터 유사도 검색으로 관련 약관 청크를 찾고
   - Graph를 통해 참조/면책/전제조건 관련 조항까지 자동 확장합니다
   - 항상 이 도구를 먼저 호출하세요

2. **AGENT_TRACE_CLAUSE(조항명)**: 특정 조항의 관계 탐색
   - 예: AGENT_TRACE_CLAUSE('보장범위') → 관련 데이터/규칙 목록

3. **AGENT_DATA_LINEAGE(테이블명)**: 데이터의 약관 근거 역추적
   - 예: AGENT_DATA_LINEAGE('INT_DISTRICT_RISK_SCORE') → 참조하는 약관 조항

4. **AGENT_PREMIUM_FLOW()**: 보험료 산정 전체 경로 시각화

## 답변 규칙

- 검색 결과에 SOURCE_TYPE='GRAPH_EXPAND' 또는 'GRAPH_NODE'가 포함된 경우,
  관련 조항 간의 관계를 명시적으로 설명하세요.
  예: "제3조(보장범위)에 따르면 화재 손해가 보장되나, 제5조(면책사항)에 의해 고의 화재는 제외됩니다."

- GRAPH_PATH가 표시되면 그 관계를 자연어로 풀어서 설명하세요.
  예: "CL_06 -[LIMITS]-> RL_01" → "보험료 산정(제6조)은 5구간 비선형 리스크 커브(v1.3)에 의해 제한됩니다."

- DATA/RULE 노드가 반환되면 실제 테이블명과 주요 컬럼을 언급하세요.
  예: "이 계산은 INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE 테이블의 COMPOSITE_RISK_SCORE를 기반으로 합니다."

- 항상 근거 조항 번호를 명시하세요.

=== END SYSTEM PROMPT ===
*/

-- ============================================================================
-- 4. 통합 테스트: 데모 시나리오 3가지
-- ============================================================================

-- 시나리오 1: 기본 질의 → Graph 확장 효과 확인
-- "태풍으로 인한 피해가 보장되나요?"
-- 기대: 제3조(보장범위) + 제5조(면책사항) + DT_07(기상위험지수) 함께 반환
SELECT '=== 시나리오 1: 태풍 피해 보장 ===' AS DEMO;
CALL INSURE_DB.GRAPH.SP_ENHANCED_SEARCH('태풍으로 인한 피해가 보장되나요?', 5, 2, 0.3);

-- 시나리오 2: 보험료 산정 경로 추적
-- "보험료는 어떻게 계산되나요?"
-- 기대: 제6조 + RL_01(리스크커브) + RL_02(7단계파이프라인) + DT_02(위험점수) 연쇄
SELECT '=== 시나리오 2: 보험료 계산 경로 ===' AS DEMO;
CALL INSURE_DB.GRAPH.SP_ENHANCED_SEARCH('보험료는 어떻게 계산되나요?', 5, 2, 0.3);
SELECT INSURE_DB.GRAPH.AGENT_PREMIUM_FLOW();

-- 시나리오 3: 데이터 리니지 역추적
-- "위험점수 데이터는 어떤 약관 조항에 근거하나요?"
-- 기대: DT_02 → CL_04(위험평가), CL_06(보험료산정), CL_05(면책) 역추적
SELECT '=== 시나리오 3: 데이터 리니지 ===' AS DEMO;
SELECT INSURE_DB.GRAPH.AGENT_DATA_LINEAGE('INT_DISTRICT_RISK_SCORE');

-- ============================================================================
-- 5. 성능 로깅
-- ============================================================================

-- 테스트 쿼리 실행시간 로깅
INSERT INTO INSURE_DB.GRAPH.GRAPH_TRAVERSAL_LOG
    (query_type, source_node_id, hops, result_count, query_text)
SELECT
    'enhanced_search',
    NULL,
    2,
    (SELECT COUNT(*) FROM TABLE(INSURE_DB.GRAPH.SP_ENHANCED_SEARCH('화재 보장', 5, 2, 0.3))),
    '화재 보장';
