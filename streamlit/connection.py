# connection.py
from snowflake.snowpark import Session
from snowflake.snowpark.context import get_active_session
import streamlit as st

def get_session():
    """
    Snowflake 세션을 가져오는 공통 함수
    SiS(Snowflake in Streamlit) 환경 우선, 로컬은 .streamlit/secrets.toml 사용
    """
    try:
        # 1. Snowflake 웹(SiS) 환경인지 확인
        return get_active_session()
    except Exception:
        # 2. 로컬 환경 - .streamlit/secrets.toml 에서 읽음 (Git에 커밋 금지)
        conn = st.secrets["connections"]["snowpark"]
        return Session.builder.configs({
            "account":   conn["account"],
            "user":      conn["user"],
            "password":  conn["password"],
            "role":      conn["role"],
            "warehouse": conn["warehouse"],
            "database":  conn["database"],
            "schema":    conn["schema"],
        }).create()
