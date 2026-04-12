"""
Share에 뷰를 공유하려면 SECURE VIEW 필요.
1. V_SHARED_RISK_SUMMARY -> SECURE VIEW로 재생성
2. V_FIRE_FORECAST_MANUAL을 래핑한 V_FIRE_FORECAST_SHARED SECURE VIEW 생성
"""
import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
import snowflake.connector

CREDS = dict(
    account="xkrheif-fw39017", user="LIKEWISE95", password="Cnrrn1187cnrrn1187*",
    role="ACCOUNTADMIN", warehouse="COMPUTE_WH", database="INSURE_DB", schema="ANALYTICS",
)

# V_FIRE_FORECAST_MANUAL 컬럼 확인 후 래퍼 SECURE VIEW 생성
STEPS = [
    # 1. V_FIRE_FORECAST_MANUAL 컬럼 확인
    ("check_forecast_cols",
     "SELECT * FROM INSURE_DB.ANALYTICS.V_FIRE_FORECAST_MANUAL LIMIT 1"),

    # 2. V_SHARED_RISK_SUMMARY -> SECURE VIEW 재생성
    ("recreate_secure_risk_summary", """
CREATE OR REPLACE SECURE VIEW INSURE_DB.ANALYTICS.V_SHARED_RISK_SUMMARY AS
SELECT
    m.GU_NAME,
    m.YEAR_MONTH,
    m.COMPOSITE_RISK_SCORE,
    m.RISK_GRADE,
    m.FIRE_RISK_SCORE,
    m.THEFT_RISK_SCORE,
    m.BUILDING_RISK_SCORE,
    m.WEATHER_RISK_SCORE,
    CASE
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 30000  THEN '3 미만'
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 50000  THEN '3~5'
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 70000  THEN '5~7'
        WHEN m.ADJUSTED_PREMIUM_MONTHLY < 100000 THEN '7~10'
        ELSE '10 이상'
    END AS PREMIUM_RANGE_KRW10K,
    ROUND(m.ESTIMATED_ANNUAL_MARKET_KRW / 100000000.0, 1) AS ANNUAL_MARKET_100M,
    CURRENT_TIMESTAMP() AS UPDATED_AT
FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY m
WHERE m.YEAR_MONTH = (
    SELECT MAX(T.YEAR_MONTH)
    FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY T
)
"""),

    # 3. V_SHARED_RISK_SUMMARY -> Share GRANT
    ("grant_risk_summary_to_share",
     "GRANT SELECT ON VIEW INSURE_DB.ANALYTICS.V_SHARED_RISK_SUMMARY TO SHARE INSURE_RISK_SHARE"),

    # 4. V_FIRE_FORECAST_MANUAL -> SECURE wrapper
    ("create_secure_forecast_view", """
CREATE OR REPLACE SECURE VIEW INSURE_DB.ANALYTICS.V_FIRE_FORECAST_SHARED AS
SELECT * FROM INSURE_DB.ANALYTICS.V_FIRE_FORECAST_MANUAL
"""),

    # 5. V_FIRE_FORECAST_SHARED -> Share GRANT
    ("grant_forecast_to_share",
     "GRANT SELECT ON VIEW INSURE_DB.ANALYTICS.V_FIRE_FORECAST_SHARED TO SHARE INSURE_RISK_SHARE"),

    # 검증
    ("verify_share_grants",
     "SHOW GRANTS TO SHARE INSURE_RISK_SHARE"),

    ("verify_risk_summary",
     "SELECT GU_NAME, RISK_GRADE, PREMIUM_RANGE_KRW10K, ANNUAL_MARKET_100M FROM INSURE_DB.ANALYTICS.V_SHARED_RISK_SUMMARY ORDER BY COMPOSITE_RISK_SCORE DESC LIMIT 5"),
]


def main():
    print("Snowflake 연결 중...")
    conn = snowflake.connector.connect(**CREDS)
    cur  = conn.cursor()
    print(f"[OK] 연결 성공\n")

    ok = err = 0
    for label, sql in STEPS:
        try:
            cur.execute(sql.strip())
            rows = cur.fetchall()
            print(f"[OK] {label}")
            if label == "check_forecast_cols" and rows:
                cols = [d[0] for d in cur.description]
                print(f"     cols: {cols}")
            elif rows:
                for r in rows[:5]:
                    print(f"     -> {r}")
            ok += 1
        except Exception as e:
            msg = str(e).split("\n")[0][:150]
            print(f"[ERR] {label}")
            print(f"      {msg}")
            err += 1

    cur.close(); conn.close()
    print(f"\n========== 완료: 성공 {ok} / 실패 {err} ==========")
    sys.exit(0 if err == 0 else 1)


if __name__ == "__main__":
    main()
