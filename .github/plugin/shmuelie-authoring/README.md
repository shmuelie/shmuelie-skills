# shmuelie-authoring

Technical-authoring skills for RFC-style specifications and evidence-based
readability analysis.

**Version:** 0.2.1

**Catalog:** [`shmuelie-skills`](../../../README.md)

**Changelog:** [`CHANGELOG.md`](../../../CHANGELOG.md)

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-authoring@shmuelie-skills
```

```text
copilot plugin update shmuelie-authoring
copilot plugin uninstall shmuelie-authoring
```

## Skills

| Skill | Use it for |
|---|---|
| [`ietf-rfc-authoring`](skills/ietf-rfc-authoring/SKILL.md) | Structure protocol specifications, apply BCP 14 terminology, write ABNF, and render RFC-style text or HTML |
| [`writing-level-analysis`](skills/writing-level-analysis/SKILL.md) | Measure Flesch-Kincaid and supporting readability indices for user-provided or locally authored text |

## Example requests

```text
Turn this protocol design into an RFC-style specification.
Review these requirements for correct MUST, SHOULD, and MAY usage.
Add ABNF for this message format.
Measure the reading grade of these Markdown files.
Compare the readability of these two document revisions.
```

## Optional tooling

- `kramdown-rfc` and `xml2rfc` for rendered RFC-style output
- Python `textstat` or another declared readability library

The readability skill analyzes only text the user supplies or identifies
locally. It does not assume access to private mail or organization systems.
