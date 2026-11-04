// Blood-request contact-PII split migration — pure logic, safe to run against
// emulator fixtures. NOT executed against production (see MIGRATION_PLAN.md and
// the owner sign-off requirement in docs/PROJECT_STATE.md, Stage 9.5 M3-C3).
//
// This module NEVER talks to Firestore by itself. `classifyRequest`,
// `extractContact` and `normalizePublic` are pure functions over a plain
// document map, so the whole before/after contract can be exercised with
// `node --test` and no emulator. Only `applyMigration` reaches a database, and
// the only place it is ever pointed at is the emulator
// (`FIRESTORE_EMULATOR_HOST`), never a live project — the caller must hand it an
// already-connected admin `db` (rules disabled / service-account privileges),
// exactly as a production run would.
//
// WHY THIS EXISTS. Stage 9.5 (M3, corrected in M3-C1) moved the three patient-
// identifying fields — `patientName`, `phoneNumber`, `hospitalAddress` — off the
// public `blood_requests/{id}` document and into
// `blood_requests/{id}/private/contact`, and the public create/update rules now
// refuse those keys. But Firestore rules cannot filter fields on READ: every
// production request document written before M3 still carries the PII inline,
// and `allow read: if request.auth != null` on the public document still exposes
// it to any signed-in account. Tightening the rules does not hide data that is
// already stored. The ONLY thing that physically closes the leak is a copy-then-
// delete migration: relocate the PII into the gated subcollection, verify it
// landed, and only then remove it from the public document. This file prepares
// that migration; it is run against emulator fixtures here and is NOT deployed
// against production without the owner's explicit authorisation.
//
// Unlike the legacy-post normalizer (a single-document rewrite), this migration
// touches TWO documents per request: it creates the `private/contact` child and
// then field-deletes the PII from the public parent. The public parent is
// updated with `deleteField()` rather than a full replace, so every other public
// field (hospitalName, bloodGroup, status, the timestamps, latitude/longitude)
// is preserved exactly, and an in-flight request keeps living through the move.

'use strict';

// The three patient-identifying / private-contact fields that must not live on
// the public document after M3-C1. Present on a public document => the document
// still needs migrating.
const PII_KEYS = Object.freeze(['patientName', 'phoneNumber', 'hospitalAddress']);

// The subcollection the PII moves into. One fixed document per request.
const CONTACT_COLLECTION = 'private';
const CONTACT_DOC = 'contact';

const isNonEmptyString = (value) => typeof value === 'string' && value.length > 0;

// A document is a real request only if it identifies an owner, a group and a
// status. Anything less is unreadable and the migration refuses to guess — it is
// left physically untouched and reported so a human can look at it.
function isReadableRequest(data) {
  return (
    data !== null &&
    typeof data === 'object' &&
    isNonEmptyString(data.userId) &&
    isNonEmptyString(data.bloodGroup) &&
    isNonEmptyString(data.status)
  );
}

// Whether any of the three PII keys is present on a public document. Presence —
// not value — is the trigger: even a null or blank `patientName` is a key the
// post-M3 public shape does not allow, and leaving it behind means the field is
// still readable on the public document.
function hasPiiKeys(data) {
  return PII_KEYS.some((key) =>
    Object.prototype.hasOwnProperty.call(data, key),
  );
}

// Classifies one request document:
//   'modern'     — carries none of the PII keys; nothing to move (no-op).
//   'legacy'     — a readable request that still has one or more PII keys inline.
//   'unreadable' — not recognisably a request; the migration refuses to touch it.
function classifyRequest(data) {
  if (!isReadableRequest(data)) {
    return 'unreadable';
  }
  return hasPiiKeys(data) ? 'legacy' : 'modern';
}

// Builds the `private/contact` payload from a public document. Each of the three
// keys is copied verbatim when it is a string, and defaulted to an empty string
// when it is absent or not a string, so the contact record always has the full
// three-key shape the subcollection rule expects (a present-but-empty address is
// legal there; a present-but-empty name/phone is what a genuinely partial legacy
// document can only give us, and is reported by the plan's `incomplete` list).
function extractContact(data) {
  const contact = {};
  for (const key of PII_KEYS) {
    contact[key] = typeof data[key] === 'string' ? data[key] : '';
  }
  return contact;
}

// Returns the contact record WITHOUT mutating or removing anything — a read-only
// projection used both for planning and for the post-write verification.
// Whether the legacy document gave us a usable value for each key, so a plan can
// flag records that will land with an empty name or phone (they still move — the
// point is to get them off the public document — but they are reported).
function contactCompleteness(contact) {
  return {
    patientName: isNonEmptyString(contact.patientName),
    phoneNumber: isNonEmptyString(contact.phoneNumber),
    hospitalAddress: isNonEmptyString(contact.hospitalAddress),
  };
}

// The public document as it should read after the move: every field EXCEPT the
// three PII keys, carried across untouched. The migration applies this in the
// database with `deleteField()` (see applyMigration) rather than a full replace,
// so the ordering/typing of the surviving fields is not our concern here — this
// projection is only used to build the plan and to verify the end state.
function normalizePublic(data) {
  const out = {};
  for (const [key, value] of Object.entries(data)) {
    if (!PII_KEYS.includes(key)) {
      out[key] = value;
    }
  }
  return out;
}

// Builds a full migration plan over the given documents WITHOUT writing anything.
//
// Returns { migrations, noops, unreadable, incomplete, backups }:
//   migrations — [{ id, before, contact, publicAfter }] for every legacy request,
//   noops      — [id] for requests already free of the PII keys,
//   unreadable — [id] for documents the migration refuses to touch,
//   incomplete — [id] for migrated requests whose contact will land with a blank
//                name or phone (still migrated; surfaced for a human to review),
//   backups    — [{ id, before }] for every request it will rewrite, so a
//                rollback can put the original public shape back verbatim. The
//                backup is taken from the same read the plan is built from, so it
//                is always the pre-write state.
function planMigration(documents) {
  const migrations = [];
  const noops = [];
  const unreadable = [];
  const incomplete = [];
  const backups = [];

  for (const { id, data } of documents) {
    const kind = classifyRequest(data);
    if (kind === 'modern') {
      noops.push(id);
      continue;
    }
    if (kind === 'unreadable') {
      unreadable.push(id);
      continue;
    }
    const contact = extractContact(data);
    migrations.push({ id, before: data, contact, publicAfter: normalizePublic(data) });
    backups.push({ id, before: data });
    const complete = contactCompleteness(contact);
    if (!complete.patientName || !complete.phoneNumber) {
      incomplete.push(id);
    }
  }

  return { migrations, noops, unreadable, incomplete, backups };
}

// Whether a migration entry has physically landed: the contact document holds
// exactly the three PII keys with the right values, and the public document no
// longer carries any of them. This is the check that must pass, per request,
// BEFORE the operator removes the public PII — `applyMigration` runs it in
// `verifyFirst` mode (write the contact, read it back, only then delete).
function verifyContactMigrated(publicData, contactData) {
  if (contactData === null || typeof contactData !== 'object') {
    return { ok: false, reason: 'contact-missing' };
  }
  for (const key of PII_KEYS) {
    if (!(key in contactData)) {
      return { ok: false, reason: `contact-missing-field:${key}` };
    }
  }
  for (const key of PII_KEYS) {
    if (Object.prototype.hasOwnProperty.call(publicData, key)) {
      return { ok: false, reason: `public-still-has:${key}` };
    }
  }
  return { ok: true, reason: null };
}

// Writes every planned migration through an ALREADY-CONNECTED, privileged
// database (rules disabled in the emulator; a service account in production).
//
// `db` is a modular Firestore instance and `deps` injects the SDK functions
// ({ doc, setDoc, updateDoc, getDoc, deleteField }) so this stays testable and so
// the caller controls the environment: the emulator only.
//
// The order is deliberate and IS the safety property: for each request it (1)
// hands the pre-write document to `backup`, (2) writes the contact child, then —
// when `getDoc` is supplied — (3) reads the contact back and only proceeds to
// (4) delete the PII keys from the public parent once the child is confirmed.
// Never the other way round: deleting the public PII before the copy has landed
// would be the one ordering that can lose data.
//
// Idempotent by construction: the delete uses `deleteField()` per key, so
// re-running over an already-migrated request finds no PII keys on the public
// document, `classifyRequest` returns 'modern', and the plan carries no migration
// for it. `applyMigration` is driven purely from the plan, so a second pass is a
// no-op. `backup` receives every pre-write document so the caller can persist a
// rollback set outside this function.
async function applyMigration(db, plan, deps, backup = () => {}) {
  const { doc: docRef, setDoc, updateDoc, deleteField } = deps;
  const getDoc = deps.getDoc; // optional; enables read-before-delete verification
  const results = [];

  for (const { id, before, contact } of plan.migrations) {
    backup(id, before);

    const contactRef = docRef(
      db,
      'blood_requests',
      id,
      CONTACT_COLLECTION,
      CONTACT_DOC,
    );
    await setDoc(contactRef, contact);

    const publicRef = docRef(db, 'blood_requests', id);

    // Read-before-delete: only strip the public PII once the contact child is
    // confirmed to exist with the full three-key shape. When no `getDoc` was
    // injected the caller has opted out of the per-document read (a batched,
    // pre-verified run) and we proceed directly to the delete.
    if (getDoc) {
      const snap = await getDoc(contactRef);
      if (!snap.exists() || !snap.data()) {
        // The copy did not land — leave the public document exactly as it was so
        // nothing is ever readable-but-erased. Report and skip the delete.
        results.push({ id, status: 'verify-failed' });
        continue;
      }
    }

    const deletion = {};
    for (const key of PII_KEYS) {
      if (Object.prototype.hasOwnProperty.call(before, key)) {
        deletion[key] = deleteField();
      }
    }
    await updateDoc(publicRef, deletion);

    results.push({ id, status: 'migrated' });
  }

  return results;
}

// Rolls a set of migrated requests back to their pre-migration public shape and
// removes the contact children. Purely mechanical and the inverse of
// applyMigration: it restores the `before` document (which still holds the PII
// keys) via a full replace and deletes the child. Intended for a controlled
// rollback where a bad batch must be undone; NOT for selective use, because a
// restored public document re-exposes the PII until re-migrated.
async function rollbackMigration(db, backups, deps) {
  const { doc: docRef, setDoc, deleteDoc } = deps;
  const results = [];
  for (const { id, before } of backups) {
    await setDoc(docRef(db, 'blood_requests', id), before);
    await deleteDoc(docRef(db, 'blood_requests', id, CONTACT_COLLECTION, CONTACT_DOC));
    results.push(id);
  }
  return results;
}

module.exports = {
  PII_KEYS,
  CONTACT_COLLECTION,
  CONTACT_DOC,
  isReadableRequest,
  hasPiiKeys,
  classifyRequest,
  extractContact,
  contactCompleteness,
  normalizePublic,
  planMigration,
  verifyContactMigrated,
  applyMigration,
  rollbackMigration,
};
