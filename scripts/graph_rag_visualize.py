# -*- coding: utf-8 -*-
"""
Graph RAG 시각화 스크립트
- 21_GRAPH_RAG_SYSTEM.sql의 노드/엣지를 네트워크 그래프로 시각화
- 출력: graph_rag_map.png (데모/발표용)
- 사용법: python graph_rag_visualize.py
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import networkx as nx
import platform
import os

# ── 한글 폰트 설정 ──
FONT_PROP = None

def setup_korean_font():
    global FONT_PROP
    system = platform.system()
    candidates = []
    if system == "Windows":
        candidates = [
            "C:/Windows/Fonts/malgun.ttf",
            "C:/Windows/Fonts/NanumGothic.ttf",
        ]
    elif system == "Darwin":
        candidates = [
            "/System/Library/Fonts/AppleSDGothicNeo.ttc",
            "/Library/Fonts/NanumGothic.ttf",
        ]
    else:
        candidates = [
            "/usr/share/fonts/truetype/nanum/NanumGothic.ttf",
        ]

    for fp in candidates:
        if os.path.exists(fp):
            FONT_PROP = fm.FontProperties(fname=fp, size=10)
            # Clear font cache and force reload
            fm.fontManager.addfont(fp)
            font_name = fm.FontProperties(fname=fp).get_name()
            matplotlib.rcParams["font.family"] = "sans-serif"
            matplotlib.rcParams["font.sans-serif"] = [font_name, "DejaVu Sans"]
            matplotlib.rcParams["axes.unicode_minus"] = False
            return

    FONT_PROP = fm.FontProperties(size=10)
    matplotlib.rcParams["axes.unicode_minus"] = False

setup_korean_font()


# ── 노드 데이터 ──
NODES = {
    # CLAUSE (14)
    "CL_01": ("CL01\nPurpose",          "CLAUSE"),
    "CL_02": ("CL02\nCoverage",         "CLAUSE"),
    "CL_03": ("CL03\nClaim Calc",       "CLAUSE"),
    "CL_04": ("CL04\nRisk Eval",        "CLAUSE"),
    "CL_05": ("CL05\nExclusions",       "CLAUSE"),
    "CL_06": ("CL06\nPremium Calc",     "CLAUSE"),
    "CL_07": ("CL07\nPremium Adj",      "CLAUSE"),
    "CL_08": ("CL08\nContract",         "CLAUSE"),
    "CL_09": ("CL09\nRefund",           "CLAUSE"),
    "CL_10": ("CL10\nRenewal",          "CLAUSE"),
    "CL_11": ("CL11\nNotification",     "CLAUSE"),
    "CL_12": ("CL12\nItem Limits",      "CLAUSE"),
    "CL_13": ("CL13\nDispute",          "CLAUSE"),
    "CL_14": ("CL14\nJurisdiction",     "CLAUSE"),
    # DATA (11)
    "DT_01": ("DT01\nInsurance\nSummary",  "DATA"),
    "DT_02": ("DT02\nRisk\nScore",         "DATA"),
    "DT_03": ("DT03\nHousehold\nGoods",    "DATA"),
    "DT_04": ("DT04\nFire\nStats",         "DATA"),
    "DT_05": ("DT05\nCrime\nStats",        "DATA"),
    "DT_06": ("DT06\nBuilding\nAge",       "DATA"),
    "DT_07": ("DT07\nWeather\nRisk",       "DATA"),
    "DT_08": ("DT08\nPremium\nLayer",      "DATA"),
    "DT_09": ("DT09\nRAG\nChunks",        "DATA"),
    "DT_10": ("DT10\nFire\nForecast",     "DATA"),
    "DT_11": ("DT11\nPersona\nSegments",  "DATA"),
    # RULE (4)
    "RL_01": ("RL01\n5-Tier Risk\nCurve",       "RULE"),
    "RL_02": ("RL02\n7-Stage\nPipeline",        "RULE"),
    "RL_03": ("RL03\nCredibility\nZ-factor",    "RULE"),
    "RL_04": ("RL04\nAffordability\nCap 0.5%",  "RULE"),
    # MODEL (2)
    "ML_01": ("ML01\nCortex ML\nFORECAST",  "MODEL"),
    "ML_02": ("ML02\nCortex Agent\nADVISOR", "MODEL"),
}

# ── 엣지 데이터 (34개) ──
EDGES = [
    ("CL_02", "DT_01", "REFERENCES",  0.9),
    ("CL_02", "DT_03", "REFERENCES",  0.8),
    ("CL_04", "DT_02", "REFERENCES",  0.9),
    ("CL_04", "DT_04", "REFERENCES",  0.7),
    ("CL_04", "DT_05", "REFERENCES",  0.7),
    ("CL_04", "DT_06", "REFERENCES",  0.6),
    ("CL_04", "DT_07", "REFERENCES",  0.6),
    ("CL_07", "DT_08", "REFERENCES",  0.8),
    ("CL_12", "DT_03", "REFERENCES",  0.9),
    ("CL_03", "RL_02", "LIMITS",      1.0),
    ("CL_06", "RL_01", "LIMITS",      1.0),
    ("RL_01", "DT_02", "CALCULATES",  0.9),
    ("RL_02", "DT_01", "APPLIES",     1.0),
    ("RL_02", "DT_08", "APPLIES",     0.9),
    ("RL_03", "DT_01", "CALCULATES",  0.7),
    ("RL_04", "DT_11", "CALCULATES",  0.6),
    ("ML_01", "DT_10", "PREDICTS",    0.9),
    ("ML_01", "DT_04", "CALCULATES",  0.8),
    ("ML_02", "DT_09", "CALCULATES",  0.8),
    ("ML_02", "DT_01", "CALCULATES",  0.9),
    ("CL_02", "CL_12", "COVERS",      0.7),
    ("CL_03", "CL_06", "COVERS",      0.8),
    ("CL_02", "CL_04", "COVERS",      0.7),
    ("CL_03", "DT_08", "REFERENCES",  0.6),
    ("CL_06", "DT_02", "REFERENCES",  0.85),
    ("RL_02", "DT_02", "APPLIES",     0.8),
    ("CL_04", "DT_10", "REFERENCES",  0.5),
    ("ML_01", "DT_06", "CALCULATES",  0.7),
    ("ML_01", "DT_07", "CALCULATES",  0.7),
    ("ML_02", "DT_02", "CALCULATES",  0.7),
    ("CL_07", "RL_03", "LIMITS",      0.8),
    ("CL_06", "RL_04", "LIMITS",      0.8),
    ("CL_05", "DT_02", "REFERENCES",  0.5),
    ("RL_01", "DT_08", "APPLIES",     0.85),
]

# ── 스타일 설정 ──
NODE_STYLES = {
    "CLAUSE": {"color": "#4A90D9", "size": 900,  "shape": "o"},
    "DATA":   {"color": "#50C878", "size": 700,  "shape": "s"},
    "RULE":   {"color": "#FF8C42", "size": 800,  "shape": "D"},
    "MODEL":  {"color": "#E74C3C", "size": 800,  "shape": "^"},
}

EDGE_COLORS = {
    "REFERENCES": "#888888",
    "CALCULATES": "#2196F3",
    "APPLIES":    "#4CAF50",
    "LIMITS":     "#FF5722",
    "COVERS":     "#9C27B0",
    "PREDICTS":   "#FF9800",
}


def build_graph():
    G = nx.DiGraph()
    for nid, (label, ntype) in NODES.items():
        G.add_node(nid, label=label, node_type=ntype)
    for src, tgt, etype, w in EDGES:
        G.add_edge(src, tgt, edge_type=etype, weight=w)
    return G


def draw_graph(G):
    fig, ax = plt.subplots(1, 1, figsize=(22, 16))
    fig.patch.set_facecolor("#FAFAFA")
    ax.set_facecolor("#FAFAFA")

    # 레이아웃: 연결 많은 노드를 중심에
    pos = nx.spring_layout(G, k=2.8, iterations=80, seed=42, weight="weight")

    # 노드 타입별로 그리기
    for ntype, style in NODE_STYLES.items():
        nodelist = [n for n, d in G.nodes(data=True) if d["node_type"] == ntype]
        nx.draw_networkx_nodes(
            G, pos, nodelist=nodelist, ax=ax,
            node_color=style["color"],
            node_size=style["size"],
            node_shape=style["shape"],
            alpha=0.9,
            edgecolors="white",
            linewidths=2,
        )

    # 엣지 타입별로 그리기
    for etype, color in EDGE_COLORS.items():
        edgelist = [(u, v) for u, v, d in G.edges(data=True) if d["edge_type"] == etype]
        weights = [G[u][v]["weight"] for u, v in edgelist]
        widths = [w * 2.5 for w in weights]
        nx.draw_networkx_edges(
            G, pos, edgelist=edgelist, ax=ax,
            edge_color=color,
            width=widths,
            alpha=0.6,
            arrows=True,
            arrowsize=15,
            arrowstyle="-|>",
            connectionstyle="arc3,rad=0.1",
        )

    # 라벨 (직접 그려서 한글 폰트 적용)
    labels = {nid: d["label"] for nid, d in G.nodes(data=True)}
    for nid, (x, y) in pos.items():
        ax.text(x, y, labels[nid], fontsize=7, fontweight="bold",
                ha="center", va="center", fontproperties=FONT_PROP)

    # 범례
    legend_items = []
    for ntype, style in NODE_STYLES.items():
        legend_items.append(
            plt.scatter([], [], c=style["color"], s=120,
                       marker=style["shape"], label=f"{ntype} ({sum(1 for _,d in G.nodes(data=True) if d['node_type']==ntype)})")
        )
    for etype, color in EDGE_COLORS.items():
        cnt = sum(1 for _,_,d in G.edges(data=True) if d["edge_type"] == etype)
        legend_items.append(
            plt.plot([], [], color=color, linewidth=2, label=f"{etype} ({cnt})")[0]
        )
    ax.legend(handles=legend_items, loc="upper left", fontsize=9,
             framealpha=0.9, edgecolor="#CCCCCC", title="Graph RAG Components",
             title_fontsize=10, prop=FONT_PROP)

    ax.set_title("INSURE Graph RAG - Node & Edge Map\n"
                 "31 Nodes (14 Clause + 11 Data + 4 Rule + 2 Model)  |  34 Edges (6 Types)",
                 fontsize=14, fontweight="bold", pad=20, fontproperties=FONT_PROP)
    ax.axis("off")

    out_path = os.path.join(os.path.dirname(__file__), "graph_rag_map.png")
    fig.savefig(out_path, dpi=200, bbox_inches="tight", facecolor="#FAFAFA")
    plt.close(fig)
    print(f"[OK] Saved: {out_path}")
    return out_path


def print_stats(G):
    print("=" * 50)
    print("  Graph RAG Stats")
    print("=" * 50)
    print(f"  Nodes: {G.number_of_nodes()}")
    print(f"  Edges: {G.number_of_edges()}")
    print(f"  Density: {nx.density(G):.4f}")

    # 허브 노드 (연결 많은 TOP 5)
    degree = sorted(G.degree(), key=lambda x: x[1], reverse=True)[:5]
    print("\n  Hub nodes (TOP 5):")
    for nid, deg in degree:
        print(f"    {nid} ({NODES[nid][0].replace(chr(10),' ')}) -{deg} connections")


if __name__ == "__main__":
    G = build_graph()
    print_stats(G)
    draw_graph(G)
