# Supabase Storage: profile photos and post photographs

Everything in this folder is **delivery material**. None of it has been applied,
nothing in the repository runs it, and no bucket or policy in this document has
ever been executed. The one honest qualification: the workspace now carries
Supabase CLI local state under `supabase/.temp/` (gitignored, untracked, never
read into a build), which is evidence that a project has been *linked* from this
machine at some point. That is not the same as the SQL below being applied, and
no project reference, URL or key is quoted here. Until someone runs the two SQL
files and uploads a real byte, treat every statement in this folder as unapplied.
The app is built to work without it: when the build carries no
Supabase defines, the photo sheet says *"Photo upload is not set up in this
build yet."*, the compose screen says the same about photographs, and neither
offers a control that could only fail.

- `supabase-avatars.sql` — the `avatars` bucket and its two storage policies (Stage 6).
- `supabase-community-posts.sql` — the **`community-posts`** bucket and its two storage
  policies (Stage 6 / feed image upload). This is the owner-authoritative feed
  bucket; `SupabaseConfig.defaultPostImagesBucket` now targets it, and the app
  must not be pointed back at `post-images`, which would orphan the images
  already uploaded there.
- `supabase-post-images.sql` — the earlier `post-images` design (Stage 8.3).
  **Superseded for new uploads** by `supabase-community-posts.sql`; retained for
  history and for the case where a build overrides the bucket via
  `SUPABASE_POST_IMAGES_BUCKET`.
- This file — the order of operations, how to verify, and what is still unproven.

Both buckets belong in **one** Supabase project, because both depend on the same
Firebase third-party auth integration. Step 2 below is the shared prerequisite;
steps 3a and 3b are the two SQL files.

## What the app does — profile photo

| Step | Where | Effect |
| --- | --- | --- |
| Pick | `ImagePickerPhotoPicker` | Gallery or camera, downscaled to 1024 px at quality 85, EXIF/GPS dropped (`requestFullMetadata: false`) |
| Check | `PhotoValidator` | 5 MB cap, and the format is decided by magic bytes (JPEG/PNG/WebP), never by the file name |
| Upload | `SupabasePhotoStorage.uploadAvatar` | `POST` to `avatars/{firebaseUid}/avatar-{millis}.{ext}` with the donor's **Firebase ID token** as the bearer |
| Publish | `ProfileRepository.setPhotoUrl` | One-field merge of `users/{uid}.photoUrl` — only after the upload answered with a URL |
| Compensate | `SupabasePhotoStorage.removeAvatar` | If the profile write fails, the object just uploaded is deleted again; the donor's previous photo is never touched |
| Remove | `ProfileController` + `ProfilePhotoController.remove` | Profile field cleared first (public card stops showing a photo), then the object is deleted best-effort |

Two ordering rules are the whole design and are covered by tests:

- **Replacement:** upload → publish → (on publish failure) delete the new object.
  A failed replacement leaves the profile exactly as it was.
- **Removal:** clear the field → delete the object. The worst case is an orphaned
  object nobody links to, never a profile pointing at a missing file.

## What the app does — post photographs

| Step | Where | Effect |
| --- | --- | --- |
| Pick | `ImagePickerPhotoPicker` | The same adapter and the same 1024 px / quality 85 downscale as the avatar sheet |
| Check | `PhotoValidator` | Same 5 MB cap, same magic-byte format sniffing, plus `PostValidator`'s four-image ceiling for the draft as a whole |
| Upload | `SupabasePostImageStorage.upload` | `POST` to `community-posts/{firebaseUid}/post-{millis}-{n}.{ext}` with the donor's **Firebase ID token** as the bearer |
| Remove one | `ComposeController.removeImage` | The image leaves the draft immediately, then the object is deleted best-effort by **path** (`Post.imagePaths` is stored beside the URLs so nothing has to parse a URL) |
| Publish | `FirestorePostRepository.publish` | One `posts` document create, after the text and the images have already been validated |
| Abandon | `ComposeController.discard` | Every object the draft uploaded is deleted, because no document will ever own them |

Two rules differ from the avatar flow and are covered by tests:

- **Upload on pick, not on publish.** Four photographs in one request means one
  opaque failure and no way to tell which file is stuck; uploading immediately
  gives each photo its own outcome while the text stays editable.
- **The draft owns its objects until a document does.** A publish that fails
  leaves the photos in place so a retry is one tap; a draft that is thrown away
  takes its objects with it.

## Order of operations

### 1. A Supabase project

Create one (or reuse an existing one that is not used for anything else at this
stage). One bucket holding 5 MB-capped avatars fits comfortably inside the free
tier; nothing here needs a paid add-on. Note the **project URL** and the
**publishable (anon) key** from *Project Settings → API*.

Do **not** copy the `service_role` / `sb_secret_…` key anywhere near this app.
The client refuses to use such a key at all — `SupabaseConfig.rejectPrivilegedKey`
drops it and the app reports itself as unconfigured — but the guardrail exists to
catch a mistake, not to make one safe.

### 2. Let Supabase verify Firebase tokens

The app authenticates with **Firebase** and has no Supabase user. For
`auth.jwt()` to carry anything in a storage policy, the Supabase project must be
told to trust the Firebase project:

*Authentication → Sign In / Providers → Third-party auth → Firebase*, add the
Firebase project id:

```
sholovvo-blood-donation
```

Dashboard wording moves between Supabase releases; the setting is the one that
lets a project accept JWTs issued by an external identity provider. If your plan
or project does not offer it, **stop here and report it** — the alternative
(minting a `role: authenticated` claim with a Firebase blocking function, or
moving to Supabase Auth) changes the authentication model and needs your
decision. No workaround for this has been implemented.

### 3a. Apply the avatars SQL

Paste `supabase-avatars.sql` into *SQL Editor* and run it. It creates:

- bucket `avatars`: public read, 5 MB, `image/jpeg`, `image/png`, `image/webp`
- an **insert** policy and a **delete** policy on `storage.objects`, both gated on
  `iss` + `aud` + `sub == first path segment`
- no update policy, no select policy, nothing on any other bucket

`public = true` is intentional: profile photos are shown on the donor card other
donors see. It also means the image URL needs no Authorization header, which is
what `Image.network` can actually send. Never store anything private in this
bucket.

### 3b. Apply the post images SQL

Paste `supabase-community-posts.sql` into the same project and run it. It creates:

- bucket `community-posts` if absent (public read, 5 MB, `image/jpeg`,
  `image/png`, `image/webp`) — the `insert` is `on conflict do nothing`, so an
  existing bucket is left alone rather than dropped
- the same two ownership policies with `bucket_id = 'community-posts'` in place
  of `'avatars'`
- no update policy (a photograph is never overwritten), no select policy

**Verify the existing layout first, read-only.** `community-posts` already holds
images from an earlier build. Those are served over the public route and keep
rendering regardless of these policies (reads do not touch RLS), but the file
includes a `split_part` query to confirm the current folder shape so the insert
predicate matches the app's `{uid}/post-...` writes. Do not loosen a predicate to
reach foreign/legacy objects, and do not drop the bucket to "fix" an upload — that
empties it and destroys the images this bucket exists to preserve.

Skipping this step is safe and visible: the compose screen keeps working and
reports that photographs are not set up, so a text-only post can still be
published.

### 4. Build the app with the defines

```
flutter run -d chrome ^
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

The same two defines apply to `flutter build apk` / `flutter build web`. Only
`https://` URLs are accepted (an `http` endpoint would put the bearer token on
the wire in clear text), and a malformed URL or a missing key simply means "not
configured".

### 5. Verify

1. Sign in, open **Profile**, tap **Add photo**, choose an image.
2. In *Storage → avatars* the object should be `{firebaseUid}/avatar-{millis}.jpg`;
   the donor card shows the photo and `users/{uid}.photoUrl` holds the public URL.
3. **Change photo** again: a second object appears, the profile points at the
   newer one, and the older object is left in place (nothing links to it — see
   limitations).
4. **Remove photo**: confirm, the card falls back to initials, `photoUrl` is
   cleared, and the object is gone.
5. Negative test — the policy, not the client, must refuse a foreign folder.
   With a signed-in donor's ID token and a path belonging to someone else:

   ```
   curl -i -X POST "$SUPABASE_URL/storage/v1/object/avatars/<other-uid>/x.jpg" ^
     -H "apikey: $SUPABASE_ANON_KEY" ^
     -H "Authorization: Bearer $FIREBASE_ID_TOKEN" ^
     -H "Content-Type: image/jpeg" ^
     --data-binary "@photo.jpg"
   ```

   Expected: `403` with `new row violates row-level security policy`. The same
   call to the donor's own folder with a token-less request must also fail.
6. Post photographs: on the dashboard, open **From the community** (any of its
   controls lead to the same page), tap **Share an update**, attach two photos,
   then publish. In *Storage → community-posts* two objects should appear under
   `{firebaseUid}/`, and the feed should show the new post at the top after the
   snapshot confirms it. Attach a third photo and abandon the draft: a
   confirmation appears, and after it the objects should be gone again.

   (An earlier revision of this step said the Feed was unreachable from normal
   navigation and that this check therefore needed a temporary route. That was
   wrong on both counts — the dashboard's *From the community* section reads the
   feed's own controller on mount and every control in it opens `FeedScreen`,
   whose labelled **Share an update** button pushes `ComposePostScreen`. The gap
   this note described was closed with that navigation, not worked around.)

   What the dashboard still does not have is a destination for one post — there
   is no per-post screen, so it is not exercisable here. Neither is a request row:
   since Stage 9.1 the dashboard's **Open requests** section and the screen behind
   **See all** read the real `blood_requests` window, but a row goes nowhere until
   Stage 10, and no row is tappable in the meantime. **A date correction to this
   note:** when it was written, nearby requests were not wired at all; they are now,
   read-only, and nothing about them touches Supabase Storage — the requests read is
   Firestore-only and cannot be used to check any policy in this file.

### 6. What each failure looks like in the app

| Supabase answer | Message |
| --- | --- |
| `401`, `Invalid JWT`, `jwt expired` | the auth sentence — sign in again |
| `403`, `row-level security`, `insufficient privilege` | the permission sentence — check step 2 and the path |
| `413`, `maximum allowed size` | the same "choose a photo under 5 MB" the client shows |
| `415`, `mime type … not supported` | "choose a JPEG, PNG or WebP image" |
| `429` | the rate-limit sentence |
| `5xx`, socket, timeout | the network sentence |

## Known limitations (read before the Security stage)

1. **No live verification yet.** No upload, download or delete has been
   exercised against real storage from this repository, and neither SQL file has
   ever been executed. All storage behaviour is covered by unit and widget tests
   against fakes. The gitignored `supabase/.temp/` CLI state (see the top of this
   file) shows a project has been linked from this machine, but linking is not
   applying: whether buckets or policies exist remotely, and whether the Firebase
   third-party-auth setting has been turned on, is **not verifiable from here**
   and has not been checked.
2. **Firebase tokens arrive as the `anon` role.** Supabase has no `role` claim to
   read, so the policies carry the whole burden: `iss`, `aud` and
   `sub == (storage.foldername(name))[1]`. Anything that weakens those three
   predicates weakens ownership for everyone.
3. **The bucket is public-read.** The URL of a photo is not a secret and can be
   shared or cached for a year (`Cache-Control: max-age=31536000`, which is safe
   only because every upload gets a fresh path). Deleted objects may stay visible
   from a CDN edge for a while.
4. **Orphans are possible.** If the compensating delete fails (offline right after
   a failed profile write), an object remains with nothing pointing at it, and
   replacing a photo always leaves the previous object behind. Cleaning those up
   needs a scheduled job — a paid feature on both providers — or a manual query,
   so nothing does it yet.
5. **Validation is enforced in two places, neither of them image analysis.** The
   bucket checks size and mime type, the client checks magic bytes; neither
   re-encodes the image, so a hostile but well-formed JPEG is stored as-is.
6. **The photo outlives the account.** Deleting a Firebase user does not delete
   their objects; only the app's own removal path does.
7. **Firestore is untouched.** `photoUrl` is a plain string field on
   `users/{uid}`; the current rules still do not validate its shape. That is the
   same gap Stage 5 listed for the future Security stage, and it was not changed
   here — rules were neither edited nor deployed.
8. **Post images have the same two gaps, one per record.** `posts.imageUrls` and
   `posts.imagePaths` are arrays of strings the rules do not inspect, and the
   feed reads them on the assumption that a corrupt entry fails to load rather
   than taking the screen with it. Deleting a post does not delete its
   photographs, because the feed has no delete yet.

## Cleaning up orphaned post photographs

Limitation 4 above describes the problem: a post deleted before the client fix
left its photographs in `community-posts` with nothing pointing at them. The
application now removes a post's own photos on delete, so no *new* orphans are
created — but the objects already sitting in the bucket are outside that code
path and need a one-off sweep.

`cleanup-orphan-post-images.mjs` (this folder) does that sweep. It reads every
live `posts` document, collects the `imagePaths` they still reference, lists
every object in the bucket, and reports the difference. It is **dry-run by
default** and deletes nothing until you pass `--execute`.

Because the truth lives in two systems, the script bridges both and therefore
needs **owner credentials** the donor-facing app never has — a Supabase
`service_role` / `sb_secret_…` key (to list and delete across every donor
folder) and a Firebase service-account JSON (to read `posts`). Both come from
the environment; nothing is read from the repo and no key is ever printed.

```powershell
cd docs/storage
npm install

$env:SUPABASE_URL           = "https://<project-ref>.supabase.co"
$env:SUPABASE_SERVICE_KEY   = "<service_role / sb_secret_… key>"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
$env:FIREBASE_PROJECT_ID    = "sholovvo-blood-donation"

node cleanup-orphan-post-images.mjs              # report only — safe
node cleanup-orphan-post-images.mjs --execute    # delete the orphans
```

Two guards are deliberate: a `posts` read that returns **0 documents** aborts
immediately (a wrong project id would otherwise flag the entire bucket as
orphaned and delete every real photo), and `--execute` deletes in batches so an
interrupted run can simply be re-run — already-deleted objects come back as
absent. This script is owner tooling; it is not wired into the app or any build.

## Rolling back

Only to remove the feature entirely (not to make an upload work):

```sql
drop policy if exists "post-images: donor uploads into their own folder" on storage.objects;
drop policy if exists "post-images: donor deletes from their own folder" on storage.objects;
delete from storage.buckets where id = 'post-images'; -- empties the bucket as well

drop policy if exists "avatars: donor uploads into their own folder" on storage.objects;
drop policy if exists "avatars: donor deletes from their own folder" on storage.objects;
delete from storage.buckets where id = 'avatars'; -- empties the bucket as well
```

Then build without the two defines: the sheet reports "not set up" again.
