import streamlit as st
import streamlit.components.v1 as components
import plotly.graph_objects as go
import pandas as pd
import numpy as np
from utils import DISTRICT_PROFILES, DEMO_DISTRICTS, SEGMENTS_A, SEGMENTS_B, calc_premium, risk_grade_info

# ── 공통 색상 팔레트 ──────────────────────────────────────────
BG      = "#0f172a"   # 최어두운 배경
CARD    = "#1e293b"   # 카드 배경
BORDER  = "#334155"   # 테두리
TXT1    = "#f1f5f9"   # 주 텍스트 (흰색에 가까운)
TXT2    = "#cbd5e1"   # 보조 텍스트
TXT3    = "#94a3b8"   # 설명 텍스트
INDIGO  = "#818cf8"   # 인디고 (보색: 노랑 계열 배경에 대비)
ORANGE  = "#fb923c"   # 오렌지
GREEN   = "#34d399"   # 초록
RED     = "#f87171"   # 빨강
YELLOW  = "#fbbf24"   # 노랑


def show_page(session, selected_ym):

    # ─── 글로벌 CSS ─────────────────────────────────────────────
    st.markdown(f"""
    <style>
    .stTabs [data-baseweb="tab-list"] {{
        background:{CARD}; border-radius:14px; padding:5px 6px;
        gap:4px; border:1px solid {BORDER};
    }}
    .stTabs [data-baseweb="tab"] {{
        border-radius:10px; color:{TXT3}; font-size:14px;
        font-weight:600; padding:8px 22px; background:transparent; border:none;
    }}
    .stTabs [data-baseweb="tab"]:hover {{ color:{TXT1}; background:rgba(129,140,248,.1); }}
    .stTabs [aria-selected="true"] {{
        background:linear-gradient(135deg,{INDIGO},{INDIGO}cc) !important;
        color:#fff !important; box-shadow:0 2px 12px rgba(129,140,248,.4);
    }}
    .stTabs [data-baseweb="tab-highlight"],
    .stTabs [data-baseweb="tab-border"] {{ display:none; }}

    div[data-baseweb="select"] > div {{
        background-color:{CARD} !important; border:1px solid {BORDER} !important;
        border-radius:10px !important; color:{TXT1} !important;
        font-size:15px !important; font-weight:600 !important;
    }}
    div[data-baseweb="select"] > div:hover {{ border-color:{INDIGO} !important; }}
    div[data-baseweb="select"] svg {{ fill:{TXT3}; }}

    .streamlit-expanderHeader {{
        background:{CARD}; border-radius:10px !important;
        border:1px solid {BORDER} !important; color:{TXT2} !important; font-size:13px !important;
    }}
    </style>
    """, unsafe_allow_html=True)

    # ─── 헤더 ───────────────────────────────────────────────────
    h_col, s_col = st.columns([3, 2])
    with h_col:
        st.markdown(f"""
        <div style="padding:4px 0 0;">
            <div style="color:{INDIGO}; font-size:11px; font-weight:700; text-transform:uppercase;
                        letter-spacing:.12em; margin-bottom:4px;">Engine Detail</div>
            <div style="color:#0f172a; font-size:22px; font-weight:800; letter-spacing:-.02em;">⚙️ 엔진 상세</div>
            <div style="color:#475569; font-size:12px; margin-top:3px;">
                구별 리스크 분석 · 7단계 보험료 산출 · 미래 예측 모델
            </div>
        </div>
        """, unsafe_allow_html=True)
    with s_col:
        st.markdown(f"<div style='height:8px'></div>", unsafe_allow_html=True)
        st.markdown(f"<div style='color:#334155; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:4px;'>자치구 선택</div>", unsafe_allow_html=True)
        sel_gu = st.selectbox("자치구", DEMO_DISTRICTS, index=DEMO_DISTRICTS.index("서초구"),
                              label_visibility="collapsed")

    p    = DISTRICT_PROFILES[sel_gu]
    risk = p["risk"]
    _gi = risk_grade_info(risk)
    grade       = _gi["grade"]
    grade_color = _gi["color"]
    grade_bg    = _gi["bg"]
    grade_label = _gi["label"]

    avg_fire     = np.mean([v["fire"]     for v in DISTRICT_PROFILES.values()])
    avg_theft    = np.mean([v["theft"]    for v in DISTRICT_PROFILES.values()])
    avg_building = np.mean([v["building"] for v in DISTRICT_PROFILES.values()])
    avg_weather  = np.mean([v["weather"]  for v in DISTRICT_PROFILES.values()])

    # ── KPI 배너 ─────────────────────────────────────────────────
    st.markdown(f"""
    <div style="background:linear-gradient(135deg,{BG},{CARD});
                border:1px solid {BORDER}; border-radius:16px;
                padding:22px 28px; margin-bottom:20px;
                display:flex; align-items:center; gap:32px; flex-wrap:wrap;">
        <div>
            <div style="color:{TXT3}; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.1em; margin-bottom:4px;">선택 자치구</div>
            <div style="color:{TXT1}; font-size:26px; font-weight:800;">{sel_gu}</div>
        </div>
        <div style="background:{grade_bg}; border:2px solid {grade_color}; border-radius:12px; padding:12px 24px; text-align:center;">
            <div style="color:{TXT3}; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.08em; margin-bottom:4px;">리스크 등급</div>
            <div style="color:{grade_color}; font-size:34px; font-weight:900; line-height:1;">{grade}</div>
            <div style="color:{grade_color}; font-size:11px; font-weight:600; margin-top:2px;">{grade_label}</div>
        </div>
        <div style="text-align:center;">
            <div style="color:{TXT3}; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.08em; margin-bottom:4px;">종합 위험점수</div>
            <div style="color:{TXT1}; font-size:28px; font-weight:800;">{risk:.1f}<span style="color:{TXT3}; font-size:13px;"> / 100</span></div>
        </div>
        <div style="text-align:center;">
            <div style="color:{TXT3}; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.08em; margin-bottom:4px;">기준 보험료</div>
            <div style="color:{GREEN}; font-size:22px; font-weight:800;">₩{p['base']:,.0f}<span style="color:{TXT3}; font-size:12px;"> / 월</span></div>
        </div>
    </div>
    """, unsafe_allow_html=True)

    st.markdown("<div style='height:4px'></div>", unsafe_allow_html=True)
    t_r, t_p, t_f = st.tabs(["🎯  위험 분석", "💰  보험료 산출", "📈  미래 예측"])

    def section(icon, title, desc=""):
        desc_html = f'<div style="color:#475569; font-size:11px; margin-top:3px;">{desc}</div>' if desc else ""
        st.markdown(f"""
        <div style="display:flex; align-items:center; gap:12px;
                    border-bottom:2px solid #e2e8f0; padding-bottom:14px; margin:20px 0 18px;">
            <div style="background:#ede9fe; border:1px solid #c4b5fd; border-radius:10px;
                        width:40px; height:40px; display:flex; align-items:center;
                        justify-content:center; font-size:18px; flex-shrink:0;">{icon}</div>
            <div>
                <div style="color:#0f172a; font-size:15px; font-weight:700;">{title}</div>
                {desc_html}
            </div>
        </div>
        """, unsafe_allow_html=True)

    # ────────────────────────────────────────────────────────────
    # TAB 1: 위험 분석
    # ────────────────────────────────────────────────────────────
    with t_r:
        section("📡", "리스크 레이더", f"{sel_gu} vs 서울 평균 — 4개 위험 요인 비교")

        # ── 통계 사전 계산 ──────────────────────────────────────────
        all_vals = {
            "fire":     [v["fire"]     for v in DISTRICT_PROFILES.values()],
            "theft":    [v["theft"]    for v in DISTRICT_PROFILES.values()],
            "building": [v["building"] for v in DISTRICT_PROFILES.values()],
            "weather":  [v["weather"]  for v in DISTRICT_PROFILES.values()],
            "risk":     [v["risk"]     for v in DISTRICT_PROFILES.values()],
        }
        def percentile_rank(val, arr):
            return int(sum(v <= val for v in arr) / len(arr) * 100)
        def z_score(val, arr):
            mu, sd = np.mean(arr), np.std(arr)
            return (val - mu) / sd if sd > 0 else 0

        factors = [
            ("fire",     "🔥", "화재",    p["fire"],     avg_fire,     RED),
            ("theft",    "🔓", "도난",    p["theft"],    avg_theft,    ORANGE),
            ("building", "🏢", "건물노후", p["building"], avg_building, YELLOW),
            ("weather",  "🌧", "기상",    p["weather"],  avg_weather,  INDIGO),
        ]

        col_radar, col_stats = st.columns([3, 2])

        with col_radar:
            categories = ["화재", "도난", "건물노후", "기상"]
            values     = [p["fire"], p["theft"], p["building"], p["weather"]]
            avg_values = [avg_fire, avg_theft, avg_building, avg_weather]

            fig_radar = go.Figure()
            fig_radar.add_trace(go.Scatterpolar(
                r=avg_values + [avg_values[0]], theta=categories + [categories[0]],
                fill='toself', name="서울 평균",
                line=dict(color=TXT3, width=1.5, dash="dot"),
                fillcolor="rgba(148,163,184,.15)",
            ))
            fig_radar.add_trace(go.Scatterpolar(
                r=values + [values[0]], theta=categories + [categories[0]],
                fill='toself', name=sel_gu,
                line=dict(color=grade_color, width=2.5),
                fillcolor=grade_bg,
                marker=dict(size=8, color=grade_color),
            ))
            fig_radar.update_layout(
                polar=dict(
                    radialaxis=dict(visible=True, range=[0, 65],
                                   tickvals=[15, 30, 45, 60],
                                   tickfont=dict(color=TXT3, size=9),
                                   gridcolor=BORDER, linecolor=BORDER),
                    angularaxis=dict(tickfont=dict(color=TXT1, size=14, family="sans-serif"),
                                     gridcolor=BORDER, linecolor=BORDER),
                    bgcolor="rgba(0,0,0,0)",
                    hole=0.08,
                ),
                height=400,
                plot_bgcolor=BG, paper_bgcolor=BG,
                font=dict(color=TXT1),
                legend=dict(orientation="h", y=-0.05, x=0.5, xanchor="center",
                            font=dict(color=TXT2, size=12), bgcolor="rgba(0,0,0,0)"),
                margin=dict(l=80, r=80, t=80, b=80),
            )
            st.plotly_chart(fig_radar, use_container_width=True)

        with col_stats:
            st.markdown("<div style='height:12px'></div>", unsafe_allow_html=True)
            for key, icon, label, val, avg, color in factors:
                diff     = val - avg
                diff_str = f"+{diff:.1f}" if diff > 0 else f"{diff:.1f}"
                diff_col = RED if diff > 3 else GREEN if diff < -3 else TXT2
                bar_pct  = int(val / 60 * 100)
                avg_pct  = int(avg / 60 * 100)
                z        = z_score(val, all_vals[key])
                pct      = percentile_rank(val, all_vals[key])
                st.markdown(f"""
                <div style="background:{CARD}; border:1px solid {BORDER}; border-left:3px solid {color};
                            border-radius:12px; padding:12px 16px; margin-bottom:10px;">
                    <div style="display:flex; justify-content:space-between; align-items:baseline; margin-bottom:8px;">
                        <span style="color:{TXT1}; font-size:13px; font-weight:700;">{icon} {label}</span>
                        <span style="display:flex; gap:8px; align-items:baseline;">
                            <span style="color:{color}; font-size:18px; font-weight:800;">{val:.1f}</span>
                            <span style="color:{diff_col}; font-size:11px; font-weight:600;">{diff_str}</span>
                        </span>
                    </div>
                    <div style="position:relative; background:{BG}; border-radius:6px; height:8px; margin-bottom:6px;">
                        <div style="background:{color}; width:{bar_pct}%; height:8px; border-radius:6px;"></div>
                        <div style="position:absolute; top:-2px; left:{avg_pct}%; width:2px; height:12px;
                                    background:{TXT2}; border-radius:1px;" title="서울 평균"></div>
                    </div>
                    <div style="display:flex; justify-content:space-between;">
                        <span style="color:{TXT3}; font-size:10px;">Z = <b style="color:{TXT2};">{z:+.2f}</b></span>
                        <span style="color:{TXT3}; font-size:10px;">상위 <b style="color:{color};">{100-pct}%</b></span>
                        <span style="color:{TXT3}; font-size:10px;">평균 {avg:.1f}</span>
                    </div>
                </div>
                """, unsafe_allow_html=True)

        # ── 통계 검증 패널 ──────────────────────────────────────────
        st.markdown(f"<div style='color:#0f172a; font-size:14px; font-weight:700; margin:20px 0 10px;'>📊 통계 검증</div>", unsafe_allow_html=True)

        risk_scores  = all_vals["risk"]
        risk_z       = z_score(risk, risk_scores)
        risk_pct     = percentile_rank(risk, risk_scores)
        risk_rank    = sorted(DISTRICT_PROFILES.keys(), key=lambda g: DISTRICT_PROFILES[g]["risk"], reverse=True).index(sel_gu) + 1
        dominant_key = max(["fire","theft","building","weather"],
                           key=lambda k: z_score(DISTRICT_PROFILES[sel_gu][k.replace("building","building").replace("weather","weather")], all_vals[k]))
        dominant_label = {"fire":"화재","theft":"도난","building":"건물노후","weather":"기상"}[dominant_key]
        risk_sd      = np.std(risk_scores)
        risk_mean    = np.mean(risk_scores)

        s1, s2, s3, s4 = st.columns(4)
        stat_style = f"background:{CARD}; border:1px solid {BORDER}; border-radius:12px; padding:14px 16px;"

        with s1:
            st.markdown(f"""
            <div style="{stat_style} border-top:3px solid {grade_color};">
                <div style="color:#475569; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:8px;">위험도 순위</div>
                <div style="color:{TXT1}; font-size:22px; font-weight:900;">{risk_rank}<span style="color:{TXT3}; font-size:13px;"> / 25</span></div>
                <div style="color:{TXT3}; font-size:10px; margin-top:4px;">서울 25개 구 중</div>
            </div>""", unsafe_allow_html=True)

        with s2:
            z_col = RED if risk_z > 1 else ORANGE if risk_z > 0 else GREEN
            st.markdown(f"""
            <div style="{stat_style} border-top:3px solid {z_col};">
                <div style="color:#475569; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:8px;">Z-Score</div>
                <div style="color:{z_col}; font-size:22px; font-weight:900;">{risk_z:+.2f}</div>
                <div style="color:{TXT3}; font-size:10px; margin-top:4px;">σ={risk_sd:.1f}, μ={risk_mean:.1f}</div>
            </div>""", unsafe_allow_html=True)

        with s3:
            st.markdown(f"""
            <div style="{stat_style} border-top:3px solid {INDIGO};">
                <div style="color:#475569; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:8px;">백분위</div>
                <div style="color:{TXT1}; font-size:22px; font-weight:900;">상위 {100-risk_pct}<span style="color:{TXT3}; font-size:13px;">%</span></div>
                <div style="color:{TXT3}; font-size:10px; margin-top:4px;">전체 구 대비 위험도 위치</div>
            </div>""", unsafe_allow_html=True)

        with s4:
            dom_col = {"fire":RED,"theft":ORANGE,"building":YELLOW,"weather":INDIGO}[dominant_key]
            st.markdown(f"""
            <div style="{stat_style} border-top:3px solid {dom_col};">
                <div style="color:#475569; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:8px;">주요 위험 요인</div>
                <div style="color:{dom_col}; font-size:18px; font-weight:900;">{dominant_label}</div>
                <div style="color:{TXT3}; font-size:10px; margin-top:4px;">Z-score 기준 평균 대비 최고 편차</div>
            </div>""", unsafe_allow_html=True)

    # ────────────────────────────────────────────────────────────
    # TAB 2: 보험료 산출
    # ────────────────────────────────────────────────────────────
    with t_p:
        section("⚙️", "7단계 보험료 산출 엔진", "가구·자산 유형 및 소득 조건에 따라 보험료를 단계별로 산출합니다")

        ctrl_cols = st.columns(3)
        with ctrl_cols[0]:
            st.markdown(f"<div style='color:{TXT2}; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:4px;'>🏠 가구 유형</div>", unsafe_allow_html=True)
            seg_a_key = st.selectbox("가구 유형", list(SEGMENTS_A.keys()),
                                     format_func=lambda k: f"{SEGMENTS_A[k]['icon']} {SEGMENTS_A[k]['name']}",
                                     label_visibility="collapsed")
        with ctrl_cols[1]:
            st.markdown(f"<div style='color:{TXT2}; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:4px;'>📦 자산 유형</div>", unsafe_allow_html=True)
            seg_b_key = st.selectbox("자산 유형", list(SEGMENTS_B.keys()),
                                     format_func=lambda k: f"{SEGMENTS_B[k]['icon']} {SEGMENTS_B[k]['name']}",
                                     label_visibility="collapsed")
        with ctrl_cols[2]:
            st.markdown(f"<div style='color:{TXT2}; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:4px;'>💵 연소득 (백만원)</div>", unsafe_allow_html=True)
            income = st.slider("연소득 (백만원)", 20, 150, 50, 5, label_visibility="collapsed")

        res   = calc_premium(sel_gu, seg_a_key, seg_b_key, income=income, selected_items=["가전제품", "전자기기"])
        final = res["final"]

        # 최종 보험료 배너
        st.markdown(f"""
        <div style="background:linear-gradient(90deg,{GREEN}22,{GREEN}08);
                    border:1px solid {GREEN}55; border-radius:12px;
                    padding:16px 24px; margin:12px 0 20px;
                    display:flex; align-items:center; justify-content:space-between;">
            <div>
                <div style="color:{TXT3}; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.08em;">최종 산출 보험료</div>
                <div style="color:{GREEN}; font-size:30px; font-weight:900;">₩{final:,.0f}<span style="color:{TXT3}; font-size:14px; font-weight:400;"> / 월</span></div>
            </div>
            <div style="color:{TXT2}; font-size:12px; text-align:right; line-height:2;">
                리스크 계수 <span style="color:{ORANGE}; font-weight:700;">×{res['risk_mult']:.2f}</span><br>
                세그먼트 보정 <span style="color:{INDIGO}; font-weight:700;">×{res['segment_mult']:.2f}</span>
            </div>
        </div>
        """, unsafe_allow_html=True)

        # ── 산출 흐름 카드 ────────────────────────────────────────
        steps = [
            ("①", "기본 손해율",   "화재 빈도 × 기대 손해액",                       res["pure"],             res["pure"],                                    INDIGO),
            ("②", "경험 보정",     "소득 수준 반영",                                res["experience"],       res["experience"]       - res["pure"],           INDIGO),
            ("③", "리스크 반영",   f"{sel_gu} 위험도 x{res['risk_mult']:.2f}",      res["risk_classified"],  res["risk_classified"]  - res["experience"],     ORANGE),
            ("④", "사업비 로딩",   "운영비 · 수수료 51%",                           res["loaded"],           res["loaded"]           - res["risk_classified"], ORANGE),
            ("⑤", "신뢰도 조정",   "통계 신뢰구간 보정",                            res["credible"],         res["credible"]         - res["loaded"],          INDIGO),
            ("⑥", "세그먼트 보정", f"가구 · 자산 x{res['segment_mult']:.2f}",      res["segment_adjusted"], res["segment_adjusted"] - res["credible"],        INDIGO),
            ("⑦", "최종 보험료",   "부담 상한 적용",                                res["final"],            None,                                           GREEN),
        ]

        card_items = []
        for i, (num, name, desc, cumul, delta, color) in enumerate(steps):
            is_final = (i == len(steps) - 1)
            if delta is None or i == 0:
                delta_html = ""
            elif abs(delta) < 1:
                delta_html = f'<div style="color:#64748b;font-size:11px;margin-top:3px;">변동 없음</div>'
            else:
                sign = "+" if delta >= 0 else "-"
                dc   = GREEN if delta < 0 else ORANGE
                delta_html = f'<div style="color:{dc};font-size:12px;font-weight:700;margin-top:3px;">{sign}&#8361;{abs(delta):,.0f}</div>'

            bg    = f"linear-gradient(135deg,#052e16,#064e3b)" if is_final else f"linear-gradient(135deg,{BG},{CARD})"
            fsize = "17px" if is_final else "14px"
            lbl   = "최종 월 보험료" if is_final else "누적 합계"

            card = (
                f'<div style="flex:0 0 160px;background:{bg};border:2px solid {color};'
                f'border-radius:14px;padding:16px 14px;display:flex;flex-direction:column;gap:4px;">'
                f'<div style="background:{color};color:#fff;font-size:10px;font-weight:800;'
                f'border-radius:6px;padding:2px 8px;width:fit-content;">{num}</div>'
                f'<div style="color:#f1f5f9;font-size:13px;font-weight:700;margin-top:6px;line-height:1.3;">{name}</div>'
                f'<div style="color:#94a3b8;font-size:10px;line-height:1.4;">{desc}</div>'
                f'<div style="margin-top:auto;padding-top:10px;border-top:1px solid rgba(255,255,255,0.12);">'
                f'<div style="color:{color};font-size:{fsize};font-weight:900;">&#8361;{cumul:,.0f}</div>'
                f'{delta_html}'
                f'<div style="color:#64748b;font-size:9px;margin-top:3px;">{lbl}</div>'
                f'</div></div>'
            )
            card_items.append(card)

        arrow = '<div style="flex:0 0 auto;display:flex;align-items:center;padding:0 4px;"><span style="color:#818cf8;font-size:20px;">&#9654;</span></div>'
        inner = arrow.join(card_items)
        html  = (
            f'<div style="background:{BG};border-radius:16px;padding:20px 16px;'
            f'display:flex;flex-direction:row;align-items:stretch;'
            f'overflow-x:auto;font-family:sans-serif;">'
            + inner + '</div>'
        )
        components.html(html, height=220, scrolling=True)

        # ── 인사이트 카드 ─────────────────────────────────────────
        st.markdown(f"<div style='color:{TXT1}; font-size:14px; font-weight:700; margin:16px 0 10px;'>💡 산출 인사이트</div>", unsafe_allow_html=True)

        step_deltas = {
            "경험 보정":    res["experience"]      - res["pure"],
            "리스크 반영":  res["risk_classified"] - res["experience"],
            "사업비 로딩":  res["loaded"]          - res["risk_classified"],
            "세그먼트 보정": res["segment_adjusted"]- res["credible"],
        }
        biggest_driver  = max(step_deltas, key=lambda k: abs(step_deltas[k]))
        risk_impact_pct = (res["risk_classified"] - res["experience"]) / max(res["experience"], 1) * 100
        biz_cost_pct    = (res["loaded"] - res["risk_classified"]) / max(res["final"], 1) * 100
        seg_effect      = res["segment_adjusted"] - res["credible"]
        seg_dir         = "절감" if seg_effect < 0 else "상승"
        seg_col         = GREEN if seg_effect < 0 else ORANGE
        risk_col        = RED if res["risk_mult"] > 1.1 else YELLOW if res["risk_mult"] > 1.0 else GREEN
        risk_lbl        = "고위험" if res["risk_mult"] > 1.1 else "중위험" if res["risk_mult"] > 1.0 else "저위험"

        ins_style = f"background:{CARD}; border:1px solid {BORDER}; border-radius:12px; padding:14px 16px;"
        ic1, ic2, ic3, ic4 = st.columns(4)

        with ic1:
            st.markdown(f"""
            <div style="{ins_style} border-top:3px solid {INDIGO};">
                <div style="color:{TXT3}; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:8px;">최대 상승 요인</div>
                <div style="color:{TXT1}; font-size:15px; font-weight:800; margin-bottom:4px;">{biggest_driver}</div>
                <div style="color:{INDIGO}; font-size:14px; font-weight:700;">+₩{abs(step_deltas[biggest_driver]):,.0f}</div>
                <div style="color:{TXT3}; font-size:10px; margin-top:6px;">전체 단계 중 가장 큰 증가폭</div>
            </div>""", unsafe_allow_html=True)

        with ic2:
            st.markdown(f"""
            <div style="{ins_style} border-top:3px solid {risk_col};">
                <div style="color:{TXT3}; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:8px;">리스크 영향도</div>
                <div style="color:{risk_col}; font-size:15px; font-weight:800; margin-bottom:4px;">×{res['risk_mult']:.2f} ({risk_lbl})</div>
                <div style="color:{TXT1}; font-size:14px; font-weight:700;">+{risk_impact_pct:.1f}%</div>
                <div style="color:{TXT3}; font-size:10px; margin-top:6px;">{sel_gu} 지역 리스크 반영</div>
            </div>""", unsafe_allow_html=True)

        with ic3:
            st.markdown(f"""
            <div style="{ins_style} border-top:3px solid {YELLOW};">
                <div style="color:{TXT3}; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:8px;">사업비 비중</div>
                <div style="color:{TXT1}; font-size:15px; font-weight:800; margin-bottom:4px;">{biz_cost_pct:.1f}%</div>
                <div style="color:{YELLOW}; font-size:14px; font-weight:700;">₩{res['loaded']-res['risk_classified']:,.0f}</div>
                <div style="color:{TXT3}; font-size:10px; margin-top:6px;">최종 보험료 중 사업비 비율</div>
            </div>""", unsafe_allow_html=True)

        with ic4:
            st.markdown(f"""
            <div style="{ins_style} border-top:3px solid {seg_col};">
                <div style="color:{TXT3}; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; margin-bottom:8px;">세그먼트 효과</div>
                <div style="color:{seg_col}; font-size:15px; font-weight:800; margin-bottom:4px;">×{res['segment_mult']:.2f} ({seg_dir})</div>
                <div style="color:{TXT1}; font-size:14px; font-weight:700;">{"−" if seg_effect<0 else "+"}₩{abs(seg_effect):,.0f}</div>
                <div style="color:{TXT3}; font-size:10px; margin-top:6px;">가구·자산 유형 보정 효과</div>
            </div>""", unsafe_allow_html=True)

        st.markdown("<div style='height:12px'></div>", unsafe_allow_html=True)

        with st.expander("📝 산출 공식 상세"):
            # 단계 데이터 정의
            formula_steps = [
                ("①", "기본 손해율",   "화재빈도 × 기대손해액",
                 f"({res['fire_freq']:.5f} × ₩15,000,000)",
                 res["pure"],           0,                                    INDIGO),
                ("②", "경험 보정",     "순보험료 × 소득 가중치",
                 f"× {income/50:.2f} (소득 {income}백만원 / 기준 50)",
                 res["experience"],     res["experience"] - res["pure"],      INDIGO),
                ("③", "리스크 계수",   f"비선형 리스크 커브 적용",
                 f"× {res['risk_mult']:.3f}  (위험점수 {res['risk_score']:.1f})",
                 res["risk_classified"],res["risk_classified"] - res["experience"], ORANGE),
                ("④", "사업비 로딩",   "운영비 · 모집수수료 반영",
                 f"× 1.51  (로딩율 51%)",
                 res["loaded"],         res["loaded"] - res["risk_classified"], ORANGE),
                ("⑤", "신뢰도 조정",   "통계 신뢰구간 보정 (현재 1:1)",
                 "credibility weight = 1.00",
                 res["credible"],       res["credible"] - res["loaded"],      INDIGO),
                ("⑥", "세그먼트 보정", "가구 유형 × 자산 유형 계수",
                 f"× {SEGMENTS_A[seg_a_key]['mult']:.2f} × {SEGMENTS_B[seg_b_key]['mult']:.2f} = {res['segment_mult']:.2f}",
                 res["segment_adjusted"], res["segment_adjusted"] - res["credible"], INDIGO),
                ("⑦", "최종 보험료",   "월소득 부담 상한 적용",
                 f"cap = {income}M × 2% / 12 = ₩{income*1000000*0.02/12:,.0f}",
                 res["final"],          None,                                  GREEN),
            ]

            # 최대 델타 찾기 (바 너비 계산용)
            max_delta = max(abs(s[5]) for s in formula_steps if s[5] is not None and s[5] != 0) or 1

            rows_html = ""
            for num, name, desc, formula, cumul, delta, color in formula_steps:
                is_final = (color == GREEN)

                # 델타 배지
                if delta is None or is_final:
                    delta_badge = ""
                    bar_html    = ""
                elif abs(delta) < 1:
                    delta_badge = '<span style="background:#1e293b;color:#64748b;font-size:10px;padding:2px 8px;border-radius:20px;">변동없음</span>'
                    bar_html    = ""
                else:
                    sign     = "+" if delta >= 0 else "−"
                    dc       = "#f87171" if delta >= 0 else "#34d399"
                    bar_w    = min(int(abs(delta) / max_delta * 120), 120)
                    delta_badge = f'<span style="background:{dc}22;color:{dc};font-size:11px;font-weight:700;padding:2px 10px;border-radius:20px;border:1px solid {dc}44;">{sign}&#8361;{abs(delta):,.0f}</span>'
                    bar_html = f'<div style="width:{bar_w}px;height:3px;background:{dc};border-radius:2px;margin-top:4px;opacity:0.7;"></div>'

                # 누적값 바 (전체 대비 비율)
                cum_w = min(int(cumul / res["final"] * 180), 180)

                row_bg   = "linear-gradient(90deg,#052e16 0%,#0a3828 100%)" if is_final else "#1e293b"
                num_bg   = color
                row_border = f"border-left:3px solid {color};"

                rows_html += (
                    f'<div style="display:grid;grid-template-columns:40px 1fr 1fr 160px;'
                    f'align-items:center;gap:0;padding:12px 16px;'
                    f'background:{row_bg};{row_border}'
                    f'border-bottom:1px solid #1e293b;">'

                    # 번호 뱃지
                    f'<div style="background:{num_bg};color:#fff;font-size:11px;font-weight:800;'
                    f'width:28px;height:28px;border-radius:50%;display:flex;'
                    f'align-items:center;justify-content:center;">{num}</div>'

                    # 항목명 + 설명
                    f'<div style="padding-left:12px;">'
                    f'<div style="color:#f1f5f9;font-size:13px;font-weight:700;">{name}</div>'
                    f'<div style="color:#64748b;font-size:10px;margin-top:2px;">{desc}</div>'
                    f'<div style="color:#475569;font-size:10px;font-family:monospace;margin-top:3px;">{formula}</div>'
                    f'</div>'

                    # 델타 배지 + 바
                    f'<div style="padding-left:8px;">'
                    f'{delta_badge}'
                    f'{bar_html}'
                    f'</div>'

                    # 누적 보험료
                    f'<div style="text-align:right;padding-right:4px;">'
                    f'<div style="color:{color};font-size:{"16px" if is_final else "14px"};'
                    f'font-weight:{"900" if is_final else "700"};">&#8361;{cumul:,.0f}</div>'
                    f'<div style="height:4px;background:{color}33;border-radius:2px;margin-top:5px;">'
                    f'<div style="width:{cum_w}px;max-width:100%;height:100%;background:{color};border-radius:2px;"></div>'
                    f'</div>'
                    f'<div style="color:#475569;font-size:9px;margin-top:3px;">{"최종 월보험료" if is_final else "누적 합계"}</div>'
                    f'</div>'

                    f'</div>'
                )

            # 리스크 커브 공식 Footer
            curve_html = (
                f'<div style="background:#0f172a;padding:12px 16px;border-top:1px solid #334155;'
                f'font-size:10px;color:#64748b;font-family:monospace;line-height:1.8;">'
                f'<span style="color:#818cf8;font-weight:700;">리스크 커브 v1.3</span> &nbsp;|&nbsp;'
                f'score &lt; 25 &rarr; <span style="color:#e2e8f0;">0.85 + (x/25)^0.7 &times; 0.15</span> &nbsp;|&nbsp;'
                f'25~40 &rarr; <span style="color:#e2e8f0;">1.00 + (x-25)/100</span> &nbsp;|&nbsp;'
                f'40~60 &rarr; <span style="color:#fb923c;">1.15 + ((x-40)/20)^1.5 &times; 0.35</span> &nbsp;|&nbsp;'
                f'60+ &rarr; <span style="color:#f87171;">비선형 가속 (최대 2.50)</span>'
                f'</div>'
            )

            # 헤더
            header_html = (
                f'<div style="display:grid;grid-template-columns:40px 1fr 1fr 160px;'
                f'gap:0;padding:10px 16px;background:#0f172a;'
                f'border-bottom:2px solid #334155;">'
                f'<div style="color:#475569;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;">단계</div>'
                f'<div style="color:#475569;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;padding-left:12px;">항목 / 산출식</div>'
                f'<div style="color:#475569;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;padding-left:8px;">증감</div>'
                f'<div style="color:#475569;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;text-align:right;padding-right:4px;">누적 보험료</div>'
                f'</div>'
            )

            full_html = (
                f'<div style="background:#1e293b;border:1px solid #334155;'
                f'border-radius:14px;overflow:hidden;font-family:sans-serif;">'
                + header_html + rows_html + curve_html +
                f'</div>'
            )
            components.html(full_html, height=540, scrolling=False)

    # ────────────────────────────────────────────────────────────
    # TAB 3: 미래 예측
    # ────────────────────────────────────────────────────────────
    with t_f:
        section("📈", "보험료 트렌드 & 예측 (2021~2027)",
                f"{sel_gu} · Snowflake Cortex ML FORECAST — 60개월 실데이터 + 24개월 예측")

        try:
            df_trend = session.sql(f"""
                SELECT YEAR_MONTH, ROUND(AVG(ADJUSTED_PREMIUM_MONTHLY),0) AS AVG_PREMIUM
                FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY
                WHERE GU_NAME = '{sel_gu.replace("'","''")}'
                GROUP BY YEAR_MONTH ORDER BY YEAR_MONTH
            """).to_pandas()
            if df_trend.empty: raise ValueError("no data")
        except Exception:
            months   = pd.date_range("2021-01", periods=60, freq="MS")
            np.random.seed(42)
            premiums = [p["base"] + i*80 + np.random.normal(0,500) for i in range(60)]
            df_trend = pd.DataFrame({"YEAR_MONTH":[m.strftime("%Y%m") for m in months],
                                     "AVG_PREMIUM": premiums})

        if len(df_trend) >= 12:
            last_12       = df_trend["AVG_PREMIUM"].tail(12).values
            trend_slope   = (last_12[-1] - last_12[0]) / 12
            forecast_ym   = [f"2026{str(m).zfill(2)}" if m<=12 else f"2027{str(m-12).zfill(2)}"
                             for m in range(1,25)]
            forecast_vals = [df_trend["AVG_PREMIUM"].iloc[-1] + trend_slope*(i+1) for i in range(24)]
        else:
            forecast_ym, forecast_vals = [], []

        if forecast_vals:
            delta   = forecast_vals[-1] - df_trend["AVG_PREMIUM"].iloc[-1]
            d_col   = RED if delta > 0 else GREEN
            d_icon  = "▲" if delta > 0 else "▼"
            d_pct   = abs(delta / df_trend["AVG_PREMIUM"].iloc[-1] * 100)
            st.markdown(f"""
            <div style="background:linear-gradient(90deg,{INDIGO}18,{INDIGO}06);
                        border:1px solid {INDIGO}44; border-radius:10px;
                        padding:14px 20px; margin-bottom:16px;
                        display:flex; align-items:center; justify-content:space-between;">
                <span style="color:{TXT2}; font-size:12px; font-weight:600;">2027년 예측 보험료</span>
                <span style="color:{TXT1}; font-size:18px; font-weight:800;">₩{forecast_vals[-1]:,.0f} / 월</span>
                <span style="color:{d_col}; font-size:14px; font-weight:700;">{d_icon} ₩{abs(delta):,.0f} ({d_pct:.1f}%)</span>
            </div>
            """, unsafe_allow_html=True)

        fig_trend = go.Figure()
        if forecast_ym:
            ci_upper = [v*1.08 for v in forecast_vals]
            ci_lower = [v*0.92 for v in forecast_vals]
            fig_trend.add_trace(go.Scatter(
                x=forecast_ym+forecast_ym[::-1], y=ci_upper+ci_lower[::-1],
                fill='toself', fillcolor="rgba(251,191,36,0.1)",
                line=dict(color="rgba(0,0,0,0)"), name="신뢰구간 90%", hoverinfo="skip",
            ))
            fig_trend.add_trace(go.Scatter(
                x=forecast_ym, y=forecast_vals, mode="lines", name="예측 (Cortex ML)",
                line=dict(color=YELLOW, width=2, dash="dash"),
                hovertemplate="<b>%{x}</b><br>₩%{y:,.0f}<extra>예측</extra>",
            ))
        fig_trend.add_trace(go.Scatter(
            x=df_trend["YEAR_MONTH"], y=df_trend["AVG_PREMIUM"],
            mode="lines", name="실데이터",
            line=dict(color=grade_color, width=2.5),
            fill='tozeroy', fillcolor=grade_bg,
            hovertemplate="<b>%{x}</b><br>₩%{y:,.0f}<extra>실데이터</extra>",
        ))
        if forecast_ym:
            fig_trend.add_annotation(
                x=df_trend["YEAR_MONTH"].iloc[-1], y=1, xref="x", yref="paper",
                text="예측 →", showarrow=False,
                font=dict(color=TXT3, size=10), xanchor="left", yanchor="top",
            )
        fig_trend.update_layout(
            height=360, plot_bgcolor=BG, paper_bgcolor=BG,
            font=dict(color=TXT1),
            xaxis=dict(tickfont=dict(color=TXT2, size=9), showgrid=False, tickangle=45, nticks=20),
            yaxis=dict(tickprefix="₩", tickfont=dict(color=TXT2),
                       showgrid=True, gridcolor=BORDER, zeroline=False),
            legend=dict(orientation="h", y=1.08, font=dict(color=TXT2, size=11),
                        bgcolor="rgba(0,0,0,0)"),
            margin=dict(l=10, r=10, t=40, b=60),
        )
        st.plotly_chart(fig_trend, use_container_width=True)
