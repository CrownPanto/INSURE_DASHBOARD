"""
공공데이터포털 - 우체국보험 상품별 약관 정보 수집기.

데이터셋: https://www.data.go.kr/data/15042150/openapi.do
엔드포인트: http://apis.data.go.kr/1721301/KpostInsuranceTermsView/insuranceTerms

응답: 상품명, 적용 시작/종료일, 약관 link URL
2단계 처리:
  (1) API에서 메타 + 약관 URL 목록 받기
  (2) 각 URL을 polite하게 GET해 PDF 저장
"""
from __future__ import annotations

import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import load_env  # noqa: E402
from crawl_insurance_terms import (  # noqa: E402
    OUT_DIR,
    HEADERS,
    download_doc,
    load_seen,
    log,
    polite_sleep,
)

ENDPOINT = "http://apis.data.go.kr/1721301/KpostInsuranceTermsView/insuranceTerms"


def fetch_page(key: str, page: int, rows: int = 100) -> str | None:
    polite_sleep()
    params = {
        "serviceKey": key,
        "pageNo": page,
        "numOfRows": rows,
        # 일부 data.go.kr API는 type 미지정 시 XML 디폴트
    }
    try:
        r = requests.get(ENDPOINT, params=params, headers=HEADERS, timeout=30)
    except Exception as e:
        log(f"우체국 API 요청 실패: {e}")
        return None
    if r.status_code != 200:
        log(f"우체국 API HTTP {r.status_code}: {r.text[:200]}")
        return None
    return r.text


def parse_items(xml_text: str) -> list[dict]:
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as e:
        log(f"XML 파싱 실패: {e}; head={xml_text[:200]}")
        return []
    items = []
    for it in root.iter("item"):
        rec = {child.tag: (child.text or "").strip() for child in it}
        items.append(rec)
    return items


def main() -> int:
    load_env()
    key = os.environ.get("DATA_GO_KR_KEY")
    if not key:
        log("DATA_GO_KR_KEY 미설정 (.env 확인)")
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    load_seen()

    all_items: list[dict] = []
    for page in range(1, 11):  # 최대 1000건
        log(f"우체국 약관 API page={page}")
        body = fetch_page(key, page)
        if body is None:
            break
        items = parse_items(body)
        if not items:
            log(f"page={page} 빈 응답 → 종료")
            break
        all_items.extend(items)
        if len(items) < 100:
            break
    log(f"메타 총 {len(all_items)}건")

    n = 0
    for it in all_items:
        # 컬럼명이 문서마다 다를 수 있어 휴리스틱
        link = (
            it.get("linkUrl")
            or it.get("link")
            or it.get("termsUrl")
            or it.get("url")
            or ""
        )
        product = (
            it.get("prdNm")
            or it.get("productName")
            or it.get("name")
            or it.get("title")
            or "우체국보험상품"
        )
        date = (
            it.get("aplyEndDt")
            or it.get("aplyStrtDt")
            or it.get("applyStartDate")
            or ""
        )
        if not link.startswith("http"):
            continue
        ok = download_doc(
            link,
            company="우체국보험",
            insurance_type="생명",  # 우체국보험 상품 대부분 생명/저축 계열
            product_name=product,
            document_date=date,
        )
        if ok:
            n += 1
    log(f"=== 우체국 약관 수집 완료: 신규 {n}건 ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
