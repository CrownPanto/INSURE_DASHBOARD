import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import snowflake.connector

CREDS = dict(
    account="xkrheif-fw39017", user="LIKEWISE95", password="Cnrrn1187cnrrn1187*",
    role="ACCOUNTADMIN", warehouse="COMPUTE_WH", database="INSURE_DB", schema="PUBLIC",
)

conn = snowflake.connector.connect(**CREDS)
cur  = conn.cursor()

# 1. MART 테이블 목록
print("=== MART tables ===")
cur.execute("SHOW TABLES IN INSURE_DB.MART")
for r in cur.fetchall():
    print(" ", r[1])

# 2. ANALYTICS 뷰 목록
print("\n=== ANALYTICS views ===")
cur.execute("SHOW VIEWS IN INSURE_DB.ANALYTICS")
for r in cur.fetchall():
    print(" ", r[1])

# 3. MART_DISTRICT_INSURANCE_SUMMARY 컬럼 확인
print("\n=== MART_DISTRICT_INSURANCE_SUMMARY columns ===")
cur.execute("SELECT * FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY LIMIT 1")
cols = [d[0] for d in cur.description]
for c in cols:
    print(" ", c)

# 4. 롤 목록
print("\n=== Roles ===")
cur.execute("SHOW ROLES")
for r in cur.fetchall():
    print(" ", r[1])

cur.close(); conn.close()
