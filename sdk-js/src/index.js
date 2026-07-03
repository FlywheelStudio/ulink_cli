// @ulinkly/sdk — the Firebase Dynamic Links alternative for JavaScript / React Native / web.
//
// A drop-in *link* SDK: create dynamic/universal links that route users to the
// right screen, survive install, and work across iOS & Android — in a few lines.
// Fetch-based, zero runtime deps, runs anywhere `fetch` exists (Node 18+, React
// Native, browsers, edge runtimes).
//
// Quickstart:
//   import { ULink } from '@ulinkly/sdk';
//   const ulink = new ULink({ apiKey: process.env.ULINK_API_KEY });
//   const link = await ulink.createLink({
//     slug: 'welcome',
//     deepLink: 'myapp://profile/12345',
//     fallbackUrl: 'https://example.com',
//     parameters: { screen: 'profile', userId: '12345' },
//   });
//   console.log(link.shortUrl);
//   const resolved = await ulink.resolve(link.shortUrl);

const DEFAULT_API_BASE = 'https://api.ulink.ly';
const SDK_SOURCE = 'js-sdk';
// api.ulink.ly is fronted by Cloudflare; a browser-like UA avoids an edge 403.
const DEFAULT_UA =
  'Mozilla/5.0 (compatible; ulink-js-sdk)';

export class ULinkError extends Error {
  constructor(message, { status, body } = {}) {
    super(message);
    this.name = 'ULinkError';
    this.status = status;
    this.body = body;
  }
}

function pruneEmpty(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj || {})) {
    if (v === undefined || v === null || v === '') continue;
    out[k] = v;
  }
  return out;
}

export class ULink {
  /**
   * @param {object} config
   * @param {string} config.apiKey        ULink app key (sent as x-app-key). Required for writes/reads.
   * @param {string} [config.apiBase]     API base URL (default https://api.ulink.ly).
   * @param {typeof fetch} [config.fetch] Custom fetch (defaults to global fetch).
   * @param {string} [config.userAgent]   Override the User-Agent header.
   */
  constructor(config = {}) {
    if (!config.apiKey) {
      throw new ULinkError(
        'ULink requires an apiKey. Get a free key at https://ulink.ly/dashboard (no credit card).'
      );
    }
    this.apiKey = config.apiKey;
    this.apiBase = (config.apiBase || DEFAULT_API_BASE).replace(/\/+$/, '');
    this._fetch = config.fetch || globalThis.fetch;
    this.userAgent = config.userAgent || DEFAULT_UA;
    if (typeof this._fetch !== 'function') {
      throw new ULinkError('No fetch implementation found. Pass config.fetch on runtimes without a global fetch.');
    }
  }

  async _request(path, { method = 'GET', body } = {}) {
    const headers = {
      'x-app-key': this.apiKey,
      'User-Agent': this.userAgent,
      Accept: 'application/json',
    };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    const res = await this._fetch(`${this.apiBase}${path}`, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json;
    try {
      json = text ? JSON.parse(text) : {};
    } catch {
      throw new ULinkError(`ULink API ${method} ${path} returned non-JSON (${res.status})`, {
        status: res.status,
        body: text,
      });
    }
    if (!res.ok) {
      throw new ULinkError(
        `ULink API ${method} ${path} → ${res.status}: ${json?.message || json?.error || 'request failed'}`,
        { status: res.status, body: json }
      );
    }
    return json;
  }

  /**
   * Create a dynamic/universal link.
   * @param {object} params
   * @param {string} [params.slug]                 Custom path; omit to auto-generate.
   * @param {'unified'|'dynamic'} [params.type]    Default 'unified'.
   * @param {string} [params.fallbackUrl]          Web/desktop fallback.
   * @param {string} [params.deepLink]             In-app deep link to open (e.g. myapp://product/42).
   * @param {string} [params.iosUrl]               iOS-specific fallback.
   * @param {string} [params.androidUrl]           Android-specific fallback.
   * @param {object} [params.parameters]           Extra forwarded params (utm_*, custom). source=js-sdk is added.
   * @param {boolean} [params.allowQueryPassthrough] Forward query to app. Default true.
   * @param {object} [params.metadata]             { ogTitle, ogDescription, ogImage }.
   * @returns {Promise<object>} the created link (includes shortUrl).
   */
  async createLink(params = {}) {
    const parameters = pruneEmpty({ ...(params.parameters || {}) });
    if (params.deepLink) parameters.deepLink = params.deepLink;
    if (!parameters.source) parameters.source = SDK_SOURCE; // instrumentation
    const payload = pruneEmpty({
      type: params.type || 'unified',
      slug: params.slug,
      fallbackUrl: params.fallbackUrl,
      iosUrl: params.iosUrl,
      androidUrl: params.androidUrl,
      parameters,
      allowQueryPassthrough: params.allowQueryPassthrough !== false,
      metadata: params.metadata,
    });
    return this._request('/sdk/links', { method: 'POST', body: payload });
  }

  /**
   * Resolve a short URL: where it routes per platform + forwarded attribution.
   * @param {string} shortUrl
   * @returns {Promise<object>}
   */
  async resolve(shortUrl) {
    if (!shortUrl) throw new ULinkError('resolve requires a short URL.');
    return this._request(`/sdk/resolve?url=${encodeURIComponent(shortUrl)}`);
  }

  /** Alias of resolve() for read-back semantics. */
  getLink(shortUrl) {
    return this.resolve(shortUrl);
  }
}

export default ULink;
