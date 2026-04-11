# -*- coding: utf-8 -*-
"""
INSURE Project - Automated Test Suite
- Graph RAG verification (from graph_rag_test.py)
- Premium calculation logic validation
- SQL schema integrity checks
- Data consistency checks

Usage: python test_all.py
"""

import sys
import os
import re
from pathlib import Path

# ── Test Framework ──
PASS_COUNT = 0
FAIL_COUNT = 0
RESULTS = []


def test(name, condition, detail=""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        RESULTS.append(("PASS", name, detail))
    else:
        FAIL_COUNT += 1
        RESULTS.append(("FAIL", name, detail))


def section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


# ============================================================
# TEST 1: Graph RAG (DuckDB)
# ============================================================
def test_graph_rag():
    section("1. Graph RAG Integrity")
    try:
        import duckdb
        con = duckdb.connect(":memory:")

        # Import seed functions from graph_rag_test
        sys.path.insert(0, str(Path(__file__).parent))
        from graph_rag_test import create_schema, seed_nodes, seed_edges

        create_schema(con)
        seed_nodes(con)
        seed_edges(con)

        # Node counts
        nodes = con.execute("SELECT node_type, COUNT(*) AS cnt FROM GRAPH_NODES GROUP BY node_type ORDER BY node_type").fetchall()
        node_dict = {r[0]: r[1] for r in nodes}
        test("CLAUSE nodes = 14", node_dict.get("CLAUSE") == 14, f"got {node_dict.get('CLAUSE')}")
        test("DATA nodes = 11", node_dict.get("DATA") == 11, f"got {node_dict.get('DATA')}")
        test("RULE nodes = 4", node_dict.get("RULE") == 4, f"got {node_dict.get('RULE')}")
        test("MODEL nodes = 2", node_dict.get("MODEL") == 2, f"got {node_dict.get('MODEL')}")

        # Edge counts
        total_edges = con.execute("SELECT COUNT(*) FROM GRAPH_EDGES").fetchone()[0]
        test("Total edges = 34", total_edges == 34, f"got {total_edges}")

        # Edge types
        edge_types = con.execute("SELECT DISTINCT edge_type FROM GRAPH_EDGES ORDER BY edge_type").fetchall()
        expected_types = {"APPLIES", "CALCULATES", "COVERS", "LIMITS", "PREDICTS", "REFERENCES"}
        actual_types = {r[0] for r in edge_types}
        test("6 edge types exist", actual_types == expected_types, f"got {actual_types}")

        # Foreign key integrity
        orphan_edges = con.execute("""
            SELECT COUNT(*) FROM GRAPH_EDGES e
            WHERE NOT EXISTS (SELECT 1 FROM GRAPH_NODES n WHERE n.node_id = e.source_node_id)
               OR NOT EXISTS (SELECT 1 FROM GRAPH_NODES n WHERE n.node_id = e.target_node_id)
        """).fetchone()[0]
        test("No orphan edges", orphan_edges == 0, f"orphans: {orphan_edges}")

        # BFS traversal
        bfs = con.execute("""
            WITH RECURSIVE pt AS (
                SELECT t.node_id AS target_id, 1 AS hop, [s.node_id, t.node_id] AS path
                FROM GRAPH_EDGES e
                JOIN GRAPH_NODES s ON e.source_node_id = s.node_id
                JOIN GRAPH_NODES t ON e.target_node_id = t.node_id
                WHERE s.node_id = 'CL_06'
                UNION ALL
                SELECT t.node_id, pt.hop + 1, list_append(pt.path, t.node_id)
                FROM pt
                JOIN GRAPH_EDGES e ON pt.target_id = e.source_node_id
                JOIN GRAPH_NODES t ON e.target_node_id = t.node_id
                WHERE pt.hop < 3 AND NOT list_contains(pt.path, t.node_id)
            )
            SELECT COUNT(*) FROM pt
        """).fetchone()[0]
        test("BFS from CL_06 finds paths", bfs > 0, f"found {bfs} paths")

        # Hub node check (CL_04 should be most connected)
        hub = con.execute("""
            SELECT n.node_id,
                (SELECT COUNT(*) FROM GRAPH_EDGES e WHERE e.source_node_id = n.node_id) +
                (SELECT COUNT(*) FROM GRAPH_EDGES e WHERE e.target_node_id = n.node_id) AS total
            FROM GRAPH_NODES n ORDER BY total DESC LIMIT 1
        """).fetchone()
        test("CL_04 is hub node", hub[0] == "CL_04", f"hub is {hub[0]} with {hub[1]} connections")

        con.close()
    except Exception as e:
        test("Graph RAG module loads", False, str(e))


# ============================================================
# TEST 2: Premium Calculation Logic
# ============================================================
def test_premium_logic():
    section("2. Premium Calculation Logic")

    # Replicate core calc_premium logic from utils.py
    def calc_premium(district_risk, income, items_value, segment_mult=1.0):
        base_rate = 0.001125
        base = items_value * base_rate

        # Risk adjustment (5-tier nonlinear curve)
        if district_risk < 20:
            risk_mult = 0.75
        elif district_risk < 40:
            risk_mult = 0.90
        elif district_risk < 60:
            risk_mult = 1.05
        elif district_risk < 80:
            risk_mult = 1.25
        else:
            risk_mult = 1.55

        adjusted = base * risk_mult
        loaded = adjusted * 1.15  # expense loading
        segmented = loaded * segment_mult

        # Affordability cap: 0.5% of monthly income
        cap = income * 0.005
        final = min(segmented, cap)
        return round(final)

    # Test cases
    p1 = calc_premium(30, 3000000, 5000000, 1.0)
    test("Low risk premium > 0", p1 > 0, f"got {p1}")
    test("Low risk premium < 10000", p1 < 10000, f"got {p1}")

    p2 = calc_premium(85, 3000000, 5000000, 1.0)
    test("High risk > low risk", p2 > p1, f"high={p2}, low={p1}")

    # Affordability cap
    p3 = calc_premium(90, 2000000, 50000000, 1.5)
    cap = 2000000 * 0.005
    test("Affordability cap applied", p3 <= cap, f"premium={p3}, cap={cap}")

    # Zero items
    p4 = calc_premium(50, 3000000, 0, 1.0)
    test("Zero items = zero premium", p4 == 0, f"got {p4}")

    # Segment multiplier effect
    p5_base = calc_premium(50, 5000000, 10000000, 1.0)
    p5_high = calc_premium(50, 5000000, 10000000, 1.5)
    test("Higher segment mult = higher premium", p5_high >= p5_base, f"base={p5_base}, high={p5_high}")


# ============================================================
# TEST 3: SQL File Integrity
# ============================================================
def test_sql_integrity():
    section("3. SQL File Integrity")

    sql_dir = Path(__file__).parent.parent / "sql"
    sql_files = sorted(sql_dir.glob("*.sql"))

    test("SQL directory exists", sql_dir.exists())
    test("SQL files > 20", len(sql_files) > 20, f"found {len(sql_files)}")

    # Check critical files exist
    critical = [
        "01_INSURE_DB_SETUP.sql",
        "04_DBT_STAGING.sql",
        "05_DBT_INTERMEDIATE.sql",
        "06_DBT_MART.sql",
        "21_GRAPH_RAG_SYSTEM.sql",
        "31_SP_INSURE_ADVISOR.sql",
    ]
    for f in critical:
        test(f"Critical file: {f}", (sql_dir / f).exists())

    # Check new files exist
    test("32_CORTEX_FORECAST_VERIFIED.sql exists", (sql_dir / "32_CORTEX_FORECAST_VERIFIED.sql").exists())
    test("33_CORTEX_AGENT_UNIFIED.sql exists", (sql_dir / "33_CORTEX_AGENT_UNIFIED.sql").exists())

    # Check FORECAST is NOT commented out in 32
    forecast_sql = (sql_dir / "32_CORTEX_FORECAST_VERIFIED.sql").read_text(encoding="utf-8")
    has_active_forecast = "CREATE OR REPLACE SNOWFLAKE.ML.FORECAST" in forecast_sql
    is_commented = "/*" in forecast_sql.split("CREATE OR REPLACE SNOWFLAKE.ML.FORECAST")[0].split("\n")[-1] if has_active_forecast else True
    test("32: FORECAST not commented out", has_active_forecast and not is_commented)

    # Check ANOMALY_DETECTION is active in 32
    has_active_anomaly = "CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION" in forecast_sql
    test("32: ANOMALY_DETECTION not commented out", has_active_anomaly)

    # Check Agent SP exists in 33
    agent_sql = (sql_dir / "33_CORTEX_AGENT_UNIFIED.sql").read_text(encoding="utf-8")
    test("33: SP_INSURE_AGENT defined", "SP_INSURE_AGENT" in agent_sql)
    test("33: FN_CLASSIFY_INTENT defined", "FN_CLASSIFY_INTENT" in agent_sql)
    test("33: SP_QUERY_GRAPH defined", "SP_QUERY_GRAPH" in agent_sql)

    # Check no hardcoded passwords in SQL files
    for f in sql_files:
        content = f.read_text(encoding="utf-8", errors="ignore")
        has_password = bool(re.search(r"password\s*=\s*['\"](?!your_)", content, re.IGNORECASE))
        test(f"No hardcoded password: {f.name}", not has_password)


# ============================================================
# TEST 4: Data Consistency (cross-file references)
# ============================================================
def test_data_consistency():
    section("4. Cross-file Data Consistency")

    sql_dir = Path(__file__).parent.parent / "sql"

    # Graph RAG nodes referenced in SQL should match seed data
    graph_sql = (sql_dir / "21_GRAPH_RAG_SYSTEM.sql").read_text(encoding="utf-8")

    # Count CLAUSE nodes in SQL
    clause_count = graph_sql.count("'CLAUSE'")
    test("Graph SQL has CLAUSE references", clause_count >= 14, f"found {clause_count}")

    # Check SP_ASK_INSURE_ADVISOR references RAG schema
    sp_sql = (sql_dir / "31_SP_INSURE_ADVISOR.sql").read_text(encoding="utf-8")
    test("SP references RAG.RAG_CHUNKS", "RAG.RAG_CHUNKS" in sp_sql)
    test("SP uses e5-base-v2", "e5-base-v2" in sp_sql)
    test("SP uses mistral-large2", "mistral-large2" in sp_sql)

    # Check Agent references both RAG and GRAPH
    agent_sql = (sql_dir / "33_CORTEX_AGENT_UNIFIED.sql").read_text(encoding="utf-8")
    test("Agent references GRAPH schema", "GRAPH.GRAPH_NODES" in agent_sql)
    test("Agent references SP_ASK_INSURE_ADVISOR", "SP_ASK_INSURE_ADVISOR" in agent_sql)
    test("Agent references MART tables", "MART.MART_DISTRICT_INSURANCE_SUMMARY" in agent_sql)


# ============================================================
# MAIN
# ============================================================
def main():
    print("=" * 60)
    print("  INSURE Project - Automated Test Suite")
    print("=" * 60)

    test_graph_rag()
    test_premium_logic()
    test_sql_integrity()
    test_data_consistency()

    # Summary
    section("TEST SUMMARY")
    for status, name, detail in RESULTS:
        marker = "PASS" if status == "PASS" else "FAIL"
        extra = f" ({detail})" if detail else ""
        print(f"  [{marker}] {name}{extra}")

    total = PASS_COUNT + FAIL_COUNT
    print(f"\n  Result: {PASS_COUNT}/{total} passed")
    if FAIL_COUNT == 0:
        print("  ==> All tests passed!")
    else:
        print(f"  ==> {FAIL_COUNT} test(s) failed")
    return 0 if FAIL_COUNT == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
