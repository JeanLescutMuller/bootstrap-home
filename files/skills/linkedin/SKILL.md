---
name: linkedin
description: LinkedIn without driving a browser - search people, profiles, company employees, jobs, the inbox, send a message or a connection request - through a free local headless session (stickerdaniel/linkedin-mcp-server, called from the shell). Use for any LinkedIn lookup or action.
---

# LinkedIn

The server is not registered as an MCP (that would load its tool names into every session): call its tools from the shell.

```bash
li() { local t=$1; shift; local a=(); for kv; do a+=(--tool-arg "$kv"); done
  UV_HTTP_TIMEOUT=300 npx -y @modelcontextprotocol/inspector@0.17.2 --cli uvx mcp-server-linkedin@latest \
    --method tools/call --tool-name "$t" "${a[@]}" 2>/dev/null; }
li search_people keywords="data science manager ads quality" current_company=Google location=London
li get_person_profile linkedin_username=jdoe sections=experience,education
```

Each call starts a headless browser (a few seconds). One call at a time. `uvx mcp-server-linkedin@latest --status` checks the login.

## Which tool for which feature

| Feature | Tool (args) | Else |
|---|---|---|
| search people | `search_people` (`keywords`, `current_company`, `location`, `network`) | **past company**: put it in `keywords`, or Chrome |
| a profile / my profile | `get_person_profile` (`linkedin_username`, `sections`), `get_my_profile`, `get_sidebar_profiles` | |
| company, its employees, its posts | `get_company_profile`, `get_company_employees` (`company_name`, `keywords`), `get_company_posts`, `search_companies` | |
| jobs | `search_jobs` (`keywords`, `location`, `date_posted`, `easy_apply`, `experience_level`, `job_type`, `work_type`, `sort_by`), `get_job_details` (`job_id`), `get_job_apply_url`, `get_saved_jobs` | **save a job, Easy Apply**: Chrome, the user confirming each application |
| inbox | `get_inbox` (`limit`), `get_conversation` (`thread_id` or `linkedin_username`), `search_conversations` | |
| new message to a connection | `send_message` (`linkedin_username`, `message`, `confirm_send=true`) | **reply inside a thread, InMail**: Chrome |
| connection request, accept | `connect_with_person` (`linkedin_username`, `note`) | withdraw: Chrome |
| feed, posts | `get_feed`, `search_posts` | publish, comment, react: Chrome |
| edit my own profile | none | skill `linkedin-profile` (Chrome) |

Chrome = skill `claude-in-chrome`, on the user's logged-in session.

## Rules

- **Show the exact text and recipient and get the user's OK before any write** (`send_message`, `connect_with_person`).
- Low volume: no bulk searches, no bulk requests. LinkedIn can restrict the account (the server's README says so).
- Not logged in → ask the user to run, once: `uvx mcp-server-linkedin@latest --import-from-browser chrome` (or `--login` for a visible window). The session is kept in `~/.linkedin-mcp/profile/`.
