
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
            color: white !important;
            margin-bottom: 5px;
            font-size: 1.1rem;
        }
        .card-desc {
            font-size: 0.85rem;
            color: white !important;
        }
        /* 결과 요약 컨테이너 */
        .result-box {
            background: #111827;
            border-radius: 12px;
            padding: 20px;
            border: 1px solid #2d3148;
        }
        /* 페르소나 배너 텍스트 */
        .persona-label {
            color: #94a3b8 !important;
            font-size: 0.85rem;
            font-weight: 600;
            margin-bottom: 5px;
            text-transform: uppercase;
        }
        .persona-title {
            margin: 0;
            color: #FFFFFF !important;
            font-size: 1.4rem;
        }
        .persona-badge {
            color: #FFFFFF !important;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.9rem;
            font-weight: 600;
        }
        /* 선택된 보장 상세 카드 텍스트 */
        .coverage-name {
            color: #FFFFFF !important;
            font-size: 1.1rem;
            font-weight: 700;
        }
        .coverage-limit-label {
            color: #94a3b8 !important;
            font-size: 0.7rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        .coverage-limit-value {
            color: #FFFFFF !important;
            font-size: 1.1rem;
            font-weight: 700;
        }
        </style>
    """, unsafe_allow_html=True)

    st.title("🎯 맞춤 보험 시뮬레이터")
    st.caption("고객 유형에 맞는 최적의 보장 설계를 시뮬레이션 하세요.")

    # ─── 사용 가이드 ───
    with st.expander("📖 이 페이지는 어떻게 사용하나요? (처음이시라면 클릭!)"):
        st.markdown("""
        **동산보험**이란, 집 안의 **가전제품·전자기기·가구 등 물건(동산)**이 화재·도난·파손으로 손해를 입었을 때 보상해주는 보험입니다.

        ---
        **시뮬레이터 사용 순서**

        1. **고객 프로필 선택** — 나와 비슷한 유형의 고객 카드를 고르세요.
        2. **보장 품목 선택** — 보험에 포함할 물건 종류를 체크하세요. 많이 체크할수록 보험료가 올라갑니다.
        3. **산출 결과 확인** — 예상 월 보험료와 리스크 분석 결과를 오른쪽에서 확인하세요.

        ---
        **용어 설명**

        | 용어 | 설명 |
        |------|------|
        | 기본 보험료 | 살고 있는 동네의 위험도 + 가구 유형에 따라 결정되는 기본 금액 |
        | 품목 가산 | 선택한 물건들의 가치와 파손 확률을 반영한 추가 금액 |
        | 리스크 점수 | 거주 지역의 화재·도난·건물 위험도를 0~10점으로 환산한 수치 |
        | 부담상한 | 보험료가 월 소득의 2%를 넘지 않도록 자동으로 조정하는 제도 |
        | 보장한도(Limit) | 사고 발생 시 해당 품목에 대해 최대 보상받을 수 있는 금액 |
        """)

    # ─── 2. 캐릭터 프로필 선택 (카드 UI) ───
    st.subheader("고객 프로필 선택")

    if "selected_preset" not in st.session_state:
        st.session_state["selected_preset"] = 0

    # 10개 카드를 5+5 두 줄로 표시
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
                        <div style="font-size:0.7rem; color:#94a3b8; font-weight:700;
                                    letter-spacing:1px; margin-bottom:4px;">{p['id']}</div>
                        <span class="icon-circle">{p['icon']}</span>
                        <div class="card-title">{p['name']}</div>
                        <div class="card-desc">{p['desc']}</div>
                        <div style="color:#6366F1; font-size:0.78rem; margin-top:6px; font-weight:600;">
                            {p.get('premium_range', '')}
                        </div>
                        {'<div style="color:#FFFFFF; font-weight:bold; margin-top:8px; font-size:0.8rem;">✓ SELECTED</div>' if is_selected else ''}
                    </div>
                """, unsafe_allow_html=True)

                if st.button("선택", key=f"p_{i}", use_container_width=True,
                             type="primary" if is_selected else "secondary"):
                    st.session_state["selected_preset"] = i
                    st.rerun()
        st.markdown('<div style="margin-bottom:8px;"></div>', unsafe_allow_html=True)

    # ─── 3. 상세 설정 섹션 ───
    sel = PRESETS[st.session_state["selected_preset"]]
    st.markdown("---")

    col_left, col_right = st.columns([3, 2], gap="large")

    with col_left:
        # 1. 사용자 페르소나 배너 (흰색 강조)
        st.markdown(f"""
            <div style="background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
                        padding: 20px; border-radius: 15px; border: 1px solid #334155;
                        border-left: 6px solid #FFFFFF; margin-bottom: 25px;">
                <div class="persona-label">User Persona Settings</div>
                <h3 class="persona-title">🛠️ {sel['persona']}</h3>
                <div style="margin-top: 15px; display: flex; gap: 10px;">
                    <span class="persona-badge" style="background: rgba(255,255,255,0.1); border: 1px solid #FFFFFF;">
                        📍 {sel['district']}
                    </span>
                    <span class="persona-badge" style="background: rgba(16,185,129,0.1); border: 1px solid #10B981;">
                        💰 연소득 {sel['income']}백만원
                    </span>
                </div>
            </div>
        """, unsafe_allow_html=True)

        # 2. 보장 품목 라이브러리
        st.markdown(
            '<p style="color: #FFFFFF !important; font-size: 1.3rem; font-weight: 700; margin-bottom: 5px;">📚 보장 품목 라이브러리</p>',
            unsafe_allow_html=True)
        st.markdown(
            '<p style="color: #D1D5DB !important; font-size: 0.95rem; margin-bottom: 5px;">보험에 포함할 물건 종류를 선택하세요. 체크할수록 보장이 넓어지지만 보험료도 올라갑니다.</p>',
            unsafe_allow_html=True)

        item_keys = list(utils.COVERAGE_ITEMS.keys())
        selected_items = []

        # 카드 그리드 배치
        for i in range(0, len(item_keys), 2):
            cols = st.columns(2)
            for j in range(2):
                if i + j < len(item_keys):
                    name = item_keys[i + j]
                    info = utils.COVERAGE_ITEMS[name]
                    monthly_cost = info["limit"] * info["damage_rate"] / 12
                    is_default = name in sel["default_items"]
                    with cols[j]:
                        st.markdown(f"""
                            <div style="background:{'rgba(99,102,241,0.12)' if is_default else '#1e293b'};
                                        border:1px solid {'#6366F1' if is_default else '#334155'};
                                        border-radius:12px; padding:14px 16px; margin-bottom:2px;">
                                <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                                    <span style="font-size:1.6rem; line-height:1;">{info['icon']}</span>
                                    <div style="text-align:right;">
                                        <div style="color:#64748b; font-size:0.6rem; text-transform:uppercase; letter-spacing:0.5px;">보장한도</div>
                                        <div style="color:#e2e8f0; font-size:0.82rem; font-weight:700;">₩{info['limit']//10000:,}만원</div>
                                    </div>
                                </div>
                                <div style="color:#ffffff; font-weight:700; font-size:0.95rem; margin:8px 0 3px 0;">{name}</div>
                                <div style="color:#94a3b8; font-size:0.7rem; margin-bottom:6px;">{info['examples']}</div>
                                <div style="background:rgba(16,185,129,0.12); border:1px solid rgba(16,185,129,0.25);
                                            border-radius:6px; padding:4px 8px; display:inline-block;">
                                    <span style="color:#34d399; font-size:0.72rem; font-weight:600;">+₩{monthly_cost:,.0f}/월</span>
                                </div>
                            </div>
                        """, unsafe_allow_html=True)
                        checked = st.checkbox(
                            "보장에 포함",
                            value=is_default,
                            key=f"final_chk_{name}",
                        )
                        if checked:
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
                            <span class="coverage-name">{it}</span>
                        </div>
                        <div style="text-align: right;">
                            <div class="coverage-limit-label">Limit</div>
                            <div class="coverage-limit-value">₩{ci['limit']:,.0f}</div>
                        </div>
                    </div>
                """, unsafe_allow_html=True)

    with col_right:
        st.subheader("💰 산출 결과")
        res = calc_premium(sel["district"], sel["seg_a"], sel["seg_b"], income=sel["income"],
                           selected_items=selected_items)

        # 가격 강조 박스
        monthly_income_display = sel["income"] * 1_000_000 / 12
        cap_amount = monthly_income_display * 0.02
        capped_msg = f'<div style="background:rgba(251,191,36,0.15); border:1px solid #F59E0B; border-radius:8px; padding:8px 12px; margin-top:12px; font-size:0.82rem; color:#FCD34D; text-align:left;">⚠️ <b>부담상한 적용</b> — 원래 보험료(₩{res["total_with_items"]:,.0f})가 월소득의 2%(₩{cap_amount:,.0f})를 초과해 자동으로 낮아졌어요.</div>' if res['capped'] else ''
        st.markdown(f"""
            <div style="background: linear-gradient(135deg, #475569 0%, #1e293b 100%); border: 2px solid #FFFFFF; padding: 25px; border-radius: 15px; text-align: center; margin-bottom: 20px;">
                <div style="color: rgba(255,255,255,0.6); font-size: 0.85rem; margin-bottom: 4px;">매달 내는 보험료</div>
                <div style="color: white; font-size: 2.5rem; font-weight: 800;">₩{res['final']:,.0f}</div>
                <div style="color: rgba(255,255,255,0.5); font-size: 0.78rem; margin-top:4px;">하루 ₩{res['final']/30:,.0f} 수준</div>
                {capped_msg}
            </div>
        """, unsafe_allow_html=True)

        # ── 인사이트 차트 (리스크 게이지 + 보험료 구성) ──
        risk = res["risk_score"]  # 0~100 스케일
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

        addon_pct = res["item_addon"] / res["final"] * 100 if res["final"] > 0 else 0
        base_pct = 100 - addon_pct
        monthly_income = sel["income"] * 1_000_000 / 12
        burden_pct = res["final"] / monthly_income * 100

        # ── 공포·탐욕 스타일 리스크 게이지 (단독) ──
        fig_risk = go.Figure()
        fig_risk.add_trace(go.Indicator(
            mode="gauge+number",
            value=risk,
            number={"font": {"color": risk_color, "size": 38, "family": "Arial Black"}, "suffix": ""},
            gauge={
                "axis": {
                    "range": [0, 100],
                    "tickvals": [0, 20, 40, 55, 70, 100],
                    "ticktext": ["0", "20", "40", "55", "70", "100"],
                    "tickcolor": "#475569",
                    "tickfont": {"color": "#64748b", "size": 9},
                },
                "bar": {"color": risk_color, "thickness": 0.28},
                "bgcolor": "rgba(0,0,0,0)",
                "borderwidth": 0,
                "steps": [
                    {"range": [0, 20],   "color": "rgba(16,185,129,0.30)"},
                    {"range": [20, 40],  "color": "rgba(132,204,22,0.28)"},
                    {"range": [40, 55],  "color": "rgba(234,179,8,0.28)"},
                    {"range": [55, 70],  "color": "rgba(249,115,22,0.28)"},
                    {"range": [70, 100], "color": "rgba(239,68,68,0.28)"},
                ],
                "threshold": {"line": {"color": "#FFFFFF", "width": 3}, "value": risk},
            },
        ))
        fig_risk.update_layout(
            height=210,
            margin=dict(l=20, r=20, t=20, b=0),
            paper_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#f1f5f9"),
            annotations=[
                # 구간 레이블
                dict(text="극도<br>안전", x=0.04, y=0.18, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#10B981", size=8), align="center"),
                dict(text="안전", x=0.22, y=0.36, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#84CC16", size=8), align="center"),
                dict(text="보통", x=0.50, y=0.47, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#EAB308", size=8), align="center"),
                dict(text="위험", x=0.73, y=0.36, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#F97316", size=8), align="center"),
                dict(text="극도<br>위험", x=0.93, y=0.18, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#EF4444", size=8), align="center"),
                # 현재 등급 표시
                dict(text=f"<b>{risk_emoji} {risk_label}</b>",
                     x=0.5, y=-0.06, xref="paper", yref="paper",
                     showarrow=False, font=dict(color=risk_color, size=15), align="center"),
            ],
        )
        st.plotly_chart(fig_risk, use_container_width=True)

        # ── 보험료 구성 도넛 (단독) ──
        fig = go.Figure()
        fig.add_trace(go.Pie(
            labels=["기본 보험료", "품목 가산"],
            values=[res["segment_adjusted"], max(res["item_addon"], 0)],
            hole=0.62,
            marker=dict(
                colors=["#6366F1", "#f97316"],
                line=dict(color="#1e293b", width=2),
            ),
            textinfo="percent",
            textfont=dict(color="#FFFFFF", size=12),
            hovertemplate="<b>%{label}</b><br>₩%{value:,.0f} (%{percent})<extra></extra>",
            direction="clockwise",
            sort=False,
        ))

        fig.update_layout(
            height=220,
            margin=dict(l=10, r=10, t=30, b=10),
            paper_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#f1f5f9", size=11),
            showlegend=True,
            legend=dict(
                orientation="h",
                x=0.5, y=-0.08, xanchor="center",
                font=dict(color="#CBD5E1", size=10),
                bgcolor="rgba(0,0,0,0)",
            ),
            annotations=[
                dict(text=f"<b>부담률</b><br>{burden_pct:.1f}%",
                     x=0.5, y=0.5, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#CBD5E1", size=13), align="center"),
                dict(text="보험료 구성", x=0.5, y=1.05, xref="paper", yref="paper",
                     showarrow=False, font=dict(color="#94a3b8", size=12)),
            ],
        )

        st.plotly_chart(fig, use_container_width=True)

        # 인사이트 요약 카드
        st.markdown(f"""
            <div style="display:flex; gap:10px; margin-top:5px;">
                <div style="flex:1; background:#1e293b; border:1px solid #334155; border-left:4px solid {risk_color};
                            border-radius:8px; padding:10px 14px;">
                    <div style="color:#94a3b8; font-size:0.75rem; margin-bottom:3px;">리스크 등급</div>
                    <div style="color:{risk_color}; font-size:1.1rem; font-weight:700;">{risk_label} ({risk:.1f}pt)</div>
                </div>
                <div style="flex:1; background:#1e293b; border:1px solid #334155; border-left:4px solid #f97316;
                            border-radius:8px; padding:10px 14px;">
                    <div style="color:#94a3b8; font-size:0.75rem; margin-bottom:3px;">품목 기여도</div>
                    <div style="color:#f97316; font-size:1.1rem; font-weight:700;">{addon_pct:.1f}%</div>
                </div>
                <div style="flex:1; background:#1e293b; border:1px solid #334155; border-left:4px solid #6366F1;
                            border-radius:8px; padding:10px 14px;">
                    <div style="color:#94a3b8; font-size:0.75rem; margin-bottom:3px;">월소득 대비 부담</div>
                    <div style="color:#818CF8; font-size:1.1rem; font-weight:700;">{burden_pct:.2f}%</div>
                </div>
            </div>
        """, unsafe_allow_html=True)

        # ── 보험료 구성 상세 차트 (품목별 기여도) ──
        st.markdown('<div style="color:#94a3b8; font-size:0.8rem; margin:12px 0 4px 0; font-weight:600; text-transform:uppercase;">보험료 산출 내역</div>', unsafe_allow_html=True)

        # 품목별 월 보험료 계산
        item_costs = []
        for it in selected_items:
            ci = utils.COVERAGE_ITEMS[it]
            cost = ci["limit"] * ci["damage_rate"] / 12
            item_costs.append({"name": f"{ci['icon']} {it}", "cost": cost})
        item_costs.sort(key=lambda x: x["cost"], reverse=True)

        # ── 한 줄 인사이트 요약 ──
        if risk < 40:
            risk_plain = "비교적 안전한 지역에 거주 중이에요."
        elif risk < 55:
            risk_plain = "보통 수준의 위험 지역이에요. 기본 보장이면 충분할 수 있어요."
        else:
            risk_plain = "위험도가 높은 지역이에요. 보장 범위를 넓히는 걸 권장해요."

        top_item = item_costs[0]["name"] if item_costs else None
        item_plain = f"선택한 품목 중 **{top_item}** 이 보험료에 가장 큰 영향을 줬어요." if top_item else "선택한 품목이 없어요."
        burden_plain = "소득 대비 보험료 부담이 매우 낮은 편이에요 ✅" if burden_pct < 1 else ("적정 수준의 부담이에요." if burden_pct < 1.5 else "소득 대비 보험료가 다소 높아요. 품목을 줄여보세요.")

        st.info(f"💡 **{risk_plain}** {item_plain} {burden_plain}")

        base      = res["segment_adjusted"]
        addon_sum = res["item_addon"]
        total     = res["final"]

        # 라벨·값·색상: 기본보험료 | 품목들 | 품목가산 | 최종보험료
        item_palette = ["#fb923c", "#fbbf24", "#fcd34d", "#a78bfa", "#67e8f9", "#86efac"]
        labels = (
            ["기본 보험료"]
            + [ic["name"] for ic in item_costs]
            + ["품목 가산", "최종 보험료"]
        )
        values = (
            [base]
            + [ic["cost"] for ic in item_costs]
            + [addon_sum, total]
        )
        bar_colors = (
            ["#6366F1"]
            + [item_palette[i % len(item_palette)] for i in range(len(item_costs))]
            + ["#F59E0B", "#10B981"]
        )
        # 각 막대 텍스트 색은 배경색과 대비되도록 설정
        text_colors = (
            ["#ffffff"]
            + ["#1e293b" for _ in item_costs]   # 밝은 오렌지/노랑 위 → 어두운 글자
            + ["#1e293b", "#ffffff"]
        )

        fig_wf = go.Figure()
        for i, (lbl, val, bc, tc) in enumerate(zip(labels, values, bar_colors, text_colors)):
            is_summary = lbl in ("품목 가산", "최종 보험료")
            pct = val / total * 100 if total > 0 else 0
            fig_wf.add_trace(go.Bar(
                name=lbl,
                x=[lbl],
                y=[val],
                marker=dict(
                    color=bc,
                    line=dict(color="rgba(255,255,255,0.25)" if is_summary else "rgba(255,255,255,0.1)", width=2 if is_summary else 1),
                    cornerradius=6,
                ),
                text=f"<b>₩{val:,.0f}</b><br><span style='font-size:9px'>({pct:.0f}%)</span>",
                textposition="outside",
                textfont=dict(color="#FFFFFF", size=10),
                width=0.55 if is_summary else 0.45,
                hovertemplate=f"<b>{lbl}</b><br>₩{val:,.0f} ({pct:.1f}%)<extra></extra>",
            ))

        # 최종 보험료 기준선
        fig_wf.add_hline(
            y=total,
            line_dash="dash",
            line_color="#10B981",
            line_width=1.5,
            annotation_text=f"  최종 ₩{total:,.0f}",
            annotation_position="top left",
            annotation_font=dict(color="#10B981", size=11, family="Arial Black"),
        )

        # 품목가산 / 최종보험료 구분선
        n_divider = len(item_costs) + 0.5  # item 끝 위치
        fig_wf.add_vline(
            x=n_divider, line_dash="dot", line_color="#4B5563", line_width=1
        )

        fig_wf.update_layout(
            height=310,
            margin=dict(l=10, r=10, t=55, b=10),
            plot_bgcolor="rgba(0,0,0,0.85)",
            paper_bgcolor="rgba(0,0,0,0.85)",
            font=dict(color="#f1f5f9", size=11),
            showlegend=False,
            bargap=0.3,
            bargroupgap=0,
            xaxis=dict(
                tickfont=dict(color="#E2E8F0", size=10),
                showgrid=False, zeroline=False,
            ),
            yaxis=dict(
                tickfont=dict(color="#94a3b8", size=9),
                tickprefix="₩",
                showgrid=True, gridcolor="rgba(75,85,99,0.3)",
                zeroline=False,
            ),
            annotations=[
                dict(
                    text="← 품목별 기여",
                    x=(len(item_costs)) / (len(labels)) * 0.72,
                    y=1.08, xref="paper", yref="paper",
                    showarrow=False,
                    font=dict(color="#94a3b8", size=9),
                ),
                dict(
                    text="합산 →",
                    x=0.92, y=1.08, xref="paper", yref="paper",
                    showarrow=False,
                    font=dict(color="#94a3b8", size=9),
                ),
            ],
        )
        st.plotly_chart(fig_wf, use_container_width=True)

        with st.expander("📝 산출 공식 상세"):
            st.caption(f"기본 리스크 점수: {res['risk_score']:.1f}")
            st.caption(f"리스크 가산: x{res['risk_mult']:.2f}")
            st.caption(f"세그먼트 보정: x{res['segment_mult']:.2f}")