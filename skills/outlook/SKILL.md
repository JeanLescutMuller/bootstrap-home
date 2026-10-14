---
name: outlook
description: The user's Outlook.com / Hotmail mailboxes (legend123@msn.com, enrices@hotmail.fr) through the audited Softeria ms-365-mcp-server and Microsoft Graph - read, search, attachments, send, reply, move, delete, folders, inbox rules (filters against spam) - which method to use (the `outlook` MCP tools, or `ol.sh` from the shell for subagents and bulk work), the rules (the user's OK before any write, move to Deleted Items instead of delete), the limits found, how to sign in an address again, and how to upgrade. Use for any Outlook, Hotmail, MSN or Live email.
---

# Outlook.com / Hotmail

Personal Microsoft accounts only. Claude's official Microsoft 365 connector refuses them (work accounts only), so we use Microsoft Graph through the open-source server Softeria `ms-365-mcp-server`, pinned to version **0.157.2**: its code and its 210 dependencies were audited on 2026-10-14 (only Microsoft hosts, no `eval` or hidden code, `npm audit` clean, install scripts off). It runs with the author's built-in app ID (the user's choice) and `MS365_MCP_TENANT_ID=consumers`.

## Addresses

| Address | Name on the account | Default | Read | Write |
|---|---|---|---|---|
| legend123@msn.com | Jean Lescut-Muller | yes | 👍 | 👍 |
| enrices@hotmail.fr | Gregory Enrices | | 👍 | 👍 |

Every tool takes `account=<email>`; without it, the default address is used. Always pass it.

## Methods

| Method | How | Use for |
|---|---|---|
| **MCP tools** | `mcp__outlook__*` in Claude Code: server `outlook` (user scope, `~/.claude.json`), `npx -y @softeria/ms-365-mcp-server@0.157.2 --preset mail`, 51 tools, writes on | small reads and every write in a normal session |
| **`ol.sh`** | `~/.claude/skills/outlook/scripts/ol.sh [--write] <tool> key=value … account=<email>`: the same server through the MCP inspector CLI, **read-only unless `--write`** | subagents, Codex, bulk reads (output to a file, read only aggregates), tests |
| **Chrome** | outlook.live.com in the "Claude - general" profile (skill `claude-in-chrome`) | what Graph cannot do: the Blocked / Safe senders lists, junk-filter settings |

```bash
OL=~/.claude/skills/outlook/scripts/ol.sh
$OL list-mail-folders account=enrices@hotmail.fr select=displayName,totalItemCount,unreadItemCount top=50 > folders.json
node -e 'const r=require("./folders.json"); console.log(JSON.parse(r.content[0].text).value)'   # payload = .content[0].text
$OL --list                     # tools and parameters (--write --list: the 51 with writes)
$OL --verify-login             # also --list-accounts, --list-permissions
```

## Rules

- **The user's OK before any write**: send, reply, forward, move, delete, create or change a rule or folder. Show exactly what will happen first (recipients and text, or the list of emails and how many, or the rule's condition and action).
- **Deleting = moving to Deleted Items**: `move-mail-message messageId=<id> body='{"DestinationId":"deleteditems"}'`. `delete-mail-message` claims a soft delete, but on Outlook.com the deleted email did **not** reach Deleted Items (tested 2026-10-14 on a draft, both addresses): use it only when the user asks for a permanent delete.
- **A new inbox rule acts on new mail only.** Count how many existing emails its condition matches and offer the one-time cleanup separately.
- Bulk work: never read raw email lists into the context; write them to files and read counts.

## What was tested

👍 = tested 2026-10-14 on both addresses · no mark = in the tool list, never tested: tell the user it is a first try.

| Feature | Tools | |
|---|---|---|
| Folders | `list-mail-folders`, `list-mail-child-folders` | 👍 |
| List, search, filter emails | `list-mail-messages`, `list-mail-folder-messages` (`search='"amazon"'`, `filter='isRead eq false'`, `select=`, `orderby=`), `list-mail-folder-messages-delta` | 👍 |
| Read an email, its raw source | `get-mail-message`, `get-mail-message-mime` | 👍 |
| Attachments | `list-mail-attachments`, `download-bytes`, `download-bytes-to-file` (target `/me/messages/<id>/attachments/<id>/$value`) | 👍 |
| Inbox rules (filters) | `list-mail-rules`, `create-mail-rule`, `delete-mail-rule` (`mailFolderId=inbox`) | 👍 |
| Drafts | `create-draft-email`, then `delete-mail-message` | 👍 |
| Send, reply, forward | `send-mail`, `reply-mail-message`, `forward-mail-message`, `send-draft-message` | |
| Move, copy, mark read | `move-mail-message`, `copy-mail-message`, `update-mail-message` | |
| Folders, categories, settings | `create-mail-folder`, `delete-mail-folder`, `create-outlook-category`, `update-mailbox-settings` | |
| Block a sender | none: `markAsJunk` is not in this version; use a rule, or Chrome | ❌ |

## Limits found

| Limit | Do |
|---|---|
| `fetchAllPages=true` stops at **10,989 emails** per call | page with `top=999 skip=<n>` and a fixed `orderby=receivedDateTime desc`; check the total against the folder's `totalItemCount` |
| Email body `contentType` must be lowercase `text` or `html` | `"Text"` is refused |
| Build JSON arguments with `JSON.stringify` (node), not by hand in the shell | escaped quotes reach the server as a string, and it refuses the call |
| Rule condition `senderContains` may also match the sender's display name | counts made on the address alone can be slightly low |
| The `outlook` MCP tools load only in sessions started after a config change | use `ol.sh` in the current session |

## Sign in an address again (new address, expired token, new permissions)

1. Start the login in the background: `ol.sh --write --login > login.log 2>&1`. It prints a code and waits about 15 minutes.
2. In Chrome "Claude - general", open `https://login.live.com/logout.srf` first: Chrome otherwise keeps the last Microsoft account and the user cannot type another one.
3. Open `https://www.microsoft.com/link`, type the code, leave the tab to the user: they click **Allow access**, sign in, and accept the permissions. Close the tab when `login.log` shows `Login successful`.

`--write` asks for `Mail.ReadWrite`, `Mail.Send`, `MailboxSettings.ReadWrite`, `User.Read`; without it, read-only permissions. Tokens: `~/Library/Application Support/ms-365-mcp-server/`, encrypted, readable only by the user (`keytar` is off, so the key sits beside the cache, not in the Keychain). Never read or decrypt them. The user revokes access at `account.live.com/consent/Manage`.

## Set up again or upgrade

The MCP registration (done by hand on 2026-10-14):

```bash
claude mcp add -s user outlook -e MS365_MCP_TENANT_ID=consumers -e npm_config_ignore_scripts=true -- npx -y @softeria/ms-365-mcp-server@0.157.2 --preset mail
```

The audited code is npm's cache `~/.npm/_npx/aa0219c2fba62d0d/`: if the cache is cleared, npx resolves the dependencies again. **Upgrade only after a new audit**, of a version at least 2 weeks old (the project publishes several versions a day):

1. `npm_config_ignore_scripts=true npx -y -p @softeria/ms-365-mcp-server@<v> -- true` (download, nothing run).
2. In its `dist/`: network hosts (`grep -oE 'https?://…'`), `child_process`, `eval`, `new Function`, obfuscation; packages with install scripts; `npm audit`; dependencies published in the last 7 days.
3. Change the version in `ol.sh` and in the `claude mcp add` line above, then sign in again if permissions changed.
