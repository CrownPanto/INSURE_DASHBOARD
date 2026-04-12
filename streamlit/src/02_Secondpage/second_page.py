
import streamlit as st
import plotly.graph_objects as go
from utils import PRESETS, SEGMENTS_A, SEGMENTS_B, COVERAGE_ITEMS, calc_premium
import utils

def show_page(session, selected_ym):
    st.markdown("""
        <style>
        .character-card {
            border-radius: 10px;
            padding: 12px 8px 10px 8px;
            text-align: center;
            transition: all 0.2s ease;
            cursor: pointer;
            border: 2px solid #2d3148;
            background: #1c1f2e;
        }
        .character-card:hover {
            border-color: #6366F1;
            box-shadow: 0 4px 12px rgba(99,102,241,0.2);
        }
        .active-card {
            background: linear-gradient(145deg, #2d3148 0%, #3f445e 100%);
            border-color: #6366F1 !important;
            box-shadow: 0 0 12px rgba(99,102,241,0.35);
        }
        /* 선택 버튼 — secondary (미선택) */
        div[data-testid="stButton"] > button[kind="secondary"] {
            background-color: #334155 !important;
            color: #e2e8f0 !important;
            border: 1px solid #475569 !important;
            border-radius: 6px !important;
            font-size: 0.78rem !important;
            font-weight: 600 !important;
        }
        div[data-testid="stButton"] > button[kind="secondary"]:hover {
            background-color: #475569 !important;
            border-color: #6366F1 !important;
            color: #ffffff !important;
        }
        /* 선택 버튼 — primary (선택됨) */
        div[data-testid="stButton"] > button[kind="primary"] {
            background-color: #6366F1 !important;
            color: #ffffff !important;
            border: none !important;
            border-radius: 6px !important;
            font-size: 0.78rem !important;
            font-weight: 700 !important;
        }
        </style>
    """, unsafe_allow_html=True)

    st.markdown("""
        <div style="background:#1e293b; border-bottom:2px solid #334155;
                    padding:18px 24px 14px 24px; margin-bottom:16px;
                    border-radius:0 0 10px 10px;">
            <div style="color:#f1f5f9; font-size:1.5rem; font-weight:800;
                        letter-spacing:-0.5px; line-height:1.2;">
                🎯 맞춤 보험 시뮬레이터
            </div>
            <div style="color:#94a3b8; font-size:0.85rem; margin-top:5px;">
                고객 유형에 맞는 최적의 보장 설계를 시뮬레이션 하세요.
            </div>
        </div>
    """, unsafe_allow_html=True)

    with st.expander("📖 사용 가이드"):
        st.markdown("""
            <div style="padding:4px 0;">
                <div style="color:#1e293b; font-size:0.9rem; font-weight:700; margin-bottom:10px;">
                    🏠 동산보험이란?
                </div>
                <div style="color:#334155; font-size:0.85rem; line-height:1.7; margin-bottom:14px;
                            background:#f8fafc; border-left:3px solid #6366f1;
                            padding:8px 12px; border-radius:0 6px 6px 0;">
                    집 안의 <b>가전제품·전자기기·가구</b> 등이 <b>화재·도난·파손</b>으로
                    손해를 입었을 때 보상하는 보험입니다.
                </div>
            </div>
        """, unsafe_allow_html=True)

        terms = [
            ("💰", "기본 보험료", "거주 지역 위험도 + 가구 유형으로 결정", "#6366f1", "#eef2ff"),
            ("➕", "품목 가산",   "선택 품목의 가치·파손 확률 반영 추가 금액", "#f97316", "#fff7ed"),
            ("⚠️", "리스크 점수", "화재·도난·건물 위험도를 0~100점으로 환산", "#ef4444", "#fef2f2"),
            ("🛡️", "부담상한",   "보험료가 월소득 2% 초과 시 자동으로 낮아짐", "#10b981", "#f0fdf4"),
        ]
        cols = st.columns(4)
        for col, (icon, term, desc, color, bg) in zip(cols, terms):
            col.markdown(f"""
                <div style="background:{bg}; border:1px solid {color}40;
                            border-top:3px solid {color}; border-radius:8px;
                            padding:10px 12px; text-align:center;">
                    <div style="font-size:1.3rem; margin-bottom:4px;">{icon}</div>
                    <div style="color:{color}; font-size:0.8rem; font-weight:800;
                                margin-bottom:4px;">{term}</div>
                    <div style="color:#475569; font-size:0.7rem; line-height:1.5;">{desc}</div>
                </div>
            """, unsafe_allow_html=True)

    # ══ STEP 1 · 고객 프로필 선택 (컴팩트) ══
    st.markdown("""
        <div style="background:#e0e7ff; border-left:5px solid #6366F1;
                    border-radius:8px; padding:10px 18px;
                    display:flex; align-items:center; gap:14px; margin:8px 0 16px 0;">
            <div style="background:#6366F1; color:#fff; font-size:0.7rem; font-weight:800;
                        padding:4px 12px; border-radius:20px; letter-spacing:1px;
                        white-space:nowrap;">STEP 1</div>
            <span style="color:#1e1b4b; font-size:1rem; font-weight:800;">
                고객 프로필 선택</span>
            <span style="color:#4338ca; font-size:0.8rem; margin-left:4px;">
                — 나와 비슷한 유형을 골라보세요</span>
        </div>
    """, unsafe_allow_html=True)

    if "selected_preset" not in st.session_state:
        st.session_state["selected_preset"] = 0

    for row in range(2):
        p_cols = st.columns(5)
        for col_idx in range(5):
            i = row * 5 + col_idx
            if i >= len(PRESETS):
                break
            p = PRESETS[i]
            with p_cols[col_idx]:
                is_selected = i == st.session_state["selected_preset"]
                active_class = "active-card" if is_selected else ""
                st.markdown(f"""
                    <div class="character-card {active_class}">
                        <div style="font-size:0.6rem; color:#6366F1; font-weight:700;
                                    letter-spacing:1px;">{p['id']}</div>
                        <div style="font-size:1.6rem; margin:4px 0 3px 0;">{p['icon']}</div>
                        <div style="font-weight:700; color:#fff; font-size:0.78rem;
                                    line-height:1.3; margin-bottom:2px;">{p['name']}</div>
                        <div style="font-size:0.62rem; color:#818cf8; font-weight:600;">
                            {p.get('premium_range','')}</div>
                        {'<div style="color:#a5b4fc; font-weight:700; font-size:0.68rem; margin-top:4px;">✓ 선택됨</div>' if is_selected else ''}
                    </div>
                """, unsafe_allow_html=True)
                if st.button("선택", key=f"p_{i}", use_container_width=True,
                             type="primary" if is_selected else "secondary"):
                    st.session_state["selected_preset"] = i
                    st.rerun()

    sel = PRESETS[st.session_state["selected_preset"]]

    st.markdown("""
        <div style="background:#e0f2fe; border-left:5px solid #0ea5e9;
                    border-radius:8px; padding:10px 18px;
                    display:flex; align-items:center; gap:14px; margin:20px 0 16px 0;">
            <div style="background:#0ea5e9; color:#fff; font-size:0.7rem; font-weight:800;
                        padding:4px 12px; border-radius:20px; letter-spacing:1px;
                        white-space:nowrap;">STEP 2</div>
            <span style="color:#0c4a6e; font-size:1rem; font-weight:800;">
                보장 설정</span>
            <span style="color:#0369a1; font-size:0.8rem; margin-left:4px;">
                — 보험에 포함할 품목을 선택하세요</span>
        </div>
    """, unsafe_allow_html=True)

    # ══ STEP 2 · 페르소나 배너 ══
    st.markdown(f"""
        <div style="background:linear-gradient(135deg,#1e293b 0%,#0f172a 100%);
                    padding:16px 20px; border-radius:12px; border:1px solid #334155;
                    border-left:5px solid #6366F1; margin-bottom:20px;">
            <div style="color:#94a3b8; font-size:0.7rem; font-weight:600;
                        text-transform:uppercase; letter-spacing:0.5px; margin-bottom:4px;">
                선택된 페르소나
            </div>
            <div style="color:#fff; font-size:1.05rem; font-weight:700; margin-bottom:8px;">
                {sel['icon']} {sel['persona']}
            </div>
            <span style="background:rgba(255,255,255,0.08); border:1px solid #475569;
                         color:#cbd5e1; padding:2px 10px; border-radius:20px;
                         font-size:0.75rem; margin-right:8px;">📍 {sel['district']}</span>
            <span style="background:rgba(16,185,129,0.1); border:1px solid #10b981;
                         color:#34d399; padding:2px 10px; border-radius:20px;
                         font-size:0.75rem;">💰 연소득 {sel['income']}백만원</span>
        </div>
    """, unsafe_allow_html=True)

    # ══ STEP 3 · 보장 품목 선택 ══
    st.markdown("**📦 보장 품목 선택** — 체크할수록 보장이 넓어지지만 보험료도 올라갑니다.")

    item_keys = list(utils.COVERAGE_ITEMS.keys())
    selected_items = []

    item_cols = st.columns(3)
    for idx, name in enumerate(item_keys):
        info = utils.COVERAGE_ITEMS[name]
        monthly_cost = info["limit"] * info["damage_rate"] / 12
        is_default = name in sel["default_items"]
        with item_cols[idx % 3]:
            st.markdown(f"""
                <div style="background:#1e293b; border:1px solid #334155;
                            border-radius:10px; padding:12px 14px; margin-bottom:4px;">
                    <span style="font-size:1.4rem;">{info['icon']}</span>
                    <span style="float:right; color:#64748b; font-size:0.58rem;
                                 text-transform:uppercase; text-align:right; line-height:1.4;">
                        보장한도<br>
                        <b style="color:#e2e8f0; font-size:0.78rem;">
                            ₩{info['limit']//10000:,}만원</b>
                    </span>
                    <div style="color:#fff; font-weight:700; font-size:0.88rem;
                                margin:6px 0 2px 0;">{name}</div>
                    <div style="color:#64748b; font-size:0.65rem;
                                margin-bottom:6px;">{info['examples']}</div>
                    <span style="background:rgba(16,185,129,0.12);
                                 border:1px solid rgba(16,185,129,0.3);
                                 border-radius:5px; padding:2px 7px;
                                 color:#34d399; font-size:0.7rem; font-weight:600;">
                        +₩{monthly_cost:,.0f}/월</span>
                </div>
            """, unsafe_allow_html=True)
            checked = st.checkbox("보장에 포함", value=is_default,
                                  key=f"final_chk_{name}")
            if checked:
                selected_items.append(name)

    # ══ 선택된 보장 상세 ══
    if selected_items:
        st.markdown('<div style="margin-top:12px;"></div>', unsafe_allow_html=True)
        st.markdown("**✅ 선택된 보장 상세**")
        det_cols = st.columns(len(selected_items))
        for idx, it in enumerate(selected_items):
            ci = utils.COVERAGE_ITEMS[it]
            with det_cols[idx]:
                st.markdown(f"""
                    <div style="background:#1e293b; border:1px solid #334155;
                                border-top:3px solid #6366F1; border-radius:8px;
                                padding:10px 12px; text-align:center;">
                        <div style="font-size:1.4rem;">{ci['icon']}</div>
                        <div style="color:#fff; font-weight:700; font-size:0.85rem;
                                    margin:4px 0 2px 0;">{it}</div>
                        <div style="color:#64748b; font-size:0.65rem;">Limit</div>
                        <div style="color:#a5b4fc; font-weight:700; font-size:0.9rem;">
                            ₩{ci['limit']:,.0f}</div>
                    </div>
                """, unsafe_allow_html=True)

    st.markdown("""
        <div style="background:#d1fae5; border-left:5px solid #10b981;
                    border-radius:8px; padding:10px 18px;
                    display:flex; align-items:center; gap:14px; margin:24px 0 16px 0;">
            <div style="background:#10b981; color:#fff; font-size:0.7rem; font-weight:800;
                        padding:4px 12px; border-radius:20px; letter-spacing:1px;
                        white-space:nowrap;">STEP 3</div>
            <span style="color:#064e3b; font-size:1rem; font-weight:800;">
                산출 결과</span>
            <span style="color:#047857; font-size:0.8rem; margin-left:4px;">
                — 예상 보험료와 리스크 분석</span>
        </div>
    """, unsafe_allow_html=True)

    # ══ STEP 4 · 산출 결과 ══
    res = calc_premium(sel["district"], sel["seg_a"], sel["seg_b"],
                       income=sel["income"], selected_items=selected_items)

    risk = res["risk_score"]
    monthly_income = sel["income"] * 1_000_000 / 12
    burden_pct = res["final"] / monthly_income * 100
    addon_pct = res["item_addon"] / res["final"] * 100 if res["final"] > 0 else 0
    cap_amount = monthly_income * 0.02

    if risk < 20:
        risk_label, risk_color, risk_emoji = "극도 안전", "#10B981", "😌"
    elif risk < 40:
        risk_label, risk_color, risk_emoji = "안전", "#84CC16", "🙂"
    elif risk < 55:
        risk_label, risk_color, risk_emoji = "보통", "#EAB308", "😐"
    elif risk < 70:
        risk_label, risk_color, risk_emoji = "위험", "#F97316", "😟"
    else:
        risk_label, risk_color, risk_emoji = "극도 위험", "#EF4444", "😱"

    # ① 월 보험료 박스
    capped_msg = (
        f'<div style="background:rgba(251,191,36,0.15); border:1px solid #F59E0B; '
        f'border-radius:6px; padding:6px 12px; margin-top:10px; font-size:0.8rem; color:#FCD34D;">'
        f'⚠️ 부담상한 적용 — 원래 ₩{res["total_with_items"]:,.0f} → 월소득 2% 상한 ₩{cap_amount:,.0f}</div>'
    ) if res['capped'] else ''

    st.markdown(f"""
        <div style="background:linear-gradient(135deg,#475569 0%,#1e293b 100%);
                    border:2px solid #FFFFFF; padding:20px 28px; border-radius:15px;
                    text-align:center; margin-bottom:16px;">
            <div style="color:rgba(255,255,255,0.55); font-size:0.82rem; margin-bottom:6px;">
                💰 매달 내는 보험료
            </div>
            <div style="color:white; font-size:3rem; font-weight:800; line-height:1.1;">
                ₩{res['final']:,.0f}
            </div>
            <div style="color:rgba(255,255,255,0.4); font-size:0.75rem; margin-top:6px;">
                하루 ₩{res['final']/30:,.0f} 수준
            </div>
            {capped_msg}
        </div>
    """, unsafe_allow_html=True)

    # ② KPI 카드 3개
    kc1, kc2, kc3 = st.columns(3)
    burden_color = "#10B981" if burden_pct < 1 else ("#EAB308" if burden_pct < 1.5 else "#EF4444")
    with kc1:
        st.markdown(f"""
            <div style="background:#1e293b; border:1px solid #334155;
                        border-left:4px solid {risk_color}; border-radius:10px;
                        padding:14px 16px; margin-bottom:16px;">
                <div style="color:#94a3b8; font-size:0.72rem; margin-bottom:4px;">리스크 등급</div>
                <div style="color:{risk_color}; font-size:1.2rem; font-weight:700;">
                    {risk_emoji} {risk_label}</div>
                <div style="color:#64748b; font-size:0.68rem; margin-top:2px;">{risk:.1f} / 100pt</div>
            </div>
        """, unsafe_allow_html=True)
    with kc2:
        st.markdown(f"""
            <div style="background:#1e293b; border:1px solid #334155;
                        border-left:4px solid #f97316; border-radius:10px;
                        padding:14px 16px; margin-bottom:16px;">
                <div style="color:#94a3b8; font-size:0.72rem; margin-bottom:4px;">품목 기여도</div>
                <div style="color:#f97316; font-size:1.2rem; font-weight:700;">{addon_pct:.1f}%</div>
                <div style="color:#64748b; font-size:0.68rem; margin-top:2px;">기본료 {100-addon_pct:.1f}%</div>
            </div>
        """, unsafe_allow_html=True)
    with kc3:
        st.markdown(f"""
            <div style="background:#1e293b; border:1px solid #334155;
                        border-left:4px solid {burden_color}; border-radius:10px;
                        padding:14px 16px; margin-bottom:16px;">
                <div style="color:#94a3b8; font-size:0.72rem; margin-bottom:4px;">월소득 대비 부담</div>
                <div style="color:{burden_color}; font-size:1.2rem; font-weight:700;">{burden_pct:.2f}%</div>
                <div style="color:#64748b; font-size:0.68rem; margin-top:2px;">상한 2.00%</div>
            </div>
        """, unsafe_allow_html=True)

    # ③ 게이지 + 도넛 나란히
    gc1, gc2 = st.columns([3, 2])

    with gc1:
        st.markdown('<div style="color:#94a3b8; font-size:0.72rem; font-weight:600; '
                    'text-transform:uppercase; letter-spacing:0.5px; margin-bottom:2px;">'
                    '지역 리스크 지수</div>', unsafe_allow_html=True)
        fig_risk = go.Figure()
        fig_risk.add_trace(go.Indicator(
            mode="gauge+number",
            value=risk,
            number={"font": {"color": risk_color, "size": 48, "family": "Arial Black"}, "suffix": ""},
            gauge={
                "axis": {
                    "range": [0, 100],
                    "tickvals": [0, 20, 40, 55, 70, 100],
                    "ticktext": ["0", "20", "40", "55", "70", "100"],
                    "tickcolor": "#64748b",
                    "tickfont": {"color": "#94a3b8", "size": 10},
                    "tickwidth": 1,
                },
                "bar": {"color": risk_color, "thickness": 0.30},
                "bgcolor": "rgba(0,0,0,0)",
                "borderwidth": 0,
                "steps": [
                    {"range": [0, 20],   "color": "rgba(16,185,129,0.55)"},
                    {"range": [20, 40],  "color": "rgba(132,204,22,0.50)"},
                    {"range": [40, 55],  "color": "rgba(234,179,8,0.50)"},
                    {"range": [55, 70],  "color": "rgba(249,115,22,0.50)"},
                    {"range": [70, 100], "color": "rgba(239,68,68,0.50)"},
                ],
                "threshold": {"line": {"color": "#FFFFFF", "width": 3}, "value": risk},
            },
        ))
        fig_risk.update_layout(
            height=240,
            margin=dict(l=20, r=20, t=20, b=10),
            paper_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#f1f5f9"),
            annotations=[
                dict(text="<b>극도안전</b>", x=0.02, y=0.10, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#10B981", size=9)),
                dict(text="<b>안전</b>", x=0.20, y=0.32, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#84CC16", size=9)),
                dict(text="<b>보통</b>", x=0.50, y=0.44, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#EAB308", size=9)),
                dict(text="<b>위험</b>", x=0.76, y=0.32, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#F97316", size=9)),
                dict(text="<b>극도위험</b>", x=0.97, y=0.10, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#EF4444", size=9)),
                dict(text=f"<b>{risk_emoji} {risk_label}</b>",
                     x=0.5, y=-0.05, xref="paper", yref="paper",
                     showarrow=False, font=dict(color=risk_color, size=15)),
            ],
        )
        st.plotly_chart(fig_risk, use_container_width=True)

    with gc2:
        # 도넛 제목 + 수치 요약 카드
        base_pct_disp = 100 - addon_pct
        st.markdown(f"""
            <div style="background:#1e293b; border:1px solid #334155; border-radius:12px;
                        padding:14px 16px; margin-bottom:6px;">
                <div style="color:#94a3b8; font-size:0.68rem; font-weight:600;
                            text-transform:uppercase; letter-spacing:0.5px;
                            margin-bottom:10px;">보험료 구성</div>
                <div style="display:grid; grid-template-columns:1fr 1fr; gap:8px;">
                    <div style="background:rgba(99,102,241,0.15); border:1px solid #6366F1;
                                border-radius:8px; padding:8px 10px;">
                        <div style="color:#a5b4fc; font-size:0.62rem; margin-bottom:2px;">
                            기본 보험료</div>
                        <div style="color:#fff; font-size:0.95rem; font-weight:800;">
                            {base_pct_disp:.0f}%</div>
                        <div style="color:#6366F1; font-size:0.65rem;">
                            ₩{res['segment_adjusted']:,.0f}</div>
                    </div>
                    <div style="background:rgba(249,115,22,0.15); border:1px solid #f97316;
                                border-radius:8px; padding:8px 10px;">
                        <div style="color:#fdba74; font-size:0.62rem; margin-bottom:2px;">
                            품목 가산</div>
                        <div style="color:#fff; font-size:0.95rem; font-weight:800;">
                            {addon_pct:.0f}%</div>
                        <div style="color:#f97316; font-size:0.65rem;">
                            ₩{res['item_addon']:,.0f}</div>
                    </div>
                </div>
            </div>
        """, unsafe_allow_html=True)

        fig_pie = go.Figure()
        fig_pie.add_trace(go.Pie(
            labels=["기본 보험료", "품목 가산"],
            values=[res["segment_adjusted"], max(res["item_addon"], 0)],
            hole=0.62,
            marker=dict(
                colors=["#6366F1", "#f97316"],
                line=dict(color="#0f172a", width=4),
            ),
            textinfo="percent",
            textposition="outside",
            textfont=dict(color="#e2e8f0", size=13, family="Arial Black"),
            hovertemplate="<b>%{label}</b><br>₩%{value:,.0f} (%{percent})<extra></extra>",
            direction="clockwise", sort=False,
            pull=[0.04, 0.04],
        ))
        fig_pie.update_layout(
            height=200,
            margin=dict(l=30, r=30, t=10, b=10),
            paper_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#f1f5f9", size=11),
            showlegend=False,
            annotations=[dict(
                text=f"<b>부담률</b><br><b>{burden_pct:.1f}%</b>",
                x=0.5, y=0.5, xref="paper", yref="paper",
                showarrow=False,
                font=dict(color="#FFFFFF", size=13), align="center"
            )],
        )
        st.plotly_chart(fig_pie, use_container_width=True)

    # ④ 워터폴
    st.markdown('<div style="color:#94a3b8; font-size:0.72rem; font-weight:600; '
                'text-transform:uppercase; letter-spacing:0.5px; margin:4px 0 6px 0;">'
                '보험료 산출 내역</div>', unsafe_allow_html=True)

    item_costs = []
    for it in selected_items:
        ci = utils.COVERAGE_ITEMS[it]
        cost = ci["limit"] * ci["damage_rate"] / 12
        item_costs.append({"name": f"{ci['icon']} {it}", "cost": cost})
    item_costs.sort(key=lambda x: x["cost"], reverse=True)

    if risk < 40:
        risk_plain = "비교적 안전한 지역에 거주 중이에요."
    elif risk < 55:
        risk_plain = "보통 수준의 위험 지역이에요. 기본 보장이면 충분할 수 있어요."
    else:
        risk_plain = "위험도가 높은 지역이에요. 보장 범위를 넓히는 걸 권장해요."
    top_item = item_costs[0]["name"] if item_costs else None
    item_plain = f"선택한 품목 중 **{top_item}** 이 보험료에 가장 큰 영향을 줬어요." if top_item else "선택한 품목이 없어요."
    burden_plain = ("소득 대비 보험료 부담이 매우 낮은 편이에요 ✅" if burden_pct < 1
                    else ("적정 수준의 부담이에요." if burden_pct < 1.5
                          else "소득 대비 보험료가 다소 높아요. 품목을 줄여보세요."))
    st.info(f"💡 **{risk_plain}** {item_plain} {burden_plain}")

    base      = res["segment_adjusted"]
    addon_sum = res["item_addon"]
    total     = res["final"]

    item_palette = ["#fb923c", "#fbbf24", "#fcd34d", "#a78bfa", "#67e8f9", "#86efac"]
    labels = (["기본 보험료"]
              + [ic["name"] for ic in item_costs]
              + ["품목 가산", "최종 보험료"])
    values = ([base]
              + [ic["cost"] for ic in item_costs]
              + [addon_sum, total])
    bar_colors = (["#6366F1"]
                  + [item_palette[i % len(item_palette)] for i in range(len(item_costs))]
                  + ["#F59E0B", "#10B981"])

    fig_wf = go.Figure()
    for i, (lbl, val, bc) in enumerate(zip(labels, values, bar_colors)):
        is_summary = lbl in ("품목 가산", "최종 보험료")
        pct = val / total * 100 if total > 0 else 0
        fig_wf.add_trace(go.Bar(
            name=lbl, x=[lbl], y=[val],
            marker=dict(color=bc,
                        line=dict(color="rgba(255,255,255,0.2)", width=1),
                        cornerradius=5),
            text=f"<b>₩{val:,.0f}</b><br><span style='font-size:9px'>({pct:.0f}%)</span>",
            textposition="outside",
            textfont=dict(color="#FFFFFF", size=10),
            width=0.5 if is_summary else 0.42,
            hovertemplate=f"<b>{lbl}</b><br>₩{val:,.0f} ({pct:.1f}%)<extra></extra>",
        ))

    fig_wf.add_hline(y=total, line_dash="dash", line_color="#10B981", line_width=1.5,
                     annotation_text=f" 최종 ₩{total:,.0f}", annotation_position="top left",
                     annotation_font=dict(color="#10B981", size=10))
    if item_costs:
        fig_wf.add_vline(x=len(item_costs) + 0.5, line_dash="dot",
                         line_color="#4B5563", line_width=1)

    fig_wf.update_layout(
        height=310,
        margin=dict(l=10, r=10, t=55, b=10),
        plot_bgcolor="rgba(0,0,0,0.85)",
        paper_bgcolor="rgba(0,0,0,0.85)",
        font=dict(color="#f1f5f9", size=11),
        showlegend=False, bargap=0.3,
        xaxis=dict(tickfont=dict(color="#E2E8F0", size=10), showgrid=False, zeroline=False),
        yaxis=dict(tickfont=dict(color="#94a3b8", size=9), tickprefix="₩",
                   showgrid=True, gridcolor="rgba(75,85,99,0.3)", zeroline=False),
        annotations=[
            dict(text="← 품목별 기여",
                 x=(len(item_costs)) / max(len(labels), 1) * 0.72,
                 y=1.08, xref="paper", yref="paper",
                 showarrow=False, font=dict(color="#94a3b8", size=9)),
            dict(text="합산 →",
                 x=0.92, y=1.08, xref="paper", yref="paper",
                 showarrow=False, font=dict(color="#94a3b8", size=9)),
        ],
    )
    st.plotly_chart(fig_wf, use_container_width=True)

    with st.expander("📝 산출 공식 상세"):
        st.caption(f"기본 리스크 점수: {res['risk_score']:.1f}")
        st.caption(f"리스크 가산: ×{res['risk_mult']:.2f}")
        st.caption(f"세그먼트 보정: ×{res['segment_mult']:.2f}")
