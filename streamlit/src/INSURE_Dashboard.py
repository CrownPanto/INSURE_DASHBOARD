"""
INSURE: 동산보험 동적 설계 데이터 엔진 - Streamlit Dashboard
Snowflake Hackathon 2025Q2 | Team CrownPanto

5개 페이지:
1. 메인 대시보드: 서울 구별 리스크 히트맵 + 세그먼트 분포
2. 세그먼트 상세: 페르소나 카드 + 추천 보험설계안
3. 리스크 분석: 화재·범죄·노후도·기상 복합 스코어
4. 상담 관리: 피드백 트렌드 + 전환율
5. 보험료 시뮬레이터: 실시간 요율 시뮬레이션
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from snowflake.snowpark.context import get_active_session

# ─── 설정 ───
st.set_page_config(
    page_title="INSURE | 동산보험 동적 설계 엔진",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded"
)

session = get_active_session()

# ─── 사이드바 ───
st.sidebar.title("🛡️ INSURE")
st.sidebar.caption("동산보험 동적 설계 데이터 엔진")
st.sidebar.markdown("---")

page = st.sidebar.radio(
    "페이지 선택",
    ["📊 메인 대시보드", "👤 세그먼트 상세", "⚠️ 리스크 분석", "💬 상담 관리", "💰 보험료 시뮬레이터"]
)

# 필터
st.sidebar.markdown("---")
st.sidebar.subheader("필터")

# 기간 선택
available_months = session.sql("""
    SELECT DISTINCT YEAR_MONTH FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
    ORDER BY YEAR_MONTH DESC
""").to_pandas()

if not available_months.empty:
    selected_month = st.sidebar.selectbox("기준 년월", available_months['YEAR_MONTH'].tolist())
else:
    selected_month = '202401'

# ═══════════════════════════════════════════
# 페이지 1: 메인 대시보드
# ═══════════════════════════════════════════
if page == "📊 메인 대시보드":
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


# ═══════════════════════════════════════════
# 페이지 2: 세그먼트 상세
# ═══════════════════════════════════════════
elif page == "👤 세그먼트 상세":
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


# ═══════════════════════════════════════════
# 페이지 3: 리스크 분석
# ═══════════════════════════════════════════
elif page == "⚠️ 리스크 분석":
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


# ═══════════════════════════════════════════
# 페이지 4: 상담 관리
# ═══════════════════════════════════════════
elif page == "💬 상담 관리":
    st.title("💬 상담 관리 및 피드백 분석")

    # 상담 KPI
    consult_kpi = session.sql("""
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN CONVERSION_YN = 'Y' THEN 1 ELSE 0 END) AS converted,
            AVG(FEEDBACK_SENTIMENT) AS avg_sentiment,
            AVG(CASE WHEN CONVERSION_YN = 'Y' THEN CONVERSION_AMOUNT END) AS avg_amount
        FROM INSURE_DB.FEEDBACK.CONSULTATION_LOG
    """).to_pandas()

    if not consult_kpi.empty:
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("총 상담", f"{consult_kpi['TOTAL'].iloc[0]}건")
        c2.metric("전환 건수", f"{consult_kpi['CONVERTED'].iloc[0]}건")
        conversion_rate = consult_kpi['CONVERTED'].iloc[0] / max(consult_kpi['TOTAL'].iloc[0], 1) * 100
        c3.metric("전환율", f"{conversion_rate:.1f}%")
        c4.metric("평균 감성", f"{consult_kpi['AVG_SENTIMENT'].iloc[0]:.2f}")

    # 상담 로그
    st.subheader("📝 최근 상담 로그")
    logs = session.sql("""
        SELECT SESSION_ID, SEGMENT_CODE, CUSTOMER_AGE_GROUP, CUSTOMER_GENDER,
               QUOTED_PREMIUM, CUSTOMER_REACTION, FEEDBACK_TEXT,
               FEEDBACK_SENTIMENT, CONVERSION_YN
        FROM INSURE_DB.FEEDBACK.CONSULTATION_LOG
        ORDER BY TIMESTAMP DESC
        LIMIT 20
    """).to_pandas()

    if not logs.empty:
        st.dataframe(logs, use_container_width=True)

    # 세그먼트별 전환율
    st.subheader("📊 세그먼트별 전환율")
    seg_conversion = session.sql("""
        SELECT SEGMENT_CODE,
               COUNT(*) AS consultations,
               SUM(CASE WHEN CONVERSION_YN='Y' THEN 1 ELSE 0 END) AS conversions,
               ROUND(SUM(CASE WHEN CONVERSION_YN='Y' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS rate
        FROM INSURE_DB.FEEDBACK.CONSULTATION_LOG
        GROUP BY SEGMENT_CODE
    """).to_pandas()

    if not seg_conversion.empty:
        fig = px.bar(seg_conversion, x='SEGMENT_CODE', y='RATE',
                     color='RATE', color_continuous_scale='Greens',
                     title="세그먼트별 전환율 (%)")
        st.plotly_chart(fig, use_container_width=True)

    # Cortex LLM 피드백 분석 (시뮬레이션)
    st.markdown("---")
    st.subheader("🤖 Cortex LLM 피드백 인사이트")
    st.info("""
    **자동 생성 인사이트 (Cortex COMPLETE 기반):**

    1. **사회초년생** 세그먼트는 '전자기기파손'과 '도난' 보장에 가장 높은 관심을 보이며,
       '화재' 보장은 건물보험과 중복으로 인식하여 거절하는 경향
    2. **신혼** 세그먼트는 보험료 민감도가 높으며, 월 3만원이 심리적 저항선.
       초기 프로모션(첫 3개월 할인)이 전환율 개선에 효과적일 것으로 예상
    3. **영리치** 세그먼트는 종합 보장을 선호하며, 보장 범위의 확장(골프용품, 미술품 등)에
       추가 지불 의향이 높음
    4. **은퇴시니어** 세그먼트는 의료기기 보장에 대한 니즈가 신규 발견됨.
       기존 설계에 '의료기기특약' 추가 권장
    """)


# ═══════════════════════════════════════════
# 페이지 5: 보험료 시뮬레이터
# ═══════════════════════════════════════════
elif page == "💰 보험료 시뮬레이터":
    st.title("💰 보험료 실시간 시뮬레이터")
    st.caption("세그먼트와 지역을 선택하면 동적 보험료가 산출됩니다")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("🎯 조건 설정")

        sim_district = st.selectbox("자치구", [
            '강남구','강동구','강북구','강서구','관악구','광진구','구로구','금천구',
            '노원구','도봉구','동대문구','동작구','마포구','서대문구','서초구',
            '성동구','성북구','송파구','양천구','영등포구','용산구','은평구','종로구','중구','중랑구'
        ])

        sim_lifecycle = st.selectbox("생애주기", [
            'A1_사회초년생','A2_신혼','A3_영유아가구','A4_학령기가구','A5_중년안정','A6_은퇴시니어'
        ])

        sim_asset_type = st.selectbox("자산/소비 유형", [
            'B0_표준소비형','B1_영리치','B2_알뜰형','B3_투자적극형','B4_고자산보수형','B5_소비과다형'
        ])

        sim_risk = st.selectbox("리스크 프로파일", [
            'E1_저위험안정','E2_중위험표준','E3_고위험집중'
        ])

        sim_coverage = st.slider("보장 비율 (%)", 50, 100, 80, 5)

        sim_movable_asset = st.number_input(
            "추정 동산 가치 (만원)",
            min_value=500, max_value=100000, value=5000, step=500
        )

    with col2:
        st.subheader("📋 산출 결과")

        # 리스크 계수
        risk_factor = {'E1_저위험안정': 0.003, 'E2_중위험표준': 0.005, 'E3_고위험집중': 0.008}
        credit_factor = {'E1_저위험안정': 0.85, 'E2_중위험표준': 1.00, 'E3_고위험집중': 1.15}

        base_premium = sim_movable_asset * 10000 * risk_factor[sim_risk] * (sim_coverage / 100)
        credit_adj = credit_factor[sim_risk]

        # 지역 리스크 조회
        district_risk = session.sql(f"""
            SELECT COALESCE(AVG(COMPOSITE_RISK_SCORE), 35) AS risk_score
            FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE
            WHERE DISTRICT_NAME = '{sim_district}'
        """).to_pandas()

        region_risk = district_risk['RISK_SCORE'].iloc[0] if not district_risk.empty else 35
        region_adj = 1 + region_risk / 200

        final_premium = base_premium * credit_adj * region_adj

        st.metric("추정 동산 가치", f"₩{sim_movable_asset:,}만원")
        st.metric("기본 월보험료", f"₩{base_premium:,.0f}")

        st.markdown("**보정 계수:**")
        st.write(f"- 신용 보정: ×{credit_adj:.2f}")
        st.write(f"- 지역 리스크 보정: ×{region_adj:.2f} ({sim_district} 리스크: {region_risk:.1f})")
        st.write(f"- 보장 비율: {sim_coverage}%")

        st.markdown("---")
        st.metric("🎯 최종 월보험료", f"₩{final_premium:,.0f}", delta=f"연 ₩{final_premium*12:,.0f}")

        # 보장 항목 추천
        coverage_map = {
            'A1_사회초년생': ['전자기기파손', '도난', '화재'],
            'A2_신혼': ['가전파손', '화재', '수재', '배상책임'],
            'A3_영유아가구': ['가전파손', '화재', '어린이안전', '배상책임'],
            'A4_학령기가구': ['화재', '도난', '수재', '가전파손'],
            'A5_중년안정': ['화재', '도난', '수재', '귀금속', '고가가전'],
            'A6_은퇴시니어': ['화재', '수재', '의료기기', '배상책임']
        }

        st.markdown("---")
        st.subheader("🛡️ 추천 보장항목")
        for item in coverage_map.get(sim_lifecycle, []):
            st.checkbox(item, value=True, key=f"cov_{item}")

    # 비교 차트
    st.markdown("---")
    st.subheader("📊 구별 보험료 비교")

    comparison_df = session.sql(f"""
        SELECT DISTRICT_NAME, AVG(ADJUSTED_PREMIUM_MONTHLY) AS premium,
               AVG(COMPOSITE_RISK_SCORE) AS risk
        FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
        WHERE YEAR_MONTH = '{selected_month}'
        GROUP BY DISTRICT_NAME
        ORDER BY premium DESC
    """).to_pandas()

    if not comparison_df.empty:
        fig = px.scatter(
            comparison_df, x='RISK', y='PREMIUM',
            text='DISTRICT_NAME', size='PREMIUM',
            title="리스크 vs 보험료 (선택 구: " + sim_district + ")",
            labels={'RISK': '복합 리스크 스코어', 'PREMIUM': '평균 월보험료 (원)'}
        )
        # 선택된 구 하이라이트
        selected_row = comparison_df[comparison_df['DISTRICT_NAME'] == sim_district]
        if not selected_row.empty:
            fig.add_trace(go.Scatter(
                x=selected_row['RISK'], y=selected_row['PREMIUM'],
                mode='markers', marker=dict(size=20, color='red', symbol='star'),
                name=sim_district, showlegend=True
            ))
        fig.update_traces(textposition='top center')
        fig.update_layout(height=500)
        st.plotly_chart(fig, use_container_width=True)


# ─── 푸터 ───
st.sidebar.markdown("---")
st.sidebar.markdown("""
**INSURE v1.0**
Team CrownPanto
Snowflake Hackathon 2025Q2

*Powered by Snowflake Cortex*
""")
