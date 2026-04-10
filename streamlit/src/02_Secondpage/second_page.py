import streamlit as st
import pandas as pd
import plotly.express as px

def show_page(session, selected_month):
    st.title("👤 세그먼트 상세 분석")

    # 세그먼트 선택
    personas = session.sql("SELECT * FROM INSURE_DB.MART.MART_SEGMENT_PERSONA").to_pandas()

    selected_seg = st.selectbox(
        "세그먼트 선택",
        personas['SEGMENT_CODE'].tolist(),
        format_func=lambda x: f"{x} - {personas[personas['SEGMENT_CODE']==x]['PERSONA_NAME'].iloc[0]}"
    )

    if selected_seg:
        persona = personas[personas['SEGMENT_CODE'] == selected_seg].iloc[0]

        col1, col2 = st.columns([1, 2])

        with col1:
            st.markdown(f"### 🎭 {persona['PERSONA_NAME']}")
            st.markdown(f"**세그먼트 코드:** `{persona['SEGMENT_CODE']}`")
            st.markdown(f"**주요 동산:** {persona['KEY_ASSETS']}")
            st.markdown(f"**보장 니즈:** {persona['COVERAGE_NEEDS']}")
            st.markdown(f"**특성:** {persona['DESCRIPTION']}")

        with col2:
            # 해당 세그먼트의 구별 분포
            seg_prefix = selected_seg.split('_')[0]
            col_name = 'SEGMENT_A' if seg_prefix.startswith('A') else \
                       'SEGMENT_B' if seg_prefix.startswith('B') else \
                       'SEGMENT_C' if seg_prefix.startswith('C') else \
                       'SEGMENT_D' if seg_prefix.startswith('D') else 'SEGMENT_E'

            dist_df = session.sql(f"""
                SELECT DISTRICT_CODE, SUM(POPULATION) AS pop,
                       AVG(ESTIMATED_MOVABLE_ASSET_VALUE) AS avg_asset,
                       AVG(BASE_PREMIUM_MONTHLY) AS avg_premium
                FROM INSURE_DB.MART.MART_INSURANCE_DESIGN
                WHERE {col_name} = '{selected_seg}'
                  AND YEAR_MONTH = '{selected_month}'
                GROUP BY DISTRICT_CODE
                ORDER BY pop DESC
                LIMIT 15
            """).to_pandas()

            if not dist_df.empty:
                fig = px.bar(
                    dist_df, x='DISTRICT_CODE', y='POP',
                    color='AVG_PREMIUM',
                    color_continuous_scale='Blues',
                    title=f"{selected_seg} 세그먼트 - 구별 인구 분포"
                )
                st.plotly_chart(fig, use_container_width=True)

    # 세그먼트 교차 분석
    st.markdown("---")
    st.subheader("🔀 세그먼트 교차 분석")

    cross_df = session.sql(f"""
        SELECT SEGMENT_A, SEGMENT_B, SEGMENT_E,
               SUM(POPULATION) AS pop,
               AVG(BASE_PREMIUM_MONTHLY) AS premium
        FROM INSURE_DB.MART.MART_INSURANCE_DESIGN
        WHERE YEAR_MONTH = '{selected_month}'
        GROUP BY SEGMENT_A, SEGMENT_B, SEGMENT_E
        HAVING SUM(POPULATION) > 100
        ORDER BY pop DESC
        LIMIT 20
    """).to_pandas()

    if not cross_df.empty:
        fig = px.scatter(
            cross_df, x='POP', y='PREMIUM',
            color='SEGMENT_E', size='POP',
            hover_data=['SEGMENT_A', 'SEGMENT_B'],
            title="세그먼트 교차: 인구 vs 보험료 (크기=인구, 색상=리스크)"
        )
        st.plotly_chart(fig, use_container_width=True)