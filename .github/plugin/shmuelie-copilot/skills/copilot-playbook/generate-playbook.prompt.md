---
description: "Generate a Copilot CLI Playbook — a teaching guide for how you drive the agent, with copyable real prompts from session history. Use when asked to create a playbook, a prompting playbook, or a 'how I use Copilot' teaching guide."
---

# Generate Copilot Playbook

Create a Copilot CLI Playbook following the `copilot-playbook` skill.

## Steps

1. **Read the latest usage report** — `Get-ChildItem Reports\*-copilot-usage-report.md | Sort-Object Name | Select-Object -Last 1`. Take the volume line ("~N sessions / M+ prompts") and note which behavioral patterns are most prominent (verb-pattern table + Key Behavioral Patterns). If none exists, generate one first via the `copilot-usage-report` skill.
2. **Mine session history for real prompts** — run the per-pattern `session_store_sql` queries from the skill **one at a time** (a wide multi-`UNION` query times out), each time-filtered with `ORDER BY RANDOM() LIMIT` and `length BETWEEN 12 AND 90`. Collect 3-5 verbatim, deduped, copyable prompts per pattern: plan→implement, commit granularity, ask-before-act, terse corrections, PR lifecycle, skills/memory, verification.
3. **Order the lessons** by prominence for this user (from the usage report), keeping the durable core set.
4. **Write each lesson** as `principle → why it works → real prompts (verbatim, in backticks) → > teaching point`, `---`-separated. Drop any lesson with no good real examples.
5. **Add the Quick-Start Checklist** — one actionable line per lesson.
6. **Close** with the pointer to the usage report for the numbers.
7. **Save** to `Reports/<YYYY-MM-DD>-copilot-playbook.md`. If a prior playbook exists, refresh prompts/volume and note it supersedes the earlier one.
