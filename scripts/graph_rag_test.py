# -*- coding: utf-8 -*-
"""
Graph RAG 로컬 검증 스크립트 (DuckDB)
- 21_GRAPH_RAG_SYSTEM.sql의 노드/엣지 데이터를 로컬 DuckDB에 재현
- Snowflake 연결 불필요, 오프라인 실행 가능
- 사용법: python graph_rag_test.py
"""

import sys
import duckdb
import pandas as pd
from tabulate import tabulate

DB_PATH = ":memory:"


def create_schema(con):
    con.execute("""
        CREATE TABLE GRAPH_NODES (
            node_id       VARCHAR PRIMARY KEY,
            node_type     VARCHAR NOT NULL,
            name          VARCHAR NOT NULL,
            description   VARCHAR,
            chapter       VARCHAR,
            schema_name   VARCHAR,
            table_name    VARCHAR,
            rule_version  VARCHAR,
            model_type    VARCHAR,
            metadata      JSON,
            created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    con.execute("""
        CREATE TABLE GRAPH_EDGES (
            edge_id         VARCHAR PRIMARY KEY,
            source_node_id  VARCHAR NOT NULL REFERENCES GRAPH_NODES(node_id),
            target_node_id  VARCHAR NOT NULL REFERENCES GRAPH_NODES(node_id),
            edge_type       VARCHAR NOT NULL,
            weight          DOUBLE DEFAULT 0.5,
            description     VARCHAR,
            created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)


def seed_nodes(con):
    """21_GRAPH_RAG_SYSTEM.sql PART 2 노드 31개 삽입"""

    # CLAUSE 14개
    clauses = [
        ('CL_01', 'CLAUSE', '제1조 목적',        '보험계약의 목적과 기본 원칙을 정의',               '총칙'),
        ('CL_02', 'CLAUSE', '제2조 보장범위',     '동산보험의 구체적 보장 범위와 대상 물품을 명시',     '총칙'),
        ('CL_03', 'CLAUSE', '제3조 보험금산출',   '보험금 지급 규칙 및 산출 방법론',                  '보험금지급'),
        ('CL_04', 'CLAUSE', '제4조 위험평가',     '자치구별 위험도 평가 및 계산 방식',                '보험금지급'),
        ('CL_05', 'CLAUSE', '제5조 면책사항',     '보험금 지급 제외 사항 및 조건',                    '보험금지급'),
        ('CL_06', 'CLAUSE', '제6조 보험료산정',   '5구간 비선형 리스크 커브를 적용한 보험료 계산',      '보험료'),
        ('CL_07', 'CLAUSE', '제7조 보험료조정',   '계약 이후 위험도 변화에 따른 보험료 조정 방식',      '보험료'),
        ('CL_08', 'CLAUSE', '제8조 계약체결',     '보험계약의 성립 요건 및 절차',                     '보험계약'),
        ('CL_09', 'CLAUSE', '제9조 해지환급',     '보험계약 해지 시 환급금 계산 및 지급 방식',         '보험계약'),
        ('CL_10', 'CLAUSE', '제10조 갱신',       '보험계약의 갱신 및 연장 조건',                     '보험계약'),
        ('CL_11', 'CLAUSE', '제11조 통지의무',   '계약자의 통지 의무 및 고지 사항',                  '보험계약'),
        ('CL_12', 'CLAUSE', '제12조 품목별한도', '품목(화재, 도난, 파손 등)별 보장한도 설정',         '품목별보장한도'),
        ('CL_13', 'CLAUSE', '제13조 분쟁해결',   '보험금 청구 분쟁의 해결 절차',                     '분쟁해결'),
        ('CL_14', 'CLAUSE', '제14조 관할법원',   '계약 관련 소송의 관할법원 지정',                   '분쟁해결'),
    ]

    # DATA 11개
    data_nodes = [
        ('DT_01', 'DATA', 'MART_DISTRICT_INSURANCE_SUMMARY', '자치구별 보험요약 데이터',       None, 'INSURE_DB.MART',         'MART_DISTRICT_INSURANCE_SUMMARY'),
        ('DT_02', 'DATA', 'INT_DISTRICT_RISK_SCORE',         '자치구별 위험점수',              None, 'INSURE_DB.INTERMEDIATE', 'INT_DISTRICT_RISK_SCORE'),
        ('DT_03', 'DATA', 'SEED_HOUSEHOLD_GOODS',            '가구 동산 품목 및 표준 가격',     None, 'INSURE_DB.RAW',          'SEED_HOUSEHOLD_GOODS'),
        ('DT_04', 'DATA', 'STG_FIRE_STATS',                  '화재 통계 및 발생률 데이터',      None, 'INSURE_DB.STAGING',      'STG_FIRE_STATS'),
        ('DT_05', 'DATA', 'STG_CRIME_STATS',                 '범죄 통계 및 발생률 데이터',      None, 'INSURE_DB.STAGING',      'STG_CRIME_STATS'),
        ('DT_06', 'DATA', 'STG_BUILDING_AGE',                '건물 노후도 및 건축 연도 통계',    None, 'INSURE_DB.STAGING',      'STG_BUILDING_AGE'),
        ('DT_07', 'DATA', 'STG_WEATHER_RISK',                '기상 위험 지수 및 변동 추이',      None, 'INSURE_DB.STAGING',      'STG_WEATHER_RISK'),
        ('DT_08', 'DATA', 'MART_PREMIUM_LAYER',              '보험료 계층화 및 세분화 데이터',    None, 'INSURE_DB.MART',         'MART_PREMIUM_LAYER'),
        ('DT_09', 'DATA', 'RAG_CHUNKS',                      'RAG 기반 약관 청크 및 임베딩',     None, 'INSURE_DB.RAG',          'RAG_CHUNKS'),
        ('DT_10', 'DATA', 'V_FIRE_FORECAST_V13',             '화재 예측 분석 뷰 (Cortex ML)',    None, 'INSURE_DB.ANALYTICS',    'V_FIRE_FORECAST_V13'),
        ('DT_11', 'DATA', 'SEED_PERSONA_SEGMENTS',           '고객 세그먼트 및 페르소나 정보',    None, 'INSURE_DB.RAW',          'SEED_PERSONA_SEGMENTS'),
    ]

    # RULE 4개
    rules = [
        ('RL_01', 'RULE', '5구간 비선형 리스크 커브 v1.3',          '위험점수에 따른 5구간 비선형 프리미엄 산출', 'v1.3', None),
        ('RL_02', 'RULE', '7단계 보험료 산출 파이프라인',            '기본료->위험조정->신뢰도->부담능력->경쟁->승인->지급', 'v1.2', None),
        ('RL_03', 'RULE', 'Credibility Adjustment (Z=min(n/1082,1.0))', '표본 크기 기반 신뢰도 조정 계수', 'v1.0', None),
        ('RL_04', 'RULE', '부담능력 상한 (월소득 0.5%)',            '고객 월소득 기반 보험료 상한선 설정',        'v1.0', None),
    ]

    # MODEL 2개
    models = [
        ('ML_01', 'MODEL', 'Cortex ML FORECAST (화재 예측)',      '화재 발생률 및 손실 예측 ML 모델',          None, 'Cortex ML'),
        ('ML_02', 'MODEL', 'Cortex Agent SP_ASK_INSURE_ADVISOR', '약관 질의응답 및 RAG 기반 상담 에이전트',    None, 'Cortex Agent'),
    ]

    for c in clauses:
        con.execute(
            "INSERT INTO GRAPH_NODES(node_id,node_type,name,description,chapter) VALUES (?,?,?,?,?)", c)

    for d in data_nodes:
        con.execute(
            "INSERT INTO GRAPH_NODES(node_id,node_type,name,description,chapter,schema_name,table_name) VALUES (?,?,?,?,?,?,?)", d)

    for r in rules:
        con.execute(
            "INSERT INTO GRAPH_NODES(node_id,node_type,name,description,rule_version,model_type) VALUES (?,?,?,?,?,?)", r)

    for m in models:
        con.execute(
            "INSERT INTO GRAPH_NODES(node_id,node_type,name,description,rule_version,model_type) VALUES (?,?,?,?,?,?)", m)


def seed_edges(con):
    """21_GRAPH_RAG_SYSTEM.sql PART 3 엣지 34개 삽입"""
    edges = [
        # CLAUSE -> DATA (REFERENCES)
        ('E001', 'CL_02', 'DT_01', 'REFERENCES',  0.9,  '보장범위가 자치구별 보험요약 데이터 참조'),
        ('E002', 'CL_02', 'DT_03', 'REFERENCES',  0.8,  '보장범위가 가구동산 품목 데이터 참조'),
        ('E003', 'CL_04', 'DT_02', 'REFERENCES',  0.9,  '위험평가가 자치구별 위험점수 데이터 참조'),
        ('E004', 'CL_04', 'DT_04', 'REFERENCES',  0.7,  '위험평가가 화재통계 데이터 참조'),
        ('E005', 'CL_04', 'DT_05', 'REFERENCES',  0.7,  '위험평가가 범죄통계 데이터 참조'),
        ('E006', 'CL_04', 'DT_06', 'REFERENCES',  0.6,  '위험평가가 건물노후도 데이터 참조'),
        ('E007', 'CL_04', 'DT_07', 'REFERENCES',  0.6,  '위험평가가 기상위험 지수 참조'),
        ('E008', 'CL_07', 'DT_08', 'REFERENCES',  0.8,  '보험료조정이 프리미엄 레이어 데이터 참조'),
        ('E009', 'CL_12', 'DT_03', 'REFERENCES',  0.9,  '품목별한도가 가구동산 품목 데이터 참조'),
        # CLAUSE -> RULE (LIMITS)
        ('E010', 'CL_03', 'RL_02', 'LIMITS',      1.0,  '보험금산출이 7단계 보험료 산출 파이프라인 정의'),
        ('E011', 'CL_06', 'RL_01', 'LIMITS',      1.0,  '보험료산정이 5구간 비선형 리스크 커브 정의'),
        # RULE -> DATA (CALCULATES / APPLIES)
        ('E012', 'RL_01', 'DT_02', 'CALCULATES',  0.9,  '5구간 리스크 커브가 위험점수 데이터 사용'),
        ('E013', 'RL_02', 'DT_01', 'APPLIES',     1.0,  '7단계 파이프라인이 자치구별 보험요약에 적용'),
        ('E014', 'RL_02', 'DT_08', 'APPLIES',     0.9,  '7단계 파이프라인이 프리미엄 레이어에 적용'),
        ('E015', 'RL_03', 'DT_01', 'CALCULATES',  0.7,  '신뢰도조정이 보험요약 데이터의 신뢰도 계산'),
        ('E016', 'RL_04', 'DT_11', 'CALCULATES',  0.6,  '부담능력 상한이 고객 세그먼트 소득 데이터 사용'),
        # MODEL -> DATA (PREDICTS / CALCULATES)
        ('E017', 'ML_01', 'DT_10', 'PREDICTS',    0.9,  'Cortex ML FORECAST가 화재예측 분석 뷰 생성'),
        ('E018', 'ML_01', 'DT_04', 'CALCULATES',  0.8,  'Cortex ML FORECAST가 화재통계를 입력데이터로 사용'),
        ('E019', 'ML_02', 'DT_09', 'CALCULATES',  0.8,  'Cortex Agent가 RAG 청크 데이터 활용'),
        ('E020', 'ML_02', 'DT_01', 'CALCULATES',  0.9,  'Cortex Agent가 보험요약 데이터 조회'),
        # CLAUSE -> CLAUSE (COVERS)
        ('E021', 'CL_02', 'CL_12', 'COVERS',      0.7,  '보장범위가 품목별한도를 포함'),
        ('E022', 'CL_03', 'CL_06', 'COVERS',      0.8,  '보험금산출이 보험료산정과 상호 연결'),
        ('E023', 'CL_02', 'CL_04', 'COVERS',      0.7,  '보장범위와 위험평가가 상호 관련'),
        # 추가 연결 엣지
        ('E024', 'CL_03', 'DT_08', 'REFERENCES',  0.6,  '보험금산출이 프리미엄 레이어 참조'),
        ('E025', 'CL_06', 'DT_02', 'REFERENCES',  0.85, '보험료산정이 위험점수 데이터 참조'),
        ('E026', 'RL_02', 'DT_02', 'APPLIES',     0.8,  '7단계 파이프라인이 위험점수에 기반'),
        ('E027', 'CL_04', 'DT_10', 'REFERENCES',  0.5,  '위험평가가 화재예측 분석 참조'),
        ('E028', 'ML_01', 'DT_06', 'CALCULATES',  0.7,  'Cortex ML FORECAST가 건물노후도 입력데이터 사용'),
        ('E029', 'ML_01', 'DT_07', 'CALCULATES',  0.7,  'Cortex ML FORECAST가 기상위험 입력데이터 사용'),
        ('E030', 'ML_02', 'DT_02', 'CALCULATES',  0.7,  'Cortex Agent가 위험점수 조회 및 활용'),
        ('E031', 'CL_07', 'RL_03', 'LIMITS',      0.8,  '보험료조정이 신뢰도조정 규칙 적용'),
        ('E032', 'CL_06', 'RL_04', 'LIMITS',      0.8,  '보험료산정이 부담능력 상한 규칙 적용'),
        ('E033', 'CL_05', 'DT_02', 'REFERENCES',  0.5,  '면책사항이 위험점수 기반 제외 조건 참조'),
        ('E034', 'RL_01', 'DT_08', 'APPLIES',     0.85, '5구간 리스크 커브가 프리미엄 레이어 생성'),
    ]
    con.executemany(
        "INSERT INTO GRAPH_EDGES(edge_id,source_node_id,target_node_id,edge_type,weight,description) VALUES (?,?,?,?,?,?)",
        edges)


def q(con, label, sql):
    """쿼리 실행 + 테이블 출력"""
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"{'='*70}")
    try:
        df = con.execute(sql).fetchdf()
        if df.empty:
            print("  (no rows)")
        else:
            print(tabulate(df, headers="keys", tablefmt="simple", showindex=False))
        return df
    except Exception as e:
        print(f"  [FAIL] {e}")
        return None


def main():
    print("=" * 70)
    print("  INSURE Graph RAG Local Verification (DuckDB)")
    print("=" * 70)

    con = duckdb.connect(DB_PATH)
    create_schema(con)
    seed_nodes(con)
    seed_edges(con)
    print("[OK] DuckDB in-memory DB ready -- nodes: 31, edges: 34")

    results = {}

    # 1. 노드 타입별 개수
    results["nodes"] = q(con, "1. Node counts by type (expect: CLAUSE=14, DATA=11, RULE=4, MODEL=2)",
        "SELECT node_type, COUNT(*) AS cnt FROM GRAPH_NODES GROUP BY node_type ORDER BY node_type")

    # 2. 엣지 타입별 분포
    results["edges"] = q(con, "2. Edge distribution (expect: 34 total)",
        "SELECT edge_type, COUNT(*) AS cnt, "
        "ROUND(AVG(weight),3) AS avg_w, MIN(weight) AS min_w, MAX(weight) AS max_w "
        "FROM GRAPH_EDGES GROUP BY edge_type ORDER BY cnt DESC")

    # 3. 1-hop: CL_04 (위험평가) -> 참조 DATA
    results["q1"] = q(con, "3. 1-hop: CL_04 (Risk Assessment) -> referenced DATA",
        """SELECT s.node_id AS clause_id, s.name AS clause_name,
                  e.edge_type, t.node_id AS data_id, t.name AS data_name,
                  t.schema_name || '.' || t.table_name AS full_table,
                  e.weight
           FROM GRAPH_NODES s
           JOIN GRAPH_EDGES e ON s.node_id = e.source_node_id
           JOIN GRAPH_NODES t ON e.target_node_id = t.node_id
           WHERE s.node_id = 'CL_04' AND t.node_type = 'DATA' AND e.edge_type = 'REFERENCES'
           ORDER BY e.weight DESC""")

    # 4. 역추적: DT_02 (위험점수) <- 참조하는 노드들
    results["q2"] = q(con, "4. Reverse lookup: DT_02 (Risk Score) <- referencing nodes",
        """SELECT s.node_id, s.node_type, s.name, e.edge_type, e.weight
           FROM GRAPH_EDGES e
           JOIN GRAPH_NODES s ON e.source_node_id = s.node_id
           WHERE e.target_node_id = 'DT_02'
             AND e.edge_type IN ('REFERENCES','CALCULATES','APPLIES')
           ORDER BY s.node_type, e.weight DESC""")

    # 5. 2-hop: CL_02 -> DATA <- other nodes (reverse direction too)
    results["q3"] = q(con, "5. 2-hop: CL_02 (Coverage) -> DATA <- other nodes that also reference same DATA",
        """WITH cl02_data AS (
             SELECT e.target_node_id AS data_id, e.weight AS w1, nd.name AS data_name
             FROM GRAPH_EDGES e
             JOIN GRAPH_NODES nd ON e.target_node_id = nd.node_id
             WHERE e.source_node_id = 'CL_02' AND e.edge_type = 'REFERENCES'
           )
           SELECT 'CL_02' AS start_cl, cd.data_name AS via_data,
                  s.node_id AS related_id, s.name AS related_name, s.node_type,
                  e2.edge_type,
                  ROUND(cd.w1 * e2.weight, 3) AS combined_w
           FROM cl02_data cd
           JOIN GRAPH_EDGES e2 ON cd.data_id = e2.target_node_id
           JOIN GRAPH_NODES s ON e2.source_node_id = s.node_id
           WHERE s.node_id != 'CL_02'
           ORDER BY combined_w DESC""")

    # 6. BFS: CL_06 (보험료산정) 3-hop 이내 전체 경로
    results["q4"] = q(con, "6. BFS 3-hop from CL_06 (Premium Calculation)",
        """WITH RECURSIVE path_traversal AS (
             SELECT s.node_id AS source_id, s.name AS source_name,
                    t.node_id AS target_id, t.name AS target_name, t.node_type AS target_type,
                    e.edge_type, 1 AS hop,
                    [s.node_id, t.node_id] AS path_nodes,
                    e.weight AS path_w
             FROM GRAPH_EDGES e
             JOIN GRAPH_NODES s ON e.source_node_id = s.node_id
             JOIN GRAPH_NODES t ON e.target_node_id = t.node_id
             WHERE s.node_id = 'CL_06'
             UNION ALL
             SELECT pt.source_id, pt.source_name,
                    t.node_id, t.name, t.node_type,
                    e.edge_type, pt.hop + 1,
                    list_append(pt.path_nodes, t.node_id),
                    pt.path_w * e.weight
             FROM path_traversal pt
             JOIN GRAPH_EDGES e ON pt.target_id = e.source_node_id
             JOIN GRAPH_NODES t ON e.target_node_id = t.node_id
             WHERE pt.hop < 3 AND NOT list_contains(pt.path_nodes, t.node_id)
           )
           SELECT hop, target_id, target_name, target_type,
                  ROUND(path_w, 3) AS weight, path_nodes
           FROM path_traversal
           ORDER BY hop, path_w DESC""")

    # 7. 노드 연결성 TOP 10
    results["connectivity"] = q(con, "7. Node connectivity TOP 10",
        """SELECT n.node_id, n.name, n.node_type,
                  (SELECT COUNT(*) FROM GRAPH_EDGES e WHERE e.source_node_id = n.node_id) AS out_edges,
                  (SELECT COUNT(*) FROM GRAPH_EDGES e WHERE e.target_node_id = n.node_id) AS in_edges,
                  (SELECT COUNT(*) FROM GRAPH_EDGES e WHERE e.source_node_id = n.node_id) +
                  (SELECT COUNT(*) FROM GRAPH_EDGES e WHERE e.target_node_id = n.node_id) AS total
           FROM GRAPH_NODES n
           ORDER BY total DESC LIMIT 10""")

    # 8. 전체 엣지 리스트
    results["all_edges"] = q(con, "8. Full edge list (sorted by weight)",
        """SELECT source_node_id || ' (' || s.node_type || ')' AS from_node,
                  target_node_id || ' (' || t.node_type || ')' AS to_node,
                  e.edge_type, e.weight, e.description
           FROM GRAPH_EDGES e
           JOIN GRAPH_NODES s ON e.source_node_id = s.node_id
           JOIN GRAPH_NODES t ON e.target_node_id = t.node_id
           ORDER BY e.weight DESC, s.node_id""")

    # ── Summary ──
    print(f"\n{'='*70}")
    print("  VERIFICATION SUMMARY")
    print(f"{'='*70}")

    node_df = results["nodes"]
    edge_df = results["edges"]
    node_ok = node_df is not None and int(node_df["cnt"].sum()) == 31
    edge_ok = edge_df is not None and int(edge_df["cnt"].sum()) == 34

    checks = [
        ("Nodes: 31 total (14+11+4+2)",  node_ok),
        ("Edges: 34 total",              edge_ok),
        ("1-hop query works",            results["q1"] is not None and not results["q1"].empty),
        ("Reverse lookup works",         results["q2"] is not None and not results["q2"].empty),
        ("2-hop traversal works",        results["q3"] is not None and not results["q3"].empty),
        ("BFS 3-hop traversal works",    results["q4"] is not None and not results["q4"].empty),
        ("Connectivity analysis works",  results["connectivity"] is not None and not results["connectivity"].empty),
        ("Full edge listing works",      results["all_edges"] is not None and not results["all_edges"].empty),
    ]

    for label, ok in checks:
        status = "PASS" if ok else "FAIL"
        print(f"  [{status}] {label}")

    passed = sum(1 for _, ok in checks if ok)
    total = len(checks)
    print(f"\n  Result: {passed}/{total} passed")

    if passed == total:
        print("  ==> Graph RAG system verified successfully!")
    else:
        print("  ==> Some checks failed -- see logs above")

    con.close()


if __name__ == "__main__":
    main()
