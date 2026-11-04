# Blood-Request Contact-PII Split Migration — Plan (Stage 9.5 M3-C3)

**Status: PREPARED, NOT EXECUTED.** This document describes a migration that has
been written and tested against the Firestore *emulator* only. It has **not**
been run against the production project (`sholovvo-blood-donation`) and MUST NOT
be without the owner's explicit authorisation. No production writes, reads of
production data, deployments or billing changes are implied or performed by this
stage.

## 1. Why this migration exists

Stage 9.5 (M3, corrected in M3-C1) moved three patient-identifying fields off the
public `blood_requests/{id}` document and into
`blood_requests/{id}/private/contact`:

- `patientName`
- `phoneNumber`
- `hospitalAddress`

The Firestore rules now **refuse** those keys on the public document's create and
update paths. **But rules cannot filter fields on READ.** Every request document
written before M3 still carries the PII inline, and the public document is
governed by `allow read: if request.auth != null` — so any signed-in account can
still read a historical patient's name, phone and street address. Tightening the
rules does not hide data that is already stored; it only stops new leaks. The
leak on historical documents is physically closed **only** by copying the PII
into the gated child and then deleting it from the public parent.

## 2. Exact fields to copy

For each `blood_requests/{id}` document, `extractContact` builds the child
`blood_requests/{id}/private/contact` with exactly the three keys:

| Key               | Source                          | Missing / wrong-type fallback |
| ----------------- | ------------------------------- | ----------------------------- |
| `patientName`     | public `patientName` (string)   | `''` (flagged `incomplete`)   |
| `phoneNumber`     | public `phoneNumber` (string)   | `''` (flagged `incomplete`)   |
| `hospitalAddress` | public `hospitalAddress` (string) | `''` (address may be empty) |

The public parent is then **field-deleted** on only those of the three keys it
actually carried (`deleteField()` per present key). No other public field
(`userId`, `hospitalName`, `bloodGroup`, `bloodBags`, `requiredDateTime`,
`status`, `latitude`, `longitude`, `createdAt`, assignment/timestamp fields, …) is
touched, so an in-flight request keeps its identity, status and life-cycle through
the move.

## 3. Backup strategy

`planMigration` captures, for every request it will rewrite, a `backup` entry
`{ id, before }` holding the **verbatim pre-write public document** (still
carrying the PII). The backup is taken from the same read the plan is built from,
so it is guaranteed to be the pre-write state. `applyMigration` hands each
`before` to a caller-supplied `backup(id, before)` sink before writing, so the
operator persists a rollback set **outside** the migration module (e.g. a dated
JSON export in a restricted bucket) — the migration itself never assumes where
backups live.

## 4. Idempotency

The migration is idempotent **by construction**:

- A document is only planned when it still carries at least one PII key
  (`classifyRequest === 'legacy'`). After a successful pass the public document
  has none, so it reclassifies as `modern` and produces no migration.
- The child write is a fixed-id `setDoc` at `private/contact`, so a re-run (e.g.
  after a crash between the child write and the parent delete) overwrites the
  child with identical values rather than duplicating it.
- The parent delete is `deleteField()` per key — deleting an already-absent key is
  a no-op.

A second pass is therefore a proven no-op (see `migration_emulator.test.js`,
*"is idempotent"*).

## 5. Verification before removing the old fields (read-before-delete)

`applyMigration` never deletes the public PII before the copy is confirmed. Per
document the order is fixed and is the safety property:

1. `backup(id, before)`
2. `setDoc(private/contact, contact)`
3. **if a `getDoc` is injected:** `getDoc(private/contact)` and require
   `exists()` — if the child did not land, the run records `verify-failed` and
   **skips the delete**, leaving the public document exactly as it was. Nothing
   is ever readable-but-erased.
4. only then `updateDoc(public, { <present PII keys>: deleteField() })`

`verifyContactMigrated(publicData, contactData)` is the pure assertion used in a
final reporting sweep: it is `ok` only when the child holds all three keys and the
parent holds none.

## 6. Rollback strategy

`rollbackMigration(db, backups, deps)` is the mechanical inverse of a successful
migration: for each backup it restores the original public document (a full
`setDoc` of `before`, PII included) and `deleteDoc`s the `private/contact` child.

**Rollback re-exposes the PII on the public document** until the request is
re-migrated, so it is intended only for a controlled undo of a bad batch, not for
selective use. It has no "safety" of its own — restoring a public document that
still carries the phone re-opens the leak — and that asymmetry is deliberate: the
migration moves data *toward* protection, and rolling back moves it *away*.

## 7. Emulator tests (the only place this is ever executed)

- `migration.test.js` — pure contract, **no emulator**: classification, extract /
  normalize, plan split, `incomplete` flagging, `verifyContactMigrated`, and the
  **write-ordering guarantee** (contact `set` → verify `get` → public `update`)
  asserted against a fake Firestore, including the "verify-failed must not delete"
  path.
- `migration_emulator.test.js` — full round-trip against `demo-solovvo-tests`
  under `firebase emulators:exec`, writing under `withSecurityRulesDisabled` (as a
  production run would with a service account) and then verifying **through the
  real deployed rules** that: the migrated public document no longer exposes any
  PII to a stranger; the `private/contact` child is readable by the owner and
  permission-denied to a stranger; a second pass is a no-op; a partial (phone-only)
  legacy document still migrates and clears; and rollback restores and removes the
  child.

Run locally (emulator must be up; from `firestore-rules-tests/`):

```
firebase emulators:exec --only firestore --project demo-solovvo-tests "npm test"
```

`npm test` (`node --test`) discovers both the main rules suite and this folder's
`*.test.js` files.

## 8. Dry-run / reporting strategy

`planMigration` is a **pure dry-run**: given the current documents it returns the
full split — `migrations`, `noops`, `unreadable`, `incomplete`, `backups` —
without writing anything. The recommended production procedure is:

1. Read every `blood_requests` document (a service-account `getDocs`).
2. `planMigration(documents)` → **report**: counts by bucket, and the `incomplete`
   ids (contacts that will land with a blank name/phone) for human review.
3. Persist `plan.backups` to the restricted rollback store.
4. Review the report; if acceptable, `applyMigration(db, plan, deps, backupSink)`
   with `getDoc` injected so every document is verified read-before-delete.
5. Re-read and run a `verifyContactMigrated` sweep; report any `verify-failed`.
6. Only after the sweep is clean, deploy / confirm the public create rule that
   forbids the PII keys (already landed in this stage).

No step above is executed by this stage. Steps 1–6 are a plan and a rehearsal.

## 9. Known limits the owner must decide on

- **Subcollection reads of `blood_requests` are not otherwise used yet**: nothing
  in the Dart app writes or reads `private/contact` today (the requests screen is
  read-only against the public projection). Building the Stage-10 contact write /
  read path is a separate decision; this migration only relocates existing data.
- **`incomplete` contacts** (historical documents with a blank name or phone) move
  as-is with empty strings. They are reported, not repaired — inventing a phone
  number is out of scope.
- **A `getAfter()`/transaction nuance**: the child is created with a plain
  `setDoc` (rules-disabled admin), not a transaction, so a public create and its
  contact are not atomic across the migration. This is acceptable because the
  migration rewrites existing documents, not creates; ordering safety is provided
  by the read-before-delete check, not by a batch.
