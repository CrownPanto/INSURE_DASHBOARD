import streamlit as st
import importlib.util
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark import Session

# ─── 세션 및 로더 설정 ───
def get_session():
    try: return get_active_session()
    except: return Session.builder.configs(st.secrets["connections"]["snowpark"]).create()

def load_page(file_path):
    spec = importlib.util.spec_from_file_location("page_module", file_path)
    page_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(page_module)
    return page_module

session = get_session()

st.set_page_config(page_title="INSURE | 동산보험 동적 설계 엔진", page_icon="🛡️", layout="wide")

if 'current_page' not in st.session_state:
    st.session_state['current_page'] = "🗺️ 서울시 보험료 지도"

# ─── 1. 성혁님의 가독성 해결 CSS 주입 ───
st.markdown("""
    <style>
    [data-testid="stSidebar"] { background-color: #111827; }
    .menu-label { font-size: 0.85rem; font-weight: 600; color: #9CA3AF; margin: 1.5rem 0 0.5rem 0.5rem; text-transform: uppercase; letter-spacing: 0.05em; }
    div.stButton > button[kind="secondary"] { background-color: transparent !important; border: none !important; text-align: left !important; color: #D1D5DB !important; width: 100% !important; display: flex !important; justify-content: flex-start !important; }
    div.stButton > button[kind="secondary"]:hover { background-color: #1F2937 !important; color: #FFFFFF !important; }
    div.stButton > button[kind="primary"] { background-color: #3730A3 !important; color: #E0E7FF !important; border-left: 4px solid #6366F1 !important; font-weight: 700 !important; text-align: left !important; width: 100% !important; }
    [data-testid="stSidebar"] label p { color: #9CA3AF !important; }
    </style>
    """, unsafe_allow_html=True)

# ─── 2. 사이드바 구성 ───
st.sidebar.markdown(f"""<div style="padding: 1rem 0.5rem;"><h1 style="color: white; font-size: 1.8rem; margin-bottom: 0;">🛡️ INSURE</h1><p style="color: #9CA3AF; font-size: 0.9rem;">동산보험 동적 설계 데이터 엔진</p></div>""", unsafe_allow_html=True)
st.sidebar.markdown('<p class="menu-label">Main Menu</p>', unsafe_allow_html=True)

# v3용 메뉴 리스트
menu_list = ["🗺️ 서울시 보험료 지도", "🎯 맞춤 보험 시뮬레이터", "💬 AI 보험 상담", "⚙️ 엔진 상세", "📊 시스템 현황"]

for menu in menu_list:
    btn_type = "primary" if st.session_state['current_page'] == menu else "secondary"
    if st.sidebar.button(menu, use_container_width=True, type=btn_type, key=f"menu_{menu}"):
        st.session_state['current_page'] = menu
        st.rerun()

# ─── 3. 필터 및 기간 ───
st.sidebar.markdown("---")
try:
    ym_df = session.sql("SELECT DISTINCT YEAR_MONTH FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY ORDER BY YEAR_MONTH DESC").to_pandas()
    selected_month = st.sidebar.selectbox("기준 년월", ym_df['YEAR_MONTH'].tolist())
except:
    selected_month = st.sidebar.selectbox("기준 년월", ["202512"])

# ─── 4. 라우팅 (성혁님 경로 규격 유지) ───
page = st.session_state['current_page']
# ─── 라우팅 (인자 2개로 통일 ㅡㅡ+) ───
if page == "🗺️ 서울시 보험료 지도":
    page_module = load_page("streamlit/src/01_Firstpage/first_page.py")
    page_module.show_page(session, selected_month)

elif page == "🎯 맞춤 보험 시뮬레이터":
    page_module = load_page("streamlit/src/02_Secondpage/second_page.py")
    page_module.show_page(session, selected_month)

elif page == "⚙️ 엔진 상세":
    page_module = load_page("streamlit/src/03_Thirdpage/third_page.py")
    page_module.show_page(session, selected_month)

elif page == "📊 시스템 현황":
    page_module = load_page("streamlit/src/04_Fourthpage/fourth_page.py")
    page_module.show_page(session, selected_month)

elif page == "💰 보험료 시뮬레이터":
    page_module = load_page("streamlit/src/05_Fifthpage/fifth_page.py")
    page_module.show_page(session, selected_month)