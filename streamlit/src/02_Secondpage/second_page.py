
import streamlit as st
import plotly.graph_objects as go
from utils import PRESETS, SEGMENTS_A, SEGMENTS_B, COVERAGE_ITEMS, calc_premium
import utils

def show_page(session, selected_ym):
    # --- 1. 전용 스타일 시트 주입 ---
    st.markdown("""
        <style>
        /* 캐릭터 카드 전체 디자인 */
        .preset-container {
            display: flex;
            gap: 15px;
            margin-bottom: 20px;
        }
        .character-card {
            border-radius: 15px;
            padding: 20px;
            text-align: center;
            transition: all 0.3s ease;
            cursor: pointer;
            border: 2px solid #2d3148;
            background: #1c1f2e;
            height: 100%;
        }
        /* 마우스 올렸을 때 효과 */
        .character-card:hover {
            transform: translateY(-5px);
            border-color: #6366F1;
            box-shadow: 0 10px 20px rgba(99, 102, 241, 0.2);
        }
        /* 수정 후: 다크그레이 배경 및 흰색 테두리 */
        .active-card {
            background: linear-gradient(145deg, #2d3148 0%, #3f445e 100%); 
            border-color: #FFFFFF !important; /* 흰색으로 변경 */
            box-shadow: 0 0 15px rgba(255, 255, 255, 0.2);
        }
        /* 잠긴 카드 스타일 */
        .locked-card {
            opacity: 0.5;
            filter: grayscale(1);
            background: #0f1117;
            border: 1px dashed #444;
        }
        .icon-circle {
            font-size: 3rem;
            margin-bottom: 10px;
            display: block;
        }
        .card-title {
            font-weight: 700;
            color: white;
            margin-bottom: 5px;
            font-size: 1.1rem;
        }
        .card-desc {
            font-size: 0.85rem;
            color: #9CA3AF;
        }
        /* 결과 요약 컨테이너 */
        .result-box {
            background: #111827;
            border-radius: 12px;
            padding: 20px;
            border: 1px solid #2d3148;
        }
        </style>
    """, unsafe_allow_html=True)

    st.title("🎯 맞춤 보험 시뮬레이터")
    st.caption("고객 유형에 맞는 최적의 보장 설계를 시뮬레이션 하세요.")

    # ─── 2. 캐릭터 프로필 선택 (카드 UI) ───
    st.subheader("고객 프로필 선택")
    p_cols = st.columns(4)

    if "selected_preset" not in st.session_state:
        st.session_state["selected_preset"] = 0

    for i, p in enumerate(PRESETS):
        with p_cols[i]:
            seg_info = SEGMENTS_A[p["seg_a"]]
            is_selected = i == st.session_state["selected_preset"]

            if p["active"]:
                # 활성 카드 디자인
                active_class = "active-card" if is_selected else ""
                st.markdown(f"""
                    <div class="character-card {active_class}">
                        <span class="icon-circle">{seg_info['icon']}</span>
                        <div class="card-title">{p['name']}</div>
                        <div class="card-desc">{p['desc']}</div>
                        {'<div style="color:#FFFFFF; font-weight:bold; margin-top:10px;">SELECTED</div>' if is_selected else ''}
                    </div>
                """, unsafe_allow_html=True)

                # 버튼을 투명하게 만들어 카드 위에 겹치는 느낌 주기 (Streamlit 제약상 아래 배치)
                if st.button(f"선택하기", key=f"p_{i}", use_container_width=True,
                             type="primary" if is_selected else "secondary"):
                    st.session_state["selected_preset"] = i
                    st.rerun()
            else:
                # 잠긴 카드 디자인
                st.markdown(f"""
                    <div class="character-card locked-card">
                        <span class="icon-circle">🔒</span>
                        <div class="card-title">{p['name']}</div>
                        <div class="card-desc">업데이트 예정</div>
                    </div>
                """, unsafe_allow_html=True)
                st.button("잠김", key=f"p_{i}", disabled=True, use_container_width=True)

    # ─── 3. 상세 설정 섹션 ───
    sel = PRESETS[st.session_state["selected_preset"]]
    st.markdown("---")

    col_left, col_right = st.columns([3, 2], gap="large")

    with col_left:
        # 1. 사용자 페르소나 배너 (흰색 강조)
        st.markdown(f"""
            <div style="background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%); 
                        padding: 20px; border-radius: 15px; border: 1px solid #334155; 
                        border-left: 6px solid #FFFFFF;  /* 흰색 바 */; margin-bottom: 25px;">
                <div style="color: #94a3b8 !important; font-size: 0.85rem; font-weight: 600; margin-bottom: 5px; text-transform: uppercase;">
                    User Persona Settings
                </div>
                <h3 style="margin:0; color: #FFFFFF !important; font-size: 1.4rem;">
                    🛠️ {sel['persona']}
                </h3>
                <div style="margin-top: 15px; display: flex; gap: 10px;">
                    <span style="background: rgba(255, 255, 255, 0.1);color: #FFFFFF !important; padding: 4px 12px; border-radius: 20px; font-size: 0.9rem; font-weight: 600; border: 1px solid #FFFFFF;">
                        📍 {sel['district']}
                    </span>
                    <span style="background: rgba(16, 185, 129, 0.1); color: #FFFFFF !important; padding: 4px 12px; border-radius: 20px; font-size: 0.9rem; font-weight: 600; border: 1px solid #10B981;">
                        💰 연소득 {sel['income']}백만원
                    </span>
                </div>
            </div>
        """, unsafe_allow_html=True)

        # 2. 보장 품목 라이브러리 (체크박스 위 안내문구 흰색)
        st.markdown(
            '<p style="color: #FFFFFF !important; font-size: 1.3rem; font-weight: 700; margin-bottom: 5px;">📚 보장 품목 라이브러리</p>',
            unsafe_allow_html=True)
        st.markdown(
            '<p style="color: #D1D5DB !important; font-size: 0.95rem; margin-bottom: 20px;">보험료에 영향을 미치는 동산 품목을 선택하세요.</p>',
            unsafe_allow_html=True)

        item_keys = list(utils.COVERAGE_ITEMS.keys())
        selected_items = []

        # 2열 그리드 배치
        for i in range(0, len(item_keys), 2):
            cols = st.columns(2)
            for j in range(2):
                if i + j < len(item_keys):
                    name = item_keys[i + j]
                    info = utils.COVERAGE_ITEMS[name]
                    with cols[j]:
                        # 스트림릿 기본 체크박스 텍스트는 시스템 설정을 따르므로,
                        # 가독성을 위해 key를 명확히 하고 UI를 유지합니다.
                        if st.checkbox(f"{info['icon']} {name}", value=(name in sel["default_items"]),
                                       key=f"final_chk_{name}"):
                            selected_items.append(name)

        st.markdown('<div style="margin: 30px 0;"></div>', unsafe_allow_html=True)

        # 3. 선택된 보장 상세 (성혁님이 말한 흰색 ㅡㅡ+)
        st.markdown(
            '<p style="color: #FFFFFF !important; font-size: 1.3rem; font-weight: 700; margin-bottom: 20px;">✅ 선택된 보장 상세</p>',
            unsafe_allow_html=True)

        if not selected_items:
            st.warning("선택된 품목이 없습니다.")
        else:
            for it in selected_items:
                ci = utils.COVERAGE_ITEMS[it]
                st.markdown(f"""
                    <div style="background: #1e293b; border: 1px solid #334155; border-radius: 10px; 
                                padding: 15px 20px; margin-bottom: 10px; display: flex; 
                                justify-content: space-between; align-items: center;
                                border-left: 4px solid #FFFFFF;">
                        <div style="display: flex; align-items: center; gap: 12px;">
                            <span style="font-size: 1.4rem;">{ci['icon']}</span>
                            <span style="color: #FFFFFF !important; font-size: 1.1rem; font-weight: 700;">{it}</span>
                        </div>
                        <div style="text-align: right;">
                            <div style="color: #94a3b8 !important; font-size: 0.7rem; font-weight: 600; text-transform: uppercase;">Limit</div>
                            <div style="color: #FFFFFF !important; font-size: 1.1rem; font-weight: 700;">₩{ci['limit']:,.0f}</div>
                        </div>
                    </div>
                """, unsafe_allow_html=True)

    with col_right:
        st.subheader("💰 산출 결과")
        res = calc_premium(sel["district"], sel["seg_a"], sel["seg_b"], income=sel["income"],
                           selected_items=selected_items)

        # 가격 강조 박스
        st.markdown(f"""
            <div style="background: linear-gradient(135deg, #475569 0%, #1e293b 100%); border: 2px solid #FFFFFF; padding: 25px; border-radius: 15px; text-align: center; margin-bottom: 20px;">
                <div style="color: rgba(255,255,255,0.8); font-size: 1rem; margin-bottom: 5px;">최종 월 보험료</div>
                <div style="color: white; font-size: 2.5rem; font-weight: 800;">₩{res['final']:,.0f}</div>
                {'<div style="background:rgba(255,255,255,0.2); border-radius:5px; padding:3px; margin-top:10px; font-size:0.8rem; color:white;">⚠️ 부담상한 적용됨</div>' if res['capped'] else ''}
            </div>
        """, unsafe_allow_html=True)

        # Waterfall 차트 디자인 개선
        fig = go.Figure(go.Waterfall(
            orientation="v",
            measure=["absolute", "relative", "total"],
            x=["기본 보험료", "품목 가산", "최종 산출"],
            y=[res["segment_adjusted"], res["item_addon"], 0],
            text=[f"₩{res['segment_adjusted']:,.0f}", f"+₩{res['item_addon']:,.0f}", f"₩{res['final']:,.0f}"],
            textposition="outside",
            connector={"line": {"color": "#444", "width": 1, "dash": "dot"}},
            increasing={"marker": {"color": "#f97316"}},  # 오렌지색
            totals={"marker": {"color": "#FFFFFF"}} # 보라색
        ))

        fig.update_layout(
            height=300,
            margin=dict(l=20, r=20, t=50, b=20),
            plot_bgcolor="rgba(0,0,0,0)",
            paper_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#f1f5f9"),
            showlegend=False,
            yaxis=dict(showgrid=True, gridcolor="#2d3148", zeroline=False)
        )

        st.plotly_chart(fig, use_container_width=True)

        with st.expander("📝 산출 공식 상세"):
            st.caption(f"기본 리스크 점수: {res['risk_score']:.1f}")
            st.caption(f"리스크 가산: x{res['risk_mult']:.2f}")
            st.caption(f"세그먼트 보정: x{res['segment_mult']:.2f}")