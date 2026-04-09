"""
금감원 OpenAPI - 분야별 감독제도 (보험 분야) 수집기.

엔드포인트:
  https://www.fss.or.kr/fss/kr/openApi/api/fealmMng.jsp
파라미터:
  apiType=json | xml
  startDate=YYYYMMDD
  endDate=YYYYMMDD
  authKey=<FSS_API_KEY>

이 API는 약관 PDF가 아니라 감독제도 변경 메타데이터를 반환합니다.
보험 도메인 RAG 보강용으로 'fss_supervisory' 카테고리에 저장합니다.
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import ROOT, load_env  # noqa: E402
from crawl_insurance_terms import (  # noqa: E402
    DocMeta,
    OUT_DIR,
    append_meta,
    load_seen,
    log,
    polite_sleep,
    HEADERS,
    _seen_urls,
)

ENDPOINT = "https://www.fss.or.kr/fss/kr/openApi/api/fealmMng.jsp"
RAW_DIR = OUT_DIR / "감독제도" / "금융감독원"


def fetch(start: str, end: str, key: str) -> dict | None:
    polite_sleep()
    params = {"apiType": "json", "startDate": start, "endDate": end, "authKey": key}
    try:
        r = requests.get(ENDPOINT, params=params, headers=HEADERS, timeout=30)
    except Exception as e:
        log(f"FSS API 요청 실패: {e}")
        return None
    if r.status_code != 200:
        log(f"FSS API HTTP {r.status_code}")
        return None
    try:
        return r.json()
    except Exception:
        # 일부 응답이 JSON 헤더 없이 평문으로 떨어지는 경우 대비
        try:
            return json.loads(r.text)
        except Exception as e:
            log(f"JSON 파싱 실패: {e}; head={r.text[:200]}")
            return None


def main() -> int:
    load_env()
    key = os.environ.get("FSS_API_KEY")
    if not key:
        log("FSS_API_KEY 미설정 (.env 확인)")
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    load_seen()

    today = datetime.now()
    start = (today - timedelta(days=365 * 5)).strftime("%Y%m%d")  # 최근 5년
    end = today.strftime("%Y%m%d")

    log(f"FSS fealmMng 호출 {start} ~ {end}")
    data = fetch(start, end, key)
    if data is None:
        return 2

    raw_path = RAW_DIR / f"fealmMng_{start}_{end}.json"
    raw_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"원본 저장: {raw_path.relative_to(ROOT)}")

    # 응답 구조: {"result": {...}, "list": [{...}, ...]} 형태로 추정.
    # 키 이름이 변할 수 있으니 list 컨테이너를 휴리스틱하게 추출.
    items: list[dict] = []
    if isinstance(data, dict):
        for v in data.values():
            if isinstance(v, list) and v and isinstance(v[0], dict):
                items = v
                break
            if isinstance(v, dict):
                for vv in v.values():
                    if isinstance(vv, list) and vv and isinstance(vv[0], dict):
                        items = vv
                        break

    insurance_items = [
        it for it in items
        if any("보험" in str(val) for val in it.values())
    ]
    log(f"전체 항목 {len(items)}건 / 보험 관련 {len(insurance_items)}건")

    n = 0
    for it in insurance_items:
        # 항목별 식별자 (없으면 해시)
        ident = (
            it.get("seqno")
            or it.get("seqNo")
            or it.get("id")
            or str(abs(hash(json.dumps(it, sort_keys=True, ensure_ascii=False))))[:10]
        )
        source_url = f"fss-openapi://fealmMng/{ident}"
        if source_url in _seen_urls:
            continue
        item_path = RAW_DIR / f"item_{ident}.json"
        item_path.write_text(json.dumps(it, ensure_ascii=False, indent=2), encoding="utf-8")
        title = (
            it.get("title")
            or it.get("subject")
            or it.get("ttl")
            or it.get("name")
            or "감독제도 항목"
        )
        date = it.get("regDate") or it.get("date") or it.get("publishDate") or ""
        meta = DocMeta(
            source_url=source_url,
            insurance_company="금융감독원",
            insurance_type="감독제도",
            product_name=str(title)[:200],
            document_date=str(date),
            file_format="JSON",
            crawl_date=datetime.now(timezone.utc).isoformat(timespec="seconds"),
            local_path=str(item_path.relative_to(OUT_DIR.parent.parent)),
        )
        append_meta(meta)
        _seen_urls.add(source_url)
        n += 1
    log(f"=== FSS OpenAPI 수집 완료: 신규 {n}건 ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
