# `TODO.md` — open items only, sorted by priority

A `TODO.md` answers one question: **what is still open, and in what order?** Template: [`../templates/TODO.template.md`](../templates/TODO.template.md).

## Closing an item: delete it, after moving what it taught

**No `## Done` section, no `✅` entries, no ~~struck-through~~ rows.** They compete with the open items for attention and grow without bound; git keeps the history. Before deleting, check where the durable part goes:

| The finished item holds | Move it to |
|---|---|
| a rule not to undo the fix | that scope's `AGENTS.md` |
| the measurement or evidence behind it | that scope's `doc/` |
| only the fact that it was done | nowhere: git history. Delete it |

## Sorting

- **Highest priority first.** A file with more than a handful of items opens with a priority table: one letter per theme, `A` most urgent, items numbered in priority order inside it (`A1`, `A2`, `B1`…), followed by one paragraph saying **why this order**. Re-sort whenever priorities change.
- **Parked items say so**, with the reason and the condition that would un-park them.

## Writing an item

- **A stable ID** (`<scope>-A1`) so it can be referenced without being restated. If IDs are renumbered, do it in one commit and update every reference (`grep` for the old ID).
- **One bold line stating the problem**, then the evidence (what was measured, where, when), then the next step.
- **In the narrowest scope that owns it**: the `TODO.md` of the deepest folder the item is about. The root `TODO.md` is an index plus genuinely cross-cutting items.
- **Questions only the author can answer** are `Q1`, `Q2`…, filed in the scope they block and indexed in the root `TODO.md`. An item blocked on a question says so, and **an agent does not act on it**.
