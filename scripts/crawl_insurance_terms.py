"""
Korean insurance terms (약관) crawler for RAG dataset.

Sources (priority order):
  1) 금감원 파인       - https://fine.fss.or.kr
  2) 생보협회/손보협회 - https://www.klia.or.kr , https://www.knia.or.kr
  3) 보험사 공시실     - 삼성생명, 현대해상, DB손해보험 ...

Output:
  data/insurance_terms/{insurance_type}/{company}/<file>.pdf
  data/insurance_terms/metadata.jsonl

Rules:
  - robots.txt 준수
  - 요청 간 2~3초 sleep
  - 동일 URL 재다운로드 스킵
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import time
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable
from urllib.parse import urljoin, urlparse
from urllib.robotparser import RobotFileParser

import requests
from bs4 import BeautifulSoup

# ─────────────────────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "data" / "insurance_terms"
META_PATH = OUT_DIR / "metadata.jsonl"
LOG_PATH = OUT_DIR / "crawl.log"

REQUEST_DELAY = 2.5  # seconds between requests (per spec: 2~3s)
TIMEOUT = 30
HEADERS = {
    "User-Agent": (
        "INSURE-RAG-Crawler/0.1 (research; contact: insure-dashboard@example.local) "
        "python-requests"
    ),
    "Accept-Language": "ko,en;q=0.8",
}

# Robots cache
_robots_cache: dict[str, RobotFileParser | None] = {}
# Already-downloaded URL cache (loaded from existing metadata.jsonl)
_seen_urls: set[str] = set()


# ─────────────────────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────────────────────
def log(msg: str) -> None:
    line = f"[{datetime.now().strftime('%H:%M:%S')}] {msg}"
    print(line, flush=True)
    try:
        with LOG_PATH.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except FileNotFoundError:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a", encoding="utf-8") as f:
            f.write(line + "\n")


# ─────────────────────────────────────────────────────────────────────────────
# robots.txt
# ─────────────────────────────────────────────────────────────────────────────
def can_fetch(url: str) -> bool:
    parsed = urlparse(url)
    base = f"{parsed.scheme}://{parsed.netloc}"
    if base not in _robots_cache:
        rp = RobotFileParser()
        try:
            rp.set_url(urljoin(base, "/robots.txt"))
            rp.read()
            _robots_cache[base] = rp
        except Exception as e:
            log(f"robots.txt 읽기 실패 ({base}): {e} -> 보수적으로 차단")
            _robots_cache[base] = None
    rp = _robots_cache[base]
    if rp is None:
        return False
    try:
        return rp.can_fetch(HEADERS["User-Agent"], url)
    except Exception:
        return False


# ─────────────────────────────────────────────────────────────────────────────
# HTTP helpers
# ─────────────────────────────────────────────────────────────────────────────
_last_request_ts = 0.0


def polite_sleep() -> None:
    global _last_request_ts
    now = time.time()
    wait = REQUEST_DELAY - (now - _last_request_ts)
    if wait > 0:
        time.sleep(wait)
    _last_request_ts = time.time()


def http_get(url: str, *, stream: bool = False) -> requests.Response | None:
    if not can_fetch(url):
        log(f"robots 차단: {url}")
        return None
    polite_sleep()
    try:
        resp = requests.get(url, headers=HEADERS, timeout=TIMEOUT, stream=stream)
        if resp.status_code != 200:
            log(f"HTTP {resp.status_code}: {url}")
            return None
        return resp
    except Exception as e:
        log(f"요청 실패 {url}: {e}")
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Metadata
# ─────────────────────────────────────────────────────────────────────────────
@dataclass
class DocMeta:
    source_url: str
    insurance_company: str
    insurance_type: str  # 생명/손해/실손/연금/동산
    product_name: str
    document_date: str
    file_format: str
    crawl_date: str
    local_path: str = ""


def load_seen() -> None:
    if META_PATH.exists():
        with META_PATH.open(encoding="utf-8") as f:
            for line in f:
                try:
                    _seen_urls.add(json.loads(line)["source_url"])
                except Exception:
                    pass
    log(f"기존 수집 문서: {len(_seen_urls)}건")


def append_meta(meta: DocMeta) -> None:
    META_PATH.parent.mkdir(parents=True, exist_ok=True)
    with META_PATH.open("a", encoding="utf-8") as f:
        f.write(json.dumps(asdict(meta), ensure_ascii=False) + "\n")


# ─────────────────────────────────────────────────────────────────────────────
# Download
# ─────────────────────────────────────────────────────────────────────────────
SAFE_NAME_RE = re.compile(r"[^\w\-.()가-힣]+")


def safe_filename(name: str, fallback_ext: str = ".pdf") -> str:
    name = SAFE_NAME_RE.sub("_", name).strip("._")
    if not name:
        name = "document" + fallback_ext
    if not os.path.splitext(name)[1]:
        name += fallback_ext
    return name[:180]


def download_doc(
    url: str,
    *,
    company: str,
    insurance_type: str,
    product_name: str,
    document_date: str = "",
) -> bool:
    if url in _seen_urls:
        return False
    resp = http_get(url, stream=True)
    if resp is None:
        return False

    ctype = resp.headers.get("Content-Type", "").lower()
    if "pdf" in ctype:
        ext = ".pdf"
        fmt = "PDF"
    elif "html" in ctype:
        ext = ".html"
        fmt = "HTML"
    elif "hwp" in ctype or "haansoft" in ctype:
        ext = ".hwp"
        fmt = "HWP"
    else:
        ext = os.path.splitext(urlparse(url).path)[1] or ".bin"
        fmt = ext.lstrip(".").upper() or "BIN"

    company_dir = OUT_DIR / insurance_type / safe_filename(company, "")
    company_dir.mkdir(parents=True, exist_ok=True)

    base = safe_filename(product_name or os.path.basename(urlparse(url).path), ext)
    if not base.lower().endswith(ext):
        base += ext
    digest = hashlib.md5(url.encode()).hexdigest()[:6]
    fname = f"{os.path.splitext(base)[0]}_{digest}{ext}"
    fpath = company_dir / fname

    try:
        with fpath.open("wb") as f:
            for chunk in resp.iter_content(8192):
                if chunk:
                    f.write(chunk)
    except Exception as e:
        log(f"저장 실패 {url}: {e}")
        return False

    meta = DocMeta(
        source_url=url,
        insurance_company=company,
        insurance_type=insurance_type,
        product_name=product_name,
        document_date=document_date,
        file_format=fmt,
        crawl_date=datetime.now(timezone.utc).isoformat(timespec="seconds"),
        local_path=str(fpath.relative_to(ROOT)),
    )
    append_meta(meta)
    _seen_urls.add(url)
    log(f"OK [{insurance_type}/{company}] {fname}")
    return True


# ─────────────────────────────────────────────────────────────────────────────
# Source-specific scrapers
#
# 주의: 한국 보험 사이트들은 대부분 동적/세션 기반이라 정적 크롤로 접근 가능한
# 표면만 훑습니다. 막히는 사이트는 polite하게 스킵하고 다음 소스로 폴백합니다.
# ─────────────────────────────────────────────────────────────────────────────

def discover_pdf_links(html_url: str) -> list[tuple[str, str]]:
    """Return list of (absolute_url, link_text) for PDF/HWP links on a page."""
    resp = http_get(html_url)
    if resp is None:
        return []
    soup = BeautifulSoup(resp.text, "lxml")
    out: list[tuple[str, str]] = []
    for a in soup.find_all("a", href=True):
        href = a["href"]
        low = href.lower()
        if any(low.endswith(ext) or ext + "?" in low for ext in (".pdf", ".hwp", ".hwpx")):
            absu = urljoin(html_url, href)
            text = (a.get_text(strip=True) or os.path.basename(absu))[:160]
            out.append((absu, text))
    return out


def crawl_fss_fine() -> int:
    """금감원 파인 - 표준약관 코너. 정적 페이지에서 노출되는 PDF만 수집."""
    log("=== [1] 금감원 파인 (fine.fss.or.kr) ===")
    seeds = [
        "https://fine.fss.or.kr/fine/fnctr/insStdrd/list.do?menuNo=900021",  # 표준약관
        "https://fine.fss.or.kr/fine/fnctr/insStdrd/list.do?menuNo=900022",
        "https://fine.fss.or.kr/fine/fnctr/insStdrd/list.do?menuNo=900023",
    ]
    n = 0
    for seed in seeds:
        for url, text in discover_pdf_links(seed):
            itype = guess_type_from_text(text)
            if download_doc(
                url,
                company="금융감독원",
                insurance_type=itype,
                product_name=text,
            ):
                n += 1
    log(f"파인 수집: {n}건")
    return n


def crawl_klia() -> int:
    """생명보험협회 - 공시실 표준약관."""
    log("=== [2a] 생명보험협회 (klia.or.kr) ===")
    seeds = [
        "https://www.klia.or.kr/consumer/stdContract/stdContractList.do",
        "https://www.klia.or.kr/consumer/stdContract/list.do",
    ]
    n = 0
    for seed in seeds:
        for url, text in discover_pdf_links(seed):
            if download_doc(
                url,
                company="생명보험협회",
                insurance_type=guess_type_from_text(text, default="생명"),
                product_name=text,
            ):
                n += 1
    log(f"생보협회 수집: {n}건")
    return n


def crawl_knia() -> int:
    """손해보험협회 - 공시실 표준약관 (동산/화재/재산종합 우선)."""
    log("=== [2b] 손해보험협회 (knia.or.kr) ===")
    seeds = [
        "https://www.knia.or.kr/consumer/insLaw/stdInsTerms",
        "https://www.knia.or.kr/consumer/insLaw/insTermsList",
        "https://www.knia.or.kr/consumer/disclosure/discList",
    ]
    n = 0
    for seed in seeds:
        for url, text in discover_pdf_links(seed):
            if download_doc(
                url,
                company="손해보험협회",
                insurance_type=guess_type_from_text(text, default="손해"),
                product_name=text,
            ):
                n += 1
    log(f"손보협회 수집: {n}건")
    return n


def crawl_insurers() -> int:
    """보험사 공시실 - 정적으로 접근 가능한 표면 페이지만."""
    log("=== [3] 보험사 공시실 ===")
    targets = [
        ("삼성생명", "생명", "https://www.samsunglife.com/individual/disclosure/policyTerms"),
        ("한화생명", "생명", "https://www.hanwhalife.com/main/disclosure/terms/MDDisclosureTermsView.do"),
        ("교보생명", "생명", "https://www.kyobo.co.kr/dgt/disclosure/terms.jsp"),
        ("현대해상", "손해", "https://www.hi.co.kr/serviceAction.do?menuId=000591"),
        ("DB손해보험", "손해", "https://www.idbins.com/disclosure/terms.do"),
        ("KB손해보험", "손해", "https://www.kbinsure.co.kr/CG201010001.ec"),
        ("메리츠화재", "손해", "https://www.meritzfire.com/disclosure/terms.do"),
        ("삼성화재", "손해", "https://www.samsungfire.com/customer/Customer400_010_001.html"),
    ]
    n = 0
    for company, itype, url in targets:
        for purl, text in discover_pdf_links(url):
            sub_type = guess_type_from_text(text, default=itype)
            if download_doc(
                purl,
                company=company,
                insurance_type=sub_type,
                product_name=text,
            ):
                n += 1
    log(f"보험사 수집: {n}건")
    return n


# ─────────────────────────────────────────────────────────────────────────────
# Type inference from link text
# ─────────────────────────────────────────────────────────────────────────────
TYPE_KEYWORDS = [
    ("실손", "실손"),
    ("의료", "실손"),
    ("연금", "연금"),
    ("저축", "연금"),
    ("종신", "생명"),
    ("정기보험", "생명"),
    ("변액", "생명"),
    ("생명", "생명"),
    ("동산", "동산"),
    ("재산종합", "동산"),
    ("패키지", "동산"),
    ("화재", "동산"),
    ("자동차", "손해"),
    ("배상책임", "손해"),
    ("여행자", "손해"),
    ("상해", "손해"),
    ("손해", "손해"),
]


def guess_type_from_text(text: str, default: str = "손해") -> str:
    for kw, t in TYPE_KEYWORDS:
        if kw in text:
            return t
    return default


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    log(f"출력 경로: {OUT_DIR}")
    load_seen()

    total = 0
    total += crawl_fss_fine()
    total += crawl_knia()  # 손보 우선 (동산 도메인)
    total += crawl_klia()
    total += crawl_insurers()

    log(f"=== 완료. 신규 수집 총 {total}건. 누적 {len(_seen_urls)}건 ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
