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
    st.subheader("서울시 자치구 지도 — 위험도 기반")
    st.caption("구의 색상 = 위험도 | 마우스 오버 시 보험료 및 위험도 정보 확인")

    try:
        # 서울시 GeoJSON 데이터 로드 (로컬 파일)
        import os
        geojson_path = os.path.join(os.path.dirname(__file__), "../../data/seoul_gu_boundaries.geojson")

        with st.spinner("서울시 자치구 경계 데이터 로드 중..."):
            with open(geojson_path, "r", encoding="utf-8") as f:
                geojson_data = json.load(f)

        st.caption("✅ 서울시 25개 자치구 경계 데이터 로드 성공")

        # GeoJSON의 구 이름과 데이터 맞추기
        # GeoJSON에는 properties.name에 구 이름이 있음
        name_mapping = {}
        for feature in geojson_data["features"]:
            name_mapping[feature["properties"]["name"]] = feature["properties"]["name"]

        # Choropleth 맵 생성
        fig_map = px.choropleth_mapbox(
            agg_df,
            geojson=geojson_data,
            locations="GU_NAME",
            featureidkey="properties.name",
            color="COMPOSITE_RISK_SCORE",
            hover_name="GU_NAME",
            hover_data={
                "GU_NAME": False,
                "COMPOSITE_RISK_SCORE": ":.1f",
                "ADJUSTED_PREMIUM_MONTHLY": "₩{:,.0f}",
                "RISK_GRADE": True,
            },
            color_continuous_scale="RdYlGn_r",  # 빨강(고위험) ~ 초록(저위험)
            mapbox_style="carto-positron",
            zoom=10.5,
            center={"lat": 37.5665, "lon": 126.9780},
            labels={"COMPOSITE_RISK_SCORE": "위험도"},
        )

        # 경계선 명확하게 표시
        fig_map.update_traces(
            marker_line_width=2.5,
            marker_line_color="#1f2937",
        )

        fig_map.update_layout(
            height=700,
            margin=dict(l=0, r=0, t=0, b=0),
            mapbox=dict(
                style="carto-positron",
                center={"lat": 37.5665, "lon": 126.9780},
                zoom=10.5,
            ),
            coloraxis_colorbar=dict(
                title="위험도",
                thickness=15,
                len=0.7,
                x=1.02,
            ),
            font=dict(color="#f1f5f9", size=11),
        )

        st.plotly_chart(fig_map, use_container_width=True)

    except Exception as e:
        st.error(f"지도 로드 실패: {str(e)}")
        st.info("💡 대신 아래의 데이터 시각화를 확인하세요.")

    st.markdown("---")

    # ─── 6. 위험도 vs 보험료 상관관계 분석 ───
    st.subheader("위험도 vs 보험료 (상관관계 분석)")
    st.caption("위험도가 높을수록 보험료가 비싼가? 데이터로 확인하세요")

    corr = agg_df["COMPOSITE_RISK_SCORE"].corr(agg_df["ADJUSTED_PREMIUM_MONTHLY"])
    avg_risk = agg_df["COMPOSITE_RISK_SCORE"].mean()

    # ── IQR 기반 outlier 탐지 ──
    Q1 = agg_df["ADJUSTED_PREMIUM_MONTHLY"].quantile(0.25)
    Q3 = agg_df["ADJUSTED_PREMIUM_MONTHLY"].quantile(0.75)
    IQR = Q3 - Q1
    y_upper = Q3 + 1.5 * IQR

    df_main_view = agg_df[agg_df["ADJUSTED_PREMIUM_MONTHLY"] <= y_upper]
    df_outliers  = agg_df[agg_df["ADJUSTED_PREMIUM_MONTHLY"] >  y_upper]

    # ── Scatter: outlier 제외한 메인 뷰 ──
    fig = px.scatter(
        df_main_view,
        x="COMPOSITE_RISK_SCORE",
        y="ADJUSTED_PREMIUM_MONTHLY",
        size="TOTAL_POPULATION",
        color="COMPOSITE_RISK_SCORE",
        hover_name="GU_NAME",
        text="GU_NAME",
        size_max=40,
        color_continuous_scale=[[0, "#10b981"], [0.5, "#f59e0b"], [1, "#ef4444"]],
    )

    # ── outlier는 별도 마커로 표시 ──
    for _, row in df_outliers.iterrows():
        fig.add_annotation(
            x=row["COMPOSITE_RISK_SCORE"],
            y=y_upper,
            text=f"⚠️ {row['GU_NAME']} ₩{row['ADJUSTED_PREMIUM_MONTHLY']:,.0f}",
            showarrow=True, arrowhead=2, arrowcolor="#f59e0b",
            font=dict(color="#f59e0b", size=10, family="monospace"),
            bgcolor="rgba(245,158,11,0.15)", bordercolor="#f59e0b",
            borderwidth=1, borderpad=6,
            ax=0, ay=-40,
        )

    # ── 추세선 (메인 뷰 기준) ──
    z = np.polyfit(df_main_view["COMPOSITE_RISK_SCORE"], df_main_view["ADJUSTED_PREMIUM_MONTHLY"], 1)
    p_fn = np.poly1d(z)
    x_tr = np.linspace(df_main_view["COMPOSITE_RISK_SCORE"].min(), df_main_view["COMPOSITE_RISK_SCORE"].max(), 100)
    fig.add_trace(go.Scatter(
        x=x_tr, y=p_fn(x_tr),
        name="추세선",
        line=dict(color="#6366f1", width=2, dash="solid"),
        mode="lines",
        hovertemplate="추세선 | 위험도 %{x:.1f} → 예상 ₩%{y:,.0f}<extra></extra>",
    ))

    # ── 평균 기준선 ──
    fig.add_hline(y=avg_premium, line_dash="dot", line_color="rgba(148,163,184,0.5)",
                  annotation_text=f"평균보험료 ₩{avg_premium:,.0f}", annotation_position="right",
                  annotation_font=dict(color="#94a3b8", size=10))
    fig.add_vline(x=avg_risk, line_dash="dot", line_color="rgba(148,163,184,0.5)",
                  annotation_text=f"평균위험도 {avg_risk:.1f}점", annotation_position="top",
                  annotation_font=dict(color="#94a3b8", size=10))

    # ── 사분면 배경 색칠 ──
    x_min, x_max = df_main_view["COMPOSITE_RISK_SCORE"].min(), df_main_view["COMPOSITE_RISK_SCORE"].max()
    y_min = 0
    for (x0, x1, y0, y1, color, label) in [
        (x_min, avg_risk, avg_premium, y_upper,  "rgba(239,68,68,0.06)",  "저위험·고보험료"),
        (avg_risk, x_max, avg_premium, y_upper,  "rgba(239,68,68,0.12)",  "고위험·고보험료"),
        (x_min, avg_risk, y_min, avg_premium,    "rgba(16,185,129,0.06)", "저위험·저보험료"),
        (avg_risk, x_max, y_min, avg_premium,    "rgba(245,158,11,0.08)", "고위험·저보험료"),
    ]:
        fig.add_shape(type="rect", x0=x0, x1=x1, y0=y0, y1=y1,
                      fillcolor=color, line_width=0, layer="below")

    # ── Y축 범위 고정 (outlier 공간 확보) ──
    fig.update_yaxes(range=[0, y_upper * 1.15],
                     title_text="월 보험료 (원) →",
                     title_font=dict(color="#cbd5e1", size=12))
    fig.update_xaxes(title_text="위험도 점수 →",
                     title_font=dict(color="#cbd5e1", size=12))

    # ── 상관계수 박스 ──
    corr_main = df_main_view["COMPOSITE_RISK_SCORE"].corr(df_main_view["ADJUSTED_PREMIUM_MONTHLY"])
    fig.add_annotation(
        text=f"<b>상관관계 통계</b><br>"
             f"r = <b>{corr_main:.3f}</b>  R² = <b>{corr_main**2:.3f}</b><br>"
             f"{'✅ 강한 양의 상관' if corr_main>0.7 else '📈 중간 상관' if corr_main>0.4 else '➡️ 약한 상관' if corr_main>0 else '📉 음의 상관'}",
        xref="paper", yref="paper", x=0.02, y=0.98,
        showarrow=False, bgcolor="rgba(15,23,42,0.95)", bordercolor="#4f46e5",
        borderwidth=2, borderpad=10, font=dict(size=10, color="#cbd5e1", family="monospace"),
        align="left",
    )
    if len(df_outliers) > 0:
        fig.add_annotation(
            text=f"⚠️ 이상치 {len(df_outliers)}개 제외 후 분석<br>(화살표로 위치 표시)",
            xref="paper", yref="paper", x=0.98, y=0.98,
            showarrow=False, bgcolor="rgba(245,158,11,0.15)", bordercolor="#f59e0b",
            borderwidth=1, borderpad=8, font=dict(size=9, color="#fcd34d"),
            align="right", xanchor="right",
        )

    fig.update_layout(
        height=580, plot_bgcolor="#0f1117", paper_bgcolor="#0f1117",
        font=dict(color="#f1f5f9", size=11), showlegend=False, hovermode="closest",
    )
    st.plotly_chart(fig, use_container_width=True)

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
        st.info(f"⚠️ **이상치 제외** — {names} ({vals}) 는 차트에서 제외됩니다 (별도 구간)")

    # 색상: 위험도 기반
    norm = df_bar["COMPOSITE_RISK_SCORE"]
    r_min, r_max = norm.min(), norm.max()
    def risk_to_color(v):
        t = (v - r_min) / (r_max - r_min) if r_max > r_min else 0.5
        if t < 0.33: return "#10b981"
        if t < 0.66: return "#f59e0b"
        return "#ef4444"
    colors = [risk_to_color(v) for v in df_bar["COMPOSITE_RISK_SCORE"]]

    fig_bar = go.Figure()
    fig_bar.add_trace(go.Bar(
        y=df_bar["GU_NAME"],
        x=df_bar["ADJUSTED_PREMIUM_MONTHLY"],
        orientation="h",
        marker=dict(color=colors, line=dict(width=0)),
        text=[f"₩{v:,.0f}" for v in df_bar["ADJUSTED_PREMIUM_MONTHLY"]],
        textposition="outside",
        textfont=dict(size=10, color="#e2e8f0"),
        hovertemplate="<b>%{y}</b><br>월보험료: ₩%{x:,.0f}<br><extra></extra>",
    ))
    fig_bar.add_vline(x=avg_premium, line_dash="dot", line_color="#6366f1", line_width=2,
                      annotation_text=f"평균 ₩{avg_premium:,.0f}",
                      annotation_font=dict(color="#a5b4fc", size=10),
                      annotation_position="top")

    fig_bar.update_layout(
        height=max(400, len(df_bar) * 28),
        plot_bgcolor="#0f1117", paper_bgcolor="#0f1117",
        font=dict(color="#f1f5f9", size=10),
        xaxis=dict(title="월 보험료 (원)", title_font=dict(color="#94a3b8"),
                   tickformat=",", gridcolor="rgba(255,255,255,0.05)"),
        yaxis=dict(title="", tickfont=dict(size=11)),
        showlegend=False,
        margin=dict(t=20, l=80, r=100, b=40),
    )
    st.plotly_chart(fig_bar, use_container_width=True)

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