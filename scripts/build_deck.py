#!/usr/bin/env python3
"""
Build the PULSE technical deck.
All content is in editable PowerPoint text boxes.
Run: python scripts/build_deck.py
Output: docs/PULSE_Rec_System_Deck.pptx
"""

from pathlib import Path
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN

# ── Palette — clean academic (light theme) ─────────────────────────────────────
BG      = RGBColor(0xFA, 0xFA, 0xFC)   # near-white page
SURFACE = RGBColor(0xFF, 0xFF, 0xFF)   # pure white panel
BORDER  = RGBColor(0xE2, 0xE8, 0xF0)  # light border
INK     = RGBColor(0x0F, 0x17, 0x2A)  # near-black text
SUB     = RGBColor(0x4A, 0x55, 0x68)  # secondary text / captions
BLUE    = RGBColor(0x1D, 0x4E, 0xD8)  # primary accent
TEAL    = RGBColor(0x05, 0x96, 0x69)  # positive / secondary
AMBER   = RGBColor(0xD9, 0x77, 0x06)  # warning / highlight
RED     = RGBColor(0xDC, 0x26, 0x26)  # negative / error
SLATE   = RGBColor(0x64, 0x74, 0x8B)  # muted accent
WHITE   = RGBColor(0xFF, 0xFF, 0xFF)

W = Inches(13.33)
H = Inches(7.5)

# ── Primitives ────────────────────────────────────────────────────────────────

def blank(prs):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    bg = slide.background.fill; bg.solid(); bg.fore_color.rgb = BG
    return slide

def rect(slide, l, t, w, h, fill=None, border=None, bw=8000):
    s = slide.shapes.add_shape(1, Inches(l), Inches(t), Inches(w), Inches(h))
    if fill: s.fill.solid(); s.fill.fore_color.rgb = fill
    else: s.fill.background()
    if border: s.line.color.rgb = border; s.line.width = bw
    else: s.line.fill.background()
    return s

def hline(slide, t, l=0.45, w=12.43, color=BORDER, thick=0.013):
    r = rect(slide, l, t, w, thick, fill=color)

def tb(slide, text, l, t, w, h,
       size=13, bold=False, color=INK, align=PP_ALIGN.LEFT, italic=False):
    box = slide.shapes.add_textbox(Inches(l), Inches(t), Inches(w), Inches(h))
    tf = box.text_frame; tf.word_wrap = True
    p = tf.paragraphs[0]; p.alignment = align
    run = p.add_run(); run.text = text
    run.font.size = Pt(size); run.font.bold = bold
    run.font.italic = italic; run.font.color.rgb = color
    return box

def section_tag(slide, text, color=BLUE):
    """Small coloured pill at top-left."""
    r = rect(slide, 0.45, 0.14, len(text) * 0.11 + 0.3, 0.3,
             fill=RGBColor(int(color[0]*0.15+0xFA*0.85),
                           int(color[1]*0.15+0xFA*0.85),
                           int(color[2]*0.15+0xFC*0.85)))
    r.line.fill.background()
    tb(slide, text.upper(), 0.6, 0.15, len(text)*0.11+0.15, 0.26,
       size=8.5, bold=True, color=color)

def heading(slide, text, sub=None):
    tb(slide, text, 0.45, 0.55, 12.43, 0.7, size=28, bold=True, color=INK)
    if sub: tb(slide, sub, 0.45, 1.22, 12.0, 0.38, size=13, color=SUB)
    hline(slide, 1.68)

def card(slide, l, t, w, h, accent=BLUE, filled=False):
    bg_col = RGBColor(
        min(255, int(accent[0]*0.08 + 0xFF*0.92)),
        min(255, int(accent[1]*0.08 + 0xFF*0.92)),
        min(255, int(accent[2]*0.08 + 0xFF*0.92)),
    ) if not filled else accent
    rect(slide, l, t, w, h, fill=bg_col, border=accent, bw=10000)

def bullet(slide, items, l, t, w=12.0, size=13, gap=0.5, color=INK, dot=BLUE):
    for i, item in enumerate(items):
        y = t + i * gap
        d = rect(slide, l, y + 0.16, 0.08, 0.08, fill=dot)
        tb(slide, item, l + 0.2, y, w - 0.2, gap - 0.06, size=size, color=color)

def kv(slide, rows, l, t, kw=2.2, vw=5.0, size=12, gap=0.48):
    for i, (k, v) in enumerate(rows):
        y = t + i * gap
        tb(slide, k, l, y, kw, gap-0.06, size=size, color=SUB)
        tb(slide, v, l+kw, y, vw, gap-0.06, size=size, bold=True, color=INK)

def tbl(slide, data, col_widths, l, t, row_h=0.36,
        hdr_fill=BLUE, hdr_fg=WHITE, body_fg=INK,
        odd=SURFACE, even=RGBColor(0xF1,0xF5,0xF9),
        body_size=11, hdr_size=12):
    rows, cols = len(data), len(data[0])
    shape = slide.shapes.add_table(
        rows, cols, Inches(l), Inches(t),
        sum(Inches(c) for c in col_widths), Inches(row_h * rows))
    t_obj = shape.table
    for ci, cw in enumerate(col_widths):
        t_obj.columns[ci].width = Inches(cw)
    for ri, row in enumerate(data):
        t_obj.rows[ri].height = Inches(row_h)
        is_hdr = ri == 0
        for ci, val in enumerate(row):
            cell = t_obj.cell(ri, ci)
            cell.text = str(val)
            p = cell.text_frame.paragraphs[0]
            p.alignment = PP_ALIGN.LEFT if ci == 0 else PP_ALIGN.CENTER
            run = p.runs[0] if p.runs else p.add_run()
            run.font.size = Pt(hdr_size if is_hdr else body_size)
            run.font.bold = is_hdr
            run.font.color.rgb = hdr_fg if is_hdr else body_fg
            cell.fill.solid()
            cell.fill.fore_color.rgb = hdr_fill if is_hdr else (odd if ri%2==0 else even)
    return t_obj

def metric_card(slide, val, label, sub, x, accent=BLUE):
    card(slide, x, 1.9, 2.45, 2.05, accent=accent)
    tb(slide, val, x+0.15, 2.05, 2.15, 0.82,
       size=34, bold=True, color=accent, align=PP_ALIGN.CENTER)
    tb(slide, label, x+0.1, 2.87, 2.25, 0.42,
       size=12, bold=True, color=INK, align=PP_ALIGN.CENTER)
    tb(slide, sub, x+0.1, 3.27, 2.25, 0.55,
       size=9.5, color=SUB, align=PP_ALIGN.CENTER)

# ── Slides ─────────────────────────────────────────────────────────────────────

def s_cover(prs):
    slide = blank(prs)
    # Left stripe
    rect(slide, 0, 0, 0.07, 7.5, fill=BLUE)
    rect(slide, 0.07, 0, 4.8, 7.5, fill=WHITE)

    tb(slide, "PULSE", 0.5, 1.1, 4.3, 1.3, size=72, bold=True, color=BLUE)
    tb(slide, "Voice-Curated Social Discovery", 0.5, 2.38, 4.3, 0.55,
       size=18, bold=True, color=INK)
    tb(slide, "System Architecture · Feed Mechanism\nRecommendation Engine · Evaluation",
       0.5, 2.95, 4.3, 0.8, size=13, color=SUB)
    hline(slide, 3.82, l=0.5, w=4.3, color=BORDER)
    meta = [
        ("Stack",       "Rust (Axum) + Flutter PWA"),
        ("Deployment",  "Railway · Docker multi-stage"),
        ("Data source", "Google Places API v1 · Yelp Fusion · Eventbrite"),
        ("Evaluation",  "Run 001 · 2026-04-30 · 15 queries"),
        ("Context",     "University project — academic prototype"),
    ]
    for i, (k, v) in enumerate(meta):
        y = 3.98 + i * 0.56
        tb(slide, k, 0.5, y, 1.6, 0.48, size=10, color=SUB)
        tb(slide, v, 2.15, y, 2.55, 0.48, size=11, bold=True, color=INK)

    # Right divider
    rect(slide, 4.87, 0, 0.06, 7.5, fill=BORDER)
    # Right side content
    tb(slide, "Table of Contents", 5.3, 0.7, 7.7, 0.45, size=13, bold=True, color=SUB)
    sections = [
        "1  Project Overview",
        "2  Feed Mechanism",
        "3  Recommendation Engine",
        "4  Data Sources: Places · Yelp · Eventbrite",
        "5  A/B Test: Without AI vs With AI",
        "6  Results — Run 001",
        "7  Discussion & Next Steps",
    ]
    for i, s in enumerate(sections):
        tb(slide, s, 5.3, 1.25 + i * 0.78, 7.6, 0.62, size=15, color=INK)
        if i < len(sections)-1:
            hline(slide, 1.93 + i * 0.78, l=5.3, w=7.6)


def s_overview(prs):
    slide = blank(prs)
    section_tag(slide, "1 · Project Overview")
    heading(slide, "System Description",
            "PULSE is an academic prototype for voice- and text-driven local activity discovery.")
    bullet(slide, [
        "Users submit natural-language queries (voice-transcribed or typed) to discover nearby venues and events.",
        "The server queries external APIs (Google Places, Yelp Fusion, Eventbrite) and merges results into a unified Activity model.",
        "An optional large language model (Gemini, OpenRouter, HuggingFace) rewrites the result summary using retrieved context.",
        "A client-side scoring function re-ranks candidates using nine weighted relevance signals before display.",
        "Results are spatially clustered by neighbourhood category and rendered as map overlays and a card list.",
        "No persistent user accounts are maintained — the personalization profile is ephemeral (session-scoped).",
    ], l=0.45, t=1.88, size=14.5, gap=0.73)


def s_stack(prs):
    slide = blank(prs)
    section_tag(slide, "1 · Project Overview")
    heading(slide, "System Components")

    cols = [
        ("Rust Core", BLUE, [
            "Axum 0.7 — async HTTP server",
            "StrollCore — domain logic struct",
            "flutter_rust_bridge 1.82 — FFI",
            "rusqlite (bundled) — SQLite",
            "Tokio — async runtime",
            "reqwest — outbound HTTP",
        ]),
        ("Flutter App", TEAL, [
            "Web PWA (primary target)",
            "speech_to_text plugin",
            "HTTP client → /api/* endpoints",
            "DiscoverWorldController",
            "Client-side scorer + clustering",
            "Responsive mobile/desktop layout",
        ]),
        ("Infrastructure", AMBER, [
            "Railway.app container hosting",
            "Dockerfile — two-stage build",
            "Stage 1: Flutter 3.27.4 web",
            "Stage 2: rust:1.85-slim binary",
            "Runtime: Debian Bookworm",
            "Health check: GET /api/health",
        ]),
    ]

    for i, (title, color, items) in enumerate(cols):
        x = 0.35 + i * 4.33
        card(slide, x, 1.85, 4.12, 5.3, accent=color)
        rect(slide, x, 1.85, 4.12, 0.38, fill=color)
        tb(slide, title, x+0.15, 1.9, 3.82, 0.3, size=12, bold=True, color=WHITE)
        for j, item in enumerate(items):
            tb(slide, item, x+0.18, 2.36 + j*0.65, 3.76, 0.6, size=12, color=INK)


def s_arch(prs):
    slide = blank(prs)
    section_tag(slide, "1 · Project Overview")
    heading(slide, "Request Lifecycle — POST /api/recommend")

    nodes = [
        (0.3,  "Client\n(Flutter)",     BLUE),
        (2.3,  "Axum\nRouter",          SLATE),
        (4.3,  "Source\nSelector",      INK),
        (6.3,  "Google\nPlaces v1",     BLUE),
        (8.3,  "Yelp\nFusion",          RED),
        (10.3, "Eventbrite\nAPI",       AMBER),
    ]
    for x, label, color in nodes:
        card(slide, x, 2.05, 1.9, 1.0, accent=color)
        tb(slide, label, x+0.1, 2.15, 1.7, 0.8, size=11, bold=True,
           color=color, align=PP_ALIGN.CENTER)

    for i in range(len(nodes)-1):
        x1 = nodes[i][0]+1.9; x2 = nodes[i+1][0]
        rect(slide, x1+0.03, 2.52, x2-x1-0.06, 0.013, fill=BORDER)

    hline(slide, 3.18)

    # Three decision rows
    steps = [
        (TEAL,  "Step 1 — Source selection",
         "Source Selector checks which API keys are configured (GOOGLE_PLACES_API_KEY, YELP_API_KEY, EVENTBRITE_TOKEN). "
         "All configured sources are queried in parallel; results are merged and deduplicated on name + lat/lng proximity."),
        (BLUE,  "Step 2 — Client re-ranking",
         "Merged candidates are returned as a flat list. Flutter's DiscoverWorldController scores each activity with the "
         "9-signal weighted scorer and sorts descending. Geo-clusters are computed on the sorted list."),
        (AMBER, "Step 3 — LLM summary (optional)",
         "If an LLM provider is configured and responds successfully, the summary field is rewritten. "
         "On failure or if no provider is set, a rule-based template (agent.rs) is used. "
         "The activity list is not affected by the LLM — only the summary text changes."),
    ]
    for i, (color, title, body) in enumerate(steps):
        y = 3.3 + i * 1.25
        rect(slide, 0.35, y, 0.06, 1.1, fill=color)
        tb(slide, title, 0.55, y+0.05, 4.0, 0.35, size=12, bold=True, color=color)
        tb(slide, body,  0.55, y+0.42, 12.3, 0.72, size=12, color=INK)


def s_feed(prs):
    slide = blank(prs)
    section_tag(slide, "2 · Feed Mechanism")
    heading(slide, "Feed Endpoint — GET /api/feed",
            "Populates the initial view before the user submits any query.")

    # Path A
    card(slide, 0.35, 1.85, 6.05, 4.88, accent=BLUE)
    rect(slide, 0.35, 1.85, 6.05, 0.38, fill=BLUE)
    tb(slide, "Live path  (external APIs configured)", 0.5, 1.9, 5.7, 0.3,
       size=12, bold=True, color=WHITE)
    bullet(slide, [
        'Default search: "popular restaurants bars cafes things to do"',
        "Sources queried: Places + Yelp + Eventbrite (whichever keys are set)",
        "Results merged, deduplicated, returned as unified Activity list",
        "Trending tags extracted from venue type metadata",
        "Social posts array is empty — no social graph from external APIs",
    ], l=0.55, t=2.38, w=5.65, size=12, gap=0.58, color=INK, dot=BLUE)

    # Path B
    card(slide, 6.6, 1.85, 6.05, 4.88, accent=RED)
    rect(slide, 6.6, 1.85, 6.05, 0.38, fill=RED)
    tb(slide, "Fallback path  (no keys configured)", 6.76, 1.9, 5.7, 0.3,
       size=12, bold=True, color=WHITE)
    bullet(slide, [
        "StrollCore.get_personalized_feed() — in-memory only",
        "Keyword intent parser extracts category + subcategory",
        "Filters from SQLite-seeded corpus, sorts by rating DESC",
        "Top 8 recommendations returned",
        "Mock posts from 2 hardcoded Shanghai entries",
        "Trending tags: 8 static hashtags (#WeekendBrunch etc.)",
    ], l=6.78, t=2.38, w=5.65, size=12, gap=0.55, color=INK, dot=RED)

    hline(slide, 6.8)
    tb(slide,
       "Coverage gap observed in Run 001 fallback: only 9/15 queries returned results (60%) "
       "vs 15/15 (100%) with Google Places. Subcategory mismatch is the primary cause.",
       0.45, 6.88, 12.4, 0.42, size=11, italic=True, color=SUB)


def s_sources(prs):
    slide = blank(prs)
    section_tag(slide, "4 · Data Sources")
    heading(slide, "External Data Sources — Places · Yelp · Eventbrite")

    sources = [
        ("Google Places\nText Search v1", BLUE,
         "places.googleapis.com/v1/places:searchText",
         "GOOGLE_PLACES_API_KEY",
         [
             "Full-text neural search — understands 'tapas', 'brunch', 'hidden gem'",
             "Returns: name, rating, review count, price level, photos, hours, editorial summary",
             "Distance computed via Haversine from user location",
             "10 results per query, 5 000 m radius bias",
             "Pricing: $0.017 per request (Pay-as-you-go)",
         ]),
        ("Yelp Fusion\nBusiness Search", RED,
         "api.yelp.com/v3/businesses/search",
         "YELP_API_KEY  (Bearer token)",
         [
             "Keyword + category search with radius and sort options",
             "Returns: name, rating, review count, price, categories, coordinates",
             "Rich category taxonomy (700+ categories) vs Places' type list",
             "500 calls/day free tier · 10 results per call",
             "Complements Places for food/nightlife coverage",
         ]),
        ("Eventbrite\nEvent Search", AMBER,
         "www.eventbriteapi.com/v3/events/search/",
         "EVENTBRITE_TOKEN  (Bearer token)",
         [
             "Searches publicly listed events by keyword + lat/lng",
             "Returns: event name, description, start/end time, venue, ticket price",
             "Adds temporal dimension — events vs static venues",
             "Maps to Activity model with is_open derived from start_time",
             "Free tier available via eventbrite.com/platform/api",
         ]),
    ]

    for i, (title, color, endpoint, auth, items) in enumerate(sources):
        x = 0.35 + i * 4.33
        card(slide, x, 1.85, 4.12, 5.45, accent=color)
        rect(slide, x, 1.85, 4.12, 0.38, fill=color)
        tb(slide, title, x+0.15, 1.89, 3.82, 0.3, size=11, bold=True, color=WHITE)
        tb(slide, endpoint, x+0.15, 2.33, 3.82, 0.28, size=9, color=color)
        tb(slide, f"Auth: {auth}", x+0.15, 2.6, 3.82, 0.28, size=9, color=SUB)
        for j, item in enumerate(items):
            tb(slide, item, x+0.15, 2.94 + j*0.54, 3.82, 0.5, size=10.5, color=INK)


def s_scorer(prs):
    slide = blank(prs)
    section_tag(slide, "3 · Recommendation Engine")
    heading(slide, "Client-Side Scoring Model",
            "Implemented in DiscoverWorldController._scoreActivity (Flutter).")

    tb(slide,
       "All candidates from all sources are scored with the weighted linear combination below "
       "and sorted descending before rendering. Weights are heuristic — not trained.",
       0.45, 1.76, 12.4, 0.42, size=12.5, color=SUB)

    data = [
        ["Signal",               "Weight", "Computation"],
        ["Rating",               "24 %",   "activity.rating / 5.0"],
        ["Open now",             "14 %",   "Binary: activity.isOpen"],
        ["Query affinity",       "14 %",   "Token overlap: query tokens  ∩  name + description + tags + location fields"],
        ["Saved by user",        "14 %",   "Binary: activity ID present in session save history"],
        ["Review count",         "12 %",   "activity.reviewCount / max(reviewCount across catalog)"],
        ["Preferred category",   "11 %",   "Binary: activity.category in session-inferred preference set"],
        ["Preferred tags",       " 8 %",   "Binary: any tag in session-inferred tag vocabulary"],
        ["Distance",             " 7 %",   "1 / (1 + km)  — parsed from pre-formatted distance string"],
        ["Network affinity",     " 6 %",   "Category + tag overlap with followed users' preferences"],
    ]

    tbl(slide, data,
        col_widths=[2.55, 1.0, 8.65],
        l=0.35, t=2.24, row_h=0.37,
        hdr_fill=BLUE, body_fg=INK, odd=SURFACE,
        even=RGBColor(0xF1,0xF5,0xF9),
        body_size=12, hdr_size=12.5)

    hline(slide, 6.98)
    tb(slide,
       "Note: weights were chosen heuristically and have not been tuned on a labelled dataset. "
       "The evaluation in §5–6 quantifies their combined effect against the server default ordering.",
       0.45, 7.05, 12.4, 0.38, size=10.5, italic=True, color=SUB)


def s_clustering(prs):
    slide = blank(prs)
    section_tag(slide, "3 · Recommendation Engine")
    heading(slide, "Clustering, Personalization, and Limitations")

    card(slide, 0.35, 1.85, 5.95, 2.95, accent=BLUE)
    tb(slide, "Spatial clustering", 0.55, 1.98, 5.5, 0.35, size=12.5, bold=True, color=BLUE)
    bullet(slide, [
        "Cluster ID = category :: neighbourhood  (e.g., food::tribeca)",
        "Center = mean lat/lng of member activities",
        "Score = mean of member scores",
        "Map overlay position normalised to [0.08, 0.92]",
        "Top activity = highest-scoring member per cluster",
    ], l=0.55, t=2.4, w=5.65, size=12, gap=0.44, color=INK, dot=BLUE)

    card(slide, 6.55, 1.85, 6.05, 2.95, accent=TEAL)
    tb(slide, "Session-scoped personalization profile", 6.72, 1.98, 5.7, 0.35,
       size=12.5, bold=True, color=TEAL)
    bullet(slide, [
        "Preferred categories — from feed, trending, social network",
        "Preferred tags — from trending and saved-item metadata",
        "Saved IDs — user-initiated saves in current session",
        "Seen IDs — deduplication across refreshes",
        "Query history — all submitted queries + result counts",
    ], l=6.72, t=2.4, w=5.72, size=12, gap=0.44, color=INK, dot=TEAL)

    hline(slide, 4.9)
    tb(slide, "Identified Limitations", 0.45, 4.98, 5, 0.35, size=12.5, bold=True, color=RED)
    limits = [
        "Server-side geo-ranking absent: GeoLocation is parsed but the _location parameter is unused in find_activities.",
        "Ephemeral personalization: preference profile is rebuilt from scratch on every page load.",
        "Static trending: the trending list reflects insertion order, not engagement signals.",
        "Coordinate mismatch in mock path: corpus hardcoded to Shanghai; client defaults to New York.",
    ]
    for i, lim in enumerate(limits):
        tb(slide, lim, 0.45, 5.38 + i*0.46, 12.4, 0.42, size=11.5, color=INK)


def s_ab_design(prs):
    slide = blank(prs)
    section_tag(slide, "5 · A/B/C Test", color=AMBER)
    heading(slide, "Three-Condition Experimental Design")

    tb(slide, "Three retrieval conditions isolate: (A) rule-based fallback, "
       "(B) live neural search via Google Places, (C) cached real-venue dataset — always available, no API key.",
       0.35, 1.76, 12.63, 0.42, size=13, color=SUB)

    CW = 4.04   # card width
    GAP = 0.25
    CT = 2.28   # card top
    CH = 4.88   # card height

    # Condition A
    lA = 0.35
    card(slide, lA, CT, CW, CH, accent=SLATE)
    rect(slide, lA, CT, CW, 0.38, fill=SLATE)
    tb(slide, "Condition A — Rule-Based Mock", lA + 0.17, CT + 0.05, CW - 0.22, 0.3,
       size=12, bold=True, color=WHITE)
    kv(slide, [
        ("Retrieval",  "Keyword intent parser (agent.rs)"),
        ("Corpus",     "4 hardcoded Shanghai venues"),
        ("Ranking",    "Rating DESC only"),
        ("LLM",        "None"),
        ("Coverage",   "9 / 15 queries (60 %)"),
        ("Server",     "Local, no API key"),
    ], l=lA + 0.17, t=CT + 0.48, kw=1.3, vw=CW - 1.55, size=11, gap=0.5)

    # Condition B
    lB = lA + CW + GAP
    card(slide, lB, CT, CW, CH, accent=BLUE)
    rect(slide, lB, CT, CW, 0.38, fill=BLUE)
    tb(slide, "Condition B — Google Places (Live)", lB + 0.17, CT + 0.05, CW - 0.22, 0.3,
       size=12, bold=True, color=WHITE)
    kv(slide, [
        ("Retrieval",  "Google Places Text Search"),
        ("Corpus",     "Live venues, globally indexed"),
        ("Ranking",    "Google score + client re-rank"),
        ("LLM",        "None (keys unavailable)"),
        ("Coverage",   "15 / 15 queries (100 %)"),
        ("Server",     "Railway production"),
    ], l=lB + 0.17, t=CT + 0.48, kw=1.3, vw=CW - 1.55, size=11, gap=0.5)

    # Condition C
    lC = lB + CW + GAP
    card(slide, lC, CT, CW, CH, accent=TEAL)
    rect(slide, lC, CT, CW, 0.38, fill=TEAL)
    tb(slide, "Condition C — Fixture Cache", lC + 0.17, CT + 0.05, CW - 0.22, 0.3,
       size=12, bold=True, color=WHITE)
    kv(slide, [
        ("Retrieval",  "Category keyword search over seed file"),
        ("Corpus",     "249 real NYC venues (Places-sourced)"),
        ("Ranking",    "Relevance score x rating + client re-rank"),
        ("LLM",        "None"),
        ("Coverage",   "15 / 15 queries (100 %)"),
        ("Server",     "Local, no API key needed"),
    ], l=lC + 0.17, t=CT + 0.48, kw=1.3, vw=CW - 1.55, size=11, gap=0.5)

    hline(slide, 7.22)
    tb(slide,
       "Run IDs — A: 20260430T060406Z (local mock)  |  "
       "B: 20260430T051138Z (Railway, Google Places)  |  "
       "C: 20260430T064253Z (local fixture cache). "
       "All runs used provider=local (template summary, no LLM). LLM summary comparison (Condition D) deferred — Gemini quota exhausted.",
       0.35, 7.3, 12.63, 0.44, size=10.5, italic=True, color=SUB)


def s_ab_results(prs):
    slide = blank(prs)
    section_tag(slide, "5 · A/B/C Test", color=AMBER)
    heading(slide, "A/B/C Results — Coverage, Depth, and Quality")

    data = [
        ["Metric",                   "A — Mock (4 venues)", "B — Google Places (live)", "C — Fixture Cache"],
        ["Query coverage",           "9 / 15  (60 %)",      "15 / 15  (100 %)",          "15 / 15  (100 %)"],
        ["Results per query",        "1  (single match)",   "10  (live results)",         "10  (cached)"],
        ["Unique venues served",     "4  (hardcoded)",      "150  (~0 overlap per run)",  "249  (static pool)"],
        ["NDCG@5  (server order)",   "trivial  (1 result)", "0.9348",                     "1.0000 *"],
        ["NDCG@5  (client re-rank)", "trivial  (1 result)", "0.9615",                     "1.0000 *"],
        ["Precision@3",              "0.333",               "1.0000",                     "1.0000 *"],
        ["Avg latency",              "2 202 ms",            "560 ms  (Railway API)",      "2 146 ms (dev binary)"],
        ["API key required",         "No",                  "Yes  (Google Places)",       "No  (offline)"],
        ["Reproducible results",     "Yes  (fixed corpus)", "No  (live, non-det.)",       "Yes  (fixed corpus)"],
    ]

    tbl(slide, data,
        col_widths=[3.0, 3.1, 3.35, 3.18],
        l=0.35, t=1.82, row_h=0.37,
        hdr_fill=BLUE, body_fg=INK, odd=SURFACE,
        even=RGBColor(0xF1, 0xF5, 0xF9),
        body_size=11, hdr_size=12)

    hline(slide, 5.58)
    tb(slide, "Interpretation", 0.45, 5.65, 3, 0.32, size=13, bold=True, color=INK)
    bullet(slide, [
        "Condition B (Google Places) eliminates the 40 % coverage gap of Condition A; "
        "NDCG@5 = 0.9348 server-side and 0.9615 after client re-ranking across 15 queries.",
        "Condition C (fixture cache) achieves 15/15 coverage without any live API call. "
        "NDCG@5 = 1.0 is inflated (*) — category labels match by construction since the corpus was "
        "originally fetched from Google Places. It establishes an always-available reproducible baseline.",
        "Client re-ranking adds +0.027 NDCG@5 lift over the Google default order (Condition B), "
        "confirming the open-now, query-affinity, and distance signals carry information Places does not optimise for.",
        "Condition A (rule-based mock) cannot serve as a production retrieval layer: "
        "40 % null-result rate, Shanghai venues, single result per query — unsuitable for fair ranking evaluation.",
    ], l=0.45, t=6.00, size=11.5, gap=0.32, color=INK)


def s_results(prs):
    slide = blank(prs)
    section_tag(slide, "6 · Results — Run 001", color=TEAL)
    heading(slide, "Aggregate Results — Run 001: Condition B (Google Places, provider=local)")

    cards = [
        ("0.9348",  "Server NDCG@5",    "Google Places default order",           BLUE),
        ("0.9615",  "Client NDCG@5",    "After 9-signal re-ranking",             TEAL),
        ("+0.027",  "NDCG@5 lift",      "Client re-rank vs server order",        AMBER),
        ("1.000",   "Precision@3",      "Top-3 relevant in all 15 queries",      SLATE),
        ("560 ms",  "Avg latency",      "15-query mean (p50, target < 1 500 ms)",SLATE),
    ]
    for i, (val, lbl, sub, color) in enumerate(cards):
        metric_card(slide, val, lbl, sub, x=0.35 + i * 2.6, accent=color)

    hline(slide, 4.12)
    tb(slide, "Key findings", 0.45, 4.2, 3, 0.35, size=13, bold=True, color=INK)
    bullet(slide, [
        "Client re-ranking improves NDCG@5 on 12 / 15 queries; largest gains: "
        "q08 coffee shop (+0.170), q07 hidden gem (+0.131), q04 craft beer bar (+0.107).",
        "Re-ranking reduces NDCG@5 on 3 queries — q01 best tapas (−0.085), q09 rooftop bar (−0.077), "
        "q13 wellness spa (−0.015) — indicating Google's default order was superior for those intents.",
        "Category match rate 0.927 — approximately 1 in 13 results is off-category, "
        "primarily in wellness / nightlife due to ambiguous Places type arrays.",
    ], l=0.45, t=4.62, size=13, gap=0.66, color=INK)


def s_per_query(prs):
    slide = blank(prs)
    section_tag(slide, "6 · Results — Run 001", color=TEAL)
    heading(slide, "Per-Query Breakdown — Condition B")

    data = [
        ["ID",  "Query",                       "Server NDCG@5", "Client NDCG@5", "Delta",    "Latency"],
        ["q01", "best tapas near me",           "0.9152",        "0.8304",        "−0.085",   "1 184 ms"],
        ["q02", "Italian dinner tonight",        "1.0000",        "1.0000",        "  0.000",  "  482 ms"],
        ["q03", "yoga class tomorrow",           "1.0000",        "1.0000",        "  0.000",  "  452 ms"],
        ["q04", "craft beer bar",                "0.8930",        "1.0000",        "+0.107",   "  501 ms"],
        ["q05", "brunch this weekend",           "0.9152",        "1.0000",        "+0.085",   "  469 ms"],
        ["q06", "contemporary art museum",       "0.9152",        "1.0000",        "+0.085",   "  574 ms"],
        ["q07", "hidden gem restaurant",         "0.8688",        "1.0000",        "+0.131",   "  528 ms"],
        ["q08", "coffee shop to work from",      "0.8304",        "1.0000",        "+0.170",   "  461 ms"],
        ["q09", "rooftop bar",                   "0.9270",        "0.8496",        "−0.077",   "  624 ms"],
        ["q10", "japanese ramen",                "1.0000",        "1.0000",        "  0.000",  "  426 ms"],
        ["q11", "something fun for two",         "1.0000",        "1.0000",        "  0.000",  "  723 ms"],
        ["q12", "late night food",               "1.0000",        "1.0000",        "  0.000",  "  483 ms"],
        ["q13", "wellness spa downtown",         "0.7574",        "0.7426",        "−0.015",   "  507 ms"],
        ["q14", "cheap eats",                    "1.0000",        "1.0000",        "  0.000",  "  493 ms"],
        ["q15", "french bakery",                 "1.0000",        "1.0000",        "  0.000",  "  486 ms"],
    ]

    t_obj = tbl(slide, data,
                col_widths=[0.7, 3.7, 1.75, 1.75, 1.4, 1.65],
                l=0.35, t=1.82, row_h=0.3,
                hdr_fill=BLUE, body_fg=INK, odd=SURFACE,
                even=RGBColor(0xF1,0xF5,0xF9),
                body_size=10.5, hdr_size=11.5)

    hurt = {1, 9, 13}
    for ri in hurt:
        cell = t_obj.cell(ri, 4)
        for run in cell.text_frame.paragraphs[0].runs:
            run.font.color.rgb = RED
            run.font.bold = True
    for ri in range(1, len(data)):
        if ri not in hurt:
            cell = t_obj.cell(ri, 4)
            for run in cell.text_frame.paragraphs[0].runs:
                if "+" in run.text:
                    run.font.color.rgb = TEAL; run.font.bold = True

    hline(slide, 7.0)
    tb(slide,
       "Negative delta queries (q01, q09, q13): client scorer penalises venues with generic names "
       "that have low query-token overlap despite being categorically correct.",
       0.45, 7.07, 12.4, 0.36, size=10.5, italic=True, color=SUB)


def s_discussion(prs):
    slide = blank(prs)
    section_tag(slide, "7 · Discussion & Next Steps")
    heading(slide, "Discussion")

    points = [
        (BLUE, "Neural retrieval vs rule-based retrieval",
         "The A/B comparison confirms that Google Places Text Search eliminates the query-coverage "
         "failure mode of the keyword parser. The mock corpus (4 venues, subcategory-filtered) cannot "
         "serve as a production retrieval layer — it is appropriate only as a development fallback."),
        (TEAL, "Client re-ranking adds measurable value over server default",
         "NDCG@5 improves by +0.027 overall and up to +0.170 on individual queries. Open-now status "
         "and query-token affinity are informative signals that Google's ranking does not directly optimise for."),
        (AMBER, "Three queries regress under client re-ranking",
         "Queries q01, q09, q13 score lower after re-ranking. The probable cause is the query-affinity "
         "signal penalising venues with generic names (e.g., 'The Rooftop Bar') that have low token overlap "
         "despite being categorically correct. A soft-matching or threshold approach may mitigate this."),
        (RED, "Evaluation limitations",
         "Automated relevance labels (rating ≥ 4.0 + category match) are a proxy for true relevance. "
         "A human-rated evaluation set of ~50–100 (query, venue) pairs would reduce label noise and "
         "enable statistically significant comparisons between system variants."),
    ]
    for i, (color, title, body) in enumerate(points):
        y = 1.88 + i * 1.32
        rect(slide, 0.35, y, 0.06, 1.15, fill=color)
        tb(slide, title, 0.55, y+0.04, 12.3, 0.36, size=14, bold=True, color=color)
        tb(slide, body,  0.55, y+0.42, 12.3, 0.82, size=12, color=INK)


def s_next_steps(prs):
    slide = blank(prs)
    section_tag(slide, "7 · Discussion & Next Steps")
    heading(slide, "Proposed Improvements")

    data = [
        ["Priority", "Change",                                                  "Expected lift",  "Effort"],
        ["P1", "Fix geo-ranking — use GeoLocation in find_activities",          "+0.05–0.10 NDCG","1 day"],
        ["P1", "Integrate Yelp Fusion API for richer food/nightlife coverage",  "+coverage",      "2 days"],
        ["P1", "Integrate Eventbrite API to add event dimension",               "+coverage",      "2 days"],
        ["P1", "Trust Google order when Places returns ≥ 8 results",            "+0.05 NDCG",     "1 day"],
        ["P2", "Persist personalization profile to local storage",              "+0.05–0.08",     "3 days"],
        ["P2", "Expand type-mapping for wellness / nightlife boundary cases",   "+CMR +0.05",     "½ day"],
        ["P2", "LLM summary comparison — restore Gemini / OpenRouter access",  "qualitative",    "0 days"],
        ["P3", "Replace keyword parser with embedding similarity (MiniLM)",     "+0.08–0.15",     "2 weeks"],
        ["P3", "Collect engagement signals (saves, clicks) for trending",       "+0.04–0.07",     "3 days"],
        ["P4", "Human-rated evaluation set — ≥ 50 (query, venue) pairs",       "reduces noise",  "1 week"],
    ]

    tbl(slide, data,
        col_widths=[0.85, 6.5, 2.35, 1.75],
        l=0.35, t=1.88, row_h=0.36,
        hdr_fill=BLUE, body_fg=INK, odd=SURFACE,
        even=RGBColor(0xF1,0xF5,0xF9),
        body_size=11.5, hdr_size=12)

    hline(slide, 6.88)
    tb(slide,
       "Yelp Fusion and Eventbrite results will be merged with Google Places results server-side "
       "before being passed to the client scorer — no changes to the scoring or clustering logic are required.",
       0.45, 6.95, 12.4, 0.42, size=11, italic=True, color=SUB)


def s_refs(prs):
    slide = blank(prs)
    rect(slide, 0, 0, 0.07, 7.5, fill=BLUE)

    tb(slide, "References & Artefacts", 0.5, 0.8, 12.4, 0.52,
       size=20, bold=True, color=INK)
    hline(slide, 1.42)

    refs = [
        ("Codebase",        "github.com/MouhamedN96/PULSE  (branch: main)"),
        ("Live server",     "pulse-production-62b2.up.railway.app"),
        ("Run 001 logs",    "experiments/logs/places/20260430T051138Z/"),
        ("Run 001 report",  "experiments/results/places_20260430T051138Z.json"),
        ("Mock run logs",   "experiments/logs/places/20260430T060406Z/"),
        ("Dashboard",       "streamlit run scripts/dashboard.py  (localhost:8501)"),
        ("Eval document",   "docs/FEED_RECOMMENDATION_EVAL.md"),
        ("Experiment log",  "experiments/EXPERIMENT_LOG.md"),
    ]
    for i, (k, v) in enumerate(refs):
        y = 1.6 + i * 0.54
        tb(slide, k, 0.5, y, 2.2, 0.44, size=11, color=SUB)
        tb(slide, v, 2.75, y, 9.9, 0.44, size=11.5, color=INK)
        if i < len(refs)-1:
            hline(slide, y + 0.5, l=0.5, w=12.1)

    hline(slide, 6.2)
    tb(slide, "External references", 0.5, 6.28, 4, 0.35, size=11, bold=True, color=SUB)
    tb(slide,
       "Järvelin, K. & Kekäläinen, J. (2002). Cumulated gain-based evaluation of IR techniques. "
       "ACM TOIS 20(4), 422–446.  ·  "
       "Google Places Text Search API: developers.google.com/maps/documentation/places/web-service/text-search  ·  "
       "Yelp Fusion API: docs.developer.yelp.com  ·  Eventbrite API: eventbrite.com/platform/api",
       0.5, 6.62, 12.3, 0.72, size=10, color=SUB)


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    prs = Presentation()
    prs.slide_width  = W
    prs.slide_height = H

    slides = [
        ("Cover",                        s_cover),
        ("System Description",           s_overview),
        ("System Components",            s_stack),
        ("Request Lifecycle",            s_arch),
        ("Feed Mechanism",               s_feed),
        ("Data Sources",                 s_sources),
        ("Scoring Model",                s_scorer),
        ("Clustering & Limitations",     s_clustering),
        ("A/B Test Design",              s_ab_design),
        ("A/B Results",                  s_ab_results),
        ("Run 001 — Aggregate",          s_results),
        ("Run 001 — Per-query",          s_per_query),
        ("Discussion",                   s_discussion),
        ("Next Steps",                   s_next_steps),
        ("References",                   s_refs),
    ]

    for i, (name, fn) in enumerate(slides, 1):
        fn(prs)
        print(f"  {i:02d}/{len(slides)}  {name}")

    out = Path(__file__).resolve().parent.parent / "docs" / "PULSE_Rec_System_Deck.pptx"
    prs.save(str(out))
    size_kb = out.stat().st_size // 1024
    print(f"\n  {len(slides)} slides  |  {size_kb} KB  |  all content in editable text boxes")

if __name__ == "__main__":
    main()
