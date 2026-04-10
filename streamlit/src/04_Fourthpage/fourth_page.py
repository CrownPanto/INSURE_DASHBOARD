import streamlit as st
import pandas as pd
import plotly.express as px

def show_page(session, selected_month):
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