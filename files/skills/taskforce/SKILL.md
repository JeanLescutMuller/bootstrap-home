---
name: taskforce
description: How to create, update and link the user's life to-do tasks in Todoist, and how to tie them to Gmail, Google Calendar and Contacts with a shared "stream" keyword. Use whenever creating, updating, completing or reviewing a Todoist task, when an agent wants to plan work for a later day, or when filing an email or calendar event that belongs to an ongoing topic (health, admin, home…).
---

# Taskforce: task management for the user and agents

The user's to-do list for life is **Todoist** (Free plan). Gmail, Calendar and Contacts are linked to it with one shared keyword, the **stream**.

## Vocabulary (use these words, don't invent others)

| Word | Meaning |
|---|---|
| **area** | Top-level category = a Todoist project: `Administrative`, `Health`, `Home`, `Robotics`, `Others` (catch-all) |
| **stream** | One ongoing topic inside an area, written `<Area> - <Topic>`, e.g. `Health - Sleep Apnea`, `Administrative - La Banque Postale` |
| **topic** | The second part of a stream, e.g. `Sleep Apnea` |
| **agent task** | A task an agent plans for itself or another agent. Always has the label `agent`, plus the model label `claude` or `chatgpt`. |
| **my task** | Any task without the `agent` label: the user's own |

## Creating a task

- **Project** = the area. Never create a new project without asking: Free plan allows 5, all 5 used. A new area means merging or deleting one first.
- **Title**: short and actionable, starting with the topic: `Sleep apnea: teeth scan for the brace (Dr. Ettlin)`.
- **Due date** when a real date is known (appointment, follow-up). Date only, no time, unless the user asks.
- **Priority**: P1 = today or there are consequences · P2 = this week · P3 = soon · P4 = someday.
- **Agent task** → add label `agent`. No exception. The user's widget filter "My day" = `(today | overdue) & !@agent` hides them; filter "Agents" = `@agent` lists them.
- **Which agent** → also add the model label, by default from the table below. Only `agent` with no model label = any agent may take it. Pick up only tasks labelled with your own model or with no model label. The user may reassign by swapping the label.

| Area / stream | Model label | Typical work |
|---|---|---|
| Administrative (all streams) | `chatgpt` | read letters, draft replies, check deadlines |
| Health (all streams) | `chatgpt` | research, questions for the doctor, compare offers |
| Home, Others | `chatgpt` | product research, comparisons |
| Robotics: Swiss Robotics Association, Swiss Robotics Day | `chatgpt` | pitch, who to meet, follow-ups |
| Robotics - Startup: **story** and names | `chatgpt` | writing |
| Robotics - Startup: **domain and website** | `claude` | anything technical, code |

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
