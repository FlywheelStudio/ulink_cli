#!/usr/bin/env node
// ULink MCP server — deep linking & Firebase Dynamic Links migration for coding agents.
//
// Exposes the ULink platform as MCP tools so an agent can take a developer from
// zero to a *verified working deep link* without leaving the editor:
//   import_firebase, create_link, verify_link, get_link, list_links,
//   list_domains, setup_domain.
//
// Design:
//   - Link creation/read goes through the ULink REST API (POST /sdk/links,
//     GET /sdk/resolve). The server OWNS this path so every link it creates is
//     tagged parameters.source=mcp for channel funnel measurement (ULI-5 §5).
//   - Firebase import + rich platform resolution reuse the shipped `ulink` CLI
//     (the FDL importer engine from ULI-7) via a subprocess, so the migration
//     logic is not duplicated.
//
// Transport: stdio (day one). A hosted remote (HTTP + OAuth 2.1) endpoint is a
// planned follow-up for one-click installs (Smithery et al.).
//
// Env:
//   ULINK_API_KEY   (required for live create/import/read)   app key, sent as x-app-key
//   ULINK_API_BASE  (default https://api.ulink.ly)
//   ULINK_CLI       (default: `ulink` on PATH)               path to the ulink binary

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { spawn } from 'node:child_process';

const API_BASE = (process.env.ULINK_API_BASE || 'https://api.ulink.ly').replace(/\/+$/, '');
const CLI = process.env.ULINK_CLI || 'ulink';
const SOURCE_TAG = 'mcp';
// api.ulink.ly sits behind Cloudflare; a browser-like UA avoids a 403 (err1010).
const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

function apiKey() {
  const k = process.env.ULINK_API_KEY;
  if (!k) {
    throw new Error(
      'ULINK_API_KEY is not set. Get a free key at https://ulink.ly/dashboard ' +
        '(no credit card) and export ULINK_API_KEY before starting the server.'
    );
  }
  return k;
}

async function apiFetch(path, { method = 'GET', body } = {}) {
  const headers = {
    'x-app-key': apiKey(),
    'User-Agent': UA,
    Accept: 'application/json',
  };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    throw new Error(`ULink API ${method} ${path} → ${res.status}: non-JSON response: ${text.slice(0, 300)}`);
  }
  if (!res.ok) {
    const msg = json?.message || json?.error || `HTTP ${res.status}`;
    throw new Error(`ULink API ${method} ${path} → ${res.status}: ${msg}`);
  }
  return json;
}

// Run the shipped `ulink` CLI and capture stdout. Rejects on non-zero exit.
function runCli(args, { input } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(CLI, args, {
      env: process.env,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    let out = '';
    let err = '';
    child.stdout.on('data', (d) => (out += d));
    child.stderr.on('data', (d) => (err += d));
    child.on('error', (e) =>
      reject(
        new Error(
          `Could not run the ulink CLI ("${CLI}"): ${e.message}. ` +
            `Install it (npm i -g @ulinkly/cli) or set ULINK_CLI to its path.`
        )
      )
    );
    child.on('close', (code) => {
      if (code === 0) resolve({ out, err });
      else reject(new Error(`ulink CLI exited ${code}: ${(err || out).slice(0, 800)}`));
    });
    if (input !== undefined) {
      child.stdin.write(input);
    }
    child.stdin.end();
  });
}

// Pull the JSON object out of CLI stdout that may be prefixed with a progress line.
function extractJson(stdout) {
  const start = stdout.indexOf('{');
  const arrStart = stdout.indexOf('[');
  const at =
    start === -1 ? arrStart : arrStart === -1 ? start : Math.min(start, arrStart);
  if (at === -1) throw new Error(`No JSON found in CLI output: ${stdout.slice(0, 300)}`);
  return JSON.parse(stdout.slice(at));
}

function prune(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj || {})) {
    if (v === undefined || v === null || v === '') continue;
    out[k] = v;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Tool implementations
// ---------------------------------------------------------------------------

async function createLink(args) {
  const parameters = prune({ ...(args.parameters || {}) });
  if (args.deepLink) parameters.deepLink = args.deepLink;
  parameters.source = SOURCE_TAG; // instrumentation (ULI-5 §5) — always tagged.
  const payload = prune({
    type: args.type || 'unified',
    slug: args.slug,
    fallbackUrl: args.fallbackUrl,
    iosUrl: args.iosUrl,
    androidUrl: args.androidUrl,
    parameters,
    allowQueryPassthrough: args.allowQueryPassthrough !== false,
    metadata: args.metadata,
  });
  const link = await apiFetch('/sdk/links', { method: 'POST', body: payload });
  return {
    shortUrl: link.shortUrl,
    slug: link.slug,
    type: link.type,
    parameters: link.parameters,
    source: link.parameters?.source || SOURCE_TAG,
    raw: link,
  };
}

async function getLink(args) {
  const url = args.url || args.shortUrl;
  if (!url) throw new Error('get_link requires `url` (the ULink short URL).');
  const link = await apiFetch(`/sdk/resolve?url=${encodeURIComponent(url)}`);
  return link;
}

async function verifyLink(args) {
  const url = args.url || args.shortUrl;
  if (!url) throw new Error('verify_link requires `url` (the ULink short URL).');
  // Reuse the CLI resolver for a per-platform verdict (iOS/iPad/Android/desktop
  // destinations + forwarded attribution).
  const { out } = await runCli(['resolve', url, '--json']);
  const r = extractJson(out);
  const platforms = r.platforms || {};
  const opensApp = Boolean(
    r.deepLink ||
      platforms.ios?.destination ||
      platforms.android?.destination
  );
  return {
    url: r.url || url,
    ok: r.ok === true && r.status === 200,
    resolvesOnEdge: r.ok === true,
    opensApp,
    deepLink: r.deepLink || null,
    platforms,
    attribution: r.attribution || {},
    summary: opensApp
      ? 'Link resolves and carries an app deep link — verify AASA/assetlinks with verify_link on the domain (setup_domain) for full app-open confirmation.'
      : 'Link resolves but no app deep link was found; it will fall back to the web URL. Add a deepLink or check platform config.',
  };
}

async function listLinks(args) {
  const qs = new URLSearchParams();
  if (args.limit) qs.set('limit', String(args.limit));
  if (args.domain) qs.set('domain', args.domain);
  const suffix = qs.toString() ? `?${qs}` : '';
  return await apiFetch(`/sdk/links${suffix}`);
}

async function importFirebase(args) {
  if (!args.input) throw new Error('import_firebase requires `input` (path to an FDL export, or "-" for stdin content in `inputContent`).');
  if (!args.domain) throw new Error('import_firebase requires `domain` (your ULink domain).');
  const cliArgs = ['import', 'firebase', '-i', args.input, '-d', args.domain, '--json'];
  if (args.live) cliArgs.push('--live');
  else cliArgs.push('--dry-run');
  if (args.noVerify) cliArgs.push('--no-verify');
  const { out } = await runCli(cliArgs, { input: args.inputContent });
  const manifest = extractJson(out);
  return {
    mode: args.live ? 'live' : 'dry-run',
    note: args.live
      ? 'Links created in ULink. NOTE: import source-tagging (source=mcp) requires a CLI --source flag (tracked follow-up); create_link already tags source=mcp.'
      : 'Dry run — no links created. Pass live:true to create them.',
    manifest,
  };
}

async function listDomains() {
  // Best-effort: the public read endpoint for domains is not part of the
  // documented /sdk contract yet. Return an honest, actionable message rather
  // than a fabricated success.
  try {
    return await apiFetch('/sdk/domains');
  } catch (e) {
    throw new Error(
      `Listing domains via the API is not available on this key/endpoint (${e.message}). ` +
        `Manage domains at https://ulink.ly/dashboard; the link domain is bound to your API key.`
    );
  }
}

async function setupDomain(args) {
  if (!args.domain) throw new Error('setup_domain requires `domain`.');
  // Emit the well-known config an agent must publish, and point at CLI verify.
  return {
    domain: args.domain,
    action: 'Publish these files at your domain, then run verify.',
    files: {
      'apple-app-site-association':
        'Serve at https://' + args.domain + '/.well-known/apple-app-site-association (no extension, Content-Type application/json). ' +
        'Contains your Team ID + bundle ID applinks paths. Get the exact contents from your ULink dashboard or the ai-setup skill.',
      'assetlinks.json':
        'Serve at https://' + args.domain + '/.well-known/assetlinks.json with your Android package name + SHA-256 signing cert fingerprint.',
    },
    verify: `Run: ulink verify ${args.domain}  (or the verify_domain tool) to confirm both are correctly published.`,
  };
}

async function verifyDomain(args) {
  if (!args.domain) throw new Error('verify_domain requires `domain`.');
  const { out } = await runCli(['verify', args.domain, '--json']).catch(async () => {
    // Older/newer CLI may not support --json on verify; fall back to text.
    return await runCli(['verify', args.domain]);
  });
  let parsed;
  try {
    parsed = extractJson(out);
  } catch {
    parsed = { raw: out.slice(0, 2000) };
  }
  return parsed;
}

// ---------------------------------------------------------------------------
// Tool registry
// ---------------------------------------------------------------------------

const TOOLS = [
  {
    name: 'import_firebase',
    description:
      'Migrate Firebase Dynamic Links (FDL) to ULink. Reads an FDL export ' +
      '(JSON DynamicLinkInfo, a { "links": [...] } batch, a newline list of *.page.link URLs, ' +
      'or a CSV) and recreates equivalent ULink links with routing + attribution preserved. ' +
      'Defaults to a safe dry-run; pass live:true to actually create links.',
    inputSchema: {
      type: 'object',
      properties: {
        input: { type: 'string', description: 'Path to the FDL export file, or "-" to read inputContent from stdin.' },
        inputContent: { type: 'string', description: 'FDL export content, used when input is "-".' },
        domain: { type: 'string', description: 'Your ULink domain the new links live under (e.g. acme.ulink.app).' },
        live: { type: 'boolean', description: 'Create links via the API. Default false (dry-run preview).' },
        noVerify: { type: 'boolean', description: 'Skip routing+attribution parity checks. Default false.' },
      },
      required: ['input', 'domain'],
    },
  },
  {
    name: 'create_link',
    description:
      'Create a ULink deep/universal link. Every link created here is tagged source=mcp for channel measurement. ' +
      'Forwarded attribution params ride in `parameters` with allowQueryPassthrough so they reach the app on open.',
    inputSchema: {
      type: 'object',
      properties: {
        slug: { type: 'string', description: 'Custom slug (path). Omit to auto-generate.' },
        type: { type: 'string', enum: ['unified', 'dynamic'], description: 'Link type. Default unified.' },
        fallbackUrl: { type: 'string', description: 'Web/desktop fallback URL.' },
        deepLink: { type: 'string', description: 'In-app deep link the agent wants opened (e.g. myapp://product/42).' },
        iosUrl: { type: 'string', description: 'iOS-specific fallback (App Store URL, etc.).' },
        androidUrl: { type: 'string', description: 'Android-specific fallback (Play Store URL, etc.).' },
        parameters: { type: 'object', description: 'Extra forwarded params (utm_*, custom). source=mcp is added automatically.' },
        allowQueryPassthrough: { type: 'boolean', description: 'Forward query params to the app. Default true.' },
        metadata: { type: 'object', description: 'Open-graph metadata: { ogTitle, ogDescription, ogImage }.' },
      },
    },
  },
  {
    name: 'verify_link',
    description:
      'Resolve a ULink short URL on the live edge and report whether it carries an app deep link per platform ' +
      '(the activation event). Returns forwarded attribution too.',
    inputSchema: {
      type: 'object',
      properties: { url: { type: 'string', description: 'The ULink short URL to verify.' } },
      required: ['url'],
    },
  },
  {
    name: 'get_link',
    description: 'Read back a single ULink link by its short URL (slug, type, parameters, config).',
    inputSchema: {
      type: 'object',
      properties: { url: { type: 'string', description: 'The ULink short URL.' } },
      required: ['url'],
    },
  },
  {
    name: 'list_links',
    description: 'List links (best-effort; may require dashboard access depending on key scope).',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'Max links to return.' },
        domain: { type: 'string', description: 'Filter by domain.' },
      },
    },
  },
  {
    name: 'list_domains',
    description: 'List the link domains available to this API key (best-effort).',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'setup_domain',
    description:
      'Return the .well-known files (apple-app-site-association, assetlinks.json) and locations you must publish ' +
      'to make universal/app links open your app, plus how to verify.',
    inputSchema: {
      type: 'object',
      properties: { domain: { type: 'string', description: 'The domain to set up.' } },
      required: ['domain'],
    },
  },
  {
    name: 'verify_domain',
    description:
      'Check that a domain\'s apple-app-site-association and assetlinks.json are correctly published so app links resolve. ' +
      'The #1 silent-failure cause in deep linking.',
    inputSchema: {
      type: 'object',
      properties: { domain: { type: 'string', description: 'The domain to verify.' } },
      required: ['domain'],
    },
  },
];

const HANDLERS = {
  import_firebase: importFirebase,
  create_link: createLink,
  verify_link: verifyLink,
  get_link: getLink,
  list_links: listLinks,
  list_domains: listDomains,
  setup_domain: setupDomain,
  verify_domain: verifyDomain,
};

// ---------------------------------------------------------------------------
// Server wiring
// ---------------------------------------------------------------------------

const server = new Server(
  { name: 'ulink', version: '0.1.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args = {} } = req.params;
  const handler = HANDLERS[name];
  if (!handler) {
    return {
      isError: true,
      content: [{ type: 'text', text: `Unknown tool: ${name}` }],
    };
  }
  try {
    const result = await handler(args);
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
  } catch (e) {
    return {
      isError: true,
      content: [{ type: 'text', text: `Error in ${name}: ${e.message}` }],
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // eslint-disable-next-line no-console
  console.error('ULink MCP server (stdio) ready — tools: ' + TOOLS.map((t) => t.name).join(', '));
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error('Fatal:', e);
  process.exit(1);
});
