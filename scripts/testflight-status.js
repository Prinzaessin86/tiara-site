#!/usr/bin/env node
/*
 * TestFlight status poller  (TIA-28)
 * -----------------------------------
 * Asks App Store Connect "what build is live for each app" using the
 * App Store Connect API key (.p8), and writes release-status.json at the repo
 * root. Tiara (index.html) reads that file and shows a live ✈ TestFlight chip
 * on each matching app card. The key never leaves the CI server.
 *
 * Auth: a short-lived ES256 JWT signed with the .p8, per Apple's spec.
 * Requires only Node's built-in crypto + global fetch (Node 18+). No npm deps.
 *
 * Env (from GitHub Actions secrets):
 *   ASC_KEY_ID     – the Key ID from App Store Connect
 *   ASC_ISSUER_ID  – the Issuer ID
 *   ASC_API_KEY_P8 – the full contents of the .p8 file (BEGIN PRIVATE KEY…)
 */
const crypto = require('crypto');
const fs = require('fs');

const KEY_ID    = process.env.ASC_KEY_ID;
const ISSUER_ID = process.env.ASC_ISSUER_ID;
const P8        = process.env.ASC_API_KEY_P8;
const OUT       = 'release-status.json';
const API       = 'https://api.appstoreconnect.apple.com';

if (!KEY_ID || !ISSUER_ID || !P8) {
  console.error('Missing ASC_KEY_ID / ASC_ISSUER_ID / ASC_API_KEY_P8 secrets.');
  process.exit(1);
}

const b64url = buf =>
  Buffer.from(buf).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

// Apple wants a JWT: ES256, kid=KeyID, iss=IssuerID, aud=appstoreconnect-v1, exp ≤ 20min.
function makeToken() {
  const now = Math.floor(Date.now() / 1000);
  const header  = { alg: 'ES256', kid: KEY_ID, typ: 'JWT' };
  const payload = { iss: ISSUER_ID, iat: now, exp: now + 18 * 60, aud: 'appstoreconnect-v1' };
  const input = b64url(JSON.stringify(header)) + '.' + b64url(JSON.stringify(payload));
  // dsaEncoding ieee-p1363 = raw r||s, which is what JOSE/JWT expects (not DER).
  const sig = crypto.sign('SHA256', Buffer.from(input), { key: P8, dsaEncoding: 'ieee-p1363' });
  return input + '.' + b64url(sig);
}

async function asc(path, token) {
  const r = await fetch(API + path, { headers: { Authorization: 'Bearer ' + token } });
  if (!r.ok) throw new Error(`ASC ${r.status} on ${path}: ${(await r.text()).slice(0, 400)}`);
  return r.json();
}

async function main() {
  const token = makeToken();

  // 1) Every app under this key, so we can key the output by bundle id.
  const apps = [];
  let next = '/v1/apps?limit=200&fields[apps]=bundleId,name';
  while (next) {
    const page = await asc(next.replace(API, ''), token);
    for (const a of page.data || []) apps.push(a);
    next = page.links && page.links.next ? page.links.next : null;
  }
  console.log(`Found ${apps.length} apps in App Store Connect.`);

  // 2) Latest build per app (most recently uploaded), plus its marketing version.
  const out = {};
  for (const app of apps) {
    const bundleId = app.attributes && app.attributes.bundleId;
    if (!bundleId) continue;
    try {
      const q = `/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=1`
        + `&include=preReleaseVersion`
        + `&fields[builds]=version,processingState,expired,uploadedDate`
        + `&fields[preReleaseVersions]=version`;
      const res = await asc(q, token);
      const build = (res.data || [])[0];
      if (!build) continue; // app exists but has no TestFlight build yet
      const pre = (res.included || []).find(i => i.type === 'preReleaseVersions');
      out[bundleId] = {
        name: (app.attributes && app.attributes.name) || bundleId,
        version: (pre && pre.attributes && pre.attributes.version) || '',
        build: (build.attributes && build.attributes.version) || '',
        state: (build.attributes && build.attributes.processingState) || '',
        expired: !!(build.attributes && build.attributes.expired),
        uploaded: (build.attributes && build.attributes.uploadedDate) || '',
      };
    } catch (e) {
      console.error(`  skip ${bundleId}: ${e.message}`);
    }
  }

  // Stable key order → clean git diffs (only real changes commit).
  const sorted = {};
  for (const k of Object.keys(out).sort()) sorted[k] = out[k];
  const payload = { generated: new Date().toISOString(), apps: sorted };
  fs.writeFileSync(OUT, JSON.stringify(payload, null, 2) + '\n');
  console.log(`Wrote ${OUT} with ${Object.keys(sorted).length} live TestFlight builds.`);
}

main().catch(e => { console.error(e); process.exit(1); });
