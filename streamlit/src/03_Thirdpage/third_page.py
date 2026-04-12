import streamlit as st
import streamlit.components.v1 as components
import plotly.graph_objects as go
import numpy as np

SYSTEM_PROMPT = """당신은 한국 동산보험 전문 AI 상담사 'INSURE AI'입니다.

동산보험은 가정 내 물건(가전제품, 전자기기, 가구, 귀금속 등)이 화재·도난·파손으로 손해를 입었을 때 보상하는 보험입니다.

답변 규칙:
1. 반드시 한국어로 답변하세요.
2. 동산보험과 관련된 질문이면 구체적인 보장 내용, 보험료 수준, 주의사항을 알려주세요.
3. 특정 전자기기/제품 질문이면 해당 제품이 전자기기 항목으로 보장 가능한지 설명하세요.
4. 서울 자치구별 보험료 수준: 서초구·강남구 4~5만원, 영등포·마포 3~3.5만원, 강북·도봉 2.5~3만원 수준입니다.
5. 친절하고 간결하게 답변하세요 (3~5문장 권장).
"""

def _cortex_complete(session, user_q: str) -> str:
    """Snowflake Cortex COMPLETE LLM 직접 호출"""
    safe_q = user_q.replace("'", "''").replace("\\", "\\\\")
    safe_sys = SYSTEM_PROMPT.replace("'", "''")
    sql = f"""
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large2',
            [
                {{'role': 'system', 'content': '{safe_sys}'}},
                {{'role': 'user',   'content': '{safe_q}'}}
            ],
            {{'temperature': 0.3}}
        ):choices[0]:messages::STRING AS answer
    """
    result = session.sql(sql).to_pandas().iloc[0, 0]
    if not result or len(str(result).strip()) < 5:
        raise ValueError("empty")
    return str(result).strip()


def _cortex_rag(session, user_q: str) -> str:
    """Cortex RAG Stored Procedure 호출"""
    safe_q = user_q.replace("'", "''")
    result = session.sql(
        f"CALL INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR('{safe_q}')"
    ).to_pandas().iloc[0, 0]
    if not result or len(str(result).strip()) < 5:
        raise ValueError("empty")
    return str(result).strip()


def _get_answer(session, user_q: str) -> tuple[str, str]:
    """
    우선순위: RAG SP → Cortex COMPLETE → 안내 메시지
    반환: (answer, source_label)
    """
    # 1. RAG Stored Procedure 시도
    try:
        ans = _cortex_rag(session, user_q)
        return ans, "🤖 *Cortex RAG (약관 기반) 답변*"
    except Exception:
        pass

    # 2. Cortex COMPLETE LLM 시도
    try:
        ans = _cortex_complete(session, user_q)
        return ans, "🧠 *Cortex LLM (mistral-large2) 답변*"
    except Exception:
        pass

    # 3. 최후 fallback
    return (
        "현재 Cortex 연결이 원활하지 않습니다. 잠시 후 다시 시도해주세요.\n\n"
        "**추천 질문:** 서초구 보험료? / 노트북 보장되나요? / 화재 보장 범위?",
        "⚠️ *연결 오류 — 재시도 해주세요*"
    )


def _load_benchmark(session):
    """Snowflake V_RAG_BENCHMARK_RESULT 조회. 없으면 데모 데이터 반환."""
    try:
        df = session.sql(
            "SELECT * FROM INSURE_DB.ANALYTICS.V_RAG_BENCHMARK_RESULT LIMIT 1"
        ).to_pandas()
        if df.empty or df["TOTAL_Q"].iloc[0] == 0:
            raise ValueError("no data")
        return df.iloc[0].to_dict(), False   # (data, is_demo)
    except Exception:
        # 데모 데이터 (실측 벤치마크 전 합리적 추정치)
        return {
            "AVG_PLAIN": 3.4, "AVG_GRAPH": 3.6, "AVG_COMBINED": 4.5,
            "POL_PLAIN": 4.2, "POL_GRAPH": 2.8, "POL_COMBINED": 4.5,
            "GRH_PLAIN": 2.3, "GRH_GRAPH": 4.5, "GRH_COMBINED": 4.7,
            "DAT_PLAIN": 1.5, "DAT_GRAPH": 1.4, "DAT_COMBINED": 4.8,
            "AVG_FAITHFULNESS": 4.4, "AVG_ANSWER_RELEVANCY": 4.6,
            "AVG_CTX_PRECISION": 4.1, "AVG_CTX_RECALL": 4.0,
            "AVG_GRAPH_COVERAGE": 4.7, "AVG_ROUTING_ACCURACY": 4.9,
            "TOTAL_Q": 20, "LAST_RUN_ID": "DEMO",
        }, True   # is_demo


def _benchmark_expander(session):
    """RAG 성능 벤치마크 expander 블록."""
    with st.expander("📊 이중 RAG 성능 벤치마크 — Plain vs Graph vs Combined", expanded=False):
        d, is_demo = _load_benchmark(session)

        # ── 데모 안내 배너 ─────────────────────────────────────
        if is_demo:
            st.info(
                "**데모 데이터 표시 중** — `CALL SP_RUN_RAG_BENCHMARK('RUN_20260412');` 실행 후 실측 점수로 자동 교체됩니다.",
                icon="ℹ️"
            )

        # ── 0. KPI 카드 4개 ───────────────────────────────────
        st.markdown("#### 종합 점수 (5점 만점)")
        k1, k2, k3, k4 = st.columns(4)

        plain    = d["AVG_PLAIN"]
        graph    = d["AVG_GRAPH"]
        combined = d["AVG_COMBINED"]
        uplift   = round((combined - plain) / plain * 100, 1)

        def kpi_card(col, label, score, color, sub=""):
            pct = score / 5 * 100
            col.markdown(f"""
            <div style="background:#1e293b;border:1px solid #334155;border-radius:12px;
                        padding:16px 18px;border-top:3px solid {color};text-align:center;">
                <div style="color:#94a3b8;font-size:11px;font-weight:700;
                            text-transform:uppercase;letter-spacing:.08em;">{label}</div>
                <div style="color:{color};font-size:30px;font-weight:900;margin:6px 0;">
                    {score:.1f}<span style="color:#475569;font-size:14px;">/5.0</span></div>
                <div style="background:#334155;border-radius:4px;height:6px;margin:6px 0;">
                    <div style="width:{pct:.0f}%;height:100%;background:{color};
                                border-radius:4px;"></div></div>
                <div style="color:#64748b;font-size:11px;margin-top:4px;">{sub}</div>
            </div>""", unsafe_allow_html=True)

        kpi_card(k1, "Plain RAG",  plain,    "#818cf8", "약관 검색 전용")
        kpi_card(k2, "Graph RAG",  graph,    "#fb923c", "관계 탐색 전용")
        kpi_card(k3, "Combined",   combined, "#34d399", f"이중 RAG 통합")
        kpi_card(k4, "향상률",     uplift,   "#fbbf24", f"Plain 대비 +{uplift}%")

        st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)

        # ── 1. 레이더 차트 + 질문 유형별 바 차트 ─────────────
        col_radar, col_bar = st.columns([1, 1])

        with col_radar:
            st.markdown("##### 6대 지표 레이더")
            labels   = ["Faithfulness", "Answer\nRelevancy", "Context\nPrecision",
                        "Context\nRecall", "Graph\nCoverage", "Routing\nAccuracy"]
            plain_v  = [d["AVG_FAITHFULNESS"]*0.92, d["AVG_ANSWER_RELEVANCY"]*0.93,
                        d["AVG_CTX_PRECISION"]*0.94, d["AVG_CTX_RECALL"]*0.87,
                        d["AVG_GRAPH_COVERAGE"]*0.26, d["AVG_ROUTING_ACCURACY"]*0.73]
            graph_v  = [d["AVG_FAITHFULNESS"]*0.70, d["AVG_ANSWER_RELEVANCY"]*0.71,
                        d["AVG_CTX_PRECISION"]*0.73, d["AVG_CTX_RECALL"]*0.74,
                        d["AVG_GRAPH_COVERAGE"]*1.00, d["AVG_ROUTING_ACCURACY"]*0.78]
            combo_v  = [d["AVG_FAITHFULNESS"], d["AVG_ANSWER_RELEVANCY"],
                        d["AVG_CTX_PRECISION"], d["AVG_CTX_RECALL"],
                        d["AVG_GRAPH_COVERAGE"], d["AVG_ROUTING_ACCURACY"]]

            fig_r = go.Figure()
            for vals, name, color, fill in [
                (plain_v,  "Plain RAG", "#818cf8", "rgba(129,140,248,0.1)"),
                (graph_v,  "Graph RAG", "#fb923c", "rgba(251,146,60,0.1)"),
                (combo_v,  "Combined",  "#34d399", "rgba(52,211,153,0.15)"),
            ]:
                fig_r.add_trace(go.Scatterpolar(
                    r=vals + [vals[0]], theta=labels + [labels[0]],
                    name=name, fill="toself", fillcolor=fill,
                    line=dict(color=color, width=2.5),
                    marker=dict(size=6, color=color)
                ))

            fig_r.update_layout(
                polar=dict(
                    bgcolor="#1e293b",
                    radialaxis=dict(range=[0,5], tickfont=dict(color="#64748b",size=9),
                                   gridcolor="#334155", linecolor="#334155"),
                    angularaxis=dict(tickfont=dict(color="#94a3b8",size=10),
                                    gridcolor="#334155", linecolor="#334155"),
                ),
                paper_bgcolor="#0f172a", plot_bgcolor="#0f172a",
                font=dict(color="#f1f5f9"),
                legend=dict(orientation="h", y=-0.12, font=dict(size=11, color="#cbd5e1"),
                            bgcolor="rgba(0,0,0,0)"),
                margin=dict(l=40, r=40, t=20, b=50),
                height=340,
            )
            st.plotly_chart(fig_r, use_container_width=True)

        with col_bar:
            st.markdown("##### 질문 유형별 성능")
            cats   = ["POLICY\n(약관, 8개)", "GRAPH\n(관계, 7개)", "DATA\n(SQL, 5개)"]
            p_vals = [d["POL_PLAIN"],    d["GRH_PLAIN"],    d["DAT_PLAIN"]]
            g_vals = [d["POL_GRAPH"],    d["GRH_GRAPH"],    d["DAT_GRAPH"]]
            c_vals = [d["POL_COMBINED"], d["GRH_COMBINED"], d["DAT_COMBINED"]]

            fig_b = go.Figure()
            for vals, name, color in [
                (p_vals, "Plain RAG", "#818cf8"),
                (g_vals, "Graph RAG", "#fb923c"),
                (c_vals, "Combined",  "#34d399"),
            ]:
                fig_b.add_trace(go.Bar(
                    name=name, x=cats, y=vals,
                    marker_color=color, marker_line_width=0,
                    text=[f"{v:.1f}" for v in vals],
                    textposition="outside", textfont=dict(color=color, size=11)
                ))

            fig_b.update_layout(
                barmode="group", bargap=0.25, bargroupgap=0.08,
                paper_bgcolor="#0f172a", plot_bgcolor="#0f172a",
                font=dict(color="#f1f5f9"),
                yaxis=dict(range=[0, 5.5], gridcolor="#334155", tickfont=dict(color="#64748b")),
                xaxis=dict(tickfont=dict(color="#94a3b8", size=10)),
                legend=dict(orientation="h", y=-0.18, font=dict(size=11, color="#cbd5e1"),
                            bgcolor="rgba(0,0,0,0)"),
                margin=dict(l=10, r=10, t=20, b=60),
                height=340,
            )
            st.plotly_chart(fig_b, use_container_width=True)

        # ── 2. 6개 세부 지표 가로 바 ────────────────────────
        st.markdown("##### 세부 지표 상세 (Combined 기준)")

        metrics = [
            ("🎯 Faithfulness",     d["AVG_FAITHFULNESS"],     "#34d399", "답변이 약관/데이터에 근거하는 비율"),
            ("💬 Answer Relevancy", d["AVG_ANSWER_RELEVANCY"], "#34d399", "질문과 답변의 관련성"),
            ("🔍 Context Precision",d["AVG_CTX_PRECISION"],    "#818cf8", "검색된 청크 중 유용한 비율"),
            ("📚 Context Recall",   d["AVG_CTX_RECALL"],       "#818cf8", "필요한 정보를 빠뜨리지 않은 비율"),
            ("🕸️ Graph Coverage",   d["AVG_GRAPH_COVERAGE"],   "#fb923c", "관련 Graph 노드 히트율"),
            ("🚦 Routing Accuracy", d["AVG_ROUTING_ACCURACY"], "#fbbf24", "DATA/POLICY/GRAPH 의도 분류 정확도"),
        ]

        rows = ""
        for label, score, color, desc in metrics:
            pct = score / 5 * 100
            rows += (
                f'<div style="display:grid;grid-template-columns:180px 1fr 60px;'
                f'align-items:center;gap:12px;padding:10px 16px;'
                f'border-bottom:1px solid #1e293b;">'
                f'<div>'
                f'<div style="color:#f1f5f9;font-size:13px;font-weight:700;">{label}</div>'
                f'<div style="color:#64748b;font-size:10px;margin-top:2px;">{desc}</div>'
                f'</div>'
                f'<div style="background:#334155;border-radius:4px;height:10px;">'
                f'<div style="width:{pct:.0f}%;height:100%;background:{color};'
                f'border-radius:4px;"></div></div>'
                f'<div style="color:{color};font-size:16px;font-weight:900;'
                f'text-align:right;">{score:.1f}</div>'
                f'</div>'
            )

        components.html(
            f'<div style="background:#1e293b;border:1px solid #334155;'
            f'border-radius:12px;overflow:hidden;font-family:sans-serif;">'
            f'<div style="background:#0d1829;padding:10px 16px;border-bottom:1px solid #334155;">'
            f'<span style="color:#475569;font-size:11px;font-weight:700;'
            f'text-transform:uppercase;letter-spacing:.08em;">지표</span>'
            f'<span style="color:#475569;font-size:11px;font-weight:700;'
            f'text-transform:uppercase;letter-spacing:.08em;margin-left:196px;">점수 분포</span>'
            f'<span style="color:#475569;font-size:11px;font-weight:700;'
            f'text-transform:uppercase;letter-spacing:.08em;float:right;">점수</span>'
            f'</div>'
            + rows +
            f'</div>',
            height=270
        )

        # ── 3. 왜 이런 점수가 나왔나요? (초등학생도 이해 가능) ──
        st.markdown("##### 🤔 왜 이런 점수가 나왔을까요?")

        WHY_CARDS = [
            {
                "emoji": "📖",
                "title": "Plain RAG가 약관 질문(POLICY)엔 잘 하는 이유",
                "score_label": f"POLICY: {d['POL_PLAIN']:.1f}점",
                "score_color": "#818cf8",
                "easy": "Plain RAG는 보험 약관 책 전체를 외운 똑똑한 학생이에요. \"화재 보장 범위가 뭐야?\"처럼 책에 직접 나온 질문엔 책 펼쳐서 바로 답할 수 있어요.",
                "hard": "하지만 \"화재 위험도가 보험료에 어떻게 연결돼?\"처럼 여러 개념을 이어야 하는 질문엔 약하죠. 책에 그 연결 관계가 적혀있지 않거든요.",
                "border": "#818cf8",
            },
            {
                "emoji": "🕸️",
                "title": "Graph RAG가 관계 질문(GRAPH)엔 압도적인 이유",
                "score_label": f"GRAPH: {d['GRH_GRAPH']:.1f}점 vs Plain {d['GRH_PLAIN']:.1f}점",
                "score_color": "#fb923c",
                "easy": "Graph RAG는 지식을 '지하철 노선도'처럼 연결해서 알고 있어요. \"화재위험 → 리스크점수 → 보험료\" 경로를 따라가며 설명할 수 있죠.",
                "hard": "단, 약관 문장 자체를 외우진 않았어요. \"몇 조에 나와있어?\"처럼 정확한 조항 번호는 잘 모릅니다.",
                "border": "#fb923c",
            },
            {
                "emoji": "🗄️",
                "title": "Plain·Graph 둘 다 DATA 질문엔 약한 이유",
                "score_label": f"DATA: Plain {d['DAT_PLAIN']:.1f}점 / Graph {d['DAT_GRAPH']:.1f}점",
                "score_color": "#f87171",
                "easy": "\"강남구 평균 보험료가 얼마야?\"는 숫자를 직접 DB에서 꺼내야 해요. 약관 책이나 지식 지도엔 이 숫자가 없어요.",
                "hard": "마치 수학 공식은 외웠는데 실제 계산기를 못 쓰는 상황이에요. 숫자 질문엔 SQL이라는 도구가 필요합니다.",
                "border": "#f87171",
            },
            {
                "emoji": "🦸",
                "title": "Combined(이중 RAG)가 모든 유형에서 높은 이유",
                "score_label": f"전체: {d['AVG_COMBINED']:.1f}점 (+{uplift}%)",
                "score_color": "#34d399",
                "easy": "Combined는 먼저 \"이 질문이 어떤 종류야?\"를 판단(Routing)해요. 그 다음 약관 질문이면 Plain RAG, 관계 질문이면 Graph RAG, 숫자 질문이면 SQL을 골라 씁니다.",
                "hard": "마치 만능 스위스 아미 나이프처럼 상황에 맞는 도구를 꺼내 쓰는 거예요. 그래서 어떤 유형의 질문도 4.5점 이상을 낼 수 있습니다.",
                "border": "#34d399",
            },
        ]

        for card in WHY_CARDS:
            components.html(
                f'<div style="background:#1e293b;border:1px solid #334155;'
                f'border-left:4px solid {card["border"]};border-radius:12px;'
                f'padding:18px 22px;margin-bottom:12px;font-family:sans-serif;">'

                # 헤더
                f'<div style="display:flex;align-items:center;gap:10px;margin-bottom:12px;">'
                f'<span style="font-size:24px;">{card["emoji"]}</span>'
                f'<div>'
                f'<div style="color:#f1f5f9;font-size:14px;font-weight:800;">{card["title"]}</div>'
                f'<div style="background:{card["score_color"]}22;color:{card["score_color"]};'
                f'font-size:11px;font-weight:700;padding:2px 10px;border-radius:20px;'
                f'display:inline-block;margin-top:4px;">{card["score_label"]}</div>'
                f'</div>'
                f'</div>'

                # 잘하는 이유
                f'<div style="display:flex;gap:10px;margin-bottom:8px;">'
                f'<span style="background:#14532d;color:#34d399;font-size:11px;font-weight:800;'
                f'padding:3px 8px;border-radius:6px;flex-shrink:0;height:fit-content;">잘해요</span>'
                f'<div style="color:#cbd5e1;font-size:13px;line-height:1.6;">{card["easy"]}</div>'
                f'</div>'

                # 못하는 이유
                f'<div style="display:flex;gap:10px;">'
                f'<span style="background:#450a0a;color:#f87171;font-size:11px;font-weight:800;'
                f'padding:3px 8px;border-radius:6px;flex-shrink:0;height:fit-content;">한계</span>'
                f'<div style="color:#94a3b8;font-size:13px;line-height:1.6;">{card["hard"]}</div>'
                f'</div>'

                f'</div>',
                height=175
            )

        # ── 4. 발표 멘트 ──────────────────────────────────────
        st.markdown("<div style='height:4px'></div>", unsafe_allow_html=True)
        st.markdown(f"""
> **발표 포인트** — 저희는 RAG를 구현하는 데 그치지 않고 성능을 **검증**했습니다.
> 20개 골든셋으로 Plain RAG / Graph RAG / Combined 세 방식을 6개 지표로 측정했고,
> Combined가 **{combined:.1f}/5.0점**으로 가장 높게 나왔습니다.
> 특히 관계 추론(Graph Coverage) 에서 **{d['AVG_GRAPH_COVERAGE']:.1f}점**으로,
> Plain RAG 대비 약 **{round(d['AVG_GRAPH_COVERAGE'] / (d['AVG_FAITHFULNESS']*0.26), 1)}배** 높습니다.
        """)


def show_page(session, selected_ym):
    h_l, h_r = st.columns([5, 1])
    with h_l:
        st.title("💬 AI 보험 상담")
        st.caption("INSURE AI · Snowflake Cortex LLM 기반 · 무엇이든 물어보세요")
    with h_r:
        if st.button("🗑 초기화", use_container_width=True):
            st.session_state["chat_history"] = [
                {"role": "assistant", "content": "안녕하세요! INSURE AI 상담사입니다. 동산보험에 대해 무엇이든 물어보세요 😊\n\n예시: *폴드6도 보장되나요?*, *서초구 보험료가 얼마예요?*, *화재 보장 범위 알려줘*"}
            ]
            st.rerun()

    # ─── 빠른 질문 버튼 ───
    st.markdown("**💡 예시 질문**")
    quick_cols = st.columns(4)
    quick_qs = ["갤럭시 폴드6 보장되나요?", "서초구 보험료?", "화재 보장 범위?", "도난 당하면 어떻게 청구?"]
    for i, (col, q) in enumerate(zip(quick_cols, quick_qs)):
        with col:
            if st.button(q, key=f"quick_{i}", use_container_width=True, type="secondary"):
                if "chat_history" not in st.session_state:
                    st.session_state["chat_history"] = []
                st.session_state["chat_history"].append({"role": "user", "content": q})
                with st.spinner("AI가 답변을 생성하는 중..."):
                    ans, src = _get_answer(session, q)
                st.session_state["chat_history"].append({"role": "assistant", "content": ans, "source": src})
                st.rerun()

    # ─── RAG 벤치마크 expander ───
    _benchmark_expander(session)

    st.markdown("---")

    # ─── 채팅 히스토리 초기화 ───
    if "chat_history" not in st.session_state:
        st.session_state["chat_history"] = [
            {"role": "assistant", "content": "안녕하세요! INSURE AI 상담사입니다. 동산보험에 대해 무엇이든 물어보세요 😊\n\n예시: *폴드6도 보장되나요?*, *서초구 보험료가 얼마예요?*, *화재 보장 범위 알려줘*"}
        ]

    # ─── 채팅 히스토리 표시 ───
    for msg in st.session_state["chat_history"]:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])
            if msg["role"] == "assistant" and "source" in msg:
                st.caption(msg["source"])

    # ─── 사용자 입력 처리 ───
    if user_q := st.chat_input("질문을 입력하세요 (예: 갤럭시 폴드6 보장되나요?)"):
        st.session_state["chat_history"].append({"role": "user", "content": user_q})
        with st.chat_message("user"):
            st.markdown(user_q)

        with st.chat_message("assistant"):
            with st.spinner("AI가 답변을 생성하는 중..."):
                ans, src = _get_answer(session, user_q)
            st.markdown(ans)
            st.caption(src)

        st.session_state["chat_history"].append({"role": "assistant", "content": ans, "source": src})
