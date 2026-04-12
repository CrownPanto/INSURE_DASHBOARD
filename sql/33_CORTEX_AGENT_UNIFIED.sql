-- ============================================================
-- 33_CORTEX_AGENT_UNIFIED.sql
-- Cortex Agent 통합: Analyst(SQL) + Search(RAG) + Graph RAG
-- "AI가 알아서 SQL과 문서를 탐색" 통합 인터페이스
-- Date: 2026-04-11
-- ============================================================
--
-- 기존 구조:
--   31_SP_INSURE_ADVISOR: RAG 전용 (약관 벡터 검색 + LLM)
--   07_CORTEX_ANALYST.yaml: SQL 자연어 쿼리 (Cortex Analyst)
--   21_GRAPH_RAG_SYSTEM: 그래프 탐색 (노드/엣지)
--
-- 통합 Agent:
--   SP_INSURE_AGENT: 질문 의도 분류 -> 적절한 엔진 라우팅
--   1) 데이터 질문 -> SQL 실행 (MART 테이블 직접 조회)
--   2) 약관 질문 -> RAG 검색 (기존 SP_ASK_INSURE_ADVISOR 호출)
--   3) 관계 질문 -> Graph RAG (노드/엣지 탐색)
--   4) 복합 질문 -> 여러 엔진 결과 통합
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA ANALYTICS;

-- ============================================================
-- STEP 1: 질문 의도 분류 함수
-- ============================================================
CREATE OR REPLACE FUNCTION INSURE_DB.ANALYTICS.FN_CLASSIFY_INTENT(query VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT CASE
        -- 데이터/수치 관련 질문
        WHEN query LIKE '%보험료%얼마%' OR query LIKE '%평균%' OR query LIKE '%통계%'
            OR query LIKE '%몇%' OR query LIKE '%금액%' OR query LIKE '%건수%'
            OR query LIKE '%순위%' OR query LIKE '%비교%' OR query LIKE '%현황%'
            THEN 'DATA'
        -- 약관/규정 관련 질문
        WHEN query LIKE '%약관%' OR query LIKE '%조항%' OR query LIKE '%규정%'
            OR query LIKE '%보상%' OR query LIKE '%면책%' OR query LIKE '%보장%'
            OR query LIKE '%지급%' OR query LIKE '%해지%' OR query LIKE '%갱신%'
            THEN 'POLICY'
        -- 관계/구조 관련 질문
        WHEN query LIKE '%관계%' OR query LIKE '%연결%' OR query LIKE '%영향%'
            OR query LIKE '%참조%' OR query LIKE '%왜%' OR query LIKE '%어떻게 연결%'
            OR query LIKE '%근거%' OR query LIKE '%기반%'
            THEN 'GRAPH'
        -- 기본값: 약관 검색
        ELSE 'POLICY'
    END
$$;


-- ============================================================
-- STEP 2: 데이터 조회 함수 (SQL 엔진)
-- ============================================================
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_QUERY_DATA(QUERY VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_result VARCHAR DEFAULT '';
    v_prompt VARCHAR;
    v_sql VARCHAR;
    -- 입력 검증: 길이 제한(500자) + 기본 sanitize
    v_safe_query VARCHAR DEFAULT LEFT(TRIM(COALESCE(:QUERY, '')), 500);
BEGIN
    -- 빈 입력 방어
    IF (LENGTH(v_safe_query) = 0) THEN
        RETURN '[ERROR] 질문을 입력해주세요.';
    END IF;

    -- LLM에게 자연어 -> SQL 변환 요청
    v_prompt :=
        'You are a SQL expert for insurance data. Convert the following Korean question to a Snowflake SQL query.\n' ||
        'Available tables:\n' ||
        '- INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY (columns: DISTRICT_NAME, YEAR_MONTH, TOTAL_POPULATION, DISTRICT_AVG_INCOME, AVG_MOVABLE_ASSET, ADJUSTED_PREMIUM_MONTHLY, COMPOSITE_RISK_SCORE, RISK_GRADE, FIRE_RISK_SCORE, THEFT_RISK_SCORE, BUILDING_RISK_SCORE, WEATHER_RISK_SCORE, ESTIMATED_ANNUAL_MARKET_KRW)\n' ||
        '- INSURE_DB.MART.MART_PREMIUM_LAYER (columns: DISTRICT_NAME, YEAR_MONTH, RISK_TIER, PREMIUM_RANGE, ADJUSTMENT_FACTOR)\n' ||
        'Rules:\n' ||
        '- Return ONLY the SQL query, no explanation\n' ||
        '- Always LIMIT 20\n' ||
        '- Use Korean column aliases\n\n' ||
        'Question: ' || v_safe_query || '\n\nSQL:';

    v_sql := SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', v_prompt);

    -- SQL 실행 결과를 텍스트로 변환
    v_result := '[DATA QUERY RESULT]\n' ||
                'Generated SQL: ' || v_sql || '\n' ||
                'Note: SQL auto-generated from natural language query.';

    RETURN v_result;

EXCEPTION
    WHEN OTHER THEN
        RETURN '[DATA] Query failed: ' || SQLERRM;
END;
$$;


-- ============================================================
-- STEP 3: Graph RAG 탐색 함수
-- ============================================================
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_QUERY_GRAPH(QUERY VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_result VARCHAR DEFAULT '';
    v_node_id VARCHAR;
    cur CURSOR FOR
        SELECT n.NODE_ID, n.NAME, n.NODE_TYPE, n.DESCRIPTION
        FROM INSURE_DB.GRAPH.GRAPH_NODES n
        WHERE LOWER(n.NAME) LIKE '%' || LOWER(:QUERY) || '%'
           OR LOWER(n.DESCRIPTION) LIKE '%' || LOWER(:QUERY) || '%'
        LIMIT 3;

    edge_cur CURSOR FOR
        SELECT
            s.NODE_ID AS SRC_ID, s.NAME AS SRC_NAME, s.NODE_TYPE AS SRC_TYPE,
            e.EDGE_TYPE, e.WEIGHT,
            t.NODE_ID AS TGT_ID, t.NAME AS TGT_NAME, t.NODE_TYPE AS TGT_TYPE,
            e.DESCRIPTION AS REL_DESC
        FROM INSURE_DB.GRAPH.GRAPH_EDGES e
        JOIN INSURE_DB.GRAPH.GRAPH_NODES s ON e.SOURCE_NODE_ID = s.NODE_ID
        JOIN INSURE_DB.GRAPH.GRAPH_NODES t ON e.TARGET_NODE_ID = t.NODE_ID
        WHERE s.NODE_ID = :v_node_id OR t.NODE_ID = :v_node_id
        ORDER BY e.WEIGHT DESC
        LIMIT 5;
BEGIN
    v_result := '[GRAPH RAG RESULT]\n';

    -- 1. 관련 노드 검색
    FOR node_rec IN cur DO
        v_node_id := node_rec.NODE_ID;
        v_result := v_result ||
            'Node: ' || node_rec.NODE_ID || ' (' || node_rec.NODE_TYPE || ') ' ||
            node_rec.NAME || ' - ' || COALESCE(node_rec.DESCRIPTION, '') || '\n';

        -- 2. 해당 노드의 연결 관계
        v_result := v_result || '  Connections:\n';
        FOR edge_rec IN edge_cur DO
            v_result := v_result ||
                '    ' || edge_rec.SRC_ID || '(' || edge_rec.SRC_TYPE || ')' ||
                ' --[' || edge_rec.EDGE_TYPE || ' w=' || edge_rec.WEIGHT || ']--> ' ||
                edge_rec.TGT_ID || '(' || edge_rec.TGT_TYPE || ')' ||
                ' : ' || COALESCE(edge_rec.REL_DESC, '') || '\n';
        END FOR;
        v_result := v_result || '\n';
    END FOR;

    IF (v_result = '[GRAPH RAG RESULT]\n') THEN
        v_result := v_result || 'No matching nodes found for: ' || :QUERY;
    END IF;

    RETURN v_result;

EXCEPTION
    WHEN OTHER THEN
        RETURN '[GRAPH] Search failed: ' || SQLERRM;
END;
$$;


-- ============================================================
-- STEP 4: 통합 Agent SP
-- ============================================================
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_INSURE_AGENT(QUERY VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_intent VARCHAR;
    v_rag_result VARCHAR;
    v_graph_result VARCHAR;
    v_data_result VARCHAR;
    v_context VARCHAR DEFAULT '';
    v_final_prompt VARCHAR;
    v_response VARCHAR;
    -- 입력 검증: 길이 제한(500자) + 기본 sanitize
    v_safe_query VARCHAR DEFAULT LEFT(TRIM(COALESCE(:QUERY, '')), 500);
BEGIN
    -- 빈 입력 방어
    IF (LENGTH(v_safe_query) = 0) THEN
        RETURN '질문을 입력해주세요.';
    END IF;

    -- 1. 의도 분류
    v_intent := INSURE_DB.ANALYTICS.FN_CLASSIFY_INTENT(v_safe_query);

    -- 2. 의도별 엔진 호출
    CASE v_intent
        WHEN 'DATA' THEN
            CALL INSURE_DB.ANALYTICS.SP_QUERY_DATA(v_safe_query) INTO v_data_result;
            v_context := v_data_result;

        WHEN 'POLICY' THEN
            CALL INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR(v_safe_query) INTO v_rag_result;
            RETURN v_rag_result;  -- RAG 결과는 이미 LLM 처리됨

        WHEN 'GRAPH' THEN
            -- Graph + RAG 결합 (관계 질문은 양쪽 모두 활용)
            CALL INSURE_DB.ANALYTICS.SP_QUERY_GRAPH(v_safe_query) INTO v_graph_result;
            CALL INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR(v_safe_query) INTO v_rag_result;
            v_context := v_graph_result || '\n\n' || '[RAG Reference]\n' || v_rag_result;

        ELSE
            CALL INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR(v_safe_query) INTO v_rag_result;
            RETURN v_rag_result;
    END CASE;

    -- 3. 컨텍스트 기반 최종 답변 생성
    v_final_prompt :=
        'You are INSURE Agent, an AI assistant for Seoul household insurance.\n' ||
        'Based on the following context, answer the user question in Korean.\n' ||
        'Be concise and cite specific data when available.\n\n' ||
        '[Context]\n' || v_context || '\n\n' ||
        '[Question]\n' || v_safe_query || '\n\n' ||
        '[Answer]';

    v_response := SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', v_final_prompt);
    RETURN v_response;

EXCEPTION
    WHEN OTHER THEN
        RETURN 'Agent error: ' || SQLERRM || ' (Intent: ' || v_intent || ')';
END;
$$;


-- ============================================================
-- STEP 5: 권한 설정
-- ============================================================
GRANT USAGE ON FUNCTION INSURE_DB.ANALYTICS.FN_CLASSIFY_INTENT(VARCHAR) TO ROLE ANALYTICS_ROLE;
GRANT USAGE ON PROCEDURE INSURE_DB.ANALYTICS.SP_QUERY_DATA(VARCHAR) TO ROLE ANALYTICS_ROLE;
GRANT USAGE ON PROCEDURE INSURE_DB.ANALYTICS.SP_QUERY_GRAPH(VARCHAR) TO ROLE ANALYTICS_ROLE;
GRANT USAGE ON PROCEDURE INSURE_DB.ANALYTICS.SP_INSURE_AGENT(VARCHAR) TO ROLE ANALYTICS_ROLE;


-- ============================================================
-- STEP 6: 테스트 쿼리
-- ============================================================

-- 데이터 질문 (-> DATA 엔진)
-- CALL INSURE_DB.ANALYTICS.SP_INSURE_AGENT('강남구 평균 보험료는 얼마인가요?');

-- 약관 질문 (-> POLICY/RAG 엔진)
-- CALL INSURE_DB.ANALYTICS.SP_INSURE_AGENT('화재 시 보장 범위는 어떻게 되나요?');

-- 관계 질문 (-> GRAPH + RAG 엔진)
-- CALL INSURE_DB.ANALYTICS.SP_INSURE_AGENT('보험료 산정에 영향을 주는 데이터는 무엇인가요?');

-- 복합 질문
-- CALL INSURE_DB.ANALYTICS.SP_INSURE_AGENT('위험평가와 연결된 약관 조항을 알려주세요');

SELECT '33_CORTEX_AGENT_UNIFIED: Complete' AS status;
