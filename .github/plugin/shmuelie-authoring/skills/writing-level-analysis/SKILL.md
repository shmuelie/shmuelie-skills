---
name: writing-level-analysis
description: Measure the readability of your own authored text — Flesch–Kincaid grade level and corroborating indices across Copilot prompts, sent email, and Azure DevOps PRs. Use when asked for my writing level, my Flesch-Kincaid score, a readability analysis, how hard my writing is to read, or the reading grade of my prompts/emails/PRs.
---

When asked to measure writing level, Flesch–Kincaid grade, reading ease, or the readability of authored text, apply this domain knowledge.

# Writing Level Analysis — Domain Knowledge

Measures the readability of **text the user actually wrote** (not text written *to* them, and not agent output). The result is a grade level plus corroborating indices, delivered as a shareable markdown report.

## Corpus — three sources, very unevenly weighted

| Source | Typical scale | Where it comes from |
|---|---|---|
| **Copilot prompts** | ~300k+ words (dominant) | The **local** session store — every user turn |
| **Sent email** | small (hundreds of words) | `workiq` MCP (M365 sent mail) |
| **ADO PR text** | small (a few thousand words) | `ado` MCP — PR descriptions + titles |

> **Prompts are ~99% of the words, so the combined score is essentially the prompt score.** Always report **per-source** grades alongside the combined number, and say plainly that the combined figure is prompt-dominated. Otherwise the small email/PR samples look equally authoritative when they aren't.

### Copilot prompts — use the LOCAL session store
The local store is the machine-complete record of prompts; the cloud store is not, and it 500s intermittently (`bad request: Authorization header is badly formatted`). Query with `source: "local"` (SQLite syntax) and retry/fall back to local if a cloud query errors.

```sql
-- Scale check (local): ~670 sessions / ~4,750 user turns on a well-used machine
SELECT COUNT(DISTINCT session_id) AS sessions, COUNT(*) AS user_turns
FROM turns WHERE user_message IS NOT NULL AND length(user_message) > 0

-- Extract the corpus
SELECT session_id, turn_index, user_message
FROM turns WHERE user_message IS NOT NULL AND length(user_message) > 0
```

Expect raw turns to exceed usable prompts by ~10% — the filtering below drops the rest (e.g. 4,742 raw → 4,226 prose prompts).

### Email (workiq / M365)
Fetch **sent** messages only. Keep just the **top authored portion** of each message — strip quoted reply threads and signatures, or you score other people's writing.

### Azure DevOps (ado MCP)
Pull PRs **filtered to the user's address** (e.g. `author@example.com`) and take the description + title. Don't include PR comments from others.

## Cleaning — the load-bearing step
Readability formulas assume **continuous prose**. Feeding them code, paths, or markup produces nonsense. Before scoring, strip:

- fenced **and** inline code
- file paths and URLs
- markdown and HTML markup
- injected framing tags (`<system_reminder>`, `<skill-context>`, `<invoked_skills>`, etc.)

Then **drop** entirely:
- bare slash-commands (`/skill-scanning`, `/clear`)
- lines that are predominantly non-prose (code, logs, stack traces)
- anything left empty after cleaning

## Scoring — `textstat`
Python [`textstat`](https://pypi.org/project/textstat/) (verified working at **0.7.13**). Score each source separately **and** the combined corpus.

> **Critical — do NOT force terminal punctuation onto prompts.** Join the cleaned items **as-is** (e.g. with blank lines) and let each prompt keep whatever punctuation it has. Appending a `.` to every prompt turns hundreds of imperatives into one-sentence-each, collapsing words-per-sentence and **halving the grade**. Measured on the same 475-prompt sample: concatenated as-is → **FK 13.94**, with forced periods → **FK 6.62**. The as-is figure is the correct one (it matches the ~12 whole-corpus result); the forced-period figure is an artifact.

```python
import textstat
textstat.flesch_kincaid_grade(text)      # headline
textstat.flesch_reading_ease(text)       # headline (0-100, higher = easier)
textstat.gunning_fog(text)               # corroborating
textstat.smog_index(text)
textstat.automated_readability_index(text)
textstat.coleman_liau_index(text)
textstat.dale_chall_readability_score(text)
```

Also compute the **drivers** — average words per sentence and syllables per word — since they explain the grade far better than the number alone.

## Report format
Save as a self-contained, shareable markdown file (default `~/flesch-kincaid-writing-level.md`; honor a user-specified path). Section order that works:

1. **Title + date/author line**
2. **Result** — headline grade in plain language (e.g. "FK Grade ≈ 12.1 (12th-grade / college-entry)") and the total word count
3. **Per-source table** — Source | Items | Words | FK Grade | Reading Ease, with a **Combined** row
4. **What it means** — plain-English reading of the grade and reading-ease band, plus the drivers (words/sentence, syllables/word) and why technical vocabulary inflates syllable counts
5. **Corroborating indices** — the other six indices over the combined corpus
6. **Methodology** — tooling, per-source extraction, and the exact cleaning applied
7. **Caveats** — mandatory (below)

## Caveats to always state
- Formulas were designed for continuous prose. Short imperative prompts ("Fix the conflicts") and embedded technical tokens pull the estimate in **both** directions → treat the grade as **±1 grade level**.
- The prompt corpus is large and statistically robust; **email and PR samples are small**, so their per-source grades are less stable.
- The combined score is prompt-dominated (see above).

## Gotchas
- **Don't report only the combined number** — it hides that one source drowns out the others.
- **Use `source: "local"`** for prompts; the cloud store is incomplete for this purpose and flaky.
- **Extraction/scoring scripts are throwaway.** They're written to temp and don't survive; re-derive them from this recipe rather than hunting for a previous run's script. Only the report artifact persists.
- **Sanity-check the output**: a technical author typically lands around grade 11–14 with reading ease in the 30s–40s ("difficult"). A wildly different result usually means cleaning failed (code or quoted text leaked into the corpus) **or** that terminal punctuation was forced onto every prompt (see the scoring warning) — a grade near 6 with reading ease near 70 is the classic signature of that bug.
- **The local session store is not a plain file you can open.** Reach it through the `session_store_sql` tool with `source: "local"`; there is no `turns` table in the `.db` files under `~/.copilot` (those are caches). Extract via the tool, then score the extracted text.
