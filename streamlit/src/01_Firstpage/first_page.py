import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import requests
import json
import numpy as np
import utils  # sys.path 설정이 메인에 되어 있어야 함 ㅡㅡ+

def show_page(session, selected_ym):
    st.title("서울시 동산보험료 지도")
    st.caption("25개 자치구별 위험도 기반 보험료 한눈에 보기")

    # ─── 1. 데이터 로드 및 is_demo 자동 판별 ───
    try:
        df_main = session.sql(
            f"SELECT * FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY WHERE YEAR_MONTH='{selected_ym}'"
        ).to_pandas()
        is_demo = False
    except:
        df_main = utils._demo_district_data()
        is_demo = True
        st.caption("⚠️ Demo Mode — Sample Data")

    # [핵심] DB 데이터에 리스크 점수가 비어있을 경우 utils 데이터로 보충 (기능 유지 ㅡㅡ+)
    _risk_cols = ["FIRE_RISK_SCORE", "THEFT_RISK_SCORE", "BUILDING_RISK_SCORE", "WEATHER_RISK_SCORE", "COMPOSITE_RISK_SCORE"]
    for _rc in _risk_cols:
        if _rc not in df_main.columns or df_main[_rc].nunique() <= 1:
            demo_ref = utils._demo_district_data()
            _map = dict(zip(demo_ref["GU_NAME"], demo_ref[_rc]))
            df_main[_rc] = df_main["GU_NAME"].map(_map).fillna(df_main[_rc] if _rc in df_main.columns else 0)

    # ─── 2. 데이터 집계 ───
    agg_df = df_main.groupby("GU_NAME").agg({
        "ADJUSTED_PREMIUM_MONTHLY": "mean",
        "COMPOSITE_RISK_SCORE": "mean",
        "TOTAL_POPULATION": "sum",
        "RISK_GRADE": "first",
        "FIRE_RISK_SCORE": "mean",
        "THEFT_RISK_SCORE": "mean",
        "BUILDING_RISK_SCORE": "mean",
        "WEATHER_RISK_SCORE": "mean",
        "AVG_BASE_PREMIUM": "mean",
    }).reset_index()

    avg_premium = agg_df["ADJUSTED_PREMIUM_MONTHLY"].mean()
    avg_risk = agg_df["COMPOSITE_RISK_SCORE"].mean()

    # ─── 3. KPI 섹션 ───
    k1, k2, k3 = st.columns(3)
    with k1:
        st.markdown(f"""
        <div style="background:linear-gradient(135deg,rgba(99,102,241,0.2),rgba(99,102,241,0.05));
                    border:1px solid rgba(99,102,241,0.5); border-radius:14px; padding:20px 24px;">
            <div style="font-size:12px; color:#000000; font-weight:600; letter-spacing:1px; text-transform:uppercase; margin-bottom:8px;">
                💰 서울 평균 월보험료
            </div>
            <div style="font-size:32px; font-weight:800; color:#000000; line-height:1.1;">
                ₩{avg_premium:,.0f}
            </div>
            <div style="font-size:12px; color:#000000; margin-top:6px;">월 납입 기준</div>
        </div>
        """, unsafe_allow_html=True)
    with k2:
        risk_color = "#ef4444" if avg_risk >= 50 else "#f59e0b" if avg_risk >= 40 else "#10b981"
        risk_border = "rgba(239,68,68,0.5)" if avg_risk >= 50 else "rgba(245,158,11,0.5)" if avg_risk >= 40 else "rgba(16,185,129,0.5)"
        risk_bg = "rgba(239,68,68,0.15)" if avg_risk >= 50 else "rgba(245,158,11,0.15)" if avg_risk >= 40 else "rgba(16,185,129,0.15)"
        st.markdown(f"""
        <div style="background:linear-gradient(135deg,{risk_bg},{risk_bg.replace('0.15','0.03')});
                    border:1px solid {risk_border}; border-radius:14px; padding:20px 24px;">
            <div style="font-size:12px; color:#000000; font-weight:600; letter-spacing:1px; text-transform:uppercase; margin-bottom:8px;">
                ⚠️ 서울 평균 위험도
            </div>
            <div style="font-size:32px; font-weight:800; color:#000000; line-height:1.1;">
                {avg_risk:.1f}<span style="font-size:18px; color:#333333;">점</span>
            </div>
            <div style="font-size:12px; color:#000000; margin-top:6px;">
                {'고위험' if avg_risk >= 50 else '중위험' if avg_risk >= 40 else '저위험'} 구간
            </div>
        </div>
        """, unsafe_allow_html=True)
    with k3:
        st.markdown(f"""
        <div style="background:linear-gradient(135deg,rgba(20,184,166,0.2),rgba(20,184,166,0.05));
                    border:1px solid rgba(20,184,166,0.5); border-radius:14px; padding:20px 24px;">
            <div style="font-size:12px; color:#000000; font-weight:600; letter-spacing:1px; text-transform:uppercase; margin-bottom:8px;">
                📍 분석 대상
            </div>
            <div style="font-size:32px; font-weight:800; color:#000000; line-height:1.1;">
                {len(agg_df)}<span style="font-size:18px; color:#333333;">개</span>
            </div>
            <div style="font-size:12px; color:#000000; margin-top:6px;">서울시 전체 자치구</div>
        </div>
        """, unsafe_allow_html=True)

    st.markdown("<br>", unsafe_allow_html=True)
    st.markdown("---")

    # ─── 4. Top 3 vs Bottom 3 섹션 ───
    st.subheader("보험료 Top 3 vs Bottom 3")
    sorted_df = agg_df.sort_values("ADJUSTED_PREMIUM_MONTHLY", ascending=False).reset_index(drop=True)

    col_high, col_low = st.columns(2)
    medals = ["🥇", "🥈", "🥉"]
    max_premium = sorted_df["ADJUSTED_PREMIUM_MONTHLY"].max()

    with col_high:
        st.markdown("#### 🔴 보험료 높은 구")
        for rank, (_, row) in enumerate(sorted_df.head(3).iterrows()):
            diff_pct = ((row["ADJUSTED_PREMIUM_MONTHLY"] - avg_premium) / avg_premium) * 100
            bar_width = int(row["ADJUSTED_PREMIUM_MONTHLY"] / max_premium * 100)
            st.markdown(f"""
            <div style="background:linear-gradient(135deg,rgba(239,68,68,0.15),rgba(239,68,68,0.05));
                        border:1px solid rgba(239,68,68,0.4); border-radius:12px;
                        padding:14px 18px; margin-bottom:10px;">
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
                    <span style="font-size:18px; font-weight:700; color:#000000;">
                        {medals[rank]} {row['GU_NAME']}
                    </span>
                    <span style="font-size:11px; background:rgba(239,68,68,0.2);
                                 color:#000000; padding:3px 8px; border-radius:20px; font-weight:600;">
                        평균 대비 +{diff_pct:.0f}%
                    </span>
                </div>
                <div style="font-size:22px; font-weight:800; color:#ef4444; margin-bottom:8px;">
                    ₩{row['ADJUSTED_PREMIUM_MONTHLY']:,.0f}<span style="font-size:13px; color:#555;">/월</span>
                </div>
                <div style="background:rgba(0,0,0,0.08); border-radius:4px; height:5px;">
                    <div style="background:linear-gradient(90deg,#ef4444,#f97316);
                                width:{bar_width}%; height:5px; border-radius:4px;"></div>
                </div>
            </div>
            """, unsafe_allow_html=True)

    with col_low:
        st.markdown("#### 🟢 보험료 낮은 구")
        bottom3 = sorted_df.tail(3).iloc[::-1].reset_index(drop=True)
        for rank, (_, row) in enumerate(bottom3.iterrows()):
            diff_pct = ((row["ADJUSTED_PREMIUM_MONTHLY"] - avg_premium) / avg_premium) * 100
            bar_width = int(row["ADJUSTED_PREMIUM_MONTHLY"] / max_premium * 100)
            st.markdown(f"""
            <div style="background:linear-gradient(135deg,rgba(16,185,129,0.15),rgba(16,185,129,0.05));
                        border:1px solid rgba(16,185,129,0.4); border-radius:12px;
                        padding:14px 18px; margin-bottom:10px;">
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
                    <span style="font-size:18px; font-weight:700; color:#000000;">
                        {medals[rank]} {row['GU_NAME']}
                    </span>
                    <span style="font-size:11px; background:rgba(16,185,129,0.2);
                                 color:#000000; padding:3px 8px; border-radius:20px; font-weight:600;">
                        평균 대비 {diff_pct:.0f}%
                    </span>
                </div>
                <div style="font-size:22px; font-weight:800; color:#10b981; margin-bottom:8px;">
                    ₩{row['ADJUSTED_PREMIUM_MONTHLY']:,.0f}<span style="font-size:13px; color:#555;">/월</span>
                </div>
                <div style="background:rgba(0,0,0,0.08); border-radius:4px; height:5px;">
                    <div style="background:linear-gradient(90deg,#10b981,#34d399);
                                width:{bar_width}%; height:5px; border-radius:4px;"></div>
                </div>
            </div>
            """, unsafe_allow_html=True)

    st.markdown("---")

    # ─── 5. 서울시 지도 시각화 ───
    st.subheader("서울시 자치구별 위험도 지도")
    st.caption("색상이 빨갈수록 위험도 높음 · 보험료 높음 | 마우스 오버로 상세 확인")

    try:
        import os
        geojson_path = os.path.join(os.path.dirname(__file__), "../../data/seoul_gu_boundaries.geojson")

        with open(geojson_path, "r", encoding="utf-8") as f:
            geojson_data = json.load(f)

        # 위험도 등급 텍스트
        def risk_label(score):
            if score >= 42: return "🔴 고위험"
            if score >= 37: return "🟡 중위험"
            return "🟢 저위험"

        agg_df["_risk_label"] = agg_df["COMPOSITE_RISK_SCORE"].apply(risk_label)
        agg_df["_premium_diff"] = ((agg_df["ADJUSTED_PREMIUM_MONTHLY"] - avg_premium) / avg_premium * 100).round(1)

        fig_map = px.choropleth_mapbox(
            agg_df,
            geojson=geojson_data,
            locations="GU_NAME",
            featureidkey="properties.name",
            color="COMPOSITE_RISK_SCORE",
            color_continuous_scale=[
                [0.0, "#1a9850"],   # 진초록 (저위험)
                [0.4, "#fee08b"],   # 노랑
                [0.7, "#f46d43"],   # 주황
                [1.0, "#d73027"],   # 진빨강 (고위험)
            ],
            range_color=[agg_df["COMPOSITE_RISK_SCORE"].min(), agg_df["COMPOSITE_RISK_SCORE"].max()],
            hover_name="GU_NAME",
            custom_data=["COMPOSITE_RISK_SCORE", "ADJUSTED_PREMIUM_MONTHLY", "_risk_label", "_premium_diff"],
            mapbox_style="carto-darkmatter",
            zoom=10.5,
            center={"lat": 37.5665, "lon": 126.9780},
        )

        fig_map.update_traces(
            marker_line_width=1.5,
            marker_line_color="rgba(255,255,255,0.4)",
            marker_opacity=0.88,
            hovertemplate=(
                "<b style='font-size:15px'>%{hovertext}</b><br><br>"
                "⚠️ 위험도: <b>%{customdata[0]:.1f}점</b>  %{customdata[2]}<br>"
                "💰 월보험료: <b>₩%{customdata[1]:,.0f}</b><br>"
                "📊 평균 대비: <b>%{customdata[3]:+.1f}%</b>"
                "<extra></extra>"
            ),
        )

        fig_map.update_layout(
            height=620,
            margin=dict(l=0, r=0, t=0, b=0),
            coloraxis_colorbar=dict(
                title=dict(text="위험도 점수", font=dict(color="#e2e8f0", size=12)),
                tickfont=dict(color="#94a3b8", size=10),
                thickness=12, len=0.55, x=1.01,
                bgcolor="rgba(15,23,42,0.8)",
                bordercolor="rgba(255,255,255,0.1)", borderwidth=1,
            ),
            paper_bgcolor="rgba(0,0,0,0)",
            hoverlabel=dict(
                bgcolor="rgba(15,23,42,0.95)",
                bordercolor="#475569",
                font=dict(color="#f1f5f9", size=13, family="Arial"),
            ),
        )

        st.plotly_chart(fig_map, use_container_width=True)

    except Exception as e:
        st.error(f"지도 로드 실패: {str(e)}")
        st.info("💡 대신 아래의 데이터 시각화를 확인하세요.")

    st.markdown("---")

    # ─── 6. 위험도 vs 보험료 상관관계 분석 ───
    st.subheader("위험도 vs 보험료 — 상관관계 분석")
    st.caption("위험도가 높을수록 보험료가 비싼가? 데이터로 확인하세요")

    avg_risk = agg_df["COMPOSITE_RISK_SCORE"].mean()

    # IQR outlier 제거
    Q1 = agg_df["ADJUSTED_PREMIUM_MONTHLY"].quantile(0.25)
    Q3 = agg_df["ADJUSTED_PREMIUM_MONTHLY"].quantile(0.75)
    y_upper = Q3 + 1.5 * (Q3 - Q1)
    df_plot = agg_df[agg_df["ADJUSTED_PREMIUM_MONTHLY"] <= y_upper].copy()

    corr_main = df_plot["COMPOSITE_RISK_SCORE"].corr(df_plot["ADJUSTED_PREMIUM_MONTHLY"])

    # 회귀선 + 95% CI
    x_arr = df_plot["COMPOSITE_RISK_SCORE"].values
    y_arr = df_plot["ADJUSTED_PREMIUM_MONTHLY"].values
    z = np.polyfit(x_arr, y_arr, 1)
    p_fn = np.poly1d(z)
    x_line = np.linspace(x_arr.min() - 0.2, x_arr.max() + 0.2, 300)
    y_line = p_fn(x_line)
    n, x_mean = len(x_arr), x_arr.mean()
    s_err = np.sqrt(np.sum((y_arr - p_fn(x_arr)) ** 2) / (n - 2))
    se = s_err * np.sqrt(1/n + (x_line - x_mean)**2 / np.sum((x_arr - x_mean)**2))

    # 사분면별 색상 매핑
    def qcolor(r_score, p_val):
        if r_score >= avg_risk and p_val >= avg_premium: return "#ef4444"   # 고위험·고보험료
        if r_score >= avg_risk and p_val <  avg_premium: return "#f97316"   # 고위험·저보험료
        if r_score <  avg_risk and p_val >= avg_premium: return "#6366f1"   # 저위험·고보험료
        return "#22c55e"                                                      # 저위험·저보험료

    df_plot["_qcolor"] = df_plot.apply(lambda r: qcolor(r["COMPOSITE_RISK_SCORE"], r["ADJUSTED_PREMIUM_MONTHLY"]), axis=1)

    y_pad = (y_arr.max() - y_arr.min()) * 0.15
    x_pad = (x_arr.max() - x_arr.min()) * 0.08
    y_lo = y_arr.min() - y_pad
    y_hi = y_arr.max() + y_pad * 1.5
    x_lo = x_arr.min() - x_pad
    x_hi = x_arr.max() + x_pad

    fig = go.Figure()

    # ── 사분면 배경 ──
    for x0, x1, y0, y1, fc, label, lx, ly, la in [
        (x_lo, avg_risk, avg_premium, y_hi,  "rgba(99,102,241,0.07)",  "저위험·고보험료",  x_lo+0.05, y_hi-y_pad*0.4, "left"),
        (avg_risk, x_hi, avg_premium, y_hi,  "rgba(239,68,68,0.07)",   "고위험·고보험료",  x_hi-0.05, y_hi-y_pad*0.4, "right"),
        (x_lo, avg_risk, y_lo, avg_premium,  "rgba(34,197,94,0.07)",   "저위험·저보험료",  x_lo+0.05, y_lo+y_pad*0.4, "left"),
        (avg_risk, x_hi, y_lo, avg_premium,  "rgba(249,115,22,0.07)",  "고위험·저보험료",  x_hi-0.05, y_lo+y_pad*0.4, "right"),
    ]:
        fig.add_shape(type="rect", x0=x0, x1=x1, y0=y0, y1=y1,
                      fillcolor=fc, line_width=0, layer="below")
        fig.add_annotation(x=lx, y=ly, text=label, showarrow=False,
                           font=dict(size=10, color="rgba(203,213,225,0.5)"),
                           xanchor=la)

    # ── 평균 기준선 ──
    fig.add_hline(y=avg_premium, line_dash="dash", line_color="rgba(148,163,184,0.3)", line_width=1)
    fig.add_vline(x=avg_risk,    line_dash="dash", line_color="rgba(148,163,184,0.3)", line_width=1)

    # ── 95% CI 밴드 ──
    fig.add_trace(go.Scatter(
        x=np.concatenate([x_line, x_line[::-1]]),
        y=np.concatenate([y_line + 1.96*se, (y_line - 1.96*se)[::-1]]),
        fill="toself", fillcolor="rgba(129,140,248,0.12)",
        line=dict(width=0), showlegend=False, hoverinfo="skip",
    ))

    # ── 회귀선 ──
    fig.add_trace(go.Scatter(
        x=x_line, y=y_line, mode="lines",
        line=dict(color="#818cf8", width=2.5, dash="solid"),
        showlegend=False,
        hovertemplate="위험도 %{x:.1f}점 → 예상 ₩%{y:,.0f}<extra>회귀선</extra>",
    ))

    # ── 산점 (단일 trace, 빠름) ──
    fig.add_trace(go.Scatter(
        x=df_plot["COMPOSITE_RISK_SCORE"],
        y=df_plot["ADJUSTED_PREMIUM_MONTHLY"],
        mode="markers+text",
        marker=dict(
            color=df_plot["_qcolor"],
            size=14,
            line=dict(color="rgba(255,255,255,0.6)", width=1.2),
        ),
        text=df_plot["GU_NAME"],
        textposition="top center",
        textfont=dict(size=9, color="#cbd5e1"),
        showlegend=False,
        customdata=df_plot[["COMPOSITE_RISK_SCORE", "ADJUSTED_PREMIUM_MONTHLY", "_qcolor"]].values,
        hovertemplate=(
            "<b>%{text}</b><br>"
            "위험도: <b>%{x:.2f}점</b><br>"
            "보험료: <b>₩%{y:,.0f}</b>"
            "<extra></extra>"
        ),
    ))

    # ── 상관계수 annotation ──
    corr_color = "#22c55e" if corr_main > 0.7 else "#f59e0b" if corr_main > 0.4 else "#94a3b8"
    corr_txt = "강한 양의 상관" if corr_main > 0.7 else "중간 양의 상관" if corr_main > 0.4 else "약한 상관" if corr_main > 0 else "음의 상관"
    fig.add_annotation(
        xref="paper", yref="paper", x=0.01, y=0.01,
        text=f"<b>r = {corr_main:+.3f}</b>  R² = {corr_main**2:.2f}<br><span style='color:{corr_color}'>{corr_txt}</span>",
        showarrow=False, align="left",
        bgcolor="rgba(15,23,42,0.88)", bordercolor="#4f46e5",
        borderwidth=1.5, borderpad=10,
        font=dict(size=12, color="#e2e8f0"),
        xanchor="left", yanchor="bottom",
    )

    fig.update_layout(
        height=540, plot_bgcolor="#0c1220", paper_bgcolor="#0c1220",
        font=dict(color="#f1f5f9", size=11),
        hovermode="closest",
        xaxis=dict(
            title="위험도 점수",
            title_font=dict(color="#94a3b8", size=12),
            tickfont=dict(color="#64748b"),
            gridcolor="rgba(255,255,255,0.04)",
            range=[x_lo, x_hi],
            zeroline=False,
        ),
        yaxis=dict(
            title="월 보험료 (원)",
            title_font=dict(color="#94a3b8", size=12),
            tickfont=dict(color="#64748b"),
            tickformat=",",
            gridcolor="rgba(255,255,255,0.04)",
            range=[y_lo, y_hi],
            zeroline=False,
        ),
        margin=dict(t=20, b=50, l=80, r=30),
    )
    st.plotly_chart(fig, use_container_width=True)

    # ── 사분면 범례 ──
    lc1, lc2, lc3, lc4 = st.columns(4)
    for col, color, label, desc in [
        (lc1, "#ef4444", "🔴 고위험·고보험료", "위험도↑ 보험료↑"),
        (lc2, "#f97316", "🟠 고위험·저보험료", "보험료 저평가 가능성"),
        (lc3, "#6366f1", "🔵 저위험·고보험료", "보험료 고평가 가능성"),
        (lc4, "#22c55e", "🟢 저위험·저보험료", "위험도↓ 보험료↓"),
    ]:
        col.markdown(
            f'<div style="border-left:3px solid {color}; padding:6px 10px; '
            f'background:rgba(255,255,255,0.03); border-radius:0 6px 6px 0; margin:2px 0;">'
            f'<div style="font-size:11px; font-weight:700; color:#e2e8f0;">{label}</div>'
            f'<div style="font-size:10px; color:#64748b;">{desc}</div></div>',
            unsafe_allow_html=True,
        )

    # 사분면 요약 카드
    quad_cols = st.columns(4)
    quads = [
        ("🔴 고위험·고보험료", agg_df[(agg_df["COMPOSITE_RISK_SCORE"]>=avg_risk)&(agg_df["ADJUSTED_PREMIUM_MONTHLY"]>=avg_premium)]),
        ("🟡 고위험·저보험료", agg_df[(agg_df["COMPOSITE_RISK_SCORE"]>=avg_risk)&(agg_df["ADJUSTED_PREMIUM_MONTHLY"]< avg_premium)]),
        ("🔵 저위험·고보험료", agg_df[(agg_df["COMPOSITE_RISK_SCORE"]< avg_risk)&(agg_df["ADJUSTED_PREMIUM_MONTHLY"]>=avg_premium)]),
        ("🟢 저위험·저보험료", agg_df[(agg_df["COMPOSITE_RISK_SCORE"]< avg_risk)&(agg_df["ADJUSTED_PREMIUM_MONTHLY"]< avg_premium)]),
    ]
    for col, (label, subset) in zip(quad_cols, quads):
        with col:
            names = " · ".join(subset["GU_NAME"].tolist()) if len(subset) > 0 else "없음"
            st.markdown(f"""
            <div style="background:rgba(255,255,255,0.04); border-radius:10px;
                        padding:12px; border:1px solid rgba(255,255,255,0.1); min-height:90px;">
                <div style="font-size:11px; font-weight:700; color:#94a3b8; margin-bottom:6px;">{label}</div>
                <div style="font-size:11px; color:#e2e8f0; line-height:1.6;">{names}</div>
            </div>
            """, unsafe_allow_html=True)

    st.markdown("<br>", unsafe_allow_html=True)

    # ─── 6-2. 구별 위험도 & 보험료 비교 (horizontal bar) ───
    st.subheader("구별 위험도 & 보험료 한눈에 비교")
    st.caption("보험료 순 정렬 | 파란선 = 서울 평균 | 색상 = 위험도")

    # outlier 제외한 24개 구 표시, 서초구 별도 안내
    Q3_bar = agg_df["ADJUSTED_PREMIUM_MONTHLY"].quantile(0.75)
    IQR_bar = Q3_bar - agg_df["ADJUSTED_PREMIUM_MONTHLY"].quantile(0.25)
    cutoff = Q3_bar + 1.5 * IQR_bar

    df_bar   = agg_df[agg_df["ADJUSTED_PREMIUM_MONTHLY"] <= cutoff].sort_values("ADJUSTED_PREMIUM_MONTHLY", ascending=True)
    df_over  = agg_df[agg_df["ADJUSTED_PREMIUM_MONTHLY"] >  cutoff]

    # 이상치 안내 박스
    if len(df_over) > 0:
        names = ", ".join(df_over["GU_NAME"].tolist())
        vals  = ", ".join([f"₩{v:,.0f}" for v in df_over["ADJUSTED_PREMIUM_MONTHLY"]])
        st.info(f"⚠️ **이상치 제외** — {names} ({vals}) 는 차트에서 제외됩니다")

    # 위험도 분포 기반 3구간 (실제 데이터 분위수)
    df_bar = df_bar.copy()
    rs = df_bar["COMPOSITE_RISK_SCORE"]
    low_thr  = rs.quantile(0.33)
    high_thr = rs.quantile(0.67)

    def bar_color(v):
        if v >= high_thr: return "#ef4444"
        if v >= low_thr:  return "#f59e0b"
        return "#22c55e"

    def risk_tier(v):
        if v >= high_thr: return f"🔴 고위험 {v:.1f}점"
        if v >= low_thr:  return f"🟡 중위험 {v:.1f}점"
        return f"🟢 저위험 {v:.1f}점"

    df_bar["_color"]     = df_bar["COMPOSITE_RISK_SCORE"].apply(bar_color)
    df_bar["_risk_tier"] = df_bar["COMPOSITE_RISK_SCORE"].apply(risk_tier)
    df_bar["_diff_pct"]  = ((df_bar["ADJUSTED_PREMIUM_MONTHLY"] - avg_premium) / avg_premium * 100).round(1)

    # X축 최솟값 기준으로 시작해서 차이가 크게 보이도록
    x_min_bar = df_bar["ADJUSTED_PREMIUM_MONTHLY"].min()
    x_max_bar = df_bar["ADJUSTED_PREMIUM_MONTHLY"].max()
    x_range   = x_max_bar - x_min_bar
    x_start   = max(0, min(x_min_bar, avg_premium) - x_range * 0.05)
    x_end     = max(x_max_bar, avg_premium) + x_range * 0.22

    fig_bar = go.Figure()
    fig_bar.add_trace(go.Bar(
        y=df_bar["GU_NAME"],
        x=df_bar["ADJUSTED_PREMIUM_MONTHLY"],
        orientation="h",
        marker=dict(color=df_bar["_color"], line=dict(width=0), opacity=0.88),
        customdata=df_bar[["_risk_tier", "_diff_pct"]].values,
        text=[f"₩{v:,.0f}" for v in df_bar["ADJUSTED_PREMIUM_MONTHLY"]],
        textposition="outside",
        textfont=dict(size=10, color="#1e293b"),
        hovertemplate=(
            "<b>%{y}</b><br>"
            "💰 월보험료: <b>₩%{x:,.0f}</b><br>"
            "⚠️ 위험도: <b>%{customdata[0]}</b><br>"
            "📊 평균 대비: <b>%{customdata[1]:+.1f}%</b>"
            "<extra></extra>"
        ),
    ))

    fig_bar.add_vline(
        x=avg_premium, line_dash="dash", line_color="#4f46e5", line_width=2,
    )
    fig_bar.add_annotation(
        x=avg_premium, y=1, yref="paper",
        text=f"▼ 서울 평균<br>₩{avg_premium:,.0f}",
        showarrow=False,
        font=dict(color="#4f46e5", size=11, family="Arial"),
        bgcolor="rgba(255,255,255,0.9)",
        bordercolor="#4f46e5",
        borderwidth=1, borderpad=6,
        xanchor="center", yanchor="bottom",
    )

    fig_bar.update_layout(
        height=max(500, len(df_bar) * 30),
        plot_bgcolor="#f8fafc", paper_bgcolor="#f8fafc",
        font=dict(color="#1e293b", size=11),
        xaxis=dict(
            title="월 보험료 (원)",
            title_font=dict(color="#475569", size=12),
            tickformat=",",
            tickfont=dict(color="#64748b"),
            gridcolor="rgba(0,0,0,0.06)",
            range=[x_start, x_end],
            zeroline=False,
        ),
        yaxis=dict(
            tickfont=dict(size=11, color="#1e293b"),
            autorange="reversed",
        ),
        showlegend=False,
        margin=dict(t=60, l=90, r=110, b=50),
    )
    st.plotly_chart(fig_bar, use_container_width=True)

    # 색상 범례
    leg1, leg2, leg3, _ = st.columns([1, 1, 1, 2])
    for col, color, label in [
        (leg1, "#ef4444", f"🔴 고위험  ≥ {high_thr:.0f}점"),
        (leg2, "#f59e0b", f"🟡 중위험  {low_thr:.0f}~{high_thr:.0f}점"),
        (leg3, "#22c55e", f"🟢 저위험  < {low_thr:.0f}점"),
    ]:
        col.markdown(
            f'<div style="border-left:3px solid {color}; padding:5px 10px; '
            f'background:rgba(0,0,0,0.03); border-radius:0 6px 6px 0;">'
            f'<span style="font-size:11px; color:#334155;">{label}</span></div>',
            unsafe_allow_html=True,
        )

    st.markdown("---")

    # ─── 7. 영등포 vs 서초 비교 (성혁님 v3 기능 유지 ㅡㅡ+) ───
    st.subheader("같은 보험, 다른 가격 — 왜?")
    st.caption("동일한 보장 내용이라도 지역 위험도에 따라 보험료가 달라집니다")

    comp_cols = st.columns(2)
    gu_styles = [
        ("영등포구", "#ef4444", "rgba(239,68,68,0.12)", "rgba(239,68,68,0.4)"),
        ("서초구",   "#6366f1", "rgba(99,102,241,0.12)", "rgba(99,102,241,0.4)"),
    ]

    for (gu_name, accent, bg, border), col in zip(gu_styles, comp_cols):
        row = agg_df[agg_df["GU_NAME"] == gu_name]
        if row.empty:
            continue
        r = row.iloc[0]
        diff_pct = (r["ADJUSTED_PREMIUM_MONTHLY"] - avg_premium) / avg_premium * 100
        diff_txt = f"+{diff_pct:.0f}%" if diff_pct >= 0 else f"{diff_pct:.0f}%"
        max_risk_val = 50

        def bar_html(icon, label, val, ac):
            w = int(min(val / max_risk_val * 100, 100))
            return (
                f'<div style="margin-bottom:8px;">'
                f'<div style="display:flex;justify-content:space-between;margin-bottom:3px;">'
                f'<span style="font-size:11px;color:#000000;">{icon} {label}</span>'
                f'<span style="font-size:11px;font-weight:700;color:#000000;">{val:.0f}점</span>'
                f'</div>'
                f'<div style="background:rgba(0,0,0,0.08);border-radius:4px;height:6px;">'
                f'<div style="background:{ac};width:{w}%;height:6px;border-radius:4px;opacity:0.8;"></div>'
                f'</div></div>'
            )

        bars = (
            bar_html("🔥", "화재 위험", r["FIRE_RISK_SCORE"],     accent) +
            bar_html("🔓", "도난 위험", r["THEFT_RISK_SCORE"],    accent) +
            bar_html("🏚", "건물 노후", r["BUILDING_RISK_SCORE"], accent) +
            bar_html("🌧", "기상 위험", r["WEATHER_RISK_SCORE"],  accent)
        )

        card = f"""
        <div style="background:{bg};border:1.5px solid {border};border-radius:16px;padding:24px 28px;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:18px;">
                <span style="font-size:22px;font-weight:800;color:#000000;">📍 {gu_name}</span>
                <span style="font-size:12px;font-weight:700;color:#000000;background:rgba(0,0,0,0.08);padding:4px 10px;border-radius:20px;">평균 대비 {diff_txt}</span>
            </div>
            <div style="margin-bottom:16px;">
                <div style="font-size:11px;color:#555555;font-weight:600;margin-bottom:4px;">💰 월 보험료</div>
                <div style="font-size:34px;font-weight:900;color:{accent};line-height:1.1;">₩{r['ADJUSTED_PREMIUM_MONTHLY']:,.0f}</div>
            </div>
            <div style="margin-bottom:20px;">
                <div style="font-size:11px;color:#555555;font-weight:600;margin-bottom:4px;">⚠️ 종합 위험도</div>
                <div style="font-size:26px;font-weight:800;color:#000000;">{r['COMPOSITE_RISK_SCORE']:.1f}<span style="font-size:14px;color:#666;">점</span></div>
            </div>
            <div style="font-size:11px;color:#444444;font-weight:600;margin-bottom:10px;">📊 위험 요소 분석</div>
            {bars}
        </div>
        """

        with col:
            st.markdown(card, unsafe_allow_html=True)

    # ─── 8. 전체 데이터 테이블 ───
    with st.expander("전체 25개 구 데이터 보기"):
        show_df = agg_df[["GU_NAME","ADJUSTED_PREMIUM_MONTHLY","COMPOSITE_RISK_SCORE","RISK_GRADE"]].copy()
        show_df.columns = ["자치구", "월보험료(원)", "위험도", "등급"]
        st.dataframe(show_df.sort_values("월보험료(원)", ascending=False), use_container_width=True)

    st.caption("🟢 인구/화재/범죄: KOSIS, 소방청, 경찰청 | 🔵 위험도/보험료: INSURE 엔진")