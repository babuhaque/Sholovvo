# Stage 9.3 — Production Firestore compatibility audit (read-only)

Executed 4 November 2026 against the live project `sholovvo-blood-donation`
(project number 419478547476). Nothing was written, deleted, or deployed. The
Admin/REST calls used the already-authenticated Firebase CLI user credential
(the same token `firebase apps:list` uses); that API bypasses security rules,
so it can *see* exactly what the rules protect and can never forge or mutate a
document. Reproduce any row with:

```
node firestore-rules-tests/production-audit/probe.mjs <command> [args]
  collections | schema <coll> [n] | subcollection <c> <id> <sub> | subs <c> <id>
```

## Live collections (top-level)

`blood_requests, donors, notifications, post_likes, posts, request_responses, requests, users`

## Shape census vs the reconciled rules

| Collection | Live docs | Dominant live shape | Read under working-tree rules | Client create under working-tree rules |
| --- | --- | --- | --- | --- |
| posts | 20 | 19 legacy: `authorEmail, authorName, authorUid, createdAt, imageUrl(str/null), likeCount, text`; 1 modern (9-field set) | ✅ `auth != null` (unchanged) | modern app ✅; **legacy-shape create rejected** (missing required keys, `hasOnly` excludes `authorEmail`/singular `imageUrl`, `isPostBody` needs `imageUrls`) |
| posts/{id}/comments | 3 (on one post) | `authorName, authorUid, createdAt, postId, text` | ✅ | current app ✅; legacy `postId` field not in `hasOnly` |
| post_likes | **42** | `createdAt, postId, userId` | ✅ **read preserved (Stage 9.3)**; writes denied | n/a (deprecated collection) |
| blood_requests | 11 | 14-key open-request shape, no `assignedDonorId` | ✅ | ✅ exact production shape passes `hasOnly`; `assignedDonorId`/pre-set status rejected (pinned by the new client tests) |
| request_responses | 8 | `bloodGroup, createdAt, donorId, donorName, donorPhone, requestId, status` | donor/owner ✅ | donor + matching bloodGroup ✅ (pre-9.2 rules, untouched) |
| notifications | 8 | `body, createdAt, isRead, recipientUid, requestId, title, type` | recipient ✅ | owner/relationship ✅ |
| users | 3 | profile shape (+ role/isAvailable) | ✅ | self-only ✅ |
| **donors** | **5** | `bloodGroup, createdAt, isAvailable, location(latlng), name, phone` (+ email/uid on 3) | **was deny-all (NO rule) — Stage 9.3 adds signed-in read + owner write** | owner-keyed, shape-checked (new) |
| **requests** (legacy) | **5** | `bags, bloodGroup, createdAt, hospital, patientName, phone, reason, status` (+ location/uid on 1) | **deny-all — no rule, pre-9.2, not touched** | stranded legacy emergency model |

## Compatibility verdict

1. **`post_likes` (42 live rows).** Stage 9.2 set `allow read, write: if false`,
   which would have **orphaned the 42 documents and broken any installed client
   still counting likes** — production allows reading them today. Stage 9.3
   refined the rule to `read: auth != null; write: false`: strictly tighter than
   what is deployed (writes fully closed), no looser on reads, nothing stranded.
   The read flips closed only after a migration copies the rows to
   `posts/{id}/likes/{uid}`.
2. **Legacy posts (19 of 20).** Reads are unaffected. The create/update shape
   tightening rejects only clients still writing the pre-Stage-8 schema
   (`authorEmail` + singular `imageUrl`). Consequence is a refused *write* for an
   old build, never data loss or a security hole. Whether such a build is still
   installed cannot be determined offline → §10 impact check is unanswerable
   here → the owner must confirm the installed base (or force-upgrade) before
   this part ships. A normalising migration (`imageUrl` → `imageUrls/imagePaths`,
   drop `authorEmail`) removes the hazard without weakening the rule.
3. **`donors`.** Deny-all before this stage, so donor discovery could never read
   it. Stage 9.3 opens read to signed-in users (the directory feature) — a real
   privacy widening (name + phone become visible to every authenticated user)
   that is **flagged for owner approval, not assumed**.
4. **`requests` (legacy).** No rule exists; already deny-all and stranded. Not
   touched by 9.2 or 9.3; left as-is and recorded.

## Deploy decision

**DO NOT DEPLOY the working-tree `firestore.rules` yet.** Blockers: (a) the
legacy-post create break against an unverifiable installed base (§2 above);
(b) the `donors` read-widening is a privacy decision reserved to the owner;
(c) the Firebase Rules API is **not enabled for this project** (the Admin
`datasets/links` call returns an HTML enable page), so the currently-deployed
ruleset source cannot even be fetched to diff before pushing. Each is listed
with its safe migration path in `docs/PROJECT_STATE.md`, Stage 9.3.

Recovery artefact (pre-reconciliation rules): `git show eb1b5e4:firestore.rules`.
Stage 9.2 committed file: HEAD `c5faf7f`. Stage 9.3 changes: uncommitted working
tree.

## Verification

Rules suite **106/106** under the emulator (96 baseline + 10 new
blood_requests/donors client-context tests). `flutter analyze` clean.
`flutter test` 851 passed / 63 skipped / 0 failed. `git diff --check` clean.

Supabase (project `qiipuczhgacwrysyndij`): `GET /storage/v1/object/list/post-images`
returned **HTTP 400 (reachable, auth-gated)** — endpoint and bucket path resolve.
An authenticated read/write was **not** performed: the publishable key is
`--dart-define` only (absent from the tree by design) and any object write would
be a destructive/foreign action forbidden by the read-only convention.
