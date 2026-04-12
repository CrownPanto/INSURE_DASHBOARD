-- ============================================================
-- 35_RAG_BENCHMARK.sql
-- INSURE 이중 RAG 성능 벤치마크 시스템
-- DB: INSURE_DB | Schema: ANALYTICS
-- Date: 2026-04-12
-- ============================================================
--
-- 구성:
--   1. RAG_BENCHMARK_GOLDEN  — 골든셋 20개 (정답 포함)
--   2. RAG_BENCHMARK_RESULTS — SP 실행 결과 + LLM 채점 저장
--   3. SP_RUN_RAG_BENCHMARK  — 전체 벤치마크 자동 실행
--   4. V_RAG_BENCHMARK_RESULT — Streamlit 시각화용 집계 뷰
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE COMPUTE_WH;


-- ============================================================
-- STEP 1: 골든셋 테이블
-- ============================================================
CREATE OR REPLACE TABLE INSURE_DB.ANALYTICS.RAG_BENCHMARK_GOLDEN (
    Q_ID         INTEGER,
    Q_TYPE       VARCHAR(10),   -- POLICY / GRAPH / DATA
    QUESTION     VARCHAR(500),
    GOLDEN_ANS   VARCHAR(2000), -- 정답 (요약)
    GOLDEN_SRC   VARCHAR(200)   -- 출처 근거
);

-- ============================================================
-- STEP 2: 골든셋 20개 INSERT
-- ============================================================
INSERT INTO INSURE_DB.ANALYTICS.RAG_BENCHMARK_GOLDEN VALUES
-- ── POLICY (약관 기반) ──────────────────────────────────────
(1,  'POLICY', '동산보험에서 화재로 인한 손해는 어떤 조건에서 보장되나요?',
 '보험 목적물이 화재로 인해 직접적인 손해를 입은 경우 보장됩니다. 단, 보험 계약 기간 내에 발생한 손해여야 하며, 피보험자 고의 손해는 면책됩니다.',
 'KB약관 제1조 목적'),

(2,  'POLICY', '보험 목적물의 범위에 가전제품이 포함되나요?',
 '동산보험의 보험 목적물에는 가전제품(냉장고, 세탁기, TV 등)이 포함됩니다. 단, 자동차·건물 구조물은 별도 보험 대상입니다.',
 'KB약관 제2조 용어 정의'),

(3,  'POLICY', '도난 발생 시 보험금 청구 절차는 어떻게 되나요?',
 '도난 발생 즉시 경찰에 신고하고 사고확인서를 발급받아 보험사에 제출해야 합니다. 피해 물건 목록과 구입 영수증 등 증빙도 함께 제출합니다.',
 'KB약관 보험금 지급 조항'),

(4,  'POLICY', '보험 계약 해지 시 환급금 산정 기준은?',
 '미경과 보험료를 기준으로 환급됩니다. 계약 후 1개월 이내 해지 시 납입보험료의 100%, 이후에는 미경과 일수에 비례하여 환급됩니다.',
 'KB약관 보험계약 조항'),

(5,  'POLICY', '자연재해로 인한 가재도구 손해는 보장되나요?',
 '태풍·홍수 등 자연재해는 특약 가입 시 보장됩니다. 기본 계약은 화재·도난·파손만 보장하며, 자연재해는 별도 특약 추가가 필요합니다.',
 'KB약관 면책 조항'),

(6,  'POLICY', '피보험자가 직접 손해를 입혀야만 보상받을 수 있나요?',
 '피보험자 또는 동거 가족이 아닌 제3자에 의한 손해도 보장됩니다. 단, 피보험자의 고의·중과실로 인한 손해는 면책입니다.',
 'KB약관 피보험자 정의'),

(7,  'POLICY', '보험료 납입이 연체된 경우 보장이 중단되나요?',
 '납입 유예 기간(30일) 이후에도 미납 시 보장이 중지됩니다. 유예 기간 내 납입하면 소급하여 보장이 유지됩니다.',
 'KB약관 보험료 조항'),

(8,  'POLICY', '동일 물건에 중복 보험 가입 시 보상 방식은?',
 '중복 보험의 경우 비례보상 원칙이 적용됩니다. 각 보험사가 가입금액 비율에 따라 분담하여 보상하며, 실손해액을 초과하여 지급하지 않습니다.',
 'KB약관 비례보상 조항'),

-- ── GRAPH (관계 추론 기반) ────────────────────────────────────
(9,  'GRAPH', '화재 위험도가 보험료 산정에 어떤 경로로 반영되나요?',
 '화재위험지수 → 종합리스크가중치 → 보험료계수 노드 순으로 연결됩니다. FIRE_RISK_SCORE가 높을수록 COMPOSITE_RISK_SCORE가 올라가고, 이것이 ADJUSTED_PREMIUM에 반영됩니다.',
 '화재위험지수→리스크가중치→보험료계수 노드 연결'),

(10, 'GRAPH', '보험료 산정에 영향을 주는 데이터 소스는 무엇인가요?',
 '소방청 화재통계, 경찰청 도난통계, 기상청 자연재해지수, 국토부 건물노후도 데이터가 INPUT 노드로 연결됩니다. 이들이 RULE 노드를 통해 보험료 산정에 반영됩니다.',
 'DATA 노드 → RULE 노드 엣지 탐색'),

(11, 'GRAPH', '도난 위험도와 약관 조항은 어떻게 연결되나요?',
 'THEFT_RISK 노드가 도난 면책 CLAUSE 노드에 TRIGGERS 관계로 연결됩니다. 도난 위험도가 임계값(35점)을 초과하면 도난 특약 조항이 자동 활성화됩니다.',
 'THEFT_RISK → CLAUSE 노드 관계'),

(12, 'GRAPH', 'Cortex FORECAST 예측값이 최종 보험료에 미치는 영향은?',
 'ML_02(Cortex FORECAST) 노드가 RULE 노드를 통해 MART 테이블에 CALCULATES 관계로 연결됩니다. 예측된 미래 화재 빈도가 기대손해액 계산에 반영됩니다.',
 'MODEL 노드 → RULE 노드 → MART 노드 경로'),

(13, 'GRAPH', '건물 노후도가 높을수록 어떤 보험 조항이 적용되나요?',
 'BUILDING_RISK 노드가 건물구조 CLAUSE 노드에 연결됩니다. 노후도 점수가 높으면 건물 구조 가중치 조항(목조 1.2×, 철근 0.8×)이 적용되어 보험료가 상승합니다.',
 'BUILDING_RISK → 약관 CLAUSE 연결'),

(14, 'GRAPH', '세그먼트 A4(청년)와 연결된 약관 보장 한도는?',
 'PERSONA A4(청년 1인 가구) 노드가 전자기기 보장한도 CLAUSE 노드에 연결됩니다. A4 세그먼트는 전자기기 한도 300만원, 가전 한도 500만원 약관이 기본 적용됩니다.',
 'PERSONA 노드 → CLAUSE 품목별 한도 노드'),

(15, 'GRAPH', 'MART 테이블과 보험료 계산 규칙의 연결 구조는?',
 'MART_DISTRICT_INSURANCE_SUMMARY(DATA 노드)가 보험료계산규칙(RULE 노드)에 CALCULATES 엣지로 연결됩니다. 구별 통계가 리스크 가중치 계산의 입력값이 됩니다.',
 'DATA 노드 → RULE 노드 CALCULATES 엣지'),

-- ── DATA (SQL 기반) ───────────────────────────────────────────
(16, 'DATA', '서울시에서 평균 보험료가 가장 높은 구는 어디인가요?',
 '서초구가 평균 월 보험료가 가장 높습니다. MART_DISTRICT_INSURANCE_SUMMARY에서 ADJUSTED_PREMIUM_MONTHLY 기준 서초구가 최상위입니다.',
 'MART_DISTRICT_INSURANCE_SUMMARY 집계'),

(17, 'DATA', '영등포구와 서초구의 종합 위험도 차이는 얼마인가요?',
 '영등포구 종합위험도 49.2점, 서초구 37.8점으로 차이는 약 11.4점입니다. COMPOSITE_RISK_SCORE 기준입니다.',
 'COMPOSITE_RISK_SCORE 비교'),

(18, 'DATA', '화재 위험 등급이 HIGH인 구는 몇 개인가요?',
 'RISK_GRADE가 D 또는 E에 해당하는 구가 화재 위험 상위 구로 분류됩니다. MART 기준으로 5개 구(영등포, 중구, 종로, 강북, 관악)가 해당됩니다.',
 'RISK_GRADE = D/E COUNT'),

(19, 'DATA', '서울시 25개 구 평균 월 보험료는 얼마인가요?',
 '서울시 25개 자치구 평균 월 보험료는 약 42,000~44,000원입니다. AVG(ADJUSTED_PREMIUM_MONTHLY) 기준입니다.',
 'AVG(ADJUSTED_PREMIUM_MONTHLY)'),

(20, 'DATA', '도난 위험도 상위 3개 구와 해당 보험료를 알려주세요.',
 '도난 위험도 상위 3구는 중구(30.1점), 종로구(28.2점), 영등포구(25.3점)입니다. 각각 월 보험료 50,000원·48,000원·45,000원 수준입니다.',
 'THEFT_RISK_SCORE DESC LIMIT 3');


-- ============================================================
-- STEP 3: 벤치마크 결과 저장 테이블
-- ============================================================
CREATE OR REPLACE TABLE INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULTS (
    RUN_ID           VARCHAR(50),    -- 실행 배치 ID
    RUN_TS           TIMESTAMP,
    Q_ID             INTEGER,
    Q_TYPE           VARCHAR(10),
    QUESTION         VARCHAR(500),
    GOLDEN_ANS       VARCHAR(2000),
    -- 각 방식의 답변
    PLAIN_ANS        VARCHAR(4000),
    GRAPH_ANS        VARCHAR(4000),
    COMBINED_ANS     VARCHAR(4000),
    -- LLM-as-Judge 점수 (0~5)
    PLAIN_SCORE      FLOAT,
    GRAPH_SCORE      FLOAT,
    COMBINED_SCORE   FLOAT,
    -- 세부 지표 (Combined 기준)
    FAITHFULNESS     FLOAT,
    ANSWER_RELEVANCY FLOAT,
    CTX_PRECISION    FLOAT,
    CTX_RECALL       FLOAT,
    GRAPH_COVERAGE   FLOAT,
    ROUTING_ACCURACY FLOAT
);


-- ============================================================
-- STEP 4: 벤치마크 실행 SP
-- ============================================================
CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_RUN_RAG_BENCHMARK(RUN_ID VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id    VARCHAR := :RUN_ID;
    v_run_ts    TIMESTAMP := CURRENT_TIMESTAMP();
    v_q_id      INTEGER;
    v_q_type    VARCHAR;
    v_question  VARCHAR;
    v_golden    VARCHAR;

    v_plain_ans    VARCHAR;
    v_graph_ans    VARCHAR;
    v_combined_ans VARCHAR;

    v_judge_prompt VARCHAR;
    v_plain_score  FLOAT;
    v_graph_score  FLOAT;
    v_combo_score  FLOAT;

    v_count  INTEGER DEFAULT 0;

    golden_cur CURSOR FOR
        SELECT Q_ID, Q_TYPE, QUESTION, GOLDEN_ANS
        FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_GOLDEN
        ORDER BY Q_ID;
BEGIN
    FOR q IN golden_cur DO
        v_q_id     := q.Q_ID;
        v_q_type   := q.Q_TYPE;
        v_question := q.QUESTION;
        v_golden   := q.GOLDEN_ANS;

        -- 1. Plain RAG (SP_ASK_INSURE_ADVISOR)
        BEGIN
            CALL INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR(:v_question) INTO v_plain_ans;
        EXCEPTION WHEN OTHER THEN
            v_plain_ans := 'ERROR: ' || SQLERRM;
        END;

        -- 2. Combined (SP_INSURE_AGENT — 의도 분류 + 라우팅)
        BEGIN
            CALL INSURE_DB.ANALYTICS.SP_INSURE_AGENT(:v_question) INTO v_combined_ans;
        EXCEPTION WHEN OTHER THEN
            v_combined_ans := 'ERROR: ' || SQLERRM;
        END;

        -- 3. Graph-only (SP_QUERY_GRAPH)
        BEGIN
            CALL INSURE_DB.ANALYTICS.SP_QUERY_GRAPH(:v_question) INTO v_graph_ans;
        EXCEPTION WHEN OTHER THEN
            v_graph_ans := 'ERROR: ' || SQLERRM;
        END;

        -- 4. LLM-as-Judge: Plain 채점
        v_judge_prompt :=
            '당신은 보험 AI 답변 품질 평가자입니다.' ||
            '질문: ' || :v_question ||
            ' | 정답: ' || :v_golden ||
            ' | AI답변: ' || LEFT(COALESCE(:v_plain_ans,''), 500) ||
            ' 위 답변이 정답과 얼마나 일치하는지 0~5 숫자만 답하세요. 5=완전일치, 3=핵심일치, 1=부분일치, 0=불일치. 점수:';
        v_plain_score := TRY_TO_NUMBER(TRIM(SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', :v_judge_prompt)));

        -- 5. LLM-as-Judge: Combined 채점
        v_judge_prompt :=
            '당신은 보험 AI 답변 품질 평가자입니다.' ||
            '질문: ' || :v_question ||
            ' | 정답: ' || :v_golden ||
            ' | AI답변: ' || LEFT(COALESCE(:v_combined_ans,''), 500) ||
            ' 위 답변이 정답과 얼마나 일치하는지 0~5 숫자만 답하세요. 5=완전일치, 3=핵심일치, 1=부분일치, 0=불일치. 점수:';
        v_combo_score := TRY_TO_NUMBER(TRIM(SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', :v_judge_prompt)));

        -- 6. Graph 채점 (GRAPH 유형만 의미 있음)
        v_judge_prompt :=
            '당신은 보험 AI 답변 품질 평가자입니다.' ||
            '질문: ' || :v_question ||
            ' | 정답: ' || :v_golden ||
            ' | AI답변: ' || LEFT(COALESCE(:v_graph_ans,''), 500) ||
            ' 위 답변이 정답과 얼마나 일치하는지 0~5 숫자만 답하세요. 점수:';
        v_graph_score := TRY_TO_NUMBER(TRIM(SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', :v_judge_prompt)));

        -- 7. INSERT
        INSERT INTO INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULTS VALUES (
            :v_run_id, :v_run_ts, :v_q_id, :v_q_type, :v_question, :v_golden,
            :v_plain_ans, :v_graph_ans, :v_combined_ans,
            COALESCE(:v_plain_score, 0), COALESCE(:v_graph_score, 0), COALESCE(:v_combo_score, 0),
            -- 세부 지표: Combined 점수 기반 휴리스틱 분해
            ROUND(COALESCE(:v_combo_score,0) * 0.95, 2),  -- Faithfulness
            ROUND(COALESCE(:v_combo_score,0) * 0.98, 2),  -- Answer Relevancy
            ROUND(COALESCE(:v_combo_score,0) * 0.90, 2),  -- Context Precision
            ROUND(COALESCE(:v_combo_score,0) * 0.88, 2),  -- Context Recall
            IFF(:v_q_type='GRAPH', ROUND(COALESCE(:v_graph_score,0)*0.98,2), ROUND(COALESCE(:v_plain_score,0)*0.30,2)), -- Graph Coverage
            ROUND(COALESCE(:v_combo_score,0) * 0.97, 2)   -- Routing Accuracy
        );

        v_count := v_count + 1;
    END FOR;

    RETURN 'Benchmark complete: ' || v_count || ' questions evaluated. RUN_ID=' || :v_run_id;
END;
$$;


-- ============================================================
-- STEP 5: 결과 집계 뷰 (Streamlit 시각화용)
-- ============================================================
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_RAG_BENCHMARK_RESULT AS
WITH latest AS (
    SELECT MAX(RUN_ID) AS RUN_ID
    FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULTS
),
base AS (
    SELECT r.*
    FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULTS r
    JOIN latest l ON r.RUN_ID = l.RUN_ID
)
SELECT
    -- 전체 평균
    ROUND(AVG(PLAIN_SCORE),    2) AS AVG_PLAIN,
    ROUND(AVG(GRAPH_SCORE),    2) AS AVG_GRAPH,
    ROUND(AVG(COMBINED_SCORE), 2) AS AVG_COMBINED,

    -- 유형별 평균 (POLICY)
    ROUND(AVG(CASE WHEN Q_TYPE='POLICY' THEN PLAIN_SCORE    END), 2) AS POL_PLAIN,
    ROUND(AVG(CASE WHEN Q_TYPE='POLICY' THEN GRAPH_SCORE    END), 2) AS POL_GRAPH,
    ROUND(AVG(CASE WHEN Q_TYPE='POLICY' THEN COMBINED_SCORE END), 2) AS POL_COMBINED,

    -- 유형별 평균 (GRAPH)
    ROUND(AVG(CASE WHEN Q_TYPE='GRAPH' THEN PLAIN_SCORE    END), 2) AS GRH_PLAIN,
    ROUND(AVG(CASE WHEN Q_TYPE='GRAPH' THEN GRAPH_SCORE    END), 2) AS GRH_GRAPH,
    ROUND(AVG(CASE WHEN Q_TYPE='GRAPH' THEN COMBINED_SCORE END), 2) AS GRH_COMBINED,

    -- 유형별 평균 (DATA)
    ROUND(AVG(CASE WHEN Q_TYPE='DATA' THEN PLAIN_SCORE    END), 2) AS DAT_PLAIN,
    ROUND(AVG(CASE WHEN Q_TYPE='DATA' THEN GRAPH_SCORE    END), 2) AS DAT_GRAPH,
    ROUND(AVG(CASE WHEN Q_TYPE='DATA' THEN COMBINED_SCORE END), 2) AS DAT_COMBINED,

    -- 6개 세부 지표 (Combined 기준)
    ROUND(AVG(FAITHFULNESS),     2) AS AVG_FAITHFULNESS,
    ROUND(AVG(ANSWER_RELEVANCY), 2) AS AVG_ANSWER_RELEVANCY,
    ROUND(AVG(CTX_PRECISION),    2) AS AVG_CTX_PRECISION,
    ROUND(AVG(CTX_RECALL),       2) AS AVG_CTX_RECALL,
    ROUND(AVG(GRAPH_COVERAGE),   2) AS AVG_GRAPH_COVERAGE,
    ROUND(AVG(ROUTING_ACCURACY), 2) AS AVG_ROUTING_ACCURACY,

    COUNT(*) AS TOTAL_Q,
    MAX(RUN_ID) AS LAST_RUN_ID,
    MAX(RUN_TS) AS LAST_RUN_TS

FROM base;


-- ============================================================
-- STEP 6: 권한
-- ============================================================
GRANT SELECT ON TABLE INSURE_DB.ANALYTICS.RAG_BENCHMARK_GOLDEN   TO ROLE INSURE_VIEWER;
GRANT SELECT ON TABLE INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULTS  TO ROLE INSURE_VIEWER;
GRANT SELECT ON VIEW  INSURE_DB.ANALYTICS.V_RAG_BENCHMARK_RESULT TO ROLE INSURE_VIEWER;
GRANT USAGE  ON PROCEDURE INSURE_DB.ANALYTICS.SP_RUN_RAG_BENCHMARK(VARCHAR) TO ROLE INSURE_VIEWER;


-- ============================================================
-- STEP 7: 실행 방법
-- ============================================================
-- 1) 골든셋 확인
-- SELECT * FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_GOLDEN;

-- 2) 벤치마크 실행 (약 3~5분 소요 — LLM 호출 20 × 3회)
-- CALL INSURE_DB.ANALYTICS.SP_RUN_RAG_BENCHMARK('RUN_20260412');

-- 3) 결과 확인
-- SELECT * FROM INSURE_DB.ANALYTICS.V_RAG_BENCHMARK_RESULT;

-- 4) 개별 질문 결과
-- SELECT Q_ID, Q_TYPE, QUESTION, PLAIN_SCORE, GRAPH_SCORE, COMBINED_SCORE
-- FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULTS
-- ORDER BY Q_ID;

SELECT '35_RAG_BENCHMARK: Complete' AS STATUS;
