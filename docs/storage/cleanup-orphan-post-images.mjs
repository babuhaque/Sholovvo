#!/usr/bin/env node
/**
 * One-off cleanup of orphaned post photographs.
 *
 * Deleting a post removes its Firestore document but — until the client fix —
 * left the photograph objects in the Supabase `community-posts` bucket behind.
 * This script finds every object in that bucket that NO live `posts` document
 * references any more, and (only when told to) deletes them.
 *
 * It is DRY-RUN BY DEFAULT: it reports what it *would* delete and changes
 * nothing. Pass `--execute` to actually remove the orphaned objects.
 *
 * ---------------------------------------------------------------------------
 * Credentials — environment only. Nothing is read from the repo and nothing
 * secret is ever printed. This is an OWNER maintenance tool: it needs a key
 * that can see every donor's folder, which the donor-scoped app key cannot.
 *
 *   SUPABASE_URL             https://<project-ref>.supabase.co
 *   SUPABASE_SERVICE_KEY     service_role / sb_secret_…  (bypasses RLS)
 *   GOOGLE_APPLICATION_CREDENTIALS   path to a Firebase service-account JSON
 *   FIREBASE_PROJECT_ID      optional; defaults to the service-account project
 *   STORAGE_BUCKET           optional; defaults to `community-posts`
 *
 * Usage:
 *   npm install
 *   node cleanup-orphan-post-images.mjs              # report only (safe)
 *   node cleanup-orphan-post-images.mjs --execute    # delete the orphans
 * ---------------------------------------------------------------------------
 */

import process from 'node:process';

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_KEY;
const bucket = process.env.STORAGE_BUCKET ?? 'community-posts';
const execute = process.argv.slice(2).includes('--execute');

function die(message) {
  console.error(`\n[cleanup] ${message}\n`);
  process.exit(1);
}

if (!url || !serviceKey) {
  die(
    'SUPABASE_URL and SUPABASE_SERVICE_KEY must both be set in the environment. ' +
      'Nothing is read from the repo on purpose.',
  );
}
if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  die(
    'GOOGLE_APPLICATION_CREDENTIALS must point at a Firebase service-account ' +
      'JSON so the script can read the `posts` collection.',
  );
}

// Dynamic imports so a missing dependency fails with a readable message rather
// than a raw module-not-found stack before the argument checks above run.
let admin, firestore, createClient;
try {
  ({ default: admin } = await import('firebase-admin'));
  ({ getFirestore: firestore } = await import('firebase-admin/firestore'));
  ({ createClient } = await import('@supabase/supabase-js'));
} catch (error) {
  die(`failed to load dependencies — run \`npm install\` first (${error.message})`);
}

// ---------------------------------------------------------------------------
// 1. The referenced set: every object path a live post still points at.
// ---------------------------------------------------------------------------
if (process.env.FIREBASE_PROJECT_ID) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: process.env.FIREBASE_PROJECT_ID,
  });
} else {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
}

const db = firestore();
const referenced = new Set();
let postCount = 0;

// `getAll` would need every document id up front; a full collection read is the
// honest way to know what is still referenced. The posts collection is small
// enough that one streamed read is fine for a one-off maintenance pass.
const snapshot = await db.collection('posts').get();
for (const doc of snapshot.docs) {
  postCount++;
  const data = doc.data() ?? {};
  const paths = data.imagePaths;
  if (Array.isArray(paths)) {
    for (const p of paths) {
      if (typeof p === 'string' && p.trim().length > 0) referenced.add(p.trim());
    }
  }
}

// A zero-document read is almost always a wrong project id or a bad service
// account, not a genuinely empty feed. Treating "referenced = empty" as truth
// would mark the WHOLE bucket orphaned and delete every real photo, so refuse.
if (postCount === 0) {
  die(
    'the `posts` collection read returned 0 documents. Refusing to continue: ' +
      'that would flag every object as orphaned. Check FIREBASE_PROJECT_ID and ' +
      'the service-account credentials.',
  );
}

// ---------------------------------------------------------------------------
// 2. The actual objects: recursive listing of the bucket.
// ---------------------------------------------------------------------------
const supabase = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
  global: { headers: {apikey: serviceKey } },
});

const PAGE = 1000;

/**
 * Lists every file under `prefix`, descending into folders.
 *
 * A Supabase folder entry has `id === null`; a file has a non-null id and a
 * `metadata` block. Paths are rebuilt bucket-relative (`{uid}/post-….jpg`) so
 * they line up exactly with the `imagePaths` values read from Firestore.
 */
async function listFiles(prefix = '') {
  const files = [];
  for (let offset = 0; ; offset += PAGE) {
    const { data, error } = await supabase.storage
      .from(bucket)
      .list(prefix, { limit: PAGE, offset, sortBy: { field: 'name', order: 'asc' } });
    if (error) die(`storage list failed under "${prefix}": ${error.message}`);
    if (!data || data.length === 0) break;

    for (const entry of data) {
      const path = prefix.length > 0 ? `${prefix}/${entry.name}` : entry.name;
      if (entry.id === null) {
        files.push(...(await listFiles(path))); // a folder — recurse
      } else {
        files.push({ path, size: entry.metadata?.size ?? 0 });
      }
    }
    if (data.length < PAGE) break; // last page
  }
  return files;
}

const allFiles = await listFiles('');

// ---------------------------------------------------------------------------
// 3. Diff: an object is orphaned when no live post references its path.
// ---------------------------------------------------------------------------
const orphans = allFiles.filter((file) => !referenced.has(file.path));
const orphanBytes = orphans.reduce((sum, file) => sum + (file.size || 0), 0);

const mb = (bytes) => `${(bytes / (1024 * 1024)).toFixed(2)} MB`;

console.log('\n=== Orphaned post-photograph report ===');
console.log(`bucket            : ${bucket}`);
console.log(`live posts read   : ${postCount}`);
console.log(`referenced paths  : ${referenced.size}`);
console.log(`objects in bucket : ${allFiles.length}`);
console.log(`orphans           : ${orphans.length}  (${mb(orphanBytes)})`);

if (orphans.length === 0) {
  console.log('\nNothing to clean up — every object is referenced by a live post.');
  process.exit(0);
}

console.log('\nOrphaned objects:');
for (const file of orphans) {
  console.log(`  - ${file.path}  (${mb(file.size)})`);
}

// ---------------------------------------------------------------------------
// 4. Delete — only with --execute, in batches.
// ---------------------------------------------------------------------------
if (!execute) {
  console.log(
    `\nDRY RUN — nothing deleted. Re-run with --execute to remove the ` +
      `${orphans.length} object(s) above.`,
  );
  process.exit(0);
}

const CHUNK = 100;
let deleted = 0;
for (let i = 0; i < orphans.length; i += CHUNK) {
  const batch = orphans.slice(i, i + CHUNK).map((file) => file.path);
  const { data, error } = await supabase.storage.from(bucket).remove(batch);
  if (error) {
    die(
      `delete failed after removing ${deleted} object(s): ${error.message}. ` +
        'Re-run to continue (already-deleted objects simply come back as absent).',
    );
  }
  deleted += Array.isArray(data) ? data.length : batch.length;
  console.log(`  deleted ${deleted}/${orphans.length}`);
}

console.log(`\nDone — removed ${deleted} orphaned object(s) from "${bucket}".`);
