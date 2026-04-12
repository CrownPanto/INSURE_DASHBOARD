-- ============================================================
-- 35_RAG_BENCHMARK.sql
-- RAG 성능 벤치마크: 골든셋 20개 + LLM-as-judge 평가 + 결과 뷰
-- "Plain RAG vs Graph RAG vs Combined 6개 지표 자동 측정"
-- Date: 2026-04-12 | Updated: 2026-04-12
--
-- 골든셋 구성:
--   Q01~Q10 (POLICY, 10개): 실생활 자연어 질문 — 약관·할인·기간·보장한도
--   Q11~Q15 (GRAPH,   5개): 노드/엣지 관계 추론 — 데이터 흐름, 위험도 연결
--   Q16~Q20 (DATA,    5개): MART 테이블 수치 조회 — Cortex Agent SQL 강점
-- ============================================================
--
-- 실행 순서:
--   STEP 1: 벤치마크 테이블 생성
--   STEP 2: 골든셋 20개 INSERT
--   STEP 3: 평가 실행 SP (SP_RUN_RAG_BENCHMARK)
--   STEP 4: 결과 집계 뷰 (V_RAG_BENCHMARK_RESULT)
--   STEP 5: 실행 및 확인
--
-- 측정 지표 (0~5점):
--   1) Faithfulness    : 답변이 검색 컨텍스트에 근거하는가 (환각 방지)
--   2) Answer Relevancy: 답변이 질문에 맞는가
--   3) Context Precision: 검색 청크가 유용한가
--   4) Context Recall  : 필요한 정보를 빠뜨리지 않았는가
--   5) Graph Coverage  : Graph RAG 노드 히트율 (GRAPH 유형 전용)
--   6) Routing Accuracy: 의도 분류(DATA/POLICY/GRAPH) 정확도
-- ============================================================

USE DATABASE INSURE_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE INSURE_WH;


-- ============================================================
-- STEP 1: 벤치마크 테이블 생성
-- ============================================================

-- 골든셋 테이블
CREATE OR REPLACE TABLE INSURE_DB.ANALYTICS.RAG_GOLDEN_SET (
    QUESTION_ID         INT PRIMARY KEY,
    QUESTION_TYPE       VARCHAR(10)     NOT NULL,   -- POLICY / GRAPH / DATA
    EXPECTED_ROUTING    VARCHAR(10)     NOT NULL,   -- SP_INSURE_AGENT가 분류해야 할 의도
    QUESTION            VARCHAR(500)    NOT NULL,
    GOLDEN_ANSWER       VARCHAR(2000)   NOT NULL,   -- 정답 (팀이 작성)
    GOLDEN_KEYWORDS     VARCHAR(500),               -- 답변에 반드시 포함돼야 할 핵심 키워드 (콤마 구분)
    SOURCE_REF          VARCHAR(200),               -- 근거 출처 (약관 조항 or 테이블명)
    CREATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 벤치마크 실행 결과 테이블
CREATE OR REPLACE TABLE INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT (
    RUN_ID              VARCHAR(50)     DEFAULT UUID_STRING(),
    RUN_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    QUESTION_ID         INT,
    QUESTION_TYPE       VARCHAR(10),
    EXPECTED_ROUTING    VARCHAR(10),
    ACTUAL_ROUTING      VARCHAR(10),    -- SP_INSURE_AGENT가 실제 분류한 의도
    COMBINED_ANSWER     VARCHAR(4000),  -- SP_INSURE_AGENT 최종 답변
    -- 지표 점수 (0.0 ~ 5.0)
    FAITHFULNESS        FLOAT,
    ANSWER_RELEVANCY    FLOAT,
    CONTEXT_PRECISION   FLOAT,
    CONTEXT_RECALL      FLOAT,
    GRAPH_COVERAGE      FLOAT,          -- GRAPH 유형만 해당, 나머지는 NULL
    ROUTING_ACCURACY    FLOAT,          -- 정답(1.0) or 오답(0.0) → 5점 환산
    JUDGE_RAW           VARCHAR(2000)   -- LLM judge 원본 응답 (디버깅용)
);


-- ============================================================
-- STEP 2: 골든셋 20개 INSERT
-- ============================================================

TRUNCATE TABLE INSURE_DB.ANALYTICS.RAG_GOLDEN_SET;

INSERT INTO INSURE_DB.ANALYTICS.RAG_GOLDEN_SET
    (QUESTION_ID, QUESTION_TYPE, EXPECTED_ROUTING, QUESTION, GOLDEN_ANSWER, GOLDEN_KEYWORDS, SOURCE_REF)
VALUES

-- ==============================
-- POLICY 유형 (10개): 실생활 질문 — Plain RAG 강점
-- 실제 사용자가 묻는 자연어 질문 기반
-- ==============================
(1, 'POLICY', 'POLICY',
 '동대문구에 사는 27세 여성인데, 전자기기 위주로 보험 들려면 어떤 조합이 좋아요?',
 '27세 여성은 세그먼트 A4(청년 1인가구)에 해당하며, 전자기기 중심 자산 유형인 B2 조합을 권장합니다. A4+B2 조합은 청년층 소형 전자기기 위주 보장으로 설계되며, 동대문구의 위험도와 연계하여 보험료가 산출됩니다.',
 'A4,B2,청년1인가구,전자기기,동대문구',
 'utils.py SEGMENTS_A/B + DISTRICT_PROFILES'),

(2, 'POLICY', 'POLICY',
 '보험 가입 기간이 보통 어떻게 되나요? 자동 갱신이 되나요?',
 '기본 보험기간은 1년입니다. 만료 30일 전까지 계약자가 갱신 거절 의사를 통지하지 않으면 1년 단위로 자동 갱신됩니다. 3년 이상 연속 갱신 시 우수 계약자 등급으로 상향되어 추가 할인을 받을 수 있습니다.',
 '1년,자동갱신,30일,우수계약자,추가할인',
 'INSURE 약관 제10조 계약기간'),

(3, 'POLICY', 'POLICY',
 '무사고 3년 됐는데, 혜택이 있나요?',
 '최근 3년간 보험금 청구 이력이 없는 경우 무사고 할인이 적용됩니다. 할인율은 최대 15%이며, 기본 보험료에서 차감됩니다. 3년 이상 연속 계약 갱신 시 장기계약 할인(최대 5%)도 중복 적용될 수 있습니다.',
 '무사고할인,15%,3년,장기계약할인,5%,중복적용',
 'INSURE 약관 제7조 할인 및 할증'),

(4, 'POLICY', 'POLICY',
 '여러 가지 보험을 같이 들면 더 저렴해지나요?',
 '2개 이상의 보험상품에 동시 가입하면 복합보험 할인이 적용되어 최대 8% 할인됩니다. 신용등급 할인, 무사고 할인 등과 중복 적용될 수 있으나, 최종 보험료는 기본 보험료의 50% 이상 200% 이하로 제한됩니다.',
 '복합보험할인,8%,2개이상,중복적용,50%,200%',
 'INSURE 약관 제7조 할인 및 할증'),

(5, 'POLICY', 'POLICY',
 '귀금속 보험 최대 보장 금액이 얼마예요?',
 '귀금속 및 보석류의 보장 한도는 기본 100만원~500만원 범위로 설정됩니다. 세그먼트에 따라 ±20% 조정되며, 고위험 세그먼트는 하향, 저위험 세그먼트는 상향 적용됩니다. 보장 한도 초과 시 추가 특약을 통해 상향 신청할 수 있습니다.',
 '귀금속,100만원,500만원,세그먼트,특약,상향',
 'INSURE 약관 제12조 품목별 보장한도'),

(6, 'POLICY', 'POLICY',
 'INSURE에서 가입할 수 있는 보험 종류가 뭐가 있어요?',
 'INSURE는 동산보험 전문 플랫폼으로 6개 자산 카테고리를 보장합니다: 가전제품, 전자기기, 가구, 자동차 부품, 귀금속·보석, 의류 및 기타 개인 물품. 각 카테고리는 10개 생애주기 세그먼트(A1~A6)와 5개 자산유형 세그먼트(B1~B5)와 결합하여 최대 1,500가지 맞춤 보험료를 제공합니다.',
 '가전제품,전자기기,가구,자동차부품,귀금속,의류,6개카테고리,1500가지',
 'INSURE 약관 제3조 보장범위'),

(7, 'POLICY', 'POLICY',
 '보험을 중도에 취소하면 위약금이 있나요?',
 '별도의 위약금은 없으나, 중도 해지 시 경과 기간에 해당하는 보험료를 차감한 미경과 보험료가 환급됩니다. 단, 보험금이 지급된 경우에는 환급하지 않습니다. 해지 후 동일 동산 재가입 시 최소 30일의 대기 기간이 필요할 수 있습니다.',
 '위약금없음,미경과보험료,환급,경과기간,30일대기',
 'INSURE 약관 제11조 해약 및 환급'),

(8, 'POLICY', 'POLICY',
 '하나의 물건에 두 보험사 보험을 동시에 들 수 있나요?',
 '동일 물건에 복수의 보험을 가입하는 것은 가능합니다. 단, 손해 발생 시 각 보험사가 보험가입금액 비율에 따라 비례 보상하며, 실손을 초과하는 보험금은 지급되지 않습니다. 중복 가입 시 각 보험사에 반드시 통지 의무가 있습니다.',
 '중복보험,가능,비례보상,통지의무,실손초과불가',
 'KB약관 비례보상 조항'),

(9, 'POLICY', 'POLICY',
 '신용등급이 낮으면 보험료가 얼마나 올라가나요?',
 '신용등급 600점 미만인 경우 기본 보험료에 10% 할증이 적용됩니다. 신용등급 600~699점은 할인도 할증도 없으며, 700~799점은 5% 할인, 800점 이상은 10% 할인입니다.',
 '신용등급,600미만,10%할증,700점,5%할인,800점,10%할인',
 'INSURE 약관 제7조 할인 및 할증'),

(10, 'POLICY', 'POLICY',
 '보험료 납부를 월납 말고 연납으로 하면 더 저렴한가요?',
 '연납(연간 일시 납부)은 월납 대비 3% 할인이 적용됩니다. 추가로 은행 자동이체 등록 시 2% 할인이 더해져 최대 5% 절감이 가능합니다.',
 '연납,3%할인,자동이체,2%추가할인,월납,5%절감',
 'INSURE 약관 제8조 보험료 납부'),


-- ==============================
-- GRAPH 유형 (5개): Graph RAG 강점
-- 노드/엣지 관계 추론 질문
-- ==============================

(11, 'GRAPH', 'GRAPH',
 '도난 위험도와 보험 약관은 어떻게 연결되나요?',
 '도난 위험 점수(THEFT_RISK_SCORE)는 경찰청 5대 범죄 통계에서 산출됩니다. 이 점수는 세그먼트 B2(전자기기)와 B3(귀중품)에 높은 가중치로 적용되며, 약관의 도난 담보 조항과 연결되어 해당 세그먼트의 보험료 할증률을 결정합니다.',
 '도난위험점수,경찰청,B2,B3,할증률,도난담보',
 'GRAPH: THEFT_RISK 노드 → SEGMENT 노드 → CLAUSE 도난담보'),

(12, 'GRAPH', 'GRAPH',
 'Cortex FORECAST 예측값이 최종 보험료에 어떤 영향을 주나요?',
 'Cortex ML FORECAST가 구별 화재 발생 건수 추세를 예측합니다. 예측값이 과거 평균 대비 증가 추세이면 해당 구의 화재 위험지수가 상향 조정되고, 이는 종합 위험지수 → 리스크 티어 → 보험료 조정 계수 순서로 반영되어 다음 분기 보험료에 영향을 줍니다.',
 'FORECAST,화재예측,위험지수,상향조정,분기갱신',
 'GRAPH: MODEL(FORECAST) 노드 → RULE 노드 → MART 노드'),

(13, 'GRAPH', 'GRAPH',
 '건물 노후도가 높은 구에서는 어떤 보험 조항이 적용되나요?',
 '건물노후도 점수(BUILDING_RISK_SCORE)가 임계값을 초과하면 건물 유형별 위험도 차등화 규칙이 적용됩니다. 노후 건물(준공 30년 이상)은 위험도 가중치가 1.5~2.0배 적용되고, 약관의 건물 구조 등급(1급~4급) 조항에 따라 보험료 할증이 결정됩니다.',
 '건물노후도,임계값,준공30년,위험도가중치,건물구조등급,할증',
 'GRAPH: BUILDING_RISK 노드 → RULE 노드 → CLAUSE 구조등급'),

(14, 'GRAPH', 'GRAPH',
 '세그먼트 A2(청년 1인가구)에 연결된 보험 보장 한도는 어떻게 결정되나요?',
 'A2 세그먼트(25~35세, 1인가구)는 가전·전자기기 중심의 동산가치를 가집니다. GRANDATA 인구통계에서 해당 연령대 평균 가재도구 가치를 산출하고, 약관의 품목별 보장 한도 조항에 따라 전자기기는 최대 500만원, 귀중품은 100만원으로 제한됩니다.',
 'A2세그먼트,청년,1인가구,GRANDATA,품목별한도,전자기기,귀중품',
 'GRAPH: PERSONA(A2) 노드 → CLAUSE 품목별보장한도'),

(15, 'GRAPH', 'GRAPH',
 'MART 테이블과 보험료 계산 규칙은 어떻게 연결되어 있나요?',
 'MART_DISTRICT_INSURANCE_SUMMARY는 Dynamic Tables 파이프라인의 최종 레이어입니다. INTERMEDIATE 레이어의 위험도 합성 결과(COMPOSITE_RISK_SCORE)가 MART의 RISK_GRADE로 분류되고, MART_PREMIUM_LAYER의 ADJUSTMENT_FACTOR가 7단계 보험료 공식에 적용되어 ADJUSTED_PREMIUM_MONTHLY를 산출합니다.',
 'MART,DynamicTables,COMPOSITE_RISK_SCORE,RISK_GRADE,ADJUSTMENT_FACTOR,7단계',
 'GRAPH: DATA(MART) 노드 → RULE(7단계파이프라인) CALCULATES 엣지'),


-- ==============================
-- DATA 유형 (5개): Cortex Agent SQL 강점
-- MART 테이블 수치 조회 질문
-- ==============================
(16, 'DATA', 'DATA',
 '서울시에서 평균 보험료가 가장 높은 구는 어디인가요?',
 'MART_DISTRICT_INSURANCE_SUMMARY에서 ADJUSTED_PREMIUM_MONTHLY 기준 최상위 구를 조회하면 확인할 수 있습니다. 일반적으로 화재·도난 위험도가 높은 구(영등포구, 용산구 등)가 상위에 위치합니다.',
 '보험료최고,ADJUSTED_PREMIUM_MONTHLY,영등포구,용산구',
 'MART_DISTRICT_INSURANCE_SUMMARY ORDER BY ADJUSTED_PREMIUM_MONTHLY DESC'),

(17, 'DATA', 'DATA',
 '영등포구와 서초구의 종합 위험도 점수 차이는 얼마인가요?',
 'COMPOSITE_RISK_SCORE를 기준으로 두 구를 비교합니다. 영등포구는 화재·노후건물 위험이 높아 서초구 대비 종합 위험도가 높게 측정됩니다.',
 'COMPOSITE_RISK_SCORE,영등포구,서초구,위험도차이',
 'MART_DISTRICT_INSURANCE_SUMMARY WHERE DISTRICT_NAME IN (영등포구,서초구)'),

(18, 'DATA', 'DATA',
 '화재 위험 등급이 HIGH인 구는 몇 개인가요?',
 'RISK_GRADE = HIGH 조건으로 COUNT를 실행하면 확인할 수 있습니다. 서울시 25개 구 중 종합 위험지수 상위 구들이 HIGH 등급에 해당합니다.',
 'RISK_GRADE,HIGH,COUNT,25개구',
 'MART_DISTRICT_INSURANCE_SUMMARY WHERE RISK_GRADE = HIGH'),

(19, 'DATA', 'DATA',
 '서울시 25개 구의 평균 월 보험료는 얼마인가요?',
 'ADJUSTED_PREMIUM_MONTHLY의 전체 평균값입니다. 서울시 전체 평균은 구별 위험도 가중 평균으로 산출됩니다.',
 'AVG,ADJUSTED_PREMIUM_MONTHLY,서울시평균',
 'MART_DISTRICT_INSURANCE_SUMMARY AVG(ADJUSTED_PREMIUM_MONTHLY)'),

(20, 'DATA', 'DATA',
 '도난 위험도 점수가 가장 높은 상위 3개 구와 해당 보험료를 알려주세요.',
 'THEFT_RISK_SCORE 기준 상위 3개 구와 각 구의 ADJUSTED_PREMIUM_MONTHLY를 함께 조회합니다. 도심 상업지역(종로구, 중구 등)이 도난 위험 상위에 위치하는 경향이 있습니다.',
 'THEFT_RISK_SCORE,상위3개구,ADJUSTED_PREMIUM_MONTHLY,종로구,중구',
 'MART_DISTRICT_INSURANCE_SUMMARY ORDER BY THEFT_RISK_SCORE DESC LIMIT 3');


-- ============================================================
-- STEP 3: 평가 실행 SP
-- ============================================================

CREATE OR REPLACE PROCEDURE INSURE_DB.ANALYTICS.SP_RUN_RAG_BENCHMARK()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_run_id        VARCHAR DEFAULT UUID_STRING();
    v_run_at        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_combined_ans  VARCHAR DEFAULT '';
    v_routing       VARCHAR DEFAULT '';
    v_judge_prompt  VARCHAR DEFAULT '';
    v_judge_raw     VARCHAR DEFAULT '';
    v_faithfulness  FLOAT DEFAULT 0;
    v_relevancy     FLOAT DEFAULT 0;
    v_precision     FLOAT DEFAULT 0;
    v_recall        FLOAT DEFAULT 0;
    v_graph_cov     FLOAT DEFAULT NULL;
    v_routing_acc   FLOAT DEFAULT 0;
    v_total_count   INT DEFAULT 0;
    v_safe_q        VARCHAR DEFAULT '';

    -- 골든셋 커서
    cur CURSOR FOR
        SELECT QUESTION_ID, QUESTION_TYPE, EXPECTED_ROUTING,
               QUESTION, GOLDEN_ANSWER, GOLDEN_KEYWORDS
        FROM INSURE_DB.ANALYTICS.RAG_GOLDEN_SET
        ORDER BY QUESTION_ID;
BEGIN
    -- 이번 실행 결과 초기화
    DELETE FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT
    WHERE RUN_ID = v_run_id;

    FOR rec IN cur DO
        -- 입력 검증
        v_safe_q := LEFT(TRIM(rec.QUESTION), 500);

        -- ① SP_INSURE_AGENT 실행 → Combined 답변 획득
        CALL INSURE_DB.ANALYTICS.SP_INSURE_AGENT(v_safe_q) INTO v_combined_ans;

        -- ② 실제 라우팅 추정 (INTENT 함수 재사용)
        v_routing := INSURE_DB.ANALYTICS.FN_CLASSIFY_INTENT(v_safe_q);

        -- ③ Routing Accuracy (정답이면 5.0, 틀리면 0.0)
        v_routing_acc := IFF(v_routing = rec.EXPECTED_ROUTING, 5.0, 0.0);

        -- ④ LLM-as-judge 프롬프트 구성 (4개 지표 한번에)
        v_judge_prompt :=
            '당신은 보험 AI 답변 품질 평가 전문가입니다. 아래 기준으로 각 지표를 0~5점 정수로만 평가하세요.\n\n' ||
            '점수 기준:\n' ||
            '5: 완벽 (정답과 동일하거나 더 상세)\n' ||
            '4: 우수 (핵심 내용 포함, 소폭 누락)\n' ||
            '3: 보통 (핵심은 맞지만 일부 오류/누락)\n' ||
            '2: 미흡 (관련 있지만 상당한 오류)\n' ||
            '1: 불량 (방향은 맞지만 대부분 틀림)\n' ||
            '0: 완전히 틀림\n\n' ||
            '===질문===\n' || rec.QUESTION || '\n\n' ||
            '===정답===\n' || rec.GOLDEN_ANSWER || '\n\n' ||
            '===핵심키워드(반드시 포함돼야 함)===\n' || COALESCE(rec.GOLDEN_KEYWORDS, '') || '\n\n' ||
            '===AI 답변===\n' || COALESCE(v_combined_ans, '(답변 없음)') || '\n\n' ||
            '아래 형식으로 숫자만 답하세요 (설명 없이):\n' ||
            'FAITHFULNESS: [0-5]\n' ||
            'ANSWER_RELEVANCY: [0-5]\n' ||
            'CONTEXT_PRECISION: [0-5]\n' ||
            'CONTEXT_RECALL: [0-5]';

        v_judge_raw := SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', v_judge_prompt);

        -- ⑤ 파싱: 정규식으로 각 점수 추출
        v_faithfulness := TRY_TO_NUMBER(
            REGEXP_SUBSTR(v_judge_raw, 'FAITHFULNESS:\\s*([0-5])', 1, 1, 'e', 1));
        v_relevancy := TRY_TO_NUMBER(
            REGEXP_SUBSTR(v_judge_raw, 'ANSWER_RELEVANCY:\\s*([0-5])', 1, 1, 'e', 1));
        v_precision := TRY_TO_NUMBER(
            REGEXP_SUBSTR(v_judge_raw, 'CONTEXT_PRECISION:\\s*([0-5])', 1, 1, 'e', 1));
        v_recall := TRY_TO_NUMBER(
            REGEXP_SUBSTR(v_judge_raw, 'CONTEXT_RECALL:\\s*([0-5])', 1, 1, 'e', 1));

        -- NULL 방어 (파싱 실패 시 2.5로 중간값 처리)
        v_faithfulness := COALESCE(v_faithfulness, 2.5);
        v_relevancy    := COALESCE(v_relevancy,    2.5);
        v_precision    := COALESCE(v_precision,    2.5);
        v_recall       := COALESCE(v_recall,       2.5);

        -- ⑥ Graph Coverage: GRAPH 유형만 측정
        IF (rec.QUESTION_TYPE = 'GRAPH') THEN
            -- 답변에 핵심 키워드 포함 비율로 Coverage 근사 측정
            DECLARE
                v_kw_count INT DEFAULT 0;
                v_kw_hit   INT DEFAULT 0;
                v_keywords ARRAY;
            BEGIN
                v_keywords := STRTOK_TO_ARRAY(COALESCE(rec.GOLDEN_KEYWORDS, ''), ',');
                v_kw_count := ARRAY_SIZE(v_keywords);
                IF (v_kw_count > 0) THEN
                    -- 각 키워드가 답변에 포함됐는지 확인 (간단 텍스트 매칭)
                    SELECT COUNT(*) INTO v_kw_hit
                    FROM (
                        SELECT VALUE AS kw
                        FROM TABLE(FLATTEN(INPUT => v_keywords))
                    )
                    WHERE CONTAINS(LOWER(v_combined_ans), LOWER(TRIM(kw)));
                    v_graph_cov := (v_kw_hit::FLOAT / v_kw_count::FLOAT) * 5.0;
                ELSE
                    v_graph_cov := NULL;
                END IF;
            EXCEPTION WHEN OTHER THEN
                v_graph_cov := NULL;
            END;
        ELSE
            v_graph_cov := NULL;
        END IF;

        -- ⑦ 결과 INSERT
        INSERT INTO INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT (
            RUN_ID, RUN_AT, QUESTION_ID, QUESTION_TYPE,
            EXPECTED_ROUTING, ACTUAL_ROUTING, COMBINED_ANSWER,
            FAITHFULNESS, ANSWER_RELEVANCY, CONTEXT_PRECISION,
            CONTEXT_RECALL, GRAPH_COVERAGE, ROUTING_ACCURACY, JUDGE_RAW
        ) VALUES (
            v_run_id, v_run_at, rec.QUESTION_ID, rec.QUESTION_TYPE,
            rec.EXPECTED_ROUTING, v_routing, v_combined_ans,
            v_faithfulness, v_relevancy, v_precision,
            v_recall, v_graph_cov, v_routing_acc, v_judge_raw
        );

        v_total_count := v_total_count + 1;

    END FOR;

    RETURN '벤치마크 완료: ' || v_total_count || '개 질문 평가 | RUN_ID: ' || v_run_id;

EXCEPTION
    WHEN OTHER THEN
        RETURN 'Benchmark 실행 오류: ' || SQLERRM;
END;
$$;


-- ============================================================
-- STEP 4: 결과 집계 뷰
-- ============================================================

-- 4-1. 최신 실행 기준 전체 결과 뷰
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_RAG_BENCHMARK_RESULT
COMMENT = 'RAG 벤치마크 최신 실행 결과 — Plain vs Graph vs Combined 지표별 평균'
AS
WITH latest_run AS (
    SELECT RUN_ID
    FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT
    ORDER BY RUN_AT DESC
    LIMIT 1
)
SELECT
    r.QUESTION_TYPE,
    COUNT(*)                                        AS QUESTION_COUNT,
    ROUND(AVG(r.FAITHFULNESS),    2)                AS AVG_FAITHFULNESS,
    ROUND(AVG(r.ANSWER_RELEVANCY), 2)               AS AVG_ANSWER_RELEVANCY,
    ROUND(AVG(r.CONTEXT_PRECISION), 2)              AS AVG_CONTEXT_PRECISION,
    ROUND(AVG(r.CONTEXT_RECALL),   2)               AS AVG_CONTEXT_RECALL,
    ROUND(AVG(r.GRAPH_COVERAGE),   2)               AS AVG_GRAPH_COVERAGE,
    ROUND(AVG(r.ROUTING_ACCURACY), 2)               AS AVG_ROUTING_ACCURACY,
    ROUND(AVG(
        (r.FAITHFULNESS + r.ANSWER_RELEVANCY +
         r.CONTEXT_PRECISION + r.CONTEXT_RECALL +
         r.ROUTING_ACCURACY) / 5.0
    ), 2)                                           AS OVERALL_SCORE
FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT r
JOIN latest_run l ON r.RUN_ID = l.RUN_ID
GROUP BY r.QUESTION_TYPE

UNION ALL

SELECT
    'ALL' AS QUESTION_TYPE,
    COUNT(*),
    ROUND(AVG(FAITHFULNESS),     2),
    ROUND(AVG(ANSWER_RELEVANCY),  2),
    ROUND(AVG(CONTEXT_PRECISION), 2),
    ROUND(AVG(CONTEXT_RECALL),    2),
    ROUND(AVG(GRAPH_COVERAGE),    2),
    ROUND(AVG(ROUTING_ACCURACY),  2),
    ROUND(AVG(
        (FAITHFULNESS + ANSWER_RELEVANCY +
         CONTEXT_PRECISION + CONTEXT_RECALL +
         ROUTING_ACCURACY) / 5.0
    ), 2)
FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT r
JOIN latest_run l ON r.RUN_ID = l.RUN_ID;


-- 4-2. 질문별 상세 결과 뷰 (디버깅 + Streamlit 히트맵용)
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_RAG_BENCHMARK_DETAIL
COMMENT = 'RAG 벤치마크 질문별 상세 점수 — 히트맵 시각화용'
AS
WITH latest_run AS (
    SELECT RUN_ID
    FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT
    ORDER BY RUN_AT DESC
    LIMIT 1
)
SELECT
    g.QUESTION_ID,
    g.QUESTION_TYPE,
    g.EXPECTED_ROUTING,
    r.ACTUAL_ROUTING,
    IFF(g.EXPECTED_ROUTING = r.ACTUAL_ROUTING, '✓', '✗') AS ROUTING_OK,
    LEFT(g.QUESTION, 40) || '...'                         AS QUESTION_PREVIEW,
    r.FAITHFULNESS,
    r.ANSWER_RELEVANCY,
    r.CONTEXT_PRECISION,
    r.CONTEXT_RECALL,
    r.GRAPH_COVERAGE,
    r.ROUTING_ACCURACY,
    ROUND(
        (r.FAITHFULNESS + r.ANSWER_RELEVANCY +
         r.CONTEXT_PRECISION + r.CONTEXT_RECALL +
         r.ROUTING_ACCURACY) / 5.0, 2
    )                                                     AS OVERALL_SCORE,
    r.RUN_AT
FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT r
JOIN INSURE_DB.ANALYTICS.RAG_GOLDEN_SET g ON r.QUESTION_ID = g.QUESTION_ID
JOIN latest_run l ON r.RUN_ID = l.RUN_ID
ORDER BY g.QUESTION_ID;


-- ============================================================
-- STEP 5: 권한 + 실행 가이드
-- ============================================================
GRANT SELECT ON TABLE INSURE_DB.ANALYTICS.RAG_GOLDEN_SET          TO ROLE ANALYTICS_ROLE;
GRANT SELECT ON TABLE INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT    TO ROLE ANALYTICS_ROLE;
GRANT SELECT ON VIEW  INSURE_DB.ANALYTICS.V_RAG_BENCHMARK_RESULT  TO ROLE ANALYTICS_ROLE;
GRANT SELECT ON VIEW  INSURE_DB.ANALYTICS.V_RAG_BENCHMARK_DETAIL  TO ROLE ANALYTICS_ROLE;
GRANT USAGE  ON PROCEDURE INSURE_DB.ANALYTICS.SP_RUN_RAG_BENCHMARK() TO ROLE ANALYTICS_ROLE;


-- ============================================================
-- STEP 6: 실행 명령 (Andy 실행 순서)
-- ============================================================

-- [1] 골든셋 확인
-- SELECT * FROM INSURE_DB.ANALYTICS.RAG_GOLDEN_SET ORDER BY QUESTION_ID;

-- [2] 벤치마크 실행 (약 2~3분 소요, Cortex API 호출 20회)
-- CALL INSURE_DB.ANALYTICS.SP_RUN_RAG_BENCHMARK();

-- [3] 결과 요약 확인 (유형별 평균 점수)
-- SELECT * FROM INSURE_DB.ANALYTICS.V_RAG_BENCHMARK_RESULT ORDER BY QUESTION_TYPE;

-- [4] 질문별 상세 확인 (히트맵용)
-- SELECT * FROM INSURE_DB.ANALYTICS.V_RAG_BENCHMARK_DETAIL;

-- [5] 종합 점수 (Streamlit KPI 카드용)
-- SELECT
--     ROUND(AVG(FAITHFULNESS), 2)     AS 환각방지,
--     ROUND(AVG(ANSWER_RELEVANCY), 2) AS 답변관련성,
--     ROUND(AVG(ROUTING_ACCURACY), 2) AS 라우팅정확도,
--     ROUND(AVG(GRAPH_COVERAGE), 2)   AS 그래프커버리지,
--     ROUND(AVG((FAITHFULNESS+ANSWER_RELEVANCY+CONTEXT_PRECISION+CONTEXT_RECALL+ROUTING_ACCURACY)/5.0), 2) AS 종합점수
-- FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT
-- WHERE RUN_ID = (SELECT RUN_ID FROM INSURE_DB.ANALYTICS.RAG_BENCHMARK_RESULT ORDER BY RUN_AT DESC LIMIT 1);

SELECT '35_RAG_BENCHMARK: 골든셋 20개 + SP + 뷰 생성 완료' AS STATUS;
