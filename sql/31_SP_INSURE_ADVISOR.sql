-- ============================================================
-- 31_SP_INSURE_ADVISOR.sql
-- INSURE 프로젝트: SP_ASK_INSURE_ADVISOR Stored Procedure 생성
-- DB: INSURE_DB | Schema: ANALYTICS
-- Cortex: mistral-large2 (LLM) + e5-base-v2 (임베딩)
-- Generated: 2026-04-11
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA ANALYTICS;

-- ============================================================
-- STEP 1: ANALYTICS 스키마 확인 (없으면 생성)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS INSURE_DB.ANALYTICS;

-- ============================================================
-- STEP 2: SP_ASK_INSURE_ADVISOR 프로시저 생성
-- ============================================================
--
-- 동작 흐름:
--   1. QUERY를 e5-base-v2로 임베딩 변환
--   2. RAG_CHUNKS에서 코사인 유사도 상위 5개 청크 검색
--   3. 검색된 청크 텍스트를 컨텍스트로 구성
--   4. mistral-large2에게 약관 전문 상담사 역할로 프롬프트 전달
--   5. 응답 반환
-- ============================================================

CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR(QUERY VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    chunk_cursor CURSOR FOR
        SELECT
            c.CHUNK_ID,
            c.SOURCE_FILE,
            c.ARTICLE_NO,
            c.ARTICLE_TITLE,
            c.CHUNK_TEXT,
            VECTOR_COSINE_SIMILARITY(
                c.CHUNK_EMBEDDING,
                SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', :QUERY)
            ) AS SIMILARITY_SCORE
        FROM INSURE_DB.RAG.RAG_CHUNKS c
        WHERE c.CHUNK_EMBEDDING IS NOT NULL
        ORDER BY SIMILARITY_SCORE DESC
        LIMIT 5;

    v_chunk_id      VARCHAR;
    v_source_file   VARCHAR;
    v_article_no    VARCHAR;
    v_article_title VARCHAR;
    v_chunk_text    VARCHAR;
    v_similarity    FLOAT;
    v_context       VARCHAR DEFAULT '';
    v_chunk_num     INTEGER DEFAULT 0;
    v_prompt        VARCHAR;
    v_response      VARCHAR;
    v_query_embedding VECTOR(FLOAT, 768);

BEGIN
    v_query_embedding := SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', :QUERY);

    OPEN chunk_cursor;
    FOR chunk_rec IN chunk_cursor DO
        v_chunk_num := v_chunk_num + 1;
        v_context := v_context ||
            '[참고 약관 ' || v_chunk_num || '] ' ||
            '출처: ' || chunk_rec.SOURCE_FILE ||
            ' | 조항: ' || COALESCE(chunk_rec.ARTICLE_NO, '') ||
            ' ' || COALESCE(chunk_rec.ARTICLE_TITLE, '') ||
            '\n' || chunk_rec.CHUNK_TEXT || '\n\n';
    END FOR;
    CLOSE chunk_cursor;

    IF (v_chunk_num = 0) THEN
        RETURN '죄송합니다. 해당 질문과 관련된 약관 정보를 찾을 수 없습니다.';
    END IF;

    v_prompt :=
        '당신은 INSURE 동산보험 전문 상담사입니다. ' ||
        '고객의 질문에 대해 아래의 약관 내용을 참고하여 정확하고 친절하게 답변해 주세요.\n\n' ||
        '답변 지침:\n' ||
        '1. 반드시 아래 제공된 약관 내용에 근거하여 답변하세요.\n' ||
        '2. 약관에 없는 내용은 추측하지 말고 "약관에서 확인할 수 없습니다"라고 안내하세요.\n' ||
        '3. 전문 용어는 쉬운 언어로 풀어서 설명해 주세요.\n' ||
        '4. 답변은 간결하고 명확하게 작성하세요.\n' ||
        '5. 필요시 관련 조항 번호를 명시해 주세요.\n\n' ||
        '[약관 내용]\n' || v_context ||
        '[고객 질문]\n' || :QUERY || '\n\n[답변]';

    v_response := SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', v_prompt);
    RETURN v_response;

EXCEPTION
    WHEN OTHER THEN
        RETURN '오류가 발생했습니다: ' || SQLERRM || '\n코드: ' || SQLCODE;
END;
$$;

SHOW PROCEDURES LIKE 'SP_ASK_INSURE_ADVISOR' IN SCHEMA INSURE_DB.ANALYTICS;

-- 테스트 예시
-- CALL INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR('동산보험에서 화재로 인한 손해는 어떻게 보상받나요?');
-- CALL INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR('보험금을 받을 수 없는 경우는?');
-- CALL INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR('월 보험료는 어떻게 계산되나요?');
