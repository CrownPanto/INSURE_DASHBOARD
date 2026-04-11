# INSURE SQL 실행 순서 가이드
> 최종 업데이트: 2026-04-11 | 브랜치: feature_kijun

## 실행 전 주의사항
- **반드시 순서대로 실행** (의존성이 있으므로 건너뛰기 금지)
- ACCOUNTADMIN 역할 사용: `USE ROLE ACCOUNTADMIN;`
- 웨어하우스: `USE WAREHOUSE COMPUTE_WH;`
- 각 Phase 완료 후 Verification 쿼리로 검증

---

## Phase 1: 기본 인프라 (최초 1회)
> 이미 실행 완료된 경우 SKIP

| 순서 | 파일 | 용도 | 검증 |
|------|------|------|------|
| 1 | `01_INSURE_DB_SETUP.sql` | DB + 7 Schemas 생성 | `SHOW SCHEMAS IN INSURE_DB;` |
| 2 | `02_PUBLIC_DATA_DDL.sql` | RAW 테이블 9개 DDL | `SHOW TABLES IN INSURE_DB.RAW_PUBLIC;` |
| 3 | `03_SEED_DATA.sql` | 서울 25구 시드 데이터 INSERT | `SELECT COUNT(*) FROM RAW_PUBLIC.FIRE_STATS;` → 100행 |
| 4 | `04_DBT_STAGING.sql` | STAGING 뷰 13개 생성 | `SHOW VIEWS IN INSURE_DB.STAGING;` |

## Phase 2: 분석 레이어
| 순서 | 파일 | 용도 | 검증 |
|------|------|------|------|
| 5 | `05_DBT_INTERMEDIATE.sql` | 세그먼트 분류 + 리스크 스코어 | `SELECT COUNT(DISTINCT DISTRICT_NAME) FROM INTERMEDIATE.INT_DISTRICT_RISK_SCORE;` → 25 |
| 6 | `06_DBT_MART.sql` | MART 테이블 + 구별 보험 요약 | `SELECT COUNT(DISTINCT GU_NAME) FROM MART.MART_DISTRICT_INSURANCE_SUMMARY;` → 25 |

## Phase 3: 버그 수정 (4/11 신규)
> **06번 실행 후 반드시 순서대로**

| 순서 | 파일 | 용도 | 검증 |
|------|------|------|------|
| 7 | `26_FIX_ALL_BUGS.sql` | 10개 버그 통합 수정 (C-8,M-5,M-6,C-1,C-7,M-1,M-3,M-2,C-5,C-4) | 각 Phase별 Verification 쿼리 포함 |
| 8 | `27_MART_UNIFIED_DDL.sql` | MART 6개 테이블/뷰 재구성 (버그 수정 반영) | `SELECT COUNT(DISTINCT GU_NAME) FROM MART.MART_DISTRICT_INSURANCE_SUMMARY;` → 25 |

### 26번 수정 내역 요약
| 버그ID | 대상 | 수정 내용 |
|--------|------|----------|
| C-8 | 03_SEED | 건물 유형별 위험도 차등화 (목재1.2/콘크리트1.0/철강0.8) |
| M-5 | 03_SEED | 리스크 가중치 합계 정규화 (1.07→1.0) |
| M-6 | 03_SEED | ROBBERY 최소값 5점 보장 |
| C-1 | 05_INT | BUILDING*100 범위초과 → 정규화 비율 직접 사용 |
| C-7 | 05_INT | 동산가치 MIN-MAX 정규화 |
| M-1 | 05_INT | 세그먼트 연령 5년 단위 비중복 재정의 |
| M-3 | 06_MART | 신용등급 6→5단계 (800/700/600/500) |
| M-2 | 06_MART | 저위험 임계값 30→25 |
| C-5 | 07_YAML | YAML expr 컬럼명 8건 수정 (STG 별칭 정합성) |
| C-4 | 09_PIPE | Task LIMIT 0 제거 → 소스 뷰 재계산 |

## Phase 4: 부가 기능
| 순서 | 파일 | 용도 | 비고 |
|------|------|------|------|
| 9 | `07_CORTEX_ANALYST.yaml` | Cortex Analyst 시맨틱 모델 | Snowflake Stage에 업로드 필요 |
| 10 | `08_CORTEX_ML_LLM.sql` | ML/LLM 함수 | 선택 사항 |
| 11 | `10_GRANTS.sql` | MCP_ROLE 권한 | 필요 시 |
| 12 | `22_V2.1_REGION_EXPANSION.sql` | 지역 확장 | 25구 확장 이후 |
| 13 | `24_FIX_PREMIUM_DATA.sql` | 보험료 이상값 수정 | |
| 14 | `25_EXPAND_REGION_ALL_MONTHS.sql` | 전체 YEAR_MONTH 확장 | |

## Phase 5: RAG + Graph RAG
| 순서 | 파일 | 용도 | 검증 |
|------|------|------|------|
| 15 | `20_RAG_SYSTEM.sql` | RAG 스키마 + 임베딩 | `SELECT COUNT(*) FROM RAG.RAG_CHUNKS;` → 367 |
| 16 | `30_RAG_UPLOAD.sql` | 367개 청크 INSERT | 위와 동일 |
| 17 | `21_GRAPH_RAG_SYSTEM.sql` | Graph 노드/엣지 | `SELECT COUNT(*) FROM GRAPH.GRAPH_NODES;` → 31 |

## Phase 6: 통합 + Agent (최종)
> **Phase 5 완료 후 실행**

| 순서 | 파일 | 용도 | 검증 |
|------|------|------|------|
| 18 | `23_PHASE3_INTEGRATION.sql` | RAG↔Graph 브릿지 + 통합검색 SP + Agent Tool 4개 | 아래 테스트 참조 |
| 19 | `31_SP_INSURE_ADVISOR.sql` | SP_ASK_INSURE_ADVISOR 프로시저 | 아래 테스트 참조 |

### Phase 6 테스트 시나리오
```sql
-- 1. 브릿지 매핑 확인
SELECT COUNT(*) FROM RAG.RAG_GRAPH_BRIDGE;

-- 2. 통합 검색 테스트
CALL SP_ENHANCED_SEARCH('태풍으로 인한 피해가 보장되나요?', 5, 2, 0.3);

-- 3. 보험료 계산 경로
CALL SP_ENHANCED_SEARCH('보험료는 어떻게 계산되나요?', 5, 2, 0.3);

-- 4. 데이터 리니지
SELECT AGENT_DATA_LINEAGE('INT_DISTRICT_RISK_SCORE');

-- 5. AI 어드바이저
CALL SP_ASK_INSURE_ADVISOR('강남구 동산보험 추천해주세요');
```

---

## 실행하지 않는 파일 (참고용)
| 파일 | 이유 |
|------|------|
| `07_MART_GENDER_AGE_CORRELATION.sql` | 상관분석 뷰 (선택 사항) |
| `09_EXTERNAL_STAGE_SNOWPIPE.sql` | C-4 수정 완료, 소스 뷰 생성 후 실행 |
| `11~19` | 버전 업그레이드 이력. 27번에 통합됨 |
| `sql/archive/*` | 구버전 아카이브. 실행 금지 |

---

## 빠른 전체 검증 쿼리
```sql
-- 모든 핵심 테이블 행 수 한번에 확인
SELECT 'INT_SEGMENT_CLASSIFICATION' AS tbl, COUNT(*) AS rows FROM INTERMEDIATE.INT_SEGMENT_CLASSIFICATION
UNION ALL SELECT 'INT_DISTRICT_RISK_SCORE', COUNT(*) FROM INTERMEDIATE.INT_DISTRICT_RISK_SCORE
UNION ALL SELECT 'MART_INSURANCE_DESIGN', COUNT(*) FROM MART.MART_INSURANCE_DESIGN
UNION ALL SELECT 'MART_DISTRICT_INSURANCE_SUMMARY', COUNT(*) FROM MART.MART_DISTRICT_INSURANCE_SUMMARY
UNION ALL SELECT 'RAG_CHUNKS', COUNT(*) FROM RAG.RAG_CHUNKS
UNION ALL SELECT 'GRAPH_NODES', COUNT(*) FROM GRAPH.GRAPH_NODES
UNION ALL SELECT 'GRAPH_EDGES', COUNT(*) FROM GRAPH.GRAPH_EDGES
ORDER BY tbl;
```
