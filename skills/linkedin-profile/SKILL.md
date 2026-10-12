---
name: linkedin-profile
description: Edit the user's own LinkedIn profile (headline, About, top skills, experience, education, skills, languages, projects) silently through Chrome - backup first, a review page, the user's OK, "Notify network" off on every dialog, Unicode bold, verify, silence check, restore. Use whenever the user asks to update, align, back up or restore their LinkedIn profile.
---

# Editing the user's LinkedIn profile

No API can do it (LinkedIn's Profile Edit API is partner-only; skill `linkedin` only reads, messages and connects). The only route is the user's logged-in Chrome (skill `claude-in-chrome`). Everything lives in `~/dev/html_resumes/linkedin/`:

| File | Role |
|---|---|
| `profile_<date>_before.json` | exact copy of the live profile before an edit session: **the restore source** |
| `profile_<date>_proposed_<why>.json` | the proposal: same schema, `_action` = keep / edit / add / delete_by_hand + why on each item, `*_md` fields with `**bold**` |
| `render.py` + `review_template.html` → `review.html` | LinkedIn-like review page: Proposed / Current / Side by side, a table of changes, character counts |
| `unibold.py` | `**phrase**` → Unicode sans-serif bold (𝗹𝗶𝗸𝗲 𝘁𝗵𝗶𝘀), the user's bold trick |
| `profile_<date>_after.json` | what is live after the session, with the differences from the proposal |

Content rules (titles, dates, what not to claim) come from the career catalog and `~/dev/html_resumes/AGENTS.md`; the profile must match the CV being sent. No emojis. XGBoost: "Official contributor to XGBoost", never details.

## Steps

1. **Back up the live profile** before anything else: `get_page_text` on `/in/<me>/details/experience/` (and `/education/`, `/skills/`, `/languages/`), plus the About editor (`/edit/forms/summary/new/`): an About text can exist even when the page shows none. Keep the text byte-exact, including the invisible `ㅤ` (U+3164) the user puts before `- ` bullets and the Unicode bold letters.
2. **Proposal + review page**: write the proposal JSON, `python3 render.py`, give the user `review.html`. **No Save until the user approves** (a general "go" covers the reviewed rows; anything new needs a new OK).
3. **Silence**: the user keeps Settings → Visibility → "Share profile updates" **Off** (`/mypreferences/d/settings/notify-network-for-updates`; it is a settings change: the user does it, or gives an explicit OK). On **every** Edit role / Edit education dialog, check the **"Notify network"** switch at the top is **Off** before Save.
4. **Edit one item at a time**, then Save:

| Item | Where | How |
|---|---|---|
| Headline | `/in/<me>/edit/intro/` | click the field, cmd+a, type |
| About + top skills (max 5) | `/in/<me>/edit/forms/summary/new/` | the text box is a contenteditable DIV: cmd+a, type; skills: "Add skill", type, pick the option via `find` |
| Experience | `/in/<me>/details/experience/edit/forms/<id>/` (ids: in the before JSON, or the pencil links on `/details/experience/`) | title/description: cmd+a + type; dates: `form_input` with month numbers; uncheck "currently working" to get end dates; organization: type then pick the company from the dropdown |
| Skills on a role | same dialog, Skills chips | click a chip to link/unlink; "Add skill" + `find` the option |
| Education | `/details/education/` → pencil (`find` "Edit education <school>") | same as experience |
| New skill | `/in/<me>/details/skills/edit/forms/new/` | pick from the typeahead (free text is not accepted; e.g. "Experimentation" does not exist), tick where it was used |
| Language | `/details/languages/` → pencil, or `/details/languages/edit/forms/new/` | proficiency via `form_input` |
| Project | profile → "Add section" → Recommended → "Add projects" (`/edit/forms/project/new/`) | only the name is required |

   - **Typing can silently drop letters** (seen in an education description: "IOR", "Deartment"). Zoom and read every field before Save; for a textarea use `form_input` to set the exact value instead. Long Unicode-bold texts typed fine into experience descriptions, but check anyway.
   - Bold: `python3 unibold.py "text with **bold**"`. Each bold letter counts as 2 characters toward the limits (headline 220, About 2,600, description 2,000).
5. **Pop-ups after Save**: "share this update" / "Post now" → **Skip, never Post**; "people you may know" → Skip; Premium upsell → close (X); "add another skill" → No thanks / Add more skills.
6. **Verify**: `get_page_text` on `/details/experience/` (and the edited sections) and compare with the proposal, line by line.
7. **Silence check**: `/in/<me>/recent-activity/all/` shows no new post; the "Share profile updates" toggle is still Off. Tell the user both results.
8. Write `profile_<date>_after.json` (with the differences from the proposal), close your Chrome tab, re-render `review.html` if useful.

**Never by Claude**: deleting an entry, a skill, media, the photo, the name or the profile URL; Open to work; posting, commenting, connecting. List these for the user to do by hand.

**Restore**: same procedure with the before JSON as the proposal (descriptions back byte-exact; re-add removed skills; re-link skills to roles).

Keep it low-volume and supervised (LinkedIn's terms ban automated activity): one session, one item at a time, never bulk.
