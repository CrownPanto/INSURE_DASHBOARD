import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

# 🎨 Streamlit 페이지 설정 (테마 및 제목)
st.set_page_config(
    page_title="INSURE 메인 대시보드",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# 🎨 테마 설정 (어두운 테마) - .streamlit/config.toml을 사용하는 것이 좋습니다.
# 여기서는 코드 내에서 시각적 개선을 보여주기 위해 plotly 테마를 사용합니다.
PLOTLY_TEMPLATE = 'plotly_dark'
CUSTOM_COLORS = {'고위험': '#ff4444', '중위험': '#ffaa00', '저위험': '#44aa44'}
MISSING_COLOR = '#ff9999'  # 미산정 색상


# 가정: session 객체는 이미 정의되어 있습니다.

def show_page(session, selected_month):
    st.title("📊 INSURE 메인 대시보드")
    st.caption(f"기준: {selected_month} | 서울시 25개 자치구")
    st.markdown("---")

    # 1️⃣ KPI 카드: 현황 요약 (맨 위 컨테이너 배치)
    with st.container():
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
            # 세련된 메트릭 디자인
            c1.metric("분석 구역", f"{kpi_data['DISTRICTS'].iloc[0]}개 구", "+2개")
            c2.metric("분석 인구", f"{kpi_data['TOTAL_POP'].iloc[0] / 10000:,.1f}만명", "-1.5%")
            c3.metric("평균 월보험료", f"₩{kpi_data['AVG_PREMIUM'].iloc[0]:,.0f}", "+₩2,300")
            c4.metric("연간 시장규모", f"₩{kpi_data['MARKET_SIZE'].iloc[0] / 100000000:,.0f}억", "+5%")
            c5.metric("평균 리스크", f"{kpi_data['AVG_RISK'].iloc[0]:.1f}점", "+0.2점")
        else:
            st.warning("데이터가 없습니다.")

    st.markdown("---")

    # 2️⃣ 리스크 분석 (중간 섹션)
    col1, col2 = st.columns([3, 2])

    with col1:
        st.subheader("🗺️ 구별 복합 리스크 스코어")  # 포맷 유지

        # 1. SQL에서 '구' 단위로 확실히 묶고(GROUP BY), 상위 25개만 가져오기
        # Y축에 변별력이 있는 ADJUSTED_PREMIUM_MONTHLY를 세우는 것을 추천합니다.
        risk_df = session.sql(f"""
            SELECT 
                DISTRICT_NAME, 
                AVG(COMPOSITE_RISK_SCORE) AS COMPOSITE_RISK_SCORE,
                AVG(ADJUSTED_PREMIUM_MONTHLY) AS PREMIUM,
                MAX(RISK_GRADE) AS RISK_GRADE
            FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
            WHERE YEAR_MONTH = '{selected_month}'
            GROUP BY DISTRICT_NAME
            ORDER BY PREMIUM DESC 
            LIMIT 25
        """).to_pandas()

        if not risk_df.empty:
            # 2. Y축을 'PREMIUM'으로 설정하여 그래프에 높낮이를 줍니다.
            fig = px.bar(
                risk_df,
                x='DISTRICT_NAME',
                y='PREMIUM',  # 리스크 점수 대신 보험료를 Y축으로 (변별력 확보)
                color='COMPOSITE_RISK_SCORE',  # 점수는 색상으로 표현
                color_continuous_scale='Reds',
                hover_data=['COMPOSITE_RISK_SCORE', 'RISK_GRADE'],
                template=PLOTLY_TEMPLATE
            )

            # 3. 레이아웃 최적화 (막대 간격 및 폰트)
            fig.update_layout(
                xaxis_tickangle=-45,
                height=500,
                margin=dict(t=10, b=120),
                bargap=0.3  # 막대 사이 간격을 줘서 '바코드' 느낌 제거
            )
            fig.update_yaxes(title='평균 월보험료 (원)')
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.warning("데이터가 없습니다.")

    with col2:
        st.subheader("🎯 리스크 등급 분포")
        if not risk_df.empty:
            # 파이 차트 개선: 데이터 다양성 표시, 어두운 테마, 백분율 레이블
            grade_count = risk_df['RISK_GRADE'].value_counts()
            fig2 = px.pie(
                values=grade_count.values,
                names=grade_count.index,
                color=grade_count.index,
                color_discrete_map={**CUSTOM_COLORS, '미산정': MISSING_COLOR},
                title=None,  # 제목 중복 제거
                template=PLOTLY_TEMPLATE  # 어두운 테마 적용
            )
            fig2.update_traces(textinfo='percent+label', hole=.3)  # 텍스트 레이블 및 도넛 스타일
            fig2.update_layout(height=500)
            st.plotly_chart(fig2, use_container_width=True)
        else:
            st.warning("데이터가 없습니다.")

    st.markdown("---")

    # 3️⃣ 하단: 세그먼트 분포
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
        # 트립맵 개선: 어두운 테마, 색상 스케일 조정
        fig3 = px.treemap(
            seg_df,
            path=['SEGMENT_A'],
            values='TOTAL_POP',
            color='AVG_PREMIUM',
            color_continuous_scale='RdYlGn_r',  # 역색상 스케일 (고보험료=빨강)
            title=None,  # 제목 중복 제거
            template=PLOTLY_TEMPLATE  # 어두운 테마 적용
        )
        fig3.update_layout(height=400)
        st.plotly_chart(fig3, use_container_width=True)
    else:
        st.warning("데이터가 없습니다.")