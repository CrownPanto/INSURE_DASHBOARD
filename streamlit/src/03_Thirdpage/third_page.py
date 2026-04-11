import streamlit as st

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
