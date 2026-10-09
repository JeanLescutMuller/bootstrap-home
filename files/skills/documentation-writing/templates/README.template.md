<!-- For a human, read years later by someone who has forgotten everything. Diagrams, not prose (prose ≤ ~150 words). Entities only: files, folders, arrows, status — never a rule or a tunable number (those live in AGENTS.md). -->
<!-- If this project has a README.html, replace this whole file with the short variant at the bottom. -->

# <project-name>

**<One line: what this does, for whom.>**

## The big picture

```mermaid
flowchart LR
    A["1_ingest<br/><code>ingest.py</code>"] -- "raw.csv" --> B["2_process<br/><code>process.py</code>"]
    B -- "clean.parquet" --> C["3_report<br/><code>report.py</code>"]
    classDef live fill:#d4edda,stroke:#28a745
    classDef broken fill:#f8d7da,stroke:#dc3545
    classDef planned fill:#eeeeee,stroke:#999999,stroke-dasharray: 4 3
    class A,B live
    class C planned
```

<sub>green = live · red = broken · dashed = planned</sub>

## Folder map

```
<project-name>/
├── AGENTS.md          rules for agents (CLAUDE.md → AGENTS.md)
├── TODO.md            open work, by priority
├── doc/               companion files for the code
└── src/               …
```

---
Rules for agents: [`AGENTS.md`](AGENTS.md) · Open work: [`TODO.md`](TODO.md)

<!-- ===== Short variant, when a README.html exists =====
# <project-name>

**<One line: what this does.>** The visual overview is [`README.html`](README.html) — open it in a browser (`open README.html`).

Rules for agents: [`AGENTS.md`](AGENTS.md) · Open work: [`TODO.md`](TODO.md)
-->
