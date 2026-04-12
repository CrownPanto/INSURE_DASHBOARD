import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import requests
import json
import numpy as np
import utils  # sys.path 설정이 메인에 되어 있어야 함 ㅡㅡ+

def _section_header(icon, title, caption="", color="#6366f1", bg="#eef2ff", text="#1e1b4b"):
    cap_html = (f'<div style="color:{text}; opacity:0.65; font-size:0.78rem; '
                f'margin-top:3px; font-weight:500;">{caption}</div>') if caption else ""
    st.markdown(f"""
        <div style="background:{bg}; border-left:5px solid {color};
                    border-radius:8px; padding:12px 18px; margin:24px 0 14px 0;">
            <div style="display:flex; align-items:center; gap:8px;">
                <span style="font-size:1.2rem;">{icon}</span>
                <span style="color:{text}; font-size:1.05rem; font-weight:800;
                             letter-spacing:-0.3px;">{title}</span>
            </div>
            {cap_html}
        </div>
    """, unsafe_allow_html=True)

def show_page(session, selected_ym):
    st.markdown("""
        <div style="background:#1e293b; border-bottom:2px solid #334155;
                    padding:18px 24px 14px 24px; margin-bottom:8px; border-radius:0 0 10px 10px;">
            <div style="color:#f1f5f9; font-size:1.5rem; font-weight:800;
                        letter-spacing:-0.5px; line-height:1.2;">
                🏙️ 서울시 동산보험료 지도
            </div>
            <div style="color:#94a3b8; font-size:0.82rem; margin-top:4px;">
                25개 자치구별 위험도 기반 보험료 한눈에 보기
            </div>
        </div>
    """, unsafe_allow_html=True)

    # ─── 1. 데이터 로드 및 is_demo 자동 판별 ───
    try:
        df_main = session.sql(
            f"SELECT * FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY WHERE YEAR_MONTH='{selected_ym}'"
        ).to_pandas()
        is_demo = False
    except Exception as _db_err:
        df_main = utils._demo_district_data()
        is_demo = True
        _db_err_msg = str(_db_err)[:200]
        st.markdown(f"""
            <div style="background:#fefce8; border:1.5px solid #fbbf24;
                        border-left:5px solid #f59e0b; border-radius:8px;
                        padding:10px 16px; margin-bottom:8px;">
                <div style="display:flex; align-items:center; gap:8px; margin-bottom:4px;">
                    <span style="font-size:1.1rem;">⚠️</span>
                    <span style="color:#92400e; font-size:0.85rem; font-weight:700;">Demo Mode</span>
                    <span style="color:#78350f; font-size:0.82rem;">
                        — Snowflake INSURE_DB 조회 실패. 로컬 샘플 데이터로 표시 중
                    </span>
                </div>
                <div style="color:#b45309; font-size:0.7rem; font-family:monospace;
                            background:#fef3c7; padding:4px 8px; border-radius:4px;">
                    {_db_err_msg}
                </div>
            </div>
        """, unsafe_allow_html=True)

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

    # calc_premium() 기반 구별 보험료 재계산 — 25구 동일 기준
    # 10개 대표 세그먼트 조합 평균으로 "구별 표준 보험료" 산출
    _COMBOS = [
        ("A4", "B3", 28), ("A4", "B2", 28), ("A4", "B1", 28),
        ("A3", "B2", 50), ("A6", "B3", 25), ("A1", "B1", 45),
        ("A5", "B1", 65), ("A2", "B2", 55), ("A5", "B4", 65),
        ("A5", "B5", 65),
    ]
    def _std_premium(gu):
        vals = [utils.calc_premium(gu, sa, sb, inc)["final"] for sa, sb, inc in _COMBOS]
        return round(sum(vals) / len(vals))
    agg_df["ADJUSTED_PREMIUM_MONTHLY"] = agg_df["GU_NAME"].apply(_std_premium)

    avg_premium = agg_df["ADJUSTED_PREMIUM_MONTHLY"].mean()
    avg_risk = agg_df["COMPOSITE_RISK_SCORE"].mean()

    # DB의 RISK_GRADE 대신 실제 점수 분포 기반으로 등급 재계산
    _r = agg_df["COMPOSITE_RISK_SCORE"]
    _lo = _r.quantile(0.33)
    _hi = _r.quantile(0.67)
    def _calc_grade(v):
        if v >= _hi: return "고위험"
        if v >= _lo: return "중위험"
        return "저위험"
    agg_df["RISK_GRADE"] = _r.apply(_calc_grade)

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
    _section_header("🏆", "보험료 Top 3 vs Bottom 3", color="#f97316", bg="#fff7ed", text="#7c2d12")
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
    _section_header("🗺️", "서울시 자치구별 위험도 지도",
                    caption="색상이 빨갈수록 위험도 높음 · 보험료 높음 | 마우스 오버로 상세 확인",
                    color="#ef4444", bg="#fef2f2", text="#7f1d1d")

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
    _section_header("📈", "위험도 vs 보험료 — 상관관계 분석",
                    caption="위험도가 높을수록 보험료가 비싼가? 데이터로 확인하세요",
                    color="#6366f1", bg="#eef2ff", text="#1e1b4b")

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

    # ── 추가 통계 계산 ──
    slope, intercept = z[0], z[1]
    # t-통계량 (H₀: 기울기=0)
    se_slope = s_err / np.sqrt(np.sum((x_arr - x_mean)**2))
    t_stat = slope / se_slope
    df_stat = n - 2
    # p-value 근사 (t분포 양측검정, numpy만 사용)
    # |t|가 클수록 p작음 — 간이 정규근사
    abs_t = abs(t_stat)
    p_approx = 2 * (1 - (0.5 * (1 + np.sign(abs_t) * (1 - np.exp(-0.717*abs_t - 0.416*abs_t**2)))))
    p_approx = max(p_approx, 1e-10)
    p_str = "< 0.001" if p_approx < 0.001 else f"= {p_approx:.3f}"
    # 잔차 표준오차 (SEE)
    see = s_err
    # 회귀식 문자열
    sign_str = "+" if intercept >= 0 else "-"
    reg_eq = f"보험료 = {slope:,.1f} × 위험도 {sign_str} {abs(intercept):,.0f}"

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
            size=20,
            line=dict(color="rgba(255,255,255,0.9)", width=2),
        ),
        text=df_plot["GU_NAME"],
        textposition="top center",
        textfont=dict(size=12, color="#1e293b"),
        showlegend=False,
        customdata=df_plot[["COMPOSITE_RISK_SCORE", "ADJUSTED_PREMIUM_MONTHLY", "_qcolor"]].values,
        hovertemplate=(
            "<b>%{text}</b><br>"
            "위험도: <b>%{x:.2f}점</b><br>"
            "보험료: <b>₩%{y:,.0f}</b>"
            "<extra></extra>"
        ),
    ))

    # ── 상관계수 + 회귀식 annotation ──
    corr_color = "#16a34a" if corr_main > 0.7 else "#d97706" if corr_main > 0.4 else "#64748b"
    corr_txt = "강한 양의 상관" if corr_main > 0.7 else "중간 양의 상관" if corr_main > 0.4 else "약한 상관" if corr_main > 0 else "음의 상관"
    fig.add_annotation(
        xref="paper", yref="paper", x=0.01, y=0.01,
        text=(
            f"<b>r = {corr_main:+.3f}</b>  R² = {corr_main**2:.3f}<br>"
            f"<span style='color:{corr_color}'>{corr_txt}</span><br>"
            f"<span style='font-size:10px; color:#475569'>{reg_eq}</span>"
        ),
        showarrow=False, align="left",
        bgcolor="rgba(255,255,255,0.95)", bordercolor="#4f46e5",
        borderwidth=1.5, borderpad=10,
        font=dict(size=12, color="#1e293b"),
        xanchor="left", yanchor="bottom",
    )

    fig.update_layout(
        height=540, plot_bgcolor="#f8fafc", paper_bgcolor="#f8fafc",
        font=dict(color="#1e293b", size=11),
        hovermode="closest",
        xaxis=dict(
            title="위험도 점수",
            title_font=dict(color="#475569", size=12),
            tickfont=dict(color="#64748b"),
            gridcolor="rgba(0,0,0,0.07)",
            range=[x_lo, x_hi],
            zeroline=False,
            linecolor="rgba(0,0,0,0.1)",
        ),
        yaxis=dict(
            title="월 보험료 (원)",
            title_font=dict(color="#475569", size=12),
            tickfont=dict(color="#64748b"),
            tickformat=",",
            gridcolor="rgba(0,0,0,0.07)",
            range=[y_lo, y_hi],
            zeroline=False,
            linecolor="rgba(0,0,0,0.1)",
        ),
        margin=dict(t=20, b=50, l=80, r=30),
    )
    st.plotly_chart(fig, use_container_width=True)

    # ── 통계 분석 패널 (expander로 묶기) ──
    sig_color = "#16a34a" if p_approx < 0.05 else "#dc2626"
    sig_txt   = "통계적으로 유의함 ✅" if p_approx < 0.05 else "유의하지 않음 ❌"

    with st.expander(f"📐 통계 검정 결과 — r = {corr_main:+.3f}  |  R² = {corr_main**2:.3f}  |  p-value {p_str}  (클릭해서 상세 보기)"):
        s1, s2, s3, s4, s5 = st.columns(5)
        for col, title, value, sub, border in [
            (s1, "피어슨 r",        f"{corr_main:+.3f}",         corr_txt,                            "#4f46e5"),
            (s2, "결정계수 R²",     f"{corr_main**2:.3f}",        f"분산의 {corr_main**2*100:.0f}% 설명", "#0891b2"),
            (s3, "t-통계량",        f"{t_stat:.3f}",              f"자유도 df = {df_stat}",             "#7c3aed"),
            (s4, "p-value",         p_str,                        sig_txt,                             sig_color),
            (s5, "잔차 표준오차",   f"₩{see:,.0f}",              "예측 오차 범위",                     "#d97706"),
        ]:
            col.markdown(
                f'<div style="background:#ffffff; border:1px solid #e2e8f0; border-top:3px solid {border}; '
                f'border-radius:8px; padding:12px 14px; text-align:center;">'
                f'<div style="font-size:10px; color:#64748b; font-weight:600; margin-bottom:4px;">{title}</div>'
                f'<div style="font-size:20px; font-weight:800; color:#1e293b; font-family:monospace;">{value}</div>'
                f'<div style="font-size:10px; color:#94a3b8; margin-top:3px;">{sub}</div>'
                f'</div>',
                unsafe_allow_html=True,
            )

        st.markdown(
            f'<div style="background:#f0fdf4; border:1px solid #bbf7d0; border-radius:8px; '
            f'padding:12px 18px; margin-top:12px; font-size:12px; color:#166534;">'
            f'📐 <b>회귀식:</b> &nbsp; <code style="background:#dcfce7; padding:3px 8px; border-radius:4px; font-size:13px;">'
            f'{reg_eq}</code>'
            f'&nbsp;&nbsp;|&nbsp;&nbsp; 위험도 1점 상승 시 월보험료 평균 <b>₩{slope:,.0f} 증가</b>'
            f'</div>',
            unsafe_allow_html=True,
        )
    st.markdown("<br>", unsafe_allow_html=True)

    # ── 사분면 범례 + 요약 카드 (통합) ──
    quad_data = [
        {
            "emoji": "🔴", "label": "고위험·고보험료", "desc": "위험도↑ 보험료↑",
            "color": "#ef4444", "bg": "#fef2f2", "border": "#fca5a5", "text": "#7f1d1d",
            "sub": "#991b1b",
            "subset": agg_df[(agg_df["COMPOSITE_RISK_SCORE"]>=avg_risk)&(agg_df["ADJUSTED_PREMIUM_MONTHLY"]>=avg_premium)],
        },
        {
            "emoji": "🟠", "label": "고위험·저보험료", "desc": "보험료 저평가 가능성",
            "color": "#f97316", "bg": "#fff7ed", "border": "#fdba74", "text": "#7c2d12",
            "sub": "#9a3412",
            "subset": agg_df[(agg_df["COMPOSITE_RISK_SCORE"]>=avg_risk)&(agg_df["ADJUSTED_PREMIUM_MONTHLY"]< avg_premium)],
        },
        {
            "emoji": "🔵", "label": "저위험·고보험료", "desc": "보험료 고평가 가능성",
            "color": "#6366f1", "bg": "#eef2ff", "border": "#a5b4fc", "text": "#1e1b4b",
            "sub": "#3730a3",
            "subset": agg_df[(agg_df["COMPOSITE_RISK_SCORE"]< avg_risk)&(agg_df["ADJUSTED_PREMIUM_MONTHLY"]>=avg_premium)],
        },
        {
            "emoji": "🟢", "label": "저위험·저보험료", "desc": "위험도↓ 보험료↓",
            "color": "#22c55e", "bg": "#f0fdf4", "border": "#86efac", "text": "#14532d",
            "sub": "#166534",
            "subset": agg_df[(agg_df["COMPOSITE_RISK_SCORE"]< avg_risk)&(agg_df["ADJUSTED_PREMIUM_MONTHLY"]< avg_premium)],
        },
    ]

    quad_cols = st.columns(4)
    for col, q in zip(quad_cols, quad_data):
        names = " · ".join(q["subset"]["GU_NAME"].tolist()) if len(q["subset"]) > 0 else "없음"
        cnt   = len(q["subset"])
        with col:
            col.markdown(f"""
            <div style="background:{q['bg']}; border:1.5px solid {q['border']};
                        border-top:4px solid {q['color']};
                        border-radius:10px; padding:14px 14px 12px 14px; min-height:120px;">
                <div style="display:flex; align-items:center; gap:6px; margin-bottom:4px;">
                    <span style="font-size:1rem;">{q['emoji']}</span>
                    <span style="font-size:0.8rem; font-weight:800;
                                 color:{q['text']};">{q['label']}</span>
                    <span style="margin-left:auto; background:{q['color']};
                                 color:#fff; font-size:0.65rem; font-weight:700;
                                 padding:1px 7px; border-radius:20px;">{cnt}개구</span>
                </div>
                <div style="font-size:0.7rem; color:{q['sub']};
                            margin-bottom:8px; font-weight:600;">{q['desc']}</div>
                <div style="font-size:0.72rem; color:{q['text']};
                            line-height:1.7; font-weight:500;">{names}</div>
            </div>
            """, unsafe_allow_html=True)

    st.markdown("<br>", unsafe_allow_html=True)

    # ─── 6-3. 위험도가 높은 이유 — 요인별 분석 ───
    _section_header("🔍", "왜 위험도가 높은가? — 요인별 분석",
                    caption="4개 위험 요소(화재·도난·건물노후·기상)가 종합 위험도에 얼마나 기여하는지 확인하세요",
                    color="#8b5cf6", bg="#f5f3ff", text="#2e1065")

    risk_factors = {
        "🔥 화재": "FIRE_RISK_SCORE",
        "🔓 도난": "THEFT_RISK_SCORE",
        "🏚 건물노후": "BUILDING_RISK_SCORE",
        "🌧 기상": "WEATHER_RISK_SCORE",
    }
    factor_colors = ["#ef4444", "#f97316", "#8b5cf6", "#0ea5e9"]

    # ── 1. 요인별 서울 평균 기여도 파이 (전체 평균) ──
    col_pie, col_radar = st.columns([1, 1])

    with col_pie:
        st.markdown("##### 서울 전체 — 위험 요인 구성비")
        factor_means = {k: agg_df[v].mean() for k, v in risk_factors.items()}
        total = sum(factor_means.values())
        fig_pie = go.Figure(go.Pie(
            labels=list(factor_means.keys()),
            values=list(factor_means.values()),
            hole=0.45,
            marker=dict(colors=factor_colors, line=dict(color="white", width=2)),
            textinfo="label+percent",
            textfont=dict(size=12, color="#1e293b"),
            hovertemplate="<b>%{label}</b><br>평균 점수: %{value:.1f}점<br>구성비: %{percent}<extra></extra>",
        ))
        fig_pie.update_layout(
            height=300, margin=dict(t=10, b=10, l=10, r=10),
            plot_bgcolor="#f8fafc", paper_bgcolor="#f8fafc",
            showlegend=False,
            annotations=[dict(text=f"<b>위험도<br>구성</b>", x=0.5, y=0.5,
                              font=dict(size=13, color="#1e293b"), showarrow=False)],
        )
        st.plotly_chart(fig_pie, use_container_width=True)

    with col_radar:
        st.markdown("##### 고위험 TOP5 vs 저위험 TOP5 비교")
        top5 = agg_df.nlargest(5, "COMPOSITE_RISK_SCORE")
        bot5 = agg_df.nsmallest(5, "COMPOSITE_RISK_SCORE")
        factors_kr = ["🔥 화재", "🔓 도난", "🏚 건물노후", "🌧 기상"]
        cols_list  = ["FIRE_RISK_SCORE", "THEFT_RISK_SCORE", "BUILDING_RISK_SCORE", "WEATHER_RISK_SCORE"]

        fig_rad = go.Figure()
        for df_grp, name, color, fill in [
            (top5, "고위험 TOP5 평균", "#ef4444", "rgba(239,68,68,0.15)"),
            (bot5, "저위험 TOP5 평균", "#22c55e", "rgba(34,197,94,0.15)"),
        ]:
            vals = [df_grp[c].mean() for c in cols_list]
            vals_closed = vals + [vals[0]]
            fig_rad.add_trace(go.Scatterpolar(
                r=vals_closed,
                theta=factors_kr + [factors_kr[0]],
                fill="toself",
                fillcolor=fill,
                line=dict(color=color, width=2),
                name=name,
                hovertemplate="%{theta}: <b>%{r:.1f}점</b><extra>" + name + "</extra>",
            ))
        fig_rad.update_layout(
            height=300, margin=dict(t=20, b=20, l=30, r=30),
            polar=dict(
                bgcolor="#f8fafc",
                radialaxis=dict(visible=True, gridcolor="rgba(0,0,0,0.1)",
                                tickfont=dict(size=9, color="#64748b")),
                angularaxis=dict(tickfont=dict(size=11, color="#1e293b")),
            ),
            paper_bgcolor="#f8fafc",
            legend=dict(font=dict(size=10, color="#1e293b"), bgcolor="rgba(255,255,255,0.8)",
                        bordercolor="#e2e8f0", borderwidth=1),
        )
        st.plotly_chart(fig_rad, use_container_width=True)

    # ── 2. 구별 요인 히트맵 (상위 10구) ──
    with st.expander("🔥 위험 요인 히트맵 & 상관관계 — 상위 10개 구 (클릭해서 보기)", expanded=False):
        st.markdown("##### 위험 요인 히트맵 — 상위 10개 구")
        st.caption("위험도 높은 순 상위 10구 | 색이 진할수록 해당 요인 점수가 높음")

        factor_labels = ["🔥 화재", "🔓 도난", "🏚 건물노후", "🌧 기상"]
        factor_cols   = ["FIRE_RISK_SCORE", "THEFT_RISK_SCORE", "BUILDING_RISK_SCORE", "WEATHER_RISK_SCORE"]

        # 상위 10구만 (위험도 내림차순)
        df_heat = agg_df.nlargest(10, "COMPOSITE_RISK_SCORE").sort_values("COMPOSITE_RISK_SCORE", ascending=False)

        # 축 전환: y=4요인, x=10구
        z_data    = df_heat[factor_cols].values.T          # shape: (4, 10)
        text_data = [[f"{v:.0f}" for v in row] for row in z_data]
        gu_labels = df_heat["GU_NAME"].tolist()

        fig_heat = go.Figure(go.Heatmap(
            z=z_data,
            x=gu_labels,
            y=factor_labels,
            text=text_data,
            texttemplate="%{text}",
            textfont=dict(size=13, color="white"),
            colorscale=[
                [0.0, "#1e3a5f"],
                [0.4, "#2563eb"],
                [0.7, "#f97316"],
                [1.0, "#dc2626"],
            ],
            hovertemplate="<b>%{x}</b><br>%{y}: <b>%{z:.1f}점</b><extra></extra>",
            showscale=True,
            colorbar=dict(
                title=dict(text="위험점수", font=dict(color="#94a3b8", size=11)),
                tickfont=dict(color="#94a3b8", size=10),
                thickness=12, len=0.8,
            ),
        ))

        fig_heat.update_layout(
            height=280,
            plot_bgcolor="#0f172a", paper_bgcolor="#0f172a",
            font=dict(color="#f1f5f9", size=12),
            xaxis=dict(tickfont=dict(size=12, color="#f1f5f9"), side="bottom", tickangle=-30),
            yaxis=dict(tickfont=dict(size=12, color="#f1f5f9")),
            margin=dict(t=10, l=10, r=80, b=60),
        )
        st.plotly_chart(fig_heat, use_container_width=True)

        # ── 3. 각 요인의 보험료 상관관계 요약 ──
        st.markdown("##### 각 위험 요인과 보험료의 상관관계")
        fc1, fc2, fc3, fc4 = st.columns(4)
        for col, (label, fcol), fcolor in zip([fc1, fc2, fc3, fc4], risk_factors.items(), factor_colors):
            fc_corr = agg_df[fcol].corr(agg_df["ADJUSTED_PREMIUM_MONTHLY"])
            bar_w = int(abs(fc_corr) * 100)
            col.markdown(
                f'<div style="background:#ffffff; border:1px solid #e2e8f0; border-top:3px solid {fcolor}; '
                f'border-radius:8px; padding:14px; text-align:center;">'
                f'<div style="font-size:13px; font-weight:700; color:#1e293b; margin-bottom:6px;">{label}</div>'
                f'<div style="font-size:26px; font-weight:800; color:{fcolor}; font-family:monospace;">{fc_corr:+.3f}</div>'
                f'<div style="background:#f1f5f9; border-radius:4px; height:6px; margin-top:10px;">'
                f'<div style="background:{fcolor}; width:{bar_w}%; height:6px; border-radius:4px;"></div>'
                f'</div></div>',
                unsafe_allow_html=True,
            )

    st.markdown("<br>", unsafe_allow_html=True)

    # ─── 6-2. 구별 위험도 & 보험료 비교 (horizontal bar) ───
    _section_header("📊", "구별 위험도 & 보험료 한눈에 비교",
                    caption="보험료 순 정렬 | 파란 점선 = 서울 평균 | 주황 점선 = 중앙값 | 색상 = 위험도",
                    color="#0ea5e9", bg="#f0f9ff", text="#0c4a6e")

    # 전체 25개 구 모두 표시 (이상치 제외 없음)
    df_bar = agg_df.sort_values("ADJUSTED_PREMIUM_MONTHLY", ascending=True).copy()
    median_premium = df_bar["ADJUSTED_PREMIUM_MONTHLY"].median()

    # 위험도 분포 기반 3구간 (실제 데이터 분위수)
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
    x_start   = max(0, min(x_min_bar, avg_premium, median_premium) - x_range * 0.05)
    x_end     = max(x_max_bar, avg_premium, median_premium) + x_range * 0.26

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

    # 평균선 (파랑)
    fig_bar.add_vline(
        x=avg_premium, line_dash="dash", line_color="#4f46e5", line_width=2,
    )
    fig_bar.add_annotation(
        x=avg_premium, y=1, yref="paper",
        text=f"▼ 평균<br>₩{avg_premium:,.0f}",
        showarrow=False,
        font=dict(color="#4f46e5", size=10, family="Arial"),
        bgcolor="rgba(255,255,255,0.92)",
        bordercolor="#4f46e5",
        borderwidth=1, borderpad=5,
        xanchor="center", yanchor="bottom",
    )
    # 중앙값선 (주황)
    fig_bar.add_vline(
        x=median_premium, line_dash="dot", line_color="#ea580c", line_width=2,
    )
    fig_bar.add_annotation(
        x=median_premium, y=1, yref="paper",
        text=f"▼ 중앙값<br>₩{median_premium:,.0f}",
        showarrow=False,
        font=dict(color="#ea580c", size=10, family="Arial"),
        bgcolor="rgba(255,255,255,0.92)",
        bordercolor="#ea580c",
        borderwidth=1, borderpad=5,
        xanchor="center", yanchor="bottom",
    )

    fig_bar.update_layout(
        height=max(550, len(df_bar) * 28),
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
    for col, color, bg, text, label in [
        (leg1, "#dc2626", "#fef2f2", "#7f1d1d", f"고위험  ≥ {high_thr:.0f}점"),
        (leg2, "#d97706", "#fffbeb", "#78350f", f"중위험  {low_thr:.0f}~{high_thr:.0f}점"),
        (leg3, "#16a34a", "#f0fdf4", "#14532d", f"저위험  < {low_thr:.0f}점"),
    ]:
        col.markdown(
            f'<div style="border-left:4px solid {color}; padding:8px 12px; '
            f'background:{bg}; border-radius:0 8px 8px 0;">'
            f'<span style="font-size:12px; font-weight:700; color:{text};">{label}</span></div>',
            unsafe_allow_html=True,
        )

    st.markdown("---")

    # ─── 7. 구 선택 비교 ───
    _section_header("💡", "같은 보험, 다른 가격 — 왜?",
                    caption="두 자치구를 직접 선택해서 보험료 차이를 비교하세요",
                    color="#10b981", bg="#f0fdf4", text="#064e3b")

    # 구 목록 (데이터에 있는 것만)
    gu_list = sorted(agg_df["GU_NAME"].tolist())
    _default_a = gu_list.index("영등포구") if "영등포구" in gu_list else 0
    _default_b = gu_list.index("서초구")   if "서초구"   in gu_list else 1

    sel_col1, sel_col2 = st.columns(2)
    with sel_col1:
        st.markdown('<div style="font-size:11px;font-weight:700;color:#374151;margin-bottom:4px;">🅐 비교 구 선택</div>', unsafe_allow_html=True)
        comp_gu_a = st.selectbox("구 A", gu_list, index=_default_a, label_visibility="collapsed", key="comp_gu_a")
    with sel_col2:
        st.markdown('<div style="font-size:11px;font-weight:700;color:#374151;margin-bottom:4px;">🅑 비교 구 선택</div>', unsafe_allow_html=True)
        comp_gu_b = st.selectbox("구 B", gu_list, index=_default_b, label_visibility="collapsed", key="comp_gu_b")

    comp_pairs = [
        (comp_gu_a, "#ef4444", "rgba(239,68,68,0.12)", "rgba(239,68,68,0.4)"),
        (comp_gu_b, "#6366f1", "rgba(99,102,241,0.12)", "rgba(99,102,241,0.4)"),
    ]
    comp_cols = st.columns(2)

    _comp_data = {}
    for (gu_name, accent, card_bg, border), col in zip(comp_pairs, comp_cols):
        row = agg_df[agg_df["GU_NAME"] == gu_name]
        if row.empty:
            continue
        r = row.iloc[0]
        _comp_data[gu_name] = r
        diff_pct = (r["ADJUSTED_PREMIUM_MONTHLY"] - avg_premium) / avg_premium * 100
        diff_txt = f"+{diff_pct:.0f}%" if diff_pct >= 0 else f"{diff_pct:.0f}%"
        diff_bg  = "#fef2f2" if diff_pct >= 0 else "#f0fdf4"
        diff_col = "#ef4444" if diff_pct >= 0 else "#16a34a"
        max_risk_val = 60

        def _bar(icon, label, val, ac):
            w = int(min(val / max_risk_val * 100, 100))
            return (
                f'<div style="margin-bottom:8px;">'
                f'<div style="display:flex;justify-content:space-between;margin-bottom:3px;">'
                f'<span style="font-size:11px;color:#374151;">{icon} {label}</span>'
                f'<span style="font-size:11px;font-weight:700;color:#111827;">{val:.0f}점</span>'
                f'</div>'
                f'<div style="background:rgba(0,0,0,0.08);border-radius:4px;height:7px;">'
                f'<div style="background:{ac};width:{w}%;height:7px;border-radius:4px;"></div>'
                f'</div></div>'
            )

        bars = (
            _bar("🔥", "화재 위험", r["FIRE_RISK_SCORE"],     accent) +
            _bar("🔓", "도난 위험", r["THEFT_RISK_SCORE"],    accent) +
            _bar("🏚", "건물 노후", r["BUILDING_RISK_SCORE"], accent) +
            _bar("🌧", "기상 위험", r["WEATHER_RISK_SCORE"],  accent)
        )

        card = f"""
        <div style="background:{card_bg};border:1.5px solid {border};border-radius:16px;padding:24px 28px;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:18px;">
                <span style="font-size:20px;font-weight:800;color:#111827;">📍 {gu_name}</span>
                <span style="font-size:12px;font-weight:700;color:{diff_col};background:{diff_bg};
                             padding:4px 10px;border-radius:20px;border:1px solid {diff_col}33;">평균 대비 {diff_txt}</span>
            </div>
            <div style="margin-bottom:16px;">
                <div style="font-size:11px;color:#6b7280;font-weight:600;margin-bottom:4px;">💰 월 보험료</div>
                <div style="font-size:34px;font-weight:900;color:{accent};line-height:1.1;">&#8361;{r['ADJUSTED_PREMIUM_MONTHLY']:,.0f}</div>
            </div>
            <div style="margin-bottom:20px;">
                <div style="font-size:11px;color:#6b7280;font-weight:600;margin-bottom:4px;">⚠️ 종합 위험도</div>
                <div style="font-size:26px;font-weight:800;color:#111827;">{r['COMPOSITE_RISK_SCORE']:.1f}<span style="font-size:14px;color:#9ca3af;">점</span></div>
            </div>
            <div style="font-size:11px;color:#6b7280;font-weight:600;margin-bottom:10px;">📊 위험 요소 분석</div>
            {bars}
        </div>
        """
        with col:
            st.markdown(card, unsafe_allow_html=True)

    # ── 차이 설명 박스 ──────────────────────────────────────────
    st.markdown("<div style='height:14px'></div>", unsafe_allow_html=True)
    if len(_comp_data) == 2:
        ra = _comp_data[comp_gu_a]
        rb = _comp_data[comp_gu_b]
        prem_a  = ra["ADJUSTED_PREMIUM_MONTHLY"]
        prem_b  = rb["ADJUSTED_PREMIUM_MONTHLY"]
        risk_a  = ra["COMPOSITE_RISK_SCORE"]
        risk_b  = rb["COMPOSITE_RISK_SCORE"]
        prem_diff = prem_b - prem_a
        risk_diff = risk_b - risk_a

        # 역설 여부: 위험도가 낮은데 보험료가 높은 경우
        paradox = (risk_b < risk_a and prem_b > prem_a) or (risk_b > risk_a and prem_b < prem_a)

        if paradox:
            higher_prem_gu  = comp_gu_b if prem_b > prem_a else comp_gu_a
            lower_risk_gu   = comp_gu_b if risk_b < risk_a else comp_gu_a
            prem_gap        = abs(prem_diff)
            risk_gap        = abs(risk_diff)
            explain_html = f"""
<div style="background:linear-gradient(135deg,#1e1b4b,#1e3a5f);border:1.5px solid #6366f1;
            border-radius:14px;padding:20px 24px;">
  <div style="display:flex;align-items:center;gap:8px;margin-bottom:14px;">
    <span style="font-size:18px;">🤔</span>
    <span style="color:#e0e7ff;font-size:14px;font-weight:800;">왜 위험도가 낮은 {lower_risk_gu}의 보험료가 더 높을까요?</span>
  </div>
  <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;margin-bottom:16px;">
    <div style="background:rgba(255,255,255,0.07);border-radius:10px;padding:12px 14px;text-align:center;">
      <div style="color:#94a3b8;font-size:10px;font-weight:700;margin-bottom:6px;">보험료 차이</div>
      <div style="color:#f87171;font-size:20px;font-weight:900;">&#8361;{prem_gap:,.0f}</div>
      <div style="color:#94a3b8;font-size:10px;margin-top:4px;">{higher_prem_gu}가 더 높음</div>
    </div>
    <div style="background:rgba(255,255,255,0.07);border-radius:10px;padding:12px 14px;text-align:center;">
      <div style="color:#94a3b8;font-size:10px;font-weight:700;margin-bottom:6px;">위험도 차이</div>
      <div style="color:#34d399;font-size:20px;font-weight:900;">{risk_gap:.1f}점</div>
      <div style="color:#94a3b8;font-size:10px;margin-top:4px;">{lower_risk_gu}가 더 낮음</div>
    </div>
    <div style="background:rgba(255,255,255,0.07);border-radius:10px;padding:12px 14px;text-align:center;">
      <div style="color:#94a3b8;font-size:10px;font-weight:700;margin-bottom:6px;">결론</div>
      <div style="color:#fbbf24;font-size:13px;font-weight:800;line-height:1.4;">위험도 역설</div>
      <div style="color:#94a3b8;font-size:10px;margin-top:4px;">아래 설명 참조</div>
    </div>
  </div>
  <div style="background:rgba(255,255,255,0.05);border-radius:10px;padding:14px 16px;
              border-left:3px solid #fbbf24;">
    <div style="color:#fbbf24;font-size:12px;font-weight:800;margin-bottom:8px;">📌 핵심 원리: 보험료 = 위험도 × 자산가치</div>
    <div style="color:#cbd5e1;font-size:12px;line-height:1.9;">
      • <b style="color:#f1f5f9;">위험도(리스크 점수)</b>는 화재·도난·기상 등 사고 발생 가능성을 나타냅니다<br>
      • <b style="color:#f1f5f9;">자산가치</b>는 해당 지역의 평균 재산 규모(가전제품·전자기기·고가품 등)를 반영합니다<br>
      • <b style="color:#fbbf24;">{higher_prem_gu}</b>는 위험도가 낮더라도 <b style="color:#fbbf24;">고가 자산</b>이 많아 사고 시 손해액 자체가 크기 때문에<br>
      &nbsp;&nbsp;기본 보험료(순보험료)가 높게 책정됩니다<br>
      • 즉, "사고 날 확률"은 낮아도 "사고 났을 때 피해 금액"이 커서 보험료가 높아집니다
    </div>
  </div>
</div>"""
        else:
            higher_gu   = comp_gu_b if prem_b > prem_a else comp_gu_a
            lower_gu    = comp_gu_b if prem_b < prem_a else comp_gu_a
            prem_gap    = abs(prem_diff)
            explain_html = f"""
<div style="background:linear-gradient(135deg,#052e16,#0c4a1e);border:1.5px solid #22c55e;
            border-radius:14px;padding:20px 24px;">
  <div style="display:flex;align-items:center;gap:8px;margin-bottom:12px;">
    <span style="font-size:18px;">✅</span>
    <span style="color:#bbf7d0;font-size:14px;font-weight:800;">위험도와 보험료가 일치하는 정상적인 패턴입니다</span>
  </div>
  <div style="color:#86efac;font-size:12px;line-height:1.9;">
    • <b style="color:#f1f5f9;">{higher_gu}</b>는 위험도가 높아 보험료도 높습니다 (&#8361;{prem_gap:,.0f} 차이)<br>
    • 위험도 점수가 높을수록 사고 빈도가 높아 보험사 입장에서 위험 비용이 증가합니다<br>
    • 두 구 중 더 안전한 지역에 거주하면 같은 조건으로 보험료를 절감할 수 있습니다
  </div>
</div>"""

        st.markdown(explain_html, unsafe_allow_html=True)

    # ─── 7b. Cortex LLM 보험료 차이 인사이트 ───
    if len(_comp_data) == 2 and not is_demo:
        _r1 = _comp_data[comp_gu_a]
        _r2 = _comp_data[comp_gu_b]
        _prompt = (
            "당신은 동산보험 요율 분석 전문가입니다. "
            "아래 두 자치구의 보험료 데이터를 분석하고, "
            "왜 가격이 다른지 비전문가도 이해할 수 있도록 2~3문장으로 설명하세요. "
            "반드시 실제 수치(원, 점수)를 포함하고, "
            "위험도와 자산 보호가액 중 어느 쪽이 주된 원인인지 명확히 밝히세요.\n\n"
            "[예시 출력]\n"
            "노원구는 위험도 41점으로 서초구(38점)보다 높습니다. "
            "그러나 서초구 보험료가 월 41,261원으로 더 비싼 이유는 "
            "아파트 평균 매매가가 서울 평균의 2배에 달해 "
            "자산 보호가액이 크기 때문입니다. "
            "INSURE는 이처럼 위험도와 자산 수준을 함께 반영해 최적 요율을 산출합니다.\n\n"
            "[분석 대상]\n"
            f"- {_r1['GU_NAME']}: 월 {_r1['ADJUSTED_PREMIUM_MONTHLY']:,.0f}원 | "
            f"위험도 {_r1['COMPOSITE_RISK_SCORE']:.1f}점 | "
            f"화재 {_r1['FIRE_RISK_SCORE']:.0f} | 도난 {_r1['THEFT_RISK_SCORE']:.0f} | "
            f"기준보험료 {_r1['AVG_BASE_PREMIUM']:,.0f}원\n"
            f"- {_r2['GU_NAME']}: 월 {_r2['ADJUSTED_PREMIUM_MONTHLY']:,.0f}원 | "
            f"위험도 {_r2['COMPOSITE_RISK_SCORE']:.1f}점 | "
            f"화재 {_r2['FIRE_RISK_SCORE']:.0f} | 도난 {_r2['THEFT_RISK_SCORE']:.0f} | "
            f"기준보험료 {_r2['AVG_BASE_PREMIUM']:,.0f}원\n\n"
            "[설명]"
        )
        try:
            _llm_result = session.sql(
                f"SELECT SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', $${_prompt}$$)"
            ).collect()[0][0]
            st.markdown(f"""
                <div style="background:linear-gradient(135deg,rgba(99,102,241,0.08),rgba(99,102,241,0.02));
                            border:1.5px solid rgba(99,102,241,0.3);border-left:4px solid #6366f1;
                            border-radius:12px;padding:16px 22px;margin-top:12px;">
                    <div style="font-size:11px;color:#6366f1;font-weight:700;
                                letter-spacing:1px;text-transform:uppercase;margin-bottom:8px;">
                        ✨ AI 심층 분석 · Cortex LLM
                    </div>
                    <div style="color:#1e293b;font-size:14px;line-height:1.75;">{_llm_result}</div>
                </div>
            """, unsafe_allow_html=True)
        except Exception:
            pass  # 정적 explain_html이 이미 표시됨

    # ─── 8. 전체 데이터 테이블 ───
    with st.expander("📋 전체 25개 구 데이터 보기", expanded=False):
        show_df = agg_df[[
            "GU_NAME", "ADJUSTED_PREMIUM_MONTHLY", "COMPOSITE_RISK_SCORE", "RISK_GRADE",
            "FIRE_RISK_SCORE", "THEFT_RISK_SCORE", "BUILDING_RISK_SCORE", "WEATHER_RISK_SCORE",
        ]].copy()
        show_df = show_df.sort_values("ADJUSTED_PREMIUM_MONTHLY", ascending=False).reset_index(drop=True)

        # 숫자 정수 반올림
        for _nc in ["ADJUSTED_PREMIUM_MONTHLY", "COMPOSITE_RISK_SCORE",
                    "FIRE_RISK_SCORE", "THEFT_RISK_SCORE", "BUILDING_RISK_SCORE", "WEATHER_RISK_SCORE"]:
            show_df[_nc] = show_df[_nc].round(0).astype(int)

        # 순위 컬럼 추가
        show_df.insert(0, "순위", [f"#{i+1}" for i in range(len(show_df))])

        def grade_icon(g):
            return {"고위험": "🔴 고위험", "중위험": "🟡 중위험", "저위험": "🟢 저위험"}.get(g, g)
        show_df["RISK_GRADE"] = show_df["RISK_GRADE"].apply(grade_icon)
        show_df["_diff"] = ((show_df["ADJUSTED_PREMIUM_MONTHLY"] - avg_premium) / avg_premium * 100).round(1)

        show_df.columns = ["순위", "자치구", "월보험료", "위험도 점수", "위험 등급",
                           "🔥 화재", "🔓 도난", "🏚 건물노후", "🌧 기상", "평균대비(%)"]

        # 상단 요약 통계
        sm1, sm2, sm3, sm4 = st.columns(4)
        _high_cnt = (agg_df["RISK_GRADE"] == "고위험").sum()
        _mid_cnt  = (agg_df["RISK_GRADE"] == "중위험").sum()
        _low_cnt  = (agg_df["RISK_GRADE"] == "저위험").sum()
        _max_gu   = agg_df.loc[agg_df["ADJUSTED_PREMIUM_MONTHLY"].idxmax(), "GU_NAME"]
        for _col, _icon, _val, _lbl in [
            (sm1, "🔴", f"{_high_cnt}개 구", "고위험 구"),
            (sm2, "🟡", f"{_mid_cnt}개 구", "중위험 구"),
            (sm3, "🟢", f"{_low_cnt}개 구", "저위험 구"),
            (sm4, "👑", _max_gu, "최고 보험료 구"),
        ]:
            _col.markdown(
                f'<div style="background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; '
                f'padding:10px 14px; text-align:center; margin-bottom:10px;">'
                f'<div style="font-size:1.4rem; margin-bottom:2px;">{_icon}</div>'
                f'<div style="font-size:1rem; font-weight:800; color:#1e293b;">{_val}</div>'
                f'<div style="font-size:0.72rem; color:#64748b; margin-top:2px;">{_lbl}</div>'
                f'</div>',
                unsafe_allow_html=True,
            )

        st.dataframe(
            show_df,
            use_container_width=True,
            hide_index=True,
            height=560,
            column_config={
                "순위": st.column_config.TextColumn("순위", width=50),
                "자치구": st.column_config.TextColumn("자치구", width=90),
                "월보험료": st.column_config.NumberColumn(
                    "💰 월보험료",
                    format="₩%d",
                    width=130,
                ),
                "위험도 점수": st.column_config.ProgressColumn(
                    "⚠️ 위험도",
                    format="%d점",
                    min_value=0,
                    max_value=100,
                    width=130,
                ),
                "위험 등급": st.column_config.TextColumn("등급", width=90),
                "🔥 화재": st.column_config.ProgressColumn(
                    "🔥 화재",
                    format="%d",
                    min_value=0,
                    max_value=100,
                    width=100,
                ),
                "🔓 도난": st.column_config.ProgressColumn(
                    "🔓 도난",
                    format="%d",
                    min_value=0,
                    max_value=100,
                    width=100,
                ),
                "🏚 건물노후": st.column_config.ProgressColumn(
                    "🏚 건물",
                    format="%d",
                    min_value=0,
                    max_value=100,
                    width=100,
                ),
                "🌧 기상": st.column_config.ProgressColumn(
                    "🌧 기상",
                    format="%d",
                    min_value=0,
                    max_value=100,
                    width=100,
                ),
                "평균대비(%)": st.column_config.NumberColumn(
                    "📊 평균 대비",
                    format="%+.1f%%",
                    width=100,
                ),
            },
        )

    st.caption("🟢 인구/화재/범죄: KOSIS, 소방청, 경찰청 | 🔵 위험도/보험료: INSURE 엔진")