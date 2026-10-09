---
name: task-management
description: Task management for everything the user and their agents need to do (life and all projects): how to create, hand off, complete and link tasks in Todoist (the current tool), and how to tie them to Gmail, Google Calendar and Contacts with a shared "stream" keyword. Use whenever creating, updating, completing or reviewing a Todoist task, when an agent wants to plan work for a later day, or when filing an email or calendar event that belongs to an ongoing topic (health, admin, home…).
---

# Task management: tasks for the user and agents

**Todoist** (Free plan) is the one exhaustive list of everything the user and the agents must do: life and every project. Life tasks live only in Todoist. Repo tasks live as files in the repo's `TODO/` folder (format below) and are mirrored in Todoist. Gmail, Calendar and Contacts are linked with one shared keyword, the **stream**.

## Vocabulary (use these words, don't invent others)

| Word | Meaning |
|---|---|
| **area** | Top-level category = a Todoist project: `Administrative`, `Health`, `Home`, `Robotics`, `Dev` (one topic per repo, e.g. `Dev - auto-commit`) |
| **stream** | One ongoing topic inside an area, written `<Area> - <Topic>`, e.g. `Health - Sleep Apnea`, `Administrative - La Banque Postale` |
| **topic** | The second part of a stream, e.g. `Sleep Apnea` |
| **owner** | Who does the task: `Jean` (the user) · `any_agent` · `claude` · `chatgpt` (Codex counts as `chatgpt`) |
| **agent task** | owner ≠ `Jean`. Labels: `agent`, plus `claude` or `chatgpt` unless owner = `any_agent` |
| **my task** | owner = `Jean`: no `agent` label |

## Creating a task

- **Project** = the area. Never create a new project without asking: Free plan allows 5, all 5 used. A new area means merging or deleting one first.
- **Title**: short and actionable, starting with the topic: `Sleep apnea: teeth scan for the brace (Dr. Ettlin)`.
- **Due date** when a real date is known (appointment, follow-up). Date only, no time, unless the user asks.
- **Priority** (an urgency level for sorting; a real time limit goes in the date/deadline): `ASAP` / `24h` → P1 · `48h` / `7 days` → P2 · `30 days` → P3 · `someday` → P4.
- **Agent task** → add label `agent`. No exception. The user's widget filter "My day" = `(today | overdue) & !@agent` hides them; filter "Agents" = `@agent` lists them.
- **Which agent** → also add the model label, by default from the table below. Only `agent` with no model label = any agent may take it. Pick up only tasks labelled with your own model or with no model label. The user may reassign by swapping the label.

| Area / stream | Model label | Typical work |
|---|---|---|
| Administrative (all streams) | `chatgpt` | read letters, draft replies, check deadlines |
| Health (all streams) | `chatgpt` | research, questions for the doctor, compare offers |
| Home | `chatgpt` | product research, comparisons |
| Robotics: Swiss Robotics Association, Swiss Robotics Day | `chatgpt` | pitch, who to meet, follow-ups |
| Robotics - Startup: **story** and names | `chatgpt` | writing |
| Robotics - Startup: **domain and website** | `claude` | anything technical, code |
| Dev (all repos) | `claude` | code, tests, ops |

Linking (Gmail labels, calendar titles/colours, `Stream:` lines) is done by whichever model owns the stream. If your tools can't do one step, create a task for the other model (`agent` + its label) instead of skipping it.
- **Description** (always, the user reads it on the phone), in this order:

```
Stream: Health - Sleep Apnea
Place / people: full address, doctor or contact names, phone
<2-4 lines: what this is about, in plain words>

**Next step:** <one concrete action>

**History**
- YYYY-MM-DD: what happened

**Calendar**
- YYYY-MM-DD HH:MM: <what>: [event](<htmlLink>)

**Gmail** (label `Health/Sleep Apnea`)
- YYYY-MM-DD: <what>: [email](https://mail.google.com/mail/u/0/#all/<threadId>)
```

Keep history: append dated lines, never delete old ones.

## Updating

- Change dates with `reschedule-tasks`, not `update-tasks` (it breaks recurrence).
- Don't send back an existing `projectId`/`sectionId`/`parentId` to `update-tasks` (treated as a move).
- **Ask before completing, deleting or re-prioritising the user's tasks** unless they asked for it. Agents may freely complete their own `agent` tasks.

## Status, claim, done

```
todo ──► in-progress ──► done         (also: blocked, dropped)
         label in-progress + comment "claimed by <hostname>, <agent>, <session UUID> since <datetime>"
```

- **Claim before working**: add label `in-progress` and the comment (repo task: also `status`, `claimed_since`, `claimed_by` in the file). Skip tasks already `in-progress`.
- **Complete only with proof**: a comment with the result (commit, log line, output). Can't verify → don't complete.
- **Stopped or blocked**: remove `in-progress`, comment what is left. If it needs the user, create a task with owner `Jean`.
- **Stale claim**: `in-progress` for more than 24h with no new comment may be freed by any agent.

## Future work and reminders

Anything to do later ("check the run succeeded in 2 days") is a task with a date, owned by the agent that should do it. **Never** a private reminder only (macOS Reminders, a scheduled wake-up, a note in a chat): if one is also set, the task is still created.

## Repo tasks: the `TODO/` folder

Every repo under `~/dev/` keeps its tasks in `TODO/`, one file per task: `TODO/<NNNN>-<slug>.md` (next number = highest in `TODO/` and `TODO/done/` + 1). A finished one-off moves to `TODO/done/`. No index file. Knowledge that is not a task (design, accepted risks) goes in the repo's docs, not here.

**Dates, everywhere, no exception:** datetime `2026-10-11T09:00+02:00[Europe/Zurich]`, whole day `2026-10-11[Europe/Zurich]`. Never relative ("in 2 days"): convert when writing.

```yaml
---
# ── What
id: auto-commit#1
type: one-off            # one-off | recurring
title: Check GCP's first real run
category: ops            # bug | feature | docs | tests | ops | question | reminder
# ── Who
owner: Jean              # Jean | any_agent | claude | chatgpt
autonomy:                # owner ≠ Jean: auto_mode (does it) | approval_needed (writes a recommendation, Jean decides)
# ── Urgency
priority: 24h            # ASAP | 24h | 48h | 7 days | 30 days | someday
estimated_work_duration: 5 min     # minutes; per run if recurring
# ── When (one-off; all optional)
not_before: 2026-10-13T14:00+02:00[Europe/Zurich]
planned_at: 2026-10-13T14:30+02:00[Europe/Zurich]
not_after:
# ── When (recurring; instead of the block above)
# repeat: every monday   # every day | every N days | every <weekday> | every month on day N; time from planned_at
# planned_at: <next run>
# last_done_at:
# until:                 # optional
# ── Status and claim
status: todo             # todo | in-progress | blocked | done | dropped (recurring: no done, each run goes in History)
claimed_since:
claimed_by:              # <hostname>, <agent>, <session UUID>
# ── Links
depends_on: []           # ids, e.g. [auto-commit#2]
todoist_id:
# ── Origin
created_at: 2026-10-09T18:55+02:00[Europe/Zurich]
created_by: chan-lescut-macbook-pro, claude, <session UUID>   # or Jean
---
## Context
## Done when
## History
- 2026-10-09: created
## Links
## Result
```

**Mirror in Todoist** (project `Dev`, every repo task has one; the file is the source of truth, but what the user changes in Todoist — completed, date, priority — is copied back into the file):

| File | Todoist |
|---|---|
| `title` | task name, prefixed `<repo>: ` |
| `owner` | labels as in Vocabulary |
| `autonomy`, `category` | labels of the same name |
| `priority` | P1–P4 as above |
| `planned_at` (or `not_before` while in the future and no `planned_at`) | due date |
| `not_after` | deadline |
| `repeat` | recurring due date |
| `estimated_work_duration` | duration |
| `status: in-progress` / `done`, `dropped` | label `in-progress` / completed |
| Body | description: `Stream: Dev - <repo>`, id, link to the file on GitHub, Context in 2-4 lines, Done when |

## Linking: the stream in each tool

| Tool | How the stream appears | Access |
|---|---|---|
| Todoist | Project = area; first description line `Stream: …`; links to events and emails | Todoist MCP (Claude) / Todoist app (ChatGPT) |
| Google Calendar | Title contains the stream: `Bobi: Health - Sleep Apnea: <what> (<doctor>)` (keep the user's existing `Bobi:` prefix on the shared *Couple* calendar). Full address in **location**. Description: `Stream: …`, doctor/people, `Todoist: https://app.todoist.com/app/task/<id>` | `gws calendar` |
| Gmail | Nested label `<Area>/<Topic>`, e.g. `Health/Sleep Apnea` | `gws gmail` (scope gmail.modify) |
| Contacts | Contact label = area (e.g. `Health`); note `Stream: …` on doctors, offices, counterparts | `gws people` (see gws-people skill) |

**Calendar colour per area** (event `colorId`): `Health` = **2 (Sage)**. Other areas have no colour yet: ask before choosing.

Link both ways: the task lists event/email links, and each event description links back to the task.

## Gotchas

- **Check search hits before labelling** emails: a name search once matched an unrelated LinkedIn email. Never label marketing/newsletters (e.g. CPAPeuropa).
- Older Gmail labels exist (`HairTransplant`, `2_Psy`, `1_Meta`, `0_Lawyer`, `3_Unemployment_and_Job_Searches`). Don't rename or merge them without asking.
- Google Keep: no API for this personal account. Don't try.
- `gws` OAuth is in Google "Testing" mode: the login expires every 7 days. On `invalid_grant`/scope errors, ask the user to re-run the login command (see gws-shared skill and memory).
- **Never send an email** or invite on the user's behalf without explicit confirmation.
- Calendars: `personnel` (primary, jean.lescut@gmail.com), `Couple` (shared), `Family`.
