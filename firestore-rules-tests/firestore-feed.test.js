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

// Same teardown discipline as firestore.test.js: without cleanup the gRPC
// channels keep `emulators:exec` alive after the last test.
after(async () => {
  await testEnv.cleanup();
});

// ---------------------------------------------------------------------------
// Stage 8.1 — feed collections. These tests first ran as behaviour discovery
// against the pre-reconciliation rules (95/95 green, every "(P0 finding)"
// gap reproduced); the record lives in docs/PROJECT_STATE.md. They now pin
// the CLOSED behaviour from the Stage 8.1.1 reconciliation (ARCHITECTURE
// section 14.1): the payloads still mirror PostDocument.toCreateMap exactly,
// so a green create here means the shipped client keeps working.
// ---------------------------------------------------------------------------

const FEED = {
  author: 'feed_author_1',
  stranger: 'feed_stranger_2',
  post: 'post_alpha_1',
  comment: 'comment_alpha_1',
  history: 'hist_confirmed_1',
  report: 'report_alpha_1',
  report2: 'report_beta_2',
};

// Exactly the nine keys of PostDocument.requiredFields plus nothing:
// this is what FirestorePostWriter sends for a text-only post.
const validPostData = (overrides = {}) => ({
  authorUid: FEED.author,
  authorName: 'Donor One',
  text: 'Completed my fifth donation today, thank you to everyone here.',
  imageUrls: [],
  imagePaths: [],
  likeCount: 0,
  commentCount: 0,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

const seedPost = async (overrides = {}) => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(doc(adminCtx.firestore(), 'posts', FEED.post), {
      ...validPostData(),
      createdAt: new Date('2026-11-01T10:00:00Z'),
      updatedAt: new Date('2026-11-01T10:00:00Z'),
      ...overrides,
    });
  });
};

const seedConfirmedDonation = async () => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(doc(adminCtx.firestore(), 'donation_history', FEED.history), {
      donorUid: FEED.author,
      bloodGroup: 'A+',
      hospitalName: 'Dhaka Medical College',
      status: 'confirmed',
      createdAt: new Date('2026-10-20T09:00:00Z'),
    });
  });
};

describe('Stage 8.1 posts — create discovery', () => {
  it('1. the exact client-shaped create succeeds (must stay green after tightening)', async () => {
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertSucceeds(setDoc(doc(db, 'posts', 'post_new_1'), validPostData()));
  });

  it('2. unauthenticated create fails', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, 'posts', 'post_new_1'), validPostData()));
  });

  it('3. create with another user as authorUid fails', async () => {
    const db = testEnv.authenticatedContext(FEED.stranger).firestore();
    await assertFails(
      setDoc(doc(db, 'posts', 'post_new_1'), validPostData({ authorUid: FEED.author })),
    );
  });

  it('4. create with required keys missing is refused (shape mirrors PostDocument.requiredFields)', async () => {
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    const { likeCount, commentCount, imagePaths, ...withoutShape } = validPostData();
    await assertFails(setDoc(doc(db, 'posts', 'post_new_1'), withoutShape));
  });

  it('5. create with 5000-character text is refused (the validator\'s 2000 bound is server-side too)', async () => {
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(
      setDoc(doc(db, 'posts', 'post_new_1'), validPostData({ text: 'x'.repeat(5000) })),
    );
  });

  it('6. create with ten images is refused (max four, fixed by the compose grid and the storage budget)', async () => {
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    const urls = Array.from({ length: 10 }, (_, i) => `https://cdn.example.test/${i}.jpg`);
    await assertFails(
      setDoc(doc(db, 'posts', 'post_new_1'), validPostData({ imageUrls: urls, imagePaths: urls })),
    );
  });

  it('7. create with more imagePaths than imageUrls is refused (the pair invariant is enforced, not just advised)', async () => {
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(
      setDoc(
        doc(db, 'posts', 'post_new_1'),
        validPostData({
          imageUrls: ['https://cdn.example.test/a.jpg'],
          imagePaths: ['a/1.jpg', 'a/2.jpg', 'a/3.jpg'],
        }),
      ),
    );
  });

  it('8. create with pre-filled counters is refused (both counters must start at zero)', async () => {
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(
      setDoc(doc(db, 'posts', 'post_new_1'), validPostData({ likeCount: 999, commentCount: 42 })),
    );
  });

  it('9. create with a client-stamped createdAt is refused (the feed is ordered by the server clock only)', async () => {
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(
      setDoc(
        doc(db, 'posts', 'post_new_1'),
        validPostData({ createdAt: new Date('2020-01-01T00:00:00Z') }),
      ),
    );
  });

  it('10. create carrying donationRecordId is refused: the key is not in the canonical schema', async () => {
    await seedConfirmedDonation();
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(
      setDoc(doc(db, 'posts', 'post_new_1'), validPostData({ donationRecordId: FEED.history })),
    );
  });

  it('11. create carrying a donationRecordId that is not the writer\'s confirmed record fails', async () => {
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(
      setDoc(doc(db, 'posts', 'post_new_1'), validPostData({ donationRecordId: 'hist_ghost' })),
    );
  });
});

describe('Stage 8.1 posts — update discovery', () => {
  it('12. an author text edit that restamps updatedAt succeeds; a bare text write does not', async () => {
    await seedPost();
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    // An edit that leaves updatedAt behind would keep the post at its publish
    // position forever; the rules refuse it so clients must restamp.
    await assertFails(updateDoc(doc(db, 'posts', FEED.post), { text: 'Edited once.' }));
    await assertSucceeds(
      updateDoc(doc(db, 'posts', FEED.post), {
        text: 'Edited once.',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('13. the stale singular imageUrl allow-list is gone: image-list edits work, oversized ones do not', async () => {
    await seedPost();
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'posts', FEED.post), {
        imageUrls: ['https://cdn.example.test/a.jpg'],
        imagePaths: ['a/1.jpg'],
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'posts', FEED.post), {
        imageUrls: Array.from({ length: 5 }, (_, i) => `https://cdn.example.test/${i}.jpg`),
        imagePaths: Array.from({ length: 5 }, (_, i) => `a/${i}.jpg`),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('14. the any-signed-in-user likeCount +-1 branch is closed: a stranger cannot move the counter at all', async () => {
    await seedPost({ likeCount: 3 });
    const db = testEnv.authenticatedContext(FEED.stranger).firestore();
    await assertFails(updateDoc(doc(db, 'posts', FEED.post), { likeCount: 4 }));
    await assertFails(updateDoc(doc(db, 'posts', FEED.post), { likeCount: 2 }));
  });

  it('15. the author cannot move the counters either: they are immutable on update until a paired like write exists', async () => {
    await seedPost({ likeCount: 3 });
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(updateDoc(doc(db, 'posts', FEED.post), { likeCount: 4, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db, 'posts', FEED.post), { commentCount: 1, updatedAt: serverTimestamp() }));
  });

  it('16. a non-author cannot edit text', async () => {
    await seedPost();
    const db = testEnv.authenticatedContext(FEED.stranger).firestore();
    await assertFails(updateDoc(doc(db, 'posts', FEED.post), { text: 'Not mine.' }));
  });
});

describe('Stage 8.1 comments — discovery', () => {
  it('17. a comment carrying only authorUid is refused; the full five-field shape is accepted', async () => {
    await seedPost();
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(
      setDoc(doc(db, 'posts', FEED.post, 'comments', FEED.comment), {
        authorUid: FEED.author,
      }),
    );
    await assertSucceeds(
      setDoc(doc(db, 'posts', FEED.post, 'comments', FEED.comment), {
        authorUid: FEED.author,
        authorName: 'Donor One',
        text: 'Congratulations on the fifth.',
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('18. a 5000-character comment is refused (the validator bound of 500 is server-side too)', async () => {
    await seedPost();
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(
      setDoc(doc(db, 'posts', FEED.post, 'comments', FEED.comment), {
        authorUid: FEED.author,
        authorName: 'Donor One',
        text: 'x'.repeat(5000),
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('19. a comment on a post that does not exist is refused (the parent must exist)', async () => {
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(
      setDoc(doc(db, 'posts', 'post_ghost', 'comments', FEED.comment), {
        authorUid: FEED.author,
        authorName: 'Donor One',
        text: 'Reply to nothing.',
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('20. comment author can delete, a stranger cannot', async () => {
    await seedPost();
    const payload = {
      authorUid: FEED.author,
      authorName: 'Donor One',
      text: 'Nice.',
      createdAt: serverTimestamp(),
    };
    const authorDb = testEnv.authenticatedContext(FEED.author).firestore();
    await assertSucceeds(
      setDoc(doc(authorDb, 'posts', FEED.post, 'comments', FEED.comment), payload),
    );
    const strangerDb = testEnv.authenticatedContext(FEED.stranger).firestore();
    await assertFails(
      deleteDoc(doc(strangerDb, 'posts', FEED.post, 'comments', FEED.comment)),
    );
    await assertSucceeds(
      deleteDoc(doc(authorDb, 'posts', FEED.post, 'comments', FEED.comment)),
    );
  });
});

describe('Stage 8.1 likes — canonical subcollection', () => {
  it('21. the flat post_likes collection is denied; posts/{id}/likes/{uid} is the only like shape', async () => {
    await seedPost();
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertFails(
      setDoc(doc(db, 'post_likes', 'like_anything'), { userId: FEED.author }),
    );
    await assertSucceeds(
      setDoc(doc(db, 'posts', FEED.post, 'likes', FEED.author), { likedAt: serverTimestamp() }),
    );
    // A like cast in another user's name — their uid as the document id —
    // is impossible by construction.
    await assertFails(
      setDoc(doc(db, 'posts', FEED.post, 'likes', FEED.stranger), { likedAt: serverTimestamp() }),
    );
  });

  it('22. the same user cannot like the same post twice: the duplicate id is an update, and updates are closed', async () => {
    await seedPost();
    const db = testEnv.authenticatedContext(FEED.author).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'posts', FEED.post, 'likes', FEED.author), { likedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(db, 'posts', FEED.post, 'likes', FEED.author), { likedAt: serverTimestamp() }),
    );
  });

  it('23. only the liker can delete their like document', async () => {
    await seedPost();
    const authorDb = testEnv.authenticatedContext(FEED.author).firestore();
    await assertSucceeds(
      setDoc(doc(authorDb, 'posts', FEED.post, 'likes', FEED.author), { likedAt: serverTimestamp() }),
    );
    const strangerDb = testEnv.authenticatedContext(FEED.stranger).firestore();
    await assertFails(deleteDoc(doc(strangerDb, 'posts', FEED.post, 'likes', FEED.author)));
    await assertSucceeds(deleteDoc(doc(authorDb, 'posts', FEED.post, 'likes', FEED.author)));
  });
});

describe('Stage 8.1 reports — create-only, mirrored from the Report entity', () => {
  const reportPayload = () => ({
    reporterUid: FEED.stranger,
    target: 'post',
    targetId: FEED.post,
    targetAuthorUid: FEED.author,
    reason: 'spam',
    note: 'Repeated reposts.',
    createdAt: serverTimestamp(),
  });

  it('24. a well-shaped report is accepted once; reads, edits and deletes are closed to clients', async () => {
    const db = testEnv.authenticatedContext(FEED.stranger).firestore();
    await assertSucceeds(setDoc(doc(db, 'reports', FEED.report), reportPayload()));
    await assertFails(getDoc(doc(db, 'reports', FEED.report)));
    await assertFails(updateDoc(doc(db, 'reports', FEED.report), { note: 'edited' }));
    await assertFails(deleteDoc(doc(db, 'reports', FEED.report)));

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(unauthDb, 'reports', FEED.report2), reportPayload()));
  });

  it('25. an unknown reason, a forged reporter or an oversized note is refused', async () => {
    const db = testEnv.authenticatedContext(FEED.stranger).firestore();
    await assertFails(
      setDoc(doc(db, 'reports', 'report_bad_1'), { ...reportPayload(), reason: 'dislike' }),
    );
    await assertFails(
      setDoc(doc(db, 'reports', 'report_bad_2'), { ...reportPayload(), reporterUid: FEED.author }),
    );
    await assertFails(
      setDoc(doc(db, 'reports', 'report_bad_3'), { ...reportPayload(), note: 'x'.repeat(301) }),
    );
  });
});
