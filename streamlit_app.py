# /streamlit_app.py (최상위 루트에 생성)
import os
import sys

# 실제 코드가 있는 폴더를 경로에 추가
sys.path.append(os.path.join(os.getcwd(), 'streamlit/src'))

# 진짜 메인 실행 파일(streamlit_app.py)의 로직을 호출하거나
# 해당 경로를 기준으로 다시 실행하게 만듭니다.
with open("streamlit/src/main.py", "r", encoding="utf-8") as f:
    exec(f.read())