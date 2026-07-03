// Live smoke test for @ulinkly/sdk. Requires ULINK_API_KEY.
import { ULink } from '../src/index.js';

let failed = false;
function check(name, cond, detail) {
  const ok = Boolean(cond);
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`);
  if (!ok) failed = true;
}

if (!process.env.ULINK_API_KEY) {
  console.log('SKIP — ULINK_API_KEY not set');
  process.exit(0);
}

const ulink = new ULink({ apiKey: process.env.ULINK_API_KEY });
const slug = 'sdksmoke' + Math.floor(Date.now() / 1000);

const link = await ulink.createLink({
  slug,
  fallbackUrl: 'https://ulink.ly',
  deepLink: 'myapp://sdk/7',
  parameters: { utm_source: 'jssdk', utm_campaign: 'sdk_e2e' },
});
check('createLink returns shortUrl', link?.shortUrl?.includes(slug), link?.shortUrl);
check('createLink tags source=js-sdk', link?.parameters?.source === 'js-sdk', JSON.stringify(link?.parameters));

const r = await ulink.resolve(link.shortUrl);
check('resolve reads back deepLink', r?.parameters?.deepLink === 'myapp://sdk/7', r?.parameters?.deepLink);
check('resolve preserves attribution', r?.parameters?.utm_source === 'jssdk', JSON.stringify(r?.parameters));

// error path
try {
  new ULink({});
  check('missing apiKey throws', false);
} catch (e) {
  check('missing apiKey throws', e.name === 'ULinkError');
}

console.log(failed ? '\nSDK SMOKE: FAIL' : '\nSDK SMOKE: PASS');
process.exit(failed ? 1 : 0);
