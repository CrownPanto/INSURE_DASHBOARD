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
    k1.metric("서울 평균 월보험료", f"₩{avg_premium:,.0f}")
    k2.metric("서울 평균 위험도", f"{avg_risk:.1f}점")
    k3.metric("분석 대상", f"{len(agg_df)}개 자치구")

    st.markdown("---")

    # ─── 4. Top 3 vs Bottom 3 섹션 ───
    st.subheader("보험료 Top 3 vs Bottom 3")
    sorted_df = agg_df.sort_values("ADJUSTED_PREMIUM_MONTHLY", ascending=False).reset_index(drop=True)
    col_high, col_low = st.columns(2)

    with col_high:
        st.markdown("##### 🔴 보험료 높은 구")
        for i, row in sorted_df.head(3).iterrows():
            diff_pct = ((row["ADJUSTED_PREMIUM_MONTHLY"] - avg_premium) / avg_premium) * 100
            st.metric(row["GU_NAME"], f"₩{row['ADJUSTED_PREMIUM_MONTHLY']:,.0f}/월",
                      delta=f"평균 대비 +{diff_pct:.0f}%", delta_color="inverse")

    with col_low:
        st.markdown("##### 🟢 보험료 낮은 구")
        for i, row in sorted_df.tail(3).iloc[::-1].iterrows():
            diff_pct = ((row["ADJUSTED_PREMIUM_MONTHLY"] - avg_premium) / avg_premium) * 100
            st.metric(row["GU_NAME"], f"₩{row['ADJUSTED_PREMIUM_MONTHLY']:,.0f}/월",
                      delta=f"평균 대비 {diff_pct:.0f}%")

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

    # 상관계수 계산 (Pandas 사용)
    corr = agg_df["COMPOSITE_RISK_SCORE"].corr(agg_df["ADJUSTED_PREMIUM_MONTHLY"])

    # 추세선 포함 scatter 그리기
    fig = px.scatter(
        agg_df,
        x="COMPOSITE_RISK_SCORE",
        y="ADJUSTED_PREMIUM_MONTHLY",
        size="TOTAL_POPULATION",
        color="COMPOSITE_RISK_SCORE",
        hover_name="GU_NAME",
        text="GU_NAME",
        size_max=45,
        color_continuous_scale=[[0, "#10b981"], [0.5, "#f59e0b"], [1, "#ef4444"]],
    )

    # NumPy를 사용한 추세선 계산 (선형 회귀)
    z = np.polyfit(agg_df["COMPOSITE_RISK_SCORE"], agg_df["ADJUSTED_PREMIUM_MONTHLY"], 1)
    p = np.poly1d(z)
    x_trend = np.linspace(agg_df["COMPOSITE_RISK_SCORE"].min(), agg_df["COMPOSITE_RISK_SCORE"].max(), 100)
    y_trend = p(x_trend)

    fig.add_trace(go.Scatter(
        x=x_trend, y=y_trend,
        name="추세선 (선형 회귀)",
        line=dict(color="#6366f1", width=3, dash="solid"),
        mode="lines",
        hovertemplate="추세선<br>위험도: %{x:.1f}<br>예상 보험료: ₩%{y:,.0f}<extra></extra>",
    ))

    # 평균선 추가 (사분면 분석용)
    avg_risk = agg_df["COMPOSITE_RISK_SCORE"].mean()
    avg_premium = agg_df["ADJUSTED_PREMIUM_MONTHLY"].mean()

    fig.add_hline(y=avg_premium, line_dash="dash", line_color="rgba(148,163,184,0.4)",
                  annotation_text=f"평균보험료: ₩{avg_premium:,.0f}", annotation_position="right")
    fig.add_vline(x=avg_risk, line_dash="dash", line_color="rgba(148,163,184,0.4)",
                  annotation_text=f"평균위험도: {avg_risk:.1f}점", annotation_position="top")

    # 축 레이블 개선
    fig.update_xaxes(title_text="위험도 점수 →", title_font=dict(color="#cbd5e1", size=12))
    fig.update_yaxes(title_text="월 보험료 (원) →", title_font=dict(color="#cbd5e1", size=12))

    # 상관계수 박스
    fig.add_annotation(
        text=f"<b>상관관계 통계</b><br>" +
             f"피어슨 상관계수: <b>{corr:.3f}</b><br>" +
             f"R² (결정계수): <b>{corr**2:.3f}</b><br><br>" +
             f"{'✅ 강한 양의 상관' if corr > 0.7 else '⚠️ 중간 상관' if corr > 0.4 else '❓ 약한 상관'}",
        xref="paper", yref="paper",
        x=0.02, y=0.98,
        showarrow=False,
        bgcolor="rgba(15, 23, 42, 0.95)",
        bordercolor="#4f46e5",
        borderwidth=2,
        borderpad=12,
        font=dict(size=10, color="#cbd5e1", family="monospace"),
        align="left",
    )

    # 사분면 설명 추가
    fig.add_annotation(
        text="<b>사분면 해석</b><br>" +
             f"<b>우상:</b> 고위험 고보험료<br>" +
             f"<b>우하:</b> 고위험 저보험료<br>" +
             f"<b>좌상:</b> 저위험 고보험료<br>" +
             f"<b>좌하:</b> 저위험 저보험료",
        xref="paper", yref="paper",
        x=0.98, y=0.02,
        showarrow=False,
        bgcolor="rgba(15, 23, 42, 0.95)",
        bordercolor="#059669",
        borderwidth=2,
        borderpad=12,
        font=dict(size=9, color="#cbd5e1"),
        align="right",
        xanchor="right",
        yanchor="bottom",
    )

    fig.update_layout(
        height=600,
        plot_bgcolor="#0f1117",
        paper_bgcolor="#0f1117",
        font=dict(color="#f1f5f9", size=11),
        showlegend=False,
        hovermode="closest",
    )
    st.plotly_chart(fig, use_container_width=True)

    # ─── 6-2. 히트맵 (밀도 기반 상관관계 분석) ───
    st.subheader("상관관계 히트맵 (밀도 분석)")
    st.caption("구들이 몰려 있는 구간 = 어두운 색 | 더 많은 구들이 해당 위험도-보험료 조합을 가짐")

    fig_heatmap = px.density_heatmap(
        agg_df,
        x="COMPOSITE_RISK_SCORE",
        y="ADJUSTED_PREMIUM_MONTHLY",
        nbinsx=10,
        nbinsy=10,
        color_continuous_scale=[[0,"#0f1117"],[0.3,"#4f46e5"],[0.7,"#f59e0b"],[1,"#ef4444"]],
    )

    fig_heatmap.update_layout(
        height=600,
        plot_bgcolor="#0f1117",
        paper_bgcolor="#0f1117",
        font=dict(color="#f1f5f9", size=11),
        xaxis_title="위험도 점수 →",
        yaxis_title="월 보험료 (원) →",
        coloraxis_colorbar=dict(title="구의<br>밀도"),
    )

    fig_heatmap.update_xaxes(title_font=dict(color="#cbd5e1", size=12))
    fig_heatmap.update_yaxes(title_font=dict(color="#cbd5e1", size=12))

    st.plotly_chart(fig_heatmap, use_container_width=True)

    # 히트맵 해석 가이드
    with st.expander("💡 히트맵 해석 방법"):
        st.markdown("""
        ### 히트맵이 보여주는 것

        **색상이 진할수록** (어두울수록):
        - 그 위험도-보험료 조합을 가진 구가 더 많다는 뜻
        - 여러 구들이 비슷한 위험도와 보험료를 가지고 있음

        **옆의 히스토그램**:
        - **위쪽**: 위험도 분포 (구들의 위험도가 어떻게 분포하는가)
        - **오른쪽**: 보험료 분포 (구들의 보험료가 어떻게 분포하는가)

        ### 패턴 해석

        - **대각선 왼쪽 아래 어둡다** → 저위험 저보험료 구들이 많음
        - **대각선 오른쪽 위 어둡다** → 고위험 고보험료 구들이 많음
        - **대각선 패턴이 명확하다** → 위험도와 보험료의 상관관계가 강함
        """)


    # 인사이트 섹션
    with st.expander("📊 상관관계 해석 가이드"):
        st.markdown(f"""
        ### 데이터 분석 결과

        **상관계수**: {corr:.3f}
        - **1에 가까울수록**: 위험도와 보험료가 강하게 연관됨
        - **0에 가까울수록**: 위험도와 보험료의 관계가 약함

        **R² 값**: {corr**2:.3f}
        - 위험도가 보험료 변동의 **{corr**2*100:.1f}%**를 설명함

        **해석**:
        - {'✅ 위험도가 높을수록 보험료가 확실히 높다!' if corr > 0.7 else '⚠️ 위험도 외 다른 요인들도 보험료에 영향을 미친다' if corr > 0.4 else '❓ 다른 지역적/사회적 요인이 더 중요할 수 있음'}
        - 각 사분면의 구들은 서로 다른 특성을 가지고 있음
        """)

        # 각 사분면의 구들 표시
        high_risk_high_premium = agg_df[(agg_df["COMPOSITE_RISK_SCORE"] >= avg_risk) &
                                        (agg_df["ADJUSTED_PREMIUM_MONTHLY"] >= avg_premium)]
        high_risk_low_premium = agg_df[(agg_df["COMPOSITE_RISK_SCORE"] >= avg_risk) &
                                       (agg_df["ADJUSTED_PREMIUM_MONTHLY"] < avg_premium)]
        low_risk_high_premium = agg_df[(agg_df["COMPOSITE_RISK_SCORE"] < avg_risk) &
                                       (agg_df["ADJUSTED_PREMIUM_MONTHLY"] >= avg_premium)]
        low_risk_low_premium = agg_df[(agg_df["COMPOSITE_RISK_SCORE"] < avg_risk) &
                                      (agg_df["ADJUSTED_PREMIUM_MONTHLY"] < avg_premium)]

        col1, col2 = st.columns(2)
        with col1:
            st.markdown("**🔴 고위험 고보험료**")
            st.write(", ".join(high_risk_high_premium["GU_NAME"].tolist()) if len(high_risk_high_premium) > 0 else "없음")

            st.markdown("**🟢 저위험 저보험료**")
            st.write(", ".join(low_risk_low_premium["GU_NAME"].tolist()) if len(low_risk_low_premium) > 0 else "없음")

        with col2:
            st.markdown("**⚠️ 고위험 저보험료**")
            st.write(", ".join(high_risk_low_premium["GU_NAME"].tolist()) if len(high_risk_low_premium) > 0 else "없음")

            st.markdown("**💡 저위험 고보험료**")
            st.write(", ".join(low_risk_high_premium["GU_NAME"].tolist()) if len(low_risk_high_premium) > 0 else "없음")

    st.markdown("---")

    # ─── 7. 영등포 vs 서초 비교 (성혁님 v3 기능 유지 ㅡㅡ+) ───
    st.subheader("같은 보험, 다른 가격 — 왜?")
    comp_cols = st.columns(2)
    for idx, gu_name in enumerate(["영등포구", "서초구"]):
        row = agg_df[agg_df["GU_NAME"] == gu_name]
        if not row.empty:
            r = row.iloc[0]
            with comp_cols[idx]:
                st.markdown(f"#### {gu_name}")
                st.metric("월보험료", f"₩{r['ADJUSTED_PREMIUM_MONTHLY']:,.0f}")
                st.metric("위험도", f"{r['COMPOSITE_RISK_SCORE']:.1f}점")
                st.caption(f"화재 {r['FIRE_RISK_SCORE']:.0f} | 도난 {r['THEFT_RISK_SCORE']:.0f} | 건물 {r['BUILDING_RISK_SCORE']:.0f} | 기상 {r['WEATHER_RISK_SCORE']:.0f}")

    # ─── 8. 전체 데이터 테이블 ───
    with st.expander("전체 25개 구 데이터 보기"):
        show_df = agg_df[["GU_NAME","ADJUSTED_PREMIUM_MONTHLY","COMPOSITE_RISK_SCORE","RISK_GRADE"]].copy()
        show_df.columns = ["자치구", "월보험료(원)", "위험도", "등급"]
        st.dataframe(show_df.sort_values("월보험료(원)", ascending=False), use_container_width=True)

    st.caption("🟢 인구/화재/범죄: KOSIS, 소방청, 경찰청 | 🔵 위험도/보험료: INSURE 엔진")