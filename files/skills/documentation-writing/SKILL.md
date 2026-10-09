---
name: documentation-writing
description: Personal documentation conventions for every project on this machine — README.md / README.html for humans, AGENTS.md for agents (CLAUDE.md is a symlink to it), TODO.md, doc/ companion files, the design-stage files (CONSIDERATIONS.md, REQUIREMENTS.md, DESIGN.md, VOCABULARY.md), and Markdown formatting (one paragraph = one line). Use when writing or editing any .md file or HTML README, when designing or scoping a new project, when setting up or reorganising a project's documentation, or when managing a TODO.md.
---

# Documentation writing

This file holds only what every documentation task needs. **Read a reference file only when your task matches its row below** — the rest is not for you.

## Always: how to write

- **One paragraph, one physical line — never hard-wrap mid-sentence**, not even to stay under 80 columns: some Markdown viewers render every newline as a line break, so a wrapped paragraph appears chopped. No trailing double-space breaks either; a real break is a blank line. Headings, table rows, list items (one line each), fenced code and horizontal rules keep their own lines. Before finishing, join any paragraph that spans several source lines.
- **Show, don't narrate.** A comparison or set of values is a table; a sequence or hierarchy is a diagram; prose is the fallback. Explain with a worked numeric example.
- **Mermaid only in a README**; everywhere else ASCII/UTF-8 box-drawing, because agents read those files as plain text.
- **Use the user's own words; one concept, one word**, for the whole project. Renaming a concept is a bug.
- **Cite the primary source** (the code file, the platform's own docs) by its full repo path. **State what was verified and how** ("verified 2026-10-07 against `7f1479d`"); dates are absolute.

## The files, and which reference to read

| File | For | In one line | Read when your task is… |
|---|---|---|---|
| `AGENTS.md` (+ `CLAUDE.md` symlink) | agents | rules only — **loaded by every session**, so kept small | writing or editing one → [`references/agents_md.md`](references/agents_md.md) |
| `README.md` / `README.html` | humans | diagrams of what exists and what calls what; no rules | writing or editing one → [`references/readme.md`](references/readme.md) |
| `TODO.md` | both | open items only, sorted by priority, stable IDs | adding, re-sorting or closing an item → [`references/todo_md.md`](references/todo_md.md) |
| `CONSIDERATIONS.md` → `REQUIREMENTS.md` → `DESIGN.md` | both | what might matter → what the user gets → what we build and how | designing or scoping a project → [`references/design_files.md`](references/design_files.md) |
| `VOCABULARY.md` | both | every word of the project, its meaning and unit | naming things, adding a word → [`references/vocabulary.md`](references/vocabulary.md) |
| `doc/` | both | companion files for the production code | setting up a project's docs, adding a `doc/` file, moving or renaming files → [`references/project_layout.md`](references/project_layout.md) |

Choosing a Mermaid diagram type → [`references/mermaid_playground.md`](references/mermaid_playground.md) (what the viewers on this machine actually render). A file from scratch → copy it from [`templates/`](templates/) (`<NAME>.template.md`, `README.template.html`).

## Before finishing a structural change

After creating, moving or renaming documentation files, run the checker and fix every `FAIL`:

```bash
bash ~/.claude/skills/documentation-writing/check_docs.sh <project-root>
```
