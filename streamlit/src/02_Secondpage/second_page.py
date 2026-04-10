import streamlit as st
import plotly.graph_objects as go
from ..utils import PRESETS, SEGMENTS_A, SEGMENTS_B, COVERAGE_ITEMS, calc_premium


def show_page(session, selected_ym):
    st.title("맞춤 보험 시뮬레이터")
    st.subheader("고객 프로필 선택")
    p_cols = st.columns(4)
    if "selected_preset" not in st.session_state: st.session_state["selected_preset"] = 0

    for i, p in enumerate(PRESETS):
        with p_cols[i]:
            if p["active"]:
                border = "#10b981" if i == st.session_state["selected_preset"] else "#2d3148"
                st.markdown(
                    f'<div style="border: 2px solid {border}; border-radius: 12px; padding: 16px; background: #12141f; min-height: 200px;"><div style="font-size: 2em; text-align: center;">{SEGMENTS_A[p["seg_a"]]["icon"]}</div><div style="text-align: center; font-weight: 700; color: #fff;">{p["name"]}</div></div>',
                    unsafe_allow_html=True)
                if st.button(f"선택", key=f"p_{i}"): st.session_state["selected_preset"] = i; st.rerun()
            else:
                st.markdown(
                    '<div style="opacity: 0.45; border: 1px dashed #333; border-radius: 12px; padding: 16px; background: #0a0b10; min-height: 200px;"><div style="font-size: 2em; text-align: center;">🔒</div></div>',
                    unsafe_allow_html=True)

    sel = PRESETS[st.session_state["selected_preset"]]
    st.markdown("---")
    st.subheader(f"{sel['persona']}의 맞춤 보험 메뉴")
    item_cols, selected_items = st.columns(3), []
    for idx, (name, info) in enumerate(COVERAGE_ITEMS.items()):
        with item_cols[idx % 3]:
            if st.checkbox(f"{info['icon']} {name}", value=(name in sel["default_items"]),
                           key=f"i_{name}"): selected_items.append(name)

    res = calc_premium(sel["district"], sel["seg_a"], sel["seg_b"], income=sel["income"], selected_items=selected_items)
    c_m, c_p = st.columns([3, 2])
    with c_m:
        st.markdown("#### 선택된 보장 내역")
        for it in selected_items:
            ci = COVERAGE_ITEMS[it]
            st.write(f"{ci['icon']} **{it}** — 한도 ₩{ci['limit']:,.0f}")
    with c_p:
        st.metric("월 보험료", f"₩{res['final']:,.0f}")
        fig = go.Figure(go.Waterfall(orientation="v", measure=["absolute", "relative", "total"], x=["기본", "품목가산", "최종"],
                                     y=[res["segment_adjusted"], res["item_addon"], 0]))
        fig.update_layout(height=250, plot_bgcolor="#0f1117", paper_bgcolor="#0f1117", font=dict(color="#f1f5f9"))
        st.plotly_chart(fig, use_container_width=True)