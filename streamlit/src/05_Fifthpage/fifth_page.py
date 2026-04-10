import streamlit as st
import pandas as pd

def show_page(session, selected_ym):
    st.title("📊 시스템 현황")
    st.subheader("데이터 파이프라인")
    df = pd.DataFrame({
        "레이어": ["RAW", "MART", "ANALYTICS", "RAG"],
        "상태": ["LIVE", "LIVE", "LIVE", "준비완료"]
    })
    st.table(df)
    st.subheader("기술 스택")
    st.write("Snowflake, Snowpark, Cortex, Arctic Embed, Streamlit")