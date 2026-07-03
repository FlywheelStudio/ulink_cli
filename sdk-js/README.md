# ULink for JavaScript / React Native — the Firebase Dynamic Links alternative

Dynamic links that route users to the right screen, survive install, and work across iOS & Android —
in a few lines of JavaScript. Built for the post-FDL world: Firebase Dynamic Links
[shut down Aug 25, 2025](https://firebase.google.com/support/dynamic-links-faq).

> Status: **v0.1.0 — staged, not yet published to npm.** Publish is gated on board consent + a QA
> claims-check. The client below works today against `api.ulink.ly`.

**Why ULink**
- 🎯 A drop-in *link* SDK — not a heavyweight attribution suite you adopt wholesale.
- ⚡ Self-serve: grab an API key and create your first link in minutes.
- 🧩 Zero deps, `fetch`-based — runs in Node 18+, React Native, browsers, and edge runtimes.

## Install

```bash
npm install @ulinkly/sdk
```

## Quickstart (a working link in <10 lines)

```js
import { ULink } from '@ulinkly/sdk';

const ulink = new ULink({ apiKey: 'your_api_key' }); // get one at https://ulink.ly

const link = await ulink.createLink({
  slug: 'welcome',
  deepLink: 'myapp://profile/12345',
  fallbackUrl: 'https://example.com',
  iosUrl: 'https://apps.apple.com/app/myapp',
  androidUrl: 'https://play.google.com/store/apps/details?id=com.myapp',
  parameters: { screen: 'profile', userId: '12345' },
});

console.log(link.shortUrl); // https://yourdomain/welcome

// Confirm it routes + preserves your params:
const resolved = await ulink.resolve(link.shortUrl);
```

## API

| Method | Purpose |
|---|---|
| `new ULink({ apiKey, apiBase?, fetch?, userAgent? })` | Create a client. |
| `createLink(params)` | Create a dynamic/universal link. Returns the link incl. `shortUrl`. |
| `resolve(shortUrl)` / `getLink(shortUrl)` | Read back where a link routes per platform + forwarded attribution. |

Forwarded params (including your `utm_*` and any custom keys) ride along with `allowQueryPassthrough`
so they reach the app on open — attribution preserved end to end. Links created via this SDK are
tagged `source=js-sdk`.

## React Native

The client is `fetch`-based and has no Node-only dependencies, so it works as-is in React Native for
creating and resolving links. Pair it with your platform's universal-link / app-link handler (AASA on
iOS, `assetlinks.json` on Android) — see [docs.ulink.ly/quickstart](https://docs.ulink.ly/quickstart?utm_source=npm&utm_medium=readme&utm_campaign=listing_v2).

## Migrating off Firebase Dynamic Links?

Use the [`ulink` CLI](https://www.npmjs.com/package/@ulinkly/cli): `ulink import firebase` recreates
your FDL links in ULink with routing + attribution preserved.

---

👉 **Get your API key at [ulink.ly](https://ulink.ly/?utm_source=npm&utm_medium=readme&utm_campaign=listing_v2)
and finish the 5-minute quickstart:
[docs.ulink.ly/quickstart](https://docs.ulink.ly/quickstart?utm_source=npm&utm_medium=readme&utm_campaign=listing_v2)**

MIT © ULink
