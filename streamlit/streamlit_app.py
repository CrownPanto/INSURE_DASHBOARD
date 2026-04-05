import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import json
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="INSURE", layout="wide")
session = get_active_session()

st.sidebar.title("INSURE")
st.sidebar.caption("Dynamic Insurance Design Engine")
page = st.sidebar.radio("Page", ["Main Dashboard","Risk Map","Risk Analysis","Premium Simulator","Feedback"])

try:
    ym_df = session.sql("SELECT DISTINCT YEAR_MONTH FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY ORDER BY YEAR_MONTH DESC").to_pandas()
    ym_list = ym_df["YEAR_MONTH"].tolist()
except:
    ym_list = ["202512"]
selected_ym = st.sidebar.selectbox("Period", ym_list, index=0)
st.sidebar.markdown("---")
st.sidebar.caption("v1.2 | 2025 Team CrownPanto")
st.sidebar.caption("SnowFlake Hackathon 2025 Q2")

# ============================================================
# PAGE 1: MAIN DASHBOARD
# ============================================================
if page == "Main Dashboard":
    st.title("INSURE Main Dashboard")
    st.caption("Period: " + str(selected_ym) + " | Seoul 25 Districts")
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
                         color_discrete_map={"고위험":"#e74c3c","중위험":"#f39c12","저위험":"#27ae60","미산정":"#95a5a6"},
                         labels={"COMPOSITE_RISK_SCORE":"Risk","GU_NAME":"District"})
            fig.update_layout(height=600, showlegend=True)
            st.plotly_chart(fig, use_container_width=True)
        with col_b:
            st.subheader("Risk Grade Distribution")
            grade_cnt = df.groupby("RISK_GRADE").size().reset_index(name="COUNT")
            fig2 = px.pie(grade_cnt, names="RISK_GRADE", values="COUNT", hole=0.4,
                          color="RISK_GRADE",
                          color_discrete_map={"고위험":"#e74c3c","중위험":"#f39c12","저위험":"#27ae60","미산정":"#95a5a6"})
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
        # Seoul district coordinates (approximate center points for each gu)
        gu_coords = {
            "강남구": [37.5172, 127.0473], "강동구": [37.5301, 127.1238],
            "강북구": [37.6396, 127.0253], "강서구": [37.5509, 126.8495],
            "관악구": [37.4784, 126.9516], "광진구": [37.5385, 127.0823],
            "구로구": [37.4954, 126.8874], "금천구": [37.4519, 126.8955],
            "노원구": [37.6542, 127.0568], "도봉구": [37.6688, 127.0471],
            "동대문구": [37.5744, 127.0400], "동작구": [37.5124, 126.9393],
            "마포구": [37.5663, 126.9014], "서대문구": [37.5791, 126.9368],
            "서초구": [37.4837, 127.0324], "성동구": [37.5633, 127.0371],
            "성북구": [37.5894, 127.0167], "송파구": [37.5145, 127.1060],
            "양천구": [37.5170, 126.8665], "영등포구": [37.5264, 126.8963],
            "용산구": [37.5326, 126.9900], "은평구": [37.6027, 126.9291],
            "종로구": [37.5735, 126.9790], "중구": [37.5641, 126.9979],
            "중랑구": [37.6063, 127.0928]
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
# PAGE 4: PREMIUM SIMULATOR (with Waterfall Chart)
# ============================================================
elif page == "Premium Simulator":
    st.title("Premium Simulator")
    st.caption("District & household-based premium calculation with cost breakdown")
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
    risk_adj = base * asset_factor * (r_score / 200)
    if credit_score >= 800:
        credit_mult = 0.90
    elif credit_score >= 700:
        credit_mult = 0.95
    else:
        credit_mult = 1.05
    pre_credit = base * asset_factor + risk_adj
    credit_adj = pre_credit * (credit_mult - 1)
    final = round(pre_credit + credit_adj, 0)

    st.markdown("---")
    c1,c2,c3,c4 = st.columns(4)
    c1.metric("Base Premium", "W{:,.0f}".format(base))
    c2.metric("Risk Grade", r_grade)
    c3.metric("Risk Score", "{:.1f}".format(r_score))
    delta_val = "{:+.1f}%".format(((final/base)-1)*100) if base > 0 else None
    c4.metric("Final Premium", "W{:,.0f}/mo".format(final), delta=delta_val)

    st.markdown("---")
    st.subheader("Premium Calculation Waterfall")
    base_adj = round(base * asset_factor, 0)
    waterfall_fig = go.Figure(go.Waterfall(
        name="Premium Breakdown",
        orientation="v",
        measure=["absolute", "relative", "relative", "total"],
        x=["Base Premium", "Risk Adj (+" + "{:.1f}".format(r_score) + ")",
           "Credit Adj (" + "{:.0f}".format(credit_score) + ")",
           "Final Premium"],
        y=[base_adj, round(risk_adj, 0), round(credit_adj, 0), 0],
        text=["W{:,.0f}".format(base_adj),
              "+W{:,.0f}".format(round(risk_adj, 0)),
              "W{:,.0f}".format(round(credit_adj, 0)),
              "W{:,.0f}".format(final)],
        textposition="outside",
        connector={"line": {"color": "#95a5a6"}},
        increasing={"marker": {"color": "#e74c3c"}},
        decreasing={"marker": {"color": "#27ae60"}},
        totals={"marker": {"color": "#3498db"}}
    ))
    waterfall_fig.update_layout(height=400, title="How Your Premium Is Calculated",
                                 showlegend=False, yaxis_title="Monthly Premium (KRW)")
    st.plotly_chart(waterfall_fig, use_container_width=True)

    st.info(str(sel_gu) + " | " + str(sel_seg) + " | Asset " + "{:,}".format(asset_val) + "0K KRW -> Monthly W" + "{:,.0f}".format(final))

# ============================================================
# PAGE 5: FEEDBACK
# ============================================================
elif page == "Feedback":
    st.title("User Feedback")
    st.caption("Help us improve INSURE with your feedback")

    with st.form("feedback_form"):
        user_type = st.selectbox("Your Role", ["Insurance Professional", "Data Analyst", "General User", "Evaluator", "Other"])
        try:
            gu_opts = session.sql("SELECT DISTINCT GU_NAME FROM INSURE_DB.MART.MART_DISTRICT_INSURANCE_SUMMARY WHERE GU_NAME IS NOT NULL ORDER BY GU_NAME").to_pandas()["GU_NAME"].tolist()
        except:
            gu_opts = ["N/A"]
        district = st.selectbox("District of Interest", ["All"] + gu_opts)
        st.markdown("**Rate the following (1=Poor, 5=Excellent):**")
        c1,c2 = st.columns(2)
        risk_accuracy = c1.slider("Risk Score Accuracy", 1, 5, 3)
        premium_fairness = c2.slider("Premium Fairness", 1, 5, 3)
        data_quality = c1.slider("Data Quality", 1, 5, 3)
        overall = c2.slider("Overall Satisfaction", 1, 5, 3)
        comments = st.text_area("Comments (optional)")
        suggestions = st.text_area("Improvement Suggestions (optional)")
        submitted = st.form_submit_button("Submit Feedback")
        if submitted:
            try:
                session.sql(
                    "INSERT INTO INSURE_DB.FEEDBACK.FEEDBACK_RESPONSES "
                    "(USER_TYPE, DISTRICT, RISK_SCORE_ACCURACY, PREMIUM_FAIRNESS, "
                    "DATA_QUALITY, OVERALL_SATISFACTION, COMMENTS, IMPROVEMENT_SUGGESTIONS) "
                    "VALUES ("
                    + chr(39) + str(user_type) + chr(39) + ","
                    + chr(39) + str(district) + chr(39) + ","
                    + str(risk_accuracy) + "," + str(premium_fairness) + ","
                    + str(data_quality) + "," + str(overall) + ","
                    + chr(39) + str(comments).replace(chr(39), chr(39)+chr(39)) + chr(39) + ","
                    + chr(39) + str(suggestions).replace(chr(39), chr(39)+chr(39)) + chr(39)
                    + ")"
                ).collect()
                st.success("Thank you for your feedback!")
            except Exception as e:
                st.error("Submission error: " + str(e))

    st.markdown("---")
    st.subheader("Feedback Summary")
    try:
        fb = session.sql("SELECT * FROM INSURE_DB.FEEDBACK.FEEDBACK_RESPONSES ORDER BY SUBMITTED_AT DESC LIMIT 20").to_pandas()
        if not fb.empty:
            avg_scores = fb[["RISK_SCORE_ACCURACY","PREMIUM_FAIRNESS","DATA_QUALITY","OVERALL_SATISFACTION"]].mean()
            c1,c2,c3,c4 = st.columns(4)
            c1.metric("Risk Accuracy", "{:.1f}/5".format(avg_scores["RISK_SCORE_ACCURACY"]))
            c2.metric("Premium Fairness", "{:.1f}/5".format(avg_scores["PREMIUM_FAIRNESS"]))
            c3.metric("Data Quality", "{:.1f}/5".format(avg_scores["DATA_QUALITY"]))
            c4.metric("Overall", "{:.1f}/5".format(avg_scores["OVERALL_SATISFACTION"]))
            st.dataframe(fb[["SUBMITTED_AT","USER_TYPE","DISTRICT","OVERALL_SATISFACTION","COMMENTS"]].head(10), use_container_width=True)
        else:
            st.info("No feedback submitted yet. Be the first!")
    except:
        st.info("Feedback table will be available after first submission")
