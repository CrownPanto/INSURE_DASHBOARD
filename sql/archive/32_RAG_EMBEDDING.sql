-- ============================================================
-- 32_RAG_EMBEDDING.sql
-- RAG 청크 임베딩 생성 (snowflake-arctic-embed-m, 768차원)
-- 31_RAG_INSERT.sql 실행 후 실행
-- ============================================================

USE DATABASE INSURE_DB;

-- 전체 청크에 임베딩 생성
UPDATE INSURE_DB.RAG.RAG_CHUNKS
SET CHUNK_EMBEDDING = SNOWFLAKE.CORTEX.EMBED_TEXT_768(
    'snowflake-arctic-embed-m',
    CHUNK_TEXT
)
WHERE CHUNK_EMBEDDING IS NULL;

-- 임베딩 생성 확인
SELECT
    COUNT(*) AS total_chunks,
    COUNT(CHUNK_EMBEDDING) AS embedded,
    COUNT(*) - COUNT(CHUNK_EMBEDDING) AS missing
FROM INSURE_DB.RAG.RAG_CHUNKS;

-- 보험사별 청크 수 확인
SELECT
    INSURER,
    PRODUCT,
    COUNT(*) AS chunk_count,
    COUNT(CHUNK_EMBEDDING) AS embedded_count
FROM INSURE_DB.RAG.RAG_CHUNKS
GROUP BY INSURER, PRODUCT
ORDER BY INSURER, PRODUCT;
