# INSURE 프로젝트 — Claude Code 지식 문서

> Team CrownPanto | Snowflake Hackathon 2026
> "INSURE, For Sure." — 동산보험 AI 설계 플랫폼

---

## 1. 프로젝트 개요

INSURE는 서울시 25개 구의 공공 안전 데이터 + GRANDATA 인구통계를 결합하여, 10개 고객 세그먼트 × 6개 자산 카테고리별 맞춤 동산보험료를 산출하는 AI 플랫폼이다. Snowflake 단일 플랫폼(데이터 수집 → 분석 → AI → 서빙)으로 End-to-End 구현.

### 비즈니스 모델
- B2B2C: 고객(무료) → 플랫폼(수수료) → 보험사(라이선스 + 손해율 개선)
- "최저가가 아닌 최적가" — 역선택 방지
- 로드맵: Phase 1(서울) → Phase 2(마이데이터) → Phase 3(보험 확장)

---

## 2. 심사위원 평가 기준 (6개 항목, 100점 만점)

### 2.1 Innovation & Creativity (배점 높음)
- 10개 페르소나 × 25개 구 × 6개 자산카테고리의 다차원 보험 설계
- Graph RAG (31노드/34엣지) + Plain RAG (367청크) 이중 검색 아키텍처
- 프리셋 4개 모두 활성화로 시연 범위 확대
- **핵심 어필**: "기존 '가재일체' 단일 요율 대비 6개 자산 카테고리 분리"

### 2.2 Snowflake Feature Utilization (배점 높음)
- 현재 활용 12개 기능: Streamlit in Snowflake, Dynamic Tables, Cortex Analyst, Cortex Search, Cortex LLM (COMPLETE/SUMMARIZE), Marketplace (GRANDATA+아정당), Graph RAG, RAG 벡터 검색, ML FORECAST, Streams+Tasks, Alerts, RLS/Masking
- **Must-Use 6개**: Dynamic Tables, Cortex Analyst, Streamlit, Marketplace, ML Forecasting, ML Classification
- **Should-Use 8개**: Cortex Agents, Cortex Search, Anomaly Detection, Top Insights, Alerts, Git Integration, RBAC+Row Access Policies, Dynamic Data Masking
- **핵심 어필**: "데이터 수집부터 서빙까지 Snowflake 밖으로 나가지 않는다"

### 2.3 Technical Depth & Quality (배점 높음)
- dbt 4-layer 메달리온 패턴: RAW → STG → INT → MART
- 7단계 보험료 엔진: Pure → Experience → Risk → Loading → Credibility → Segment → Cap
- 리스크 가중치 합계 1.0 정규화, MIN-MAX 정규화, 건물 유형별 위험도 차등화
- SQL 33개 파일 체계 (01~33번)
- **핵심 어필**: "블랙박스가 아닌 투명한 보험료 산출 — 워터폴 차트로 7단계 분해"

### 2.4 Business Viability (배점 보통)
- B2B2C 수익 모델 명확
- 6개 자산 카테고리 분리가 기존 대비 차별화 설명력
- Phase 1→2→3 로드맵 구체적
- **핵심 어필**: "같은 앱, 같은 보장, 다른 보험료" 비교 시연

### 2.5 Dashboard & UX (배점 보통)
- Streamlit 5페이지 (Andy V1.0 현황 — 2026-04-12 기준):
  - P1 ✅: 서울시 보험료 지도 — KPI 3개 + Top3/Bottom3 + 버블차트(위험도 vs 보험료) + "같은 보험 다른 가격" 영등포 vs 서초 비교 + 25구 테이블. **GeoJSON 코로플레스 없음, 버블차트로 대체**
  - P2 ✅: 맞춤 보험 시뮬레이터 (482줄) — 7단계 워터폴 차트, 4개 프리셋, 세그먼트 선택. 핵심 데모 페이지
  - P3 ✅: AI 보험 상담 — `SP_ASK_INSURE_ADVISOR` SP 호출, 채팅 히스토리, 데모 폴백
  - P4 ⚠️ **Andy 작업 중** (23줄): 레이더 탭만 구현, 보험료 산출 탭·미래 예측 탭은 플레이스홀더
  - P5 ⚠️ **미완성** (12줄): 정적 테이블만 있음, V_SYSTEM_HEALTH 등 DB 쿼리 없음
- 다크 사이드바 (#111827) + Plotly 인터랙션

### 2.6 Completeness & Security (배점 보통)
- 5페이지 라우팅 동작 (P4/P5는 내용 미완성)
- 비밀번호 st.secrets 전환 완료
- SQL 인젝션 파라미터화 처리 완료
- **해소됨**: calc_premium() DRY — utils.py:110에 단일 정의, P2에서 import 사용
- **남은 이슈**: P4 보험료 산출/미래예측 탭, P5 헬스체크 DB 연동

---

## 3. 현재 점수: B+ (79/100) — v1 대비 +21점

| 항목 | v1 점수 | v2 점수 | 변화 |
|---|---|---|---|
| Innovation & Creativity | 78 | 82 | +4 |
| Snowflake Feature Utilization | 52 | 75 | +23 |
| Technical Depth & Quality | 62 | 80 | +18 |
| Business Viability | 75 | 82 | +7 |
| Dashboard & UX | 65 | 78 | +13 |
| Completeness & Security | 35 | 65 | +30 |
| **총점** | **58 (C)** | **79 (B+)** | **+21** |

---

## 4. 수상 가능성을 높이는 추가 액션 (우선순위순)

> Andy 고유 영역(P4/P5 Streamlit, Snowflake 직접 배포)은 Claude가 직접 수정하지 않음.
> Streamlit/Snowflake 코드 변경은 반드시 `feature_kijun` 브랜치 push → Andy 배포 경로로만.

1. **Graph RAG → Streamlit 연동 완료** — Innovation +3~5점. P3 또는 P4에 Graph RAG 경로 시각화 UI 추가. Andy와 협의 필요.
2. **P4 미래 예측 탭 Forecast 연결** — Feature +3~5점. `V_FIRE_FORECAST_V13` 쿼리 → Plotly 시계열. Andy 작업 중인 P4에 포함 예정.
3. **Cortex Agent 통합 확인** — SQL 33번 완료. SP_ASK_INSURE_ADVISOR가 Cortex Agent 기반인지 확인 후 P3 설명 보완.
4. ~~**calc_premium() DRY 위반 해소**~~ — **해소 완료** (utils.py:110 단일 정의)
5. **시연 영상 30초 녹화** — 라이브 데모 실패 시 백업. "같은 보장, 다른 보험료" 비교 장면 핵심.

---

## 5. 심사 대응 Q&A

| 예상 질문 | 방어 논리 |
|---|---|
| "보험료 산출 근거가 뭔가요?" | P4 엔진 상세 탭 7단계 워터폴 차트. "블랙박스가 아닌 투명한 산출" |
| "실제 보험사에서 쓸 수 있나요?" | B2B2C 모델. "최저가가 아닌 최적가"로 역선택 방지. Phase 2 마이데이터 연동 시 실서비스 |
| "Snowflake를 왜 써야 하나요?" | "수집→분석→AI→서빙 전부 Snowflake 안에서. 밖으로 나가지 않는다" |
| "3개 구만 실측이고 나머진 추정?" | "맞다. 중요한 건 구조 — 실측 데이터 추가 시 같은 파이프라인에 투입 가능" |
| "AI 상담이 하드코딩 아닌가요?" | P3에서 라이브로 새 질문 입력. RAG 367청크 벡터 검색 → SP → Cortex LLM 흐름을 P5에서 확인 |
| "Graph RAG vs Plain RAG 차이?" | "Plain은 유사 문서 검색. Graph는 문서 간 관계 추론 — 약관+리스크+세그먼트+규정 연결" |

---

## 6. 주요 버그 수정 이력 (v1→v2, 10건)

| ID | 수정 내용 | 점수 영향 |
|---|---|---|
| C-1 | BUILDING×100 제거 → 0~1 정규화 | Technical +3 |
| C-4 | Task LIMIT 0 제거 (파이프라인 실행 정상화) | Feature +2 |
| C-5 | YAML 컬럼명 6건 수정 (Cortex Analyst 정상화) | Feature +3 |
| C-7 | 동산가치 MIN-MAX 정규화 | Technical +2 |
| C-8 | 건물 유형별 위험도 차등화 | Business +2 |
| M-1 | 세그먼트 연령 기준 재정의 | Business +1 |
| M-2 | 저위험 임계값 30→25 | Technical +1 |
| M-3 | 신용등급 6→5단계 표준화 (한국 실무 기준) | Business +1 |
| M-5 | 리스크 가중치 합계 1.0 정규화 | Technical +3 |
| M-6 | ROBBERY 최소값 5점 보장 (영점 보호) | Technical +1 |

---

## 7. SQL 파일 구조 (33개, feature_kijun 브랜치 기준)

```
sql/
├── 00_EXECUTION_GUIDE.md        # 실행 가이드
├── 01_INSURE_DB_SETUP.sql       # DB/스키마/웨어하우스 초기 설정
├── 02_PUBLIC_DATA_DDL.sql       # 공공데이터 테이블 DDL
├── 03_SEED_DATA.sql             # 시드 데이터 삽입
├── 04_DBT_STAGING.sql           # Staging 레이어 (Dynamic Tables)
├── 05_DBT_INTERMEDIATE.sql      # Intermediate 레이어
├── 06_DBT_MART.sql              # Mart 레이어
├── 07_CORTEX_ANALYST.yaml       # Cortex Analyst 시맨틱 모델
├── 07_MART_GENDER_AGE_CORRELATION.sql  # 성별/연령 상관분석 마트
├── 08_CORTEX_ML_LLM.sql         # Cortex ML/LLM 함수 (Forecast, Anomaly, Classification, Top Insights)
├── 09_EXTERNAL_STAGE_SNOWPIPE.sql # 외부 스테이지 + Snowpipe
├── 10_GRANTS.sql                # RBAC 권한 설정
├── 11_V1.3_ENHANCEMENTS.sql     # v1.3 개선사항
├── 12_V1.4_ENHANCEMENTS.sql     # v1.4 개선사항 (통합)
├── 13_V1.4_STREAMLIT_DEPLOY.sql # v1.4 Streamlit 배포
├── 14_V1.5_PERSONA_SEGMENT.sql  # 10개 페르소나 세그먼트
├── 15_V1.5_ADVANCED_FEATURES.sql # v1.5 고급 기능 (RLS, Masking, Classification)
├── 16_V1.5_STREAMLIT_DEPLOY.sql # v1.5 Streamlit 배포
├── 17_V1.6_OPERATIONS.sql       # v1.6 운영 (Alerts, Streams+Tasks)
├── 18_V1.6_STREAMLIT_DEPLOY.sql # v1.6 Streamlit 배포
├── 19_V2.0_ASSET_DATA.sql       # 6개 자산 카테고리 테이블
├── 20_RAG_SYSTEM.sql            # RAG 스키마 + 임베딩 + 검색
├── 21_GRAPH_RAG_SYSTEM.sql      # Graph RAG (노드/엣지/BFS 검색)
├── 22_V2.1_REGION_EXPANSION.sql # 25개 구 전체 확장
├── 23_PHASE3_INTEGRATION.sql    # Phase3 통합 (조인 분석)
├── 24_FIX_PREMIUM_DATA.sql      # 보험료 데이터 수정
├── 25_EXPAND_REGION_ALL_MONTHS.sql # 전 구/전 월 확장
├── 26_FIX_ALL_BUGS.sql          # 버그 수정 통합 (C-1~M-6)
├── 27_MART_UNIFIED_DDL.sql      # 마트 통합 DDL
├── 30_RAG_UPLOAD.sql            # RAG 청크 업로드
├── 31_SP_INSURE_ADVISOR.sql     # SP_ASK_INSURE_ADVISOR (보험 상담 SP)
├── 32_CORTEX_FORECAST_VERIFIED.sql # Cortex Forecast 검증본
└── 33_CORTEX_AGENT_UNIFIED.sql  # Cortex Agent 통합 (Analyst+Search)
```

---

## 8. Streamlit 앱 구조 (Andy V1.0 — 2026-04-12 기준)

```
streamlit_app.py              # 루트 진입점 (streamlit/src/main.py exec)
streamlit/src/
├── main.py                   # 세션, 사이드바, 라우팅 (5페이지)
├── utils.py                  # calc_premium(), DISTRICT_PROFILES, SEGMENTS_A/B, PRESETS
├── 01_Firstpage/first_page.py  # ✅ P1 — 버블차트+KPI+Top3/Bottom3 (105줄)
├── 02_Secondpage/second_page.py # ✅ P2 — 7단계 워터폴 시뮬레이터 (482줄, 핵심 데모)
├── 03_Thirdpage/third_page.py  # ✅ P3 — SP_ASK_INSURE_ADVISOR 챗봇 (21줄)
├── 04_Fourthpage/fourth_page.py # ⚠️ P4 — 레이더만 완성, 나머지 탭 플레이스홀더 [Andy 작업 중]
└── 05_Fifthpage/fifth_page.py  # ⚠️ P5 — 정적 테이블만, DB 쿼리 없음 (12줄)
```

### 주요 데이터 흐름
- P1/P2: `MART_DISTRICT_INSURANCE_SUMMARY` 직접 쿼리, 실패 시 `utils._demo_district_data()` 폴백
- P3: `INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR('{질문}')` 호출
- P2 `calc_premium()`: `utils.py:110` 단일 정의 — 수정 시 utils.py만 변경하면 됨

---

## 9. 핵심 기술 스택

- **Data Pipeline**: Dynamic Tables (메달리온 6-layer), Streams+Tasks, Snowpipe
- **AI/ML**: Cortex Analyst, Cortex Search, Cortex LLM (COMPLETE/SUMMARIZE), ML FORECAST, ML Classification, ML Anomaly Detection
- **RAG**: Plain RAG (367청크, EMBED_TEXT_768) + Graph RAG (31노드/34엣지, BFS)
- **Security**: RBAC, Row Access Policies, Dynamic Data Masking, st.secrets
- **External Data**: Snowflake Marketplace (GRANDATA, 아정당), 공공데이터 API (화재/CCTV/도난/침수)
- **Frontend**: Streamlit in Snowflake (5페이지), Plotly, GeoJSON

---

## 10. 코드 작업 시 주의사항

### 고유 규칙 (반드시 준수)
- **Snowflake 및 Streamlit 코드를 직접 수정/배포하지 않는다**
  - 모든 변경은 `feature_kijun` 브랜치 push로만 이루어짐
  - 배포(Snowflake에 업로드)는 Andy 고유 권한
- **P4 (`04_Fourthpage/`) 는 Andy 고유 영역** — 직접 수정 금지, 제안만 가능
- Streamlit 앱에서 DB 연결 시 `st.secrets` 사용 (하드코딩 금지)

### SQL 실행 규칙
- SQL 파일은 반드시 번호 순서대로 실행 (의존성 있음)
- 07번 번호가 중복됨 (yaml + sql) — `07_CORTEX_ANALYST.yaml` 먼저 실행
- 28~29번은 결번 (통합 과정에서 건너뜀)
- MART 테이블명 정합성 확인 필수: `MART_DISTRICT_INSURANCE_SUMMARY`, `V_FIRE_FORECAST_V13`

### 코딩 규칙
- `calc_premium()` 단일 정의 위치: `streamlit/src/utils.py:110` — 수정 시 이곳만
- P1 데모 폴백 데이터: `utils._demo_district_data()` (DB 실패 시 자동 전환)
