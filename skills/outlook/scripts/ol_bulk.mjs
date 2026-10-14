#!/usr/bin/env node
// ol_bulk.mjs - many Outlook tool calls over ONE connection to the audited ms-365-mcp-server
// (ol.sh starts the server for every call: 3-5 s each; here ~0.2-0.5 s per call).
//
//   ol_bulk.mjs [--write] list <account> <folder> <out.ndjson>
//       every email of a folder (inbox, junkemail, deleteditems or a folder id), one line each:
//       {"id","a" (sender address, lowercase),"n" (sender name),"s" (subject),"dt","r" (isRead)}
//   ol_bulk.mjs [--write] run <calls.ndjson> <results.ndjson> [parallel=4]
//       one call per line {"tool":"move-mail-message","args":{...}}; writes {"i","ok","err"} per line.
//       Resumable: lines already in results.ndjson are skipped. Stops after 20 errors in a row.
//
// Read-only unless --write. Graph throttling (429) is retried by the server itself.
import { readFileSync, existsSync, appendFileSync, writeFileSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { createRequire } from "node:module";

const VERSION = "0.157.2"; // the audited version: same as ol.sh (SKILL.md, "Set up again or upgrade")
const args = process.argv.slice(2);
const write = args[0] === "--write" && args.shift();
const [mode, ...rest] = args;

// The SDK comes from the audited server's own npx folder: nothing else is downloaded.
const npx = `${homedir()}/.npm/_npx`;
const dir = readdirSync(npx).map(d => `${npx}/${d}`).find(d =>
    existsSync(`${d}/node_modules/@softeria/ms-365-mcp-server/package.json`) &&
    JSON.parse(readFileSync(`${d}/node_modules/@softeria/ms-365-mcp-server/package.json`)).version === VERSION);
if (!dir) { console.error(`ms-365-mcp-server@${VERSION} not in ${npx}: run ol.sh --verify-login once`); process.exit(1); }
const req = createRequire(`${dir}/package.json`);
const { Client } = await import(req.resolve("@modelcontextprotocol/sdk/client/index.js"));
const { StdioClientTransport } = await import(req.resolve("@modelcontextprotocol/sdk/client/stdio.js"));

const transport = new StdioClientTransport({
    command: "npx",
    args: ["-y", `@softeria/ms-365-mcp-server@${VERSION}`, "--preset", "mail", ...(write ? [] : ["--read-only"])],
    env: { ...process.env, MS365_MCP_TENANT_ID: "consumers", npm_config_ignore_scripts: "true" },
    stderr: "ignore",
});
const client = new Client({ name: "ol_bulk", version: "1" });
await client.connect(transport);

async function call(tool, a) {
    const r = await client.callTool({ name: tool, arguments: a }, undefined, { timeout: 120000 });
    const text = r.content?.[0]?.text ?? "";
    if (r.isError) throw new Error(text.slice(0, 300));
    try { return JSON.parse(text); } catch { return text; }
}

if (mode === "list") {
    const [account, folder, out] = rest;
    writeFileSync(out, "");
    let skip = 0, n = 0;
    for (;;) {
        const j = await call("list-mail-folder-messages", { account, mailFolderId: folder, top: 999, skip,
            orderby: ["receivedDateTime desc"], select: ["id", "from", "subject", "receivedDateTime", "isRead"] });
        const v = j.value ?? [];
        appendFileSync(out, v.map(m => JSON.stringify({ id: m.id,
            a: (m.from?.emailAddress?.address ?? "").toLowerCase(), n: m.from?.emailAddress?.name ?? "",
            s: m.subject ?? "", dt: m.receivedDateTime, r: m.isRead })).join("\n") + (v.length ? "\n" : ""));
        n += v.length; skip += v.length;
        if (v.length < 999) break;
    }
    console.log(`${n} emails -> ${out}`);
} else if (mode === "run") {
    const [callsFile, out, par = "4"] = rest;
    const calls = readFileSync(callsFile, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l));
    const done = new Set(existsSync(out) ? readFileSync(out, "utf8").split("\n").filter(Boolean)
        .map(l => JSON.parse(l)).filter(r => r.ok).map(r => r.i) : []);
    const todo = calls.map((c, i) => ({ ...c, i })).filter(c => !done.has(c.i));
    let ok = 0, err = 0, streak = 0, next = 0;
    const t0 = Date.now();
    async function worker() {
        while (next < todo.length && streak < 20) {
            const c = todo[next++];
            try { await call(c.tool, { excludeResponse: true, ...c.args }); ok++; streak = 0;
                appendFileSync(out, JSON.stringify({ i: c.i, ok: true }) + "\n"); }
            catch (e) { err++; streak++; appendFileSync(out, JSON.stringify({ i: c.i, ok: false, err: e.message }) + "\n"); }
            if ((ok + err) % 500 === 0) console.log(`${ok + err}/${todo.length} ok=${ok} err=${err} ${((Date.now() - t0) / 1000).toFixed(0)}s`);
        }
    }
    await Promise.all(Array.from({ length: Number(par) }, worker));
    console.log(`done: ${ok} ok, ${err} errors, ${done.size} done before${streak >= 20 ? ", STOPPED after 20 errors in a row" : ""} (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
} else {
    console.error(readFileSync(new URL(import.meta.url), "utf8").split("\n").slice(1, 13).join("\n"));
    process.exitCode = 2;
}
await client.close();
