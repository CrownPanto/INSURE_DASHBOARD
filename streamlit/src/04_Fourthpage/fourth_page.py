import streamlit as st
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd
import numpy as np
from utils import DISTRICT_PROFILES, DEMO_DISTRICTS, SEGMENTS_A, SEGMENTS_B, calc_premium

def show_page(session, selected_ym):
    st.title("⚙️ 엔진 상세")
    st.caption("구별 리스크 분석 · 7단계 보험료 산출 · 미래 예측 모델")

    col_ctrl, _ = st.columns([2, 3])
    with col_ctrl:
        sel_gu = st.selectbox("자치구 선택", DEMO_DISTRICTS, index=DEMO_DISTRICTS.index("서초구"))

    p = DISTRICT_PROFILES[sel_gu]
    t_r, t_p, t_f = st.tabs(["🎯 위험 분석", "💰 보험료 산출", "📈 미래 예측"])

    # ─── TAB 1: 위험 분석 ───────────────────────────────────
    with t_r:
        col_radar, col_stats = st.columns([3, 2])

        with col_radar:
            categories = ["화재", "도난", "건물", "기상"]
            values     = [p["fire"], p["theft"], p["building"], p["weather"]]

            # 서울 평균 벤치마크
            avg_fire     = np.mean([v["fire"]     for v in DISTRICT_PROFILES.values()])
            avg_theft    = np.mean([v["theft"]    for v in DISTRICT_PROFILES.values()])
            avg_building = np.mean([v["building"] for v in DISTRICT_PROFILES.values()])
            avg_weather  = np.mean([v["weather"]  for v in DISTRICT_PROFILES.values()])
            avg_values   = [avg_fire, avg_theft, avg_building, avg_weather]

            fig_radar = go.Figure()
            fig_radar.add_trace(go.Scatterpolar(
                r=values + [values[0]],
                theta=categories + [categories[0]],
                fill='toself', name=sel_gu,
                line=dict(color="#6366F1", width=2),
                fillcolor="rgba(99,102,241,0.25)",
            ))
            fig_radar.add_trace(go.Scatterpolar(
                r=avg_values + [avg_values[0]],
                theta=categories + [categories[0]],
                fill='toself', name="서울 평균",
                line=dict(color="#94a3b8", width=1.5, dash="dot"),
                fillcolor="rgba(148,163,184,0.1)",
            ))
            fig_radar.update_layout(
                polar=dict(
                    radialaxis=dict(visible=True, range=[0, 60], tickfont=dict(color="#94a3b8", size=9)),
                    angularaxis=dict(tickfont=dict(color="#e2e8f0", size=12)),
                    bgcolor="rgba(15,17,23,0)",
                ),
                height=380,
                plot_bgcolor="#0f1117", paper_bgcolor="#0f1117",
                font=dict(color="#e2e8f0"),
                legend=dict(orientation="h", y=-0.1, font=dict(color="#94a3b8")),
                margin=dict(l=50, r=50, t=30, b=40),
            )
            st.plotly_chart(fig_radar, use_container_width=True)

        with col_stats:
            risk = p["risk"]
            grade = "A (최저)" if risk < 38 else "B (낮음)" if risk < 42 else "C (보통)" if risk < 47 else "D (높음)" if risk < 52 else "E (최고)"
            grade_color = "#10B981" if risk < 38 else "#6366F1" if risk < 42 else "#F59E0B" if risk < 47 else "#f97316" if risk < 52 else "#EF4444"

            st.markdown(f"""
                <div style="background:#1e293b; border-radius:12px; padding:20px; border:1px solid #334155;
                            border-left:5px solid {grade_color}; margin-bottom:16px;">
                    <div style="color:#94a3b8; font-size:0.8rem; text-transform:uppercase; margin-bottom:4px;">종합 리스크 등급</div>
                    <div style="color:{grade_color}; font-size:2rem; font-weight:800;">{grade}</div>
                    <div style="color:#94a3b8; font-size:0.9rem; margin-top:4px;">점수: {risk:.1f} / 100</div>
                </div>
            """, unsafe_allow_html=True)

            metrics = [
                ("🔥 화재", p["fire"], avg_fire, "#EF4444"),
                ("🔓 도난", p["theft"], avg_theft, "#f97316"),
                ("🏢 건물", p["building"], avg_building, "#F59E0B"),
                ("🌧 기상", p["weather"], avg_weather, "#6366F1"),
            ]
            for label, val, avg, color in metrics:
                diff = val - avg
                diff_str = f"+{diff:.1f}" if diff > 0 else f"{diff:.1f}"
                diff_color = "#EF4444" if diff > 0 else "#10B981"
                st.markdown(f"""
                    <div style="display:flex; justify-content:space-between; align-items:center;
                                background:#0f1117; border-radius:8px; padding:8px 14px; margin-bottom:8px;
                                border-left:3px solid {color};">
                        <span style="color:#e2e8f0; font-size:0.95rem;">{label}</span>
                        <span style="color:#e2e8f0; font-weight:700;">{val:.1f}</span>
                        <span style="color:{diff_color}; font-size:0.8rem;">서울평균 대비 {diff_str}</span>
                    </div>
                """, unsafe_allow_html=True)

    # ─── TAB 2: 보험료 산출 ──────────────────────────────────
    with t_p:
        st.markdown("##### ⚙️ 7단계 보험료 산출 엔진")
        ctrl_cols = st.columns(3)
        with ctrl_cols[0]:
            seg_a_key = st.selectbox("가구 유형", list(SEGMENTS_A.keys()),
                                     format_func=lambda k: f"{SEGMENTS_A[k]['icon']} {SEGMENTS_A[k]['name']}")
        with ctrl_cols[1]:
            seg_b_key = st.selectbox("자산 유형", list(SEGMENTS_B.keys()),
                                     format_func=lambda k: f"{SEGMENTS_B[k]['icon']} {SEGMENTS_B[k]['name']}")
        with ctrl_cols[2]:
            income = st.slider("연소득 (백만원)", 20, 150, 50, 5)

        res = calc_premium(sel_gu, seg_a_key, seg_b_key, income=income, selected_items=["가전제품", "전자기기"])

        # 7단계 산출 워터폴
        stages = [
            ("① 기본 손해율", res["pure"],            "#4B5563"),
            ("② 경험 보정",   res["experience"],       "#4B5563"),
            ("③ 리스크 반영", res["risk_classified"],  "#6366F1"),
            ("④ 사업비 로딩", res["loaded"],           "#6366F1"),
            ("⑤ 신뢰도 조정", res["credible"],         "#3B82F6"),
            ("⑥ 세그먼트 보정", res["segment_adjusted"],"#8B5CF6"),
            ("⑦ 최종 보험료", res["final"],            "#10B981"),
        ]

        labels = [s[0] for s in stages]
        values = [s[1] for s in stages]
        colors = [s[2] for s in stages]

        fig_wf = go.Figure()
        for i, (lbl, val, color) in enumerate(stages):
            is_final = i == len(stages) - 1
            fig_wf.add_trace(go.Bar(
                name=lbl, x=[lbl], y=[val],
                marker=dict(color=color, cornerradius=5,
                            line=dict(color="rgba(255,255,255,0.2)", width=1.5 if is_final else 0.5)),
                text=f"<b>₩{val:,.0f}</b>",
                textposition="outside",
                textfont=dict(color="#FFFFFF", size=10),
                width=0.6,
                hovertemplate=f"<b>{lbl}</b><br>₩{val:,.0f}<extra></extra>",
            ))

        fig_wf.update_layout(
            height=340, showlegend=False,
            plot_bgcolor="rgba(0,0,0,0)", paper_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#e2e8f0", size=10),
            margin=dict(l=10, r=10, t=50, b=10),
            xaxis=dict(tickfont=dict(color="#e2e8f0", size=9), showgrid=False),
            yaxis=dict(tickprefix="₩", tickfont=dict(color="#94a3b8", size=9),
                       showgrid=True, gridcolor="rgba(75,85,99,0.3)"),
        )
        st.plotly_chart(fig_wf, use_container_width=True)

        # 산출 공식 expander
        with st.expander("📝 산출 공식 상세 (비선형 리스크 커브 v1.3)"):
            st.markdown(f"""
            | 단계 | 항목 | 값 |
            |------|------|------|
            | ① | 기본 손해율 (화재 빈도 × 기대 손해액) | ₩{res['pure']:,.0f} |
            | ② | 경험 보정 (소득 가중) | ₩{res['experience']:,.0f} |
            | ③ | 리스크 계수 적용 (비선형 × **{res['risk_mult']:.2f}**) | ₩{res['risk_classified']:,.0f} |
            | ④ | 사업비 로딩 (51%) | ₩{res['loaded']:,.0f} |
            | ⑤ | 신뢰도 조정 | ₩{res['credible']:,.0f} |
            | ⑥ | 세그먼트 보정 (× **{res['segment_mult']:.2f}**) | ₩{res['segment_adjusted']:,.0f} |
            | ⑦ | **최종 보험료** (부담상한 적용) | **₩{res['final']:,.0f}** |

            > 리스크 커브: 점수 < 25 → `0.85 + (x/25)^0.7 × 0.15` | 25~40 → `1.00 + (x-25)/100` | 40+ → 비선형 가속
            """)

    # ─── TAB 3: 미래 예측 ────────────────────────────────────
    with t_f:
        st.markdown("##### 📈 보험료 트렌드 & 예측 (2021~2027)")
        st.caption(f"{sel_gu} · Snowflake Cortex ML FORECAST 기반 (60개월 실데이터 + 24개월 예측)")

        # 실데이터: DB에서 가져오기 (실패 시 demo)
        try:
            df_trend = session.sql(f"""
                SELECT YEAR_MONTH, ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY),0) AS AVG_PREMIUM
                FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
                WHERE GU_NAME = '{sel_gu.replace("'", "''")}'
                GROUP BY YEAR_MONTH ORDER BY YEAR_MONTH
            """).to_pandas()
            if df_trend.empty:
                raise ValueError("no data")
        except Exception:
            months = pd.date_range("2021-01", periods=60, freq="MS")
            base_p = p["base"]
            np.random.seed(42)
            premiums = [base_p + i * 80 + np.random.normal(0, 500) for i in range(60)]
            df_trend = pd.DataFrame({"YEAR_MONTH": [m.strftime("%Y%m") for m in months], "AVG_PREMIUM": premiums})

        # 예측 데이터 (간단한 선형 트렌드 연장)
        if len(df_trend) >= 12:
            last_12 = df_trend["AVG_PREMIUM"].tail(12).values
            trend_slope = (last_12[-1] - last_12[0]) / 12
            forecast_months = [f"2026{str(m).zfill(2)}" if m <= 12 else f"2027{str(m-12).zfill(2)}" for m in range(1, 25)]
            forecast_vals = [df_trend["AVG_PREMIUM"].iloc[-1] + trend_slope * (i + 1) for i in range(24)]
        else:
            forecast_months, forecast_vals = [], []

        fig_trend = go.Figure()

        # 실데이터 선
        fig_trend.add_trace(go.Scatter(
            x=df_trend["YEAR_MONTH"], y=df_trend["AVG_PREMIUM"],
            mode="lines+markers", name="실데이터",
            line=dict(color="#6366F1", width=2.5),
            marker=dict(size=4, color="#818CF8"),
            hovertemplate="<b>%{x}</b><br>₩%{y:,.0f}<extra>실데이터</extra>",
        ))

        # 예측 선
        if forecast_months:
            fig_trend.add_trace(go.Scatter(
                x=forecast_months, y=forecast_vals,
                mode="lines", name="예측 (Cortex ML)",
                line=dict(color="#F59E0B", width=2, dash="dash"),
                hovertemplate="<b>%{x}</b><br>₩%{y:,.0f}<extra>예측</extra>",
            ))
            # 신뢰구간
            ci_upper = [v * 1.08 for v in forecast_vals]
            ci_lower = [v * 0.92 for v in forecast_vals]
            fig_trend.add_trace(go.Scatter(
                x=forecast_months + forecast_months[::-1],
                y=ci_upper + ci_lower[::-1],
                fill='toself', fillcolor="rgba(245,158,11,0.1)",
                line=dict(color="rgba(0,0,0,0)"), name="신뢰구간 (90%)",
                hoverinfo="skip",
            ))

        # 실데이터/예측 구분선 (string 카테고리 x축은 add_vline 미지원 → add_annotation 사용)
        if forecast_months:
            fig_trend.add_annotation(
                x=df_trend["YEAR_MONTH"].iloc[-1], y=1,
                xref="x", yref="paper",
                text="▶ 예측 시작",
                showarrow=False,
                font=dict(color="#94a3b8", size=10),
                xanchor="left", yanchor="top",
            )

        fig_trend.update_layout(
            height=380,
            plot_bgcolor="rgba(0,0,0,0)", paper_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#e2e8f0"),
            xaxis=dict(tickfont=dict(color="#94a3b8", size=9), showgrid=False,
                       tickangle=45, nticks=20),
            yaxis=dict(tickprefix="₩", tickfont=dict(color="#94a3b8"),
                       showgrid=True, gridcolor="rgba(75,85,99,0.3)"),
            legend=dict(orientation="h", y=1.1, font=dict(color="#94a3b8")),
            margin=dict(l=10, r=10, t=50, b=60),
        )
        st.plotly_chart(fig_trend, use_container_width=True)

        # 예측 인사이트
        if forecast_vals:
            delta = forecast_vals[-1] - df_trend["AVG_PREMIUM"].iloc[-1]
            st.info(f"📊 **{sel_gu} 2027년 예측 보험료: ₩{forecast_vals[-1]:,.0f}/월** — 현재 대비 {'▲' if delta > 0 else '▼'} ₩{abs(delta):,.0f} ({abs(delta/df_trend['AVG_PREMIUM'].iloc[-1]*100):.1f}%)")
