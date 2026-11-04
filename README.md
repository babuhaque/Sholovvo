# Solovvo

Blood donation and social networking platform for Android and iOS.

**Save Lives • Connect Hearts**

## Status

Stage 8.3 **implemented — hardening in progress**, five hardening steps done. **Stage 8
is the social feed**, and the feed now both reads and writes: a paged `FeedScreen` over
one Firestore
query on `posts`, and a composer that publishes a text-plus-photographs post
through `FirestorePostRepository` and uploads its images to a `post-images`
Supabase bucket. Nothing else can be done to a post — no like, comment, save,
report, edit, delete or share — and no rule, index, bucket or backend setting was
changed or deployed.

Four things are true at once and belong in any resume-from-these-notes brief, so
they are stated here rather than only in `docs/PROJECT_STATE.md`:

- **The stage is implemented and the suite is green, and neither of those means
  signed off.** `flutter analyze` reports no issues and `flutter test` reports 733
  passed, 58 skipped, **0 failed**, measured on the tree that carries the Step 3,
  Step 4 and Step 5 hardening. The one red test the recovery audit found was a
  test-synchronisation defect in the composer's own suite, fixed test-side on
  2026-11-03 with no change to any production code: the test now waits until the
  storage upload has actually started before asserting the uploading state. By this
  project's gate a stage is only *done* when both commands pass, so the gate is met
  for today's tree — while the rules still check nothing about a post, and no
  approval record exists for Stage 7, 8.2 or 8.3.
- **The feed is reachable, and the two blockers that made it unreachable are
  closed.** `FeedScreen` opens from the dashboard whether or not the community has
  posts: the community section previews the feed's own controller, **See all**
  appears when there is something to see, and a section with nothing to preview
  carries an **Open the community** button instead. A page whose documents are all
  unreadable no longer strands a donor on an empty screen — the controller walks
  past up to five such pages, and **Load more** stays on screen for as long as the
  collection has more in it. The composer sits behind that screen, so the read
  path, the composer and the upload can now all be opened.
- **The composer is tested where it is used.** Alongside its 64 logic tests,
  `ComposePostScreen` and `compose_image_grid` have 74 widget tests, and the
  visual-review harness has a `compose` group of eleven captures. Those captures
  were taken and pass, but they are written to `build/review/`, which is
  gitignored: `docs/visuals/stage8/` still holds only the five read-path renders,
  so the composer has a review pass and no committed picture of itself.
- **What a feed cannot read now says so, and a draft cannot be lost mid-upload.**
  Step 5 (Stage 8.4) changed no data path and no rule. `FeedPage.skipped` — the count
  of documents the mapper refused — reaches both screens: the feed draws one honest
  line above its working **Load more**, and the dashboard's community section has a
  fifth state that says the feed could not be fully read instead of claiming *"No
  posts yet"* over a collection that is merely unreadable. `ComposeController.discard()`
  now takes the same `_busy` guard `addImage` and `publish` take and returns whether it
  actually discarded, so the form stays open while a photograph is still going up
  instead of throwing away a draft its upload is about to orphan. Three photographs
  that a screen reader announced as nothing now name whose they are, and
  `FeedPostTile` has 13 tests that mount the tile itself rather than the whole feed.

Stage 8.1 laid the foundations (`Post`, `Comment` and `Report` entities, a pure
`Post` document mapper, shared photo primitives in `core/media`, one avatar and
one blood-group badge instead of two of each), 8.1.1 aligned the schema documents
with the rules, and 8.2 delivered the read path. Everything through Stage 7 still
stands: the app runs in Bangla and English, in light and dark, remembers both
choices, and a signed-in donor lands in a two-tab shell: a responsive home
dashboard and their own profile, with a settings page (account, appearance,
about, sign out) pushed above them. They can maintain their profile with a split
between what others may read and what only they can, and can add, change or
remove a profile photo through Supabase Storage. See
[`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) for the stage tracker, the
Stage 8.3 hardening list and per-stage verification results.

## Stack

| Concern | Choice |
| --- | --- |
| Client | Flutter / Dart |
| Auth | Firebase Authentication |
| Database | Cloud Firestore (Spark plan, rules-enforced) |
| Push | Firebase Cloud Messaging — deferred, see limitations |
| Images | Supabase Storage |
| Maps | flutter_map + OpenStreetMap |
| Location | geolocator |
| State | Riverpod |
| Languages | Bangla + English, `gen_l10n` / ARB |
| Theming | Light + dark + system, `ThemeExtension` role palette |
| Preferences | shared_preferences (device-local) |

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — layering, state management,
  theming and languages, security model, backend constraints, medical-domain rules.
- [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) — stage tracker and verified
  results per stage.
- [`docs/storage/`](docs/storage) — the Supabase bucket and storage policies for
  profile photos, and the order of operations to apply them. **Delivered, not
  applied.**
- [`docs/visuals/`](docs/visuals) — rendered screens per stage.

## Getting started

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=APP_FLAVOR=development
```

Flavours are compile-time (`--dart-define=APP_FLAVOR=development|staging|production`).
An unflagged build always resolves to `development`.

Photo storage needs two more defines, and works without them by saying so. The
same two cover both buckets — the profile avatar (Stage 6) and post photographs
(Stage 8.3):

```bash
flutter run ^
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

`https` only; an `sb_secret_…` key or a service-role JWT is refused at runtime
rather than used. The two buckets, the four storage policies and the
Firebase→Supabase authentication step are in
[`docs/storage/README.md`](docs/storage/README.md) and have **not** been applied
from this repository — so unless the owner has applied them by hand, supplying the
defines only gets a request to a bucket that is not there. The code and the
delivery material are both finished; **live verification is neither**.

Translations are generated, not hand-written Dart: `flutter gen-l10n` (or any
build, `generate: true` is set) turns `lib/l10n/app_en.arb` and `app_bn.arb` into
`lib/l10n/generated/`. To add copy, add the key to **both** ARB files, then use
`context.l10n.<key>`. A key that exists only in English is reported in
`lib/l10n/untranslated.json` and fails `test/l10n/arb_parity_test.dart`.

The Firebase project is `sholovvo-blood-donation`, already registered for
Android, iOS and web via FlutterFire.

Screenshot set for a design review (skipped by default, writes PNGs to
`build/review/`):

```powershell
$env:SOLOVVO_VISUAL_REVIEW=1; flutter test test/review/visual_review_test.dart
```

The same states captured from the built web app in a real browser live in
[`docs/visuals/stage3-browser/`](docs/visuals/stage3-browser),
[`docs/visuals/stage4-browser/`](docs/visuals/stage4-browser) and
[`docs/visuals/stage5-browser/`](docs/visuals/stage5-browser) — that is the pass
that catches things a widget render cannot, such as a sheet background that does
not follow a theme switch. Stages 6, 7 and 8 have widget renders only
([`docs/visuals/stage6/`](docs/visuals/stage6),
[`docs/visuals/stage7/`](docs/visuals/stage7),
[`docs/visuals/stage8/`](docs/visuals/stage8)): Stage 6 has no live upload to
photograph, and the temporary browser entrypoint used in Stage 3 was not recreated
for any of them. The Stage 8 set covers the feed populated in light English and
dark Bangla, at the wide measure with pictures, empty, and after a failed read.
**The composer has captures but no committed render:**
`test/review/visual_review_test.dart` has `feed` and `compose` groups, and the
eleven `compose` captures pass under `SOLOVVO_VISUAL_REVIEW=1` — but they land in
gitignored `build/review/`, so `docs/visuals/stage8/` has no picture of the form.
That is part of the Stage 8.3 verification gap recorded in `docs/PROJECT_STATE.md`.

## Home dashboard

`lib/features/home` is a three-layer feature: `domain` view models, `application`
provider seams, `presentation` widgets. The donor strip in
`application/home_providers.dart` projects the signed-in donor's real profile and
donation history (Stage 5), and the community preview
(`feedPreviewProvider`) is now a projection of the feed's own
`FeedController` — the newest three posts of the one page the feed has read,
not a second query on `posts`. Nearby requests are still **empty on purpose**:
the collection behind them is read in Stage 9. Each seam
is replaced by the stage that owns its data; the layout renders both the empty and
the populated path already, so nothing in `presentation` has to change when data
arrives. Nothing on this screen is a placeholder number.

## Navigation and settings

`lib/app/app_shell.dart` is the signed-in surface: an `IndexedStack` of two live
tabs under a `NavigationBar`, or beside a `NavigationRail` once the window is
720px wide. There are exactly two tabs because exactly two destinations exist; a
stage that adds a third destination adds one enum member and one destination, and
nothing else on the bar changes. The full feed (Stage 8.2) is a route pushed
above the shell for the same reason Settings is: it is a place you go to and come
back from, not a place you live. The dashboard's community section is the way in,
by **See all** when the preview has posts and by **Open the community** when it
does not, and the route pops back to the dashboard. Neither appears in
`AppRoutes`, which still carries only the three auth routes: pushed feature
screens own their own `route()` factory.

Settings (`lib/features/settings`) is pushed above the shell rather than being a
third tab: account (the session's own address, read-only), preferences (the same
appearance sheet Welcome and Home open, not a copy), about (brand and build
flavour), and **sign out** — which used to be the last control on the dashboard
and now lives here, where a mis-tap cannot cost a session. There is deliberately
no notification switch: nothing on Spark can deliver one, and a switch that
changes nothing is worse than no switch. Signing out pops back to the gate before
the gate swaps the session, because a pushed route survives the swap.

## Profile

`lib/features/profile` owns the signed-in donor's own profile and nothing else.
The repository has **no `uid` parameter**: every read and write is addressed from
`FirebaseAuth.currentUser`, and `firestore.rules` rejects anything else, so no
screen can be pointed at another person's document.

The data is split by who may read it, not by what is convenient to write
together:

| Document | Readable by | Holds |
| --- | --- | --- |
| `users/{uid}` | any signed-in account | display name, role, blood group, availability, photo URL, and the area *only* while the donor published it |
| `users/{uid}/private/profile` | the owner only | area (canonical), street address, phone, date of birth, gender, the publication flag |
| `donation_history/{id}` | the owning donor | read-only in this stage; written by the request flow in Stages 10/11 |

Turning "show my area" off writes `FieldValue.delete()` for the public copy, so the
value becomes unreadable rather than hidden behind a flag. Donation statistics
count **confirmed** records only; pending rows are listed and labelled. See
`docs/ARCHITECTURE.md` §12.

### Profile photos

`user_profile.photoUrl` is a public URL into the `avatars` bucket on Supabase
Storage; the image itself is addressed as `{firebaseUid}/avatar-{millis}.{ext}`
and the path is built by `SupabasePhotoStorage`, never by a caller. Uploads are
authorised by Storage RLS, not by a role: the request carries the donor's
**Firebase** ID token, and the policy proves the token's `iss`, its `aud`, and
that the first path segment equals its `sub` (§13).

Validation is by magic bytes and a 5 MB cap on the client, and by
`file_size_limit` / `allowed_mime_types` on the bucket. Ordering is the whole
design: a replacement uploads a new object and publishes its URL only after the
upload answered, deleting the new object again if the profile write fails, so a
failed change leaves the previous photo whole; a removal clears the field first
and then deletes the object, so the card can never point at a missing file.
Without the Supabase defines the sheet reports that upload is not set up and
offers nothing that could only fail.

## Feed

Stage 8 is the social feed. **8.1** added the foundations — three immutable
entities and one mapper — **8.2** added the read path (one screen, one repository,
one provider, one query), and **8.3** added the composer and post photographs: one
form, one write port, one storage adapter. A post can now be **created**, with up
to four photographs. It still cannot be edited, deleted, liked, saved, commented
on, reported or shared, and there is no sample data in production code.
`firestore.rules` was not touched by any of the three stages.

| Type | Holds | Refuses |
| --- | --- | --- |
| `Post` | author `uid`, name and photo, text, up to 4 image URLs and their storage paths, like/comment counts, three timestamps | blank text, text over 2 000 characters, more than 4 images, a negative counter |
| `Comment` | author `uid`, name and photo, text, an optional parent and the name being replied to | blank text, text over 500 characters, a reply with no parent |
| `Report` | reporter `uid`, target type and id, the target author, a reason, an optional note | a missing reporter, target or target author; a note over 300 characters |

Each rule is a validator returning an issue value, and `PostDocument` maps a
`Post` to and from a plain map in `data` — the only file in the feature that
touches `cloud_firestore`. A malformed document is refused with the issue that
names the field; nothing is quietly replaced with a default, and nothing a donor
wrote reaches a debug message.

The author's name and photo are a **snapshot from write time**, not a lookup per
card: one read per feed row instead of one per author is what keeps the feed
inside the Spark plan. The cost is that a renamed or re-photographed donor keeps
the old values on posts they already published. Phone, street address, area and
blood group are never copied into a post.

### Reading it

`FeedScreen` (`lib/features/feed/presentation`) is a pushed route above the
two-tab shell. The dashboard's community section is the only way in, and it is
always there: **See all** when the preview has a post in it, **Open the
community** on the empty card when it does not (see *Home dashboard* above). It
reads ten posts at a time:

```
posts
  .orderBy('createdAt', descending: true)
  .limit(11)                          // page size + 1, to answer hasMore exactly
  .startAfterDocument(lastSnapshot)   // every page after the first
```

- **A `DocumentSnapshot` cursor, not an offset.** A post published between two
  pages cannot shift the window, because the cursor addresses a document rather
  than a position. `SnapshotCursor` lives in `data`; the domain sees only an
  empty `FeedCursor` interface.
- **Eleven reads per page, at most.** The extra document answers `hasMore` and is
  never mapped or drawn. There is no realtime listener and no query that could
  return the whole collection; **Load more** is a button, so no scroll position
  spends a read the donor did not ask for.
- **One read at a time.** A second `loadMore`, or a pull-to-refresh landing on a
  page in flight, is refused rather than merged into the list. A failed load-more
  keeps the page and the cursor, so the retry re-asks the same question.
- **Counts are read, not fetched.** `likeCount` and `commentCount` come from the
  post document and are displayed read-only; no `posts/{id}/likes` or
  `posts/{id}/comments` subcollection is addressed anywhere.
- **A malformed post is dropped, not fatal.** It is counted in `FeedPage.skipped`
  so one bad document cannot empty the feed, and the count is what a debugger
  reads to confirm the schema has drifted. **And an empty page is not an empty
  feed:** `hasMore` is decided from the raw document count, so a page can carry no
  readable post and still have posts behind it. `FeedController` answers that by
  walking — it re-asks with the cursor the refused page returned, up to
  `maxEmptyPages` (five) times, and stops the moment a page has a post, the
  collection runs out, or the bound is reached. `FeedState.isEmptyResult` requires
  `!hasMore`, so the empty card — which would replace the footer holding **Load
  more** — only appears when there is genuinely nothing to page to. The cost is
  bounded and real: a capped walk is five reads, fifty documents scanned for one
  tap. See `docs/ARCHITECTURE.md` §14.2.
- **No composite index is needed.** One collection, one `orderBy`, no `where`:
  Firestore serves that from its automatic single-field index. There is no
  `firestore.indexes.json` in this repository and this stage did not add one.
- **The read is permitted by the rules as they stand.**
  `allow read: if request.auth != null` on `/posts/{postId}` has no field
  condition, so it covers a list query for a signed-in caller.

### Writing it

`ComposePostScreen` is pushed from the feed's own button. Two ports keep the write
testable without an app, in the same shape the read side earned:

| Port | Implemented by | Job |
| --- | --- | --- |
| `PostRepository` | `FirestorePostRepository` → `PostWriter` (`FirestorePostWriter`) | `publish(PostDraft) → Result<Post>`: one `set` on a pre-allocated id, `createdAt`/`updatedAt` as `FieldValue.serverTimestamp()` |
| `PostImageStorage` | `SupabasePostImageStorage` | `isConfigured`, `upload(ValidatedPhoto)`, `remove(objectPath)` against the `post-images` bucket |

- **The author's uid comes from the session, never from the form.** `PostDraft`
  carries no uid, because the create rule compares `authorUid` to
  `request.auth.uid`; a form that could choose the value could only produce denied
  writes. A donor with no profile document posts under `PostAuthor.unknown()`.
- **Validation happens before the network.** `PostDraft.issue` re-runs the same
  `PostValidator` the read mapper uses, so an unpublishable draft costs no quota.
- **Photographs upload on pick, not on publish,** so each file gets its own outcome
  while the text is still editable, and publish stays one small document write.
- **The object path is `{uid}/post-{millis}-{n}.{ext}`** — the sequence number keeps
  four photos picked in the same millisecond from overwriting each other, which is
  also why every URL is immutable and may be cached for a year.
- **Removal names the path, not the URL.** `Post.imagePaths` exists beside
  `Post.imageUrls` for exactly this, and `ownPath()` refuses any delete whose first
  segment is not the caller's uid — so a corrupt document cannot become a delete
  aimed at somebody else's photograph.
- **Abandoning a draft deletes its objects.** Confirming the discard prompt calls
  `ComposeController.discard()`, because otherwise every abandoned compose leaves up
  to four objects that nothing names. It refuses — and says so by returning `false`, so
  the screen keeps the form open — while anything is in flight, which is the same
  `_busy` guard the other two mutators have always had.
- **The published post is prepended to the feed** through `FeedController.prepend`
  rather than triggering a refresh the donor did not ask for; it is a no-op on a
  feed that has not loaded and dedupes by id.
- **With no `SUPABASE_*` defines there is no photo control,** only a sentence saying
  upload is not set up — and the text half of the form still publishes.

What the write path still does not have is **server-side enforcement** — see the
rules paragraph below. Its presentation layer is no longer untested:
`ComposePostScreen` and `compose_image_grid` have 74 widget tests over the same
fake ports, on top of the 64 that cover `ComposeController`,
`FirestorePostRepository` and `SupabasePostImageStorage`, and the visual-review
harness has a `compose` group. All 138 pass. Neither the bucket nor its policies
has been applied, so no photograph has ever been uploaded for real. See
`docs/PROJECT_STATE.md` (Stage 8.3) and `docs/ARCHITECTURE.md` §14.3 and §14.4.

One distinction the tests now pin, because it was ambiguous enough to break a test:
waiting for the donor to choose a file is **not** uploading. `ComposeState.isUploading`
covers the storage phase only — the add tile's spinner and `feedComposeUploading`
describe bytes on the wire — while the controller's private `_busy` guard covers the
whole pick-then-upload flow, including the window before any state has changed. A
refusal from the validator never sets the flag either, and a dedicated regression
test fails anyone who tries to hoist it above the picker.

`firestore.rules` was **not touched by Stage 8.1, 8.1.1, 8.2 or 8.3**, but it is not
empty on the feed: it already has a `posts` block, a nested `comments` block and
a top-level `post_likes` block. Those rules predate the feed design and are **not
approved** for it — they allow updating a singular `imageUrl` where the mapper
writes `imageUrls` and `imagePaths`, they keep likes at `post_likes/{likeId}`
instead of under a post, they permit a `donationRecordId` the entity does not
model, and no branch lets `commentCount` change. The Feed schema has **not** been
reconciled with them, and `reports` has **no rule at all**.

**This is now the project's main outstanding security gap, and 8.3 made it worse
by making it live.** While the feed only read, the mismatch was latent. A donor can
now create a post through a create rule that checks `authorUid` and nothing else:
no field set, no text length, no image count, no counter shape. What the client
guarantees is that *this* app writes the mapper's field set, validated first; what
the rules guarantee about *any other* client is nothing. `firestore-rules-tests/`
covers no feed collection at all. Reconciliation against §14.1 — a later, separately
approved stage — gates any deployment of the write path. See
`docs/ARCHITECTURE.md` §14.1, §14.2 and §14.3.

## Security rules

`firestore.rules` is deployed separately and is **not** part of the app bundle:

```bash
firebase deploy --only firestore:rules
```

Rules tests live in `firestore-rules-tests/` (`npm test`, requires the Firestore
emulator).

Never commit Firebase Admin service account keys or Supabase service role keys.
`.gitignore` blocks the common filename patterns; privileged operations must be
authorised by rules, never by a secret shipped in the app.
