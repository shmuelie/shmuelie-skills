---
description: "Generate a comprehensive session report for the current or a specified session. Covers tools, skills, problem/solution, files, testing, learnings, tool assessments, and pending work."
---

# Generate Session Report

Create a detailed session report following the `copilot-session-report` skill template.

## Steps

1. **Identify the session** — use the current session ID, or ask the user which session to report on
2. **Run all 9 queries** from the skill against `session_store_sql`
3. **Reconstruct the narrative** from user messages — what was asked, in what order
4. **Fill in the template** sections:
   - Header with session ID, dates, work item/PR links, model
   - Tools and skills breakdown with purpose annotations
   - Problem statement derived from first user message
   - Solution approach from assistant responses
   - Files modified with line counts and descriptions
   - Testing results (unit, E2E, regression)
   - Key learnings — gotchas and workarounds
   - Tool assessment — evaluate testing, automation, or other tools that were or weren't used
   - Pending work items
5. **Save** to `~/.copilot/session-state/<id>/files/session-report.md`
6. **Open** in VS Code for review
