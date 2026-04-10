-- ============================================================
-- 33_RAG_SEARCH_TEST.sql
-- RAG 벡터 검색 테스트 쿼리
-- 32_RAG_EMBEDDING.sql 실행 후 실행
-- ============================================================

USE DATABASE INSURE_DB;

-- ============================================================
-- 테스트 1: "화재 보장 범위" 검색
-- ============================================================
WITH query_embedding AS (
    SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768(
        'snowflake-arctic-embed-m',
        '화재로 인한 손해 보장 범위가 어떻게 되나요?'
    ) AS qe
)
SELECT
    c.CHUNK_ID,
    c.CONTEXT,
    c.INSURER,
    c.DOMAIN_PRIORITY,
    VECTOR_COSINE_SIMILARITY(c.CHUNK_EMBEDDING, q.qe) AS similarity
FROM INSURE_DB.RAG.RAG_CHUNKS c, query_embedding q
ORDER BY similarity DESC
LIMIT 5;

-- ============================================================
-- 테스트 2: "냉장고 보험료" 검색
-- ============================================================
WITH query_embedding AS (
    SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768(
        'snowflake-arctic-embed-m',
        '냉장고가 화재로 파손되면 보상금은 얼마인가요?'
    ) AS qe
)
SELECT
    c.CHUNK_ID,
    c.CONTEXT,
    c.INSURER,
    c.SQL_REFERENCES,
    VECTOR_COSINE_SIMILARITY(c.CHUNK_EMBEDDING, q.qe) AS similarity
FROM INSURE_DB.RAG.RAG_CHUNKS c, query_embedding q
ORDER BY similarity DESC
LIMIT 5;

-- ============================================================
-- 테스트 3: "보험료 할인" 검색 (특화약관 SQL 참조 확인)
-- ============================================================
WITH query_embedding AS (
    SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768(
        'snowflake-arctic-embed-m',
        '보험료 할인 조건과 할증 기준이 무엇인가요?'
    ) AS qe
)
SELECT
    c.CHUNK_ID,
    c.CONTEXT,
    c.INSURER,
    c.SQL_REFERENCES,
    VECTOR_COSINE_SIMILARITY(c.CHUNK_EMBEDDING, q.qe) AS similarity
FROM INSURE_DB.RAG.RAG_CHUNKS c, query_embedding q
ORDER BY similarity DESC
LIMIT 5;

-- ============================================================
-- 테스트 4: 특화약관 SQL 참조 필드 검증
-- ============================================================
SELECT
    CHUNK_ID,
    CONTEXT,
    SQL_REFERENCES
FROM INSURE_DB.RAG.RAG_CHUNKS
WHERE SQL_REFERENCES IS NOT NULL
ORDER BY CHUNK_ID;
