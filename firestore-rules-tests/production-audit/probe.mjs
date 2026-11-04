// Read-only production Firestore probe for the Stage 9.3 compatibility audit.
//
// Uses the ALREADY-AUTHENTICATED Firebase CLI user credential (the same one
// `firebase apps:list` uses), refreshed in memory from
// ~/.config/configstore/firebase-tools.json. It never prints secret material.
//
// Every request is a GET or a `documents/{list}` POST, which is a read. The
// Admin API bypasses security rules, so what this script can see is exactly
// what the deployed rules protect — nothing here can forge or modify data.
//
// Run with: node firestore-rules-tests/production-audit/probe.mjs <command> [args]
//   collections                      list top-level collection ids
//   schema <collection> [limit]      field/type census of up to `limit` docs
//   subcollection <collection> <id> <sub>  list a subcollection's shape
//   subs <collection> <id>             list a document's subcollection ids
//   indexes                          list composite indexes (read-only)
//   rules                            fetch the deployed rules source

import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';

const PROJECT = 'sholovvo-blood-donation';
const API = 'https://firestore.googleapis.com/v1';

function loadTokens() {
  const file = path.join(homedir(), '.config', 'configstore', 'firebase-tools.json');
  const cfg = JSON.parse(readFileSync(file, 'utf8'));
  if (!cfg.tokens?.access_token) throw new Error('no stored CLI credential found');
  return cfg.tokens;
}

async function accessToken() {
  const tokens = loadTokens();
  // `expires_at` is stored as epoch milliseconds (a number).
  const expiresAt = Number(tokens.expires_at);
  // The stored access token is used as-is; if it is expired, running any
  // `firebase` command refreshes it in place, so this probe never attempts
  // its own refresh and never prints credential material.
  if (Number.isFinite(expiresAt) && expiresAt > Date.now() + 60_000) {
    return tokens.access_token;
  }
  throw new Error('stored access token expired - run any read-only firebase command to refresh it, then rerun this probe');
}

async function get(url) {
  const token = await accessToken();
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (res.status === 401) throw new Error('token rejected: refresh needed (CLI will do it transparently when any firebase command runs)');
  if (!res.ok) throw new Error(`GET ${url.split('?')[0]} -> ${res.status} ${JSON.stringify((await res.json().catch(() => null)))?.slice(0, 300)}`);
  return res.json();
}

function encodeValue(v) {
  if (v == null) return 'NULL';
  if (v.stringValue !== undefined) return `"${v.stringValue}"`;
  if (v.integerValue !== undefined) return `int ${v.integerValue}`;
  if (v.doubleValue !== undefined) return `double ${v.doubleValue}`;
  if (v.booleanValue !== undefined) return `bool ${v.booleanValue}`;
  if (v.timestampValue !== undefined) return `timestamp`;
  if (v.geoPointValue !== undefined) return `geopoint`;
  if (v.arrayValue !== undefined) return `list[${v.arrayValue.values?.length ?? 0}] {${(v.arrayValue.values ?? []).slice(0, 3).map(encodeValue).join(', ')}}`;
  if (v.mapValue !== undefined) return `map{${Object.keys(v.mapValue.fields ?? {}).slice(0, 8).join(', ')}}`;
  if (v.referenceValue !== undefined) return `reference`;
  return Object.keys(v).join('|');
}

function census(docs) {
  const fields = new Map();
  for (const doc of docs) {
    for (const [k, v] of Object.entries(doc.fields ?? {})) {
      const t = encodeValue(v);
      const base = t.startsWith('"') ? 'string' : t.split(' ')[0].split('[')[0].split('{')[0];
      if (!fields.has(k)) fields.set(k, new Map());
      const kinds = fields.get(k);
      kinds.set(base, (kinds.get(base) ?? 0) + 1);
    }
  }
  return fields;
}

const [cmd, ...args] = process.argv.slice(2);
const base = `${API}/projects/${PROJECT}/databases/(default)/documents`;

if (cmd === 'collections') {
  const token = await accessToken();
  const res = await fetch(`${base}:listCollectionIds`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ pageSize: 100 }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`listCollectionIds -> ${res.status} ${JSON.stringify(json).slice(0, 300)}`);
  console.log('collectionIds:', JSON.stringify(json.collectionIds ?? []));
} else if (cmd === 'schema') {
  const [coll, limitStr] = args;
  const limit = Number(limitStr ?? 50);
  const token = await accessToken();
  // Plain list (a GET): documents come back ordered by id, page size up to 300.
  const res = await fetch(`${base}/${encodeURIComponent(coll)}?pageSize=${Math.min(limit, 300)}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`list -> ${res.status} ${JSON.stringify(json).slice(0, 300)}`);
  const docs = json.documents ?? [];
  console.log(`collection ${coll}: sampled ${docs.length} document(s)`);
  for (const doc of docs.slice(0, 5)) console.log('  doc', doc.name.split('/documents/')[1], 'fields:', Object.keys(doc.fields ?? {}).sort().join(', '));
  const fields = census(docs);
  for (const [k, kinds] of [...fields].sort()) console.log(`  ${k}: ${[...kinds].map(([t, n]) => `${t} x${n}`).join(', ')}`);
} else if (cmd === 'subcollection') {
  const [coll, id, sub] = args;
  const token = await accessToken();
  const url = `${base}/${encodeURIComponent(coll)}/${encodeURIComponent(id)}/${encodeURIComponent(sub)}`;
  const res = await fetch(`${url}?pageSize=50`, { headers: { Authorization: `Bearer ${token}` } });
  const json = await res.json();
  if (!res.ok) throw new Error(`list -> ${res.status} ${JSON.stringify(json).slice(0, 300)}`);
  const docs = json.documents ?? [];
  console.log(`${coll}/${id}/${sub}: ${docs.length} document(s)`);
  const fields = census(docs);
  for (const [k, kinds] of [...fields].sort()) console.log(`  ${k}: ${[...kinds].map(([t, n]) => `${t} x${n}`).join(', ')}`);
} else if (cmd === 'subs') {
  // List the subcollections that exist under a given document.
  const [coll, id] = args;
  const token = await accessToken();
  const res = await fetch(`${base}/${encodeURIComponent(coll)}/${encodeURIComponent(id)}:listCollectionIds`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`listCollectionIds -> ${res.status} ${JSON.stringify(json).slice(0, 300)}`);
  console.log(`${coll}/${id} subcollections:`, JSON.stringify(json.collectionIds ?? []));
} else if (cmd === 'indexes') {
  const token = await accessToken();
  const res = await fetch(`${API}/projects/${PROJECT}/databases/(default)/collectionIndexes`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`indexes -> ${res.status} ${JSON.stringify(json).slice(0, 300)}`);
  const idx = json.collectionIndexes ?? [];
  console.log(`composite indexes: ${idx.length}`);
  for (const i of idx) console.log('  ', i.collection, (i.indexFields ?? []).map((f) => `${f.fieldPath}:${f.mode}`).join(', '));
} else if (cmd === 'rules') {
  const token = await accessToken();
  const res = await fetch(`https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases?pageSize=100`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`releases -> ${res.status} ${JSON.stringify(json).slice(0, 300)}`);
  for (const r of json.releases ?? []) console.log('release:', r.name, 'rules:', r.rules?.name);
} else if (cmd === 'activelink') {
  // The ruleset currently served in production, via the dataset link.
  const token = await accessToken();
  const link = await fetch(`https://firebaserules.googleapis.com/v1/projects/${PROJECT}/datasets/(default)/links`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const lj = await link.json();
  if (!link.ok) throw new Error(`links -> ${link.status} ${JSON.stringify(lj).slice(0, 300)}`);
  for (const l of lj.links ?? []) {
    console.log('link:', l.name, '-> ruleset:', l.spec?.source?.files?.[0]?.name ?? l.name);
    const files = l.spec?.source?.files ?? [];
    for (const f of files) {
      const content = f.content ?? '';
      console.log(`--- ${f.name} (${content.length} chars) ---`);
      // Print only the lines that matter for compatibility: the feed + donors.
      const keep = content.split('\n').filter((ln) => /match\s+\/(posts|post_likes|comments|likes|donors|requests|reports|blood_requests)/.test(ln) || /allow\s+(read|write|create|update|delete)/.test(ln));
      console.log(keep.join('\n'));
    }
  }
} else {
  console.error('unknown command');
  process.exit(2);
}
