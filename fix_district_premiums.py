import snowflake.connector
import warnings
warnings.filterwarnings('ignore')

conn = snowflake.connector.connect(
    account='xkrheif-fw39017',
    user='LIKEWISE95',
    password='Cnrrn1187cnrrn1187*',
    role='ACCOUNTADMIN',
    warehouse='COMPUTE_WH',
    database='INSURE_DB',
    schema='MART'
)

cur = conn.cursor()
cur.execute("USE ROLE ACCOUNTADMIN")
cur.execute("USE WAREHOUSE COMPUTE_WH")
cur.execute("USE DATABASE INSURE_DB")

def run(sql, label=None):
    if label:
        print(f"\n=== {label} ===")
    cur.execute(sql)
    rows = cur.fetchall()
    desc = cur.description
    if desc:
        headers = [d[0] for d in desc]
        print('\t'.join(headers))
        for row in rows[:20]:
            print('\t'.join(str(x) for x in row))
    return rows

# STEP 1: Create backup
print("\n=== STEP 1: Create Backup ===")
cur.execute("USE SCHEMA MART")
cur.execute("""
CREATE TABLE IF NOT EXISTS MART_DISTRICT_INSURANCE_SUMMARY_BACKUP_20260412
AS SELECT * FROM MART_DISTRICT_INSURANCE_SUMMARY
""")
cur.execute("SELECT COUNT(*) FROM MART_DISTRICT_INSURANCE_SUMMARY_BACKUP_20260412")
cnt = cur.fetchone()[0]
print(f"Backup created with {cnt} rows")

# STEP 2: Check STG_ASSET_INCOME
print("\n=== STEP 2: Check STG_ASSET_INCOME columns ===")
try:
    run("""
    SELECT COLUMN_NAME, DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'STAGING' AND TABLE_NAME = 'STG_ASSET_INCOME'
    ORDER BY ORDINAL_POSITION
    """, "STG_ASSET_INCOME columns")
    run("SELECT * FROM INSURE_DB.STAGING.STG_ASSET_INCOME LIMIT 5", "STG_ASSET_INCOME sample")
except Exception as e:
    print(f"STG_ASSET_INCOME error: {e}")

# Check FACT_GU_ASSET_PROFILE
print("\n=== STEP 2b: Check FACT_GU_ASSET_PROFILE ===")
try:
    run("""
    SELECT COLUMN_NAME, DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'STAGING' AND TABLE_NAME = 'FACT_GU_ASSET_PROFILE'
    ORDER BY ORDINAL_POSITION
    """, "FACT_GU_ASSET_PROFILE columns")
    run("SELECT * FROM INSURE_DB.STAGING.FACT_GU_ASSET_PROFILE LIMIT 5", "FACT_GU_ASSET_PROFILE sample")
except Exception as e:
    print(f"FACT_GU_ASSET_PROFILE error: {e}")

# STEP 2c: List staging tables for reference
print("\n=== STEP 2c: List STAGING tables ===")
run("""
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'STAGING'
ORDER BY TABLE_NAME
""", "STAGING tables")

# STEP 3: GU_CODE_MAPPING
print("\n=== STEP 3: GU_CODE_MAPPING ===")
run("SELECT * FROM INSURE_DB.STAGING.GU_CODE_MAPPING ORDER BY GU_NAME", "GU_CODE_MAPPING")

# STEP 4: Diagnostic - per-GU income
print("\n=== STEP 4: Per-GU income diagnostic ===")
try:
    run("""
    SELECT
        g.GU_NAME,
        AVG(ai.AVERAGE_INCOME) AS district_avg_income
    FROM INSURE_DB.STAGING.STG_ASSET_INCOME ai
    LEFT JOIN INSURE_DB.STAGING.STG_DISTRICT_MASTER dm ON ai.DISTRICT_CODE = dm.DISTRICT_CODE
    LEFT JOIN INSURE_DB.STAGING.GU_CODE_MAPPING g ON LEFT(ai.DISTRICT_CODE::VARCHAR, 5) = g.GU_CODE
    GROUP BY g.GU_NAME
    ORDER BY district_avg_income DESC
    """, "Per-GU average income from STG_ASSET_INCOME")
except Exception as e:
    print(f"Per-GU income error: {e}")
    # Try FACT_GU_ASSET_PROFILE
    try:
        run("SELECT * FROM INSURE_DB.STAGING.FACT_GU_ASSET_PROFILE LIMIT 10", "FACT_GU_ASSET_PROFILE fallback")
    except Exception as e2:
        print(f"FACT_GU_ASSET_PROFILE error: {e2}")

conn.close()
print("\n=== Steps 1-4 complete ===")
