# shmuelie-authoring

Technical authoring: rigorous RFC-style specifications and evidence-based
readability analysis.

**Version:** 0.2.1

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-authoring@shmuelie-skills
```

Update or remove:

```text
copilot plugin update shmuelie-authoring
copilot plugin uninstall shmuelie-authoring
```

## Skills

### ietf-rfc-authoring

Produce documents that read like an RFC: the recognizable section structure, BCP
14 (RFC 2119) keyword conventions (MUST/SHOULD/MAY), ABNF grammar notation, and
text/HTML rendering with kramdown-rfc (Markdown → RFC XML v3) and xml2rfc. This
is about style and format for internal or personal specifications, not IETF
submission.

### writing-level-analysis

Measure the readability of text you provide or identify locally: Flesch-Kincaid
grade level plus corroborating indices (Flesch Reading Ease, Gunning Fog,
Coleman-Liau, ARI). It reports per-source results, recomputes combined metrics
from the full cleaned corpus, states the library used, and never assumes access
to private mail or organization systems.

## Example requests

```text
Turn this protocol design into an RFC-style specification.
Review these requirements for correct MUST, SHOULD, and MAY usage.
Add ABNF for this message format.
Measure the reading grade of these Markdown files.
Compare the readability of these two document revisions.
```

## Optional tooling

- `kramdown-rfc` and `xml2rfc` for rendered RFC-style output.
- A readability library such as Python `textstat`.

## Changelog

Each skill has its own `CHANGELOG.md`; marketplace-wide history is in the
[repository changelog](../../../CHANGELOG.md).
