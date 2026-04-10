import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

def show_page(session, selected_month):
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