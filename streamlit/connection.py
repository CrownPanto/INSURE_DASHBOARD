# connection.py
from snowflake.snowpark import Session
from snowflake.snowpark.context import get_active_session
import streamlit as st

def get_session():
    """
    Snowflake 세션을 가져오는 공통 함수
    """
    try:
        # 1. Snowflake 웹(SiS) 환경인지 확인
        return get_active_session()
    except Exception:
        # 2. 로컬(PyCharm) 환경일 경우 직접 연결
        # 보안을 위해 실제 서비스 시에는 st.secrets 등을 쓰는 게 좋지만,
        # 일단 지금은 성혁 님 로컬용으로 아래 정보를 채우세요.
        connection_parameters = {
            "account": "nfkpxoq-pe61822",
            "user": "likewise95",
            "password": "Cnrrn1187cnrrn1187*",
            "role": "ACCOUNTADMIN",
            "warehouse": "COMPUTE_WH",
            "database": "성혁님_DB명",
            "schema": "PUBLIC"
        }
        return Session.builder.configs(connection_parameters).create()