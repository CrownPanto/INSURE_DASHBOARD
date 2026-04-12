"""
오류난 구문만 수정해서 재실행:
  1. sql/33 GRANT → ANALYTICS_ROLE 없으므로 INSURE_VIEWER 사용
  2. sql/34 GRANT → MART_PREMIUM_LAYER -> MART_INSURANCE_DESIGN
                    V_FIRE_FORECAST_V13 -> V_FIRE_FORECAST_MANUAL
  3. sql/34 CREATE VIEW V_SHARED_RISK_SUMMARY 재시도
"""
import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
import snowflake.connector

CREDS = dict(
    account="xkrheif-fw39017", user="LIKEWISE95", password="Cnrrn1187cnrrn1187*",
    role="ACCOUNTADMIN", warehouse="COMPUTE_WH", database="INSURE_DB", schema="ANALYTICS",
)

FIXES = [
    # ── sql/33 GRANT 수정 ────────────────────────────────────────
    ("33 GRANT: FN_CLASSIFY_INTENT -> INSURE_VIEWER",
     "GRANT USAGE ON FUNCTION INSURE_DB.ANALYTICS.FN_CLASSIFY_INTENT(VARCHAR) TO ROLE INSURE_VIEWER"),

    ("33 GRANT: SP_QUERY_DATA -> INSURE_VIEWER",
     "GRANT USAGE ON PROCEDURE INSURE_DB.ANALYTICS.SP_QUERY_DATA(VARCHAR) TO ROLE INSURE_VIEWER"),

    ("33 GRANT: SP_QUERY_GRAPH -> INSURE_VIEWER",
     "GRANT USAGE ON PROCEDURE INSURE_DB.ANALYTICS.SP_QUERY_GRAPH(VARCHAR) TO ROLE INSURE_VIEWER"),

    ("33 GRANT: SP_INSURE_AGENT -> INSURE_VIEWER",
     "GRANT USAGE ON PROCEDURE INSURE_DB.ANALYTICS.SP_INSURE_AGENT(VARCHAR) TO ROLE INSURE_VIEWER"),

    # ── sql/34 GRANT 수정 ────────────────────────────────────────
    ("34 GRANT: MART_INSURANCE_DESIGN",
     "GRANT SELECT ON TABLE INSURE_DB.MART.MART_INSURANCE_DESIGN TO SHARE INSURE_RISK_SHARE"),

    ("34 GRANT: MART_SEGMENT_PERSONA",
     "GRANT SELECT ON TABLE INSURE_DB.MART.MART_SEGMENT_PERSONA TO SHARE INSURE_RISK_SHARE"),

    ("34 GRANT: V_FIRE_FORECAST_MANUAL",
     "GRANT SELECT ON VIEW INSURE_DB.ANALYTICS.V_FIRE_FORECAST_MANUAL TO SHARE INSURE_RISK_SHARE"),

    # ── sql/34 CREATE VIEW V_SHARED_RISK_SUMMARY ─────────────────
    ("34 CREATE VIEW: V_SHARED_RISK_SUMMARY", """
CREATE OR REPLACE VIEW INSURE_DB.ANALYTICS.V_SHARED_RISK_SUMMARY AS
SELECT
    m.GU_NAME                                               AS GU_NAME,
    m.YEAR_MONTH                                            AS YEAR_MONTH,
    m.COMPOSITE_RISK_SCORE                                  AS COMPOSITE_RISK_SCORE,
    m.RISK_GRADE                                            AS RISK_GRADE,
    m.FIRE_RISK_SCORE                                       AS FIRE_RISK_SCORE,
    m.THEFT_RISK_SCORE                                      AS THEFT_RISK_SCORE,
    m.BUILDING_RISK_SCORE                                   AS BUILDING_RISK_SCORE,
    m.WEATHER_RISK_SCORE                                    AS WEATHER_RISK_SCORE,
    CASE
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 30000  THEN '3 미만'
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 50000  THEN '3~5'
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 70000  THEN '5~7'
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 100000 THEN '7~10'
        ELSE '10 이상'
    END                                                     AS PREMIUM_RANGE_KRW10K,
    ROUND(m.ESTIMATED_ANNUAL_MARKET_KRW / 100000000.0, 1)  AS ANNUAL_MARKET_100M,
    CURRENT_TIMESTAMP()                                     AS UPDATED_AT
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY m
WHERE m.YEAR_MONTH = (
    SELECT MAX(T.YEAR_MONTH)
    FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY T
)
"""),

    ("34 GRANT: V_SHARED_RISK_SUMMARY -> Share",
     "GRANT SELECT ON VIEW INSURE_DB.ANALYTICS.V_SHARED_RISK_SUMMARY TO SHARE INSURE_RISK_SHARE"),

    # ── 검증 ────────────────────────────────────────────────────
    ("검증: V_SHARED_RISK_SUMMARY 조회",
     "SELECT GU_NAME, RISK_GRADE, PREMIUM_RANGE_KRW10K, ANNUAL_MARKET_100M FROM INSURE_DB.ANALYTICS.V_SHARED_RISK_SUMMARY ORDER BY COMPOSITE_RISK_SCORE DESC LIMIT 5"),

    ("검증: SHOW GRANTS TO SHARE",
     "SHOW GRANTS TO SHARE INSURE_RISK_SHARE"),
]


def main():
    print("Snowflake 연결 중...")
    conn = snowflake.connector.connect(**CREDS)
    cur  = conn.cursor()
    print(f"[OK] 연결 성공 — {CREDS['account']} / {CREDS['role']}\n")

    ok = err = 0
    for label, sql in FIXES:
        try:
            cur.execute(sql.strip())
            rows = cur.fetchall()
            print(f"[OK] {label}")
            if rows:
                for r in rows[:5]:
                    print(f"     -> {r}")
            ok += 1
        except Exception as e:
            msg = str(e).split("\n")[0][:120]
            print(f"[ERR] {label}")
            print(f"      {msg}")
            err += 1

    cur.close(); conn.close()
    print(f"\n========== 완료: 성공 {ok} / 실패 {err} ==========")
    sys.exit(0 if err == 0 else 1)


if __name__ == "__main__":
    main()
