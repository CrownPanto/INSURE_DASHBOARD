# """
# INSURE: 동산보험 동적 설계 데이터 엔진 - Streamlit Dashboard
# Snowflake Hackathon 2025Q2 | Team CrownPanto
# """
#
# import streamlit as st
# import importlib.util
# from snowflake.snowpark.context import get_active_session
# from snowflake.snowpark import Session
#
# # ─── 세션 설정 (환경 인식형) ───
# def get_session():
#     try:
#         # Snowflake 서버 내부에서 실행 중일 때
#         return get_active_session()
#     except:
#         # 로컬(PyCharm)에서 실행 중일 때 (.streamlit/secrets.toml 사용)
#         return Session.builder.configs(st.secrets["connections"]["snowpark"]).create()
# # 동적 모듈 로드 함수 (폴더명이 숫자로 시작할 때 발생하는 import 에러 방지)
# def load_page(file_path):
#     spec = importlib.util.spec_from_file_location("page_module", file_path)
#     page_module = importlib.util.module_from_spec(spec)
#     spec.loader.exec_module(page_module)
#     return page_module
# session = get_session()
# # ─── 설정 ───
# st.set_page_config(
#     page_title="INSURE | 동산보험 동적 설계 엔진",
#     page_icon="🛡️",
#     layout="wide",
#     initial_sidebar_state="expanded"
# )
#
# session = get_active_session()
#
# # ─── 사이드바 ───
# st.sidebar.title("🛡️ INSURE")
# st.sidebar.caption("동산보험 동적 설계 데이터 엔진")
# st.sidebar.markdown("---")
#
# page = st.sidebar.selectbox(
#     "페이지 선택",
#     ["📊 메인 대시보드", "👤 세그먼트 상세", "⚠️ 리스크 분석", "💬 상담 관리", "💰 보험료 시뮬레이터"]
# )
#
# # 필터
# st.sidebar.markdown("---")
# st.sidebar.subheader("필터")
#
# # 기간 선택
# available_months = session.sql("""
#     SELECT DISTINCT YEAR_MONTH FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
#     ORDER BY YEAR_MONTH DESC
# """).to_pandas()
#
# if not available_months.empty:
#     selected_month = st.sidebar.selectbox("기준 년월", available_months['YEAR_MONTH'].tolist())
# else:
#     selected_month = '202401'
#
# # ─── 푸터 ───
# st.sidebar.markdown("---")
# st.sidebar.markdown("""
# **INSURE v1.0**
# Team CrownPanto
# Snowflake Hackathon 2025Q2
#
# *Powered by Snowflake Cortex*
# """)
#
# # ─── 라우팅 ───
# if page == "📊 메인 대시보드":
#     page_module = load_page("streamlit/src/01_Firstpage/first_page.py")
#     page_module.show_page(session, selected_month)
#
# elif page == "👤 세그먼트 상세":
#     page_module = load_page("streamlit/src/02_Secondpage/second_page.py")
#     page_module.show_page(session, selected_month)
#
# elif page == "⚠️ 리스크 분석":
#     page_module = load_page("streamlit/src/03_Thirdpage/third_page.py")
#     page_module.show_page(session, selected_month)
#
# elif page == "💬 상담 관리":
#     page_module = load_page("streamlit/src/04_Fourthpage/fourth_page.py")
#     page_module.show_page(session, selected_month)
#
# elif page == "💰 보험료 시뮬레이터":
#     page_module = load_page("streamlit/src/05_Fifthpage/fifth_page.py")
#     page_module.show_page(session, selected_month)
"""
INSURE: 동산보험 동적 설계 데이터 엔진 - Streamlit Dashboard
Snowflake Hackathon 2025Q2 | Team CrownPanto
"""
"""
INSURE: 동산보험 동적 설계 데이터 엔진 - Streamlit Dashboard
Snowflake Hackathon 2025Q2 | Team CrownPanto
"""

import streamlit as st
import importlib.util
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark import Session

# ─── 세션 설정 (환경 인식형) ───
def get_session():
    try:
        return get_active_session()
    except:
        return Session.builder.configs(st.secrets["connections"]["snowpark"]).create()

# 동적 모듈 로드 함수 (기존 로직 유지 ㅡㅡ+)
def load_page(file_path):
    spec = importlib.util.spec_from_file_location("page_module", file_path)
    page_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(page_module)
    return page_module

session = get_session()

# ─── 설정 ───
st.set_page_config(
    page_title="INSURE | 동산보험 동적 설계 엔진",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ─── 사이드바 메뉴 상태 관리 ───
# 초기 페이지 설정
if 'current_page' not in st.session_state:
    st.session_state['current_page'] = "📊 메인 대시보드"

# ─── 사이드바 ───
# ─── 1. 사이드바 커스텀 CSS 주입 (디자인 핵심) ───
# ─── 1. 사이드바 커스텀 CSS 주입 (가독성 문제 해결) ───
st.markdown("""
    <style>
    /* 사이드바 전체 배경색 및 폰트 설정 (다크 테마 유지) */
    [data-testid="stSidebar"] {
        background-color: #111827;
    }

    /* 메뉴 제목(Main Menu, Filter) 스타일 (가독성 개선) */
    .menu-label {
        font-size: 0.85rem;
        font-weight: 600;
        color: #9CA3AF; /* <--- 더 밝은 회색으로 변경 (#6B7280 -> #9CA3AF) */
        margin: 1.5rem 0 0.5rem 0.5rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }

    /* === [가독성 해결 핵심] === 
       비활성화된 버튼 전체 스타일 (미선택 상태, Secondary 버튼) 
       아이콘과 텍스트를 모두 포함하는 전체 버튼 영역을 타겟팅합니다.
    */
    div.stButton > button[kind="secondary"] {
        background-color: transparent !important;
        border: none !important;
        text-align: left !important;
        padding: 0.6rem 1rem !important;
        width: 100% !important;
        display: flex !important;
        justify-content: flex-start !important;
        font-size: 1rem !important;
        border-radius: 8px !important;
        transition: all 0.2s ease;
        /* 기본 텍스트 색상을 더 밝게 강제 */
        color: #D1D5DB !important; /* <--- 밝은 회색으로 강제 (#9CA3AF -> #D1D5DB) */
    }

    /* === [가독성 해결 핵심] === 
       비활성화된 버튼 내부의 아이콘(span) 색상을 밝게 강제
    */
    div.stButton > button[kind="secondary"] span {
        color: #D1D5DB !important; /* <--- 밝은 회색으로 강제 */
    }

    /* 마우스 호버 시 효과 */
    div.stButton > button[kind="secondary"]:hover {
        background-color: #1F2937 !important;
        color: #FFFFFF !important;
    }
    div.stButton > button[kind="secondary"]:hover span {
        color: #FFFFFF !important;
    }

    /* 선택된 버튼 스타일 (Primary 모드) 
       기존 디자인을 유지하면서 더 강력하게 적용 
    */
    div.stButton > button[kind="primary"] {
        background-color: #3730A3 !important; /* 진한 보라색 배경 */
        color: #E0E7FF !important; /* 밝은 글자색 */
        border-left: 4px solid #6366F1 !important; /* 왼쪽에 강조선 */
        font-weight: 700 !important;
    }
    /* 선택된 버튼 내부의 아이콘 색상도 밝게 강제 */
    div.stButton > button[kind="primary"] span {
        color: #E0E7FF !important; /* <--- 밝은 글자색 */
    }

    /* 필터 섹션 제목 및 레이블 스타일 (가독성 개선) 
    */
    [data-testid="stSidebar"] label p {
        color: #9CA3AF !important; /* <--- 더 밝은 회색으로 변경 */
    }

    /* 푸터 스타일 (가독성 개선) */
    .stSidebar [data-testid="stMarkdownContainer"] p {
        color: #9CA3AF; /* <--- 더 밝은 회색으로 변경 */
    }

    </style>
    """, unsafe_allow_html=True)

# ─── 2. 사이드바 헤더 ───
st.sidebar.markdown(f"""
    <div style="padding: 1rem 0.5rem;">
        <h1 style="color: white; font-size: 1.8rem; margin-bottom: 0;">🛡️ INSURE</h1>
        <p style="color: #9CA3AF; font-size: 0.9rem;">동산보험 동적 설계 데이터 엔진</p>
    </div>
    """, unsafe_allow_html=True)

st.sidebar.markdown('<p class="menu-label">Main Menu</p>', unsafe_allow_html=True)

# ─── 3. 메뉴 내비게이션 (로직은 유지, 스타일만 적용) ───
menu_list = ["📊 메인 대시보드", "👤 세그먼트 상세", "⚠️ 리스크 분석", "💬 상담 관리", "💰 보험료 시뮬레이터"]

for menu in menu_list:
    # 현재 선택된 메뉴면 primary, 아니면 secondary로 버튼 생성
    is_active = st.session_state['current_page'] == menu
    btn_type = "primary" if is_active else "secondary"

    if st.sidebar.button(menu, use_container_width=True, type=btn_type, key=f"menu_{menu}"):
        st.session_state['current_page'] = menu
        st.rerun()
# st.sidebar.title("🛡️ INSURE")
# st.sidebar.caption("동산보험 동적 설계 데이터 엔진")
# st.sidebar.markdown("---")
#
#
#
#
# # [핵심] Radio/Selectbox 대신 버튼으로 나열 ㅡㅡ^
# menu_list = ["📊 메인 대시보드", "👤 세그먼트 상세", "⚠️ 리스크 분석", "💬 상담 관리", "💰 보험료 시뮬레이터"]
#
# for menu in menu_list:
#     # 현재 선택된 메뉴는 강조(primary)하고 나머지는 일반 버튼으로 표시
#     btn_type = "primary" if st.session_state['current_page'] == menu else "secondary"
#     if st.sidebar.button(menu, use_container_width=True, type=btn_type):
#         st.session_state['current_page'] = menu
#         st.rerun() # 클릭 즉시 페이지 갱신 ㅡㅡ+

# 현재 선택된 페이지 확정
page = st.session_state['current_page']

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
st.sidebar.markdown("**INSURE v1.0**")

# ─── 라우팅 (성혁님 기존 경로 유지 ㅡㅡ+) ───
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