-- ============================================================================
-- 39_PHASE3_ENHANCED_SEARCH.sql
-- Phase 3: 통합 검색 함수 (Vector Search + Graph Expansion)
-- 의존: 38_PHASE3_RAG_GRAPH_BRIDGE.sql 실행 완료 후
-- ============================================================================

USE DATABASE INSURE_DB;

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
