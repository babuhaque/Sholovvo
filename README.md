# Solovvo

Blood donation and social networking platform for Android and iOS.

**Save Lives • Connect Hearts**

## Status

Stage 6 of 14 complete (approved) — the app runs in Bangla and English,
in light and dark, remembers both choices, a signed-in donor lands on a responsive
home dashboard, can maintain their own profile with a split between what others
may read and what only they can, and can add, change or remove a profile photo
through Supabase Storage. See
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
not follow a theme switch. Stage 6 has widget renders only
([`docs/visuals/stage6/`](docs/visuals/stage6)): there is no Supabase project, so
there is no live upload to photograph, and the widget renderer cannot load
`Image.network` (the avatar shows its initials fallback there).

## Home dashboard

`lib/features/home` is a three-layer feature: `domain` view models, `application`
provider seams, `presentation` widgets. The donor strip in
`application/home_providers.dart` projects the signed-in donor's real profile and
donation history (Stage 5); nearby requests and the feed preview are still **empty
on purpose** — the collections behind them are read in Stage 9 and, for the feed,
in a later stage that has not been scheduled. Each seam
is replaced by the stage that owns its data; the layout renders both the empty and
the populated path already, so nothing in `presentation` has to change when data
arrives. Nothing on this screen is a placeholder number.

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
