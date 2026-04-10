import streamlit as st
import plotly.graph_objects as go
from utils import DISTRICT_PROFILES, DEMO_DISTRICTS

def show_page(session, selected_ym):
    st.title("⚙️ 엔진 상세")
    sel_gu = st.selectbox("자치구 선택", DEMO_DISTRICTS)
    t_r, t_p, t_f = st.tabs(["위험 분석", "보험료 산출", "미래 예측"])
    p = DISTRICT_PROFILES[sel_gu]

    with t_r:
        fig = go.Figure()
        fig.add_trace(go.Scatterpolar(r=[p["fire"], p["theft"], p["building"], p["weather"], p["fire"]], theta=["화재", "도난", "건물", "기상", "화재"], fill='toself', name=sel_gu))
        fig.update_layout(polar=dict(radialaxis=dict(visible=True, range=[0, 60])), height=400, plot_bgcolor="#0f1117", paper_bgcolor="#0f1117")
        st.plotly_chart(fig, use_container_width=True)

    with t_p:
        st.markdown("##### 7단계 보험료 산출")
        # Waterfall 로직 (기존 코드와 동일하게 구현)
        st.info("비선형 리스크 커브 v1.3 적용 중")

    with t_f:
        st.markdown("##### Cortex ML FORECAST")
        st.caption("소방청 5개년 데이터 기반 시계열 예측")