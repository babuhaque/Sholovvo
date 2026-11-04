// Emulator round-trip for the blood-request contact-PII split migration. Runs the
// plan / write / verify / re-read cycle against the in-memory emulator only —
// never a live project. Invoked under `firebase emulators:exec` alongside the
// rules suite; the pure write-ordering contract lives in migration.test.js.
//
// What this proves that the pure test cannot: after the migration physically
// removes the PII from the public `blood_requests/{id}` document, (a) a signed-in
// stranger reading that public document gets NO patient name / phone / address,
// and (b) the relocated data now sits in `private/contact`, which the deployed
// Stage 9.5 (M3-C1 / M3-C2) rules keep readable ONLY by the request owner (or a
// donor whose immutable claim landed) — not by the stranger. In other words the
// migration is what closes the read leak that tightening the rules alone could
// not close, and the rules hold the closed door.
//
// The WRITE is a privileged operation and runs under
// `withSecurityRulesDisabled`, exactly as a production run would with a service
// account: the migration must be able to create the contact child and delete the
// public keys regardless of the client rules. The VERIFICATION reads then run in
// ordinary authenticated contexts so the real rules are what decide them.
//
// The handle is a context `.firestore()`, which is the same `firebase` class the
// modular `doc/collection/getDocs/getDoc/setDoc/updateDoc/deleteDoc` functions
// accept; `testEnv.adminFirestore` is a different (bundled) class rejected by
// those functions.

'use strict';

const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  collection,
  setDoc,
  updateDoc,
  deleteDoc,
  deleteField,
} = require('firebase/firestore');

const {
  PII_KEYS,
  planMigration,
  applyMigration,
  classifyRequest,
} = require('./migration.js');

// Roles: the patient owns the request; `strangerUid` and `matchedDonorUid` are
// the two non-owner readers the rules must treat differently.
const OWNER = 'uid_patient_owner';
const STRANGER = 'uid_stranger_reader';
const DONOR = 'uid_matched_donor';

const REQUEST = 'req_legacy_1';

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

// A pre-M3 production request: the three PII fields inline on the public doc.
const legacyPublic = (overrides = {}) => ({
  userId: OWNER,
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
  createdAt: new Date(),
  ...overrides,
});

// Seeds the given documents (admin), runs one plan+apply (admin), and returns the
// captured plan so each test can then re-read as an ordinary user and assert the
// rules decide the post-migration visibility.
const migrateSeed = async (seedDocs) => {
  let captured;
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    const db = adminCtx.firestore();
    for (const { id, data } of seedDocs) {
      await setDoc(doc(db, 'blood_requests', id), data);
    }
    const documents = (await getDocs(collection(db, 'blood_requests'))).docs.map((d) => ({
      id: d.id,
      data: d.data(),
    }));
    const plan = planMigration(documents);
    const results = await applyMigration(db, plan, {
      doc,
      setDoc,
      updateDoc,
      getDoc,
      deleteField,
    });
    captured = { plan, results };
  });
  return captured;
};

describe('request-pii split migration against the emulator', () => {
  it('removes the PII from the public document and lands it in private/contact', async () => {
    const { plan, results } = await migrateSeed([
      { id: REQUEST, data: legacyPublic() },
    ]);

    assert.strictEqual(plan.migrations.length, 1);
    assert.deepStrictEqual(results, [{ id: REQUEST, status: 'migrated' }]);

    // The public document, read back through the rules as the OWNER (the app's
    // own request view), no longer carries any of the three keys.
    const ownerDb = testEnv.authenticatedContext(OWNER).firestore();
    const pub = (await getDoc(doc(ownerDb, 'blood_requests', REQUEST))).data();
    for (const key of PII_KEYS) {
      assert.ok(!(key in pub), `${key} must be gone from the public doc`);
    }
    // Everything a donor needs to decide stayed put.
    assert.strictEqual(pub.hospitalName, 'Dhaka Medical College');
    assert.strictEqual(pub.bloodGroup, 'A+');
    assert.strictEqual(pub.bloodBags, 2);

    // The relocated PII is intact in the child.
    const contact = (await getDoc(doc(ownerDb, 'blood_requests', REQUEST, 'private', 'contact'))).data();
    assert.strictEqual(contact.patientName, 'Ayesha Begum');
    assert.strictEqual(contact.phoneNumber, '+8801700000009');
    assert.strictEqual(contact.hospitalAddress, 'House 12, Road 5, Banani');
  });

  it('a signed-in stranger can still read the public doc but sees NO PII and cannot read the contact', async () => {
    await migrateSeed([{ id: REQUEST, data: legacyPublic() }]);

    const strangerDb = testEnv.authenticatedContext(STRANGER).firestore();
    const pubSnap = await getDoc(doc(strangerDb, 'blood_requests', REQUEST));
    assert.ok(pubSnap.exists(), 'the public request is still world-readable by signed-in users');
    const pub = pubSnap.data();
    for (const key of PII_KEYS) {
      assert.ok(!(key in pub), `${key} must not be readable on the public doc`);
    }
    // The leak the rules alone could not close is now physically gone: the
    // stranger literally cannot fetch the phone, because it is no longer on the
    // document they can read, and the child is gated away from them.
    await assert.rejects(
      getDoc(doc(strangerDb, 'blood_requests', REQUEST, 'private', 'contact')),
      (err) => err.code === 'permission-denied',
    );
  });

  it('is idempotent: a second plan+apply over the migrated documents does nothing', async () => {
    await migrateSeed([{ id: REQUEST, data: legacyPublic() }]);

    // Re-plan against the CURRENT physical documents (not re-seeded).
    let second;
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const db = adminCtx.firestore();
      const documents = (await getDocs(collection(db, 'blood_requests'))).docs.map((d) => ({
        id: d.id,
        data: d.data(),
      }));
      second = planMigration(documents);
      const results = await applyMigration(db, second, {
        doc,
        setDoc,
        updateDoc,
        getDoc,
        deleteField,
      });
      second.results = results;
    });

    assert.strictEqual(second.migrations.length, 0, 'nothing left to migrate');
    assert.deepStrictEqual(second.noops, [REQUEST]);
    assert.deepStrictEqual(second.results, []);

    // And the public document still classifies as modern after the second pass.
    const ownerDb = testEnv.authenticatedContext(OWNER).firestore();
    const pub = (await getDoc(doc(ownerDb, 'blood_requests', REQUEST))).data();
    assert.strictEqual(classifyRequest(pub), 'modern');
  });

  it('leaves an already-clean request untouched and creates no contact child', async () => {
    const clean = legacyPublic({ userId: OWNER });
    for (const key of PII_KEYS) {
      delete clean[key];
    }
    const { plan } = await migrateSeed([{ id: 'req_clean', data: clean }]);

    assert.strictEqual(plan.migrations.length, 0);
    assert.deepStrictEqual(plan.noops, ['req_clean']);

    const ownerDb = testEnv.authenticatedContext(OWNER).firestore();
    const child = await getDoc(doc(ownerDb, 'blood_requests', 'req_clean', 'private', 'contact'));
    assert.strictEqual(child.exists(), false, 'no contact child is minted for a clean request');
  });

  it('refuses to touch a document that is not recognisably a request', async () => {
    const { plan } = await migrateSeed([
      { id: 'junk', data: { text: 'not a request at all' } },
    ]);
    assert.deepStrictEqual(plan.unreadable, ['junk']);
    assert.strictEqual(plan.migrations.length, 0);

    // Still there, still untouched — the migration did not guess an owner.
    const anyDb = testEnv.authenticatedContext(STRANGER).firestore();
    const snap = await getDoc(doc(anyDb, 'blood_requests', 'junk'));
    assert.strictEqual(snap.exists(), true);
    assert.strictEqual(snap.data().text, 'not a request at all');
  });

  it('moves a partially-populated legacy request (only a phone) and still clears the public key', async () => {
    const partial = legacyPublic({ userId: OWNER });
    for (const key of PII_KEYS) {
      delete partial[key];
    }
    partial.phoneNumber = '+8801700000009'; // only a phone is present

    const { plan, results } = await migrateSeed([{ id: 'req_partial', data: partial }]);

    assert.strictEqual(plan.migrations.length, 1);
    // Flagged as landing with a blank name, but still migrated off the public doc.
    assert.deepStrictEqual(plan.incomplete, ['req_partial']);
    assert.deepStrictEqual(results, [{ id: 'req_partial', status: 'migrated' }]);

    const ownerDb = testEnv.authenticatedContext(OWNER).firestore();
    const pub = (await getDoc(doc(ownerDb, 'blood_requests', 'req_partial'))).data();
    assert.ok(!('phoneNumber' in pub), 'the stray phone key is gone from the public doc');
    const contact = (await getDoc(doc(ownerDb, 'blood_requests', 'req_partial', 'private', 'contact'))).data();
    assert.strictEqual(contact.phoneNumber, '+8801700000009');
    assert.strictEqual(contact.patientName, '');
  });

  it('rollbackMigration restores the public PII and removes the child', async () => {
    const seed = [{ id: REQUEST, data: legacyPublic() }];
    // Capture the plan's backups, migrate, then roll back — all under admin.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const db = adminCtx.firestore();
      await setDoc(doc(db, 'blood_requests', REQUEST), legacyPublic());
      const documents = (await getDocs(collection(db, 'blood_requests'))).docs.map((d) => ({
        id: d.id,
        data: d.data(),
      }));
      const plan = planMigration(documents);
      await applyMigration(db, plan, { doc, setDoc, updateDoc, getDoc, deleteField });

      // Sanity: it migrated.
      assert.strictEqual(plan.migrations.length, 1);
      // Now roll back using the backups the plan produced.
      const { rollbackMigration } = require('./migration.js');
      await rollbackMigration(db, plan.backups, { doc, setDoc, deleteDoc });
    });

    // After rollback the public document carries the PII again and the child is
    // gone — the exact inverse of a successful migration.
    const ownerDb = testEnv.authenticatedContext(OWNER).firestore();
    const pub = (await getDoc(doc(ownerDb, 'blood_requests', REQUEST))).data();
    assert.strictEqual(pub.patientName, 'Ayesha Begum');
    const child = await getDoc(doc(ownerDb, 'blood_requests', REQUEST, 'private', 'contact'));
    assert.strictEqual(child.exists(), false);
  });
});
