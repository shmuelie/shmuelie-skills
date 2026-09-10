---
description: "Generate a Copilot CLI Playbook — a teaching guide for how you drive the agent, including delegated-work supervision habits, with copyable real prompts from session history. Use when asked to create a playbook, a prompting playbook, or a 'how I use Copilot' teaching guide."
---

# Generate Copilot Playbook

Create a Copilot CLI Playbook following the `copilot-playbook` skill.

## Steps

1. **Read the latest usage report** — `Get-ChildItem Reports\*-copilot-usage-report.md | Sort-Object Name | Select-Object -Last 1`. Take the volume line ("~N sessions / M+ prompts") and note which behavioral patterns are most prominent (verb-pattern table + Key Behavioral Patterns). If none exists, generate one first via the `copilot-usage-report` skill.
2. **Mine session history for real prompts** — run the per-pattern `session_store_sql` queries from the skill **one at a time** (a wide multi-`UNION` query times out), each time-filtered with `ORDER BY RANDOM() LIMIT` and `length BETWEEN 12 AND 90`. Collect 3-5 verbatim, deduped, copyable prompts per pattern: plan→implement, commit granularity, delegated-work supervision, ask-before-act, terse corrections, PR lifecycle, skills/memory, verification.
3. **Order the lessons** by prominence for this user (from the usage report), keeping the durable core set.
4. **Write each lesson** as `principle → why it works → real prompts (verbatim, in backticks) → > teaching point`, `---`-separated. Drop any lesson with no good real examples.
5. **When supervision prompts exist, add the delegated-work lesson** — teach bounded delegation for longer background work: state the objective, allowed scope, non-goals, completion criteria, and expected evidence; ask for milestone updates with completed work, blockers, and next step; distinguish inline synchronous tasks from longer background work; rely on supported notifications or task-appropriate delayed check-ins instead of tight polling; explain the safe response to success, blockers, drift, and unavailable live progress.
6. **Add the Quick-Start Checklist** — one actionable line per lesson.
7. **Close** with the pointer to the usage report for the numbers.
8. **Save** to `Reports/<YYYY-MM-DD>-copilot-playbook.md`. If a prior playbook exists, refresh prompts/volume and note it supersedes the earlier one.
