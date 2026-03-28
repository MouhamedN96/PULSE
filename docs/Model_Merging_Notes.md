# Model Merging.pdf - Practical Notes for STROLL

Source reviewed: `C:\Users\momo-\OneDrive\Desktop\YAATAL\R&D\Model Merging.pdf`

## Key takeaways from the paper

- The paper argues that **directly merging FocalCodec + LFM2-Audio** is possible but likely a quality tradeoff.
- A stronger path is a **layered architecture**:
  - ultra-compact tokenizer (FocalCodec),
  - lightweight contextualizer for retrieval embeddings,
  - small reasoning model for decision logic.
- For constrained devices, memory budgeting and inference latency dominate model choices.
- Retrieval quality can improve by avoiding brittle ASR cascades in low-resource/code-switching contexts.

## What this means for STROLL V1

- Keep V1 architecture simple:
  - Rust recommendation pipeline + SQLite persistence + typed Flutter bridge.
- Use cloud LLMs only for **summary enhancement** and keep local recommendation logic deterministic.
- Treat advanced model-merging ideas as **R&D track**, not a V1 dependency.

## Cloud AI setup direction

- For low-cost experimentation, OpenRouter default model is set to:
  - `liquid/lfm-2.5-1.2b-instruct:free`
- For cloud quality testing, Gemini provider is now supported:
  - `provider: "gemini"` in `/api/recommend`
  - env: `GEMINI_API_KEY`, optional `GEMINI_MODEL`, `GEMINI_ENDPOINT`

## Suggested experiment plan (post-V1)

1. Baseline recommendation quality with local summaries (`provider=local`).
2. Compare summary quality/cost/latency:
   - OpenRouter LFM free vs Gemini Flash.
3. Log prompt + output metrics (latency, token cost proxy, user click/save).
4. Use results to decide cloud fallback policy and future agent memory upgrades.
