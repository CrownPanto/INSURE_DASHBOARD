import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

def show_page(session, selected_month):
    st.title("⚠️ 복합 리스크 분석")

    # 리스크 레이더 차트
    risk_detail = session.sql("""
        SELECT DISTRICT_NAME, YEAR,
               FIRE_RISK_SCORE, THEFT_RISK_SCORE, BUILDING_RISK_SCORE,
               WEATHER_RISK_SCORE, SAFETY_INFRA_SCORE, CCTV_SECURITY_SCORE,
               COMPOSITE_RISK_SCORE, RISK_GRADE
        FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE
        WHERE YEAR = (SELECT MAX(YEAR) FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE)
        ORDER BY COMPOSITE_RISK_SCORE DESC
    """).to_pandas()

    if not risk_detail.empty:
        selected_districts = st.multiselect(
            "비교할 구 선택 (최대 4개)",
            risk_detail['DISTRICT_NAME'].tolist(),
            default=risk_detail['DISTRICT_NAME'].tolist()[:3],
            max_selections=4
        )

        if selected_districts:
            fig = go.Figure()
            categories = ['화재', '도난', '건물노후', '기상', '안전인프라(역)', 'CCTV(역)']

            for district in selected_districts:
                row = risk_detail[risk_detail['DISTRICT_NAME'] == district].iloc[0]
                values = [
                    row['FIRE_RISK_SCORE'],
                    row['THEFT_RISK_SCORE'],
                    row['BUILDING_RISK_SCORE'],
                    row['WEATHER_RISK_SCORE'],
                    100 - row['SAFETY_INFRA_SCORE'],  # 역수 (높을수록 위험)
                    100 - row['CCTV_SECURITY_SCORE']
                ]
                fig.add_trace(go.Scatterpolar(
                    r=values + [values[0]],
                    theta=categories + [categories[0]],
                    fill='toself',
                    name=f"{district} (종합: {row['COMPOSITE_RISK_SCORE']:.1f})"
                ))

            fig.update_layout(
                polar=dict(radialaxis=dict(visible=True, range=[0, 100])),
                showlegend=True, height=500,
                title="구별 리스크 프로파일 레이더"
            )
            st.plotly_chart(fig, use_container_width=True)

        # 리스크 상세 테이블
        st.subheader("📋 전체 구 리스크 순위")
        st.dataframe(
            risk_detail[['DISTRICT_NAME','COMPOSITE_RISK_SCORE','RISK_GRADE',
                         'FIRE_RISK_SCORE','THEFT_RISK_SCORE','BUILDING_RISK_SCORE',
                         'WEATHER_RISK_SCORE']].style.background_gradient(
                subset=['COMPOSITE_RISK_SCORE'], cmap='RdYlGn_r'
            ),
            use_container_width=True, height=400
        )

    # 화재 예측
    st.markdown("---")
    st.subheader("🔮 화재 예측 (Cortex FORECAST)")
    forecast_df = session.sql("""
        SELECT DISTRICT_NAME, FORECAST_YEAR, PREDICTED_FIRES, LOWER_95, UPPER_95
        FROM INSURE_DB.ANALYTICS.V_FIRE_FORECAST_MANUAL
        ORDER BY PREDICTED_FIRES DESC
    """).to_pandas()

    if not forecast_df.empty:
        fig = px.bar(
            forecast_df[forecast_df['FORECAST_YEAR']==2025],
            x='DISTRICT_NAME', y='PREDICTED_FIRES',
            error_y=forecast_df[forecast_df['FORECAST_YEAR']==2025]['UPPER_95'] - forecast_df[forecast_df['FORECAST_YEAR']==2025]['PREDICTED_FIRES'],
            title="2025년 구별 화재 예측 건수 (95% 신뢰구간)"
        )
        fig.update_layout(xaxis_tickangle=-45)
        st.plotly_chart(fig, use_container_width=True)