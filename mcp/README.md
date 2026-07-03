# ULink MCP server

**Deep linking & Firebase Dynamic Links migration your coding agent can set up and verify.**

Create, import, and verify mobile deep links without leaving your editor. One tool to migrate off
Firebase Dynamic Links (shut down 25 Aug 2025), generate universal/app links, and confirm they resolve
on iOS and Android — end to end, no dashboard visit, no credit card.

> Status: **v0.1.0 — staged, not yet published.** Registry listing + hosted remote endpoint are gated on
> board publish-consent. The stdio server below runs today.

## Tools

| Tool | What it does |
|---|---|
| `import_firebase` | Migrate an FDL export (JSON / batch / `*.page.link` list / CSV) to ULink with routing + attribution preserved. Dry-run by default; `live:true` to create. |
| `create_link` | Create a deep/universal link. Every link is tagged `source=mcp` for channel measurement. |
| `verify_link` | Resolve a short URL on the live edge and report whether it carries an app deep link per platform (**the activation event**) + forwarded attribution. |
| `get_link` | Read back a single link by short URL. |
| `list_links` | List links (best-effort, key-scope dependent). |
| `list_domains` | List link domains for the key (best-effort). |
| `setup_domain` | Emit the `.well-known` files (AASA / assetlinks.json) + locations to publish. |
| `verify_domain` | Check a domain's `apple-app-site-association` + `assetlinks.json` are correctly published — the #1 silent-failure cause in deep linking. |

## Requirements

- Node ≥ 18
- The `ulink` CLI on `PATH` (`npm i -g @ulinkly/cli`) — reused for FDL import and per-platform resolution.
- A ULink API key: `export ULINK_API_KEY=…` (free tier, get one at https://ulink.ly/dashboard).

## Environment

| Var | Default | Purpose |
|---|---|---|
| `ULINK_API_KEY` | — | App key (sent as `x-app-key`). Required for live create/import/read. |
| `ULINK_API_BASE` | `https://api.ulink.ly` | API base URL. |
| `ULINK_CLI` | `ulink` | Path to the `ulink` binary. |

## Install (one-line, per client)

**Claude Code**
```bash
claude mcp add ulink -e ULINK_API_KEY=$ULINK_API_KEY -- npx -y @ulinkly/mcp
```

**Cursor** — `~/.cursor/mcp.json`
```json
{
  "mcpServers": {
    "ulink": {
      "command": "npx",
      "args": ["-y", "@ulinkly/mcp"],
      "env": { "ULINK_API_KEY": "your_key" }
    }
  }
}
```

**VS Code** — `.vscode/mcp.json`
```json
{
  "servers": {
    "ulink": {
      "command": "npx",
      "args": ["-y", "@ulinkly/mcp"],
      "env": { "ULINK_API_KEY": "${env:ULINK_API_KEY}" }
    }
  }
}
```

## Run locally (from source)

```bash
cd mcp
npm install
ULINK_API_KEY=… ULINK_CLI=/path/to/ulink npm start   # stdio server
npm run smoke                                          # end-to-end live test
```

## Verified example (create → verify)

`create_link { slug, fallbackUrl, deepLink: "myapp://smoke/42", parameters: { utm_source: "smoke" } }`
→ short URL on your domain, `parameters.source = "mcp"`.
`verify_link { url }` → `opensApp: true`, `deepLink: "myapp://smoke/42"`, `attribution: { utm_source: "smoke" }`.

## Instrumentation

Links created via `create_link` are tagged `parameters.source = "mcp"` so the Head of Distribution can
measure the discover → install → run → verified-link funnel (ULI-5 §5). Import source-tagging rides a
planned `--source` flag on the CLI (tracked follow-up).

## Roadmap (staged / gated)

- Hosted remote endpoint (HTTP + OAuth 2.1) for one-click installs (Smithery).
- Publish `server.json` to the official MCP Registry (`server.json` staged in this dir).
- `ai-setup` skill that orchestrates these tools end-to-end (ULI-5 §4).

MIT © ULink
