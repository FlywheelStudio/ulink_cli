// End-to-end stdio smoke test for the ULink MCP server.
// Drives the real JSON-RPC loop over stdio: initialize → tools/list →
// create_link (live) → verify_link (live) → get_link (live).
//
// Requires ULINK_API_KEY in env and the ulink CLI reachable via ULINK_CLI.
// Run: node test/smoke.mjs

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SERVER = path.join(__dirname, '..', 'src', 'index.js');

const child = spawn('node', [SERVER], { stdio: ['pipe', 'pipe', 'pipe'] });
child.stderr.on('data', (d) => process.stderr.write('[server] ' + d));

let buf = '';
const pending = new Map();
child.stdout.on('data', (d) => {
  buf += d;
  let nl;
  while ((nl = buf.indexOf('\n')) !== -1) {
    const line = buf.slice(0, nl).trim();
    buf = buf.slice(nl + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    }
  }
});

let idc = 0;
function rpc(method, params) {
  const id = ++idc;
  return new Promise((resolve) => {
    pending.set(id, resolve);
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
  });
}
function notify(method, params) {
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n');
}

function textOf(res) {
  const c = res?.result?.content?.[0]?.text;
  return c ? JSON.parse(c) : res?.result;
}

let failed = false;
function check(name, cond, detail) {
  const ok = Boolean(cond);
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`);
  if (!ok) failed = true;
}

async function run() {
  const init = await rpc('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'smoke', version: '0' },
  });
  check('initialize', init?.result?.serverInfo?.name === 'ulink', init?.result?.serverInfo?.name);
  notify('notifications/initialized', {});

  const tools = await rpc('tools/list', {});
  const names = (tools?.result?.tools || []).map((t) => t.name);
  const expected = ['import_firebase', 'create_link', 'verify_link', 'get_link', 'list_links', 'list_domains', 'setup_domain', 'verify_domain'];
  check('tools/list has all tools', expected.every((e) => names.includes(e)), names.join(','));

  if (!process.env.ULINK_API_KEY) {
    console.log('SKIP live create/verify — ULINK_API_KEY not set');
    child.kill();
    process.exit(failed ? 1 : 0);
  }

  const slug = 'mcpsmoke' + Math.floor(Date.now() / 1000);
  const created = await rpc('tools/call', {
    name: 'create_link',
    arguments: {
      slug,
      fallbackUrl: 'https://ulink.ly',
      deepLink: 'myapp://smoke/42',
      parameters: { utm_source: 'smoke', utm_campaign: 'mcp_e2e' },
    },
  });
  const cl = textOf(created);
  check('create_link returns shortUrl', cl?.shortUrl?.includes(slug), cl?.shortUrl);
  check('create_link tags source=mcp', cl?.parameters?.source === 'mcp', JSON.stringify(cl?.parameters));

  const verified = await rpc('tools/call', {
    name: 'verify_link',
    arguments: { url: cl.shortUrl },
  });
  const vf = textOf(verified);
  check('verify_link resolves on edge', vf?.resolvesOnEdge === true, `ok=${vf?.ok}`);
  check('verify_link sees app deep link', vf?.opensApp === true && vf?.deepLink === 'myapp://smoke/42', vf?.deepLink);
  check('verify_link preserves attribution', vf?.attribution?.utm_source === 'smoke', JSON.stringify(vf?.attribution));

  const got = await rpc('tools/call', { name: 'get_link', arguments: { url: cl.shortUrl } });
  const gl = textOf(got);
  check('get_link reads back params', gl?.parameters?.source === 'mcp' && gl?.parameters?.utm_campaign === 'mcp_e2e', JSON.stringify(gl?.parameters));

  child.kill();
  console.log(failed ? '\nSMOKE: FAIL' : '\nSMOKE: PASS');
  process.exit(failed ? 1 : 0);
}

run().catch((e) => {
  console.error('smoke error:', e);
  child.kill();
  process.exit(1);
});
