# Copilot Instructions for shmuelie-skills

## Project Overview

This is a Copilot CLI plugin that packages domain knowledge as reusable skills in `skills/*/SKILL.md` files. The plugin is installed via `copilot plugin install shmuelie/shmuelie-skills`.

## Scanning for New Learnings

When asked to scan for new learnings or update skills, follow this process:

1. **Query the session store** for sessions created after the last known sweep date. Use the `sql` tool with `database: "session_store"` to search:
   - `search_index` for technical patterns, conventions, and bug fixes
   - `checkpoints` for detailed technical knowledge
   - `sessions` and `turns` for conversation content
   - Also check WSL session stores at `$HOME/.copilot/session-store.db` via `wsl` commands
   - Also check VS Code chat history at `%APPDATA%/Code/User/workspaceStorage/*/chatSessions/*.jsonl`

2. **Compare against existing skills** in the `skills/` directory to identify:
   - New patterns not yet covered by any skill
   - Updates or corrections to existing skill content
   - Entirely new topic areas that warrant a new skill

3. **Update or create SKILL.md files** with the new knowledge. Each SKILL.md has:
   ```markdown
   ---
   name: skill-name
   description: Brief description
   ---

   Context instructions.

   # Domain Knowledge
   ...
   ```

4. **Bump the version** in both `plugin.json` and `.github/plugin/marketplace.json` following SemVer:
   - PATCH for minor content updates to existing skills
   - MINOR for new skills or significant content additions

5. **Update CHANGELOG.md** following Keep a Changelog format:
   - Add entries under `[Unreleased]` or a new version section
   - Move `[Unreleased]` entries to the new version on release
   - Update comparison links at the bottom

6. **Update README.md** if:
   - A new skill was added (update the Skills table and Project Structure)
   - Source repos changed

7. **Commit and push** with a descriptive message.

## Conventions

- Skills are markdown files at `skills/<name>/SKILL.md`
- Version is tracked in `plugin.json` and `.github/plugin/marketplace.json` — both must stay in sync
- Follow Semantic Versioning for all version bumps
- Follow Keep a Changelog for CHANGELOG.md
- Skill descriptions should be specific and actionable, not vague
- Include code examples, gotchas, and bug patterns — not just general advice
