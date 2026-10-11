---
name: data-moves
description: How to move, copy, deduplicate or delete data across this user's machines (Mac, VM H-Frank-1, NAS babisnas) without losing anything. Use for any data migration, backup, cleanup of large folders, or delete that cannot be undone.
---

# Moving or deleting data

1. **Compare by content hash, never by opening files**: one manifest per machine (path, size, mtime, MD5), each machine hashing its own disk, all in parallel, run detached (`nohup`; on the Mac under `caffeinate`).
2. **Remove duplicates before compressing.** Never delete before the destination copy is checked by MD5, read back where it landed.
3. **Delete in batches, each shown and approved first**, with a dry run; re-check every file just before unlinking it.
4. Before the biggest irreversible delete, do **one more independent check** unprompted: re-hash from scratch, look every file up in the backup's own lists.
5. Ask before overwriting a secret (e.g. `credentials.json`); never print it, compare hashes only.

Report each phase as a short table, then ask before the next one.

Reusable tools: `~/dev/trading-bot/doc/data_inventory/tools/` (`hasher.py`, `snapwriter.py`, `snapcheck.py`, `delete_batch.py`); the 2026-10-10 migration that used them (23 M files, 0 lost): `~/dev/trading-bot/doc/data_inventory/migration_plan.md`.

Traps: `ssh host "cd X && nohup cmd &"` keeps ssh open (use `cd X || exit; nohup …`); a duckdb join with `OR` or a correlated subquery can hang (use equality joins on precomputed keys).
