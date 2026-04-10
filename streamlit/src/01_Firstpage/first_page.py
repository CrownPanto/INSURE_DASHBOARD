import streamlit as st
import pandas as pd
import plotly.express as px

def show_page(session, selected_month):
    st.title("📊 INSURE 메인 대시보드")
    st.caption(f"기준: {selected_month} | 서울시 25개 자치구")

    # KPI 카드
    kpi_data = session.sql(f"""
        SELECT
            COUNT(DISTINCT DISTRICT_NAME) AS districts,
            SUM(TOTAL_POPULATION) AS total_pop,
            AVG(ADJUSTED_PREMIUM_MONTHLY) AS avg_premium,
            SUM(ESTIMATED_ANNUAL_MARKET_KRW) AS market_size,
            AVG(COMPOSITE_RISK_SCORE) AS avg_risk
        FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
        WHERE YEAR_MONTH = '{selected_month}'
    """).to_pandas()

    if not kpi_data.empty:
        c1, c2, c3, c4, c5 = st.columns(5)
        c1.metric("분석 구역", f"{kpi_data['DISTRICTS'].iloc[0]}개 구")
        c2.metric("분석 인구", f"{kpi_data['TOTAL_POP'].iloc[0]:,.0f}명")
        c3.metric("평균 월보험료", f"₩{kpi_data['AVG_PREMIUM'].iloc[0]:,.0f}")
        c4.metric("연간 시장규모", f"₩{kpi_data['MARKET_SIZE'].iloc[0]/100000000:,.0f}억")
        c5.metric("평균 리스크", f"{kpi_data['AVG_RISK'].iloc[0]:.1f}점")

    st.markdown("---")

    col1, col2 = st.columns([3, 2])

    with col1:
        st.subheader("🗺️ 구별 복합 리스크 스코어")
        risk_df = session.sql(f"""
            SELECT DISTRICT_NAME, COMPOSITE_RISK_SCORE, RISK_GRADE,
                   FIRE_RISK_SCORE, THEFT_RISK_SCORE, BUILDING_RISK_SCORE,
                   ADJUSTED_PREMIUM_MONTHLY, TOTAL_POPULATION
            FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
            WHERE YEAR_MONTH = '{selected_month}'
            ORDER BY COMPOSITE_RISK_SCORE DESC
        """).to_pandas()

        if not risk_df.empty:
            fig = px.bar(
                risk_df,
                x='DISTRICT_NAME',
                y='COMPOSITE_RISK_SCORE',
                color='RISK_GRADE',
                color_discrete_map={'고위험':'#ff4444', '중위험':'#ffaa00', '저위험':'#44aa44'},
                hover_data=['FIRE_RISK_SCORE', 'THEFT_RISK_SCORE', 'ADJUSTED_PREMIUM_MONTHLY'],
                title="구별 복합 리스크 스코어"
            )
            fig.update_layout(xaxis_tickangle=-45, height=400)
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("🎯 리스크 등급 분포")
        if not risk_df.empty:
            grade_count = risk_df['RISK_GRADE'].value_counts()
            fig2 = px.pie(
                values=grade_count.values,
                names=grade_count.index,
                color=grade_count.index,
                color_discrete_map={'고위험':'#ff4444', '중위험':'#ffaa00', '저위험':'#44aa44'},
                title="리스크 등급 비율"
            )
            fig2.update_layout(height=400)
            st.plotly_chart(fig2, use_container_width=True)

    # 하단: 세그먼트 분포
    st.subheader("👥 주요 세그먼트 분포")
    seg_df = session.sql(f"""
        SELECT SEGMENT_A, COUNT(*) AS cnt, SUM(POPULATION) AS total_pop,
               AVG(BASE_PREMIUM_MONTHLY) AS avg_premium
        FROM INSURE_DB.MART.MART_INSURANCE_DESIGN
        WHERE YEAR_MONTH = '{selected_month}'
        GROUP BY SEGMENT_A
        ORDER BY total_pop DESC
    """).to_pandas()

    if not seg_df.empty:
        fig3 = px.treemap(
            seg_df,
            path=['SEGMENT_A'],
            values='TOTAL_POP',
            color='AVG_PREMIUM',
            color_continuous_scale='RdYlGn_r',
            title="생애주기 세그먼트별 인구 분포 (색상: 평균 보험료)"
        )
        fig3.update_layout(height=350)
        st.plotly_chart(fig3, use_container_width=True)