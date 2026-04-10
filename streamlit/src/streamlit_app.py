"""
INSURE: 동산보험 동적 설계 데이터 엔진 - Streamlit Dashboard
Snowflake Hackathon 2025Q2 | Team CrownPanto
"""

import streamlit as st
import importlib.util
from snowflake.snowpark.context import get_active_session

# 동적 모듈 로드 함수 (폴더명이 숫자로 시작할 때 발생하는 import 에러 방지)
def load_page(file_path):
    spec = importlib.util.spec_from_file_location("page_module", file_path)
    page_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(page_module)
    return page_module

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

# ─── 푸터 ───
st.sidebar.markdown("---")
st.sidebar.markdown("""
**INSURE v1.0**
Team CrownPanto
Snowflake Hackathon 2025Q2

*Powered by Snowflake Cortex*
""")

# ─── 라우팅 ───
if page == "📊 메인 대시보드":
    page_module = load_page("streamlit/src/01_Firstpage/first_page.py")
    page_module.show_page(session, selected_month)

elif page == "👤 세그먼트 상세":
    page_module = load_page("streamlit/src/02_Secondpage/second_page.py")
    page_module.show_page(session, selected_month)

elif page == "⚠️ 리스크 분석":
    page_module = load_page("streamlit/src/03_Thirdpage/third_page.py")
    page_module.show_page(session, selected_month)

elif page == "💬 상담 관리":
    page_module = load_page("streamlit/src/04_Fourthpage/fourth_page.py")
    page_module.show_page(session, selected_month)

elif page == "💰 보험료 시뮬레이터":
    page_module = load_page("streamlit/src/05_Fifthpage/fifth_page.py")
    page_module.show_page(session, selected_month)