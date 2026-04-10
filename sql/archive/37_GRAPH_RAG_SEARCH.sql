-- ============================================================================
-- INSURE Graph RAG Search & Traversal Queries
-- Purpose: Graph exploration test queries and path finding
-- Date: 2026-04-09
-- ============================================================================

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
