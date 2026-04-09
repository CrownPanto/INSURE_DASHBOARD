"""
보험 약관 PDF → 정제된 JSON 블록 추출.

사용법:
    python3 scripts/extract_insurance_terms.py

입력:  data/insurance_terms/**/*.pdf
출력:  data/processed/insurance_terms/**/<파일명>.json
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

import pdfplumber

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "data" / "insurance_terms"
OUT_DIR = ROOT / "data" / "processed" / "insurance_terms"

# ---------- 정규식 ----------
RE_CHAPTER = re.compile(r"^제\s*([0-9]+)\s*([장관])\s*(.*)$")
RE_ARTICLE = re.compile(r"^제\s*([0-9]+)\s*조(?:\s*\(([^)]*)\))?\s*(.*)$")
RE_CLAUSE_CIRCLED = re.compile(r"[①-⑳]")
RE_APPENDIX = re.compile(r"^(별표|부표|별첨)\s*[0-9]*")
RE_DEFINITION_HINT = re.compile(r"용어의?\s*정의|정의|용어")
# 목차 엔트리: "제3조 ... ············· 2" 같은 점선+페이지번호로 끝나는 라인
RE_TOC_ENTRY = re.compile(r"[·.\u2026]{3,}\s*\d{1,4}\s*$")
# 약관 섹션 구분 (라인 전체가 섹션명이어야 함)
RE_SECTION = re.compile(r"^.{0,30}?(보통약관|특별약관|추가약관|특약)$")

# OCR 보정 매핑 (조/장 번호에 자주 끼는 글자)
OCR_DIGIT_FIX = str.maketrans({"l": "1", "I": "1", "O": "0", "o": "0", "S": "5"})


def fix_ocr_numbers(text: str) -> str:
    """'제l조' → '제1조' 등 조/장/항 번호 인접 OCR 오류 교정."""
    def _fix(m: re.Match) -> str:
        prefix, body, suffix = m.group(1), m.group(2), m.group(3)
        return prefix + body.translate(OCR_DIGIT_FIX) + suffix
    return re.sub(r"(제\s*)([0-9lIOoS]+)(\s*[조장항호])", _fix, text)


def normalize_whitespace(text: str) -> str:
    text = text.replace("\u3000", " ").replace("\xa0", " ")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


# ---------- 페이지 추출 + 머리/바닥글 제거 ----------
def extract_pages(pdf_path: Path) -> list[list[str]]:
    pages: list[list[str]] = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            txt = page.extract_text() or ""
            lines = [ln.strip() for ln in txt.splitlines() if ln.strip()]
            pages.append(lines)
    return pages


def strip_headers_footers(pages: list[list[str]]) -> list[list[str]]:
    """여러 페이지에 반복되는 상/하단 라인을 머리글/바닥글로 간주하고 제거."""
    if len(pages) < 3:
        return pages
    n = len(pages)
    top = Counter()
    bot = Counter()
    for p in pages:
        if not p:
            continue
        for ln in p[:2]:
            top[ln] += 1
        for ln in p[-2:]:
            bot[ln] += 1
    threshold = max(3, n // 2)
    repeated = {ln for ln, c in top.items() if c >= threshold}
    repeated |= {ln for ln, c in bot.items() if c >= threshold}

    cleaned = []
    for p in pages:
        kept = []
        for ln in p:
            if ln in repeated:
                continue
            # 페이지 번호만 있는 라인 제거
            if re.fullmatch(r"-?\s*\d{1,4}\s*-?", ln):
                continue
            kept.append(ln)
        cleaned.append(kept)
    return cleaned


# ---------- 표 추출 → markdown ----------
def extract_tables_markdown(pdf_path: Path) -> list[dict]:
    out = []
    with pdfplumber.open(pdf_path) as pdf:
        for i, page in enumerate(pdf.pages, start=1):
            for tbl in page.extract_tables() or []:
                if not tbl or not any(any(c for c in row) for row in tbl):
                    continue
                md = table_to_markdown(tbl)
                out.append({"page": i, "markdown": md})
    return out


def table_to_markdown(tbl: list[list[str | None]]) -> str:
    rows = [[(c or "").replace("\n", " ").strip() for c in row] for row in tbl]
    width = max(len(r) for r in rows)
    rows = [r + [""] * (width - len(r)) for r in rows]
    header = rows[0]
    body = rows[1:] if len(rows) > 1 else []
    md = "| " + " | ".join(header) + " |\n"
    md += "| " + " | ".join(["---"] * width) + " |\n"
    for r in body:
        md += "| " + " | ".join(r) + " |\n"
    return md.strip()


# ---------- 구조 태깅 ----------
def tag_blocks(lines: list[str], tables: list[dict]) -> list[dict]:
    blocks: list[dict] = []
    current_chapter: str | None = None
    current_section: str | None = None
    current_article: dict | None = None
    in_appendix = False
    in_definition = False

    def flush_article():
        nonlocal current_article
        if current_article is not None:
            current_article["content"] = normalize_whitespace(current_article["content"])
            blocks.append(current_article)
            current_article = None

    # 제목 후보: 첫 비어있지 않은 라인 중 '제 N 장/조'가 아닌 것
    title_set = False

    for raw in lines:
        ln = fix_ocr_numbers(raw).strip()
        if not ln:
            continue

        # 목차(ToC) 엔트리 드롭: "제N조 ... ········ 12" 같은 라인
        if RE_TOC_ENTRY.search(ln):
            continue

        # 섹션 헤더 (보통약관/특별약관/추가약관/특약) — 조항 흐름 초기화
        m_sec = RE_SECTION.match(ln)
        if m_sec and len(ln) <= 30 and not RE_ARTICLE.match(ln) and not RE_CHAPTER.match(ln):
            flush_article()
            current_section = ln
            current_chapter = None
            in_definition = False
            in_appendix = False
            blocks.append({"block_type": "SECTION", "section": ln, "content": ""})
            continue

        if not title_set and not RE_CHAPTER.match(ln) and not RE_ARTICLE.match(ln):
            blocks.append({"block_type": "TITLE", "content": ln})
            title_set = True
            continue

        if RE_APPENDIX.match(ln):
            flush_article()
            in_appendix = True
            blocks.append({"block_type": "APPENDIX", "title": ln, "content": ""})
            continue

        if in_appendix:
            if blocks and blocks[-1].get("block_type") == "APPENDIX":
                blocks[-1]["content"] += ("\n" if blocks[-1]["content"] else "") + ln
                continue
            in_appendix = False  # appendix 블록이 더 이상 말단이 아니면 모드 종료

        m = RE_CHAPTER.match(ln)
        if m:
            flush_article()
            unit = m.group(2)  # '장' or '관'
            current_chapter = f"제{m.group(1)}{unit} {m.group(3)}".strip()
            blocks.append({
                "block_type": "CHAPTER",
                "chapter": current_chapter,
                "section": current_section,
            })
            in_definition = bool(RE_DEFINITION_HINT.search(m.group(3) or ""))
            continue

        m = RE_ARTICLE.match(ln)
        if m:
            flush_article()
            num = f"제{m.group(1)}조"
            title = (m.group(2) or "").strip()
            rest = (m.group(3) or "").strip()
            btype = "DEFINITION" if (in_definition or RE_DEFINITION_HINT.search(title)) else "ARTICLE"
            current_article = {
                "block_type": btype,
                "article_number": num,
                "article_title": title,
                "content": rest,
                "parent_chapter": current_chapter,
                "section": current_section,
            }
            continue

        if current_article is not None:
            current_article["content"] += "\n" + ln
        else:
            # 장/조 이전의 서문
            blocks.append({"block_type": "PREAMBLE", "content": ln})

    flush_article()

    # 표 블록 부착
    for t in tables:
        blocks.append({"block_type": "TABLE", "page": t["page"], "content": t["markdown"]})

    return blocks


# ---------- 메인 ----------
def process_pdf(pdf_path: Path) -> dict:
    pages = extract_pages(pdf_path)
    pages = strip_headers_footers(pages)
    flat_lines = [ln for p in pages for ln in p]
    tables = extract_tables_markdown(pdf_path)
    blocks = tag_blocks(flat_lines, tables)
    rel = pdf_path.relative_to(SRC_DIR)
    return {
        "source_file": str(rel),
        "category": rel.parts[0] if len(rel.parts) > 1 else None,
        "insurer": rel.parts[1] if len(rel.parts) > 2 else None,
        "product": pdf_path.stem,
        "num_pages": len(pages),
        "num_blocks": len(blocks),
        "blocks": blocks,
    }


def main() -> int:
    pdfs = sorted(SRC_DIR.rglob("*.pdf"))
    if not pdfs:
        print(f"PDF 없음: {SRC_DIR}", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"총 {len(pdfs)}개 PDF 처리 시작")
    for pdf in pdfs:
        rel = pdf.relative_to(SRC_DIR)
        out_path = OUT_DIR / rel.with_suffix(".json")
        out_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            data = process_pdf(pdf)
        except Exception as e:
            print(f"  ✗ {rel}: {e}", file=sys.stderr)
            continue
        out_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"  ✓ {rel} → {out_path.relative_to(ROOT)} ({data['num_blocks']} blocks)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
