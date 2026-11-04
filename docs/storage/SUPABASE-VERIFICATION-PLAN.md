# Supabase Storage — authenticated-upload verification plan (Stage 9.4)

**Status: a plan only. Nothing here has been executed, against production or against a
test bucket, and no object has been uploaded, listed, overwritten or deleted.** This file
identifies precisely *what is required* to verify that an authenticated image upload works,
using a dedicated test identity and a synthetic object, while respecting every production-
and privacy-safety restriction.

## 0. What is already true, and what is explicitly NOT claimed

From the Stage 9.3 audit (`../firestore-rules-tests/production-audit/REPORT.md`) and the
delivery material in `README.md` + the two SQL files, the honest baseline is:

* **Only reachability is known.** `GET /storage/v1/object/list/post-images` answered
  **HTTP 400**. That tells us the host resolves, the bucket path is on the storage API, and
  the request was rejected before doing any work. **HTTP 400 does NOT prove authenticated
  Storage access** — it is not a 200, it carried no valid third-party JWT subject binding,
  and it exercised no row-level-security policy. Reaching an endpoint and being *authorised*
  by it are different facts, and only the second one matters here. This plan exists to
  establish the second fact honestly.
* **Nothing has ever been applied.** Neither `supabase-avatars.sql` nor
  `supabase-post-images.sql` has been run; no bucket or policy is known to exist remotely.
  The workspace carries Supabase CLI link state under `supabase/.temp/` (gitignored,
  untracked, never read into a build) — evidence a project was *linked from this machine*,
  not that any policy was created.
* **No credential is in the tree and none will be added.** `SUPABASE_URL` and
  `SUPABASE_ANON_KEY` are compile-time `--dart-define`s (`lib/core/config/supabase_config.dart`
  `SupabaseConfig.fromEnvironment`); the key is absent from the repository by design. The
  service-role / `sb_secret_…` key is *refused at load* by `rejectPrivilegedKey`, and
  `SupabaseConfig.toString` deliberately never prints the key.

## 1. The mechanism being verified (read from the code, not assumed)

`SupabasePhotoStorage` / `SupabasePostImageStorage`:

1. read the signed-in Firebase user's **ID token** (`_auth.currentUser`), freshly, per
   operation — no Supabase Auth session is ever created and no Supabase user exists;
2. build a short-lived `StorageClient` for `storageUrl` (`https://<ref>.supabase.co/storage/v1`)
   carrying **only the publishable key** as `apikey` and the Firebase ID token as the
   `Authorization: Bearer …`;
3. `POST` the bytes to `<bucket>/<uid>/avatar-<millis>.<ext>` (or
   `post-images/<uid>/post-<millis>-<n>.<ext>`), so the object's **first path folder is the
   caller's own uid**;
4. the storage policy independently requires `iss` + `aud` + `sub == (storage.foldername(name))[1]`,
   so **ownership is enforced server-side**, never by this Dart file.

A correct verification therefore has to observe, at minimum, a real authenticated `POST`
that the **policy accepts for the owner's own folder and rejects for a foreign folder**.
Nothing short of that distinguishes "endpoint reachable" from "authenticated upload works".

## 2. Hard prerequisites that must be confirmed FIRST (owner / dashboard actions)

These cannot be checked from the repository and gate everything below:

1. **A Supabase project is chosen for testing.** Preferred: a **dedicated throwaway test
   project**, not `qiipuczhgacwrysyndij`, so no real user's objects are ever in scope. If
   the shared project must be used, testing is confined to a **single synthetic object under a
   dedicated test uid's folder** and nothing else (§4).
2. **Firebase third-party auth is enabled** on that project (*Authentication → Third-party
   auth → Firebase*, project id `sholovvo-blood-donation`). Without it, `auth.jwt()` carries
   no `sub`, the policy predicate can never be satisfied, and every upload returns 403 for a
   reason unrelated to the client. If the plan/project does not offer this setting, **stop and
   report it** (see `README.md` §2) — it changes the auth model and needs an owner decision.
3. **The two SQL files are applied to that test project** (buckets + insert/delete policies),
   so there is a policy to satisfy at all. Applying them to the *production* project is out of
   scope for this verification and forbidden without owner sign-off.

## 3. The safe identity and the safe object

* **Identity:** a **dedicated throwaway Firebase test account** created solely for this
  verification. Its uid is the only folder any object is written under. Never sign in as a
  real donor, and never address a path whose first segment is not this test uid.
* **Object:** a **locally generated synthetic image** (a 1×1 PNG/JPEG made on the machine),
  not a photo from any user's device or gallery. Size/format are chosen to sit inside the
  policy bounds (≤ 5 MB, `image/*`) so a success proves the auth path, not to probe limits.
* **Teardown:** the test uploads, then deletes, **only its own** object (the delete policy is
  exercised by the app's own `removeAvatar` path against the same test uid). No other object
  is touched; deleting the test's own object is authorised by being the test's own folder.

## 4. The verification procedure (once §2 gates are green)

Supplied at build/run time from a secret manager, never committed and never echoed:
`SUPABASE_URL`, `SUPABASE_ANON_KEY` (publishable), and the test account's sign-in.

1. **Configure check** — boot the app with the two defines and assert
   `SupabaseConfig.isConfigured == true` and `rejection == null`. (A `service_role`/`sb_secret_`
   key must make this *false*; that guardrail is already unit-tested in
   `test/core/supabase_config_test.dart`.)
2. **Positive — owner upload.** Sign in as the test uid, upload the synthetic image to
   `avatars/<test-uid>/…`. Expected: HTTP **200**, the object appears under *Storage → avatars*
   in exactly that folder, and `getPublicUrl` returns a URL that fetches without an
   `Authorization` header (public-read bucket). This is the step HTTP 400 never proved.
3. **Negative — foreign folder.** With the *same* test token, attempt a `POST` to
   `avatars/<someone-else>/x.jpg` (curl form in `README.md` §5.5). Expected: **403** with
   `row-level security`. This proves the policy, not the client, is what gates ownership.
4. **Negative — no token.** The own-folder upload again with the bearer removed. Expected:
   auth rejection. Together 3+4 pin that both the key *and* the identity bind are required.
5. **Post-image flow** — repeat 2–4 against `post-images/<test-uid>/post-…` so the Stage 8.3
   bucket and its separate policies are each actually exercised.
6. **Delete** — remove the test's own object via the app path; confirm it is gone (and, per
   `README.md` limitation 3, may linger on a CDN edge — that is expected, not a failure).
7. **Failure mapping** — optionally drive a few wrong shapes the client guards against (over
   5 MB → 413, non-image → 415) to confirm `mapStorageErrorToFailure` surfaces the right
   sentence; none of these writes a lasting object.

Every one of these is a **write/read against a dedicated test project or a dedicated test
folder only**. If a real project or a real user's folder would be in scope, the step does not
run.

## 5. What would and would not count as proof

* **Counts as proof:** step 2 returning 200 **and** the object being visible in the intended
  owner folder **and** steps 3–4 returning 403/auth-fail. Ownership enforcement is verified
  only by the *contrast* between the accepted own-folder write and the refused foreign write.
* **Does NOT count as proof:** any `GET /object/list/...` reachability (including the HTTP 400
  already seen); a 200 obtained with a `service_role` key (that bypasses RLS and verifies the
  opposite of what we mean); a success against the owner's folder *without* the matching
  foreign-folder refusal (a missing policy would look identical to a working one). Recording a
  green client-side upload test that runs against a fake does not verify real Storage either —
  the existing `test/features/profile/supabase_photo_storage_test.dart` and
  `test/features/feed/supabase_post_image_storage_test.dart` are fake-backed and stay green
  regardless of the remote project.

## 6. Constraints this plan honours

* No production/user object is uploaded, overwritten or deleted — only a dedicated test
  identity's own synthetic object, and only after §2 gates are confirmed.
* No credential, publishable key, ID token or `service_role` secret is committed, printed, or
  logged; `SupabaseConfig` already refuses privileged keys and already redacts the key in
  `toString`.
* HTTP 400 reachability is never presented as authenticated Storage access.
* No paid feature is required: the flow fits the free tier, and orphan cleanup (a scheduled
  job) is explicitly out of scope (`README.md` limitation 4).

## 7. Open blocker (owner decision)

This verification cannot run from the repository as-is: it needs (a) a chosen **test**
project (or explicit authorisation to use the shared one within a single test folder), (b) the
**Firebase third-party-auth** setting confirmed on that project, and (c) the SQL **applied** to
that project. All three are dashboard actions outside this codebase and outside the
read-only-from-here convention. Until they are satisfied, the honest status is: *upload path
implemented, unit/widget-tested against fakes, real authenticated access unverified.*
Reconciling that is Stage 10 / Security work, gated on the owner.
