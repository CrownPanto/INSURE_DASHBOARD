import pandas as pd
import streamlit as st

DEMO_DISTRICTS = [
    "강남구","강동구","강북구","강서구","관악구","광진구","구로구","금천구",
    "노원구","도봉구","동대문구","동작구","마포구","서대문구","서초구","성동구",
    "성북구","송파구","양천구","영등포구","용산구","은평구","종로구","중구","중랑구"
]

DISTRICT_PROFILES = {
    "강남구":{"pop":547000,"risk":42.3,"fire":28.5,"theft":18.2,"building":22.1,"weather":15.8,"base":52000},
    "강동구":{"pop":453000,"risk":38.7,"fire":22.1,"theft":15.3,"building":25.4,"weather":14.2,"base":41000},
    "강북구":{"pop":303000,"risk":52.8,"fire":31.2,"theft":22.5,"building":42.3,"weather":18.7,"base":38000},
    "강서구":{"pop":576000,"risk":41.2,"fire":25.8,"theft":19.1,"building":28.3,"weather":16.4,"base":43000},
    "관악구":{"pop":498000,"risk":48.5,"fire":27.3,"theft":24.8,"building":38.2,"weather":17.5,"base":40000},
    "광진구":{"pop":352000,"risk":39.4,"fire":23.5,"theft":20.1,"building":26.7,"weather":15.3,"base":44000},
    "구로구":{"pop":411000,"risk":44.1,"fire":26.2,"theft":21.3,"building":33.5,"weather":16.8,"base":39000},
    "금천구":{"pop":234000,"risk":46.3,"fire":28.8,"theft":20.7,"building":35.8,"weather":17.1,"base":37000},
    "노원구":{"pop":519000,"risk":40.5,"fire":21.3,"theft":16.8,"building":32.1,"weather":19.2,"base":36000},
    "도봉구":{"pop":326000,"risk":43.2,"fire":22.5,"theft":15.1,"building":35.7,"weather":20.3,"base":35000},
    "동대문구":{"pop":352000,"risk":47.8,"fire":29.5,"theft":23.4,"building":36.2,"weather":16.5,"base":42000},
    "동작구":{"pop":395000,"risk":44.7,"fire":24.8,"theft":19.5,"building":34.1,"weather":17.8,"base":43000},
    "마포구":{"pop":376000,"risk":40.1,"fire":24.2,"theft":21.3,"building":25.8,"weather":15.1,"base":48000},
    "서대문구":{"pop":314000,"risk":45.3,"fire":25.1,"theft":18.7,"building":37.5,"weather":18.2,"base":41000},
    "서초구":{"pop":432000,"risk":37.8,"fire":22.8,"theft":16.5,"building":19.3,"weather":14.7,"base":55000},
    "성동구":{"pop":305000,"risk":41.5,"fire":25.3,"theft":19.8,"building":27.4,"weather":15.9,"base":46000},
    "성북구":{"pop":440000,"risk":46.8,"fire":26.7,"theft":20.2,"building":38.8,"weather":18.5,"base":39000},
    "송파구":{"pop":667000,"risk":38.2,"fire":23.1,"theft":17.5,"building":21.8,"weather":14.5,"base":50000},
    "양천구":{"pop":454000,"risk":39.8,"fire":22.7,"theft":16.2,"building":28.5,"weather":15.8,"base":42000},
    "영등포구":{"pop":399000,"risk":49.2,"fire":32.1,"theft":25.3,"building":30.5,"weather":16.2,"base":45000},
    "용산구":{"pop":229000,"risk":43.5,"fire":27.8,"theft":22.1,"building":24.2,"weather":15.5,"base":53000},
    "은평구":{"pop":480000,"risk":42.7,"fire":23.8,"theft":17.5,"building":34.2,"weather":19.5,"base":38000},
    "종로구":{"pop":152000,"risk":50.3,"fire":33.5,"theft":28.2,"building":31.8,"weather":16.1,"base":48000},
    "중구":{"pop":133000,"risk":51.7,"fire":35.2,"theft":30.1,"building":28.5,"weather":15.3,"base":50000},
    "중랑구":{"pop":393000,"risk":47.1,"fire":26.3,"theft":21.8,"building":37.2,"weather":18.1,"base":37000},
}

SEGMENTS_A = {
    "A1": {"name": "신혼 가구", "desc": "결혼 1~3년, 가전 구입기", "icon": "💍", "mult": 1.05},
    "A2": {"name": "유아기 가구", "desc": "영유아 자녀, 안전 최우선", "icon": "👶", "mult": 1.12},
    "A3": {"name": "아동기 가구", "desc": "초등 자녀, 활동 범위 확대", "icon": "🎒", "mult": 1.08},
    "A4": {"name": "청년 1인 가구", "desc": "20~30대, 소형 가전 중심", "icon": "🧑‍💻", "mult": 0.88},
    "A5": {"name": "중년 가족", "desc": "40~50대, 고가 가구/가전", "icon": "👨‍👩‍👧‍👦", "mult": 1.15},
    "A6": {"name": "노년 가구", "desc": "60대+, 오래된 가전/가구", "icon": "👴", "mult": 1.20},
}

SEGMENTS_B = {
    "B1": {"name": "가전 중심", "desc": "냉장고/세탁기/에어컨 등", "icon": "🏠", "mult": 1.00},
    "B2": {"name": "전자기기 중심", "desc": "PC/노트북/카메라 등", "icon": "💻", "mult": 0.95},
    "B3": {"name": "가구 중심", "desc": "소파/침대/장롱 등", "icon": "🛋️", "mult": 0.90},
    "B4": {"name": "자동차 포함", "desc": "차량 + 동산 패키지", "icon": "🚗", "mult": 1.25},
    "B5": {"name": "귀금속/명품", "desc": "보석/시계/명품백 등", "icon": "💎", "mult": 1.40},
}

PRESETS = [
    {"name": "영등포 청년 A4+B2", "district": "영등포구", "seg_a": "A4", "seg_b": "B2",
     "income": 35, "desc": "영등포 원룸 1인가구, 노트북+모니터 중심", "active": True,
     "persona": "김민수 (28세) — 영등포구 당산동 원룸, IT 프리랜서",
     "default_items": ["가전제품", "전자기기", "의류/생활"]},
    {"name": "서초 중년가족 A5+B1", "district": "서초구", "seg_a": "A5", "seg_b": "B1",
     "income": 80, "desc": "서초 아파트 4인가족, 고가 가전 다수", "active": True,
     "persona": "박지영 (47세) — 서초구 반포동 아파트, 4인 가족",
     "default_items": ["가전제품", "전자기기", "가구류", "의류/생활"]},
    {"name": "강북 노년 A6+B3", "district": "강북구", "seg_a": "A6", "seg_b": "B3",
     "income": 30, "desc": "강북 단독주택, 오래된 가구 중심", "active": False,
     "persona": "이순자 (68세) — 강북구 수유동 단독주택",
     "default_items": ["가전제품", "가구류", "의류/생활"]},
    {"name": "송파 신혼 A1+B4", "district": "송파구", "seg_a": "A1", "seg_b": "B4",
     "income": 60, "desc": "송파 신혼부부, 차량+신규 가전", "active": False,
     "persona": "최현우·한소희 (31·29세) — 송파구 잠실 신축 아파트",
     "default_items": ["가전제품", "전자기기", "자동차부품", "가구류"]},
]

COVERAGE_ITEMS = {
    "가전제품": {"limit": 5000000, "damage_rate": 0.032, "icon": "🏠", "examples": "냉장고, 세탁기, 에어컨, TV"},
    "전자기기": {"limit": 3000000, "damage_rate": 0.045, "icon": "💻", "examples": "노트북, 데스크탑, 카메라, 태블릿"},
    "가구류": {"limit": 3000000, "damage_rate": 0.018, "icon": "🛋️", "examples": "소파, 침대, 장롱, 식탁"},
    "자동차부품": {"limit": 10000000, "damage_rate": 0.028, "icon": "🚗", "examples": "차량 내 동산, 블랙박스"},
    "귀금속/명품": {"limit": 2000000, "damage_rate": 0.055, "icon": "💎", "examples": "보석, 시계, 명품백"},
    "의류/생활": {"limit": 1000000, "damage_rate": 0.015, "icon": "👔", "examples": "의류, 침구, 주방용품"},
}

def _demo_district_data():
    # DB 로직과 동기화 — IQR 클램핑 + 선형 리스크 보정
    import numpy as np
    bases = [DISTRICT_PROFILES[gu]["base"] for gu in DEMO_DISTRICTS]
    q1, q3 = np.percentile(bases, 25), np.percentile(bases, 75)
    iqr = q3 - q1
    lower_bound = q1 - 1.5 * iqr
    upper_bound = q3 + 1.5 * iqr

    rows = []
    for gu in DEMO_DISTRICTS:
        p = DISTRICT_PROFILES.get(gu, {})
        grade = "A" if p["risk"] < 38 else "B" if p["risk"] < 42 else "C" if p["risk"] < 47 else "D" if p["risk"] < 52 else "E"
        # IQR 클램핑 적용 (DB의 LEAST/GREATEST와 동일)
        clamped_base = max(min(p["base"], upper_bound), lower_bound)
        # DB 공식: base * (1 + risk/200) * credit_factor (데모는 신용 1.05 가정)
        adj_premium = int(clamped_base * (1 + p["risk"] / 200.0) * 1.05)
        market = int(p["pop"] * adj_premium * 0.03 / 1e8) * 1e8
        rows.append({
            "GU_NAME": gu, "TOTAL_POPULATION": p["pop"], "COMPOSITE_RISK_SCORE": p["risk"], "RISK_GRADE": grade,
            "AVG_BASE_PREMIUM": p["base"], "ADJUSTED_PREMIUM_MONTHLY": adj_premium, "ESTIMATED_ANNUAL_MARKET_KRW": market,
            "FIRE_RISK_SCORE": p["fire"], "THEFT_RISK_SCORE": p["theft"], "BUILDING_RISK_SCORE": p["building"],
            "WEATHER_RISK_SCORE": p["weather"], "YEAR_MONTH": "202512",
        })
    return pd.DataFrame(rows)

def calc_premium(district, seg_a_key, seg_b_key, income=50, selected_items=None):
    p = DISTRICT_PROFILES.get(district, DISTRICT_PROFILES["영등포구"])
    risk_score = p["risk"]
    seg_a = SEGMENTS_A[seg_a_key]
    seg_b = SEGMENTS_B[seg_b_key]
    base_fire_rate, severity, loading_rate = 0.001125, 15000000, 0.51
    fire_freq = base_fire_rate * (p["fire"] / 26.0)
    pure = fire_freq * severity
    experience = pure * (income / 50.0)
    if risk_score < 25: risk_mult = 0.85 + (risk_score / 25.0) ** 0.7 * 0.15
    elif risk_score < 40: risk_mult = 1.00 + (risk_score - 25) / 100.0
    elif risk_score < 60: risk_mult = 1.15 + ((risk_score - 40) / 20.0) ** 1.5 * 0.35
    elif risk_score < 80: risk_mult = 1.50 + ((risk_score - 60) / 20.0) ** 1.8 * 0.50
    else: risk_mult = min(2.00 + (risk_score - 80) * 0.02, 2.50)
    risk_classified = experience * risk_mult
    loaded = risk_classified * (1 + loading_rate)
    credible = loaded
    segment_mult = seg_a["mult"] * seg_b["mult"]
    segment_adjusted = credible * segment_mult
    item_addon = 0
    if selected_items:
        for item_name in selected_items:
            if item_name in COVERAGE_ITEMS:
                ci = COVERAGE_ITEMS[item_name]
                item_addon += ci["limit"] * ci["damage_rate"] / 12
    total_with_items = segment_adjusted + item_addon
    monthly_income = income * 1_000_000 / 12
    cap = monthly_income * 0.02
    final = min(total_with_items, cap) if cap > 0 else total_with_items
    return {
        "pure": round(pure), "experience": round(experience), "risk_classified": round(risk_classified),
        "risk_mult": risk_mult, "loaded": round(loaded), "credible": round(credible),
        "segment_adjusted": round(segment_adjusted), "segment_mult": segment_mult, "item_addon": round(item_addon),
        "total_with_items": round(total_with_items), "final": round(final), "capped": total_with_items > cap if cap > 0 else False,
        "fire_freq": fire_freq, "risk_score": risk_score,
    }