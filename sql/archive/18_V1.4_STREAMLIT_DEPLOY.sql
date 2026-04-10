CALL INSURE_DB.RAW_PUBLIC.WRITE_RAW_FILE('@INSURE_DB.ANALYTICS.STS_STREAMLIT/streamlit_app.py', $$import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import json
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="INSURE v1.4", layout="wide")
session = get_active_session()

st.sidebar.title("INSURE")
st.sidebar.caption("Dynamic Insurance Design Engine v1.4")
page = st.sidebar.radio("Page", [
    "Main Dashboard",
    "Risk Map",
    "Risk Analysis",
    "Goods Analysis",
    "Premium Simulator",
    "Fire Forecast",
    "Actuarial Premium",
    "Business KPI"
])

try:
    ym_df = session.sql("SELECT DISTINCT YEAR_MONTH FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY ORDER BY YEAR_MONTH DESC").to_pandas()
    ym_list = ym_df["YEAR_MONTH"].tolist()
except:
    ym_list = ["202512"]
selected_ym = st.sidebar.selectbox("Period", ym_list, index=0)
st.sidebar.markdown("---")
st.sidebar.caption("v1.4 | 2025 Team CrownPanto")
st.sidebar.caption("SnowFlake Hackathon 2025 Q2")

# ============================================================
# PAGE 1: MAIN DASHBOARD
# ============================================================
if page == "Main Dashboard":
    st.title("INSURE Main Dashboard")
    st.caption("Period: " + str(selected_ym) + " | Seoul 25 Districts | v1.4 Actuarial Premium")
    try:
        df = session.sql("SELECT * FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY WHERE YEAR_MONTH=" + chr(39) + str(selected_ym) + chr(39)).to_pandas()
    except:
        df = pd.DataFrame()
    if not df.empty:
        c1,c2,c3,c4,c5 = st.columns(5)
        c1.metric("Districts", str(df["GU_NAME"].nunique()) + " gu")
        c2.metric("Population", "{:,.0f}".format(df["TOTAL_POPULATION"].sum()))
        c3.metric("Avg Premium", "W{:,.0f}".format(df["AVG_BASE_PREMIUM"].mean()))
        mkt = df["ESTIMATED_ANNUAL_MARKET_KRW"].sum()/1e8
        c4.metric("Annual Market", "W{:,.0f}B".format(mkt))
        c5.metric("Avg Risk", "{:.1f}".format(df["COMPOSITE_RISK_SCORE"].mean()))
        st.markdown("---")
        col_a, col_b = st.columns(2)
        with col_a:
            st.subheader("District Risk Score")
            gu_risk = df.groupby("GU_NAME").agg({"COMPOSITE_RISK_SCORE":"mean","RISK_GRADE":"first"}).reset_index().sort_values("COMPOSITE_RISK_SCORE",ascending=True)
            fig = px.bar(gu_risk, y="GU_NAME", x="COMPOSITE_RISK_SCORE", color="RISK_GRADE", orientation="h",
                         color_discrete_map={"\uace0\uc704\ud5d8":"#e74c3c","\uc911\uc704\ud5d8":"#f39c12","\uc800\uc704\ud5d8":"#27ae60","\ubbf8\uc0b0\uc815":"#95a5a6"},
                         labels={"COMPOSITE_RISK_SCORE":"Risk","GU_NAME":"District"})
            fig.update_layout(height=600, showlegend=True)
            st.plotly_chart(fig, use_container_width=True)
        with col_b:
            st.subheader("Risk Grade Distribution")
            grade_cnt = df.groupby("RISK_GRADE").size().reset_index(name="COUNT")
            fig2 = px.pie(grade_cnt, names="RISK_GRADE", values="COUNT", hole=0.4,
                          color="RISK_GRADE",
                          color_discrete_map={"\uace0\uc704\ud5d8":"#e74c3c","\uc911\uc704\ud5d8":"#f39c12","\uc800\uc704\ud5d8":"#27ae60","\ubbf8\uc0b0\uc815":"#95a5a6"})
            fig2.update_layout(height=300)
            st.plotly_chart(fig2, use_container_width=True)

            st.subheader("Premium by District (Top 10)")
            top_prem = df.nlargest(10, "ADJUSTED_PREMIUM_MONTHLY")[["GU_NAME","ADJUSTED_PREMIUM_MONTHLY","COMPOSITE_RISK_SCORE"]]
            fig_prem = px.bar(top_prem, x="GU_NAME", y="ADJUSTED_PREMIUM_MONTHLY",
                              color="COMPOSITE_RISK_SCORE", color_continuous_scale="Reds",
                              labels={"ADJUSTED_PREMIUM_MONTHLY":"Premium (W)","GU_NAME":"District"})
            fig_prem.update_layout(height=280)
            st.plotly_chart(fig_prem, use_container_width=True)
    else:
        st.warning("No data for selected period")

# ============================================================
# PAGE 2: RISK MAP (Seoul Choropleth)
# ============================================================
elif page == "Risk Map":
    st.title("Seoul District Risk Map")
    st.caption("Choropleth visualization of risk scores across Seoul 25 districts")
    try:
        df = session.sql("SELECT * FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY WHERE YEAR_MONTH=" + chr(39) + str(selected_ym) + chr(39)).to_pandas()
    except:
        df = pd.DataFrame()

    if not df.empty:
        gu_coords = {
            "\uac15\ub0a8\uad6c": [37.5172, 127.0473], "\uac15\ub3d9\uad6c": [37.5301, 127.1238],
            "\uac15\ubd81\uad6c": [37.6396, 127.0253], "\uac15\uc11c\uad6c": [37.5509, 126.8495],
            "\uad00\uc545\uad6c": [37.4784, 126.9516], "\uad11\uc9c4\uad6c": [37.5385, 127.0823],
            "\uad6c\ub85c\uad6c": [37.4954, 126.8874], "\uae08\ucc9c\uad6c": [37.4519, 126.8955],
            "\ub178\uc6d0\uad6c": [37.6542, 127.0568], "\ub3c4\ubd09\uad6c": [37.6688, 127.0471],
            "\ub3d9\ub300\ubb38\uad6c": [37.5744, 127.0400], "\ub3d9\uc791\uad6c": [37.5124, 126.9393],
            "\ub9c8\ud3ec\uad6c": [37.5663, 126.9014], "\uc11c\ub300\ubb38\uad6c": [37.5791, 126.9368],
            "\uc11c\ucd08\uad6c": [37.4837, 127.0324], "\uc131\ub3d9\uad6c": [37.5633, 127.0371],
            "\uc131\ubd81\uad6c": [37.5894, 127.0167], "\uc1a1\ud30c\uad6c": [37.5145, 127.1060],
            "\uc591\ucc9c\uad6c": [37.5170, 126.8665], "\uc601\ub4f1\ud3ec\uad6c": [37.5264, 126.8963],
            "\uc6a9\uc0b0\uad6c": [37.5326, 126.9900], "\uc740\ud3c9\uad6c": [37.6027, 126.9291],
            "\uc885\ub85c\uad6c": [37.5735, 126.9790], "\uc911\uad6c": [37.5641, 126.9979],
            "\uc911\ub791\uad6c": [37.6063, 127.0928]
        }

        map_metric = st.radio("Map Metric", ["Composite Risk Score", "Adjusted Premium", "Population"], horizontal=True)

        gu_df = df.groupby("GU_NAME").agg({
            "COMPOSITE_RISK_SCORE": "mean",
            "ADJUSTED_PREMIUM_MONTHLY": "mean",
            "TOTAL_POPULATION": "sum",
            "RISK_GRADE": "first",
            "FIRE_RISK_SCORE": "mean",
            "THEFT_RISK_SCORE": "mean",
            "BUILDING_RISK_SCORE": "mean",
            "WEATHER_RISK_SCORE": "mean"
        }).reset_index()

        lat_list = []
        lon_list = []
        for gu in gu_df["GU_NAME"]:
            if gu in gu_coords:
                lat_list.append(gu_coords[gu][0])
                lon_list.append(gu_coords[gu][1])
            else:
                lat_list.append(37.55)
                lon_list.append(126.98)
        gu_df["LAT"] = lat_list
        gu_df["LON"] = lon_list

        if map_metric == "Composite Risk Score":
            color_col = "COMPOSITE_RISK_SCORE"
            color_scale = "RdYlGn_r"
        elif map_metric == "Adjusted Premium":
            color_col = "ADJUSTED_PREMIUM_MONTHLY"
            color_scale = "Blues"
        else:
            color_col = "TOTAL_POPULATION"
            color_scale = "Viridis"

        fig_map = px.scatter_mapbox(
            gu_df, lat="LAT", lon="LON", size=color_col, color=color_col,
            hover_name="GU_NAME",
            hover_data={"COMPOSITE_RISK_SCORE":":.1f", "ADJUSTED_PREMIUM_MONTHLY":":.0f",
                        "TOTAL_POPULATION":":.0f", "RISK_GRADE":True,
                        "LAT":False, "LON":False},
            color_continuous_scale=color_scale,
            size_max=30, zoom=10.5,
            mapbox_style="carto-positron",
            labels={color_col: map_metric}
        )
        fig_map.update_layout(height=600, margin={"r":0,"t":0,"l":0,"b":0})
        st.plotly_chart(fig_map, use_container_width=True)

        st.markdown("---")
        st.subheader("Risk Component Radar")
        sel_gu_radar = st.selectbox("Select District for Radar", sorted(gu_df["GU_NAME"].tolist()))
        row = gu_df[gu_df["GU_NAME"] == sel_gu_radar].iloc[0]
        categories = ["Fire Risk", "Theft Risk", "Building Risk", "Weather Risk"]
        values = [row["FIRE_RISK_SCORE"], row["THEFT_RISK_SCORE"],
                  row["BUILDING_RISK_SCORE"], row["WEATHER_RISK_SCORE"]]
        values_closed = values + [values[0]]
        categories_closed = categories + [categories[0]]

        fig_radar = go.Figure(data=[go.Scatterpolar(
            r=values_closed, theta=categories_closed, fill="toself",
            name=sel_gu_radar, line_color="#e74c3c"
        )])
        avg_vals = [gu_df["FIRE_RISK_SCORE"].mean(), gu_df["THEFT_RISK_SCORE"].mean(),
                    gu_df["BUILDING_RISK_SCORE"].mean(), gu_df["WEATHER_RISK_SCORE"].mean()]
        avg_closed = avg_vals + [avg_vals[0]]
        fig_radar.add_trace(go.Scatterpolar(
            r=avg_closed, theta=categories_closed, fill="toself",
            name="Seoul Average", line_color="#3498db", opacity=0.5
        ))
        fig_radar.update_layout(polar=dict(radialaxis=dict(visible=True, range=[0, 60])),
                                showlegend=True, height=400)
        st.plotly_chart(fig_radar, use_container_width=True)
    else:
        st.warning("No data for selected period")

# ============================================================
# PAGE 3: RISK ANALYSIS
# ============================================================
elif page == "Risk Analysis":
    st.title("Risk Analysis")
    try:
        risk = session.sql(
            "SELECT DISTRICT_NAME, FIRE_RISK_SCORE, THEFT_RISK_SCORE, "
            "BUILDING_RISK_SCORE, WEATHER_RISK_SCORE, "
            "SAFETY_INFRA_SCORE, CCTV_SECURITY_SCORE, "
            "COMPOSITE_RISK_SCORE, RISK_GRADE "
            "FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE "
            "WHERE YEAR=(SELECT MAX(YEAR) FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE) "
            "ORDER BY COMPOSITE_RISK_SCORE DESC"
        ).to_pandas()
        st.subheader("District Risk Detail")
        st.dataframe(risk, use_container_width=True, height=500)

        st.markdown("---")
        st.subheader("Risk Component Heatmap")
        if not risk.empty:
            heat_data = risk.set_index("DISTRICT_NAME")[["FIRE_RISK_SCORE","THEFT_RISK_SCORE","BUILDING_RISK_SCORE","WEATHER_RISK_SCORE"]].copy()
            heat_data.columns = ["Fire","Theft","Building","Weather"]
            fig_heat = px.imshow(heat_data.T, aspect="auto", color_continuous_scale="RdYlGn_r",
                                 labels=dict(x="District", y="Risk Type", color="Score"))
            fig_heat.update_layout(height=300)
            st.plotly_chart(fig_heat, use_container_width=True)
    except Exception as e:
        st.error("Risk data error: " + str(e))

    st.subheader("Fire Prediction (Latest Year)")
    try:
        fire = session.sql(
            "SELECT DISTRICT_NAME, SUM(TOTAL_FIRES) AS PREDICTED_FIRES "
            "FROM INSURE_DB.STAGING.STG_FIRE_STATS "
            "WHERE YEAR=(SELECT MAX(YEAR) FROM INSURE_DB.STAGING.STG_FIRE_STATS) "
            "GROUP BY DISTRICT_NAME ORDER BY PREDICTED_FIRES DESC"
        ).to_pandas()
        if not fire.empty:
            fig = px.bar(fire, x="DISTRICT_NAME", y="PREDICTED_FIRES",
                         color="PREDICTED_FIRES", color_continuous_scale="Reds",
                         labels={"DISTRICT_NAME":"District","PREDICTED_FIRES":"Predicted Fires"})
            fig.update_layout(height=400)
            st.plotly_chart(fig, use_container_width=True)
    except:
        st.info("Fire stats loading failed")

# ============================================================
# PAGE 4: GOODS ANALYSIS (v1.3 feature, kept in v1.4)
# ============================================================
elif page == "Goods Analysis":
    st.title("Household Goods Analysis")
    st.caption("v1.4 | Income-bracket specific movable asset estimation")

    tab1, tab2, tab3 = st.tabs(["By Income Bracket", "By Segment", "Item Detail"])

    with tab1:
        st.subheader("Total Movable Asset Value by Income Bracket")
        try:
            goods_income = session.sql(
                "SELECT INCOME_BRACKET, SEGMENT_A, "
                "SUM(AVG_TOTAL_VALUE_KRW) AS TOTAL_VALUE, "
                "SUM(AVG_TOTAL_VALUE_KRW * DAMAGE_RISK_RATE) AS EXPECTED_LOSS, "
                "COUNT(*) AS ITEM_TYPES "
                "FROM INSURE_DB.SEED.SEED_HOUSEHOLD_GOODS "
                "GROUP BY INCOME_BRACKET, SEGMENT_A "
                "ORDER BY TOTAL_VALUE DESC"
            ).to_pandas()
            if not goods_income.empty:
                fig_gi = px.bar(goods_income, x="SEGMENT_A", y="TOTAL_VALUE",
                                color="INCOME_BRACKET", barmode="group",
                                color_discrete_map={"LOW":"#95a5a6","MID":"#3498db","HIGH":"#f39c12","ULTRA":"#e74c3c"},
                                labels={"TOTAL_VALUE":"Total Asset Value (KRW)","SEGMENT_A":"Life Stage"})
                fig_gi.update_layout(height=400)
                st.plotly_chart(fig_gi, use_container_width=True)

                st.subheader("Expected Annual Loss by Segment")
                fig_loss = px.bar(goods_income, x="SEGMENT_A", y="EXPECTED_LOSS",
                                  color="INCOME_BRACKET", barmode="group",
                                  color_discrete_map={"LOW":"#95a5a6","MID":"#3498db","HIGH":"#f39c12","ULTRA":"#e74c3c"},
                                  labels={"EXPECTED_LOSS":"Expected Loss (KRW)","SEGMENT_A":"Life Stage"})
                fig_loss.update_layout(height=350)
                st.plotly_chart(fig_loss, use_container_width=True)
            else:
                st.info("Goods seed data not found. Run 14_V1.3_ENHANCEMENTS.sql first.")
        except Exception as e:
            st.info("Goods data not available: " + str(e))

    with tab2:
        st.subheader("Asset Coefficients by Segment")
        try:
            coeff = session.sql(
                "SELECT SEGMENT_KEY, ASSET_RATIO, INCOME_RATIO, INSTALLMENT_MULT, DESCRIPTION "
                "FROM INSURE_DB.SEED.SEGMENT_ASSET_COEFFICIENTS ORDER BY SEGMENT_KEY"
            ).to_pandas()
            if not coeff.empty:
                col1, col2 = st.columns(2)
                with col1:
                    fig_coeff = go.Figure()
                    fig_coeff.add_trace(go.Bar(name="Asset Ratio", x=coeff["SEGMENT_KEY"], y=coeff["ASSET_RATIO"], marker_color="#3498db"))
                    fig_coeff.add_trace(go.Bar(name="Income Ratio", x=coeff["SEGMENT_KEY"], y=coeff["INCOME_RATIO"], marker_color="#e74c3c"))
                    fig_coeff.update_layout(barmode="group", height=350, title="Asset vs Income Coefficients")
                    st.plotly_chart(fig_coeff, use_container_width=True)
                with col2:
                    fig_mult = px.bar(coeff, x="SEGMENT_KEY", y="INSTALLMENT_MULT",
                                      color="INSTALLMENT_MULT", color_continuous_scale="Oranges",
                                      title="Installment Multiplier by Segment")
                    fig_mult.update_layout(height=350)
                    st.plotly_chart(fig_mult, use_container_width=True)
                st.dataframe(coeff, use_container_width=True)
            else:
                st.info("Coefficient data not found.")
        except Exception as e:
            st.info("Coefficient data not available: " + str(e))

    with tab3:
        st.subheader("Detailed Item Breakdown")
        try:
            items = session.sql(
                "SELECT INCOME_BRACKET, SEGMENT_A, ITEM_CATEGORY, ITEM_NAME, "
                "AVG_QUANTITY, AVG_UNIT_VALUE_KRW, AVG_TOTAL_VALUE_KRW, DAMAGE_RISK_RATE "
                "FROM INSURE_DB.SEED.SEED_HOUSEHOLD_GOODS ORDER BY INCOME_BRACKET, SEGMENT_A, ITEM_CATEGORY"
            ).to_pandas()
            if not items.empty:
                sel_bracket = st.selectbox("Income Bracket", sorted(items["INCOME_BRACKET"].unique().tolist()))
                filtered = items[items["INCOME_BRACKET"] == sel_bracket]
                sel_seg_g = st.selectbox("Life Stage", sorted(filtered["SEGMENT_A"].unique().tolist()))
                filtered2 = filtered[filtered["SEGMENT_A"] == sel_seg_g]

                fig_tree = px.treemap(filtered2, path=["ITEM_CATEGORY","ITEM_NAME"],
                                      values="AVG_TOTAL_VALUE_KRW",
                                      color="DAMAGE_RISK_RATE", color_continuous_scale="RdYlGn_r",
                                      title="Asset Value Treemap (size=value, color=risk)")
                fig_tree.update_layout(height=400)
                st.plotly_chart(fig_tree, use_container_width=True)

                total_val = filtered2["AVG_TOTAL_VALUE_KRW"].sum()
                total_risk = (filtered2["AVG_TOTAL_VALUE_KRW"] * filtered2["DAMAGE_RISK_RATE"]).sum()
                c1,c2,c3 = st.columns(3)
                c1.metric("Total Items", str(len(filtered2)))
                c2.metric("Total Value", "W{:,.0f}".format(total_val))
                c3.metric("Expected Loss", "W{:,.0f}/yr".format(total_risk))

                st.dataframe(filtered2, use_container_width=True)
            else:
                st.info("Item data not found.")
        except Exception as e:
            st.info("Item data not available: " + str(e))

# ============================================================
# PAGE 5: PREMIUM SIMULATOR (v1.4 with Actuarial note)
# ============================================================
elif page == "Premium Simulator":
    st.title("Premium Simulator v1.4")
    st.caption("Nonlinear risk curve + segment-specific asset coefficients")

    st.info(
        "\u2728 **NEW in v1.4:** Check the **Actuarial Premium** page for detailed actuarial-grade breakdown "
        "with 7-layer decomposition, risk classification factors, and affordability analysis!"
    )

    try:
        gu_list = session.sql("SELECT DISTINCT GU_NAME FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY WHERE GU_NAME IS NOT NULL ORDER BY GU_NAME").to_pandas()["GU_NAME"].tolist()
    except:
        gu_list = []
    try:
        seg_list2 = session.sql("SELECT DISTINCT SEGMENT_A FROM INSURE_DB.MART.MART_INSURANCE_DESIGN ORDER BY SEGMENT_A").to_pandas()["SEGMENT_A"].tolist()
    except:
        seg_list2 = ["A0"]
    c1,c2 = st.columns(2)
    sel_gu = c1.selectbox("District", gu_list)
    sel_seg = c2.selectbox("Segment", seg_list2)
    asset_val = st.slider("Asset Value (10K KRW)", 1000, 100000, 22000, step=1000)

    try:
        bp = session.sql("SELECT AVG(AVG_BASE_PREMIUM) AS BP FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY WHERE GU_NAME=" + chr(39) + str(sel_gu) + chr(39)).to_pandas()
        base = float(bp["BP"].iloc[0]) if not bp.empty and bp["BP"].iloc[0] is not None else 10000
    except:
        base = 10000
    try:
        rk = session.sql("SELECT COMPOSITE_RISK_SCORE, RISK_GRADE FROM INSURE_DB.INTERMEDIATE.INT_DISTRICT_RISK_SCORE WHERE DISTRICT_NAME=" + chr(39) + str(sel_gu) + chr(39) + " ORDER BY YEAR DESC LIMIT 1").to_pandas()
        r_score = float(rk["COMPOSITE_RISK_SCORE"].iloc[0]) if not rk.empty else 30
        r_grade = rk["RISK_GRADE"].iloc[0] if not rk.empty else "N/A"
    except:
        r_score = 30
        r_grade = "N/A"

    try:
        credit_df = session.sql("SELECT AVG(AVG_CREDIT) AS CR FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY WHERE GU_NAME=" + chr(39) + str(sel_gu) + chr(39)).to_pandas()
        credit_score = float(credit_df["CR"].iloc[0]) if not credit_df.empty and credit_df["CR"].iloc[0] is not None else 700
    except:
        credit_score = 700

    asset_factor = asset_val / 22000

    if r_score < 25:
        risk_mult = 0.85 + (r_score / 25.0) ** 0.7 * 0.15
    elif r_score < 40:
        risk_mult = 1.00 + (r_score - 25) / 100.0
    elif r_score < 60:
        risk_mult = 1.15 + ((r_score - 40) / 20.0) ** 1.5 * 0.35
    elif r_score < 80:
        risk_mult = 1.50 + ((r_score - 60) / 20.0) ** 1.8 * 0.50
    else:
        risk_mult = min(2.00 + (r_score - 80) * 0.02, 2.50)

    old_risk_mult = 1 + r_score / 200.0

    base_adj = round(base * asset_factor, 0)
    risk_adj = round(base_adj * (risk_mult - 1), 0)
    old_risk_adj = round(base_adj * (old_risk_mult - 1), 0)

    if credit_score >= 800:
        credit_mult = 0.90
    elif credit_score >= 700:
        credit_mult = 0.95
    else:
        credit_mult = 1.05
    pre_credit = base_adj + risk_adj
    credit_adj = round(pre_credit * (credit_mult - 1), 0)
    final = round(pre_credit + credit_adj, 0)
    old_final = round((base_adj + old_risk_adj) * credit_mult, 0)

    st.markdown("---")
    c1,c2,c3,c4,c5 = st.columns(5)
    c1.metric("Base Premium", "W{:,.0f}".format(base))
    c2.metric("Risk Grade", r_grade)
    c3.metric("Risk Score", "{:.1f}".format(r_score))
    delta_val = "{:+.1f}%".format(((final/base)-1)*100) if base > 0 else None
    c4.metric("Final Premium", "W{:,.0f}/mo".format(final), delta=delta_val)
    diff_pct = ((final - old_final) / old_final * 100) if old_final > 0 else 0
    c5.metric("vs Linear v1.2", "{:+.1f}%".format(diff_pct))

    st.markdown("---")
    col_w, col_c = st.columns([3, 2])
    with col_w:
        st.subheader("Premium Waterfall (v1.4)")
        waterfall_fig = go.Figure(go.Waterfall(
            name="Premium Breakdown",
            orientation="v",
            measure=["absolute", "relative", "relative", "total"],
            x=["Base Premium", "Risk Adj (+" + "{:.1f}".format(r_score) + ")",
               "Credit Adj (" + "{:.0f}".format(credit_score) + ")",
               "Final Premium"],
            y=[base_adj, risk_adj, credit_adj, 0],
            text=["W{:,.0f}".format(base_adj),
                  "+W{:,.0f}".format(risk_adj),
                  "W{:,.0f}".format(credit_adj),
                  "W{:,.0f}".format(final)],
            textposition="outside",
            connector={"line": {"color": "#95a5a6"}},
            increasing={"marker": {"color": "#e74c3c"}},
            decreasing={"marker": {"color": "#27ae60"}},
            totals={"marker": {"color": "#3498db"}}
        ))
        waterfall_fig.update_layout(height=400, title="Nonlinear Premium Breakdown",
                                     showlegend=False, yaxis_title="Monthly Premium (KRW)")
        st.plotly_chart(waterfall_fig, use_container_width=True)

    with col_c:
        st.subheader("Risk Curve: v1.2 vs v1.4")
        import numpy as np
        scores = list(range(0, 101))
        linear_mults = [1 + s / 200.0 for s in scores]
        nonlinear_mults = []
        for s in scores:
            if s < 25:
                nonlinear_mults.append(0.85 + (s / 25.0) ** 0.7 * 0.15)
            elif s < 40:
                nonlinear_mults.append(1.00 + (s - 25) / 100.0)
            elif s < 60:
                nonlinear_mults.append(1.15 + ((s - 40) / 20.0) ** 1.5 * 0.35)
            elif s < 80:
                nonlinear_mults.append(1.50 + ((s - 60) / 20.0) ** 1.8 * 0.50)
            else:
                nonlinear_mults.append(min(2.00 + (s - 80) * 0.02, 2.50))

        fig_curve = go.Figure()
        fig_curve.add_trace(go.Scatter(x=scores, y=linear_mults, mode="lines",
                                        name="v1.2 Linear", line=dict(color="#95a5a6", dash="dash")))
        fig_curve.add_trace(go.Scatter(x=scores, y=nonlinear_mults, mode="lines",
                                        name="v1.4 Nonlinear", line=dict(color="#e74c3c", width=3)))
        fig_curve.add_vline(x=r_score, line_dash="dot", line_color="#3498db",
                            annotation_text=str(sel_gu))
        fig_curve.update_layout(height=400, title="Risk Multiplier Curve",
                                xaxis_title="Risk Score", yaxis_title="Premium Multiplier",
                                showlegend=True)
        st.plotly_chart(fig_curve, use_container_width=True)

    st.info(str(sel_gu) + " | " + str(sel_seg) + " | Asset " + "{:,}".format(asset_val) + "0K KRW -> Monthly W" + "{:,.0f}".format(final) + " (v1.2: W{:,.0f})".format(old_final))

# ============================================================
# PAGE 6: FIRE FORECAST (v1.3 feature, kept in v1.4)
# ============================================================
elif page == "Fire Forecast":
    st.title("Fire Prediction & Forecast v1.4")
    st.caption("Ensemble prediction: Trend + Weighted Moving Average")

    try:
        forecast = session.sql(
            "SELECT * FROM INSURE_DB.ANALYTICS.V_FIRE_FORECAST_V13 ORDER BY ENSEMBLE_PREDICTION DESC"
        ).to_pandas()
        if not forecast.empty:
            c1,c2,c3 = st.columns(3)
            c1.metric("Avg Predicted Fires", "{:.0f}".format(forecast["ENSEMBLE_PREDICTION"].mean()))
            high_conf = forecast[forecast["CONFIDENCE_LEVEL"] == "HIGH"].shape[0]
            c2.metric("High Confidence", str(high_conf) + "/" + str(len(forecast)))
            c3.metric("Total Predicted Damage", "W{:,.0f}B".format(forecast["PREDICTED_DAMAGE_KRW"].sum()/1e8))

            st.markdown("---")
            col1, col2 = st.columns(2)
            with col1:
                st.subheader("2025 Fire Prediction by District")
                fig_fc = go.Figure()
                fig_fc.add_trace(go.Bar(
                    x=forecast["DISTRICT_NAME"], y=forecast["ENSEMBLE_PREDICTION"],
                    name="Ensemble Prediction", marker_color="#e74c3c"
                ))
                fig_fc.add_trace(go.Scatter(
                    x=forecast["DISTRICT_NAME"], y=forecast["UPPER_95"],
                    mode="markers", name="Upper 95%", marker=dict(symbol="triangle-up", size=8, color="#f39c12")
                ))
                fig_fc.add_trace(go.Scatter(
                    x=forecast["DISTRICT_NAME"], y=forecast["LOWER_95"],
                    mode="markers", name="Lower 95%", marker=dict(symbol="triangle-down", size=8, color="#3498db")
                ))
                fig_fc.update_layout(height=450, xaxis_tickangle=-45)
                st.plotly_chart(fig_fc, use_container_width=True)

            with col2:
                st.subheader("Prediction Confidence")
                conf_counts = forecast["CONFIDENCE_LEVEL"].value_counts().reset_index()
                conf_counts.columns = ["LEVEL", "COUNT"]
                fig_conf = px.pie(conf_counts, names="LEVEL", values="COUNT", hole=0.4,
                                  color="LEVEL",
                                  color_discrete_map={"HIGH":"#27ae60","MEDIUM":"#f39c12","LOW":"#e74c3c"})
                fig_conf.update_layout(height=250)
                st.plotly_chart(fig_conf, use_container_width=True)

                st.subheader("Model R-squared")
                fig_r2 = px.bar(forecast.sort_values("MODEL_R_SQUARED", ascending=True),
                                y="DISTRICT_NAME", x="MODEL_R_SQUARED", orientation="h",
                                color="CONFIDENCE_LEVEL",
                                color_discrete_map={"HIGH":"#27ae60","MEDIUM":"#f39c12","LOW":"#e74c3c"})
                fig_r2.update_layout(height=350)
                st.plotly_chart(fig_r2, use_container_width=True)

            st.markdown("---")
            st.subheader("Trend vs Weighted Prediction")
            fig_compare = go.Figure()
            fig_compare.add_trace(go.Bar(name="Trend", x=forecast["DISTRICT_NAME"], y=forecast["TREND_PREDICTION"], marker_color="#3498db"))
            fig_compare.add_trace(go.Bar(name="Weighted Avg", x=forecast["DISTRICT_NAME"], y=forecast["WEIGHTED_PREDICTION"], marker_color="#e74c3c"))
            fig_compare.add_trace(go.Scatter(name="Ensemble", x=forecast["DISTRICT_NAME"], y=forecast["ENSEMBLE_PREDICTION"],
                                              mode="markers+lines", marker=dict(size=10, color="#2ecc71")))
            fig_compare.update_layout(barmode="group", height=400, xaxis_tickangle=-45)
            st.plotly_chart(fig_compare, use_container_width=True)

            st.dataframe(forecast, use_container_width=True)
        else:
            st.info("No forecast data. Run 14_V1.3_ENHANCEMENTS.sql first.")
    except Exception as e:
        st.info("Forecast view not available yet: " + str(e))

    st.markdown("---")
    st.subheader("Historical Fire Trend")
    try:
        hist = session.sql(
            "SELECT DISTRICT_NAME, DATE_KEY, FIRE_COUNT "
            "FROM INSURE_DB.ANALYTICS.V_FIRE_TIMESERIES ORDER BY DISTRICT_NAME, DATE_KEY"
        ).to_pandas()
        if not hist.empty:
            fig_hist = px.line(hist, x="DATE_KEY", y="FIRE_COUNT", color="DISTRICT_NAME",
                               labels={"FIRE_COUNT":"Fires","DATE_KEY":"Year"})
            fig_hist.update_layout(height=400)
            st.plotly_chart(fig_hist, use_container_width=True)
    except:
        st.info("Historical fire data not available")

# ============================================================
# PAGE 7: ACTUARIAL PREMIUM (NEW in v1.4)
# ============================================================
elif page == "Actuarial Premium":
    st.title("Actuarial Premium Analysis v1.4")
    st.caption("7-layer premium decomposition with risk classification and affordability assessment")

    sel_district_ap = st.selectbox("Select District", [
        "\uac15\ub0a8\uad6c", "\uac15\ub3d9\uad6c", "\uac15\ubd81\uad6c", "\uac15\uc11c\uad6c",
        "\uad00\uc545\uad6c", "\uad11\uc9c4\uad6c", "\uad6c\ub85c\uad6c", "\uae08\ucc9c\uad6c",
        "\ub178\uc6d0\uad6c", "\ub3c4\ubd09\uad6c", "\ub3d9\ub300\ubb38\uad6c", "\ub3d9\uc791\uad6c",
        "\ub9c8\ud3ec\uad6c", "\uc11c\ub300\ubb38\uad6c", "\uc11c\ucd08\uad6c", "\uc131\ub3d9\uad6c",
        "\uc131\ubd81\uad6c", "\uc1a1\ud30c\uad6c", "\uc591\ucc9c\uad6c", "\uc601\ub4f1\ud3ec\uad6c",
        "\uc6a9\uc0b0\uad6c", "\uc740\ud3c9\uad6c", "\uc885\ub85c\uad6c", "\uc911\uad6c", "\uc911\ub791\uad6c"
    ], key="ap_district")

    try:
        ap_df = session.sql(
            "SELECT * FROM INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14 WHERE DISTRICT=" + chr(39) + str(sel_district_ap) + chr(39) + " LIMIT 1"
        ).to_pandas()

        if not ap_df.empty:
            row = ap_df.iloc[0]

            st.markdown("---")
            st.subheader("\ud83c\udcc4 Premium Decomposition Waterfall")

            pure_premium = row.get("PURE_PREMIUM", 5000)
            exp_rating = row.get("EXPERIENCE_RATING_ADJ", 500)
            risk_class = row.get("RISK_CLASS_ADJ", 800)
            segment_adj = row.get("SEGMENT_ADJ", 600)
            expense_profit = row.get("EXPENSE_PROFIT_LOADING", 1200)
            credit_feedback = row.get("CREDIT_FEEDBACK_ADJ", -300)
            affordability_cap = row.get("AFFORDABILITY_CAP", 0)

            fig_waterfall = go.Figure(go.Waterfall(
                name="Actuarial Premium",
                orientation="v",
                measure=["absolute", "relative", "relative", "relative", "relative", "relative", "relative", "total"],
                x=[
                    "Pure Premium\n(Freq x Sev)",
                    "Experience\nRating",
                    "Risk Class",
                    "Segment",
                    "Expense/Profit",
                    "Credit/Feedback",
                    "Affordability\nCap",
                    "Final\nPremium"
                ],
                y=[pure_premium, exp_rating, risk_class, segment_adj, expense_profit, credit_feedback, affordability_cap, 0],
                text=[
                    "W{:,.0f}".format(pure_premium),
                    "+W{:,.0f}".format(exp_rating),
                    "+W{:,.0f}".format(risk_class),
                    "+W{:,.0f}".format(segment_adj),
                    "+W{:,.0f}".format(expense_profit),
                    "-W{:,.0f}".format(abs(credit_feedback)),
                    "+W{:,.0f}".format(affordability_cap),
                    "W{:,.0f}".format(pure_premium + exp_rating + risk_class + segment_adj + expense_profit + credit_feedback + affordability_cap)
                ],
                textposition="outside",
                connector={"line": {"color": "#95a5a6"}},
                increasing={"marker": {"color": "#e74c3c"}},
                decreasing={"marker": {"color": "#27ae60"}},
                totals={"marker": {"color": "#3498db"}}
            ))
            fig_waterfall.update_layout(
                height=450,
                title="7-Layer Actuarial Premium Decomposition",
                yaxis_title="Premium Component (KRW)",
                showlegend=False
            )
            st.plotly_chart(fig_waterfall, use_container_width=True)
        else:
            st.warning("Actuarial premium data not available for " + str(sel_district_ap))
    except Exception as e:
        st.warning("Actuarial premium table not available yet: " + str(e))
        st.info("Expected source: INSURE_DB.MART.MART_ACTUARIAL_PREMIUM_V14")

    st.markdown("---")
    st.subheader("\ud83d\udcc4 Premium Comparison: v1.3 Simple vs v1.4 Actuarial")
    try:
        comp_df = session.sql(
            "SELECT * FROM INSURE_DB.ANALYTICS.VW_PREMIUM_COMPARISON_V13_VS_V14 WHERE DISTRICT=" + chr(39) + str(sel_district_ap) + chr(39)
        ).to_pandas()

        if not comp_df.empty:
            fig_comp = px.bar(
                comp_df, x="SEGMENT", y=["V13_SIMPLE_PREMIUM", "V14_ACTUARIAL_PREMIUM"],
                barmode="group",
                labels={
                    "V13_SIMPLE_PREMIUM": "v1.3 Simple",
                    "V14_ACTUARIAL_PREMIUM": "v1.4 Actuarial",
                    "SEGMENT": "Customer Segment"
                },
                color_discrete_map={
                    "V13_SIMPLE_PREMIUM": "#95a5a6",
                    "V14_ACTUARIAL_PREMIUM": "#3498db"
                }
            )
            fig_comp.update_layout(height=350)
            st.plotly_chart(fig_comp, use_container_width=True)
            st.dataframe(comp_df, use_container_width=True)
        else:
            st.info("Comparison data not available for " + str(sel_district_ap))
    except Exception as e:
        st.info("Comparison view not available yet: " + str(e))

    st.markdown("---")
    st.subheader("\ud83c\udfc6 Risk Classification Factors (8-Tier System)")
    try:
        risk_class_df = session.sql(
            "SELECT RISK_CLASS, MIN_SCORE, MAX_SCORE, PREMIUM_MULTIPLIER, DESCRIPTION FROM INSURE_DB.SEED.SEED_RISK_CLASS_FACTORS ORDER BY PREMIUM_MULTIPLIER DESC"
        ).to_pandas()

        if not risk_class_df.empty:
            st.dataframe(risk_class_df, use_container_width=True, hide_index=True)
        else:
            st.info("Risk classification table not found.")
    except Exception as e:
        st.info("Risk classification data not available: " + str(e))

    st.markdown("---")
    st.subheader("\ud83c\udcb0 Affordability Index")
    try:
        afford_df = session.sql(
            "SELECT DISTRICT, AFFORDABILITY_INDEX, AVG_INCOME, RECOMMENDED_PREMIUM FROM INSURE_DB.MART.MART_AFFORDABILITY_INDEX WHERE DISTRICT=" + chr(39) + str(sel_district_ap) + chr(39)
        ).to_pandas()

        if not afford_df.empty:
            row_af = afford_df.iloc[0]
            c1, c2, c3 = st.columns(3)
            c1.metric("\ud83d\udcc8 Affordability Index", "{:.2f}".format(row_af.get("AFFORDABILITY_INDEX", 0.8)))
            c2.metric("\ud83c\udcb3 Avg Income", "W{:,.0f}M".format(row_af.get("AVG_INCOME", 50000000)))
            c3.metric("\ud83d\udcb5 Recommended Premium", "W{:,.0f}".format(row_af.get("RECOMMENDED_PREMIUM", 15000)))
        else:
            st.info("Affordability index not available for this district.")
    except Exception as e:
        st.info("Affordability data not available: " + str(e))

# ============================================================
# PAGE 8: BUSINESS KPI (NEW in v1.4 - replaces Feedback)
# ============================================================
elif page == "Business KPI":
    st.title("Business KPI Dashboard v1.4")
    st.caption("Automated business metrics and system health monitoring")

    st.markdown("---")
    st.subheader("\ud83d\udcc8 Actuary KPI Metrics")
    try:
        actuary_kpi = session.sql(
            "SELECT CONVERSION_RATE, AVG_DESIGN_TIME_DAYS, QUOTE_VOLUME, APPROVAL_RATE FROM INSURE_DB.FEEDBACK.V_ACTUARY_KPI LIMIT 1"
        ).to_pandas()

        if not actuary_kpi.empty:
            row_ak = actuary_kpi.iloc[0]
            c1, c2, c3, c4 = st.columns(4)
            c1.metric("\ud83c\udf89 Conversion Rate", "{:.1f}%".format(row_ak.get("CONVERSION_RATE", 42.5)))
            c2.metric("\ud83d\udcc5 Avg Design Time", "{:.0f}".format(row_ak.get("AVG_DESIGN_TIME_DAYS", 3)) + " days")
            c3.metric("\ud83d\udcca Quote Volume", "{:,.0f}".format(row_ak.get("QUOTE_VOLUME", 1250)))
            c4.metric("\u2705 Approval Rate", "{:.1f}%".format(row_ak.get("APPROVAL_RATE", 78.5)))
        else:
            st.info("Actuary KPI data not available yet.")
    except Exception as e:
        st.info("Actuary KPI not available: " + str(e))

    st.markdown("---")
    st.subheader("\ud83d\udecd\ufe0f Customer Journey Funnel")
    try:
        cust_kpi = session.sql(
            "SELECT SEARCH_COUNT, COMPARE_COUNT, QUOTE_COUNT, SIGNUP_COUNT FROM INSURE_DB.FEEDBACK.V_CUSTOMER_KPI LIMIT 1"
        ).to_pandas()

        if not cust_kpi.empty:
            row_ck = cust_kpi.iloc[0]
            funnel_data = pd.DataFrame({
                "Stage": ["Search", "Compare", "Quote", "Signup"],
                "Count": [
                    row_ck.get("SEARCH_COUNT", 5000),
                    row_ck.get("COMPARE_COUNT", 2500),
                    row_ck.get("QUOTE_COUNT", 1200),
                    row_ck.get("SIGNUP_COUNT", 480)
                ]
            })

            fig_funnel = go.Figure(go.Funnel(
                x=funnel_data["Count"],
                y=funnel_data["Stage"],
                marker=dict(color=["#3498db", "#2ecc71", "#f39c12", "#e74c3c"])
            ))
            fig_funnel.update_layout(height=350, title="Customer Conversion Funnel")
            st.plotly_chart(fig_funnel, use_container_width=True)
        else:
            st.info("Customer KPI data not available yet.")
    except Exception as e:
        st.info("Customer KPI funnel not available: " + str(e))

    st.markdown("---")
    st.subheader("\ud83d\udcab System Health Metrics")
    try:
        sys_health = session.sql(
            "SELECT API_UPTIME_PCT, AVG_RESPONSE_TIME_MS, ERROR_RATE_PCT, DATA_FRESHNESS_HOURS FROM INSURE_DB.FEEDBACK.V_SYSTEM_HEALTH LIMIT 1"
        ).to_pandas()

        if not sys_health.empty:
            row_sh = sys_health.iloc[0]
            col1, col2 = st.columns(2)

            with col1:
                uptime = row_sh.get("API_UPTIME_PCT", 99.8)
                fig_uptime = go.Figure(go.Indicator(
                    mode="gauge+number+delta",
                    value=uptime,
                    title={"text": "API Uptime %"},
                    delta={"reference": 99.9},
                    gauge={"axis": {"range": [95, 100]}, "bar": {"color": "#27ae60"}}
                ))
                fig_uptime.update_layout(height=300)
                st.plotly_chart(fig_uptime, use_container_width=True)

            with col2:
                error_rate = row_sh.get("ERROR_RATE_PCT", 0.2)
                fig_errors = go.Figure(go.Indicator(
                    mode="gauge+number",
                    value=error_rate,
                    title={"text": "Error Rate %"},
                    gauge={"axis": {"range": [0, 1]}, "bar": {"color": "#e74c3c"}}
                ))
                fig_errors.update_layout(height=300)
                st.plotly_chart(fig_errors, use_container_width=True)

            c1, c2 = st.columns(2)
            c1.metric("\ud83d\udeeb Avg Response Time", "{:.0f}".format(row_sh.get("AVG_RESPONSE_TIME_MS", 145)) + " ms")
            c2.metric("\ud83d\udcc1 Data Freshness", "{:.1f}".format(row_sh.get("DATA_FRESHNESS_HOURS", 2)) + " hrs")
        else:
            st.info("System health data not available yet.")
    except Exception as e:
        st.info("System health metrics not available: " + str(e))

    st.markdown("---")
    st.subheader("\ud83d\udce7 User Feedback (Quick Form)")

    with st.form("quick_feedback_form"):
        fb_category = st.selectbox("\ud83d\udcac Feedback Category", ["Feature Request", "Bug Report", "Performance", "Data Quality", "Other"])
        fb_text = st.text_area("\ud83d\udcdd Your Feedback", placeholder="Tell us what you think...")
        fb_submit = st.form_submit_button("\u2705 Submit")

        if fb_submit and fb_text:
            try:
                session.sql(
                    "INSERT INTO INSURE_DB.FEEDBACK.FEEDBACK_RESPONSES "
                    "(USER_TYPE, DISTRICT, COMMENTS) VALUES ("
                    + chr(39) + "KPI_Dashboard" + chr(39) + ", "
                    + chr(39) + "N/A" + chr(39) + ", "
                    + chr(39) + str(fb_text).replace(chr(39), chr(39)+chr(39)) + chr(39)
                    + ")"
                ).collect()
                st.success("\ud83c\udf86 Thank you for your feedback!")
            except Exception as e:
                st.error("Submission error: " + str(e))
        elif fb_submit:
            st.warning("Please enter feedback text.")
$$);