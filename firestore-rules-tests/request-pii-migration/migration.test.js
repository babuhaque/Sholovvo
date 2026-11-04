// Pure tests for the blood-request contact-PII split migration. These need NO
// emulator: they exercise the before/after contract and the write-ordering
// guarantee over plain maps and an injected fake Firestore. Run:
//   node --test firestore-rules-tests/request-pii-migration/migration.test.js
//
// The emulator round-trip (that a migrated public document actually satisfies the
// deployed rules, the contact child lands gated, and a second pass is a no-op
// against real documents) lives in migration_emulator.test.js.

'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const {
  PII_KEYS,
  classifyRequest,
  hasPiiKeys,
  extractContact,
  contactCompleteness,
  normalizePublic,
  planMigration,
  verifyContactMigrated,
  applyMigration,
  rollbackMigration,
} = require('./migration.js');

// A pre-M3 request exactly as it would be found in production: the three PII
// fields inline on the public document, everything else already public-safe.
const legacyRequest = (overrides = {}) => ({
  userId: 'uid_patient',
  patientName: 'Ayesha Begum',
  phoneNumber: '+8801700000009',
  hospitalAddress: 'House 12, Road 5, Banani',
  bloodGroup: 'A+',
  bloodBags: 2,
  hospitalName: 'Dhaka Medical College',
  requiredDateTime: '2026-11-10 10:00 AM',
  status: 'open',
  latitude: 23.8,
  longitude: 90.4,
  createdAt: 1729000000000,
  ...overrides,
});

const migratedRequest = (overrides = {}) => {
  const doc = legacyRequest(overrides);
  for (const key of PII_KEYS) {
    delete doc[key];
  }
  return doc;
};

describe('classifyRequest', () => {
  it('calls a PII-bearing readable request legacy', () => {
    assert.strictEqual(classifyRequest(legacyRequest()), 'legacy');
  });
  it('calls a PII-free request modern', () => {
    assert.strictEqual(classifyRequest(migratedRequest()), 'modern');
  });
  it('reports a legacy doc with only ONE PII key present as legacy', () => {
    const only = migratedRequest();
    only.patientName = 'Just A Name';
    assert.strictEqual(classifyRequest(only), 'legacy');
    assert.ok(hasPiiKeys(only));
  });
  it('treats a present-but-null PII key as still needing migration', () => {
    // Presence is the trigger, not value: a null phone left on the public doc is
    // still a readable key the post-M3 shape forbids.
    const withNullPhone = migratedRequest();
    withNullPhone.phoneNumber = null; // re-introduce the key with a null value
    assert.strictEqual(classifyRequest(withNullPhone), 'legacy');
  });
  it('refuses a document that is not recognisably a request', () => {
    assert.strictEqual(classifyRequest({ text: 'no owner, no group' }), 'unreadable');
    assert.strictEqual(classifyRequest(migratedRequest({ userId: '' })), 'unreadable');
    assert.strictEqual(classifyRequest(migratedRequest({ bloodGroup: 42 })), 'unreadable');
  });
});

describe('extractContact / normalizePublic', () => {
  it('copies the three PII values verbatim into the contact', () => {
    const contact = extractContact(legacyRequest());
    assert.deepStrictEqual(contact, {
      patientName: 'Ayesha Begum',
      phoneNumber: '+8801700000009',
      hospitalAddress: 'House 12, Road 5, Banani',
    });
  });
  it('defaults absent or non-string PII to empty strings', () => {
    const contact = extractContact({ patientName: 7, phoneNumber: undefined });
    assert.deepStrictEqual(contact, { patientName: '', phoneNumber: '', hospitalAddress: '' });
    assert.deepEqual(contactCompleteness(contact), {
      patientName: false,
      phoneNumber: false,
      hospitalAddress: false,
    });
  });
  it('strips exactly the three PII keys and keeps every other field', () => {
    const after = normalizePublic(legacyRequest());
    for (const key of PII_KEYS) {
      assert.ok(!(key in after), `${key} must be gone`);
    }
    assert.strictEqual(after.hospitalName, 'Dhaka Medical College');
    assert.strictEqual(after.bloodBags, 2);
    assert.strictEqual(after.status, 'open');
    assert.strictEqual(after.latitude, 23.8);
    assert.strictEqual(after.createdAt, 1729000000000);
  });
});

describe('planMigration', () => {
  it('splits a mixed batch into migrations, noops and unreadable', () => {
    const plan = planMigration([
      { id: 'a', data: legacyRequest() },
      { id: 'b', data: migratedRequest() },
      { id: 'c', data: { text: 'junk' } },
    ]);
    assert.deepStrictEqual(plan.migrations.map((m) => m.id), ['a']);
    assert.deepStrictEqual(plan.noops, ['b']);
    assert.deepStrictEqual(plan.unreadable, ['c']);
    assert.deepStrictEqual(plan.backups.map((b) => b.id), ['a']);
    // The backup is the untouched pre-write document, still carrying the PII.
    assert.strictEqual(plan.backups[0].before.patientName, 'Ayesha Begum');
  });
  it('flags a migrated request whose contact will land with a blank name/phone', () => {
    const partial = migratedRequest();
    partial.phoneNumber = '+8801700000009';
    const plan = planMigration([{ id: 'd', data: partial }]);
    assert.strictEqual(plan.migrations.length, 1);
    assert.deepStrictEqual(plan.incomplete, ['d']);
  });
  it('carries the projected contact and public shape for each migration', () => {
    const plan = planMigration([{ id: 'a', data: legacyRequest() }]);
    assert.strictEqual(plan.migrations[0].contact.patientName, 'Ayesha Begum');
    assert.ok(!('patientName' in plan.migrations[0].publicAfter));
  });
});

describe('verifyContactMigrated', () => {
  it('is ok only when the contact has all three keys and the public has none', () => {
    const ok = verifyContactMigrated(migratedRequest(), extractContact(legacyRequest()));
    assert.deepStrictEqual(ok, { ok: true, reason: null });
  });
  it('fails when a PII key is still on the public document', () => {
    const res = verifyContactMigrated(legacyRequest(), extractContact(legacyRequest()));
    assert.strictEqual(res.ok, false);
    assert.match(res.reason, /public-still-has:patientName/);
  });
  it('fails when the contact is missing or incomplete', () => {
    assert.strictEqual(verifyContactMigrated(migratedRequest(), null).ok, false);
    assert.strictEqual(verifyContactMigrated(migratedRequest(), { patientName: 'x' }).ok, false);
  });
});

// A minimal fake Firestore that records the ORDER and the target of every write,
// so the "child first, delete second" guarantee is asserted without an emulator.
function fakeFirestore({ contactExists = true } = {}) {
  const calls = [];
  const docRef = (_db, ...path) => ({ path });
  const deleteField = () => ({ __delete: true });
  const deps = {
    doc: docRef,
    deleteField,
    setDoc: async (ref, data) => {
      calls.push({ op: 'set', path: ref.path, data });
    },
    updateDoc: async (ref, data) => {
      calls.push({ op: 'update', path: ref.path, data });
    },
    deleteDoc: async (ref) => {
      calls.push({ op: 'delete', path: ref.path });
    },
    getDoc: async (ref) => {
      calls.push({ op: 'get', path: ref.path });
      return { exists: () => contactExists, data: () => (contactExists ? extractContact(legacyRequest()) : undefined) };
    },
  };
  return { deps, calls };
}

describe('applyMigration — write ordering and verification', () => {
  it('writes the contact child before deleting the public PII keys', async () => {
    const plan = planMigration([{ id: 'a', data: legacyRequest() }]);
    const { deps, calls } = fakeFirestore();
    const backups = [];
    const results = await applyMigration({}, plan, deps, (id, before) =>
      backups.push({ id, before }),
    );

    assert.deepStrictEqual(results, [{ id: 'a', status: 'migrated' }]);
    assert.deepStrictEqual(backups.map((b) => b.id), ['a']);

    const ops = calls.map((c) => c.op);
    // set (contact) ... get (verify) ... update (public delete) — in that order.
    assert.deepStrictEqual(ops, ['set', 'get', 'update']);
    assert.deepStrictEqual(calls[0].path, ['blood_requests', 'a', 'private', 'contact']);
    assert.deepStrictEqual(calls[2].path, ['blood_requests', 'a']);
    // The delete uses deleteField() for exactly the PII keys the document had.
    assert.deepStrictEqual(Object.keys(calls[2].data).sort(), [...PII_KEYS].sort());
    assert.ok(calls[2].data.patientName.__delete);
  });
  it('does NOT delete the public PII when the contact read-back is missing', async () => {
    const plan = planMigration([{ id: 'a', data: legacyRequest() }]);
    const { deps, calls } = fakeFirestore({ contactExists: false });
    const results = await applyMigration({}, plan, deps);

    assert.deepStrictEqual(results, [{ id: 'a', status: 'verify-failed' }]);
    // No 'update' ever reached the public document — nothing was erased.
    assert.ok(!calls.some((c) => c.op === 'update'), 'public delete must not run');
  });
  it('is a no-op over an already-migrated plan', async () => {
    const plan = planMigration([{ id: 'a', data: migratedRequest() }]);
    const { deps, calls } = fakeFirestore();
    const results = await applyMigration({}, plan, deps);
    assert.deepStrictEqual(results, []);
    assert.deepStrictEqual(calls, []);
  });
  it('deletes only the keys the document actually carried', async () => {
    const partial = migratedRequest();
    partial.phoneNumber = '+8801700000009'; // only phone present
    const plan = planMigration([{ id: 'a', data: partial }]);
    const { deps, calls } = fakeFirestore();
    await applyMigration({}, plan, deps);
    const update = calls.find((c) => c.op === 'update');
    assert.deepStrictEqual(Object.keys(update.data), ['phoneNumber']);
  });
});

describe('rollbackMigration', () => {
  it('restores the original public shape and deletes the child', async () => {
    const plan = planMigration([{ id: 'a', data: legacyRequest() }]);
    const { deps, calls } = fakeFirestore();
    const ids = await rollbackMigration({}, plan.backups, deps);
    assert.deepStrictEqual(ids, ['a']);
    // A full set (restore) then a delete (child).
    assert.deepStrictEqual(calls.map((c) => c.op), ['set', 'delete']);
    assert.strictEqual(calls[0].data.patientName, 'Ayesha Begum');
    assert.deepStrictEqual(calls[1].path, ['blood_requests', 'a', 'private', 'contact']);
  });
});
