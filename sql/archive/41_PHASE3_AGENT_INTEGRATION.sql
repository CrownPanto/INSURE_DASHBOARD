-- ============================================================================
-- 40_PHASE3_AGENT_INTEGRATION.sql
-- Phase 3: Cortex Agent에 Graph-Enhanced RAG 통합
-- 의존: 39_PHASE3_ENHANCED_SEARCH.sql 실행 완료 후
-- ============================================================================

USE DATABASE INSURE_DB;

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
