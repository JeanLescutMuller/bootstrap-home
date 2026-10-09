# The README — for a human, graphical

Written to be understood **years later by someone who has forgotten everything**. Diagrams, not prose: a pipeline is a diagram, a folder map is a tree, a comparison is a table. Prose ≤ ~150 words; **no limit on diagrams**. Agents are not required to read it.

## It shows things; `AGENTS.md` states rules

That split is what keeps the two from drifting apart:

| | README owns | `AGENTS.md` owns |
|---|---|---|
| | **entities** — files, folders, arrows, what calls what, what flows where, status (live / partial / broken / planned) | **assertions** — rules, thresholds, tunable values, traps |
| must never contain | an imperative about the code, or a tunable number (a timeout, a worker count) | diagrams for a human |

Structural counts ("four stages") are entities and are fine. A standing footer pointing at `AGENTS.md` and `TODO.md` is navigation, not a rule. **When a file is renamed, check whether a README diagram names it.**

In Mermaid, use `classDef` to carry status as colour and put real filenames on the nodes and edges. Check [`mermaid_playground.md`](mermaid_playground.md) before using an unusual diagram type.

## `README.md` or `README.html` — you decide

| Signal | `README.md` (default) | `README.html` pays off |
|---|---|---|
| components | one tool, a few files | several stages or services |
| flows | one linear pipeline | data crossing machines, stages with states |
| status | one status for the whole | per-component status |
| reader | the author, quickly | the author after months, or someone new |

GitHub and VS Code render a `README.md` automatically but show a `README.html` as raw code, so **a `README.html` always comes with a 3-line `README.md` stub** that names the project and links to it (short variant at the bottom of [`../templates/README.template.md`](../templates/README.template.md)).

### Building a `README.html`

Example on this machine: `~/dev/agent-quota-maximizer/design/PIPELINE_MAP.html`. Starting point: [`../templates/README.template.html`](../templates/README.template.html).

- **Same content rule: entities only.** Agents do not read it, so a rule placed only here is lost.
- **One self-contained file** that opens with a double-click (`open README.html`): CSS and JS inline, no build step, no server. A CDN library only with an **exact pinned version** (`mermaid@10.9.1`, never `@latest`). Hand-drawn inline SVG needs no library and works offline — prefer it for the main diagram.
- **Light and dark**: colours as CSS variables on `:root`, redefined under `@media (prefers-color-scheme: dark)`.
- **Status as colour, with a legend**, using the same four statuses everywhere: live, partial, broken, planned.
- **Real filenames on boxes and edges**, so the page can be checked against the tree.
- **No secrets, no production data**: the page may be shared (Claude can publish it as a private claude.ai artifact; the repo file stays the source).
- **Sections:** header (name, one-line purpose, last-updated date) · the big picture (one diagram) · folder map · per-component status with legend · footer linking `AGENTS.md`, `TODO.md`, the design files.
