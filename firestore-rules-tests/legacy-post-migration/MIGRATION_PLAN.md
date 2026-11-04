# Legacy-post migration plan (Stage 9.4) — PREPARED, NOT EXECUTED

**Status:** designed, implemented as pure + emulator-tested code, and **deliberately
NOT run against production.** Deploying or executing any of this against the live
project `sholovvo-blood-donation` requires the owner's explicit sign-off (see
`docs/PROJECT_STATE.md`, Stage 9.3 "Deploy decision"). Nothing in this folder talks to
a live project by itself; the only database `applyMigration` is ever pointed at is the
emulator.

## 1. Why this migration exists

The Stage 9.3 read-only production audit (`../production-audit/REPORT.md`) censused the
`posts` collection at **20 live documents**: **19** written in a pre-feed schema and **1**
already in the Stage 9.2 schema. The reconciled `firestore.rules` (working tree, uncommitted)
tightened the create/update key set to the modern shape only. Consequences of that tightening,
per the audit:

* **Reads are unaffected.** The `posts` read rule is unconditional for a signed-in user, so
  legacy documents keep rendering in every installed app.
* **Writes from an old build break.** A legacy client that re-submits its own pre-Stage-8
  body (`authorEmail` + singular `imageUrl`, no `imageUrls`/`imagePaths`/`commentCount`/
  `updatedAt`) is refused by `hasOnly` / `hasAll` / `isPostBody`. This is a refused *write*,
  never data loss and never a security hole.
* Whether such a build is still installed **cannot be determined offline** — that is an owner
  impact check. Normalising the 19 documents forward removes the hazard **without weakening
  the rule**, so the rule never has to be loosened to keep old posts editable.

This plan is the safe path the audit pointed to: *"A normalising migration (`imageUrl` →
`imageUrls`/`imagePaths`, drop `authorEmail`) removes the hazard without weakening the rule."*

## 2. Before / after schema

The nine required modern keys are exactly the `hasAll` set of the reconciled create rule
(`firestore.rules`, posts create ~L246–L330):

```
authorUid, authorName, text, imageUrls, imagePaths, likeCount, commentCount, createdAt, updatedAt
```

**Before** (audited legacy shape — 19 documents):

```jsonc
{
  "authorUid":   "uid_ayesha",
  "authorName":  "Ayesha Rahman",
  "authorEmail": "ayesha@example.com",     // legacy: PII snapshot, no longer stored
  "text":        "Donated at Dhaka Medical today.",
  "imageUrl":    "https://cdn/post-1.jpg", // legacy singular; may be null
  "likeCount":   3,
  "createdAt":   1729000000000
  // no imageUrls, no imagePaths, no commentCount, no updatedAt
}
```

**After** (modern shape the create rule accepts):

```jsonc
{
  "authorUid":    "uid_ayesha",
  "authorName":   "Ayesha Rahman",
  "text":         "Donated at Dhaka Medical today.",
  "imageUrls":    ["https://cdn/post-1.jpg"], // folded up from the singular imageUrl
  "imagePaths":   [],                          // legacy schema had no storage paths
  "likeCount":    3,                           // preserved verbatim
  "commentCount": 0,                           // legacy predated the comment counter
  "createdAt":    1729000000000,               // preserved verbatim, NEVER overwritten
  "updatedAt":    1729000000000                // derived from createdAt when absent
  // optional authorPhotoUrl / editedAt are carried through when present and well-typed
}
```

## 3. Exact field transformations (`normalizePost`)

Every rule is implemented in `migration.js` and pinned by `migration.test.js`:

| Field | Rule |
| --- | --- |
| `authorUid`, `text` | copied verbatim (their presence is what makes a document *readable*) |
| `authorName` | copied verbatim; degraded to `""` only if it was never a string |
| `imageUrls` | existing array wins (`.slice()`); else a non-empty singular `imageUrl` becomes `[imageUrl]`; else `[]` |
| `imagePaths` | existing array wins; else `[]` (the legacy schema stored no storage path) |
| `likeCount`, `commentCount` | preserved when a number; a missing counter defaults to `0` |
| `createdAt` | preserved when present; **only** a document that never had one falls back to `now` |
| `updatedAt` | preserved; else derived from `createdAt`; else `now` |
| `authorEmail`, `imageUrl`, `donationRecordId` | **dropped** — the modern schema has no place for them (the pre-Stage-9.2 donation-record branch is gone) |
| `authorPhotoUrl`, `editedAt` | passed through untouched when present |

`now` is **injected**, never read from a device clock, so the function is pure and the test
pins the exact value. In a real run the caller passes the server `Timestamp`/`serverTimestamp()`.

A document that is not recognisably a post (no `authorUid`, or no non-empty `text`) is
classified **`unreadable`** and the migration **refuses to touch it** — it is reported for a
human to inspect rather than guessed into a body.

## 4. Idempotency

`normalizePost` of an already-modern document returns an equal document (asserted in
`migration.test.js` → *"is idempotent"*). `classifyPost` therefore tags a normalised post as
`modern`, so `planMigration` puts it in `noops` and a **second pass plans zero writes**
(asserted end-to-end in `migration_emulator.test.js` → *"is idempotent: running the plan a
second time migrates nothing"*). A re-run is safe: it cannot double-apply, reset a counter,
or re-stamp a timestamp.

Note `classifyPost` also tags a modern-looking document that still carries a stale
`authorEmail` as **`legacy`**, so a rewrite cleans the leftover key — which is exactly what a
naive merge-write would leave behind.

## 5. Backup and rollback procedure

`planMigration` returns, **before any write happens**:

```
{ migrations: [{ id, before, after }], noops: [id], unreadable: [id], backups: [{ id, before }] }
```

* `backups` is a **verbatim copy of the original shape** of every document the run will
  rewrite (not the normalised one) — rollback fidelity.
* `applyMigration(db, plan, deps, backup)` calls `backup(id, before)` for every document
  **immediately before** its `setDoc`, so a caller can persist the whole rollback set to a
  cold bucket / a `posts_backup_<runid>` collection / a local JSONL before the first write.

**Rollback** = replay the backup set with the same full-replace `setDoc(doc(db,'posts',id),
before)`. Because the migration only ever rewrites documents it first backed up, and never
deletes a document, rollback restores the exact pre-run state of the touched subset.
Unreadable documents were never written, so they need no rollback.

The write is a **full `setDoc` replace, not a merge** — deliberate, because normalisation
*removes* `authorEmail`/`imageUrl`/`donationRecordId`, and a merge would leave them on the
document.

## 6. Installed-app-version compatibility and deploy ordering

The migration is a **prerequisite safety step, not a follow-up.** Recommended ordering:

1. **(Optional but recommended) Run the migration on production first** while the *currently
   deployed* rules are still in place. The deployed rules read legacy posts fine and the
   Admin/service-account write bypasses them, so normalising before the rule change costs
   nothing and removes the write-break window entirely.
2. **Then deploy the reconciled `firestore.rules`.** With documents already modern, no client
   (old or new) is caught mid-transition on a write.

   — *or, if the owner prefers rules-first:* the rule tightening only refuses a **write** from
   an old build; reads keep working throughout, and the migration can run immediately after.
   The residual risk is an old build failing to edit its own legacy post in the gap between
   rule deploy and migration, which is why migration-first is preferred.
3. The owner must still **confirm the installed base** (or force-upgrade) — the audit flags
   this as unanswerable offline. This migration makes the *data* compatible; it does not, and
   cannot, decide the *client* support question.

`post_likes` (42 rows) is **out of scope here** — its safe path (copy to
`posts/{id}/likes/{uid}`, then close the read) is a separate Stage-10 like-migration, tracked
in the audit. This plan touches only `posts`.

## 7. Emulator test evidence

* `migration.test.js` — **pure**, no emulator (`node --test
  firestore-rules-tests/legacy-post-migration/migration.test.js`): classification, every field
  transform, idempotency, plan split, verbatim backup, full-replace-not-merge write, backup-sink
  contract.
* `migration_emulator.test.js` — **emulator only**, run under `firebase emulators:exec
  --only firestore --project demo-solovvo-tests`: seeds legacy/modern/junk fixtures, runs
  plan→apply→re-read, and asserts (a) a legacy post becomes the modern shape with legacy keys
  gone, (b) a second pass plans nothing, (c) an already-modern post is byte-for-byte untouched
  (its `commentCount`/`imagePaths` preserved), (d) an unreadable document is recorded and never
  rewritten, (e) a tolerated optional field (`authorPhotoUrl`) and an existing `likeCount`
  survive a rewrite.

The emulator cycle runs with **security rules disabled** (`withSecurityRulesDisabled`) because
the rewrite is a privileged maintenance operation — a normalised legacy post keeps a non-zero
`likeCount` and a historical `createdAt` that the create rule would otherwise refuse, and a full
`setDoc` replace is not the narrow author-only update the rule permits. This mirrors how a
production run executes: with a service-account/admin credential, not a client.

## 8. Production-safety guarantees in the code

* No live endpoint: `applyMigration` only ever receives a `db` the caller hands it; the only
  caller in this repo passes the emulator (`demo-solovvo-tests`). There is no project id, no
  credential, and no default connection to `sholovvo-blood-donation` anywhere in this folder.
* No deletes: the migration only `setDoc`s documents it first backed up.
* No invention: unreadable documents and missing private fields are never fabricated; a
  dropped `authorEmail` survives verbatim in the plan's own backup.
* No rule changes: this folder does not modify `firestore.rules`.

Reproduce the emulator run (from the repo root):

```
firebase emulators:exec --only firestore --project demo-solovvo-tests ^
  "npm --prefix firestore-rules-tests test"
```
