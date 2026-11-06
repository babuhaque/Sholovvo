const { describe, it, afterEach, before, after } = require('node:test');
const assert = require('node:assert');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('node:fs');
const path = require('node:path');
const {
  serverTimestamp,
  GeoPoint,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  runTransaction,
  collection,
  query,
  where,
  limit,
  getDocs,
} = require('firebase/firestore');

let testEnv;

before(async () => {
  const rulesPath = path.resolve(__dirname, '../firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  testEnv = await initializeTestEnvironment({
    projectId: 'demo-solovvo-tests',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: rules,
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// Without an explicit teardown the Firestore gRPC channels stay open after the
// last test and `node --test` never exits, which hangs `emulators:exec`.
after(async () => {
  await testEnv.cleanup();
});

describe('Phase 2.1 Donation History Security Rules Comprehensive Tests', () => {
  const ownerId = 'user_owner_123';
  const otherId = 'user_other_456';

  const validDonationData = (overrides = {}) => ({
    donorUid: ownerId,
    bloodGroup: 'A+',
    hospitalName: 'Dhaka Medical College',
    status: 'pending',
    createdAt: serverTimestamp(),
    ...overrides,
  });

  it('1. Unauthenticated user cannot read or write donation history', async () => {
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const recordRef = unauthDb.collection('donation_history').doc('rec_unauth');

    await assertFails(recordRef.get());
    await assertFails(recordRef.set(validDonationData()));
  });

  it('2. Owner can read their own donation history', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx.firestore().collection('donation_history').doc('rec_1').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    await assertSucceeds(ownerDb.collection('donation_history').doc('rec_1').get());
  });

  it('3. User cannot read another user\'s donation history', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx.firestore().collection('donation_history').doc('rec_1').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const otherDb = testEnv.authenticatedContext(otherId).firestore();
    await assertFails(otherDb.collection('donation_history').doc('rec_1').get());
  });

  it('4. Owner can create a valid pending donation record with server timestamp', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_valid');

    await assertSucceeds(recordRef.set(validDonationData()));
  });

  it('5. User cannot create a record for another UID', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_spoofed');

    await assertFails(recordRef.set(validDonationData({ donorUid: otherId })));
  });

  it('6. Client cannot create a confirmed record', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_confirmed');

    await assertFails(recordRef.set(validDonationData({ status: 'confirmed' })));
  });

  it('7. Creation fails with invalid blood group', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_bad_blood');

    await assertFails(recordRef.set(validDonationData({ bloodGroup: 'Z+' })));
  });

  it('8. Creation fails with empty hospital name', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_no_hospital');

    await assertFails(recordRef.set(validDonationData({ hospitalName: '' })));
  });

  it('9. Creation fails with missing required field (hospitalName)', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_missing');
    const data = validDonationData();
    delete data.hospitalName;

    await assertFails(recordRef.set(data));
  });

  it('10. Creation fails with invalid createdAt timestamp (client local Date)', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_bad_time');

    await assertFails(recordRef.set(validDonationData({ createdAt: new Date(0) })));
  });

  it('11. Client updates are completely denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx.firestore().collection('donation_history').doc('rec_update').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    await assertFails(ownerDb.collection('donation_history').doc('rec_update').update({
      hospitalName: 'Updated Hospital',
    }));
  });

  it('12. Owner can delete own pending record', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx.firestore().collection('donation_history').doc('rec_del').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    await assertSucceeds(ownerDb.collection('donation_history').doc('rec_del').delete());
  });

  it('13. Another user attempts to delete owner\'s pending record', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx.firestore().collection('donation_history').doc('rec_del_other').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const otherDb = testEnv.authenticatedContext(otherId).firestore();
    await assertFails(otherDb.collection('donation_history').doc('rec_del_other').delete());
  });

  it('14. Cross-user collection query is restricted by rules (only returns owner documents)', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const col = adminCtx.firestore().collection('donation_history');
      await col.doc('rec_owner').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
      await col.doc('rec_other').set({
        donorUid: otherId,
        bloodGroup: 'B+',
        hospitalName: 'Square Hospital',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const collection = ownerDb.collection('donation_history');

    // An unconstrained collection list can never be authorised: for a list the
    // rule engine binds `resource` to a placeholder document, so `donorUid` is
    // undefined and the read is denied. The query itself must be narrowed.
    await assertFails(collection.get());

    // Narrowed to the caller's own uid the same query is authorised and only
    // ever yields the caller's document.
    const ownSnapshot = await collection.where('donorUid', '==', ownerId).get();
    assert.strictEqual(ownSnapshot.size, 1);
    assert.strictEqual(ownSnapshot.docs[0].data().donorUid, ownerId);

    // Narrowed to another user's uid it is denied rather than returning data.
    await assertFails(collection.where('donorUid', '==', otherId).get());
  });
});

// ---------------------------------------------------------------------------
// Phase 1 - Response claims, donor response notifications and request claiming.
// These suites cover the collections touched by the Phase 1 fixes:
//   blood_requests, request_responses, response_claims, notifications.
// ---------------------------------------------------------------------------

const IDS = {
  recipient: 'recipient_owner_1',
  donor: 'donor_one_1',
  otherDonor: 'donor_two_2',
  request: 'req_alpha_1',
  response: 'resp_alpha_1',
};

// Mirrors RequestResponseService.getClaimId so the tests exercise the real id shape.
const claimDocId = (requestId, donorId) =>
  `req_${requestId.length}_${requestId}_donor_${donorId.length}_${donorId}`;

const donorResponsePayload = (overrides = {}) => ({
  recipientUid: IDS.recipient,
  requestId: IDS.request,
  responseId: IDS.response,
  type: 'donor_response',
  title: 'Donor Response (A+)',
  body: 'Donor One has accepted your request for Patient.',
  createdAt: serverTimestamp(),
  ...overrides,
});

const newRequestPayload = (overrides = {}) => ({
  recipientUid: IDS.donor,
  requestId: IDS.request,
  responseId: null,
  type: 'new_request',
  title: 'New A+ Blood Request',
  body: 'Patient needs 1 bag(s) of blood.',
  createdAt: serverTimestamp(),
  ...overrides,
});

const seedBase = async ({ requestStatus = 'open', withResponse = true } = {}) => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    const db = adminCtx.firestore();
    await db.collection('users').doc(IDS.recipient).set({
      uid: IDS.recipient,
      fullName: 'Recipient Owner',
      role: 'recipient',
      bloodGroup: 'O+',
      isAvailable: false,
    });
    await db.collection('users').doc(IDS.donor).set({
      uid: IDS.donor,
      fullName: 'Donor One',
      role: 'donor',
      bloodGroup: 'A+',
      isAvailable: true,
    });
    await db.collection('users').doc(IDS.otherDonor).set({
      uid: IDS.otherDonor,
      fullName: 'Donor Two',
      role: 'donor',
      bloodGroup: 'B+',
      isAvailable: true,
    });
    await db.collection('blood_requests').doc(IDS.request).set({
      userId: IDS.recipient,
      patientName: 'Patient',
      phoneNumber: '+8801700000000',
      bloodGroup: 'A+',
      bloodBags: 1,
      hospitalName: 'Dhaka Medical College',
      hospitalAddress: 'Dhaka',
      requiredDateTime: '2026-11-10 10:00 AM',
      requestType: 'Normal',
      notes: '',
      status: requestStatus,
      assignedDonorId: null,
      latitude: 23.8,
      longitude: 90.4,
      createdAt: new Date(),
    });

    if (withResponse) {
      await db.collection('request_responses').doc(IDS.response).set({
        requestId: IDS.request,
        donorId: IDS.donor,
        donorName: 'Donor One',
        donorPhone: '+8801700000001',
        bloodGroup: 'A+',
        status: 'accepted',
        createdAt: new Date(),
      });
    }
  });
};

describe('Phase 1.1 response_claims security rules', () => {
  it('1. Booking transaction can read a claim that does not exist yet', async () => {
    await seedBase({ withResponse: false });
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    const claimRef = doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor));

    assert.strictEqual((await getDoc(claimRef)).exists(), false);
  });

  it('2. Donor can atomically create the response and claim, and claim the request', async () => {
    await seedBase({ withResponse: false });
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    const requestRef = doc(db, 'blood_requests', IDS.request);
    const responseRef = doc(db, 'request_responses', IDS.response);
    const claimRef = doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor));

    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const requestSnap = await tx.get(requestRef);
        assert.strictEqual(requestSnap.data().status, 'open');
        const claimSnap = await tx.get(claimRef);
        assert.strictEqual(claimSnap.exists(), false);

        tx.set(responseRef, {
          requestId: IDS.request,
          donorId: IDS.donor,
          donorName: 'Donor One',
          donorPhone: '+8801700000001',
          bloodGroup: 'A+',
          status: 'accepted',
          createdAt: serverTimestamp(),
        });
        tx.set(claimRef, {
          requestId: IDS.request,
          donorId: IDS.donor,
          responseId: IDS.response,
        });
        tx.update(requestRef, {
          status: 'accepted',
          assignedDonorId: IDS.donor,
          acceptedAt: serverTimestamp(),
        });
      }),
    );

    const stored = await getDoc(
      testEnv.authenticatedContext(IDS.donor).firestore().doc(`response_claims/${claimDocId(IDS.request, IDS.donor)}`),
    );
    assert.strictEqual(stored.data().responseId, IDS.response);
  });

  it('3. A donor cannot create a claim for someone else', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.otherDonor).firestore();

    await assertFails(
      setDoc(doc(db, 'response_claims', claimDocId(IDS.request, IDS.otherDonor)), {
        requestId: IDS.request,
        donorId: IDS.donor,
        responseId: IDS.response,
      }),
    );
  });

  it('4. A claim cannot reference a response belonging to a different request', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor)), {
        requestId: 'req_some_other',
        donorId: IDS.donor,
        responseId: IDS.response,
      }),
    );
  });

  it('5. A claim cannot point at a response that does not exist', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor)), {
        requestId: IDS.request,
        donorId: IDS.donor,
        responseId: 'resp_missing',
      }),
    );
  });

  it('6. A claim cannot carry extra fields', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor)), {
        requestId: IDS.request,
        donorId: IDS.donor,
        responseId: IDS.response,
        isWinner: true,
      }),
    );
  });

  it('7. An existing claim is readable only by the donor who owns it', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('response_claims')
        .doc(claimDocId(IDS.request, IDS.donor))
        .set({ requestId: IDS.request, donorId: IDS.donor, responseId: IDS.response });
    });

    const donorDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertSucceeds(getDoc(doc(donorDb, 'response_claims', claimDocId(IDS.request, IDS.donor))));

    const otherDb = testEnv.authenticatedContext(IDS.otherDonor).firestore();
    await assertFails(getDoc(doc(otherDb, 'response_claims', claimDocId(IDS.request, IDS.donor))));
  });

  it('8. A winning claim cannot be edited or released', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('response_claims')
        .doc(claimDocId(IDS.request, IDS.donor))
        .set({ requestId: IDS.request, donorId: IDS.donor, responseId: IDS.response });
    });

    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    const claimRef = doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor));

    await assertFails(updateDoc(claimRef, { responseId: 'resp_other' }));
    await assertFails(deleteDoc(claimRef));
  });

  it('9. Unauthenticated users cannot read or write claims', async () => {
    await seedBase();
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(unauthDb, 'response_claims', claimDocId(IDS.request, IDS.donor))));
    await assertFails(
      setDoc(doc(unauthDb, 'response_claims', claimDocId(IDS.request, IDS.donor)), {
        requestId: IDS.request,
        donorId: IDS.donor,
        responseId: IDS.response,
      }),
    );
  });
});

describe('Phase 1.2 notifications security rules', () => {
  it('1. Donor can raise a donor_response notification resolved through responseId', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertSucceeds(
      setDoc(doc(db, 'notifications', `notif_resp_${IDS.response}`), donorResponsePayload()),
    );
  });

  it('2. donor_response is rejected when responseId points at a blood request instead', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', 'notif_resp_bad'),
        donorResponsePayload({ responseId: IDS.request }),
      ),
    );
  });

  it('3. A donor cannot raise a donor_response notification for a response they do not own', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.otherDonor).firestore();

    await assertFails(
      setDoc(doc(db, 'notifications', `notif_resp_${IDS.response}`), donorResponsePayload()),
    );
  });

  it('4. A donor cannot address a donor_response notification to someone other than the request owner', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', 'notif_resp_wrong_recipient'),
        donorResponsePayload({ recipientUid: IDS.otherDonor }),
      ),
    );
  });

  it('5. Request owner can raise a new_request notification for a matching donor', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();

    await assertSucceeds(
      setDoc(
        doc(db, 'notifications', `notif_req_new_request_${IDS.request}_${IDS.donor}`),
        newRequestPayload(),
      ),
    );
  });

  it('6. A new_request notification is rejected when the request does not exist', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', 'notif_req_missing'),
        newRequestPayload({ requestId: 'req_does_not_exist' }),
      ),
    );
  });

  it('7. A notification cannot carry unexpected fields', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', `notif_resp_${IDS.response}`),
        donorResponsePayload({ isAdmin: true }),
      ),
    );
  });

  it('8. A notification must use a server timestamp', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', `notif_resp_${IDS.response}`),
        donorResponsePayload({ createdAt: new Date(0) }),
      ),
    );
  });

  it('9. Sender can idempotently re-raise a notification without un-reading it', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('notifications')
        .doc(`notif_resp_${IDS.response}`)
        .set({ ...donorResponsePayload(), createdAt: new Date(), isRead: true });
    });

    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    const notifRef = doc(db, 'notifications', `notif_resp_${IDS.response}`);

    await assertSucceeds(setDoc(notifRef, donorResponsePayload(), { merge: true }));

    const recipientDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    const stored = await getDoc(doc(recipientDb, 'notifications', `notif_resp_${IDS.response}`));
    assert.strictEqual(stored.data().isRead, true);
  });

  it('10. Sender cannot flip the read state of an existing notification', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('notifications')
        .doc(`notif_resp_${IDS.response}`)
        .set({ ...donorResponsePayload(), createdAt: new Date(), isRead: true });
    });

    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', `notif_resp_${IDS.response}`),
        { isRead: false },
        { merge: true },
      ),
    );
  });

  it('11. Sender cannot redirect an existing notification to another recipient', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('notifications')
        .doc(`notif_resp_${IDS.response}`)
        .set({ ...donorResponsePayload(), createdAt: new Date(), isRead: false });
    });

    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', `notif_resp_${IDS.response}`),
        { recipientUid: IDS.otherDonor },
        { merge: true },
      ),
    );
  });

  it('12. Only the recipient can read their notification', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('notifications')
        .doc(`notif_resp_${IDS.response}`)
        .set({ ...donorResponsePayload(), createdAt: new Date(), isRead: false });
    });

    const recipientDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(getDoc(doc(recipientDb, 'notifications', `notif_resp_${IDS.response}`)));

    const otherDb = testEnv.authenticatedContext(IDS.otherDonor).firestore();
    await assertFails(getDoc(doc(otherDb, 'notifications', `notif_resp_${IDS.response}`)));
  });

  it('13. Recipient can mark their notification as read', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('notifications')
        .doc(`notif_resp_${IDS.response}`)
        .set({ ...donorResponsePayload(), createdAt: new Date(), isRead: false });
    });

    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'notifications', `notif_resp_${IDS.response}`), { isRead: true }),
    );
  });

  it('14. Unauthenticated users cannot read or write notifications', async () => {
    await seedBase();
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(unauthDb, 'notifications', `notif_resp_${IDS.response}`)));
    await assertFails(
      setDoc(doc(unauthDb, 'notifications', `notif_resp_${IDS.response}`), donorResponsePayload()),
    );
  });
});

describe('Phase 1.3 blood_requests claiming rules', () => {
  const claimUpdate = () => ({
    status: 'accepted',
    assignedDonorId: IDS.donor,
    acceptedAt: serverTimestamp(),
  });

  it('1. A matching, available donor can claim an open request', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertSucceeds(
      updateDoc(doc(db, 'blood_requests', IDS.request), claimUpdate()),
    );
  });

  it('2. A donor with a different blood group cannot claim the request', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.otherDonor).firestore();

    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), {
        status: 'accepted',
        assignedDonorId: IDS.otherDonor,
        acceptedAt: serverTimestamp(),
      }),
    );
  });

  it('3. A donor cannot write fields outside the claim contract', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), {
        ...claimUpdate(),
        patientName: 'Hijacked',
      }),
    );
  });

  it('4. A donor cannot claim a request that is no longer open', async () => {
    await seedBase({ requestStatus: 'accepted' });
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), claimUpdate()),
    );
  });

  it('5. The request owner can cancel their own request', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();

    await assertSucceeds(
      updateDoc(doc(db, 'blood_requests', IDS.request), { status: 'cancelled' }),
    );
  });

  it('6. An unrelated donor cannot modify the request', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.otherDonor).firestore();

    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), { status: 'cancelled' }),
    );
  });
});

// ---------------------------------------------------------------------------
// P0 regression suite — the four security findings, after remediation.
//
// These started life as behaviour-discovery tests: fourteen assertions named
// `currently permits … (P0 finding)` that documented what the unmodified
// firestore.rules allowed. The rules were then hardened, so each of those
// fourteen now asserts the closed behaviour instead of the open one, and the
// contract it was pointing at is spelled out by the tests around it. The four
// describes below keep the original numbering; a test that replaced a discovery
// assertion says so in its name.
//
// Nothing above this line was touched: the 43 original tests still run
// unchanged, which is why `writeBatch` is required locally rather than added to
// the import block at the top of the file.
// ---------------------------------------------------------------------------

const { writeBatch } = require('firebase/firestore');

const P0_HOSPITAL = 'P0 Verification Hospital';

// Fresh uids and document ids, isolated from the `IDS` fixtures above.
const P0 = {
  attacker: 'P0_attacker_1',
  victim: 'P0_victim_2',
  bystander: 'P0_bystander_3',
  owner: 'P0_owner_4',
  donor: 'P0_donor_5',
  request: 'P0_req_seeded',
  forgedRequest: 'P0_req_forged',
  forgedHistory: 'P0_history_forged',
  batchRequest: 'P0_req_batch',
  batchHistory: 'P0_history_batch',
  ownerRequest: 'P0_req_owner',
  secondRequest: 'P0_req_second',
  transferRequest: 'P0_req_transfer',
  notification: 'P0_notif_1',
  reassignedNotification: 'P0_notif_reassigned',
  newRequestNotification: 'P0_notif_new_request',
  badTimeNotification: 'P0_notif_bad_time',
  cancelledNotification: 'P0_notif_cancelled',
};

// A payload the create rule accepts: open, unassigned, own uid, server time.
// Overrides exist so a test can violate exactly one clause at a time.
//
// Stage 9.5 (M3 / M3-C1): the payload no longer carries `patientName`,
// `phoneNumber` or `hospitalAddress` — those fields moved to the private/contact
// subcollection and the public create rule now refuses them via `hasOnly`. The
// fixture is the post-M3 public shape; a client that wanted to also raise the
// contact record would setDoc it separately at
// `blood_requests/{id}/private/contact`.
const p0OpenRequestData = (overrides = {}) => ({
  userId: P0.attacker,
  bloodGroup: 'A+',
  bloodBags: 1,
  hospitalName: P0_HOSPITAL,
  requiredDateTime: '2026-11-10 10:00 AM',
  requestType: 'Normal',
  notes: '',
  latitude: 23.8,
  longitude: 90.4,
  status: 'open',
  createdAt: serverTimestamp(),
  ...overrides,
});

// A stored request at an arbitrary point in its life. Only ever written with
// the rules disabled: these tests are about what a client may do next, not
// about how the document got into that state. Stage 9.5 (M3 / M3-C1) drops the
// contact PII fields here too — the downstream tests key on `status` and
// `assignedDonorId`, never on `patientName`/`phoneNumber`/`hospitalAddress`, so
// the shape stays minimal and honest about what the rules now expect on a live
// document.
const p0RequestDoc = ({
  userId = P0.owner,
  status = 'open',
  assignedDonorId = null,
  bloodGroup = 'A+',
  hospitalName = P0_HOSPITAL,
} = {}) => ({
  userId,
  bloodGroup,
  bloodBags: 1,
  hospitalName,
  requiredDateTime: '2026-11-10 10:00 AM',
  requestType: 'Normal',
  notes: '',
  latitude: 23.8,
  longitude: 90.4,
  status,
  assignedDonorId,
  createdAt: new Date(),
});

// The confirmed branch requires the eight keys, a timestamp donationDate, and a
// request that is the caller's, assigned to exactly this donor, completed or
// already fulfilled, with the same blood group and hospital.
const p0ConfirmedHistoryData = (overrides = {}) => ({
  donorUid: P0.donor,
  bloodGroup: 'A+',
  hospitalName: P0_HOSPITAL,
  status: 'confirmed',
  createdAt: serverTimestamp(),
  donationDate: new Date(),
  requestId: P0.forgedRequest,
  confirmedBy: P0.owner,
  ...overrides,
});

// notifications.create pins exactly these seven keys, and never a self-address.
const p0NotificationData = (overrides = {}) => ({
  recipientUid: P0.victim,
  requestId: P0.request,
  responseId: null,
  type: 'new_request',
  title: 'P0 notification title',
  body: 'P0 notification body',
  createdAt: serverTimestamp(),
  ...overrides,
});

const p0SeedRequest = async (id, data) => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await adminCtx.firestore().collection('blood_requests').doc(id).set(data);
  });
};

// The claimant branch reads users/$(uid) before it lets anyone claim anything.
const p0SeedDonor = async (uid, { role = 'donor', bloodGroup = 'A+', isAvailable = true } = {}) => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await adminCtx
      .firestore()
      .collection('users')
      .doc(uid)
      .set({ uid, fullName: 'P0 Donor', role, bloodGroup, isAvailable });
  });
};

const p0SeedDocument = async (path, data) => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await adminCtx.firestore().doc(path).set(data);
  });
};

describe('P0 finding 1 - fabricated donation history', () => {
  it('1. blood_requests.create refuses a completed status and a pre-filled donor (finding closed)', async () => {
    const db = testEnv.authenticatedContext(P0.attacker).firestore();

    // The old rule accepted any payload whose userId matched the caller. A
    // completed status is no longer a creation state, and the assignment cannot
    // be pre-filled, so the two claims this finding needed are both refused.
    await assertFails(
      setDoc(
        doc(db, 'blood_requests', P0.forgedRequest),
        p0OpenRequestData({ status: 'donation_completed' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(db, 'blood_requests', P0.forgedRequest),
        p0OpenRequestData({ assignedDonorId: P0.victim }),
      ),
    );

    // The same payload without either claim is still accepted, so the two
    // refusals above are not the fingerprint of a blanket denial.
    await assertSucceeds(
      setDoc(doc(db, 'blood_requests', P0.forgedRequest), p0OpenRequestData()),
    );
  });

  it('2. an open request can no longer be turned into a confirmed record for a stranger (finding closed)', async () => {
    const db = testEnv.authenticatedContext(P0.attacker).firestore();

    // Commit 1: the request really is the attacker's own document now.
    await assertSucceeds(
      setDoc(doc(db, 'blood_requests', P0.forgedRequest), p0OpenRequestData()),
    );

    // Commit 2: the same confirmed payload the finding used. The request exists
    // and is owned by the caller, but it is open and assigned to nobody, so the
    // confirmed branch refuses it: status, assignment and blood group must all
    // line up before a record can name this donor.
    await assertFails(
      setDoc(
        doc(db, 'donation_history', P0.forgedHistory),
        p0ConfirmedHistoryData({
          donorUid: P0.victim,
          requestId: P0.forgedRequest,
          confirmedBy: P0.attacker,
        }),
      ),
    );
  });

  it('3. the confirmation can be written in the same batch as the fulfilment', async () => {
    await p0SeedRequest(
      P0.batchRequest,
      p0RequestDoc({ status: 'donation_completed', assignedDonorId: P0.donor }),
    );

    const db = testEnv.authenticatedContext(P0.owner).firestore();
    const batch = writeBatch(db);

    batch.set(
      doc(db, 'donation_history', P0.batchHistory),
      p0ConfirmedHistoryData({ requestId: P0.batchRequest }),
    );
    batch.update(doc(db, 'blood_requests', P0.batchRequest), {
      status: 'fulfilled',
    });

    // Both writes are judged against the pre-commit state, in which the request
    // is already donation_completed and assigned to this donor. That is exactly
    // why the confirmed branch accepts 'fulfilled' as well: the client can order
    // the two writes either way and the batch still commits.
    await assertSucceeds(batch.commit());

    const request = await assertSucceeds(
      getDoc(doc(db, 'blood_requests', P0.batchRequest)),
    );
    assert.strictEqual(request.data().status, 'fulfilled');

    // The record is the donor's, so it is read back in the donor's context: the
    // owner who wrote it has no read access to someone else's history.
    const donorDb = testEnv.authenticatedContext(P0.donor).firestore();
    const record = await assertSucceeds(
      getDoc(doc(donorDb, 'donation_history', P0.batchHistory)),
    );
    assert.strictEqual(record.data().status, 'confirmed');
    assert.strictEqual(record.data().donorUid, P0.donor);
  });

  it('4. denies a confirmed record when the referenced request does not exist', async () => {
    const db = testEnv.authenticatedContext(P0.attacker).firestore();

    // Everything else about the payload satisfies the confirmed branch, so the
    // only reason to refuse is `exists(blood_requests/...)`.
    await assertFails(
      setDoc(
        doc(db, 'donation_history', P0.forgedHistory),
        p0ConfirmedHistoryData({
          requestId: 'P0_req_missing',
          confirmedBy: P0.attacker,
        }),
      ),
    );
  });

  it('5. the named donor can read a legitimate confirmed record, and a bystander cannot', async () => {
    await p0SeedRequest(
      P0.request,
      p0RequestDoc({ status: 'fulfilled', assignedDonorId: P0.donor }),
    );
    await p0SeedDocument(`donation_history/${P0.forgedHistory}`, {
      ...p0ConfirmedHistoryData({ requestId: P0.request }),
      createdAt: new Date(),
    });

    const donorDb = testEnv.authenticatedContext(P0.donor).firestore();
    await assertSucceeds(
      getDoc(doc(donorDb, 'donation_history', P0.forgedHistory)),
    );

    const bystanderDb = testEnv.authenticatedContext(P0.bystander).firestore();
    await assertFails(
      getDoc(doc(bystanderDb, 'donation_history', P0.forgedHistory)),
    );
  });

  it('6. the donor still has no route to correct a confirmed record (known limitation)', async () => {
    await p0SeedDocument(`donation_history/${P0.forgedHistory}`, {
      ...p0ConfirmedHistoryData({ requestId: P0.request }),
      createdAt: new Date(),
    });

    const donorDb = testEnv.authenticatedContext(P0.donor).firestore();
    const recordRef = doc(donorDb, 'donation_history', P0.forgedHistory);

    // `allow update: if false`, and delete requires `status == 'pending'`. A
    // donor who believes a confirmed record is wrong has no correction path; the
    // compensating control is that only a request owner can create one, and only
    // after that donor claimed and completed the request.
    await assertFails(updateDoc(recordRef, { hospitalName: 'Corrected' }));
    await assertFails(deleteDoc(recordRef));
  });
});

describe('P0 finding 2 - notification recipient reassignment', () => {
  it('1. a notification addressed to the sender is refused, so the recipient branch has nothing to key on (finding closed)', async () => {
    // The request is the attacker's own and open, so every other clause of the
    // new_request branch is satisfied: the self-address is the only violation.
    await p0SeedRequest(P0.request, p0RequestDoc({ userId: P0.attacker }));

    const db = testEnv.authenticatedContext(P0.attacker).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', P0.notification),
        p0NotificationData({ recipientUid: P0.attacker }),
      ),
    );
  });

  it('2. the recipient can no longer hand their notification to another user or rewrite it (finding closed)', async () => {
    await p0SeedRequest(P0.request, p0RequestDoc({ userId: P0.owner }));
    await p0SeedDocument(`notifications/${P0.reassignedNotification}`, {
      ...p0NotificationData({ recipientUid: P0.attacker }),
      createdAt: new Date(),
    });

    const db = testEnv.authenticatedContext(P0.attacker).firestore();

    // The recipient branch now allows `isRead` and nothing else, so the whole
    // reassignment in one write is refused, and it is refused again field by
    // field: a single forbidden key is enough.
    await assertFails(
      updateDoc(doc(db, 'notifications', P0.reassignedNotification), {
        recipientUid: P0.victim,
        type: 'donation_confirmed',
        title: 'Your donation was confirmed',
        body: 'Written by the previous recipient, never validated for this one.',
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'notifications', P0.reassignedNotification), {
        recipientUid: P0.victim,
      }),
    );

    // And the document is unchanged: still the attacker's, still a new_request.
    const stored = await assertSucceeds(
      getDoc(doc(db, 'notifications', P0.reassignedNotification)),
    );
    assert.strictEqual(stored.data().recipientUid, P0.attacker);
    assert.strictEqual(stored.data().type, 'new_request');
  });

  it('3. the recipient may set the read flag and nothing else', async () => {
    await p0SeedRequest(P0.request, p0RequestDoc({ userId: P0.owner }));
    await p0SeedDocument(`notifications/${P0.reassignedNotification}`, {
      ...p0NotificationData({ recipientUid: P0.victim }),
      createdAt: new Date(),
      isRead: false,
    });

    const victimDb = testEnv.authenticatedContext(P0.victim).firestore();
    const notifRef = doc(victimDb, 'notifications', P0.reassignedNotification);

    await assertSucceeds(updateDoc(notifRef, { isRead: true }));

    // Marking read and editing the text in the same write is refused, which is
    // what stops the recipient from rewriting history along the way.
    await assertFails(updateDoc(notifRef, { isRead: true, title: 'Rewritten' }));

    const bystanderDb = testEnv.authenticatedContext(P0.bystander).firestore();
    await assertFails(
      getDoc(doc(bystanderDb, 'notifications', P0.reassignedNotification)),
    );
  });
});

describe('P0 finding 3 - unauthorized new_request notification', () => {
  it('1. only the request owner may raise a new_request notification (finding closed)', async () => {
    await p0SeedRequest(P0.request, p0RequestDoc({ userId: P0.owner }));

    const attackerDb = testEnv.authenticatedContext(P0.attacker).firestore();
    await assertFails(
      setDoc(
        doc(attackerDb, 'notifications', P0.newRequestNotification),
        p0NotificationData({ recipientUid: P0.victim }),
      ),
    );

    // The owner of that same request, raising the same notification for the
    // same recipient, is still allowed.
    const ownerDb = testEnv.authenticatedContext(P0.owner).firestore();
    await assertSucceeds(
      setDoc(
        doc(ownerDb, 'notifications', P0.newRequestNotification),
        p0NotificationData({ recipientUid: P0.victim }),
      ),
    );
  });

  it('2. a new_request notification is still refused without a server timestamp', async () => {
    await p0SeedRequest(P0.request, p0RequestDoc({ userId: P0.owner }));

    const db = testEnv.authenticatedContext(P0.owner).firestore();

    // `createdAt == request.time` is checked before any type branch, so this is
    // refused even though the caller is the owner and the request exists.
    await assertFails(
      setDoc(
        doc(db, 'notifications', P0.badTimeNotification),
        p0NotificationData({ recipientUid: P0.victim, createdAt: new Date(0) }),
      ),
    );
  });

  it('3. a new_request notification is refused once the request is no longer open', async () => {
    await p0SeedRequest(
      P0.request,
      p0RequestDoc({ status: 'accepted', assignedDonorId: P0.donor }),
    );

    const db = testEnv.authenticatedContext(P0.owner).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', P0.newRequestNotification),
        p0NotificationData({ recipientUid: P0.victim }),
      ),
    );
  });

  it('4. the owner may tell the assigned donor that the request was cancelled, in the same batch', async () => {
    await p0SeedRequest(
      P0.request,
      p0RequestDoc({ status: 'accepted', assignedDonorId: P0.donor }),
    );

    const db = testEnv.authenticatedContext(P0.owner).firestore();
    const batch = writeBatch(db);

    batch.update(doc(db, 'blood_requests', P0.request), { status: 'cancelled' });
    batch.set(
      doc(db, 'notifications', P0.cancelledNotification),
      p0NotificationData({
        recipientUid: P0.donor,
        type: 'request_cancelled',
        title: 'Request cancelled',
        body: 'The patient cancelled this request.',
      }),
    );

    // The cancel and its notification are one atomic write. The notification is
    // judged against the pre-commit state, in which the request is still
    // 'accepted', so the batch commits and the donor cannot be left uninformed
    // by a failure between two separate commits.
    await assertSucceeds(batch.commit());

    const donorDb = testEnv.authenticatedContext(P0.donor).firestore();
    const stored = await assertSucceeds(
      getDoc(doc(donorDb, 'notifications', P0.cancelledNotification)),
    );
    assert.strictEqual(stored.data().type, 'request_cancelled');

    // And the same notification is refused afterwards, from a stranger, so the
    // new type is not a general purpose megaphone.
    const attackerDb = testEnv.authenticatedContext(P0.attacker).firestore();
    await assertFails(
      setDoc(
        doc(attackerDb, 'notifications', P0.badTimeNotification),
        p0NotificationData({
          recipientUid: P0.donor,
          type: 'request_cancelled',
        }),
      ),
    );
  });

  it('5. request_cancelled is refused for a recipient who was never assigned', async () => {
    await p0SeedRequest(
      P0.request,
      p0RequestDoc({ status: 'accepted', assignedDonorId: P0.donor }),
    );

    const db = testEnv.authenticatedContext(P0.owner).firestore();

    // The owner is the right sender and the request exists, but the victim never
    // accepted it, so there is nothing to cancel on their behalf.
    await assertFails(
      setDoc(
        doc(db, 'notifications', P0.cancelledNotification),
        p0NotificationData({
          recipientUid: P0.victim,
          type: 'request_cancelled',
        }),
      ),
    );
  });
});

describe('P0 finding 4 - unrestricted blood_requests owner update', () => {
  it('1. the owner can no longer rewrite status, assignment or ownership (finding closed)', async () => {
    await p0SeedRequest(P0.ownerRequest, p0RequestDoc({ userId: P0.owner }));

    const db = testEnv.authenticatedContext(P0.owner).firestore();
    const requestRef = doc(db, 'blood_requests', P0.ownerRequest);

    // The owner branch is now a set of named transitions, so a status jump, a
    // self-assignment and a transfer are refused one at a time.
    await assertFails(updateDoc(requestRef, { status: 'fulfilled' }));
    await assertFails(updateDoc(requestRef, { assignedDonorId: P0.victim }));
    await assertFails(updateDoc(requestRef, { userId: P0.victim }));

    // Editing the details of a request that is still open is what the owner is
    // for, blood group included: a typo may be corrected while nobody has
    // claimed, and that is the whole point of leaving the details editable.
    await assertSucceeds(
      updateDoc(requestRef, {
        hospitalName: 'Square Hospital',
        notes: 'Gate 2',
        bloodGroup: 'O-',
      }),
    );

    const stored = await assertSucceeds(getDoc(requestRef));
    assert.strictEqual(stored.data().status, 'open');
    assert.strictEqual(stored.data().assignedDonorId, null);
    assert.strictEqual(stored.data().bloodGroup, 'O-');
  });

  it('2. the owner can no longer transfer the request by rewriting userId (finding closed)', async () => {
    await p0SeedRequest(P0.ownerRequest, p0RequestDoc({ userId: P0.owner }));

    const ownerDb = testEnv.authenticatedContext(P0.owner).firestore();

    // Ownership is fixed at creation; a transfer is refused and the document
    // still belongs to the owner afterwards.
    await assertFails(
      updateDoc(doc(ownerDb, 'blood_requests', P0.ownerRequest), {
        userId: P0.victim,
      }),
    );

    const stored = await assertSucceeds(
      getDoc(doc(ownerDb, 'blood_requests', P0.ownerRequest)),
    );
    assert.strictEqual(stored.data().userId, P0.owner);
  });

  it('3. denies the same protected-field update from an unrelated authenticated user', async () => {
    await p0SeedRequest(P0.ownerRequest, p0RequestDoc({ userId: P0.owner }));

    const db = testEnv.authenticatedContext(P0.bystander).firestore();

    // Neither branch applies: not the owner, and the claimant branch needs
    // 'open' -> 'accepted'. 'fulfilled' and 'O-' satisfy neither.
    await assertFails(
      updateDoc(doc(db, 'blood_requests', P0.ownerRequest), {
        status: 'fulfilled',
        assignedDonorId: P0.bystander,
        bloodGroup: 'O-',
      }),
    );
  });

  it('4. the owner may cancel an accepted request, but not once the donation is completed', async () => {
    await p0SeedRequest(
      P0.ownerRequest,
      p0RequestDoc({ status: 'accepted', assignedDonorId: P0.donor }),
    );
    await p0SeedRequest(
      P0.secondRequest,
      p0RequestDoc({ status: 'donation_completed', assignedDonorId: P0.donor }),
    );

    const db = testEnv.authenticatedContext(P0.owner).firestore();

    // While it is accepted the details are frozen: cancelling is the only write
    // the patient has left, so the donor is not chasing a moving target.
    await assertFails(
      updateDoc(doc(db, 'blood_requests', P0.ownerRequest), {
        bloodGroup: 'O-',
      }),
    );

    await assertSucceeds(
      updateDoc(doc(db, 'blood_requests', P0.ownerRequest), {
        status: 'cancelled',
      }),
    );

    // The blood has already been drawn: the owner confirms or disputes the
    // donation, but can no longer make it disappear.
    await assertFails(
      updateDoc(doc(db, 'blood_requests', P0.secondRequest), {
        status: 'cancelled',
      }),
    );
  });

  it('5. the assigned donor cannot cancel on the patient\'s behalf', async () => {
    await p0SeedRequest(
      P0.ownerRequest,
      p0RequestDoc({ status: 'accepted', assignedDonorId: P0.donor }),
    );
    await p0SeedDonor(P0.donor);

    const db = testEnv.authenticatedContext(P0.donor).firestore();

    await assertFails(
      updateDoc(doc(db, 'blood_requests', P0.ownerRequest), {
        status: 'cancelled',
      }),
    );
  });

  it('6. only the patient may confirm a completed donation, and only towards fulfilled', async () => {
    await p0SeedRequest(
      P0.ownerRequest,
      p0RequestDoc({ status: 'donation_completed', assignedDonorId: P0.donor }),
    );
    await p0SeedRequest(
      P0.secondRequest,
      p0RequestDoc({ status: 'accepted', assignedDonorId: P0.donor }),
    );
    await p0SeedDonor(P0.donor);

    const donorDb = testEnv.authenticatedContext(P0.donor).firestore();
    const bystanderDb = testEnv.authenticatedContext(P0.bystander).firestore();

    await assertFails(
      updateDoc(doc(donorDb, 'blood_requests', P0.ownerRequest), {
        status: 'fulfilled',
      }),
    );
    await assertFails(
      updateDoc(doc(bystanderDb, 'blood_requests', P0.ownerRequest), {
        status: 'fulfilled',
      }),
    );

    const ownerDb = testEnv.authenticatedContext(P0.owner).firestore();

    // 'fulfilled' is unreachable straight from 'accepted': the donor has to
    // close out the donation first, which is what gives the patient something
    // to confirm.
    await assertFails(
      updateDoc(doc(ownerDb, 'blood_requests', P0.secondRequest), {
        status: 'fulfilled',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(ownerDb, 'blood_requests', P0.ownerRequest), {
        status: 'fulfilled',
      }),
    );
  });

  it('7. a donor cannot claim their own request', async () => {
    await p0SeedRequest(
      P0.ownerRequest,
      p0RequestDoc({ userId: P0.donor }),
    );
    await p0SeedDonor(P0.donor);

    const db = testEnv.authenticatedContext(P0.donor).firestore();

    // Requesting blood and donating it in the same document would let one
    // account manufacture its own donation record.
    await assertFails(
      updateDoc(doc(db, 'blood_requests', P0.ownerRequest), {
        status: 'accepted',
        assignedDonorId: P0.donor,
        acceptedAt: serverTimestamp(),
      }),
    );
  });

  it('8. the whole chain still runs: create, claim, complete, confirm, rate', async () => {
    await p0SeedDonor(P0.donor);

    const ownerDb = testEnv.authenticatedContext(P0.owner).firestore();
    const donorDb = testEnv.authenticatedContext(P0.donor).firestore();

    // The patient raises a request with the exact payload the create rule wants.
    await assertSucceeds(
      setDoc(
        doc(ownerDb, 'blood_requests', P0.ownerRequest),
        p0OpenRequestData({ userId: P0.owner }),
      ),
    );

    // A matching, available donor claims it, then closes out the donation.
    await assertSucceeds(
      updateDoc(doc(donorDb, 'blood_requests', P0.ownerRequest), {
        status: 'accepted',
        assignedDonorId: P0.donor,
        acceptedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(doc(donorDb, 'blood_requests', P0.ownerRequest), {
        status: 'donation_completed',
        completedAt: serverTimestamp(),
      }),
    );

    // The patient confirms it.
    await assertSucceeds(
      updateDoc(doc(ownerDb, 'blood_requests', P0.ownerRequest), {
        status: 'fulfilled',
      }),
    );

    // Both downstream contracts that key on 'fulfilled' are still reachable:
    // the rating, and the confirmed history record (now allowed after fulfilment
    // as well, so the order of the last two writes does not matter).
    await assertSucceeds(
      setDoc(doc(ownerDb, 'donation_ratings', P0.ownerRequest), {
        requestId: P0.ownerRequest,
        donorUid: P0.donor,
        recipientUid: P0.owner,
        stars: 5,
        review: 'Thank you',
        createdAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      setDoc(
        doc(ownerDb, 'donation_history', P0.forgedHistory),
        p0ConfirmedHistoryData({ requestId: P0.ownerRequest }),
      ),
    );
  });

  it('9. a confirmed record must match the request\'s blood group and hospital', async () => {
    await p0SeedRequest(
      P0.ownerRequest,
      p0RequestDoc({ status: 'donation_completed', assignedDonorId: P0.donor }),
    );

    const db = testEnv.authenticatedContext(P0.owner).firestore();
    const recordRef = doc(db, 'donation_history', P0.forgedHistory);

    await assertFails(
      setDoc(
        recordRef,
        p0ConfirmedHistoryData({
          requestId: P0.ownerRequest,
          bloodGroup: 'O-',
        }),
      ),
    );
    await assertFails(
      setDoc(
        recordRef,
        p0ConfirmedHistoryData({
          requestId: P0.ownerRequest,
          hospitalName: 'A Hospital That Never Treated Anyone',
        }),
      ),
    );
    await assertSucceeds(
      setDoc(
        recordRef,
        p0ConfirmedHistoryData({ requestId: P0.ownerRequest }),
      ),
    );
  });

  it('10. a confirmed record needs a completed request, and cannot name the owner as the donor', async () => {
    await p0SeedRequest(
      P0.ownerRequest,
      p0RequestDoc({ status: 'accepted', assignedDonorId: P0.donor }),
    );

    const ownerDb = testEnv.authenticatedContext(P0.owner).firestore();

    // Accepted is not completed: the donation has not happened yet.
    await assertFails(
      setDoc(
        doc(ownerDb, 'donation_history', P0.forgedHistory),
        p0ConfirmedHistoryData({ requestId: P0.ownerRequest }),
      ),
    );

    // Someone cannot confirm a donation to themselves.
    await p0SeedRequest(
      P0.secondRequest,
      p0RequestDoc({ status: 'donation_completed', assignedDonorId: P0.owner }),
    );
    await assertFails(
      setDoc(
        doc(ownerDb, 'donation_history', P0.batchHistory),
        p0ConfirmedHistoryData({
          requestId: P0.secondRequest,
          donorUid: P0.owner,
        }),
      ),
    );
  });
});

describe('Stage 9.1 blood_requests open-requests read path', () => {
  // FirestoreRequestDocuments.fetch issues exactly this query: one equality
  // filter on status, an over-fetch-by-one limit, no orderBy (requiredDateTime
  // is free TEXT here, so ordering under Firestore type rules happens in the
  // mapper). These tests prove the rules do not obstruct that read, and that
  // an anonymous caller cannot perform it.
  const openWindowQuery = (db) =>
    query(
      collection(db, 'blood_requests'),
      where('status', '==', 'open'),
      limit(26),
    );

  it('1. a signed-in client can run the open-requests window query and receives the text-typed request', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      // A second, closed request whose requiredDateTime is a TIMESTAMP: the
      // collection genuinely holds both types, which is why there is no
      // composite index and no orderBy.
      await adminCtx.firestore().collection('blood_requests').doc('req_beta_2').set({
        userId: IDS.recipient,
        patientName: 'Patient Two',
        phoneNumber: '+8801700000002',
        bloodGroup: 'B+',
        bloodBags: 2,
        hospitalName: 'Chattogram Medical College',
        hospitalAddress: 'Chattogram',
        requiredDateTime: new Date('2026-11-12T08:00:00Z'),
        status: 'fulfilled',
        createdAt: new Date(),
      });
    });

    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    const snapshot = await assertSucceeds(getDocs(openWindowQuery(db)));

    assert.strictEqual(snapshot.size, 1);
    const docSnap = snapshot.docs[0];
    assert.strictEqual(docSnap.id, IDS.request);
    // The mapper parses this string; proving it arrives as TEXT is the point.
    assert.strictEqual(docSnap.data().requiredDateTime, '2026-11-10 10:00 AM');
  });

  it('2. an unauthenticated client cannot run the open-requests window query', async () => {
    await seedBase();
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDocs(openWindowQuery(db)));
  });

  it('3. any signed-in user can read a single request document; anonymous cannot', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.otherDonor).firestore();
    await assertSucceeds(getDoc(doc(db, 'blood_requests', IDS.request)));

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(unauthDb, 'blood_requests', IDS.request)));
  });

  it('4. a signed-in client cannot reach a stranger\'s private notifications instead of the public request window', async () => {
    // Guards the read model's privacy claim: the window query is on
    // blood_requests, and nothing in Stage 9.1 reads a stranger's
    // notifications — the rules already deny that (only the recipient can
    // list), and this pins the fact.
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(
      getDocs(query(collection(db, 'notifications'), where('recipientUid', '==', IDS.recipient))),
    );
  });
});

// ---------------------------------------------------------------------------
// Stage 9.3 — the production compatibility audit turned two documented hazards
// into executed assertions. Both were previously proven only through the admin
// bypass (seedBase writes assignedDonorId: null with rules disabled), so a rule
// regression that started accepting a client-supplied assignment would have
// gone unnoticed. These run in a real client context.
// ---------------------------------------------------------------------------

// The eleven keys the post-Stage-9.5-M3 (corrected in M3-C1) client create rule
// expects on the public `blood_requests` projection. The three contact-PII keys
// (`patientName`, `phoneNumber`, `hospitalAddress`) that used to sit here as part
// of the fourteen-key production shape have moved to
// `blood_requests/{id}/private/contact`; a client that tries to write them into
// the public document is now refused by `hasOnly`.
// status is 'open' and createdAt is the server clock.
const productionRequestData = (overrides = {}) => ({
  userId: IDS.recipient,
  bloodGroup: 'A+',
  bloodBags: 1,
  hospitalName: 'Dhaka Medical College',
  requiredDateTime: '2026-11-10 10:00 AM',
  requestType: 'Normal',
  notes: '',
  latitude: 23.8,
  longitude: 90.4,
  status: 'open',
  createdAt: serverTimestamp(),
  ...overrides,
});

describe('Stage 9.3 blood_requests client create shape', () => {
  it('1. a client create of the exact production shape is accepted', async () => {
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'blood_requests', 'req_client_1'), productionRequestData()),
    );
  });

  it('2. a client cannot pre-assign a donor: adding assignedDonorId is refused by hasOnly', async () => {
    // The admin-bypass seed writes assignedDonorId: null, so only a client-
    // context test proves the create rule still excludes the key entirely.
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      setDoc(doc(db, 'blood_requests', 'req_client_2'), productionRequestData({ assignedDonorId: null })),
    );
    await assertFails(
      setDoc(doc(db, 'blood_requests', 'req_client_3'), productionRequestData({ assignedDonorId: IDS.donor })),
    );
  });

  it('3. a request is born open: a client cannot create it already accepted or fulfilled', async () => {
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      setDoc(doc(db, 'blood_requests', 'req_client_4'), productionRequestData({ status: 'accepted' })),
    );
    await assertFails(
      setDoc(doc(db, 'blood_requests', 'req_client_5'), productionRequestData({ status: 'fulfilled' })),
    );
  });

  it('4. a client cannot create a request for another user, unauthenticated, or with a device clock', async () => {
    const strangerDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(
      setDoc(doc(strangerDb, 'blood_requests', 'req_client_6'), productionRequestData({ userId: IDS.recipient })),
    );
    const anonDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(anonDb, 'blood_requests', 'req_client_7'), productionRequestData()),
    );
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      setDoc(doc(ownerDb, 'blood_requests', 'req_client_8'), productionRequestData({ createdAt: new Date() })),
    );
  });
});

describe('Stage 9.3 donors directory (donor discovery)', () => {
  // The production donors row: name, bloodGroup, phone, isAvailable, a geopoint
  // location, createdAt, and for the newer rows a uid binding the Firebase user.
  const validDonor = (overrides = {}) => ({
    name: 'Donor One',
    bloodGroup: 'A+',
    phone: '+8801700000001',
    isAvailable: true,
    location: new GeoPoint(23.8, 90.4),
    createdAt: serverTimestamp(),
    ...overrides,
  });

  const seedDonor = async (donorId, data) => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await setDoc(doc(adminCtx.firestore(), 'donors', donorId), {
        ...data,
        uid: donorId,
        createdAt: new Date('2026-10-01T09:00:00Z'),
      });
    });
  };

  it('1. the owner reads their own donor row; a stranger cannot, and cannot browse', async () => {
    // Stage 9.4 makes `donors` owner-only: it holds a phone, so it is no longer a
    // world-readable directory. A donor reads their own document; another signed-in
    // user is refused the same read, and a bulk browse is refused too. Discovery
    // reads the consent-gated public `users` profile instead (suite below).
    await seedDonor(IDS.donor, validDonor({ uid: undefined }));
    await seedDonor(IDS.otherDonor, validDonor({ bloodGroup: 'B+', isAvailable: false, uid: undefined }));
    const ownerDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertSucceeds(getDoc(doc(ownerDb, 'donors', IDS.donor)));
    const strangerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(getDoc(doc(strangerDb, 'donors', IDS.donor)));
    await assertFails(
      getDocs(query(collection(strangerDb, 'donors'), where('bloodGroup', '==', 'A+'), where('isAvailable', '==', true))),
    );
  });

  it('2. an unauthenticated client cannot browse the directory', async () => {
    await seedDonor(IDS.donor, validDonor({ uid: undefined }));
    const anonDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anonDb, 'donors', IDS.donor)));
  });

  it('3. a donor creates their own row keyed to their uid, with the server clock', async () => {
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertSucceeds(setDoc(doc(db, 'donors', IDS.donor), validDonor({ uid: IDS.donor })));
  });

  it('4. a donor cannot write a row under another uid, or forge the shape', async () => {
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(setDoc(doc(db, 'donors', IDS.otherDonor), validDonor()));
    await assertFails(setDoc(doc(db, 'donors', IDS.donor), validDonor({ uid: IDS.otherDonor })));
    await assertFails(setDoc(doc(db, 'donors', IDS.donor), validDonor({ bloodGroup: 'Z+' })));
    await assertFails(setDoc(doc(db, 'donors', IDS.donor), validDonor({ location: '23.8,90.4' })));
    await assertFails(setDoc(doc(db, 'donors', IDS.donor), validDonor({ createdAt: new Date() })));
  });

  it('5. the owner toggles availability; a stranger cannot edit anyone', async () => {
    await seedDonor(IDS.donor, validDonor({ uid: undefined }));
    await seedDonor(IDS.otherDonor, validDonor({ uid: undefined }));
    const ownerDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertSucceeds(updateDoc(doc(ownerDb, 'donors', IDS.donor), { isAvailable: false }));
    const strangerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(updateDoc(doc(strangerDb, 'donors', IDS.otherDonor), { isAvailable: false }));
  });

  it('6. a donor cannot rewrite their own identity binding or delete the row', async () => {
    await seedDonor(IDS.donor, validDonor({ uid: undefined }));
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    // uid is outside the update allow-list, so it can never move.
    await assertFails(updateDoc(doc(db, 'donors', IDS.donor), { uid: IDS.otherDonor }));
    await assertFails(deleteDoc(doc(db, 'donors', IDS.donor)));
  });
});

describe('Stage 9.4 donor discovery reads the public users profile', () => {
  // A public `users/{uid}` document, spelled the way ProfileDocuments.publicFields
  // writes it: only discovery-safe fields. `phone`, `addressLine`, date of birth and
  // gender live in the owner-only `private/profile` subcollection and are NOT here —
  // that absence is what makes the directory safe to open to signed-in users.
  const publicProfile = (overrides = {}) => ({
    displayName: 'Donor One',
    role: 'donor',
    bloodGroup: 'A+',
    isAvailable: true,
    photoUrl: null,
    ...overrides,
  });

  const seedUser = async (uid, data) => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await setDoc(doc(adminCtx.firestore(), 'users', uid), data);
    });
  };

  it('1. a signed-in user can run the discovery query over public profiles', async () => {
    await seedUser(IDS.donor, publicProfile());
    await seedUser(IDS.otherDonor, publicProfile({ bloodGroup: 'B+', isAvailable: false }));
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'users'),
          where('role', '==', 'donor'),
          where('isAvailable', '==', true),
          where('bloodGroup', '==', 'A+'),
        ),
      ),
    );
    // The area filter is a third equality on a published-area row; equality-only
    // queries merge single-field indexes, so no composite index is required.
    await seedUser(IDS.donor, publicProfile({ area: 'Dhanmondi' }));
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'users'),
          where('role', '==', 'donor'),
          where('area', '==', 'Dhanmondi'),
        ),
      ),
    );
  });

  it('2. a signed-in user can read another donor\'s public profile', async () => {
    await seedUser(IDS.donor, publicProfile());
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', IDS.donor)));
  });

  it('3. an unauthenticated client cannot browse profiles', async () => {
    await seedUser(IDS.donor, publicProfile());
    const anonDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anonDb, 'users', IDS.donor)));
  });

  it('4. the private subcollection that holds the phone stays owner-only', async () => {
    // Discovery must not reach the phone even though the public read is open: the
    // PII lives under `users/{uid}/private/profile`, which only the owner reads.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await setDoc(doc(adminCtx.firestore(), 'users', IDS.donor, 'private', 'profile'), {
        phone: '+8801700000001',
        addressLine: 'House 1, Road 2',
        publishAreaInSearch: true,
      });
    });
    const strangerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(getDoc(doc(strangerDb, 'users', IDS.donor, 'private', 'profile')));
    const ownerDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertSucceeds(getDoc(doc(ownerDb, 'users', IDS.donor, 'private', 'profile')));
  });
});

describe('Stage 9.5 donor discovery requires an explicit opt-in', () => {
  // The consent gate is a query-level filter, not a rules gate: `users/{uid}`
  // stays publicly readable (Stage 9.4 relies on it), but the discovery
  // query that the donor-search feature runs always adds
  // `where('allowDonorDiscovery', '==', true)`. These tests prove the query
  // does what the design says it does: opted-out and legacy documents are
  // never returned, so the app cannot accidentally list a donor who has not
  // said yes. A rules change is not required and none is being made here —
  // the enforcement is in the shape of the write and the shape of the query.
  const consented = (overrides = {}) => ({
    displayName: 'Consented Donor',
    role: 'donor',
    bloodGroup: 'A+',
    isAvailable: true,
    allowDonorDiscovery: true,
    ...overrides,
  });
  const optedOut = (overrides = {}) => ({
    displayName: 'Opted-Out Donor',
    role: 'donor',
    bloodGroup: 'A+',
    isAvailable: true,
    allowDonorDiscovery: false,
    ...overrides,
  });
  // A pre-Stage-9.5 document: written by an older build, so the key has never
  // been present. The consent gate has to treat absence as false.
  const legacy = (overrides = {}) => ({
    displayName: 'Legacy Donor',
    role: 'donor',
    bloodGroup: 'A+',
    isAvailable: true,
    ...overrides,
  });

  const seed = async (uid, data) => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await setDoc(doc(adminCtx.firestore(), 'users', uid), data);
    });
  };

  const discoveryQuery = (db) =>
    query(
      collection(db, 'users'),
      where('role', '==', 'donor'),
      where('allowDonorDiscovery', '==', true),
    );

  const idsFrom = async (snapshot) =>
    (await Promise.resolve(snapshot)).docs.map((d) => d.id).sort();

  it('1. the consented donor appears; opted-out and legacy do not', async () => {
    await seed(IDS.donor, consented());
    await seed(IDS.otherDonor, optedOut({ displayName: 'Opted-Out' }));
    const legacyUid = 'legacy_donor_3';
    await seed(legacyUid, legacy({ displayName: 'Legacy Donor' }));

    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    const snapshot = await assertSucceeds(getDocs(discoveryQuery(db)));
    const ids = await idsFrom(snapshot);

    // Only the opted-in document matches. Absent and false behave the same way
    // because the query asks for `== true`, and Firestore does not return a
    // document whose filter field is missing.
    assert.deepEqual(ids, [IDS.donor]);
  });

  it('2. the discovery query still permits additional equality filters', async () => {
    // The consent filter is always on; other filters stack on top of it. This
    // mirrors `FirestoreDonorDocuments.fetch` where role + consent + optional
    // bloodGroup / area / availability are combined with only equality
    // filters, so single-field indexes are enough and nothing needs deploying.
    await seed(IDS.donor, consented({ bloodGroup: 'O+' }));
    await seed(IDS.otherDonor, consented({ bloodGroup: 'B+' }));

    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    const snapshot = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'users'),
          where('role', '==', 'donor'),
          where('allowDonorDiscovery', '==', true),
          where('bloodGroup', '==', 'O+'),
        ),
      ),
    );
    const ids = await idsFrom(snapshot);

    assert.deepEqual(ids, [IDS.donor]);
  });

  it('3. opting out after opting in removes the donor from the query', async () => {
    // Round-trip: a document that had `allowDonorDiscovery: true` and is then
    // set to `false` (or, as `publicFields` does for withdrawal, has the key
    // deleted) stops appearing. This is the "withdraw consent" path the
    // profile screen takes.
    await seed(IDS.donor, consented());
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();

    const before = await idsFrom(getDocs(discoveryQuery(db)));
    assert.deepEqual(before, [IDS.donor]);

    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      // Mimics the merge-write pattern ProfileDocuments uses: an update that
      // writes `false` (as the private copy does) or deletes the key (as the
      // public projection does) — either is enough for the query to stop
      // matching.
      await updateDoc(doc(adminCtx.firestore(), 'users', IDS.donor), {
        allowDonorDiscovery: false,
      });
    });

    const after = await idsFrom(getDocs(discoveryQuery(db)));
    assert.deepEqual(after, []);
  });

  it('4. a recipient browsing users is not filtered by consent — the rules do not gate reads on the flag', async () => {
    // Consent is a *directory* control, not a *read* control. Any signed-in
    // user can still `getDoc(users/{uid})` for a peer, exactly as they could
    // before Stage 9.5; the change is that the discovery query does not hand
    // them opted-out rows in a bulk read. This distinction matters because the
    // recipient who has matched with a donor through a request still needs to
    // see that donor's profile — the consent is about the searchable
    // directory, not about the person they are already talking to.
    await seed(IDS.donor, optedOut());
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();

    // A direct getDoc on the same document is still allowed by the rules.
    const snap = await assertSucceeds(getDoc(doc(db, 'users', IDS.donor)));
    assert.equal(snap.data().displayName, 'Opted-Out Donor');

    // But a discovery query would not have returned it — the query, not the
    // rules, is what hides it.
    const q = await assertSucceeds(getDocs(discoveryQuery(db)));
    assert.equal(q.docs.length, 0);
  });

  it('5. an unauthenticated client cannot run the discovery query either', async () => {
    // Stage 9.4 already closed unauthenticated browsing of `users`; Stage 9.5
    // does not widen it. The consent filter is on top of the same rules.
    await seed(IDS.donor, consented());
    const anonDb = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDocs(discoveryQuery(anonDb)));
  });
});

describe('Stage 9.5 M2 — public users profile field allow-list', () => {
  // Stage 9.5 (M2). The rule that used to sit here was `allow write: if
  // request.auth != null && request.auth.uid == userId`, so any owner write
  // went through, no matter which fields it carried. That made it possible —
  // through a client bug or a hostile payload — for a phone number, a street
  // address, or a date of birth to land on `users/{uid}`, which every
  // signed-in account can read. The allow-list closes that hole: even the
  // account's own owner can no longer put a sensitive field into the public
  // projection.
  //
  // The allow-list matches what `ProfileDocuments.publicFields`,
  // `availabilityFields`, `photoFields` and `coverFields` actually write. Any of
  // the private keys — `phone`, `addressLine`, `dateOfBirth`, `gender`,
  // `publishAreaInSearch` — must be refused on both create and update.
  const PUBLIC_FIELDS = [
    'displayName',
    'role',
    'isAvailable',
    'updatedAt',
    'bloodGroup',
    'photoUrl',
    'coverUrl',
    'area',
    'allowDonorDiscovery',
  ];

  const legalPublicDoc = (overrides = {}) => ({
    displayName: 'Rafiq Hasan',
    role: 'donor',
    isAvailable: true,
    bloodGroup: 'O+',
    updatedAt: new Date(),
    ...overrides,
  });

  it('1. the owner can create their public profile with only the allow-listed keys', async () => {
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    // The exact shape `ProfileDocuments.publicFields` writes for a consented
    // donor with an area — every key on the allow-list, none off it.
    const payload = legalPublicDoc({
      photoUrl: 'https://cdn/ayesha.jpg',
      coverUrl: 'https://cdn/ayesha-cover.jpg',
      area: 'Dhanmondi, Dhaka',
      allowDonorDiscovery: true,
    });

    await assertSucceeds(setDoc(doc(db, 'users', IDS.donor), payload));
    const snap = await getDoc(doc(db, 'users', IDS.donor));
    assert.equal(snap.data().displayName, 'Rafiq Hasan');
  });

  it('2. the owner cannot create a public profile that carries a phone', async () => {
    // The whole point of M2. A buggy or hostile client that tried to write
    // `phone` into the public projection is refused at the rules layer, not
    // at the write path — a leak stops being a discipline problem.
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(
      setDoc(doc(db, 'users', IDS.donor), legalPublicDoc({ phone: '+8801700000001' })),
    );
  });

  it('3. the owner cannot create a public profile with addressLine, dateOfBirth or gender', async () => {
    // Each sensitive key is its own refusal, not a shared one. A test that
    // batched them together would only prove one of them was in the deny set.
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    for (const [key, value] of [
      ['addressLine', 'House 12, Road 5'],
      ['dateOfBirth', new Date('1996-04-17')],
      ['gender', 'female'],
      ['publishAreaInSearch', true],
    ]) {
      await assertFails(
        setDoc(doc(db, 'users', IDS.donor), legalPublicDoc({ [key]: value })),
        `${key} must not be creatable on the public profile`,
      );
    }
  });

  it('4. the owner cannot inject a sensitive field by updating an existing public profile', async () => {
    // A hostile update against an existing profile is the more realistic
    // attack than a create: a legitimate profile already lives at
    // `users/{uid}`, and the caller adds `phone` to it. `affectedKeys()`
    // catches the addition even when every other field on the document is
    // already allow-listed.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await setDoc(doc(adminCtx.firestore(), 'users', IDS.donor), legalPublicDoc());
    });
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      updateDoc(doc(db, 'users', IDS.donor), { phone: '+8801700000001' }),
    );
  });

  it('5. the owner can legitimately update an allow-listed field', async () => {
    // Preserving legitimate profile-edit: a name change, an availability
    // toggle, a photo upload or a discovery-consent flip must all keep
    // working after the allow-list lands.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await setDoc(doc(adminCtx.firestore(), 'users', IDS.donor), legalPublicDoc());
    });
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertSucceeds(updateDoc(doc(db, 'users', IDS.donor), { displayName: 'Rafiq Uddin' }));
    await assertSucceeds(updateDoc(doc(db, 'users', IDS.donor), { isAvailable: false }));
    await assertSucceeds(updateDoc(doc(db, 'users', IDS.donor), { photoUrl: 'https://cdn/new.jpg' }));
    await assertSucceeds(updateDoc(doc(db, 'users', IDS.donor), { coverUrl: 'https://cdn/new-cover.jpg' }));
    await assertSucceeds(updateDoc(doc(db, 'users', IDS.donor), { allowDonorDiscovery: true }));
  });

  it('6. the owner can clear an optional field via merge-delete of an allow-listed key', async () => {
    // `ProfileDocuments.publicFields` writes `FieldValue.delete()` to
    // withdraw an area or discovery consent. Firestore's affected-keys diff
    // reports that as touching the deleted key, which is on the allow-list,
    // so the write is legal.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await setDoc(
        doc(adminCtx.firestore(), 'users', IDS.donor),
        legalPublicDoc({ area: 'Dhanmondi', allowDonorDiscovery: true }),
      );
    });
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertSucceeds(
      updateDoc(doc(db, 'users', IDS.donor), {
        area: null,
        allowDonorDiscovery: false,
      }),
    );
  });

  it('7. a signed-in stranger cannot write anything to another account\'s public profile', async () => {
    // The `request.auth.uid == userId` half of the rule still applies to
    // every field, whether or not that field is on the allow-list. A stranger
    // who tries the *most innocuous* update is refused the same way an
    // attacker is refused a `phone` injection.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await setDoc(doc(adminCtx.firestore(), 'users', IDS.donor), legalPublicDoc());
    });
    const strangerDb = testEnv.authenticatedContext(IDS.recipient).firestore();

    await assertFails(updateDoc(doc(strangerDb, 'users', IDS.donor), { displayName: 'Hijacked' }));
    await assertFails(setDoc(doc(strangerDb, 'users', IDS.donor), legalPublicDoc()));
    await assertFails(deleteDoc(doc(strangerDb, 'users', IDS.donor)));
  });

  it('8. the owner can delete their own public profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await setDoc(doc(adminCtx.firestore(), 'users', IDS.donor), legalPublicDoc());
    });
    const ownerDb = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertSucceeds(deleteDoc(doc(ownerDb, 'users', IDS.donor)));
  });

  it('9. an unauthenticated client cannot create or update a public profile', async () => {
    const anonDb = testEnv.unauthenticatedContext().firestore();

    await assertFails(setDoc(doc(anonDb, 'users', IDS.donor), legalPublicDoc()));
    await assertFails(updateDoc(doc(anonDb, 'users', IDS.donor), { displayName: 'Ghost' }));
  });

  it('10. a legacy users/{uid} document carrying old keys can still be updated on allow-listed keys', async () => {
    // Migration-friendly behaviour: `affectedKeys()` looks at what the write
    // changes, not at what the stored document holds. A pre-Stage-9.5
    // document that has, say, `fullName` and `uid` sitting on it is not
    // forced through a data migration — a normal profile-save still touches
    // only allow-listed keys, so it is accepted. Only writing the sensitive
    // keys is refused.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await setDoc(doc(adminCtx.firestore(), 'users', IDS.donor), {
        fullName: 'Legacy Donor',
        uid: IDS.donor,
        role: 'donor',
        bloodGroup: 'A+',
        isAvailable: true,
      });
    });
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertSucceeds(updateDoc(doc(db, 'users', IDS.donor), { displayName: 'Rafiq' }));
    await assertFails(updateDoc(doc(db, 'users', IDS.donor), { phone: '+8801700000001' }));
  });

  it('11. the private subcollection still holds the sensitive fields for the owner', async () => {
    // The rule that makes the whole M2 story coherent: the sensitive keys
    // the public allow-list refuses are exactly the ones the private
    // subcollection accepts. A phone number written here stays owner-only.
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertSucceeds(
      setDoc(doc(db, 'users', IDS.donor, 'private', 'profile'), {
        phone: '+8801700000001',
        addressLine: 'House 12, Road 5',
        dateOfBirth: new Date('1996-04-17'),
        gender: 'male',
        publishAreaInSearch: true,
        allowDonorDiscovery: true,
        area: 'Dhanmondi, Dhaka',
      }),
    );

    const strangerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(getDoc(doc(strangerDb, 'users', IDS.donor, 'private', 'profile')));
  });

  // Sanity assertion for reviewers: the allow-list here matches the shape the
  // profile layer writes. Any drift between the Dart and the rules would show
  // up as one of these strings missing, so keeping the two side by side makes
  // that drift visible.
  it('12. the allow-list literal is exhaustive against what ProfileDocuments writes', async () => {
    assert.deepEqual(
      [...PUBLIC_FIELDS].sort(),
      [
        'allowDonorDiscovery',
        'area',
        'bloodGroup',
        'coverUrl',
        'displayName',
        'isAvailable',
        'photoUrl',
        'role',
        'updatedAt',
      ],
      'The Dart write side and the rules must agree on every public key',
    );
  });
});

describe('Stage 9.5 M3 — blood request private contact subcollection', () => {
  // Stage 9.5 (M3), corrected in M3-C1 / M3-C2.
  //
  // M3-C1: the rules split the request document into a public projection and a
  // `private/contact` subcollection. Everything that identifies, reaches or
  // pinpoints the patient (`patientName`, `phoneNumber`, `hospitalAddress`) moves
  // to the subcollection; the list row keeps only group, units, hospital name and
  // the required-by text.
  //
  // M3-C2: the authoritative proof of a legitimate match is the immutable
  // `response_claims` row, NOT the parent's client-writable `assignedDonorId` /
  // `status`, which any matching, available donor can self-forge with a single
  // public update (see the forgery tests at the end). That claim row, however, is
  // addressed by a length-prefixed id, and Firestore security rules cannot cast
  // an integer to a string, so the row is unreachable from a rule (see the
  // M3-C2 BLOCKER note in firestore.rules). The minimum SAFE interim is therefore
  // to make the private contact OWNER-ONLY: no donor read at all — legitimately
  // matched or self-forged — until a rule-derivable authoritative anchor lands in
  // a later stage. The tests below lock that posture: the owner reads succeed, and
  // EVERY donor read is refused, including a donor whose real claim landed (which
  // is a deliberate, reported narrowing, not a bug).
  const contactPath = (requestId) =>
    ['blood_requests', requestId, 'private', 'contact'];

  const contactPayload = (overrides = {}) => ({
    patientName: 'Ayesha Begum',
    phoneNumber: '+8801700000009',
    hospitalAddress: 'Road 12, Dhanmondi, Dhaka',
    ...overrides,
  });

  // Public create shape as the app writes it (post-M3-C1, no contact PII), used
  // as the parent for every contact-record test below. Rules-validated so a
  // caller can only put their own userId on it.
  const publicCreate = (db, requestId, overrides = {}) =>
    setDoc(
      doc(db, 'blood_requests', requestId),
      productionRequestData({ userId: IDS.recipient, ...overrides }),
    );

  // Seed the base roles plus a request already at `status` and assigned to
  // IDS.donor, and — when `withClaim` — the authoritative `response_claims` row
  // (and its backing `request_responses` row) that a real booking transaction
  // would have written. Everything is placed with the rules disabled so these
  // tests isolate the subcollection's read rule from the transaction that
  // normally produces the state.
  const seedAssigned = async ({
    status = 'accepted',
    withClaim = true,
    donorRole = 'donor',
    seedDonorUser = true,
  } = {}) => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const db = adminCtx.firestore();
      await db.collection('users').doc(IDS.recipient).set({
        uid: IDS.recipient,
        fullName: 'Recipient Owner',
        role: 'recipient',
        bloodGroup: 'O+',
        isAvailable: false,
      });
      if (seedDonorUser) {
        await db.collection('users').doc(IDS.donor).set({
          uid: IDS.donor,
          fullName: 'Donor One',
          role: donorRole,
          bloodGroup: 'A+',
          isAvailable: true,
        });
      }
      await db.collection('blood_requests').doc(IDS.request).set({
        ...productionRequestData({ userId: IDS.recipient }),
        status,
        assignedDonorId: IDS.donor,
      });
      if (withClaim) {
        await db.collection('request_responses').doc(IDS.response).set({
          requestId: IDS.request,
          donorId: IDS.donor,
          donorName: 'Donor One',
          donorPhone: '+8801700000001',
          bloodGroup: 'A+',
          status: 'accepted',
          createdAt: new Date(),
        });
        await db
          .collection('response_claims')
          .doc(claimDocId(IDS.request, IDS.donor))
          .set({
            requestId: IDS.request,
            donorId: IDS.donor,
            responseId: IDS.response,
          });
      }
    });
  };

  it('1. the public create rule refuses a client that adds patientName', async () => {
    // The whole point of the M3 shape change: the fields the Dart reader
    // already refused to render are now refused at the rules layer too. The
    // rest of the payload is exactly the shape a legitimate create uses.
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      setDoc(
        doc(db, 'blood_requests', 'm3_req_withPatientName'),
        productionRequestData({ patientName: 'Leak' }),
      ),
    );
  });

  it('2. the public create rule refuses a client that adds phoneNumber', async () => {
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      setDoc(
        doc(db, 'blood_requests', 'm3_req_withPhoneNumber'),
        productionRequestData({ phoneNumber: '+8801700000000' }),
      ),
    );
  });

  it('2b. the public create rule refuses a client that adds hospitalAddress', async () => {
    // M3-C1 moved the specific street line to private/contact too. The public
    // projection keeps only `hospitalName`, so an attempt to carry an address on
    // the list document is refused by the same `hasOnly`.
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      setDoc(
        doc(db, 'blood_requests', 'm3_req_withHospitalAddress'),
        productionRequestData({ hospitalAddress: 'House 12, Road 5' }),
      ),
    );
  });

  it('3. the public create rule still accepts the eleven-key shape (no PII)', async () => {
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(publicCreate(db, 'm3_req_cleanPublic'));
  });

  it('4. the request owner can create the private/contact document', async () => {
    // A contact record is a shape-checked set of the three private fields.
    await seedBase({ withResponse: false });
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(db, ...contactPath(IDS.request)), contactPayload()),
    );
    const snap = await getDoc(doc(db, ...contactPath(IDS.request)));
    assert.strictEqual(snap.data().patientName, 'Ayesha Begum');
    assert.strictEqual(snap.data().hospitalAddress, 'Road 12, Dhanmondi, Dhaka');
  });

  it('5. the owner cannot create a contact record that carries an extra field', async () => {
    // hasOnly([patientName, phoneNumber, hospitalAddress]) — no stray medical
    // notes, no secondary phone, no id-number. The subcollection is deliberately
    // narrow so the shape of "PII we hold" stays auditable.
    await seedBase({ withResponse: false });
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      setDoc(
        doc(db, ...contactPath(IDS.request)),
        contactPayload({ nationalId: '1234-5678' }),
      ),
    );
  });

  it('6. the owner cannot create a contact record that is missing a field', async () => {
    // hasAll([patientName, phoneNumber, hospitalAddress]): all three are
    // required to be present, so a partial record (even a real name + phone with
    // the address simply omitted) is refused.
    await seedBase({ withResponse: false });
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      setDoc(
        doc(db, ...contactPath(IDS.request)),
        { patientName: 'Only Name' },
      ),
    );
    await assertFails(
      setDoc(
        doc(db, ...contactPath(IDS.request)),
        { phoneNumber: '+8801700000099' },
      ),
    );
    await assertFails(
      setDoc(
        doc(db, ...contactPath(IDS.request)),
        { patientName: 'Ayesha Begum', phoneNumber: '+8801700000009' },
      ),
    );
  });

  it('7. the owner cannot create a contact record with an empty patientName or phoneNumber', async () => {
    // size() > 0 for the name and phone: an empty string is not a name, and an
    // empty phone cannot be dialled. `hospitalAddress` is allowed to be an empty
    // string (a patient with no street line is not blocked), so only the name and
    // phone are checked for length.
    await seedBase({ withResponse: false });
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      setDoc(
        doc(db, ...contactPath(IDS.request)),
        contactPayload({ patientName: '' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(db, ...contactPath(IDS.request)),
        contactPayload({ phoneNumber: '' }),
      ),
    );
    // A blank-but-present address is accepted.
    await assertSucceeds(
      setDoc(
        doc(db, ...contactPath(IDS.request)),
        contactPayload({ hospitalAddress: '' }),
      ),
    );
  });

  it('8. a stranger cannot create the contact record for someone else\'s request', async () => {
    // The rule is `parent.userId == request.auth.uid`, so a caller who is not
    // the request owner cannot write the contact even for a request that does
    // not yet have one.
    await seedBase({ withResponse: false });
    const strangerDb = testEnv.authenticatedContext(IDS.otherDonor).firestore();
    await assertFails(
      setDoc(doc(strangerDb, ...contactPath(IDS.request)), contactPayload()),
    );
  });

  it('9. the request owner can read their own contact record', async () => {
    await seedBase({ withResponse: false });
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );
    await assertSucceeds(getDoc(doc(ownerDb, ...contactPath(IDS.request))));
  });

  it('10. a donor whose real claim landed still cannot read the contact (owner-only interim)', async () => {
    // M3-C2 interim: the read is owner-only until a rule-derivable authoritative
    // anchor lands. Even a legitimately matched donor — the authoritative
    // `response_claims` row present alongside the accepted assignment — is
    // refused. This is the deliberate, reported narrowing that keeps the patient
    // PII from leaking to a donor we cannot prove in a rule.
    await seedAssigned({ status: 'accepted', withClaim: true });
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );
    // The owner can still read it back.
    await assertSucceeds(getDoc(doc(ownerDb, ...contactPath(IDS.request))));
    const donorDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(getDoc(doc(donorDb, ...contactPath(IDS.request))));
  });

  it('11. an assigned donor cannot read the contact while the donation is being closed out', async () => {
    // 'donation_completed' with a real claim: still owner-only under the interim.
    await seedAssigned({ status: 'donation_completed', withClaim: true });
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );
    const donorDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(getDoc(doc(donorDb, ...contactPath(IDS.request))));
  });

  it('12. an assigned donor cannot read the contact after the request reaches fulfilled', async () => {
    // Refused under the owner-only interim (and, when a donor-read branch is
    // added later, it must also close once the patient confirms fulfilment).
    await seedAssigned({ status: 'fulfilled', withClaim: true });
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );
    const donorDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(getDoc(doc(donorDb, ...contactPath(IDS.request))));
  });

  it('13. a donor read is refused while the request is still open (nobody has claimed it yet)', async () => {
    // An open request has no assigned donor and no claim.
    await seedBase({ requestStatus: 'open', withResponse: false });
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );
    const donorDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(getDoc(doc(donorDb, ...contactPath(IDS.request))));
  });

  it('14. a signed-in stranger (not assigned, no claim) cannot read the contact', async () => {
    await seedAssigned({ status: 'accepted', withClaim: true });
    const strangerDb = testEnv.authenticatedContext(IDS.otherDonor).firestore();
    await assertFails(getDoc(doc(strangerDb, ...contactPath(IDS.request))));
  });

  it('15. an unauthenticated caller cannot read the contact', async () => {
    await seedAssigned({ status: 'accepted', withClaim: true });
    const anonDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anonDb, ...contactPath(IDS.request))));
  });

  it('16. a matched donor read stays refused regardless of the caller\'s role', async () => {
    // Under the owner-only interim every donor read is refused; this case holds a
    // real claim and a live assignment but the caller has since converted to a
    // recipient, so it doubles as a guard that a future donor-read branch must
    // still gate on role==donor. It fails today simply because the read is
    // owner-only.
    await seedAssigned({
      status: 'accepted',
      withClaim: true,
      donorRole: 'recipient',
    });
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );
    const formerDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(getDoc(doc(formerDb, ...contactPath(IDS.request))));
  });

  it('17. a matched donor whose users document is missing is also refused', async () => {
    // Another guard for a future donor-read branch (it must require the caller's
    // users doc to exist). Under today's owner-only interim it fails simply
    // because no donor can read the contact.
    await seedAssigned({
      status: 'accepted',
      withClaim: true,
      seedDonorUser: false,
    });
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );
    // IDS.donor is intentionally NOT seeded as a user document.
    const ghostDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(getDoc(doc(ghostDb, ...contactPath(IDS.request))));
  });

  it('18. the contact subcollection refuses writes to any document id other than the pinned `contact`', async () => {
    // The rules block matches `private/{contactDoc}` but every clause carries
    // a `contactDoc == 'contact'` guard, so paths like `private/backup` or
    // `private/profile` under `blood_requests` fall through to Firestore's
    // default-deny. A caller cannot bury a copy of the patient's phone at an
    // alternate id next to the legitimate record.
    await seedBase({ withResponse: false });
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      setDoc(
        doc(db, 'blood_requests', IDS.request, 'private', 'backup'),
        contactPayload(),
      ),
    );
  });

  it('19. the request owner can update and delete their contact record', async () => {
    await seedBase({ withResponse: false });
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(db, ...contactPath(IDS.request)), contactPayload()),
    );
    await assertSucceeds(
      updateDoc(doc(db, ...contactPath(IDS.request)), {
        phoneNumber: '+8801799999999',
      }),
    );
    await assertSucceeds(deleteDoc(doc(db, ...contactPath(IDS.request))));
  });

  it('20. a stranger cannot delete another user\'s contact record', async () => {
    await seedBase({ withResponse: false });
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );
    const strangerDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(deleteDoc(doc(strangerDb, ...contactPath(IDS.request))));
  });

  it('21. the patient-edits-details update branch no longer accepts a PII/hospitalAddress injection', async () => {
    // Before M3 the affected-keys allow-set for the edit branch was named
    // after every public field, including `patientName`/`phoneNumber`/
    // `hospitalAddress`. After M3-C1 those three keys are gone, so an update that
    // tries to CHANGE them on an existing open request is refused even though the
    // caller is the owner. The values must differ from what seedBase wrote, or
    // the diff would report an empty affected set and the rules would accept the
    // write as a no-op — a legitimate Firestore behaviour unrelated to M3-C1.
    await seedBase({ requestStatus: 'open', withResponse: false });
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), {
        patientName: 'Silently Re-Injected',
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), {
        phoneNumber: '+8801799999999',
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), {
        hospitalAddress: 'Secret New Address',
      }),
    );
    // A legitimate edit through the same branch still succeeds.
    await assertSucceeds(
      updateDoc(doc(db, 'blood_requests', IDS.request), {
        bloodBags: 2,
      }),
    );
  });

  it('22. the subcollection shape sanity: exactly three keys, all strings', async () => {
    // A reviewer's sanity check: the rules require `patientName`, `phoneNumber`
    // and `hospitalAddress` and refuse every other key. If a future stage wants
    // to widen the shape this test has to change, and the reviewer of that PR is
    // forced to look at the shape decision rather than accept it silently.
    const required = ['patientName', 'phoneNumber', 'hospitalAddress'];
    assert.deepEqual(
      [...required].sort(),
      ['hospitalAddress', 'patientName', 'phoneNumber'],
      'The subcollection accepts exactly these three keys, nothing else',
    );
  });

  // ---------------------------------------------------------------------------
  // M3-C2 — forged and legitimate donor reads alike are refused: the contact is
  // owner-only, so neither a self-written `assignedDonorId` / `status` nor a real
  // (but rule-unreachable) claim opens a donor read.
  // ---------------------------------------------------------------------------

  it('23. a matching donor CAN self-assign the public request, but that alone does NOT open the contact', async () => {
    // This is the exact scenario the three-signal design used to trust: a real,
    // available, blood-group-matching donor uses the legitimate
    // `blood_requests` update branch to set `assignedDonorId = self` and
    // `status = accepted` in one client write, WITHOUT running the booking
    // transaction that would create a `response_claims` row. The public update is
    // allowed (proving the fields are forgeable), yet the contact read stays shut
    // because no claim exists at the deterministic lock key.
    await seedBase({ requestStatus: 'open', withResponse: false });

    // Owner raises the contact record while the request is still open.
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );

    // The donor self-assigns on the public document (no response, no claim).
    const donorDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertSucceeds(
      updateDoc(doc(donorDb, 'blood_requests', IDS.request), {
        status: 'accepted',
        assignedDonorId: IDS.donor,
        acceptedAt: serverTimestamp(),
      }),
    );

    // ...and the forged assignment buys them nothing.
    await assertFails(getDoc(doc(donorDb, ...contactPath(IDS.request))));
  });

  it('24. an unrelated donor cannot read the contact even if they forge the assignment fields', async () => {
    // A donor who is NOT the one whose claim landed — here the request is a
    // stranger's that the attacker cannot even self-assign (blood-group
    // mismatch) — must be refused. Seeds a request that legitimately belongs to
    // another patient and has no claim for the attacker.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const db = adminCtx.firestore();
      await db.collection('users').doc(IDS.recipient).set({
        uid: IDS.recipient,
        fullName: 'Recipient Owner',
        role: 'recipient',
        bloodGroup: 'O+',
        isAvailable: false,
      });
      // The attacker is an available donor whose group does NOT match the
      // request, so even the public self-assign branch is closed to them.
      await db.collection('users').doc(IDS.otherDonor).set({
        uid: IDS.otherDonor,
        fullName: 'Donor Two',
        role: 'donor',
        bloodGroup: 'B+',
        isAvailable: true,
      });
      await db.collection('blood_requests').doc(IDS.request).set({
        ...productionRequestData({ userId: IDS.recipient, bloodGroup: 'A+' }),
        status: 'accepted',
        assignedDonorId: IDS.donor,
      });
    });
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );
    // The attacker cannot even forge: the update is refused...
    const attackerDb = testEnv.authenticatedContext(IDS.otherDonor).firestore();
    await assertFails(
      updateDoc(doc(attackerDb, 'blood_requests', IDS.request), {
        status: 'accepted',
        assignedDonorId: IDS.otherDonor,
        acceptedAt: serverTimestamp(),
      }),
    );
    // ...and, with the assignment still pointing at the real donor, the attacker
    // has no claim of their own so the contact read is refused.
    await assertFails(getDoc(doc(attackerDb, ...contactPath(IDS.request))));
  });

  it('25. even the full booking transaction (response + claim + assignment) does NOT open a donor read yet', async () => {
    // The negative control for tests 23/24: the legitimate path writes all three
    // documents atomically and produces a real `response_claims` row, yet under
    // the M3-C2 owner-only interim the donor read is STILL refused. This is the
    // reported blocker, not a test gap — the rule cannot address the length-
    // prefixed claim row (see firestore.rules), so it deliberately trusts no
    // donor read at all. When a rule-derivable authoritative anchor lands, THIS
    // is the test that should flip to assertSucceeds.
    await seedBase({ requestStatus: 'open', withResponse: false });
    const ownerDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, ...contactPath(IDS.request)), contactPayload()),
    );

    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    const requestRef = doc(db, 'blood_requests', IDS.request);
    const responseRef = doc(db, 'request_responses', IDS.response);
    const claimRef = doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor));
    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const snap = await tx.get(requestRef);
        assert.strictEqual(snap.data().status, 'open');
        tx.set(responseRef, {
          requestId: IDS.request,
          donorId: IDS.donor,
          donorName: 'Donor One',
          donorPhone: '+8801700000001',
          bloodGroup: 'A+',
          status: 'accepted',
          createdAt: serverTimestamp(),
        });
        tx.set(claimRef, {
          requestId: IDS.request,
          donorId: IDS.donor,
          responseId: IDS.response,
        });
        tx.update(requestRef, {
          status: 'accepted',
          assignedDonorId: IDS.donor,
          acceptedAt: serverTimestamp(),
        });
      }),
    );

    // The claim row is provably present (the owner/transaction wrote it), yet the
    // donor contact read is refused — owner-only interim.
    const donorDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertFails(getDoc(doc(donorDb, ...contactPath(IDS.request))));
    // And the owner still reads their own contact intact.
    const ownerRead = await assertSucceeds(getDoc(doc(ownerDb, ...contactPath(IDS.request))));
    assert.strictEqual(ownerRead.data().patientName, 'Ayesha Begum');
  });
});
