"""
보험 약관 JSON → RAG 청크(JSONL) 생성.

규칙:
- 기본 단위: 조(條) 1개 = 청크 1개
- < MIN_TOKENS → 같은 section 내 인접 조와 병합
- > MAX_TOKENS → 항(項, ①②③…) 단위로 분리
- prefix: "[{insurer} / {product} / {chapter or section}] {article_num} {title}"
- chunk_id: "{insurer}_{product}_{section_idx}_{article_num}[_p{part}]"
- category == "동산" → domain_priority: "high"

토큰 근사: 한국어 1 토큰 ≈ 2.5자 기준 (MIN 200 tok ≈ 500자, MAX 600 tok ≈ 1500자)
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IN_DIR = ROOT / "data" / "processed" / "insurance_terms"
OUT_DIR = ROOT / "data" / "processed" / "rag_chunks"

CHAR_PER_TOKEN = 2.5
MIN_CHARS = int(200 * CHAR_PER_TOKEN)   # 500
MAX_CHARS = int(600 * CHAR_PER_TOKEN)   # 1500

RE_CLAUSE_SPLIT = re.compile(r"(?=[①-⑳])")
RE_ARTICLE_NUM = re.compile(r"제\s*([0-9]+)\s*조")


def article_num_int(s: str) -> int | None:
    m = RE_ARTICLE_NUM.search(s or "")
    return int(m.group(1)) if m else None


def hard_split(text: str, limit: int) -> list[str]:
    """문단 → 문장 → 하드 슬라이스 순으로 limit 이하로 쪼갬."""
    if len(text) <= limit:
        return [text]
    # 1차: 빈 줄 기준
    paras = re.split(r"\n{2,}", text)
    out: list[str] = []
    buf = ""
    for p in paras:
        if not buf:
            buf = p
        elif len(buf) + len(p) + 2 <= limit:
            buf = buf + "\n\n" + p
        else:
            out.append(buf)
            buf = p
    if buf:
        out.append(buf)
    # 2차: 여전히 큰 덩어리는 단일 개행/문장 분리로
    refined: list[str] = []
    for chunk in out:
        if len(chunk) <= limit:
            refined.append(chunk)
            continue
        sents = re.split(r"(?<=[.。\n])\s+", chunk)
        buf = ""
        for s in sents:
            if not buf:
                buf = s
            elif len(buf) + len(s) + 1 <= limit:
                buf = buf + " " + s
            else:
                refined.append(buf)
                buf = s
        if buf:
            refined.append(buf)
    # 3차: 하드 슬라이스
    final: list[str] = []
    for chunk in refined:
        if len(chunk) <= limit:
            final.append(chunk)
        else:
            for i in range(0, len(chunk), limit):
                final.append(chunk[i:i + limit])
    return final


def approx_tokens(s: str) -> int:
    return int(len(s) / CHAR_PER_TOKEN)


def slugify(s: str) -> str:
    s = re.sub(r"\s+", "_", s.strip())
    s = re.sub(r"[^\w가-힣()]+", "", s)
    return s[:40]


def split_by_clause(text: str) -> list[str]:
    """①②③ 기준으로 분리. 환형 숫자가 없으면 단일 덩어리."""
    parts = [p.strip() for p in RE_CLAUSE_SPLIT.split(text) if p.strip()]
    if len(parts) <= 1:
        return [text.strip()]
    # 앞부분(① 이전)이 있으면 첫 덩어리로 유지
    return parts


def build_prefix(insurer: str, product: str, chapter: str | None, section: str | None,
                 article_num: str, article_title: str) -> str:
    ctx = chapter or section or ""
    return f"[{insurer} / {product} / {ctx}] {article_num} {article_title}".strip()


def iter_articles(blocks: list[dict]):
    """블록 순회하며 (section, chapter, article_block) 튜플을 방출."""
    section = None
    chapter = None
    for b in blocks:
        bt = b.get("block_type")
        if bt == "SECTION":
            section = b.get("section")
            chapter = None
            continue
        if bt == "CHAPTER":
            chapter = b.get("chapter")
            continue
        if bt in ("ARTICLE", "DEFINITION"):
            # block 자체에 section/parent_chapter가 있으면 우선
            yield (
                b.get("section") or section,
                b.get("parent_chapter") or chapter,
                b,
            )


def build_chunks_for_file(data: dict) -> list[dict]:
    insurer = data.get("insurer") or ""
    product = data.get("product") or ""
    category = data.get("category") or ""
    is_domain = category == "동산"

    # 1) (section, chapter, article) 리스트 만들기 + 내용 유효 필터
    items = []
    for section, chapter, art in iter_articles(data["blocks"]):
        content = (art.get("content") or "").strip()
        # 점선/공백/숫자만 남은 ToC 잔해 필터
        if len(re.sub(r"[·.\s\d\u2026]", "", content)) < 10:
            continue
        items.append({
            "section": section,
            "chapter": chapter,
            "article_number": art.get("article_number") or "",
            "article_title": art.get("article_title") or "",
            "content": content,
        })

    # 2) section 그룹 내에서 작은 조항 병합 (< MIN_CHARS면 다음 조와 합침).
    # 조항번호가 감소(리셋)하면 가상 섹션 경계로 간주하여 병합 중단.
    merged = []
    i = 0
    while i < len(items):
        cur = dict(items[i])
        cur_last_num = article_num_int(cur["article_number"])
        j = i + 1
        while (
            len(cur["content"]) < MIN_CHARS
            and j < len(items)
            and items[j]["section"] == cur["section"]
            and len(cur["content"]) + len(items[j]["content"]) <= MAX_CHARS
        ):
            nxt = items[j]
            nxt_num = article_num_int(nxt["article_number"])
            # 조항번호 리셋 감지 → 병합 중단
            if cur_last_num is not None and nxt_num is not None and nxt_num <= cur_last_num:
                break
            cur["content"] = cur["content"] + "\n\n" + f"{nxt['article_number']} {nxt['article_title']}\n{nxt['content']}"
            cur["article_number"] = f"{cur['article_number']}~{nxt['article_number']}"
            cur["merged"] = True
            cur_last_num = nxt_num if nxt_num is not None else cur_last_num
            j += 1
        merged.append(cur)
        i = j

    # 3) 큰 조항은 항(①②③) 단위로 분할
    chunks: list[dict] = []
    section_indices: dict[str, int] = {}
    used_ids: set[str] = set()

    for it in merged:
        sec = it["section"] or "_"
        if sec not in section_indices:
            section_indices[sec] = len(section_indices)
        sec_idx = section_indices[sec]

        prefix = build_prefix(insurer, product, it["chapter"], it["section"],
                              it["article_number"], it["article_title"])

        content = it["content"]
        pieces: list[str]
        if len(content) > MAX_CHARS:
            raw_pieces = split_by_clause(content)
            # greedy pack to MAX_CHARS
            packed: list[str] = []
            buf = ""
            for p in raw_pieces:
                if not buf:
                    buf = p
                elif len(buf) + len(p) + 2 <= MAX_CHARS:
                    buf = buf + "\n" + p
                else:
                    packed.append(buf)
                    buf = p
            if buf:
                packed.append(buf)
            # 여전히 MAX 초과하는 피스는 하드 분할
            pieces = []
            for p in packed:
                pieces.extend(hard_split(p, MAX_CHARS))
        else:
            pieces = [content]

        for part_i, piece in enumerate(pieces, start=1):
            chunk_text = f"{prefix}\n{piece}"
            cid_base = f"{slugify(insurer)}_{slugify(product)}_{sec_idx:02d}_{slugify(it['article_number'])}"
            cid = cid_base if len(pieces) == 1 else f"{cid_base}_p{part_i}"
            # 중복 id는 _dN 으로 유니크화
            if cid in used_ids:
                k = 2
                while f"{cid}_d{k}" in used_ids:
                    k += 1
                cid = f"{cid}_d{k}"
            used_ids.add(cid)
            chunk = {
                "chunk_id": cid,
                "context": prefix,
                "chunk_text": chunk_text,
                "insurer": insurer,
                "product": product,
                "category": category,
                "section": it["section"],
                "chapter": it["chapter"],
                "article_number": it["article_number"],
                "article_title": it["article_title"],
                "char_len": len(chunk_text),
                "approx_tokens": approx_tokens(chunk_text),
            }
            if is_domain:
                chunk["domain_priority"] = "high"
            chunks.append(chunk)

    return chunks


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    jsons = sorted(IN_DIR.rglob("*.json"))
    total = 0
    for jp in jsons:
        data = json.loads(jp.read_text(encoding="utf-8"))
        chunks = build_chunks_for_file(data)
        rel = jp.relative_to(IN_DIR).with_suffix(".jsonl")
        out_path = OUT_DIR / rel
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            for c in chunks:
                f.write(json.dumps(c, ensure_ascii=False) + "\n")
        total += len(chunks)
        print(f"  ✓ {rel}  chunks={len(chunks)}")
    print(f"총 청크: {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
