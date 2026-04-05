# INSURE 버전 변경 기록

## v1.1 (2026-04-04) — GU 커버리지 확대 + 리스크 스코어 최적화

### 변경 사항 요약

| 항목 | v1.0 | v1.1 | 변화 |
|------|------|------|------|
| 표시 구 수 | 3개 (중구, 영등포구, 서초구) | **25개 (서울 전체)** | +22개 |
| 평균 리스크 스코어 | 46.2 | **33.9** | -12.3 (현실화) |
| 평균 보험료 | W70,567 | **W77,066** | +9.2% |
| 총 인구 | ~2.7M | **~159M** | 25개 구 합산 |
| 리스크 가중치 | 화재25/도난25/건물20/기상15 | **화재30/도난30/건물15/기상10** | 동산보험 특성 반영 |

### 상세 변경 내역

#### 1. 구 커버리지 확대 (3 → 25)

**문제 진단:** GRANDATA Marketplace 데이터(ASSET_INCOME_INFO, FLOATING_POPULATION_INFO, CARD_SALES_INFO)가 서울 3개 구(중구/영등포구/서초구)만 포함. GU_CODE_MAPPING JOIN 자체는 정상이었으나, 원본 데이터 한계.

**해결:**
- 3개 구: GRANDATA 실측 데이터 기반 세그먼트 분석 유지
- 22개 구: 서울 평균값(소득/자산/보험료) + STG_DISTRICT_MASTER 인구 추정 + 공공데이터 리스크 스코어 조합
- MART_DISTRICT_INSURANCE_SUMMARY에 UNION ALL로 통합

**SQL:** `12_FIX_GU_COVERAGE_AND_RISK.sql`

#### 2. 리스크 스코어 최적화

**문제:** 절대값 기반 스코어링으로 인구 밀집 지역 불리, 전체적으로 스코어가 너무 높게 산출

**변경:**
- 화재 리스크: 분모를 250→300으로 조정, 재산피해 분모 5B→8B로 조정
- 도난 리스크: 절도 분모 5000→6000, 침입절도 500→600, 총범죄 12000→15000
- 복합 가중치: 화재/도난 각 30% (동산보험 핵심 위험), 건물 15%, 기상 10%
- 안전인프라/CCTV 감점은 유지 (8%/7%)

#### 3. MART 테이블 재구축

- `INT_DISTRICT_RISK_SCORE`: 조정된 스코어링으로 재생성
- `MART_DISTRICT_INSURANCE_SUMMARY`: 25개 구 통합 버전
- `MART_PREMIUM_SIMULATION`: 뷰 재생성

---

## v1.2 (2026-04-05) — 조인 개선 + 시각화 강화 + Feedback 시스템

### 변경 사항 요약

| 항목 | v1.1 | v1.2 | 변화 |
|------|------|------|------|
| 대시보드 페이지 | 4개 | **5개** | +Risk Map, +Feedback |
| APT_PRICE 통합 | 없음 | **평당 매매/전세가** | RICHGO 데이터 활용 |
| 조인 방식 | 일부 불일치 | **TRIM() 전수 적용** | 조인 안정성 확보 |
| Feedback 테이블 | 스키마만 존재 | **테이블 생성 + UI** | 피드백 수집 가능 |
| 평균 리스크 | 33.9 | **19.8** | TRIM 조인 후 매칭 개선 |
| 평균 아파트 평당가 | - | **W2,880** | 신규 지표 |

### 상세 변경 내역

#### 1. SQL 개선 (`13_V1.2_IMPROVEMENTS.sql`)

- **TRIM 조인**: 모든 DISTRICT_NAME 조인에 TRIM() 적용 → 공백 불일치 해소
- **APT_PRICE 통합**: RICHGO STG_APT_PRICE 데이터로 구별 평당 매매/전세 가격 추가
  - 실측 데이터 3개 구 + 서울 평균으로 22개 구 보완
  - AVG_SALE_PRICE_PYEONG, AVG_JEONSE_PRICE_PYEONG 컬럼 추가
- **Feedback 테이블**: FEEDBACK_RESPONSES, FEEDBACK_PREMIUM_ADJUSTMENT 생성

#### 2. Streamlit 대시보드 v1.2 (5페이지)

**Page 1 - Main Dashboard (강화)**
- 리스크 등급별 색상 매핑 (고위험/중위험/저위험/미산정)
- Top 10 보험료 구 차트 추가

**Page 2 - Risk Map (신규)**
- scatter_mapbox: 서울 25개 구 좌표 기반 지도 시각화
- 전환 가능 메트릭: 리스크 스코어 / 보험료 / 인구
- 레이더 차트: 선택 구 vs 서울 평균 리스크 비교

**Page 3 - Risk Analysis (강화)**
- 히트맵 추가 (px.imshow): 구별 화재/도난/건물/기상 리스크
- SAFETY_INFRA_SCORE, CCTV_SECURITY_SCORE 컬럼 추가

**Page 4 - Premium Simulator (강화)**
- Waterfall 차트: Base → Risk Adj → Credit Adj → Final 분해
- go.Waterfall 사용

**Page 5 - Feedback (신규)**
- 사용자 피드백 폼 (리스크 정확도/보험료 공정성/데이터 품질/만족도)
- INSURE_DB.FEEDBACK.FEEDBACK_RESPONSES에 INSERT
- 제출된 피드백 요약 통계 표시

#### 3. 배포

- 한글 인코딩 이슈: Unicode escape (\uXXXX) 방식으로 해결
- WRITE_RAW_FILE 2-arg 버전 사용 (3-arg는 인자 순서 상이)
- 파일 크기: 8,363 bytes → 18,633 bytes

---

## v1.0 (2026-04-04) — 초기 배포

- 6개 스키마 아키텍처 구축 완료
- 11개 SQL 스크립트 실행
- Streamlit 4페이지 대시보드 배포
- Cortex Analyst 시맨틱 모델 배포
- 21개 세그먼트 자동 분류 로직
- 보험료 산출 공식: base_premium * (1 + risk/200) * credit_adj
