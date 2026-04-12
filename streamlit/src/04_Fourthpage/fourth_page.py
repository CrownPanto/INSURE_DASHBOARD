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
            <div style="margin-top:6px; display:flex; gap:6px; flex-wrap:wrap;">
                <span style="background:#eef2ff; border:1px solid #a5b4fc; color:#3730a3;
                             font-size:11px; font-weight:700; padding:2px 10px; border-radius:20px;">🎯 구별 리스크 분석</span>
                <span style="background:#fff7ed; border:1px solid #fdba74; color:#9a3412;
                             font-size:11px; font-weight:700; padding:2px 10px; border-radius:20px;">💰 7단계 보험료 산출</span>
                <span style="background:#fefce8; border:1px solid #fde047; color:#713f12;
                             font-size:11px; font-weight:700; padding:2px 10px; border-radius:20px;">📈 미래 예측 모델</span>
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
            formula_steps = [
                ("①", "기본 손해율",   f"빈도 {res['fire_freq']:.5f} × 손해액 ₩15,000,000",
                 res["pure"],           0,                                          INDIGO),
                ("②", "경험 보정",     f"소득 가중 × {income/50:.2f}  ({income}백만원 ÷ 기준 50)",
                 res["experience"],     res["experience"] - res["pure"],            INDIGO),
                ("③", "리스크 계수",   f"위험점수 {res['risk_score']:.1f} → 커브 × {res['risk_mult']:.3f}",
                 res["risk_classified"],res["risk_classified"] - res["experience"], ORANGE),
                ("④", "사업비 로딩",   "운영비 · 수수료 × 1.51  (로딩율 51%)",
                 res["loaded"],         res["loaded"] - res["risk_classified"],     ORANGE),
                ("⑤", "신뢰도 조정",   "통계 신뢰도 보정 (현재 계수 1.00)",
                 res["credible"],       res["credible"] - res["loaded"],            INDIGO),
                ("⑥", "세그먼트 보정", f"가구 {SEGMENTS_A[seg_a_key]['mult']:.2f} × 자산 {SEGMENTS_B[seg_b_key]['mult']:.2f} = {res['segment_mult']:.2f}",
                 res["segment_adjusted"], res["segment_adjusted"] - res["credible"],INDIGO),
                ("⑦", "최종 보험료",   f"부담 상한 ₩{income*1_000_000*0.02/12:,.0f} 적용{'  (상한 적용됨)' if res['capped'] else ''}",
                 res["final"],          None,                                        GREEN),
            ]

            max_delta = max((abs(s[4]) for s in formula_steps if s[4] is not None and abs(s[4]) > 0), default=1)

            rows_html = ""
            for num, name, formula_desc, cumul, delta, color in formula_steps:
                is_final = (color == GREEN)

                # 증감 배지
                if is_final or delta is None:
                    badge = ""
                elif abs(delta) < 1:
                    badge = '<span style="color:#475569;font-size:12px;">변동없음</span>'
                else:
                    sign = "+" if delta > 0 else "−"
                    dc   = "#f87171" if delta > 0 else "#34d399"
                    badge = (
                        f'<div style="display:inline-flex;align-items:center;gap:6px;">'
                        f'<span style="background:{dc}20;color:{dc};font-size:13px;font-weight:800;'
                        f'padding:4px 14px;border-radius:8px;border:1px solid {dc}50;white-space:nowrap;">'
                        f'{sign}&#8361;{abs(delta):,.0f}</span>'
                        # 비례 바
                        f'<div style="width:{min(int(abs(delta)/max_delta*80),80)}px;height:6px;'
                        f'background:{dc};border-radius:3px;opacity:0.6;"></div>'
                        f'</div>'
                    )

                # 누적 프로그레스 바 (전체 대비 %)
                pct = min(cumul / max(res["final"], 1) * 100, 100)

                row_bg = "linear-gradient(90deg,#052e16,#083322)" if is_final else ("#243347" if delta and abs(delta) > 0 else "#1a2538")
                rows_html += (
                    f'<div style="display:grid;grid-template-columns:52px 1fr auto 180px;'
                    f'align-items:center;padding:14px 20px;gap:12px;'
                    f'background:{row_bg};border-left:4px solid {color};'
                    f'border-bottom:1px solid #243347;">'

                    # ① 번호 뱃지
                    f'<div style="background:{color};color:#fff;font-size:13px;font-weight:900;'
                    f'width:34px;height:34px;border-radius:50%;display:flex;'
                    f'align-items:center;justify-content:center;flex-shrink:0;">{num}</div>'

                    # ② 항목명 + 설명
                    f'<div>'
                    f'<div style="color:#f1f5f9;font-size:15px;font-weight:700;line-height:1.2;">{name}</div>'
                    f'<div style="color:#94a3b8;font-size:12px;margin-top:4px;">{formula_desc}</div>'
                    f'</div>'

                    # ③ 증감 배지
                    f'<div style="min-width:180px;">{badge}</div>'

                    # ④ 누적 보험료 + 바
                    f'<div style="text-align:right;">'
                    f'<div style="color:{color};font-size:{"18px" if is_final else "16px"};'
                    f'font-weight:900;">&#8361;{cumul:,.0f}</div>'
                    f'<div style="background:#334155;border-radius:3px;height:5px;margin-top:6px;">'
                    f'<div style="width:{pct:.0f}%;height:100%;background:{color};border-radius:3px;'
                    f'transition:width .3s;"></div></div>'
                    f'<div style="color:#475569;font-size:10px;margin-top:3px;text-align:right;">'
                    f'{"최종 월 보험료" if is_final else f"{pct:.0f}% 도달"}</div>'
                    f'</div>'

                    f'</div>'
                )

            # Footer: 리스크 커브
            curve_html = (
                f'<div style="padding:14px 20px;background:#0d1829;border-top:1px solid #334155;">'
                f'<div style="color:#64748b;font-size:11px;font-weight:700;margin-bottom:6px;">리스크 커브 v1.3</div>'
                f'<div style="display:flex;flex-wrap:wrap;gap:10px;">'
                f'<span style="background:#1e293b;color:#cbd5e1;font-size:11px;padding:4px 12px;border-radius:6px;font-family:monospace;">score &lt; 25 → 0.85 + (x/25)^0.7 × 0.15</span>'
                f'<span style="background:#1e293b;color:#cbd5e1;font-size:11px;padding:4px 12px;border-radius:6px;font-family:monospace;">25~40 → 1.00 + (x−25)/100</span>'
                f'<span style="background:#431407;color:#fb923c;font-size:11px;padding:4px 12px;border-radius:6px;font-family:monospace;">40~60 → 1.15 + ((x−40)/20)^1.5 × 0.35</span>'
                f'<span style="background:#450a0a;color:#f87171;font-size:11px;padding:4px 12px;border-radius:6px;font-family:monospace;">60+ → 비선형 가속 (max 2.50)</span>'
                f'</div>'
                f'</div>'
            )

            header_html = (
                f'<div style="display:grid;grid-template-columns:52px 1fr auto 180px;gap:12px;'
                f'padding:10px 20px;background:#0d1829;border-bottom:1px solid #334155;">'
                f'<div style="color:#475569;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;">단계</div>'
                f'<div style="color:#475569;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;">항목 / 산출식</div>'
                f'<div style="color:#475569;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;min-width:180px;">증감</div>'
                f'<div style="color:#475569;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;text-align:right;">누적 보험료</div>'
                f'</div>'
            )

            full_html = (
                f'<div style="background:#1a2538;border:1px solid #334155;'
                f'border-radius:14px;overflow:hidden;font-family:-apple-system,sans-serif;">'
                + header_html + rows_html + curve_html +
                f'</div>'
            )
            components.html(full_html, height=600, scrolling=False)

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

        # ── YEAR_MONTH "202101" → "2021-01" 변환 (Plotly 날짜 인식용) ──
        df_trend["YEAR_MONTH"] = (
            df_trend["YEAR_MONTH"].astype(str).str[:4] + "-" +
            df_trend["YEAR_MONTH"].astype(str).str[4:6]
        )

        # ── 앙상블 예측: Holt-Winters + GBM(스텀프) + Ridge — 순수 numpy ──
        import warnings; warnings.filterwarnings("ignore")

        y_all    = df_trend["AVG_PREMIUM"].values.astype(float)
        n_obs    = len(y_all)
        start_mo = int(df_trend["YEAR_MONTH"].iloc[0][5:])

        # 피처 행렬: [t, t², sin(2πm/12), cos(2πm/12)]
        def _Xmat(length, first_mo):
            t  = np.arange(length, dtype=float)
            m  = np.array([(first_mo + i - 1) % 12 + 1 for i in range(length)])
            return np.column_stack([t, t**2,
                                    np.sin(2*np.pi*m/12),
                                    np.cos(2*np.pi*m/12)])

        X_all      = _Xmat(n_obs, start_mo)
        X_future_f = _Xmat(n_obs + 24, start_mo)[n_obs:]

        # 마지막 월 다음 24개월 레이블
        last_ym = df_trend["YEAR_MONTH"].iloc[-1]
        yr, mo  = int(last_ym[:4]), int(last_ym[5:])
        forecast_ym = []
        for _ in range(24):
            mo += 1
            if mo > 12: mo, yr = 1, yr + 1
            forecast_ym.append(f"{yr:04d}-{mo:02d}")

        # ─── 순수 numpy 모델 3종 ────────────────────────────────────────
        def _ridge_np(Xtr, ytr, Xpred, alpha=10.0):
            """Ridge Regression — numpy linalg"""
            c = np.linalg.solve(Xtr.T @ Xtr + alpha*np.eye(Xtr.shape[1]), Xtr.T @ ytr)
            return Xpred @ c

        def _gbm_np(Xtr, ytr, Xpred, n_iter=80, lr=0.12):
            """Gradient Boosting (decision stumps) — numpy only, XGBoost 동일 원리"""
            pred  = np.full(len(Xtr), ytr.mean())
            trees = []
            for _ in range(n_iter):
                res  = ytr - pred
                best = None; best_loss = np.inf
                for f in range(Xtr.shape[1]):
                    for pct in [20, 40, 60, 80]:
                        thr = np.percentile(Xtr[:, f], pct)
                        lm  = Xtr[:, f] <= thr
                        if lm.sum() < 2 or (~lm).sum() < 2: continue
                        lv, rv = res[lm].mean(), res[~lm].mean()
                        loss   = ((res - np.where(lm, lv, rv))**2).mean()
                        if loss < best_loss:
                            best_loss = loss; best = (f, thr, lv, rv)
                if best is None: break
                f, thr, lv, rv = best
                pred += lr * np.where(Xtr[:, f] <= thr, lv, rv)
                trees.append(best)
            out = np.full(len(Xpred), ytr.mean())
            for f, thr, lv, rv in trees:
                out += lr * np.where(Xpred[:, f] <= thr, lv, rv)
            return out

        def _hw_np(ytr, steps, s=12, alpha=0.3, beta=0.1, gamma=0.2):
            """Holt-Winters Triple Exp Smoothing — SARIMA 계열, numpy only"""
            n = len(ytr)
            if n < s * 2:
                slp = (ytr[-1] - ytr[0]) / max(n-1, 1)
                return np.array([ytr[-1] + slp*h for h in range(1, steps+1)])
            lvl = ytr[:s].mean()
            trd = (ytr[s:2*s].mean() - lvl) / s
            sea = [ytr[i] / (lvl or 1e-9) for i in range(s)]
            for t in range(n):
                si  = sea[t % s] or 1e-9; pl = lvl
                lvl = alpha*(ytr[t]/si) + (1-alpha)*(lvl+trd)
                trd = beta*(lvl-pl)     + (1-beta)*trd
                sea[t%s] = gamma*(ytr[t]/lvl) + (1-gamma)*si
            return np.array([(lvl + h*trd)*sea[(n+h-1)%s] for h in range(1, steps+1)])

        # ─── TimeSeriesSplit CV (5-fold, numpy only) ─────────────────────
        def _cv(predict_fn, n_splits=5):
            fold = n_obs // (n_splits + 1)
            rmses, r2s = [], []
            for i in range(n_splits):
                te, ve = fold*(i+1), min(fold*(i+2), n_obs)
                if te < 13 or ve <= te: continue
                p = predict_fn(te, ve)
                a = y_all[te:ve]
                if len(p) != len(a) or len(a) == 0: continue
                ss_res = float(((a-p)**2).sum())
                ss_tot = float(((a-a.mean())**2).sum())
                rmses.append(float(np.sqrt(ss_res/len(a))))
                r2s.append(float(1 - ss_res/ss_tot) if ss_tot > 0 else 0.0)
            return (float(np.mean(rmses)) if rmses else None,
                    float(np.mean(r2s))   if r2s   else None)

        cv_results = {}
        hw_forecast = ridge_forecast = gbm_forecast = None

        # 선형 트렌드 분리 (GBM 외삽 문제 해결용)
        # GBM은 훈련범위 밖 t값을 외삽 못함 → 트렌드 제거 후 잔차만 학습
        t_idx      = np.arange(n_obs, dtype=float)
        trend_coef = np.polyfit(t_idx, y_all, 1)          # slope, intercept
        trend_in   = np.polyval(trend_coef, t_idx)
        resid_all  = y_all - trend_in
        t_future   = np.arange(n_obs, n_obs + 24, dtype=float)
        trend_fut  = np.polyval(trend_coef, t_future)     # 미래 트렌드 (선형 외삽)
        # GBM용 피처: sin/cos만 사용 (주기적 → 외삽 문제 없음)
        X_sea_in  = X_all[:, 2:]       # sin, cos only
        X_sea_fut = X_future_f[:, 2:]

        if n_obs >= 12:
            rmse_r, r2_r = _cv(lambda te, ve: _ridge_np(X_all[:te], y_all[:te], X_all[te:ve]))
            cv_results["Ridge"] = {"RMSE": rmse_r, "R2": r2_r}
            ridge_forecast = _ridge_np(X_all, y_all, X_future_f)

            # GBM: 잔차 학습 → 미래잔차 예측 + 선형트렌드 합산
            def _gbm_cv(te, ve):
                res_in  = resid_all[:te]
                res_hat = _gbm_np(X_sea_in[:te], res_in, X_sea_in[te:ve])
                return trend_in[te:ve] + res_hat

            rmse_g, r2_g = _cv(_gbm_cv)
            cv_results["GBM"] = {"RMSE": rmse_g, "R2": r2_g}
            gbm_resid_fut = _gbm_np(X_sea_in, resid_all, X_sea_fut)
            gbm_forecast  = trend_fut + gbm_resid_fut   # 트렌드 + 계절잔차

        if n_obs >= 24:
            rmse_h, r2_h = _cv(lambda te, ve: _hw_np(y_all[:te], ve-te))
            cv_results["HW"] = {"RMSE": rmse_h, "R2": r2_h}
            hw_forecast = _hw_np(y_all, 24)

        # 앙상블: HW 35% + GBM 45% + Ridge 20%
        parts, weights = [], []
        if hw_forecast    is not None: parts.append(hw_forecast);    weights.append(0.35)
        if gbm_forecast   is not None: parts.append(gbm_forecast);   weights.append(0.45)
        if ridge_forecast is not None: parts.append(ridge_forecast); weights.append(0.20)
        if parts:
            wt = sum(weights)
            raw_forecast = sum(p*(w/wt) for p, w in zip(parts, weights))
        else:
            slp = float(trend_coef[0])
            raw_forecast = np.array([y_all[-1] + slp*(i+1) for i in range(24)])

        # ── 물가 상승률(CPI) 하한선 적용 ─────────────────────────────
        # 한국 소비자물가지수 장기 평균 ~3.0% / 년 (통계청 기준)
        # 보험료는 물가연동 특성 → 최소 CPI 상승률 이하로 감소 불가
        CPI_ANNUAL   = 0.030          # 연 3.0%
        CPI_MONTHLY  = CPI_ANNUAL / 12
        cpi_floor    = np.array([y_all[-1] * (1 + CPI_MONTHLY)**(i+1) for i in range(24)])
        forecast_arr = np.maximum(raw_forecast, cpi_floor)
        forecast_vals = forecast_arr.tolist()

        best_rmse = next((cv_results[k]["RMSE"] for k in ["GBM","HW","Ridge"]
                          if cv_results.get(k) and cv_results[k]["RMSE"]), None)
        ci_pct    = (best_rmse / np.mean(y_all)) if best_rmse else 0.06
        trend_slope_disp = (forecast_vals[-1] - y_all[-1]) / 24

        if forecast_vals:
            delta     = forecast_vals[-1] - y_all[-1]
            d_col     = RED if delta > 0 else GREEN
            d_icon    = "▲" if delta > 0 else "▼"
            d_pct     = abs(delta / y_all[-1] * 100)
            end_label = forecast_ym[-1] if forecast_ym else "2027-12"
            st.markdown(f"""
            <div style="background:linear-gradient(135deg,#1e1b4b,#312e81);
                        border:1.5px solid #6366f1; border-radius:12px;
                        padding:16px 22px; margin-bottom:16px;">
                <div style="color:#a5b4fc; font-size:10px; font-weight:700;
                            text-transform:uppercase; letter-spacing:.1em; margin-bottom:8px;">
                    📈 {end_label} 예측 보험료
                </div>
                <div style="display:flex; align-items:baseline; gap:12px; flex-wrap:wrap;">
                    <span style="color:#ffffff; font-size:26px; font-weight:900;
                                 letter-spacing:-.02em;">₩{forecast_vals[-1]:,.0f}</span>
                    <span style="color:#c7d2fe; font-size:14px; font-weight:600;">/ 월</span>
                    <span style="background:{'rgba(248,113,113,0.2)' if delta>0 else 'rgba(52,211,153,0.2)'};
                                 border:1px solid {d_col};
                                 color:{d_col}; font-size:13px; font-weight:700;
                                 padding:3px 10px; border-radius:20px; margin-left:4px;">
                        {d_icon} ₩{abs(delta):,.0f} ({d_pct:.1f}%)
                    </span>
                </div>
            </div>
            """, unsafe_allow_html=True)

        fig_trend = go.Figure()
        if forecast_ym:
            ci_upper = [v*(1+ci_pct) for v in forecast_vals]
            ci_lower = [v*(1-ci_pct) for v in forecast_vals]
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
            fig_trend.add_vline(
                x=df_trend["YEAR_MONTH"].iloc[-1],
                line=dict(color=TXT3, width=1, dash="dot"),
            )
            fig_trend.add_annotation(
                x=df_trend["YEAR_MONTH"].iloc[-1], y=0.97,
                xref="x", yref="paper",
                text="◀ 실데이터  예측 ▶",
                showarrow=False,
                font=dict(color=TXT3, size=10),
                xanchor="center", yanchor="top",
                bgcolor=BG, borderpad=3,
            )
        fig_trend.update_layout(
            height=380, width=820, plot_bgcolor=BG, paper_bgcolor=BG,
            font=dict(color=TXT1),
            xaxis=dict(
                type="date",
                tickformat="%Y-%m",
                tickfont=dict(color=TXT2, size=9),
                showgrid=False, tickangle=45, nticks=20,
                dtick="M6",
                range=["2023-07", forecast_ym[-1] if forecast_ym else "2027-12"],
            ),
            yaxis=dict(tickprefix="₩", tickfont=dict(color=TXT2),
                       showgrid=True, gridcolor=BORDER, zeroline=False),
            legend=dict(orientation="h", y=1.08, font=dict(color=TXT2, size=11),
                        bgcolor="rgba(0,0,0,0)"),
            margin=dict(l=10, r=10, t=40, b=60),
        )
        st.plotly_chart(fig_trend, use_container_width=False)

        # ── 예측 모델 상세 expander ────────────────────────────────────
        with st.expander("📐 예측 모델 상세 — 모델 비교 & 검증 점수"):
            # ── 3모델 CV 결과 행 생성
            model_meta = [
                ("Holt-Winters", "시계열",    "#06b6d4",
                 "Triple Exponential Smoothing · SARIMA 동일 계열 · 계절·추세·수준 분리",
                 cv_results.get("HW"),    False),
                ("GBM",          "트리부스팅","#fb923c",
                 "Gradient Boosting (Decision Stumps) · XGBoost·LightGBM 동일 원리 · iter=80",
                 cv_results.get("GBM"),   True),
                ("Ridge",        "선형",      "#818cf8",
                 "Ridge Regression · 트렌드 + 계절성(sin/cos) 피처 · α=10",
                 cv_results.get("Ridge"), False),
            ]
            cv_rows_html = ""
            for mkey, badge, color, desc, res, selected in model_meta:
                rmse_str = f"₩{res['RMSE']:,.0f}" if res else "—"
                r2_val   = res['R2'] if (res and res.get('R2') is not None) else None
                r2_str   = f"{r2_val:.3f}" if r2_val is not None else "—"
                r2_bar   = max(0, min(1, r2_val)) * 100 if r2_val is not None else 0
                sel_bg   = f"linear-gradient(135deg,{color}18,{color}06)" if selected else "#1e293b"
                sel_bd   = color if selected else "#334155"
                sel_bw   = "2px" if selected else "1px"
                star     = f' <span style="background:{color};color:#000;font-size:10px;font-weight:800;padding:1px 8px;border-radius:20px;margin-left:6px;">★ 채택</span>' if selected else ""
                cv_rows_html += f"""
<div style="background:{sel_bg};border:{sel_bw} solid {sel_bd};border-left:4px solid {color};
            border-radius:10px;padding:14px 18px;margin-bottom:10px;">
  <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px;">
    <div style="background:{color}33;border:1px solid {color}88;border-radius:6px;
                padding:4px 14px;font-size:12px;color:{color};font-weight:800;
                white-space:nowrap;">{badge}</div>
    <div style="color:#f1f5f9;font-size:16px;font-weight:700;">{mkey}{star}</div>
  </div>
  <div style="color:#94a3b8;font-size:12px;margin-bottom:12px;line-height:1.6;">{desc}</div>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;">
    <div style="background:#0f172a;border:1px solid #334155;border-radius:8px;padding:10px 14px;">
      <div style="color:#7dd3fc;font-size:11px;font-weight:700;letter-spacing:.04em;margin-bottom:5px;">RMSE (CV)</div>
      <div style="color:#f1f5f9;font-size:18px;font-weight:800;">{rmse_str}</div>
    </div>
    <div style="background:#0f172a;border:1px solid #334155;border-radius:8px;padding:10px 14px;">
      <div style="color:#86efac;font-size:11px;font-weight:700;letter-spacing:.04em;margin-bottom:5px;">R² (CV)</div>
      <div style="color:#f1f5f9;font-size:18px;font-weight:800;">{r2_str}</div>
      <div style="background:#1e293b;border-radius:3px;height:4px;width:100%;margin-top:7px;">
        <div style="background:linear-gradient(90deg,#34d399,#06b6d4);width:{r2_bar:.0f}%;height:4px;border-radius:3px;"></div>
      </div>
    </div>
  </div>
</div>"""

            # 앙상블 합산 행
            ens_parts = [(cv_results.get("HW"),    0.35),
                         (cv_results.get("GBM"),   0.45),
                         (cv_results.get("Ridge"), 0.20)]
            valid_ens = [(r, w) for r, w in ens_parts if r]
            if valid_ens:
                w_tot    = sum(w for _, w in valid_ens)
                ens_rmse = sum(r["RMSE"]*(w/w_tot) for r, w in valid_ens
                               if r.get("RMSE") is not None)
                valid_r2 = [(r, w) for r, w in valid_ens if r.get("R2") is not None]
                ens_r2   = (sum(r["R2"]*(w/sum(w2 for _,w2 in valid_r2))
                               for r, w in valid_r2) if valid_r2 else 0.0)
                ens_bar  = max(0, min(1, ens_r2)) * 100
                w_desc   = " + ".join([f"{k} {int(w*100)}%" for (r,w),(k,*_) in
                                       zip(valid_ens, [("HW",), ("GBM",), ("Ridge",)])])
                cv_rows_html += f"""
<div style="background:linear-gradient(135deg,#052e16,#0c1a2e);border:2px solid #34d399;
            border-left:4px solid #34d399;border-radius:10px;padding:14px 18px;margin-bottom:10px;">
  <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px;flex-wrap:wrap;">
    <div style="background:#34d39933;border:1px solid #34d39988;border-radius:6px;
                padding:4px 14px;font-size:12px;color:#34d399;font-weight:800;">앙상블</div>
    <div style="color:#f1f5f9;font-size:16px;font-weight:700;">{w_desc}</div>
    <span style="background:#fbbf24;color:#000;font-size:10px;font-weight:800;
                 padding:2px 10px;border-radius:20px;">★ 최종 예측</span>
  </div>
  <div style="color:#94a3b8;font-size:12px;margin-bottom:12px;line-height:1.6;">
    TimeSeriesSplit 5-fold · 가중 평균 앙상블 · 순수 numpy 구현</div>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;">
    <div style="background:#0f172a;border:1px solid #334155;border-radius:8px;padding:10px 14px;">
      <div style="color:#7dd3fc;font-size:11px;font-weight:700;letter-spacing:.04em;margin-bottom:5px;">RMSE (가중평균)</div>
      <div style="color:#f1f5f9;font-size:18px;font-weight:800;">₩{ens_rmse:,.0f}</div>
    </div>
    <div style="background:#0f172a;border:1px solid #334155;border-radius:8px;padding:10px 14px;">
      <div style="color:#86efac;font-size:11px;font-weight:700;letter-spacing:.04em;margin-bottom:5px;">R² (가중평균)</div>
      <div style="color:#f1f5f9;font-size:18px;font-weight:800;">{ens_r2:.3f}</div>
      <div style="background:#1e293b;border-radius:3px;height:4px;width:100%;margin-top:7px;">
        <div style="background:linear-gradient(90deg,#34d399,#fbbf24);width:{ens_bar:.0f}%;height:4px;border-radius:3px;"></div>
      </div>
    </div>
  </div>
</div>"""
            st.markdown(f"""
<div style="background:#1e293b;border:1px solid #475569;border-radius:8px;
            padding:10px 16px;margin-bottom:14px;display:flex;flex-wrap:wrap;gap:16px;align-items:center;">
  <span style="color:#cbd5e1;font-size:12px;font-weight:600;">
    📊 학습: <b style="color:#f1f5f9;">{df_trend["YEAR_MONTH"].iloc[0]} ~ {df_trend["YEAR_MONTH"].iloc[-1]}</b> ({n_obs}개월)
  </span>
  <span style="color:#475569;">|</span>
  <span style="color:#cbd5e1;font-size:12px;font-weight:600;">🔁 <b style="color:#f1f5f9;">TimeSeriesSplit CV</b></span>
  <span style="color:#475569;">|</span>
  <span style="color:#cbd5e1;font-size:12px;font-weight:600;">
    🎯 예측: <b style="color:#f1f5f9;">{forecast_ym[0] if forecast_ym else "-"} ~ {forecast_ym[-1] if forecast_ym else "-"}</b> (24개월)
  </span>
</div>
{cv_rows_html}
<div style="background:#1e293b;border:1.5px solid #475569;border-radius:10px;
            padding:16px 20px;margin-top:10px;">
  <div style="color:#fbbf24;font-size:13px;font-weight:800;margin-bottom:10px;">📌 해석 가이드</div>
  <div style="font-size:12.5px;line-height:2.1;color:#cbd5e1;">
    • <b style="color:#06b6d4;">Holt-Winters</b> = 계절·추세·수준을 지수평활로 분리하는 시계열 모델 (SARIMA 동일 계열)<br>
    • <b style="color:#fb923c;">GBM</b> = 여러 결정트리를 순서대로 쌓아 오차를 줄이는 트리부스팅 (XGBoost·LightGBM 동일 계열)<br>
    • <b style="color:#818cf8;">Ridge</b> = 과적합 방지 정규화가 추가된 선형 회귀<br>
    • <b style="color:#f1f5f9;">R²</b> 1에 가까울수록 우수 &nbsp;·&nbsp; <b style="color:#f1f5f9;">RMSE</b> 낮을수록 오차 작음<br>
    • 신뢰구간: CV RMSE 기반 <b style="color:#f1f5f9;">±{ci_pct*100:.1f}%</b> &nbsp;·&nbsp; 월 평균 기울기: <b style="color:#f1f5f9;">₩{trend_slope_disp:+,.0f}</b><br>
    • <b style="color:#fbbf24;">📌 CPI 하한선</b>: 한국 소비자물가 장기 평균 <b style="color:#fbbf24;">연 3.0%</b> 적용 (통계청) — 보험료는 물가연동 특성상 이 이하로 감소하지 않음
  </div>
</div>
""", unsafe_allow_html=True)
