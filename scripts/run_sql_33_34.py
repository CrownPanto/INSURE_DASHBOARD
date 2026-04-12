"""
sql/33, sql/34 Snowflake 자동 실행 스크립트
실행: conda run -n INSURE_DASHBOARD python scripts/run_sql_33_34.py
"""
import re
import sys
import io
# Windows cp949 인코딩 문제 방지
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
import snowflake.connector

# ── credentials ──────────────────────────────────────────────
CREDS = dict(
    account   = "xkrheif-fw39017",
    user      = "LIKEWISE95",
    password  = "Cnrrn1187cnrrn1187*",
    role      = "ACCOUNTADMIN",
    warehouse = "COMPUTE_WH",
    database  = "INSURE_DB",
    schema    = "ANALYTICS",
)

SQL_FILES = [
    ("sql/33_CORTEX_AGENT_UNIFIED.sql", "SP 재생성 (입력 검증 v1.1)"),
    ("sql/34_DATA_SHARING.sql",          "Data Sharing 설정 (ACCOUNTADMIN)"),
]


def split_statements(sql_text: str) -> list[str]:
    """
    SQL 파일을 세미콜론 기준으로 분리.
    달러-따옴표 블록($$...$$) 안의 세미콜론은 무시.
    주석 전용 라인 및 빈 구문은 제거.
    """
    statements = []
    current    = []
    in_dollar  = False

    for line in sql_text.splitlines():
        stripped = line.strip()
        # 단일 라인 주석 (전체가 --)
        if stripped.startswith("--"):
            current.append(line)
            continue

        # $$ 토글
        dollar_count = line.count("$$")
        if dollar_count % 2 == 1:
            in_dollar = not in_dollar

        current.append(line)

        # $$ 블록 밖 세미콜론 → 구문 종료
        if not in_dollar and ";" in stripped:
            stmt = "\n".join(current).strip()
            # 주석만 있는 블록 제거
            code_only = re.sub(r"--[^\n]*", "", stmt).strip()
            if code_only:
                statements.append(stmt)
            current = []

    # 마지막 미종료 구문
    if current:
        stmt = "\n".join(current).strip()
        code_only = re.sub(r"--[^\n]*", "", stmt).strip()
        if code_only:
            statements.append(stmt)

    return statements


def run_file(cur, filepath: str, label: str):
    print(f"\n{'='*60}")
    print(f"&gt;&gt; {label}")
    print(f"  파일: {filepath}")
    print("="*60)

    with open(filepath, encoding="utf-8") as f:
        sql_text = f.read()

    stmts = split_statements(sql_text)
    ok = err = 0

    for i, stmt in enumerate(stmts, 1):
        # 첫 줄만 미리보기
        preview = stmt.split("\n")[0][:80]
        try:
            cur.execute(stmt)
            rows = cur.fetchall()
            print(f"  [{i:02d}] [OK] {preview}")
            if rows:
                for r in rows[:3]:
                    print(f"       → {r}")
            ok += 1
        except Exception as e:
            err_msg = str(e).split("\n")[0][:120]
            print(f"  [{i:02d}] [ERR] {preview}")
            print(f"       오류: {err_msg}")
            err += 1

    print(f"\n  결과: 성공 {ok} / 실패 {err} / 전체 {ok+err}")
    return err == 0


def main():
    base = "C:/Users/andyp/Desktop/고려대/insure_project_kim/INSURE_DASHBOARD"

    print("Snowflake 연결 중...")
    conn = snowflake.connector.connect(**CREDS)
    cur  = conn.cursor()
    print(f"[OK] 연결 성공 — account: {CREDS['account']} | role: {CREDS['role']}")

    all_ok = True
    for filename, label in SQL_FILES:
        filepath = f"{base}/{filename}"
        success  = run_file(cur, filepath, label)
        if not success:
            all_ok = False

    cur.close()
    conn.close()

    print(f"\n{'='*60}")
    if all_ok:
        print("[DONE] 모든 SQL 실행 완료!")
    else:
        print("[WARN]  일부 구문에서 오류 발생. 위 로그를 확인하세요.")
    print("="*60)
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
