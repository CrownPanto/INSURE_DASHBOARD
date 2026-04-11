# Snowflake Hackathon 2026 - PPTX 슬라이드별 입력 내용

> 이 문서를 보고 템플릿 PPTX에 직접 붙여넣기하세요.

---

## Slide 1: Cover

| 필드 | 입력값 |
|------|--------|
| Name of Individual | Team INSURE (김기준, 앤디, 현지) |
| Organization Name | [소속 조직명] |
| Date | Apr 2026 |

---

## Slide 2-3: Instructions / Requirements

> 삭제하거나 그대로 두세요. 제출 안내용 슬라이드입니다.

---

## Slide 4: Problem + Architecture

### Problem Statement (왼쪽)

```
서울시 동산보험의 4가지 구조적 한계:

1. 획일적 보험료 산정
   - 자치구별 화재율 최대 3.2배, 범죄율 2.8배 차이
   - 동일 보험료 적용으로 저위험 고객 이탈 + 고위험 지역 손실률 악화

2. 고객 세분화 부재
   - 1인가구 청년 ↔ 4인가구 자영업자에게 같은 상품 제안
   - 라이프사이클/자산규모/소득 미반영, 전환율 저조

3. 약관 해석 불투명성
   - 14개 조항 × 4개 규칙의 복잡한 상호참조
   - 상담사 즉답 어려움 → 고객 이탈 + 컴플라이언스 리스크

4. 시장 기회 포착 불가
   - 이사 시즌(3-4월, 9-10월) 수요 급증 실시간 감지 못함
```

### Theme

```
공공데이터 + Snowflake ML/LLM 기반 동산보험 분석 및 AI 상담 플랫폼
```

### Architecture Diagram (오른쪽)

```
[6-Layer Snowflake Pipeline]

RAW (9 tables)        → 화재/범죄/기상/건물/부동산/소비자사고
STAGING (13 views)    → dbt 패턴 비정규화 + 타입 정리
INTERMEDIATE          → Risk Score (4요소 통합) + Segment + Anomaly
MART                  → District Summary + Premium Layer + Correlation
RAG / GRAPH           → 367 chunks (e5-base-v2) + 31 nodes + 34 edges
ML / LLM              → FORECAST + ANOMALY + Mistral-Large2 + SENTIMENT
```

### 사용 기술 (로고/태그)

```
Snowflake, Cortex ML, Cortex LLM, Cortex Analyst, 
Streamlit in Snowflake, Snowpipe, Graph RAG, e5-base-v2, Mistral-Large2
```

---

## Slide 5: Insight #1 - 7단계 보험료 산출 엔진

### 핵심 분석 인사이트 (최대 3개 bullet)

```
• 서울 25개 자치구 화재율/범죄율/기상위험/건물노후도 분석 결과, 
  지역별 위험도 편차가 최대 3.2배 → 균일 보험료는 구조적 미스프라이싱

• 5구간 비선형 리스크 커브 적용 시, 
  저위험 지역 보험료 15-20% 인하 + 고위험 지역 적정 보험료 확보 가능

• 신뢰도 보정(Z계수) + 부담능력 상한(월소득 0.5%)으로 
  통계적 안정성과 금융소비자 보호 동시 충족
```

### 적용 기술 (상세)

```
7-Stage Premium Pipeline:
  순보험료 → 경험보험료 → 위험분류(5구간 커브) → 부가보험료 
  → 신뢰도보정(Z=min(n/1082,1.0)) → 세그먼트조정(10 persona) → 최종승인
```

### 기대 효과

```
• 공정한 지역별 보험료 → 저위험 고객 유지율 향상
• 7단계 투명 공개 → 금융소비자 보호법 준수
• 시뮬레이터 → 고객이 직접 보험료 산출 과정 확인 가능
```

---

## Slide 6: Insight #2 - Graph RAG 약관 추론

### 핵심 분석 인사이트 (최대 3개 bullet)

```
• 동산보험 약관 14개 조항이 11개 데이터, 4개 규칙, 2개 ML 모델과 
  34개 관계로 연결 → 단순 키워드 검색으로는 조항 간 관계 파악 불가

• Graph RAG 3-hop 탐색으로 "보험료산정(CL06) → 리스크커브(RL01) → 
  위험점수(DT02)" 같은 연결 경로 자동 추출

• Vector RAG(367 chunks) + Graph RAG(31 nodes) 이중 구조로 
  정확도와 맥락 이해도 동시 향상
```

### 적용 기술 (상세)

```
• Vector RAG: e5-base-v2 임베딩, cosine similarity TOP-5 검색
• Graph RAG: 31 노드(CLAUSE/DATA/RULE/MODEL) + 34 엣지(6 관계 타입)
• LLM: Mistral-Large2, 약관 원문 강제 참조로 hallucination 방지
• SP_ASK_INSURE_ADVISOR: Snowflake Stored Procedure로 배포
```

### 기대 효과

```
• "보험료가 왜 이 금액인가요?" → 조항+데이터+규칙 연결 근거 자동 제시
• 상담사 업무 부담 경감 (약관 검색 시간 90% 단축 예상)
• Hallucination 방지 → 컴플라이언스 리스크 제거
```

---

## Slide 7: Insight #3 - 페르소나 세분화 + 시장 인텔리전스

### 핵심 분석 인사이트 (최대 3개 bullet)

```
• 5차원(라이프사이클/자산소비/주거/직업/위험성향) 교차 분석으로 
  10개 대표 페르소나 도출 → 맞춤 보장한도/리스크팩터(1.0~1.8) 자동 적용

• 부동산 거래량 Z-Score 이상치 탐지로 이사 시즌 
  2-3주 전 사전 포착 → 교차판매 골든타임 확보

• Cortex ML FORECAST 기반 화재 발생률 예측(95% CI)으로 
  선제적 위험 관리 및 포트폴리오 최적화
```

### 적용 기술 (상세)

```
• Cortex FORECAST: 화재 발생률 시계열 예측
• ANOMALY_DETECTION: 부동산 거래량 급등 자동 감지
• SENTIMENT: 소비자 사고 심각도 자동 분류
• Cortex Analyst: 자연어 쿼리 인터페이스 ("강남구 평균 동산 가치는?")
• REGR_SLOPE: 추세 기울기 분석
```

### 기대 효과

```
• 사회초년생 → 소액 필수보장, 자영업자 → 고가품 확장보장 자동 추천
• 이사 시즌 사전 감지 → 교차판매 전환율 향상
• 자치구별 시장 규모(ESTIMATED_ANNUAL_MARKET_KRW) 자동 산출
```

---

## Slide 8: Thank You

```
THANK YOU

Team INSURE | Snowflake Hackathon 2026

25 Districts | 7 Premium Stages | 10 Personas
367 RAG Chunks | 31 Graph Nodes | 6 Data Layers
```
