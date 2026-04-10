import streamlit as st
import plotly.express as px
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
    _risk_cols = ["FIRE_RISK_SCORE", "THEFT_RISK_SCORE", "BUILDING_RISK_SCORE", "WEATHER_RISK_SCORE"]
    for _rc in _risk_cols:
        if _rc not in df_main.columns or df_main[_rc].sum() == 0:
            demo_ref = utils._demo_district_data()
            _map = dict(zip(demo_ref["GU_NAME"], demo_ref[_rc]))
            df_main[_rc] = df_main["GU_NAME"].map(_map).fillna(0)

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

    # ─── 5. 버블 차트 ───
    st.subheader("위험도 vs 보험료")
    st.caption("원 크기 = 인구수 | 위험할수록 오른쪽, 비쌀수록 위")
    fig = px.scatter(
        agg_df, x="COMPOSITE_RISK_SCORE", y="ADJUSTED_PREMIUM_MONTHLY",
        size="TOTAL_POPULATION", color="COMPOSITE_RISK_SCORE",
        hover_name="GU_NAME", text="GU_NAME", size_max=45,
        color_continuous_scale=[[0, "#1e2028"], [0.3, "#f97316"], [0.7, "#fb923c"], [1, "#fbbf24"]]
    )
    fig.update_layout(height=500, plot_bgcolor="#0f1117", paper_bgcolor="#0f1117", font=dict(color="#f1f5f9"))
    st.plotly_chart(fig, use_container_width=True)

    st.markdown("---")

    # ─── 6. 영등포 vs 서초 비교 (성혁님 v3 기능 유지 ㅡㅡ+) ───
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

    # ─── 7. 전체 데이터 테이블 ───
    with st.expander("전체 25개 구 데이터 보기"):
        show_df = agg_df[["GU_NAME","ADJUSTED_PREMIUM_MONTHLY","COMPOSITE_RISK_SCORE","RISK_GRADE"]].copy()
        show_df.columns = ["자치구", "월보험료(원)", "위험도", "등급"]
        st.dataframe(show_df.sort_values("월보험료(원)", ascending=False), use_container_width=True)

    st.caption("🟢 인구/화재/범죄: KOSIS, 소방청, 경찰청 | 🔵 위험도/보험료: INSURE 엔진")