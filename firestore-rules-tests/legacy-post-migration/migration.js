// Legacy-post normalization — pure logic, safe to run against emulator fixtures.
//
// This module NEVER talks to Firestore by itself. `classifyPost` and `normalizePost`
// are pure functions over a plain document map, so the whole before/after contract
// can be exercised with `node --test` and no emulator. Only `applyMigration` reaches a
// database, and the only place it is ever pointed at is the emulator (`FIRESTORE_EMULATOR_HOST`),
// never a live project — the caller must hand it an already-connected admin `db`.
//
// WHY THIS EXISTS. The Stage 9.3 read-only production audit found 19 live posts written
// in a pre-feed schema (singular `imageUrl`, an `authorEmail` snapshot, no `imageUrls`/
// `imagePaths`/`commentCount`/`updatedAt`) alongside 1 already in the Stage 9.2 schema.
// The reconciled `firestore.rules` create contract accepts only the modern shape, so
// once those rules deploy the legacy documents still READ fine (`allow read` is
// unconditional) but can no longer be WRITTEN by their old client without failing the
// create/update key set. Normalizing them forward is what keeps those 19 posts editable
// after the rules land. It is prepared here, run against emulator fixtures only, and is
// NOT deployed against production without the owner's sign-off (see MIGRATION_PLAN.md).

'use strict';

// The nine keys the Stage 9.2 create rule requires, in `hasAll` order.
const REQUIRED_KEYS = Object.freeze([
  'authorUid',
  'authorName',
  'text',
  'imageUrls',
  'imagePaths',
  'likeCount',
  'commentCount',
  'createdAt',
  'updatedAt',
]);

// Keys the modern schema tolerates but a legacy document may still carry. They are
// copied through untouched when present and well-typed, dropped when they are not.
const OPTIONAL_PASSTHROUGH = Object.freeze(['authorPhotoUrl', 'editedAt']);

// Legacy-only keys the modern schema has no place for. `donationRecordId` is named
// because the Stage 9.2 comment says the branch is gone; a stray one is dropped too.
const LEGACY_KEYS_TO_DROP = Object.freeze(['authorEmail', 'imageUrl', 'donationRecordId']);

const isArray = (value) => Array.isArray(value);
const isNonEmptyString = (value) => typeof value === 'string' && value.length > 0;

// A document is a real post only if it has an author id and some text. Everything else
// is repaired or degraded, never invented — an unreadable document is left alone and
// reported so a human can look at it rather than the migration guessing a body.
function isReadablePost(data) {
  return (
    data !== null &&
    typeof data === 'object' &&
    isNonEmptyString(data.authorUid) &&
    typeof data.text === 'string' &&
    data.text.length > 0
  );
}

// Classifies one post document.
//   'modern'   — already satisfies the create key set; migration is a no-op for it.
//   'legacy'   — a readable post that needs normalizing into the modern shape.
//   'unreadable' — not recognisably a post at all; the migration refuses to touch it.
function classifyPost(data) {
  if (!isReadablePost(data)) {
    return 'unreadable';
  }
  const hasAllRequired = REQUIRED_KEYS.every((key) =>
    Object.prototype.hasOwnProperty.call(data, key),
  );
  const hasLegacyKeys = LEGACY_KEYS_TO_DROP.some((key) =>
    Object.prototype.hasOwnProperty.call(data, key),
  );
  if (hasAllRequired && !hasLegacyKeys) {
    return 'modern';
  }
  return 'legacy';
}

// Returns a NEW document in the modern shape. Idempotent: normalizing an already
// modern document returns an equal one, so a re-run cannot double-apply.
//
// `now` is the value written for a timestamp the legacy document never carried
// (`updatedAt`, and `createdAt` in the pathological case). It is injected rather than
// read from a clock so the function stays pure and the test can pin the exact value.
// Against a real database the caller passes the server's Timestamp or
// serverTimestamp(), never a device clock.
function normalizePost(data, now) {
  if (!isReadablePost(data)) {
    throw new Error('normalizePost called on an unreadable post');
  }

  const out = {};

  // Identity and body carry straight across.
  out.authorUid = data.authorUid;
  out.authorName = typeof data.authorName === 'string' ? data.authorName : '';
  out.text = data.text;

  // Media: the plural arrays win if present; otherwise the singular legacy `imageUrl`
  // is folded up into a one-element array. An absent or blank image becomes an empty
  // list, which is what the create rule expects for a text-only post.
  if (isArray(data.imageUrls)) {
    out.imageUrls = data.imageUrls.slice();
  } else if (isNonEmptyString(data.imageUrl)) {
    out.imageUrls = [data.imageUrl];
  } else {
    out.imageUrls = [];
  }
  out.imagePaths = isArray(data.imagePaths) ? data.imagePaths.slice() : [];

  // Counters start where the document left them, defaulting a missing one to zero —
  // a legacy post that predates `commentCount` had no comment model at all.
  out.likeCount = typeof data.likeCount === 'number' ? data.likeCount : 0;
  out.commentCount = typeof data.commentCount === 'number' ? data.commentCount : 0;

  // Timestamps are preserved verbatim when the document had them; only a genuinely
  // missing one falls back to `now`. createdAt is never overwritten if it exists.
  out.createdAt = Object.prototype.hasOwnProperty.call(data, 'createdAt')
    ? data.createdAt
    : now;
  out.updatedAt = Object.prototype.hasOwnProperty.call(data, 'updatedAt')
    ? data.updatedAt
    : (Object.prototype.hasOwnProperty.call(data, 'createdAt') ? data.createdAt : now);

  // Optional pass-through fields, kept only when they are present.
  for (const key of OPTIONAL_PASSTHROUGH) {
    if (Object.prototype.hasOwnProperty.call(data, key)) {
      out[key] = data[key];
    }
  }

  // Anything else the legacy document carried that is neither a modern field nor a
  // recognised optional (a stale `authorEmail`, a `donationRecordId`, a stray key) is
  // simply not copied — so the write drops it. Nothing private is invented; an author
  // email the app no longer reads is the only category removed, and it is preserved in
  // the migration's own backup (see planMigration) rather than discarded.
  return out;
}

// Builds a full migration plan over the given documents WITHOUT writing anything.
//
// Returns { migrations, noops, unreadable, backups }:
//   migrations — [{ id, before, after }] for every legacy document,
//   noops      — [id] for documents already modern,
//   unreadable — [id] for documents the migration refuses to touch,
//   backups    — [{ id, before }] for every document it will rewrite, so a rollback can
//                put the original shape back verbatim. The backup is taken from the
//                same read the plan is built from, so it is always the pre-write state.
function planMigration(documents, now) {
  const migrations = [];
  const noops = [];
  const unreadable = [];
  const backups = [];

  for (const { id, data } of documents) {
    const kind = classifyPost(data);
    if (kind === 'modern') {
      noops.push(id);
      continue;
    }
    if (kind === 'unreadable') {
      unreadable.push(id);
      continue;
    }
    const after = normalizePost(data, now);
    migrations.push({ id, before: data, after });
    backups.push({ id, before: data });
  }

  return { migrations, noops, unreadable, backups };
}

// Writes every planned migration through an ALREADY-CONNECTED database.
//
// `db` is a modular Firestore instance and `deps` injects the SDK functions so this
// stays testable and so the caller controls the environment: the emulator only. A full
// `setDoc` (not a merge) is deliberate — the normalization REMOVES legacy keys, and a
// merge-write would leave `authorEmail` and `imageUrl` behind on the document. Replacing
// the document is what actually gets it to the modern shape. `backup` receives every
// pre-write document so the caller can persist a rollback set outside this function.
async function applyMigration(db, plan, deps, backup = () => {}) {
  const { doc: docRef, setDoc } = deps;
  const results = [];

  for (const { id, before, after } of plan.migrations) {
    backup(id, before);
    await setDoc(docRef(db, 'posts', id), after);
    results.push(id);
  }

  return results;
}

module.exports = {
  REQUIRED_KEYS,
  LEGACY_KEYS_TO_DROP,
  isReadablePost,
  classifyPost,
  normalizePost,
  planMigration,
  applyMigration,
};
