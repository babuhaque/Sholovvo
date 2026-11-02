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
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  runTransaction,
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
const p0OpenRequestData = (overrides = {}) => ({
  userId: P0.attacker,
  patientName: 'P0 Patient',
  phoneNumber: '+8801700000000',
  bloodGroup: 'A+',
  bloodBags: 1,
  hospitalName: P0_HOSPITAL,
  hospitalAddress: 'Dhaka',
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
// about how the document got into that state.
const p0RequestDoc = ({
  userId = P0.owner,
  status = 'open',
  assignedDonorId = null,
  bloodGroup = 'A+',
  hospitalName = P0_HOSPITAL,
} = {}) => ({
  userId,
  patientName: 'P0 Patient',
  phoneNumber: '+8801700000000',
  bloodGroup,
  bloodBags: 1,
  hospitalName,
  hospitalAddress: 'Dhaka',
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

