// Emulator round-trip for the legacy-post migration. Runs the plan/write/read cycle
// against the in-memory emulator only — never a live project. Invoked under
// `firebase emulators:exec` alongside the rules suite; the pure contract lives in
// migration.test.js.
//
// Why everything happens inside `withSecurityRulesDisabled`: rewriting a legacy post
// into the modern shape is an ADMIN operation. The normalized document keeps its
// original `likeCount` (non-zero) and its historical `createdAt`, which the deployed
// create rule would refuse (it demands `likeCount == 0` and `createdAt == request.time`),
// and a full `setDoc` replace is not the narrow author-only `update` the rule allows.
// The migration is a privileged maintenance job, so the emulator drives it with rules
// disabled exactly as a production run would with a service account — and, like the
// whole suite, pointed at the emulator and never at the live project.
//
// The handle is a context `.firestore()`, which is the same `firebase` class the modular
// `doc/collection/getDocs/setDoc` functions accept; `testEnv.adminFirestore` is a
// different (bundled) class and is rejected by those functions.

'use strict';

const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, getDocs, collection, setDoc } = require('firebase/firestore');

const { planMigration, classifyPost, applyMigration } = require('./migration.js');

const NOW = 1730000000000;

let testEnv;

before(async () => {
  const rules = fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-solovvo-tests',
    firestore: { host: '127.0.0.1', port: 8080, rules },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

const legacyPost = (overrides = {}) => ({
  authorEmail: 'ayesha@example.com',
  authorName: 'Ayesha Rahman',
  authorUid: 'uid_ayesha',
  createdAt: 1729000000000,
  imageUrl: 'https://cdn/post-1.jpg',
  likeCount: 3,
  text: 'Donated at Dhaka Medical today.',
  ...overrides,
});

// Seeds `seedDocs` ([{id, data}]), runs the plan + apply once, then re-reads every
// post. Returns { plan, after } where `after` maps document id -> stored data, so each
// test can assert both the plan split and the physical result of the write.
//
// `withSecurityRulesDisabled` awaits the callback but does not forward its return
// value, so the result is captured into an outer binding rather than returned.
const migrateCycle = async (seedDocs) => {
  let captured;
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    const db = adminCtx.firestore();

    for (const { id, data } of seedDocs) {
      await setDoc(doc(db, 'posts', id), data);
    }

    const readAll = async () =>
      (await getDocs(collection(db, 'posts'))).docs.map((d) => ({ id: d.id, data: d.data() }));

    const plan = planMigration(await readAll(), NOW);
    await applyMigration(db, plan, { doc, setDoc });

    const after = {};
    for (const { id, data } of await readAll()) {
      after[id] = data;
    }
    captured = { plan, after };
  });
  return captured;
};

// Re-plans over the CURRENT physical documents (no re-seed) — used to prove a second
// migration pass is a no-op against what the first pass actually left behind.
const replanCurrent = async () => {
  let captured;
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    const db = adminCtx.firestore();
    const documents = (await getDocs(collection(db, 'posts'))).docs.map((d) => ({
      id: d.id,
      data: d.data(),
    }));
    captured = planMigration(documents, NOW);
  });
  return captured;
};

describe('legacy-post migration against the emulator', () => {
  it('turns a seeded legacy post into the modern shape and drops the legacy keys', async () => {
    const { plan, after } = await migrateCycle([{ id: 'legacy-1', data: legacyPost() }]);

    assert.strictEqual(plan.migrations.length, 1);

    const afterDoc = after['legacy-1'];
    assert.ok(Array.isArray(afterDoc.imageUrls));
    assert.deepStrictEqual(afterDoc.imageUrls, ['https://cdn/post-1.jpg']);
    assert.deepStrictEqual(afterDoc.imagePaths, []);
    assert.strictEqual(afterDoc.commentCount, 0);
    assert.ok(afterDoc.updatedAt !== undefined);
    assert.ok(!('authorEmail' in afterDoc), 'stale authorEmail must be gone');
    assert.ok(!('imageUrl' in afterDoc), 'singular imageUrl must be gone');
    assert.strictEqual(classifyPost(afterDoc), 'modern');
  });

  it('is idempotent: running the plan a second time migrates nothing', async () => {
    const seeds = [
      { id: 'legacy-1', data: legacyPost() },
      { id: 'legacy-2', data: legacyPost({ imageUrl: null, likeCount: 0 }) },
    ];

    // First pass normalizes both; second pass over the SAME physical documents
    // (not re-seeded) must find nothing left to do.
    const first = await migrateCycle(seeds);
    assert.strictEqual(first.plan.migrations.length, 2);

    const second = await replanCurrent();
    assert.strictEqual(second.migrations.length, 0, 'nothing left to normalize');
    assert.deepStrictEqual(second.noops.sort(), ['legacy-1', 'legacy-2']);
  });

  it('leaves an already-modern document byte-for-byte untouched', async () => {
    const modern = {
      authorUid: 'uid_nadia',
      authorName: 'Nadia Islam',
      text: 'Camp this Friday.',
      imageUrls: ['https://cdn/a.jpg'],
      imagePaths: ['post-images/a.jpg'],
      likeCount: 0,
      commentCount: 2,
      createdAt: 1729500000000,
      updatedAt: 1729600000000,
    };
    const { plan, after } = await migrateCycle([{ id: 'modern-1', data: modern }]);

    assert.strictEqual(plan.migrations.length, 0);
    assert.deepStrictEqual(plan.noops, ['modern-1']);
    assert.strictEqual(after['modern-1'].commentCount, 2, 'a modern counter must not be reset');
    assert.deepStrictEqual(after['modern-1'].imagePaths, ['post-images/a.jpg']);
  });

  it('refuses to rewrite an unreadable document, and records it', async () => {
    const { plan, after } = await migrateCycle([
      { id: 'junk-1', data: { text: 'a body with no author' } },
    ]);

    assert.deepStrictEqual(plan.unreadable, ['junk-1']);
    assert.strictEqual(plan.migrations.length, 0);

    // Still there, still untouched — the migration did not guess an author.
    assert.ok(!('imageUrls' in after['junk-1']));
    assert.strictEqual(after['junk-1'].text, 'a body with no author');
  });

  it('preserves unrelated fields the modern schema tolerates (authorPhotoUrl) across a rewrite', async () => {
    const { after } = await migrateCycle([
      { id: 'legacy-photo', data: legacyPost({ authorPhotoUrl: 'https://cdn/me.jpg' }) },
    ]);
    assert.strictEqual(after['legacy-photo'].authorPhotoUrl, 'https://cdn/me.jpg');
    assert.strictEqual(after['legacy-photo'].likeCount, 3, 'existing counter carried forward');
  });
});
