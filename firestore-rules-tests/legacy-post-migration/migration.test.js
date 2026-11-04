// Pure tests for the legacy-post normalizer. These need NO emulator: they exercise the
// before/after contract over plain maps. Run: node --test firestore-rules-tests/legacy-post-migration/migration.test.js
//
// The emulator round-trip (that the normalized output actually satisfies the deployed
// create rule and a second pass is a no-op against real documents) lives in
// migration_emulator.test.js.

'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const {
  classifyPost,
  normalizePost,
  planMigration,
  applyMigration,
  REQUIRED_KEYS,
} = require('./migration.js');

const NOW = 1730000000000;

// A pre-feed post exactly as the Stage 9.3 audit found 19 of them in production.
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

const modernPost = (overrides = {}) => ({
  authorUid: 'uid_nadia',
  authorName: 'Nadia Islam',
  text: 'Camp this Friday.',
  imageUrls: ['https://cdn/a.jpg'],
  imagePaths: ['post-images/uid_nadia/a.jpg'],
  likeCount: 0,
  commentCount: 0,
  createdAt: 1729500000000,
  updatedAt: 1729500000000,
  ...overrides,
});

describe('classifyPost', () => {
  it('calls the audited legacy shape legacy', () => {
    assert.strictEqual(classifyPost(legacyPost()), 'legacy');
  });

  it('calls a fully modern document modern', () => {
    assert.strictEqual(classifyPost(modernPost()), 'modern');
  });

  it('calls a modern document that still carries a stale authorEmail legacy', () => {
    // The extra key is exactly what a merge-only write would leave behind; classifying
    // it legacy means the migration rewrites it clean.
    assert.strictEqual(classifyPost(modernPost({ authorEmail: 'x@y.z' })), 'legacy');
  });

  it('refuses to touch a document that is not a readable post', () => {
    assert.strictEqual(classifyPost({ text: 'no author' }), 'unreadable');
    assert.strictEqual(classifyPost({ authorUid: '', text: 'x' }), 'unreadable');
    assert.strictEqual(classifyPost(null), 'unreadable');
  });
});

describe('normalizePost', () => {
  it('produces every required modern key', () => {
    const after = normalizePost(legacyPost(), NOW);
    for (const key of REQUIRED_KEYS) {
      assert.ok(
        Object.prototype.hasOwnProperty.call(after, key),
        `missing required key ${key}`,
      );
    }
  });

  it('folds a singular imageUrl up into imageUrls', () => {
    const after = normalizePost(legacyPost({ imageUrl: 'https://cdn/x.jpg' }), NOW);
    assert.deepStrictEqual(after.imageUrls, ['https://cdn/x.jpg']);
  });

  it('an absent or blank image becomes an empty list, not a one-element junk list', () => {
    assert.deepStrictEqual(normalizePost(legacyPost({ imageUrl: null }), NOW).imageUrls, []);
    assert.deepStrictEqual(normalizePost(legacyPost({ imageUrl: '' }), NOW).imageUrls, []);
    const noImage = legacyPost();
    delete noImage.imageUrl;
    assert.deepStrictEqual(normalizePost(noImage, NOW).imageUrls, []);
  });

  it('defaults imagePaths to empty (the legacy schema had no storage paths)', () => {
    assert.deepStrictEqual(normalizePost(legacyPost(), NOW).imagePaths, []);
  });

  it('carries likeCount forward and starts a missing commentCount at zero', () => {
    const after = normalizePost(legacyPost({ likeCount: 7 }), NOW);
    assert.strictEqual(after.likeCount, 7);
    assert.strictEqual(after.commentCount, 0);
  });

  it('drops the legacy keys the modern schema has no place for', () => {
    const after = normalizePost(legacyPost({ donationRecordId: 'dr_9' }), NOW);
    assert.ok(!('authorEmail' in after));
    assert.ok(!('imageUrl' in after));
    assert.ok(!('donationRecordId' in after));
  });

  it('preserves createdAt and stamps a missing updatedAt from it', () => {
    const after = normalizePost(legacyPost({ createdAt: 111 }), NOW);
    assert.strictEqual(after.createdAt, 111);
    assert.strictEqual(after.updatedAt, 111);
  });

  it('only uses now for a timestamp the document never had at all', () => {
    const bare = { authorUid: 'u', authorName: 'U', text: 'hi' };
    const after = normalizePost(bare, NOW);
    assert.strictEqual(after.createdAt, NOW);
    assert.strictEqual(after.updatedAt, NOW);
  });

  it('keeps a well-formed optional pass-through field', () => {
    const after = normalizePost(legacyPost({ authorPhotoUrl: 'https://cdn/p.jpg' }), NOW);
    assert.strictEqual(after.authorPhotoUrl, 'https://cdn/p.jpg');
  });

  it('is idempotent: normalizing a modern post returns an equal one', () => {
    const once = normalizePost(legacyPost(), NOW);
    const twice = normalizePost(once, NOW);
    assert.deepStrictEqual(twice, once);
  });

  it('refuses to normalize an unreadable document', () => {
    assert.throws(() => normalizePost({ text: 'x' }, NOW), /unreadable/);
  });
});

describe('planMigration', () => {
  const mixed = [
    { id: 'legacy-1', data: legacyPost() },
    { id: 'legacy-2', data: legacyPost({ imageUrl: null }) },
    { id: 'modern-1', data: modernPost() },
    { id: 'junk-1', data: { text: 'no author at all' } },
  ];

  it('splits the corpus into migrations, noops and unreadable', () => {
    const plan = planMigration(mixed, NOW);
    assert.deepStrictEqual(plan.migrations.map((m) => m.id).sort(), ['legacy-1', 'legacy-2']);
    assert.deepStrictEqual(plan.noops, ['modern-1']);
    assert.deepStrictEqual(plan.unreadable, ['junk-1']);
  });

  it('records a verbatim backup of every document it will rewrite', () => {
    const plan = planMigration(mixed, NOW);
    const ids = plan.backups.map((b) => b.id).sort();
    assert.deepStrictEqual(ids, ['legacy-1', 'legacy-2']);
    // The backup is the ORIGINAL shape, not the normalized one — rollback fidelity.
    const backup = plan.backups.find((b) => b.id === 'legacy-1').before;
    assert.strictEqual(backup.authorEmail, 'ayesha@example.com');
    assert.strictEqual(backup.imageUrl, 'https://cdn/post-1.jpg');
  });

  it('plans nothing for an all-modern corpus (a re-run is empty)', () => {
    const plan = planMigration([{ id: 'm', data: modernPost() }], NOW);
    assert.strictEqual(plan.migrations.length, 0);
    assert.deepStrictEqual(plan.noops, ['m']);
  });
});

describe('applyMigration', () => {
  // A stand-in db + SDK: the function must only call setDoc(doc(db,'posts',id), after).
  const makeDeps = () => {
    const written = [];
    const calls = [];
    return {
      written,
      calls,
      deps: {
        doc: (_db, collection, id) => ({ collection, id }),
        setDoc: async (ref, data) => {
          calls.push(ref.id);
          written.push({ id: ref.id, data });
        },
      },
    };
  };

  it('writes exactly the planned migrations, replaced not merged', () => {
    const { written, calls, deps } = makeDeps();
    const plan = planMigration(
      [
        { id: 'legacy-1', data: legacyPost() },
        { id: 'modern-1', data: modernPost() },
      ],
      NOW,
    );

    return applyMigration({}, plan, deps).then((results) => {
      assert.deepStrictEqual(results, ['legacy-1']);
      assert.deepStrictEqual(calls, ['legacy-1']);
      // A full replace: no legacy key survives in the written payload.
      assert.ok(!('authorEmail' in written[0].data));
      assert.ok(Array.isArray(written[0].data.imageUrls));
    });
  });

  it('hands every pre-write document to the backup sink', () => {
    const { deps } = makeDeps();
    const backedUp = [];
    const plan = planMigration([{ id: 'legacy-9', data: legacyPost() }], NOW);

    return applyMigration({}, plan, deps, (id, before) =>
      backedUp.push({ id, before })).then(() => {
      assert.deepStrictEqual(backedUp.map((b) => b.id), ['legacy-9']);
      assert.strictEqual(backedUp[0].before.authorEmail, 'ayesha@example.com');
    });
  });
});
