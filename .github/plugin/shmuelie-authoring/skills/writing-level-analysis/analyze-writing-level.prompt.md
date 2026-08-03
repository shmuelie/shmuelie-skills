---
description: "Measure my Flesch–Kincaid writing level across my own authored text (Copilot prompts, sent email, ADO PRs) and save a shareable markdown report. Use when asked for my writing level, readability score, or how hard my writing is to read."
---

# Analyze Writing Level

Measure the user's readability across their authored text following the `writing-level-analysis` skill, and save a shareable report.

## Steps

1. **Confirm scope and destination** — default to all three sources (Copilot prompts, sent email, ADO PRs) and `~/flesch-kincaid-writing-level.md`. If the user named a narrower scope or a different path, use it. Verify `textstat` is available (`python -c "import textstat"`); install it if missing.

2. **Extract Copilot prompts** — query the **local** session store (`source: "local"`, SQLite syntax; the cloud store is incomplete for this and errors intermittently):
   ```sql
   SELECT session_id, turn_index, user_message
   FROM turns WHERE user_message IS NOT NULL AND length(user_message) > 0
   ```
   Note the raw turn count and distinct session count for the methodology section.

3. **Extract email** — via the `workiq` MCP, fetch **sent** messages. Keep only the top authored portion of each: drop quoted reply threads and signatures.

4. **Extract ADO PR text** — via the `ado` MCP, fetch pull requests authored by the user (filter on their address) and take description + title.

5. **Clean every source before scoring** — strip fenced/inline code, file paths, URLs, markdown/HTML, and injected framing tags (`<system_reminder>`, `<skill-context>`, …). Drop bare slash-commands, predominantly non-prose lines (code/logs), and anything left empty. Record how many items survived per source.

6. **Score with `textstat`** — per source **and** combined: `flesch_kincaid_grade` and `flesch_reading_ease` (headline), plus `gunning_fog`, `smog_index`, `automated_readability_index`, `coleman_liau_index`, `dale_chall_readability_score` (corroborating). Also compute average words per sentence and syllables per word.
   **Join the cleaned items as-is (blank-line separated) — never append a period to every prompt.** Forcing terminal punctuation makes each imperative its own sentence and halves the grade (measured: FK 13.94 as-is vs 6.62 with forced periods on the same sample).

7. **Sanity-check** — a technical author usually lands near grade 11–14 with reading ease in the 30s–40s. A result near grade 6 / ease 70 means periods were forced onto prompts; a wildly different number otherwise means cleaning leaked code or quoted text. Fix and re-score before writing the report.

8. **Assemble the report** in this order: Title + date/author → **Result** (headline grade, plain-language meaning, total words) → **per-source table** (Source | Items | Words | FK Grade | Reading Ease + Combined row) → **What it means** (drivers, technical-vocabulary effect) → **Corroborating indices** → **Methodology** (tooling, extraction, cleaning) → **Caveats**.
   State explicitly that prompts dominate the word count, so the combined score ≈ the prompt score, and that the email/PR samples are small and less stable. Include the ±1 grade-level caveat.

9. **Save and report back** — write the markdown to the chosen path and tell the user the path plus the headline grade.
