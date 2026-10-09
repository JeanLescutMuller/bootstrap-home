<!-- Loaded by EVERY session working in this folder or below: every word costs on every turn. Aim ≤ 400 words, never above ~600, not counting ## Vocabulary. Rules and pointers only; evidence goes in doc/ or TODO.md. Never repeat a parent AGENTS.md. Then: ln -sfn AGENTS.md CLAUDE.md -->

# <project-name>

**<One line: the purpose, in the user's words.>**

## Rules

- **<Imperative rule.>** <One sentence of why, if not obvious.> → [`doc/<subject>.md`](doc/<subject>.md) §<n>
- **Do not touch <file/area>** without <condition>. → [`DESIGN.md`](DESIGN.md) §<n>

## Commands

| | |
|---|---|
| test | `bash test/run.sh` |
| deploy | `bash release/install.sh` |

## Vocabulary

The only words for these concepts, in every file and when talking to the user. A new word is added here first, with the user's agreement.

| Word | Means | Never say |
|---|---|---|
| **<word>** | <one line; a measured quantity names its unit> | <synonyms agents drift to; words removed by a rename> |

## Where to look

| | |
|---|---|
| open work | [`TODO.md`](TODO.md) |
| how <subject> works | [`doc/<subject>.md`](doc/<subject>.md) |
| why it is built this way | [`DESIGN.md`](DESIGN.md) |
