#!/usr/bin/env node
'use strict';

// Thin npm launcher for the ULink CLI.
//
// The CLI itself is a Dart program compiled to native binaries and published
// as GitHub Release assets on FlywheelStudio/ulink_cli. This package does not
// bundle those binaries; on first run it downloads the one matching the host
// platform + this package's version, verifies its checksum, caches it under
// ~/.ulink/npm/<version>/, then execs it transparently with the user's args.

const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const pkg = require('../package.json');

const REPO = 'FlywheelStudio/ulink_cli';
// The npm version maps 1:1 to a release tag (v1.2.0). Override for testing.
const VERSION = process.env.ULINK_CLI_VERSION || `v${pkg.version}`;

// Map host platform/arch to the release asset name produced by release.yml.
function assetName() {
  const platform = os.platform();
  const arch = os.arch();
  const table = {
    'darwin:arm64': 'ulink-macos-arm64',
    'darwin:x64': 'ulink-macos-x64',
    'linux:x64': 'ulink-linux-x64',
    'win32:x64': 'ulink-windows-x64.exe',
  };
  const asset = table[`${platform}:${arch}`];
  if (!asset) {
    throw new Error(
      `Unsupported platform: ${platform}/${arch}.\n` +
        `Supported: macOS (arm64/x64), Linux (x64), Windows (x64).\n` +
        `See ${pkg.homepage} for manual installation.`
    );
  }
  return asset;
}

const isWindows = os.platform() === 'win32';
const binDir = path.join(os.homedir(), '.ulink', 'npm', VERSION);
const binPath = path.join(binDir, isWindows ? 'ulink.exe' : 'ulink');

// GET with redirect-following (GitHub release URLs 302 to a CDN host).
function download(url, redirects = 0) {
  return new Promise((resolve, reject) => {
    if (redirects > 5) return reject(new Error('Too many redirects'));
    https
      .get(url, { headers: { 'User-Agent': '@ulinkly/cli' } }, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          res.resume();
          return resolve(download(res.headers.location, redirects + 1));
        }
        if (res.statusCode !== 200) {
          res.resume();
          return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
        }
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => resolve(Buffer.concat(chunks)));
        res.on('error', reject);
      })
      .on('error', reject);
  });
}

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

// checksums.txt lines look like: "<hex>  ulink-macos-arm64"
function expectedChecksum(text, asset) {
  for (const line of text.split('\n')) {
    const m = line.trim().match(/^([a-f0-9]{64})\s+\*?(.+)$/i);
    if (m && m[2].trim() === asset) return m[1].toLowerCase();
  }
  return null;
}

async function ensureBinary() {
  if (fs.existsSync(binPath)) return binPath;

  const asset = assetName();
  const base = `https://github.com/${REPO}/releases/download/${VERSION}`;
  process.stderr.write(`Fetching ULink CLI ${VERSION} (${asset})…\n`);

  const bin = await download(`${base}/${asset}`);

  // Verify against the published checksums when available; fail closed on a
  // genuine mismatch, but tolerate a missing/unreachable checksums.txt.
  try {
    const sums = await download(`${base}/checksums.txt`);
    const expected = expectedChecksum(sums.toString('utf8'), asset);
    if (expected) {
      const actual = sha256(bin);
      if (actual !== expected) {
        throw new Error(
          `Checksum mismatch for ${asset}\n  expected ${expected}\n  got      ${actual}`
        );
      }
    }
  } catch (err) {
    if (/Checksum mismatch/.test(err.message)) throw err;
    process.stderr.write(`Warning: skipping checksum verification (${err.message})\n`);
  }

  fs.mkdirSync(binDir, { recursive: true });
  const tmp = `${binPath}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, bin);
  fs.chmodSync(tmp, 0o755);
  fs.renameSync(tmp, binPath); // atomic publish into the cache
  return binPath;
}

ensureBinary()
  .then((bin) => {
    const res = spawnSync(bin, process.argv.slice(2), { stdio: 'inherit' });
    if (res.error) throw res.error;
    process.exit(res.status === null ? 1 : res.status);
  })
  .catch((err) => {
    process.stderr.write(`ulink: ${err.message}\n`);
    process.exit(1);
  });
