"""
Register manually uploaded PDFs into the metadata.jsonl index and move them
under the canonical {insurance_type}/{company}/ layout.

source_url is set to local://<original_filename> so dedup still works.
"""
from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from crawl_insurance_terms import (  # noqa: E402
    DocMeta,
    OUT_DIR,
    append_meta,
    load_seen,
    log,
    safe_filename,
    _seen_urls,
)

# Explicit mapping. Type taxonomy: 생명/손해/실손/연금/동산.
# 주택/아파트 화재·도난 → 동산보험 도메인.
LOCAL_FILES = [
    # filename, company, type, product_name
    ("kb_주택.pdf",                      "KB손해보험", "동산", "주택종합보험 (주택)"),
    ("kb_주택종합.pdf",                  "KB손해보험", "동산", "주택종합보험"),
    ("kb_아파트.pdf",                    "KB손해보험", "동산", "아파트종합보험"),
    ("kb_레저.pdf",                      "KB손해보험", "손해", "레저종합보험"),
    ("kb_시티즌자전거.pdf",              "KB손해보험", "손해", "시티즌자전거보험"),
    ("kb_드론배상책임.pdf",              "KB손해보험", "손해", "드론배상책임보험"),
    ("kb_휠체어및스쿠터배상책임보험.pdf", "KB손해보험", "손해", "휠체어및스쿠터배상책임보험"),
    ("meritz_개인용자동차보험.pdf",       "메리츠화재", "손해", "개인용자동차보험"),
    ("meritz_종합보험.pdf",               "메리츠화재", "동산", "주택화재 종합보험"),
    ("meritz_운전자상해종합보험.pdf",     "메리츠화재", "손해", "운전자상해종합보험"),
]


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    load_seen()
    n = 0
    for fname, company, itype, product in LOCAL_FILES:
        src = OUT_DIR / fname
        if not src.exists():
            log(f"누락(스킵): {fname}")
            continue
        source_url = f"local://{fname}"
        if source_url in _seen_urls:
            log(f"이미 등록됨: {fname}")
            continue
        dst_dir = OUT_DIR / itype / safe_filename(company, "")
        dst_dir.mkdir(parents=True, exist_ok=True)
        dst = dst_dir / safe_filename(f"{product}.pdf")
        src.rename(dst)
        meta = DocMeta(
            source_url=source_url,
            insurance_company=company,
            insurance_type=itype,
            product_name=product,
            document_date="",
            file_format="PDF",
            crawl_date=datetime.now(timezone.utc).isoformat(timespec="seconds"),
            local_path=str(dst.relative_to(OUT_DIR.parent.parent)),
        )
        append_meta(meta)
        _seen_urls.add(source_url)
        log(f"등록 [{itype}/{company}] {dst.name}")
        n += 1
    log(f"=== 로컬 등록 완료: {n}건 ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
