import streamlit as st

def show_page(session, selected_ym):
    h_l, h_r = st.columns([5, 1])
    with h_l: st.title("AI 보험 상담")
    with h_r:
        if st.button("🗑 초기화"): st.session_state["chat_history"] = [{"role": "assistant", "content": "안녕하세요! INSURE AI 상담사입니다."}]; st.rerun()

    if "chat_history" not in st.session_state: st.session_state["chat_history"] = [{"role": "assistant", "content": "안녕하세요! INSURE AI 상담사입니다. 무엇이든 물어보세요."}]

    for msg in st.session_state["chat_history"]:
        with st.chat_message(msg["role"]): st.write(msg["content"])

    if user_q := st.chat_input("질문을 입력하세요"):
        st.session_state["chat_history"].append({"role": "user", "content": user_q})
        with st.chat_message("user"): st.write(user_q)
        try:
            ans = session.sql(f"CALL INSURE_DB.ANALYTICS.SP_ASK_INSURE_ADVISOR('{user_q}')").to_pandas().iloc[0, 0]
        except:
            ans = "현재 데모 모드입니다. Cortex Agent가 연결되면 실제 약관 데이터 기반 답변이 제공됩니다."
        st.session_state["chat_history"].append({"role": "assistant", "content": ans})
        with st.chat_message("assistant"): st.write(ans)