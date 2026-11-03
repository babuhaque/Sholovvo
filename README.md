# Solovvo

Blood donation and social networking platform for Android and iOS.

**Save Lives • Connect Hearts**

## Status

Stage 8.2 complete (awaiting approval). **Stage 8 is the social feed**, and 8.2
makes it **readable**: a paged, pull-to-refresh `FeedScreen` over one Firestore
query on `posts`, with the dashboard's community **See all** as the route in.
Nothing in the feed can be written — no post, like, comment, save, report or
upload — and no rule, index or backend setting was changed. Stage 8.1 laid the
foundations (`Post`, `Comment` and `Report` entities, a pure `Post` document
mapper, shared photo primitives in `core/media`, one avatar and one blood-group
badge instead of two of each), and 8.1.1 aligned the schema documents with the
rules. Everything through Stage 7 still
stands: the app runs in Bangla and English, in light and dark, remembers both
choices, and a signed-in donor lands in a two-tab shell: a responsive home
dashboard and their own profile, with a settings page (account, appearance,
about, sign out) pushed above them. They can maintain their profile with a split
between what others may read and what only they can, and can add, change or
remove a profile photo through Supabase Storage. See
[`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) for the stage tracker and
per-stage verification results.

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

Profile photo upload needs two more defines, and works without them by saying so:

```bash
flutter run ^
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

`https` only; an `sb_secret_…` key or a service-role JWT is refused at runtime
rather than used. The bucket, the policies and the Firebase→Supabase
authentication step are in [`docs/storage/README.md`](docs/storage/README.md) and
have **not** been applied.

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
[`docs/visuals/stage8/`](docs/visuals/stage8)): Stage 6 has no Supabase project,
so there is no live upload to photograph, and the temporary browser entrypoint
used in Stage 3 was not recreated for any of them. The Stage 8 set covers the
feed populated in light English and dark Bangla, at the wide measure with
pictures, empty, and after a failed read.

## Home dashboard

`lib/features/home` is a three-layer feature: `domain` view models, `application`
provider seams, `presentation` widgets. The donor strip in
`application/home_providers.dart` projects the signed-in donor's real profile and
donation history (Stage 5); nearby requests and the feed preview are still **empty
on purpose** — the collections behind them are read in Stage 9 and, for the feed,
by the full `FeedScreen` that Stage 8.2 added. Each seam
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
back from, not a place you live.

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
entities and one mapper — and **8.2** adds the read path: one screen, one
repository, one provider, one query. Nothing in the feed can be created, edited,
deleted, liked, saved, commented on, reported or uploaded to; there is no sample
data in production code, and `firestore.rules` was not touched in either stage.

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
two-tab shell, reached from the dashboard's community **See all**. It reads ten
posts at a time:

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
  reads to confirm the schema has drifted.
- **No composite index is needed.** One collection, one `orderBy`, no `where`:
  Firestore serves that from its automatic single-field index. There is no
  `firestore.indexes.json` in this repository and this stage did not add one.
- **The read is permitted by the rules as they stand.**
  `allow read: if request.auth != null` on `/posts/{postId}` has no field
  condition, so it covers a list query for a signed-in caller.

`firestore.rules` was **not touched by Stage 8.1, 8.1.1 or 8.2**, but it is not
empty on the feed: it already has a `posts` block, a nested `comments` block and
a top-level `post_likes` block. Those rules predate the feed design and are **not
approved** for it — they allow updating a singular `imageUrl` where the mapper
writes `imageUrls` and `imagePaths`, they keep likes at `post_likes/{likeId}`
instead of under a post, they permit a `donationRecordId` the entity does not
model, and no branch lets `commentCount` change. The Feed schema has **not** been
reconciled with them, and `reports` has **no rule at all**. That is why this
stage only reads: every write would land on a rule nobody has approved.
Reconciliation is a later, separately approved stage. See
`docs/ARCHITECTURE.md` §14.1 and §14.2.

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
