#!/usr/bin/env bash
# ============================================================
# package_submission.sh
# INSURE Hackathon 제출용 소스코드 zip 패키징 스크립트
# Team 까레이스키 | Snowflake Hackathon 2026
#
# 사용법:
#   bash scripts/package_submission.sh
#
# 결과물:
#   INSURE_submission_<날짜>.zip (프로젝트 루트에 생성)
# ============================================================

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATE_TAG=$(date +%Y%m%d_%H%M)
OUTPUT_FILE="${REPO_ROOT}/INSURE_submission_${DATE_TAG}.zip"

echo "============================================"
echo "  INSURE 제출 패키지 생성"
echo "  Team 까레이스키 | Snowflake Hackathon 2026"
echo "============================================"
echo ""
echo "[1/4] 저장소 루트: ${REPO_ROOT}"
echo "[2/4] 출력 파일:   ${OUTPUT_FILE}"
echo ""

cd "${REPO_ROOT}"

# ============================================================
# 포함 대상 (명시적으로 지정)
# ============================================================
INCLUDE=(
    "sql/"                          # SQL 파일 전체 (01~34번)
    "streamlit/"                    # Streamlit 앱
    "scripts/graph_rag_test.py"     # Graph RAG 테스트
    "scripts/graph_rag_visualize.py"
    "scripts/test_all.py"           # 전체 테스트
    "scripts/requirements.txt"      # 의존성
    "CLAUDE.md"                     # 프로젝트 문서
)

# ============================================================
# 제외 패턴
# ============================================================
EXCLUDE=(
    "__pycache__"
    "*.pyc"
    "*.pyo"
    ".git"
    ".env"
    "*.env"
    "secrets.toml"
    ".streamlit/secrets.toml"
    "INSURE_submission_*.zip"       # 이전 패키지 파일 제외
    "scripts/package_submission.sh" # 이 스크립트 자체 제외
)

# zip 제외 옵션 구성
EXCLUDE_ARGS=()
for pattern in "${EXCLUDE[@]}"; do
    EXCLUDE_ARGS+=("--exclude=*${pattern}*")
done

# ============================================================
# zip 생성
# ============================================================
echo "[3/4] 패키징 중..."

zip -r "${OUTPUT_FILE}" "${INCLUDE[@]}" "${EXCLUDE_ARGS[@]}" 2>/dev/null || {
    # macOS/Linux zip 버전 차이 대응
    zip -r "${OUTPUT_FILE}" "${INCLUDE[@]}"
    for pattern in "${EXCLUDE[@]}"; do
        zip -d "${OUTPUT_FILE}" "*${pattern}*" 2>/dev/null || true
    done
}

# ============================================================
# 결과 확인
# ============================================================
echo ""
echo "[4/4] 패키지 내용 확인:"
echo "----------------------------------------------"
zip -sf "${OUTPUT_FILE}" | head -60
echo "----------------------------------------------"
echo ""

FILE_SIZE=$(du -sh "${OUTPUT_FILE}" | cut -f1)
FILE_COUNT=$(zip -sf "${OUTPUT_FILE}" | wc -l)

echo "완료!"
echo "  파일: ${OUTPUT_FILE}"
echo "  크기: ${FILE_SIZE}"
echo "  파일 수: ~${FILE_COUNT}개"
echo ""
echo "제출 체크리스트:"
echo "  [ ] sql/ 폴더 안에 01~34번 SQL 파일 모두 포함됐는지 확인"
echo "  [ ] streamlit/ 폴더 안에 streamlit_app.py 포함됐는지 확인"
echo "  [ ] .env, secrets.toml 파일이 포함되지 않았는지 확인"
echo "  [ ] zip 파일을 Google Drive 등에 업로드 후 공유 링크 생성"
echo ""
echo "과제 제출 Forms에 이 zip의 다운로드 링크를 붙여넣으세요."
