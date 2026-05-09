"""
PULSE Recommendation Dashboard
================================
Reads all experiment result files from experiments/results/ and renders
interactive charts for NDCG, latency, per-query breakdown, and run comparison.

Run:
  streamlit run scripts/dashboard.py
"""

import json
from pathlib import Path
from datetime import datetime

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import streamlit as st

# ── Config ─────────────────────────────────────────────────────────────────────

REPO_ROOT  = Path(__file__).resolve().parent.parent
RESULTS    = REPO_ROOT / "experiments" / "results"
LOG_DIR    = REPO_ROOT / "experiments" / "logs" / "places"

PALETTE = {
    "server":  "#6C63FF",
    "client":  "#00C9A7",
    "random":  "#AAAAAA",
    "rating":  "#FF6584",
    "reviews": "#FFC75F",
    "gemini":  "#4285F4",
    "local":   "#34A853",
}

# Signal weights for advanced eval display (mirrors discover_world_controller.dart)
WEIGHTS_DISPLAY = {
    "rating":          0.24,
    "reviews":         0.12,
    "isOpen":          0.14,
    "saved":           0.14,
    "preferredCat":    0.11,
    "preferredTags":   0.08,
    "queryAffinity":   0.14,
    "distance":        0.07,
    "networkAffinity": 0.06,
}

st.set_page_config(
    page_title="PULSE · Rec Dashboard",
    page_icon="📍",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Helpers ────────────────────────────────────────────────────────────────────

def load_results() -> dict[str, dict]:
    files = sorted(RESULTS.glob("*.json"))
    loaded = {}
    for f in files:
        try:
            data = json.loads(f.read_text())
            loaded[f.stem] = data
        except Exception:
            pass
    return loaded

def result_label(key: str, data: dict) -> str:
    ts = data.get("run_id", key)[:15]
    provider = data.get("provider", "?")
    source = data.get("source", "places" if "server_order" in data else "yelp_academic")
    return f"{ts}  [{source}·{provider}]"

def ts_to_dt(run_id: str) -> datetime:
    try:
        return datetime.strptime(run_id[:15], "%Y%m%dT%H%M%S")
    except Exception:
        return datetime.min

# ── Sidebar ────────────────────────────────────────────────────────────────────

st.sidebar.title("📍 PULSE Rec Dashboard")
st.sidebar.markdown("---")

all_results = load_results()

if not all_results:
    st.warning("No result files found in `experiments/results/`. Run an experiment first:")
    st.code("python scripts/experiment_places.py --base-url https://pulse-production-62b2.up.railway.app")
    st.stop()

keys_sorted = sorted(all_results.keys(), key=lambda k: ts_to_dt(all_results[k].get("run_id", "")), reverse=True)
labels      = {k: result_label(k, all_results[k]) for k in keys_sorted}

view = st.sidebar.radio(
    "View",
    ["A/B/C Analysis", "Advanced Eval", "Single run", "Compare runs", "All runs timeline", "Raw logs"],
)

# Filter out advanced_eval files from run-picker views
run_keys_sorted = [k for k in keys_sorted if all_results[k].get("source") != "advanced_eval"]

if view in ("Single run", "Raw logs"):
    selected_key = st.sidebar.selectbox("Run", run_keys_sorted, format_func=lambda k: labels[k])
    selected     = all_results[selected_key]

elif view in ("A/B/C Analysis", "Advanced Eval"):
    pass  # no sidebar controls needed

elif view == "Compare runs":
    col1, col2 = st.sidebar.columns(2)
    key_a = col1.selectbox("Run A", run_keys_sorted, format_func=lambda k: labels[k])
    key_b = col2.selectbox("Run B", run_keys_sorted,
                            index=min(1, len(run_keys_sorted) - 1),
                            format_func=lambda k: labels[k])
    run_a, run_b = all_results[key_a], all_results[key_b]

st.sidebar.markdown("---")
st.sidebar.caption(f"{len(all_results)} result file(s) loaded")

# ── View: A/B/C Analysis ─────────────────────────────────────────────────────

if view == "A/B/C Analysis":
    st.title("🔬 A/B/C Condition Analysis")
    st.caption(
        "Three retrieval conditions compared: "
        "**A** = rule-based mock (4 Shanghai venues)  ·  "
        "**B** = Google Places live (Railway)  ·  "
        "**C** = fixture cache (249 real NYC venues, no API key required)"
    )

    # Identify runs by server URL heuristic
    cond_keys: dict[str, str | None] = {"A": None, "B": None, "C": None}
    for k, v in all_results.items():
        url = v.get("server_url", "")
        n   = v.get("successful_queries", v.get("query_count", 0))
        if "server_order" not in v:
            continue
        if "localhost" in url or "8788" in url:
            # Condition A has low successful_queries, C has high
            if n is not None and int(n) < 12:
                cond_keys["A"] = k
            else:
                cond_keys["C"] = k
        elif "railway" in url or "up.railway" in url:
            cond_keys["B"] = k

    missing = [c for c, k in cond_keys.items() if k is None]
    if missing:
        st.warning(
            f"Could not auto-detect condition(s): **{', '.join(missing)}**. "
            "Run the missing experiments or select manually below."
        )
        for c in missing:
            picked = st.selectbox(f"Select run for Condition {c}", keys_sorted,
                                   format_func=lambda k: labels[k], key=f"cond_{c}")
            cond_keys[c] = picked

    # Build comparison table
    def cond_data(key):
        if key is None:
            return None
        return all_results.get(key)

    dA, dB, dC = cond_data(cond_keys["A"]), cond_data(cond_keys["B"]), cond_data(cond_keys["C"])

    def fmt(d, path, fmt_str="{:.4f}"):
        if d is None:
            return "—"
        parts = path.split(".")
        v = d
        for p in parts:
            v = v.get(p, None) if isinstance(v, dict) else None
            if v is None:
                return "—"
        try:
            return fmt_str.format(v)
        except Exception:
            return str(v)

    cov_A = f"{dA['successful_queries']}/15 ({int(dA['successful_queries']/15*100)}%)" if dA else "—"
    cov_B = f"{dB['successful_queries']}/15 ({int(dB['successful_queries']/15*100)}%)" if dB else "—"
    cov_C = f"{dC['successful_queries']}/15 ({int(dC['successful_queries']/15*100)}%)" if dC else "—"

    comparison = {
        "Metric": [
            "Query coverage",
            "NDCG@5 (server order)",
            "NDCG@5 (client re-rank)",
            "Precision@3 (server)",
            "Category match rate",
            "Avg latency (ms)",
            "API key required",
            "Reproducible",
            "Unique venues",
        ],
        "A — Mock": [
            cov_A,
            fmt(dA, "server_order.avg_ndcg5"),
            fmt(dA, "client_rerank.avg_ndcg5"),
            fmt(dA, "server_order.avg_p3"),
            fmt(dA, "server_order.avg_cmr"),
            fmt(dA, "avg_latency_ms", "{:.0f} ms"),
            "No",
            "Yes (4 fixed)",
            "4",
        ],
        "B — Google Places": [
            cov_B,
            fmt(dB, "server_order.avg_ndcg5"),
            fmt(dB, "client_rerank.avg_ndcg5"),
            fmt(dB, "server_order.avg_p3"),
            fmt(dB, "server_order.avg_cmr"),
            fmt(dB, "avg_latency_ms", "{:.0f} ms"),
            "Yes",
            "No (live)",
            "~150 / run",
        ],
        "C — Fixture Cache": [
            cov_C,
            fmt(dC, "server_order.avg_ndcg5") + " *",
            fmt(dC, "client_rerank.avg_ndcg5") + " *",
            fmt(dC, "server_order.avg_p3") + " *",
            fmt(dC, "server_order.avg_cmr") + " *",
            fmt(dC, "avg_latency_ms", "{:.0f} ms"),
            "No",
            "Yes (249 fixed)",
            "249",
        ],
    }

    df_cmp = pd.DataFrame(comparison)
    st.markdown("### Summary comparison")
    st.dataframe(df_cmp.set_index("Metric"), use_container_width=True)
    st.caption("\\* Condition C NDCG@5 = 1.0 is inflated by construction — "
               "corpus was originally sourced from Google Places so category labels align perfectly. "
               "Operational value: 15/15 coverage, key-free, reproducible.")

    st.markdown("---")
    st.markdown("### NDCG@5 — server order vs client re-rank")

    cond_labels = []
    ndcg_server = []
    ndcg_client = []
    colors_bar  = ["#AAAAAA", "#6C63FF", "#00C9A7"]
    for label, d in [("A — Mock", dA), ("B — Places", dB), ("C — Fixture", dC)]:
        cond_labels.append(label)
        ndcg_server.append(d["server_order"]["avg_ndcg5"] if d else 0)
        ndcg_client.append(d["client_rerank"]["avg_ndcg5"] if d else 0)

    fig_ab = go.Figure()
    fig_ab.add_bar(name="Server order",    x=cond_labels, y=ndcg_server,
                   marker_color=["#AAAAAA", "#4444CC", "#007A6E"], opacity=0.75)
    fig_ab.add_bar(name="Client re-rank",  x=cond_labels, y=ndcg_client,
                   marker_color=["#888888", "#6C63FF", "#00C9A7"], opacity=0.9)
    fig_ab.update_layout(
        barmode="group", height=380,
        yaxis=dict(title="NDCG@5", range=[0, 1.08]),
        legend=dict(orientation="h", y=1.02),
        margin=dict(t=30),
    )
    st.plotly_chart(fig_ab, use_container_width=True)

    # Per-query breakdown for B and C side by side
    if dB and dC:
        st.markdown("### Per-query NDCG@5 — Condition B vs Condition C (client re-rank)")
        qb = {r["id"]: r for r in dB.get("per_query", [])}
        qc = {r["id"]: r for r in dC.get("per_query", [])}
        common_q = sorted(set(qb) & set(qc))
        if common_q:
            rows_pq = []
            for qid in common_q:
                rb, rc = qb[qid], qc[qid]
                rows_pq.append({
                    "Query":      f"{qid} · {rb['text'][:30]}",
                    "B client":   rb["client_ndcg5"],
                    "C client":   rc["client_ndcg5"],
                    "B latency":  rb["latency_ms"],
                    "C latency":  rc["latency_ms"],
                })
            df_pq = pd.DataFrame(rows_pq)

            fig_pq = go.Figure()
            fig_pq.add_bar(name="B — Google Places", x=df_pq["Query"], y=df_pq["B client"],
                           marker_color="#6C63FF", opacity=0.85)
            fig_pq.add_bar(name="C — Fixture Cache", x=df_pq["Query"], y=df_pq["C client"],
                           marker_color="#00C9A7", opacity=0.85)
            fig_pq.update_layout(
                barmode="group", height=420,
                yaxis=dict(title="NDCG@5 (client re-rank)", range=[0, 1.08]),
                xaxis_tickangle=-35, margin=dict(b=140),
                legend=dict(orientation="h", y=1.02),
            )
            st.plotly_chart(fig_pq, use_container_width=True)

            col_l, col_r = st.columns(2)
            with col_l:
                st.markdown("### Latency — Condition B")
                fig_lat_b = px.bar(df_pq, x="Query", y="B latency",
                                   color_discrete_sequence=["#6C63FF"])
                avg_b = dB.get("avg_latency_ms", 0)
                fig_lat_b.add_hline(y=avg_b, line_dash="dash", line_color="white",
                                    annotation_text=f"avg {avg_b:.0f} ms")
                fig_lat_b.update_layout(height=320, xaxis_tickangle=-35, margin=dict(b=140, t=20))
                st.plotly_chart(fig_lat_b, use_container_width=True)
            with col_r:
                st.markdown("### Latency — Condition C")
                fig_lat_c = px.bar(df_pq, x="Query", y="C latency",
                                   color_discrete_sequence=["#00C9A7"])
                avg_c = dC.get("avg_latency_ms", 0)
                fig_lat_c.add_hline(y=avg_c, line_dash="dash", line_color="white",
                                    annotation_text=f"avg {avg_c:.0f} ms")
                fig_lat_c.update_layout(height=320, xaxis_tickangle=-35, margin=dict(b=140, t=20))
                st.plotly_chart(fig_lat_c, use_container_width=True)

            st.markdown("### Data table — per-query detail")
            st.dataframe(
                df_pq.style.background_gradient(
                    subset=["B client", "C client"], cmap="RdYlGn", vmin=0, vmax=1
                ),
                use_container_width=True,
            )

    # ── Yelp Fusion comparison ────────────────────────────────────────────────
    yelp_fusion_runs = {k: v for k, v in all_results.items()
                        if v.get("source") == "yelp_fusion" and "server_order" in v}
    if yelp_fusion_runs:
        st.markdown("---")
        st.markdown("### Yelp Fusion — side-by-side with Condition B (Google Places)")

        yk = sorted(yelp_fusion_runs, key=lambda k: ts_to_dt(yelp_fusion_runs[k].get("run_id", "")))[-1]
        dY = yelp_fusion_runs[yk]

        y_labels  = ["B — Google Places", "Yelp Fusion"]
        y_server  = [dB["server_order"]["avg_ndcg5"] if dB else 0, dY["server_order"]["avg_ndcg5"]]
        y_client  = [dB["client_rerank"]["avg_ndcg5"] if dB else 0, dY["client_rerank"]["avg_ndcg5"]]

        fig_yf = go.Figure()
        fig_yf.add_bar(name="Server order",   x=y_labels, y=y_server,
                       marker_color=["#4444CC", "#E47B00"], opacity=0.75)
        fig_yf.add_bar(name="Client re-rank", x=y_labels, y=y_client,
                       marker_color=["#6C63FF", "#FFA500"], opacity=0.9)
        fig_yf.update_layout(
            barmode="group", height=340,
            yaxis=dict(title="NDCG@5", range=[0, 1.08]),
            legend=dict(orientation="h", y=1.02),
            margin=dict(t=30),
        )
        st.plotly_chart(fig_yf, use_container_width=True)

        # Summary diff table
        def ydiff(sk):
            sv = dB["server_order"][sk] if dB else 0
            yv = dY["server_order"][sk]
            return {"Metric": sk, "Google Places": sv, "Yelp Fusion": yv, "Delta (Yelp-Places)": round(yv-sv, 4)}

        df_ydiff = pd.DataFrame([
            ydiff("avg_ndcg5"), ydiff("avg_p3"), ydiff("avg_cmr"),
            {"Metric": "avg_latency_ms",
             "Google Places": dB.get("avg_latency_ms", 0) if dB else 0,
             "Yelp Fusion": dY.get("avg_latency_ms", 0),
             "Delta (Yelp-Places)": round(dY.get("avg_latency_ms", 0) - (dB.get("avg_latency_ms", 0) if dB else 0), 1)},
        ])
        st.dataframe(df_ydiff.style.background_gradient(
            subset=["Delta (Yelp-Places)"], cmap="RdYlGn", vmin=-0.1, vmax=0.1),
            use_container_width=True)

        st.caption(f"Yelp Fusion run: `{yk}` — "
                   f"{dY.get('successful_queries', '?')}/{dY.get('query_count', '?')} queries, "
                   f"avg {dY.get('avg_latency_ms', 0):.0f} ms")

    st.markdown("---")
    st.markdown(
        "**Run IDs** — "
        f"A: `{cond_keys['A'] or 'not found'}`  ·  "
        f"B: `{cond_keys['B'] or 'not found'}`  ·  "
        f"C: `{cond_keys['C'] or 'not found'}`"
    )


# ── View: Single run ──────────────────────────────────────────────────────────

if view == "Single run":
    is_places = "server_order" in selected
    is_yelp   = "summary" in selected and "random" in selected.get("summary", {})

    run_id   = selected.get("run_id", selected_key)
    provider = selected.get("provider", "local")
    ts       = selected.get("timestamp", "")[:19]

    st.title("📍 Run Detail")
    m1, m2, m3, m4 = st.columns(4)
    m1.metric("Run ID", run_id[:15])
    m2.metric("Provider", provider)
    m3.metric("Queries", selected.get("query_count", "—"))
    m4.metric("Timestamp", ts)

    # ── Places result ──
    if is_places:
        server  = selected["server_order"]
        client  = selected["client_rerank"]
        latency = selected.get("avg_latency_ms", 0)

        st.markdown("---")
        c1, c2, c3, c4, c5 = st.columns(5)
        c1.metric("Server NDCG@5",   f"{server['avg_ndcg5']:.4f}")
        c2.metric("Client NDCG@5",   f"{client['avg_ndcg5']:.4f}",
                  delta=f"{client['avg_ndcg5']-server['avg_ndcg5']:+.4f}")
        c3.metric("Server P@3",      f"{server['avg_p3']:.4f}")
        c4.metric("Client P@3",      f"{client['avg_p3']:.4f}",
                  delta=f"{client['avg_p3']-server['avg_p3']:+.4f}")
        c5.metric("Avg latency",     f"{latency:.0f} ms")

        st.markdown("### Per-query NDCG@5")
        per_q = selected.get("per_query", [])
        df = pd.DataFrame([{
            "Query":       f"{r['id']} · {r['text'][:35]}",
            "Server":      r["server_ndcg5"],
            "Client":      r["client_ndcg5"],
            "Delta":       r["ndcg_delta"],
            "Latency (ms)":r["latency_ms"],
            "Results":     r["result_count"],
        } for r in per_q])

        fig = go.Figure()
        fig.add_bar(name="Server order", x=df["Query"], y=df["Server"],
                    marker_color=PALETTE["server"], opacity=0.8)
        fig.add_bar(name="Client re-rank", x=df["Query"], y=df["Client"],
                    marker_color=PALETTE["client"], opacity=0.8)
        fig.update_layout(
            barmode="group", height=420,
            yaxis=dict(title="NDCG@5", range=[0, 1.05]),
            xaxis=dict(tickangle=-35),
            legend=dict(orientation="h", yanchor="bottom", y=1.02),
            margin=dict(t=40, b=120),
        )
        st.plotly_chart(fig, use_container_width=True)

        col_l, col_r = st.columns(2)

        with col_l:
            st.markdown("### NDCG Delta (Client − Server)")
            df_sorted = df.sort_values("Delta")
            color_vals = ["#FF6584" if v < 0 else "#00C9A7" for v in df_sorted["Delta"]]
            fig2 = go.Figure(go.Bar(
                x=df_sorted["Delta"], y=df_sorted["Query"],
                orientation="h", marker_color=color_vals,
            ))
            fig2.update_layout(
                height=420, xaxis_title="Delta NDCG@5",
                shapes=[dict(type="line", x0=0, x1=0, y0=-0.5,
                             y1=len(df_sorted)-0.5,
                             line=dict(color="white", width=1, dash="dot"))],
                margin=dict(l=220, t=20),
            )
            st.plotly_chart(fig2, use_container_width=True)

        with col_r:
            st.markdown("### Latency per query (ms)")
            fig3 = px.bar(df, x="Query", y="Latency (ms)",
                          color_discrete_sequence=[PALETTE["server"]])
            fig3.add_hline(y=latency, line_dash="dash", line_color="white",
                           annotation_text=f"avg {latency:.0f} ms")
            fig3.update_layout(height=420, xaxis_tickangle=-35,
                                margin=dict(t=20, b=120))
            st.plotly_chart(fig3, use_container_width=True)

        st.markdown("### Data table")
        st.dataframe(df.style.background_gradient(subset=["Server", "Client"],
                                                   cmap="RdYlGn", vmin=0, vmax=1)
                              .background_gradient(subset=["Delta"],
                                                   cmap="RdYlGn", vmin=-0.2, vmax=0.2),
                     use_container_width=True)

    # ── Yelp result ──
    elif is_yelp:
        summary = selected["summary"]
        city    = selected.get("city", "?")
        ds_size = selected.get("dataset_size", "?")

        st.markdown("---")
        st.markdown(f"**City:** {city} &nbsp;·&nbsp; **Dataset size:** {ds_size:,} businesses")

        rankers = ["random", "rating", "reviews", "client"]
        labels_r = ["Random", "Rating-sort", "Review-sort", "Client scorer"]
        colors   = [PALETTE["random"], PALETTE["rating"], PALETTE["reviews"], PALETTE["client"]]

        c_ndcg = [summary[r]["avg_ndcg5"] for r in rankers]
        c_p3   = [summary[r]["avg_p3"]    for r in rankers]

        col1, col2 = st.columns(2)
        with col1:
            st.markdown("### NDCG@5 by ranker")
            fig = go.Figure(go.Bar(x=labels_r, y=c_ndcg, marker_color=colors))
            fig.update_layout(yaxis=dict(title="NDCG@5", range=[0, 1.05]),
                               height=320, margin=dict(t=20))
            st.plotly_chart(fig, use_container_width=True)
        with col2:
            st.markdown("### Precision@3 by ranker")
            fig = go.Figure(go.Bar(x=labels_r, y=c_p3, marker_color=colors))
            fig.update_layout(yaxis=dict(title="Precision@3", range=[0, 1.05]),
                               height=320, margin=dict(t=20))
            st.plotly_chart(fig, use_container_width=True)

        per_q = selected.get("per_query", [])
        if per_q:
            st.markdown("### Per-query breakdown")
            df = pd.DataFrame([{
                "Query":         f"{r['qid']} · {r['text'][:35]}",
                "Random":        r["random_ndcg5"],
                "Rating-sort":   r["rating_ndcg5"],
                "Review-sort":   r["reviews_ndcg5"],
                "Client scorer": r["client_ndcg5"],
            } for r in per_q])

            fig = go.Figure()
            for col, color in zip(["Random", "Rating-sort", "Review-sort", "Client scorer"], colors):
                fig.add_bar(name=col, x=df["Query"], y=df[col], marker_color=color, opacity=0.85)
            fig.update_layout(barmode="group", height=420,
                               yaxis=dict(title="NDCG@5", range=[0, 1.05]),
                               xaxis_tickangle=-35, margin=dict(b=140),
                               legend=dict(orientation="h", y=1.02))
            st.plotly_chart(fig, use_container_width=True)

# ── View: Compare runs ─────────────────────────────────────────────────────────

elif view == "Compare runs":
    st.title("📊 Run Comparison")

    is_places = "server_order" in run_a and "server_order" in run_b

    if is_places:
        def row(label, va, vb):
            delta = vb - va
            return {"Metric": label, "Run A": va, "Run B": vb, "Delta (B−A)": round(delta, 4)}

        summary_rows = [
            row("Server NDCG@5",   run_a["server_order"]["avg_ndcg5"], run_b["server_order"]["avg_ndcg5"]),
            row("Client NDCG@5",   run_a["client_rerank"]["avg_ndcg5"], run_b["client_rerank"]["avg_ndcg5"]),
            row("Server P@3",      run_a["server_order"]["avg_p3"],    run_b["server_order"]["avg_p3"]),
            row("Client P@3",      run_a["client_rerank"]["avg_p3"],   run_b["client_rerank"]["avg_p3"]),
            row("Avg latency (ms)",run_a["avg_latency_ms"],            run_b["avg_latency_ms"]),
        ]
        df_sum = pd.DataFrame(summary_rows)
        st.markdown("### Summary")
        st.dataframe(df_sum.style.background_gradient(subset=["Delta (B−A)"],
                                                       cmap="RdYlGn", vmin=-0.1, vmax=0.1),
                     use_container_width=True)

        # Per-query NDCG diff
        qa_map = {r["id"]: r for r in run_a.get("per_query", [])}
        qb_map = {r["id"]: r for r in run_b.get("per_query", [])}
        common = sorted(set(qa_map) & set(qb_map))

        if common:
            rows = []
            for qid in common:
                ra, rb = qa_map[qid], qb_map[qid]
                rows.append({
                    "Query":      f"{qid} · {ra['text'][:35]}",
                    "A client":   ra["client_ndcg5"],
                    "B client":   rb["client_ndcg5"],
                    "Δ client":   round(rb["client_ndcg5"] - ra["client_ndcg5"], 4),
                    "A server":   ra["server_ndcg5"],
                    "B server":   rb["server_ndcg5"],
                    "Δ server":   round(rb["server_ndcg5"] - ra["server_ndcg5"], 4),
                })
            df_pq = pd.DataFrame(rows)

            st.markdown("### Per-query client NDCG@5 (A vs B)")
            fig = go.Figure()
            fig.add_bar(name=f"A [{labels[key_a]}]", x=df_pq["Query"],
                        y=df_pq["A client"], marker_color=PALETTE["server"], opacity=0.85)
            fig.add_bar(name=f"B [{labels[key_b]}]", x=df_pq["Query"],
                        y=df_pq["B client"], marker_color=PALETTE["client"], opacity=0.85)
            fig.update_layout(barmode="group", height=400,
                               yaxis=dict(title="NDCG@5", range=[0, 1.05]),
                               xaxis_tickangle=-35, margin=dict(b=140),
                               legend=dict(orientation="h", y=1.02))
            st.plotly_chart(fig, use_container_width=True)

            st.markdown("### Delta table (B − A)")
            st.dataframe(df_pq[["Query", "Δ client", "Δ server"]].style
                          .background_gradient(subset=["Δ client", "Δ server"],
                                               cmap="RdYlGn", vmin=-0.2, vmax=0.2),
                         use_container_width=True)
    else:
        st.info("Comparing two Yelp runs — summary metrics only.")
        if "summary" in run_a and "summary" in run_b:
            rankers = ["random", "rating", "reviews", "client"]
            rows = []
            for r in rankers:
                va = run_a["summary"].get(r, {}).get("avg_ndcg5", 0)
                vb = run_b["summary"].get(r, {}).get("avg_ndcg5", 0)
                rows.append({"Ranker": r, "A": va, "B": vb, "Δ": round(vb - va, 4)})
            st.dataframe(pd.DataFrame(rows), use_container_width=True)

# ── View: All runs timeline ────────────────────────────────────────────────────

elif view == "All runs timeline":
    st.title("📈 All Runs — Timeline")

    places_runs = {k: v for k, v in all_results.items()
                   if "server_order" in v and v.get("source", "places") == "places"}
    yelp_fusion_runs = {k: v for k, v in all_results.items()
                        if "server_order" in v and v.get("source") == "yelp_fusion"}
    yelp_runs   = {k: v for k, v in all_results.items() if "summary" in v and "random" in v.get("summary", {})}

    if places_runs:
        st.markdown("### Google Places runs")
        rows = []
        for k, v in sorted(places_runs.items(), key=lambda x: ts_to_dt(x[1].get("run_id", ""))):
            rows.append({
                "Run":          v.get("run_id", k)[:15],
                "Provider":     v.get("provider", "local"),
                "Server NDCG@5":v["server_order"]["avg_ndcg5"],
                "Client NDCG@5":v["client_rerank"]["avg_ndcg5"],
                "Avg Lat (ms)": v.get("avg_latency_ms", 0),
            })
        df = pd.DataFrame(rows)

        fig = go.Figure()
        fig.add_scatter(x=df["Run"], y=df["Server NDCG@5"], name="Server order",
                        mode="lines+markers", line_color=PALETTE["server"], line_width=2)
        fig.add_scatter(x=df["Run"], y=df["Client NDCG@5"], name="Client re-rank",
                        mode="lines+markers", line_color=PALETTE["client"], line_width=2)
        fig.update_layout(height=340, yaxis=dict(title="NDCG@5", range=[0, 1.05]),
                           legend=dict(orientation="h", y=1.02), margin=dict(t=30))
        st.plotly_chart(fig, use_container_width=True)

        fig2 = px.bar(df, x="Run", y="Avg Lat (ms)", color="Provider",
                      color_discrete_map={"local": PALETTE["local"], "gemini": PALETTE["gemini"]})
        fig2.update_layout(height=280, yaxis_title="Avg latency (ms)", margin=dict(t=20))
        st.plotly_chart(fig2, use_container_width=True)

        st.dataframe(df, use_container_width=True)

    if yelp_fusion_runs:
        st.markdown("### Yelp Fusion runs (live API)")
        rows_yf = []
        for k, v in sorted(yelp_fusion_runs.items(), key=lambda x: ts_to_dt(x[1].get("run_id", ""))):
            rows_yf.append({
                "Run":           v.get("run_id", k)[:15],
                "Server NDCG@5": v["server_order"]["avg_ndcg5"],
                "Client NDCG@5": v["client_rerank"]["avg_ndcg5"],
                "Avg Lat (ms)":  v.get("avg_latency_ms", 0),
                "Coverage":      f"{v.get('successful_queries','?')}/{v.get('query_count','?')}",
            })
        df_yf = pd.DataFrame(rows_yf)
        fig_yf = go.Figure()
        fig_yf.add_scatter(x=df_yf["Run"], y=df_yf["Server NDCG@5"], name="Server order",
                           mode="lines+markers", line_color="#E47B00", line_width=2)
        fig_yf.add_scatter(x=df_yf["Run"], y=df_yf["Client NDCG@5"], name="Client re-rank",
                           mode="lines+markers", line_color="#FFA500", line_width=2)
        fig_yf.update_layout(height=280, yaxis=dict(title="NDCG@5", range=[0, 1.05]),
                              legend=dict(orientation="h", y=1.02), margin=dict(t=20))
        st.plotly_chart(fig_yf, use_container_width=True)
        st.dataframe(df_yf, use_container_width=True)

    if yelp_runs:
        st.markdown("### Yelp academic offline runs")
        rows = []
        for k, v in sorted(yelp_runs.items(), key=lambda x: ts_to_dt(x[1].get("run_id", ""))):
            s = v.get("summary", {})
            rows.append({
                "Run":     v.get("run_id", k)[:15],
                "City":    v.get("city", "?"),
                "Random":  s.get("random",  {}).get("avg_ndcg5", 0),
                "Rating":  s.get("rating",  {}).get("avg_ndcg5", 0),
                "Reviews": s.get("reviews", {}).get("avg_ndcg5", 0),
                "Client":  s.get("client",  {}).get("avg_ndcg5", 0),
            })
        df_y = pd.DataFrame(rows)
        st.dataframe(df_y, use_container_width=True)

# ── View: Advanced Eval ───────────────────────────────────────────────────────

elif view == "Advanced Eval":
    st.title("🔭 Advanced Evaluation")
    st.caption(
        "Three data-driven tests on existing log data — no new API calls. "
        "Run `python scripts/eval_advanced.py` to generate or refresh results."
    )

    ae_runs = {k: v for k, v in all_results.items() if v.get("source") == "advanced_eval"}
    if not ae_runs:
        st.warning(
            "No advanced eval results found. Run:\n"
            "```bash\npython scripts/eval_advanced.py\n```"
        )
        st.stop()

    # Pick most recent advanced eval run
    ae_key = sorted(ae_runs, key=lambda k: ts_to_dt(ae_runs[k].get("run_id", "")))[-1]
    ae     = ae_runs[ae_key]
    st.caption(f"Showing: `{ae_key}` — Places run `{ae.get('places_run','?')}`, "
               f"Yelp run `{ae.get('yelp_run','?')}`")

    # ── Test 1: Cross-source head-to-head ─────────────────────────────────────
    st.markdown("---")
    st.markdown("## Test 1 — Cross-source head-to-head")
    st.caption(
        "Same 15 queries fired at Google Places and Yelp Fusion. "
        "Client re-ranker applied independently to each pool, then to a merged pool."
    )

    t1 = ae.get("test1_cross_source", {})

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Places avg NDCG@5",  f"{t1.get('avg_places_ndcg5', 0):.4f}")
    col2.metric("Yelp avg NDCG@5",    f"{t1.get('avg_yelp_ndcg5', 0):.4f}",
                delta=f"{t1.get('avg_yelp_ndcg5', 0) - t1.get('avg_places_ndcg5', 0):+.4f}")
    col3.metric("Merged avg NDCG@5",  f"{t1.get('avg_merged_ndcg5', 0):.4f}")
    col4.metric("Head-to-head",
                f"P {t1.get('places_wins',0)}W · Y {t1.get('yelp_wins',0)}W · {t1.get('ties',0)}T")

    pq1 = t1.get("per_query", [])
    if pq1:
        df1 = pd.DataFrame(pq1)

        # Grouped bar: Places vs Yelp per query
        fig1 = go.Figure()
        fig1.add_bar(name="Google Places", x=df1["id"], y=df1["places_ndcg5"],
                     marker_color="#6C63FF", opacity=0.85)
        fig1.add_bar(name="Yelp Fusion",   x=df1["id"], y=df1["yelp_ndcg5"],
                     marker_color="#FFA500", opacity=0.85)
        fig1.add_bar(name="Merged pool",   x=df1["id"], y=df1["merged_ndcg5"],
                     marker_color="#00C9A7", opacity=0.75)
        fig1.update_layout(
            barmode="group", height=380,
            yaxis=dict(title="NDCG@5 (client re-rank)", range=[0, 1.08]),
            xaxis_title="Query ID",
            legend=dict(orientation="h", y=1.02),
            margin=dict(t=30),
        )
        st.plotly_chart(fig1, use_container_width=True)

        # Top-5 slot attribution
        st.markdown("### Top-5 slot attribution (merged pool)")
        st.caption("How many of the merged top-5 slots come from each source.")
        df1["top5_yelp_frac"] = df1["top5_yelp"] / 5
        fig1b = go.Figure()
        fig1b.add_bar(name="Places slots", x=df1["id"], y=df1["top5_places"],
                      marker_color="#6C63FF")
        fig1b.add_bar(name="Yelp slots",   x=df1["id"], y=df1["top5_yelp"],
                      marker_color="#FFA500")
        fig1b.update_layout(
            barmode="stack", height=300,
            yaxis=dict(title="# top-5 slots", range=[0, 5.5], dtick=1),
            xaxis_title="Query ID",
            legend=dict(orientation="h", y=1.02),
            margin=dict(t=30),
        )
        st.plotly_chart(fig1b, use_container_width=True)

        df1_display = df1[["id", "text", "places_ndcg5", "yelp_ndcg5", "merged_ndcg5",
                            "winner", "top5_places", "top5_yelp"]].copy()
        df1_display.columns = ["ID", "Query", "Places NDCG@5", "Yelp NDCG@5",
                                "Merged NDCG@5", "Winner", "Top5 Places", "Top5 Yelp"]
        st.dataframe(
            df1_display.style.background_gradient(
                subset=["Places NDCG@5", "Yelp NDCG@5", "Merged NDCG@5"],
                cmap="RdYlGn", vmin=0.7, vmax=1.0,
            ),
            use_container_width=True,
        )

    # ── Test 2: Signal ablation ────────────────────────────────────────────────
    st.markdown("---")
    st.markdown("## Test 2 — Re-ranker signal ablation")
    st.caption(
        "Zero out one signal at a time on Places data. Negative delta = that signal helps. "
        "Cold-start signals (saved, prefTags, netAffinity) are always 0 — ablating them has no effect."
    )

    t2 = ae.get("test2_ablation", {})
    baseline_ndcg = t2.get("baseline_ndcg5", 0)
    st.metric("Baseline NDCG@5 (full scorer)", f"{baseline_ndcg:.4f}")

    sigs = t2.get("signals", [])
    if sigs:
        df2 = pd.DataFrame(sigs)
        df2_active    = df2[~df2["cold_start"]].copy()
        df2_coldstart = df2[df2["cold_start"]].copy()

        df2_active = df2_active.sort_values("delta")
        colors2 = [
            "#FF6584" if d < -0.001 else ("#00C9A7" if d > 0.001 else "#AAAAAA")
            for d in df2_active["delta"]
        ]

        fig2 = go.Figure(go.Bar(
            x=df2_active["delta"],
            y=df2_active["signal"].apply(lambda s: f"{s}  (w={WEIGHTS_DISPLAY.get(s,'?')})"),
            orientation="h",
            marker_color=colors2,
            text=[f"{d:+.4f}" for d in df2_active["delta"]],
            textposition="outside",
        ))
        fig2.add_vline(x=0, line_color="white", line_dash="dot", line_width=1)
        fig2.update_layout(
            height=320,
            xaxis=dict(title="NDCG@5 delta (ablated − baseline)", zeroline=False),
            margin=dict(l=200, t=20, r=80),
        )
        st.plotly_chart(fig2, use_container_width=True)

        st.caption(
            "Red bars (negative delta) = signal **helps** ranking — removing it hurts. "
            "Green bar (positive delta) = signal **hurts** ranking — removing it helps. "
            f"⚠️ `isOpen` (+{df2_active[df2_active.signal=='isOpen']['delta'].values[0]:+.4f}) "
            "is counterproductive: venues marked closed get penalized even if they are high quality, "
            "so NDCG@5 improves when you stop penalizing them."
        )

        col_a, col_b = st.columns(2)
        with col_a:
            st.markdown("**Active signals**")
            df2_act_display = df2_active[["signal", "weight", "ndcg5", "delta"]].copy()
            df2_act_display.columns = ["Signal", "Weight", "NDCG@5 (ablated)", "Delta"]
            st.dataframe(
                df2_act_display.style.background_gradient(
                    subset=["Delta"], cmap="RdYlGn_r", vmin=-0.05, vmax=0.05
                ),
                use_container_width=True,
            )
        with col_b:
            st.markdown("**Cold-start signals** (always 0 — no personalization)")
            df2_cs_display = df2_coldstart[["signal", "weight", "note"]].copy()
            df2_cs_display.columns = ["Signal", "Weight", "Note"]
            st.dataframe(df2_cs_display, use_container_width=True)

    # ── Test 3: ILD ───────────────────────────────────────────────────────────
    st.markdown("---")
    st.markdown("## Test 3 — Intra-list Diversity (ILD@5)")
    st.caption(
        "ILD = fraction of top-5 pairs with different categories. "
        "0.0 = all 5 results same category, 1.0 = all different. "
        "Diversity is good for multi-intent queries (q11, q14) but "
        "precision queries (q02 Italian dinner) should score near 0."
    )

    t3 = ae.get("test3_ild", {})

    col_m1, col_m2 = st.columns(2)
    col_m1.metric("Places avg ILD@5", f"{t3.get('avg_ild_places', 0):.4f}")
    col_m2.metric("Yelp avg ILD@5",   f"{t3.get('avg_ild_yelp', 0):.4f}",
                  delta=f"{t3.get('avg_ild_yelp', 0) - t3.get('avg_ild_places', 0):+.4f}")

    p_rows3 = {r["id"]: r for r in t3.get("places", [])}
    y_rows3 = {r["id"]: r for r in t3.get("yelp",   [])}
    all_ids = sorted(set(p_rows3) | set(y_rows3))

    if all_ids:
        rows3 = []
        for qid in all_ids:
            pr = p_rows3.get(qid, {})
            yr = y_rows3.get(qid, {})
            rows3.append({
                "id":           qid,
                "text":         pr.get("text", yr.get("text", "")),
                "places_ild":   pr.get("ild", 0),
                "yelp_ild":     yr.get("ild", 0),
                "places_cats":  str(pr.get("category_distribution", {})),
                "yelp_cats":    str(yr.get("category_distribution", {})),
            })
        df3 = pd.DataFrame(rows3)

        fig3 = go.Figure()
        fig3.add_bar(name="Google Places", x=df3["id"], y=df3["places_ild"],
                     marker_color="#6C63FF", opacity=0.85)
        fig3.add_bar(name="Yelp Fusion",   x=df3["id"], y=df3["yelp_ild"],
                     marker_color="#FFA500", opacity=0.85)
        fig3.update_layout(
            barmode="group", height=360,
            yaxis=dict(title="ILD@5  (0=mono-cat, 1=all-diverse)", range=[0, 1.05]),
            xaxis_title="Query ID",
            legend=dict(orientation="h", y=1.02),
            margin=dict(t=30),
        )
        st.plotly_chart(fig3, use_container_width=True)

        df3_display = df3[["id", "text", "places_ild", "yelp_ild",
                            "places_cats", "yelp_cats"]].copy()
        df3_display.columns = ["ID", "Query", "Places ILD", "Yelp ILD",
                                "Places cat dist", "Yelp cat dist"]
        st.dataframe(
            df3_display.style.background_gradient(
                subset=["Places ILD", "Yelp ILD"], cmap="YlOrRd", vmin=0, vmax=1
            ),
            use_container_width=True,
        )

    st.markdown("---")
    st.caption(
        f"Advanced eval run: `{ae_key}` — "
        f"Places run `{ae.get('places_run','?')}` · "
        f"Yelp run `{ae.get('yelp_run','?')}`"
    )


# ── View: Raw logs ─────────────────────────────────────────────────────────────

elif view == "Raw logs":
    st.title("🗂 Raw Query Logs")

    run_id  = selected.get("run_id", selected_key)
    log_run = LOG_DIR / run_id

    if not log_run.exists():
        st.warning(f"No per-query logs found at `experiments/logs/places/{run_id}/`")
        st.json(selected)
        st.stop()

    log_files = sorted(log_run.glob("*.json"))
    query_ids = [f.stem for f in log_files]
    chosen    = st.selectbox("Query", query_ids)

    log_data = json.loads((log_run / f"{chosen}.json").read_text())
    st.markdown(f"**Query:** {log_data.get('query_text', '')}  "
                f"&nbsp;·&nbsp; **Latency:** {log_data.get('latency_ms', '?')} ms  "
                f"&nbsp;·&nbsp; **Results:** {len(log_data.get('activities', []))}")
    st.markdown(f"> {log_data.get('server_summary', '')}")

    activities = log_data.get("activities", [])
    if activities:
        df = pd.DataFrame([{
            "Rank":      i + 1,
            "Name":      a.get("name", ""),
            "Category":  a.get("category", ""),
            "Rating":    a.get("rating", 0),
            "Reviews":   a.get("reviewCount", 0),
            "Price":     a.get("priceLevel", 0),
            "Distance":  a.get("distance", ""),
            "Open":      "✓" if a.get("isOpen") else "✗",
            "Why":       a.get("whyRecommended", "")[:60],
        } for i, a in enumerate(activities)])
        st.dataframe(df.style.background_gradient(subset=["Rating"], cmap="RdYlGn", vmin=0, vmax=5),
                     use_container_width=True)

        st.markdown("### Rating distribution")
        fig = px.histogram(df, x="Rating", nbins=10, color_discrete_sequence=[PALETTE["client"]])
        fig.update_layout(height=260, margin=dict(t=20))
        st.plotly_chart(fig, use_container_width=True)

    with st.expander("Full JSON"):
        st.json(log_data)
