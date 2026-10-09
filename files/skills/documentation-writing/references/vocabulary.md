# Vocabulary — the user's words, one concept one word

- **Use the user's own words** for what they named. Do not coin a new term when an ordinary phrase works; if one is genuinely needed, define it in one line the first time it appears.
- **One concept, one word, for the whole project.** Renaming a concept mid-project is a bug: the same word ends up meaning different things in different files. If a rename is truly needed, do it everywhere in one commit, lower level first, and record the removed word.
- **No name without its unit and its span** for anything measured (`week_used_pct`, not `used`).

## Where the words live — split by cost

| Where | What |
|---|---|
| `AGENTS.md` | the ~10 core words every session will meet, as a two-column table, plus a pointer to `VOCABULARY.md` |
| `VOCABULARY.md` | the full list: field names, units, notation and formula symbols, the naming grammar, words removed and why |

The full list does not fit in `AGENTS.md`: real ones on this machine are 3,000–3,800 words, 7–9× its budget. Put `VOCABULARY.md` in `design/` during the design stage, in `doc/` once the code exists; `REQUIREMENTS.md` may carry its own small table of user-facing words.

Template: [`../templates/VOCABULARY.template.md`](../templates/VOCABULARY.template.md). Example: `~/dev/agent-quota-maximizer/design/VOCABULARY.md` (a naming grammar, plus "words removed").
