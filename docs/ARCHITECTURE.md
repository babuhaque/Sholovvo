# Solovvo — Architecture

Blood donation and social networking platform. Flutter client, Firebase backend
on the **Spark (free) plan**, Supabase Storage for images.

This document is the contract every stage must respect. If a later stage needs to
break a rule here, the rule gets updated in the same change.

---

## 1. Layering

Feature-based Clean Architecture, four layers, enforced by import direction:

```
presentation  →  domain  ←  data
      ↓            ↑
            core
```

| Layer | May import | Must never import |
| --- | --- | --- |
| `presentation` | `domain`, `core` | `data`, `firebase_*`, `supabase_*` |
| `domain` | `core` | `data`, `presentation`, any SDK |
| `data` | `domain`, `core` | `presentation` |
| `core` | Flutter SDK, `core` | any feature |

Consequences that matter:

- A widget never sees a `DocumentSnapshot`. It sees domain models.
- A repository returns `Result<T>` carrying a `Failure`. It never throws SDK
  exceptions at the caller.
- Swapping Firestore for another backend is a `data`-layer change only.

## 2. Directory layout

```
lib/
  main.dart                     entry point; delegates to bootstrap()
  app/                          composition root: startup, root widget, router,
                                the appearance & language sheet
  core/                         cross-feature primitives, no feature knowledge
    brand/                      product identity constants
    config/                     AppConfig + appConfigProvider
    error/                      Failure hierarchy + exception mapping
    result/                     Result<T> sealed type
    logging/                    AppLogger
    firebase/                   Firebase initialisation + result type
    preferences/                persisted theme/language + their providers
  features/<feature>/
    domain/                     entities, repository interfaces, use cases
    data/                       DTOs, data sources, repository implementations
    presentation/               screens, widgets, controllers (providers)
  design/                       design system: tokens, primitives (Stage 1)
    tokens/app_palette.dart     semantic colour roles, one instance per theme
  l10n/                         ARB catalogues + generated AppLocalizations
```

A feature directory appears only when that feature is built. Empty scaffolding is
not created ahead of time, because it rots silently and misleads readers about
what is actually implemented.

**Implemented features:**

| Feature | Layers present | What exists |
| --- | --- | --- |
| `auth` | `domain`, `data`, `presentation`, `application` | `AuthUser`, `AuthRepository` interface, validators, `FirebaseAuthRepository`, error mapping, sign-in / register / reset / verification screens |
| `splash` | `presentation` | 2 s brand reveal, no navigation of its own |
| `welcome` | `presentation` | unauthenticated landing screen |
| `home` | `domain`, `application`, `presentation` | authenticated dashboard: donor status strip, the two headline actions, nearby requests and community preview; every data surface reads a provider seam that is empty until its own stage lands |
| `profile` | `domain`, `data`, `application`, `presentation` | the signed-in donor's own profile: `UserProfile`, `DonationRecord`, validators, `FirestoreProfileRepository` over two documents, the profile screen and its edit form |

## 3. State management

**Riverpod 3** (`flutter_riverpod`), chosen for: compile-time safe dependency
injection, no `BuildContext` requirement in providers (testable without widgets),
automatic disposal, and `ProviderScope` overrides that make fakes trivial in
tests.

Rejected alternatives:

- `provider` — no built-in async/loading modeling, weaker disposal guarantees.
- `bloc` — excellent for large teams with strict event auditing, but the event
  boilerplate is not worth it for a solo-maintained app of this size.

Rules:

- Providers live next to what they provide; cross-feature providers live in
  `domain` or `core`.
- Controllers are `Notifier` / `AsyncNotifier` (Riverpod 3 style). Legacy
  `StateNotifier` is not used.
- `ref.watch` only in `build`; `ref.read` only inside callbacks.
- **A screen whose data belongs to a later stage reads a seam, not a placeholder
  value.** `home` renders a donor snapshot, nearby requests and a feed preview
  from three providers in `features/home/application/home_providers.dart`. The
  donor snapshot is now a real projection over the signed-in donor's profile and
  donation history (Stage 5); nearby requests and the feed preview still return an
  empty list. The screen therefore has one "no data" path and one "has data" path
  from day one, and the stage that owns each collection replaces one provider
  instead of rebuilding the layout. A hard-coded sample row would have been
  indistinguishable from real data on a screenshot.

## 4. Result and Failure

`Result<T>` (`core/result/result.dart`) is a sealed type with `Success<T>` and
`FailureResult<T>`. `Failure` (`core/error/failure.dart`) carries a machine
readable `FailureCode`, never user-facing prose.

Why: the app ships in Bangla and English. If a repository returned
`"Invalid password"`, the Bangla UI would leak English. Instead the presentation
layer maps `FailureCode` → localised string from the ARB catalogue
(`features/auth/presentation/auth_messages.dart` is the one place that does it for
the auth feature).

`ValidationFailure` additionally carries `messageKey` and `field` so forms can
show inline, translated errors.

`AuthFailure` additionally carries an `AuthFailureReason`
(`invalidCredentials`, `emailAlreadyInUse`, `weakPassword`, `userDisabled`,
`requiresRecentLogin`, `operationNotAllowed`, `unknown`, …), because "wrong
password" and "this address already has an account" demand different UI while both
being `FailureCode.unauthorised`.

The mapper (`auth/data/auth_error_mapper.dart`) takes the Firebase **error code
string**, not the `FirebaseAuthException` — the exception's constructor is
protected, so accepting the exception would make the mapping untestable without
network or reflection.

Anti-enumeration is a hard rule: `wrong-password`, `user-not-found`,
`invalid-credential`, `invalid-login-credentials` and `invalid-email` all collapse
to one reason and one user-visible sentence, and a password reset for an unknown
address still reports success. Otherwise the sign-in form becomes an oracle for
which phone numbers or emails have accounts — a real safety problem for a
donor-matching app.

Field validation follows the same rule one level down: `AuthValidators` returns an
`AuthFieldIssue` (`emailInvalid`, `passwordTooShort`, `confirmMismatch`, …), never a
sentence. The form stores the issue it found, so an error already on screen
re-renders in the newly chosen language instead of staying in the language it was
validated in.

## 5. Theming and languages

Two independent axes, both user-controlled at runtime, both persisted:

| Axis | Values | Default |
| --- | --- | --- |
| Theme | `ThemeMode.system/light/dark` | `system` |
| Language | `en`, `bn` | `null` = follow the device |

**Colour is a set of semantic roles, not a palette of constants.** `SolovvoPalette`
is a `ThemeExtension` with named roles (`surface`, `surfaceMuted`, `textPrimary`,
`textSecondary`, `brandInk`, `brandTint`, `onBrandTint`, `outline`, `danger`, …) and
two instances, `light` and `dark`. Widgets read `context.palette.surface`, never
`AppColors.cream`; `AppColors` remains the raw brand ramp and is used only where a
value must be theme-invariant (the blood mark drawn on the brand disc).

Why a `ThemeExtension` rather than two `ThemeData`s with different constants:

- A role that is missing from one theme is a compile error, not a black rectangle
  found by eye in dark mode.
- Flutter interpolates extensions during the theme animation, so switching theme
  fades rather than flashes.
- `AppTheme.light` / `AppTheme.dark` stay declarative; nothing in a screen names a
  theme.

**Language.** `gen_l10n` with `lib/l10n/app_en.arb` + `app_bn.arb`, generated in
tree under `lib/l10n/generated` (`generate: true`, configured by `l10n.yaml`). No
screen contains a user-facing literal; `context.l10n.<key>` is the only way to
obtain copy, so a missing string is a compile error rather than an English word on
a Bengali screen.

Rules that follow from this:

- `untranslated-messages-file` is enabled and the file must stay `{}`. A key added
  to English without Bengali is a build warning and a red test, not a silent gap.
- Dates and framework strings come from `MaterialLocalizations`
  (`formatShortMonthDay`, `backButtonTooltip`), not `intl.DateFormat`, so no
  locale data has to be initialised before the first frame.
- The Bengali catalogue writes Bengali numerals (`৮`, not `8`) and keeps every
  `{placeholder}` the English sentence had; both are asserted by tests.
- **A number that reaches the screen is formatted by the catalogue, not by the
  widget.** A count placeholder declared with `"format": "decimalPattern"` is
  rendered through `NumberFormat` for the active locale, so `homeUnitsNeeded(2)`
  reads "2 units needed" in English and "২ ইউনিট দরকার" in Bengali without either
  widget knowing which. ICU plurals live in the catalogue too, because "1 units
  needed" is a copy bug, not a layout bug.
- Bengali glyphs come from the platform face (Noto Sans Bengali on Android,
  Kohinoor Bangla on iOS). No font is bundled; see the open items.

**Where the choices are read.** `SolovvoApp` is the only widget that touches
`themeModeProvider` and `localeProvider`; every screen below it sees only
`Theme.of(context)` and `context.l10n`. The switcher is one shared
`AppearanceSheet` (`lib/app/appearance_sheet.dart`) reachable from the welcome
screen — before sign-up, so a Bengali speaker is not pushed through an English
form — and from home. Stage 7 hosts the same widget inside Settings rather than
growing a second copy.

**Theme colours come from the theme, never from a captured context.** The rule
that matters when adding a sheet: `showModalBottomSheet` paints its own
background, and a `backgroundColor: context.palette.surface` argument is resolved
*once*, when the sheet opens. Anything colourful inside the sheet then follows a
later theme switch while the card behind it does not. Sheets, dialogs and drawers
take their surface from the relevant sub-theme in `AppTheme`
(`bottomSheetTheme`, `dialogTheme`, …), which is rebuilt per palette.

**Persistence** is `shared_preferences`, read once in `bootstrap()` before
`runApp`, so the first painted frame is already in the saved theme and language.
Stored values are enum *names*: renaming a constant is a compile error, whereas a
stored index would silently turn "dark" into "light" when the list changes.

## 6. Startup sequence

```
main() → bootstrap()
  WidgetsFlutterBinding.ensureInitialized()
  AppConfig.fromEnvironment()
  PreferencesStore.load()        → stored theme + language (synchronous reads after)
  initialiseFirebase()  →  FirebaseReady | FirebaseUnavailable
  runApp(ProviderScope(overrides: [appConfig, preferences, firebaseResult],
                       child: SolovvoApp()))
```

There is deliberately no "assume it worked" branch. If Firebase fails, the app
renders `FirebaseUnavailable` with the classified code, so a misconfigured
project is visible immediately instead of appearing as an empty list three
screens later.

### Session gate

Once Firebase is ready, `BootstrapGate` shows `AuthGate` (`lib/app/auth_gate.dart`),
and that widget — alone — decides which screen exists:

```
splash (2 s reveal, or while the stored session resolves)
   ├── no session            → WelcomeScreen
   ├── session, unverified   → VerifyEmailScreen
   └── session, verified     → HomeScreen
```

Consequences, all deliberate:

- **No screen navigates to a destination.** The four auth forms call
  `popUntil(route.isFirst)` on success and let the stream do the rest. Signing out,
  confirming an email, or a token revoking on the server all land the user in the
  right place without any screen knowing about any other.
- **The 2 s brand reveal always runs**, even when the session resolves from disk in
  20 ms, because the brief asks for it. The gate holds the splash rather than the
  splash holding the gate.
- **`AsyncValue.hasValue` is the branch discriminator, not a null check.** The
  payload is `AuthUser?`, so "signed out" and "not resolved yet" are only
  distinguishable that way; conflating them shows the welcome screen to a signed-in
  user for one frame.
- A stream error renders `AuthStreamErrorView` with a retry that invalidates
  `authStateProvider`. Silently downgrading a storage failure to "signed out" would
  hide a broken session.

The splash screen therefore has no `Navigator` dependency at all: it takes an
`onRevealComplete` callback.

## 7. Backend constraints (Spark plan)

These are real limitations, not implementation shortcuts.

| Capability | Spark plan | Consequence for this app |
| --- | --- | --- |
| Firestore reads/writes | Yes, daily free quota | Fine |
| Firebase Auth (email/password) | Yes | Fine |
| Cloud Functions | **No** (Blaze only) | No server-side business logic |
| FCM push to other users | **No** (needs Admin SDK in a trusted server) | Push deferred; see Stage 11 |
| Sending an SMS/email from the app | No | Never attempted client-side |

**Therefore, privileged operations are enforced by Firestore Security Rules,
not by a server.** The existing `firestore.rules` already implements the atomic
"first donor to accept wins" model using a `response_claims` document created in
the same transaction as the response. That is server-authoritative in the sense
that matters: the *client cannot bypass it*, because rules reject any write that
does not match the claimed state.

What this does **not** give us: true push notifications to a donor whose app is
closed. That needs either the Blaze plan (Cloud Functions) or an external
backend holding a service account key. Deferred with the user's agreement; the
in-app notification feed and Firestore realtime listeners are built first, so
the UI does not depend on FCM existing.

## 8. Security model

- Never ship privileged credentials in the bundle: no Firebase Admin service
  account, no Supabase service role key. `.gitignore` blocks the common
  filenames, and `core/config/app_config.dart` states the rule.
  `core/config/supabase_config.dart` goes further and *refuses* such a key at
  runtime: an `sb_secret_…` value, or a JWT whose payload carries
  `role: service_role`, is dropped and the app reports itself unconfigured.
  That guardrail exists to catch a mistake, not to make one safe.
- Client keys (`apiKey`, Supabase anon key) are expected to be public. Their
  safety comes from Security Rules and Storage RLS, not secrecy.
- Every write path is authorised by rules: ownership (`uid == auth.uid`), role
  (`role == 'donor'`), state transitions, and exact allowed key sets.
- Storage is authorised by its own RLS, and it does not get to relax anything to
  work (see §13): the bucket policy proves the token's issuer, its audience and
  that the object path sits under the caller's own id.
- Input validation happens on both sides. Client validation is UX; rules are the
  boundary.
- Rate limiting is enforced in rules where the data model allows it.

## 9. Medical domain rules

Donation eligibility is **configuration, not code**. The interval between
donations differs by donation type (whole blood, plasma, platelets) and per
national guideline, so a constant `90 days` in Dart would be a medical claim the
app is not qualified to make.

Design: eligibility parameters live in a Firestore configuration document,
versioned and editable without an app release. The domain layer reads the
policy, the repository supplies current donor history, and a pure function
decides eligibility. Until that configuration exists, the app must **not**
silently assume a default interval — it must surface "eligibility unknown".

Donor *availability* (the ON/OFF switch) is a separate, user-controlled flag.
A donor who switches OFF stays OFF until they switch it back ON; no automated
process may flip it. Eligibility and availability are distinct concepts and are
never merged into one field.

## 10. Package policy

Before adding a package: check the publisher, last release date, open issue
volume, whether it is null-safe and supports the current Dart SDK, and whether a
50-line implementation would do the job. Every dependency added in a stage is
recorded in `docs/PROJECT_STATE.md`.

Current direct dependencies:

| Package | Version | Added in | Why |
| --- | --- | --- | --- |
| `firebase_core` | 5.1.0 | 0 | Required to initialise any Firebase service |
| `firebase_auth` | 7.0.1 | 2 | Email/password identity and session persistence |
| `flutter_riverpod` | 3.4.3 | 0 | State management / DI, see §3 |
| `flutter_localizations` | SDK | 3 | Material/Cupertino strings for `bn`; `gen_l10n` delegate |
| `intl` | 0.20.3 | 3 | Required by the generated `AppLocalizations` |
| `shared_preferences` | 2.5.6 | 3 | Persist theme and language choices |
| `cloud_firestore` | 7.1.0 | 5 | Read and write the profile documents; the first stage that needs a database |
| `storage_client` | 2.8.1 | 6 | Supabase Storage REST client: no session, no singleton, one client per call carrying the Firebase token (§13) |
| `image_picker` | 1.2.4 | 6 | Gallery/camera source for the profile photo, with EXIF dropped |
| `cupertino_icons` | 1.0.9 | pre-existing | Template dependency |

`flutter_localizations` is an SDK package, not a third-party dependency, and
`intl` is already pinned by it — the localisation layer adds exactly one new
runtime package. A bundled Bengali font was considered and rejected: the platform
faces are correct on both targets, and bundling would add ~500 KB to every install
for a rendering path the OS already provides.

Firestore, messaging, maps, GPS and storage packages arrive in the stage that
first uses them. `supabase_flutter` was considered for Stage 6 and rejected: it
brings a Supabase Auth session and a plugin singleton, and this app's identity is
Firebase — the raw REST client is the smaller, safer dependency.

## 11. Known open items

Carried deliberately, not forgotten:

1. **Design reference image missing.** The three-screen mockup referenced by the
   brief was not supplied. `Images/download.png` is an unrelated stock
   illustration. Stage 1 is built from the written palette spec and must be
   reviewed against the real mockup before Stage 2 starts.
2. **Brand spelling conflict.** Logo artwork reads "Sholovvo"; the brief says
   "Solovvo". User-facing copy uses "Solovvo" via `core/brand/app_brand.dart` —
   one line to change.
3. **Android `applicationId` is `com.example.*`.** Matches the registered
   Firebase Android app, so changing it now would break `google-services.json`.
   Must be re-registered before any Play Store upload (Stage 14).
4. **`google-services` Gradle plugin is not applied.** Not required while the
   app passes explicit `FirebaseOptions` from `firebase_options.dart`. Re-verify
   in Stage 11 when FCM needs the default app configuration.
5. **iOS cannot be built or verified on this machine** (Windows host, no macOS).
   iOS correctness is reviewed by inspection until a macOS machine is available.
6. **No committed Firebase Functions.** `firebase.json` previously declared a
   `functions` source directory that does not exist, which would fail
   `firebase deploy`. Removed in Stage 0 because the Spark plan does not include
   Functions.
7. **Email/password sign-in must be enabled in the Firebase console.** No runtime
   check was possible from this machine (no emulator, no reachable test account),
   so this is an assumption, not a verified fact. If it is disabled, every form
   correctly surfaces `operationNotAllowed` — the mapping and the message are
   covered by tests, the console setting is not.
8. **The web target has no Firebase JS SDK** in `web/index.html`, so
   `Firebase.initializeApp` cannot run there. Web is a review surface only until
   that is added; the Stage 2 screens were reviewed through a stub-backed
   entrypoint (since deleted).
9. **Bengali typography depends on the platform font** (Stage 3). No face is
   bundled, so rendering is only as good as the device: Noto Sans Bengali on
   Android, Kohinoor Bangla on iOS. Layout was reviewed with Nirmala UI, which is
   the Windows face — close in metrics to Noto Sans Bengali but not identical.
   A device pass is required before Stage 14; if either platform's default face
   clips or crowds, the fix is one bundled font, not a layout rewrite.
10. **Profile photo upload has never run against real storage** (Stage 6). There
    is no Supabase project in this workspace, so the bucket, the storage policies
    and the Firebase third-party-auth setting are unapplied delivery material in
    `docs/storage/`. The app is honest about it — with no `SUPABASE_*` defines the
    sheet says upload is not set up — but "tested against fakes" is not
    "verified", and the difference is recorded in `docs/PROJECT_STATE.md`.

## 12. Profile data model and privacy (Stage 5)

The profile is **two documents**, split by who may read them rather than by what
is convenient to write together:

| Document | Readable by | Fields written |
| --- | --- | --- |
| `users/{uid}` | every signed-in account | `displayName`, `role`, `isAvailable`, `updatedAt`, and — only when there is a value — `bloodGroup`, `photoUrl`, `area` |
| `users/{uid}/private/profile` | the owner only | `area` (canonical), `addressLine`, `phone`, `gender`, `dateOfBirth`, `publishAreaInSearch`, `updatedAt` |
| `donation_history/{recordId}` | the owning donor | read-only here: `donorUid`, `bloodGroup`, `hospitalName`, `status`, `createdAt`, `donationDate`, `requestId`, `confirmedBy` |

`firestore.rules` is the boundary and was **not modified** in Stage 5. What it
already grants:

- `users/{uid}` — `read: auth != null`, `write: auth.uid == uid`.
- `users/{uid}/private/{doc}` — read and write only when `auth.uid == uid`.
- `donation_history/{recordId}` — `read` only when `donorUid == auth.uid`;
  `create` only as a self-claimed `pending` record or a `confirmed` one authored
  by the recipient of a completed request; `update: false`; `delete` only of a
  `pending` record by its owner.

**Rules that follow from the arrangement:**

1. **Privacy is placement, not a visibility flag.** A field in the public
   document is readable by every signed-in account whether or not a screen shows
   it. Phone, street address, date of birth and gender therefore only ever live in
   the private subcollection, and the profile screen marks them `Private` so the
   donor can see why they are not on the card.
2. **Un-publishing removes the data, it does not hide it.** Flipping "show my
   area" off writes `FieldValue.delete()` for the public `area`, so a client that
   reads `users/{uid}` afterwards finds nothing rather than a value plus a flag it
   might ignore. The canonical area stays in the private document.
3. **`area` is deliberately duplicated.** The private copy is the source of
   truth; the public copy is a projection that exists only while publication is
   on. Reads prefer the private copy and fall back to the public one, so a profile
   saved before the subcollection existed still shows its area.
4. **An absent field means "not set".** Writes collapse null and blank strings to
   `FieldValue.delete()`, so "has a phone number" is a presence check everywhere
   downstream instead of a comparison against `''`. `null` from `watchProfile`
   means *no document at all*, which the screen renders as a prompt to create one
   rather than as an empty card.
5. **`role: 'donor'` is written from the first save and repeated on the
   availability write.** The rules match donors on `role == 'donor'` **and**
   `isAvailable == true` **and** `bloodGroup == <requested group>`; a profile that
   omitted the role would be a donor who can never be matched.
6. **Date of birth is a calendar day, pinned to UTC midnight once, at the write.**
   Storing the device's instant would move the birthday by a day for a reader in
   another time zone.
7. **No composite index is needed for the history.** The query filters on
   `donorUid` equality only and sorts newest-first on the client
   (`ProfileDocuments.sortNewestFirst`), because "equality + `orderBy`" would
   require an index, and an index is deployed configuration.
8. **A statistic counts confirmed records only.** A `pending` row is a donor's own
   claim that no recipient has verified; counting it would overstate what the
   person has given. The list still shows pending rows, labelled as pending.
9. **Nobody can edit anyone else's profile, by construction.** `ProfileRepository`
   has no `uid` parameter — every read and write is addressed from
   `FirebaseAuth.currentUser` — and `saveProfile` refuses a payload naming a
   different account. The rule and the interface say the same thing twice on
   purpose.

**Not in Stage 5:** image upload (`photoUrl` was displayed and carried across a
save, never written by the client — written by Stage 6, §13), any write to
`donation_history` (Stages 10/11), and any read of another person's profile via
the app.

## 13. Profile photos on Supabase Storage (Stage 6)

The photo is the first thing this app stores outside Firebase. The arrangement
follows from one fact: **the identity is Firebase's, and Supabase has to be
taught to believe it.**

### The authentication bridge

A Firebase ID token carries `sub`, `iss`, `aud`, `email` and custom claims — but
no `role`. Supabase therefore treats every request as its `anon` Postgres role,
and minting `role: 'authenticated'` would need a Firebase *blocking function* to
add that claim before the token is issued, which needs Blaze. That was refused
by agreement.

So the policies do the work a role would have done. Both the insert and the
delete policy require all of:

```
bucket_id = 'avatars'
auth.jwt() ->> 'iss' = 'https://securetoken.google.com/sholovvo-blood-donation'
auth.jwt() ->> 'aud' = 'sholovvo-blood-donation'
auth.jwt() ->> 'sub' is not null and <> ''
array_length(storage.foldername(name), 1) = 1
(storage.foldername(name))[1] = auth.jwt() ->> 'sub'
```

A caller without a verified Firebase token has no `sub` and no `iss`, so every
comparison is false and the row is refused — the `anon` grant is not what
authorises anything. The bucket is `public = true` because a profile photo is
shown to other donors, which is also the only way `Image.network` can fetch it
(no header, so no listing). There is deliberately **no select policy and no
update policy**.

### The client

- One `SupabasePhotoStorage`, constructed lazily from `FirebaseAuth.instance` and
  `SupabaseConfig`. It builds the path itself
  (`{uid}/avatar-{millis}.{ext}`), so no caller can choose a folder.
- Per operation, a fresh `SupabaseStorageClient` with `apikey` and
  `Authorization: Bearer <getIdToken()>`. Nothing holds a session, so nothing can
  go stale or leak into another donor's request.
- `objectPathOf(publicUrl)` is the only thing that turns a stored URL back into a
  path, and it refuses anything outside the configured project and this bucket —
  so `removeAvatar` cannot be aimed at someone else's object even if the field
  holds a hostile value.

### The order, and what a failure leaves behind

| Action | Steps | Failure leaves |
| --- | --- | --- |
| Replace | upload new object → `setPhotoUrl(url)` → on write failure, delete the new object | the previous photo and its URL, untouched |
| Remove | `setPhotoUrl(null)` → delete the object (best effort) | at worst an orphaned object nobody links to |

The opposite of each is a profile pointing at a file that is gone. Uniqueness of
object names is what makes the "upload new, then publish" order possible at all,
and it is also why `cacheControl: max-age=31536000` is safe and why no update
policy exists.

### What is not verified

No Supabase project exists in this workspace. The bucket, the policies and the
Firebase third-party-auth setting in `docs/storage/` have never been applied, and
no upload has run against real storage. Every claim above about storage
behaviour is a test against a fake. "Known limitations" in
`docs/storage/README.md` lists the gap first, and `docs/PROJECT_STATE.md`
repeats it for this stage.

