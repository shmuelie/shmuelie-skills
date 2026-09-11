---
description: Analyze the readability and reading grade of user-provided or locally authored text
---

Analyze my writing level:

1. Ask me to identify the text, files, or directories to analyze if they are not
   already provided.
2. Include only text I authored.
3. Remove code, logs, quoted material, generated boilerplate, and URLs unless I
   explicitly want them included. Preserve punctuation in retained prose and
   leave original sources unchanged; do not append periods to fragments or
   records. State the exclusions and the separator used to assemble the corpus.
4. Calculate Flesch-Kincaid Grade Level, Flesch Reading Ease, Gunning Fog,
   Coleman-Liau, and Automated Readability Index.
5. Report library/version, language, word/sentence/syllable counts, sample
   sizes and per-document results, then recompute combined metrics from the
   complete cleaned corpus rather than averaging document scores.
6. Explain which writing patterns increase or decrease readability. Investigate
   preprocessing and segmentation before attributing suspicious score shifts to
   writing quality; label tiny samples and sensitivity comparisons clearly.
7. Save a concise Markdown report when I request an output file.
