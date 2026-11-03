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
| `presentation` | `domain`, `application`, `core` | `data`, `firebase_*`, `supabase_*` |
| `application` | `domain`, `core`, the `data` implementations it constructs at the DI seam, and the Firebase SDKs needed to construct them | `presentation` |
| `domain` | `core` | `data`, `presentation`, any SDK |
| `data` | `domain`, `core` | `presentation`, `application` |
| `core` | Flutter SDK, `core` | any feature |

`application` is the layer every built feature has, and the one the diagram above
predated. It holds the providers and the `Notifier` controllers, and
it is the only layer besides `data` allowed to name a Firebase type —
`feed_providers.dart`, `compose_providers.dart`, `profile_providers.dart` and
`auth_providers.dart` all construct a `data` implementation behind a `domain` port.
Screens import it to watch a provider; it never imports them back. Verified by
search rather than by assertion: **no file under any `presentation/` directory in
`lib/features` imports `firebase_*`, `cloud_firestore` or `storage_client`.**

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
    media/                      photo picking + validation (size, MIME, magic
                                bytes, metadata stripping) shared by features
    preferences/                persisted theme/language + their providers
  features/<feature>/
    domain/                     entities, repository interfaces, use cases
    data/                       DTOs, data sources, repository implementations
    application/                providers and `Notifier` controllers; the DI seam
                                where a `domain` port meets a `data` implementation
    presentation/               screens, widgets, feature-local copy mapping
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
| `home` | `domain`, `application`, `presentation` | the first tab of the shell: donor status strip, the two headline actions, nearby requests and community preview; every data surface reads a provider seam, and the seam is empty until the stage that owns the collection lands — except the community preview, which is a projection of the feed's own controller (§14.2) |
| `profile` | `domain`, `data`, `application`, `presentation` | the signed-in donor's own profile: `UserProfile`, `DonationRecord`, validators, `FirestoreProfileRepository` over two documents, the profile screen and its edit form |
| `feed` | `domain`, `data`, `application`, `presentation` | **Stages 8.1, 8.2 and 8.3 — 8.3 implemented, hardening in progress, not signed off.** `Post`, `Comment`, `Report` entities with their validators and enums, and the pure `PostDocument` mapper (8.1); the read path — `FeedRepository`/`FirestoreFeedRepository` over a `FeedDocuments` seam, `FeedController`, `FeedScreen`, `FeedPostTile` (8.2); and the write path — `PostRepository`/`PostWriter` ports, `FirestorePostRepository`, `FirestorePostWriter`, `PostImageStorage`/`SupabasePostImageStorage`, `ComposeController`, `ComposePostScreen` and `compose_image_grid` (8.3). See §14, and `docs/PROJECT_STATE.md` for what is **not** yet verified about 8.3 |
| `settings` | `presentation` | account summary, the appearance sheet, build information, sign-out |

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
  donor snapshot is a real projection over the signed-in donor's profile and
  donation history (Stage 5); the feed preview is a projection of
  `feedControllerProvider`, so the dashboard and the feed screen have one answer
  to "what is the newest post" rather than two (§14.2); nearby requests still
  return an empty list, because nothing owns `blood_requests` until Stage 9. The
  screen therefore has one "no data" path and one "has data" path
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
(`bottomSheetTheme`, `dialogTheme`, `navigationBarTheme`, …), which is rebuilt
per palette.

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
   └── session, verified     → AppShell
```

**The shell is not a route.** `AppShell` (`lib/app/app_shell.dart`) is the widget
the gate builds for a verified session: an `IndexedStack` of two live tabs under a
`NavigationBar`, or beside a `NavigationRail` at 720px and up, and each tab owns
its own `Scaffold`. Which tab is showing is local `State`, not a route, so
switching tabs cannot grow the stack, and a page pushed above the shell (the
settings page, the profile form, the feed and its composer) returns to whichever
tab was showing.

`ShellTab` has exactly the members that have a live destination — there is no
placeholder tab waiting for a later stage, for the same reason the dashboard's
seams render empty rather than fake.

Consequences, all deliberate:

- **No screen navigates to a destination.** The four auth forms call
  `popUntil(route.isFirst)` on success and let the stream do the rest. Signing out,
  confirming an email, or a token revoking on the server all land the user in the
  right place without any screen knowing about any other. The one place a screen
  does pop on its own is `SettingsScreen` after a successful sign-out: a route
  pushed **above** the gate survives the gate swapping the widget underneath it.
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
10. **Profile photo upload has never run against real storage** (Stage 6). No
    bucket, policy or upload has ever been created or exercised **from this
    repository** (item 12 records the `supabase/.temp/` CLI state and what it
    does and does not prove), so the bucket, the storage policies
    and the Firebase third-party-auth setting are unapplied delivery material in
    `docs/storage/`. The app is honest about it — with no `SUPABASE_*` defines the
    sheet says upload is not set up — but "tested against fakes" is not
    "verified", and the difference is recorded in `docs/PROJECT_STATE.md`.
11. **The feed rules predate the feed design and are not approved** (Stage
    8.1.1). `firestore.rules` has had `posts/{postId}`,
    `posts/{postId}/comments/{commentId}` and `post_likes/{likeId}` since before
    Stage 8, and none of them has been reviewed against §14. The post update
    rule allows a singular `imageUrl` where the mapper writes `imageUrls` and
    `imagePaths`; likes are a top-level `post_likes/{likeId}` collection with a
    `userId` field, not the per-post subcollection the mapper names; create
    permits a `donationRecordId` that `Post` does not model; no branch lets
    `commentCount` change; and the post create rule checks no field shape at all.
    `reports` has no rule. Stage 8.2 **reads** `posts` (§14.2); Stage 8.3
    **creates** them (§14.3), so a donor now writes through a rule that only
    checks `authorUid`. What the client guarantees instead is that a create
    carries exactly the mapper's field set, validated before the network; what
    the rules will guarantee once reconciled is that no *other* client can write
    something this feed would refuse. §14.1 records the proposed canonical schema
    and every Rules change it will need.
12. **Post images have a bucket, a policy and a client, and none of them has
    been applied** (Stage 8.3). `docs/storage/supabase-post-images.sql` creates
    `post-images` and its two policies; `SupabasePostImageStorage` uploads into it
    and deletes by path. Like the `avatars` bucket, it is delivery material: no
    bucket, policy or Firebase third-party-auth setting has been applied **from
    this repository**, nothing has been exercised against real storage, and the app
    reports itself as unconfigured when the `SUPABASE_*` defines are absent. One
    caveat on the older wording here: local, gitignored Supabase CLI state exists on
    the development machine (`supabase/.temp/`, ignored by `.gitignore`), so a
    project may have been linked by hand. Whether it carries either bucket is not
    establishable from the repository and needs an owner check — see
    `docs/storage/README.md`.
13. **Stage 8.3 is implemented, and hardened in steps — and is still not signed
    off.** The detailed record is the Stage 8.3 entry in `docs/PROJECT_STATE.md`,
    and the short form is here so this list cannot be read as "8.3 shipped
    cleanly". The three things this entry carried as open are **closed**:
    `ComposePostScreen` and `compose_image_grid` now have 74 widget tests over the
    same fake ports, plus a `compose` capture group in the opt-in visual-review
    harness (§14.3); the feed and the composer are **reachable**, because the
    dashboard's community section previews the feed's own controller and offers
    **Open the community** when it has nothing to preview (§14.2); and a page of
    unreadable documents can no longer strand a donor on a permanently empty feed,
    because the controller walks past up to five such pages (§14.2). The fourth
    item — the failing test in `compose_controller_test.dart` — was closed earlier,
    test-side (2026-11-03, `68f9ee8`): the test asserted the uploading flag before
    the controller had finished awaiting the image picker, and now waits on a
    deterministic entry signal from the storage fake before asserting it. **No file
    under `lib/` changed for that one.** What is genuinely open is not the client's
    own behaviour: the rules reconciliation (item 11) and any live verification at
    all (items 10 and 12). Two more things this paragraph carried as open were closed
    the same day by hardening step 5 (§14.4) — the `ComposeController.discard()` /
    `_busy` race, and a walk that ended on an empty list with no explanation of it —
    leaving only the five reads such a walk costs, which is a price rather than a
    defect. The suite is 733 passed, 58 skipped, 0 failed and `flutter analyze` is
    clean, which satisfies the gate at the top of `docs/PROJECT_STATE.md` for today's
    tree and says nothing about approval.

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

## 14. Feed foundations (Stage 8.1)

**Stage 8 is the social feed** — posts, comments, likes, saves, reports. The
stage that used to sit in this slot, donor management and badges, is unscheduled
rather than renumbered. Stage 8.1 delivers the feed's *foundations*: types, a
mapper, and the refactors they need. It contains no reads, no writes, no
provider, no screen and no sample data.

### What exists, and what it refuses

| Type | Fields | Refused because |
| --- | --- | --- |
| `Post` | `id`, `authorUid`, `authorName`, `authorPhotoUrl?`, `text`, `imageUrls`, `imagePaths`, `likeCount`, `commentCount`, `createdAt`, `updatedAt`, `editedAt?` | blank text, text over 2 000 characters, more than 4 images, more paths than URLs, a negative counter |
| `Comment` | `id`, `authorUid`, `authorName`, `authorPhotoUrl?`, `text`, `parentId?`, `replyToName?`, `createdAt` | blank text, text over 500 characters, a reply with no parent |
| `Report` | `id`, `reporterUid`, `target`, `targetId`, `targetAuthorUid`, `reason`, `note?`, `createdAt` | a missing reporter, target or target author; a note over 300 characters |

Every rule is a pure `*Validator` returning a `*Issue` enum member, following the
convention §4 sets for `AuthFieldIssue`: values travel between layers, and only
the presentation layer turns one into a sentence. The entities wrap their image
lists in `List.unmodifiable` in the constructor, so a `Post` that exists is a
`Post` no caller can mutate behind another's back.

Three absences are deliberate:

- **No `postId` on `Comment`.** A comment lives at
  `posts/{id}/comments/{id}`, so the parent post *is* its path. A copy in the
  body could disagree with the address, and there is no rule that could stop it.
- **No moderation status, and no follow graph.** Both were considered and left
  out. A status field would imply an enforcement pipeline that Spark cannot run
  (no Functions, §7), and a report is a signal a human reads in a later stage,
  not a switch that hides a post. Following would need its own counters, rules
  and query shapes, and nothing in Stage 8 reads it.
- **No private profile fields.** A post carries the author's `uid`, display name
  and photo URL — the three fields §12 marks as readable by any signed-in
  account. Phone, street address, canonical area and blood group are never
  copied into a post. A feed that leaked the area of a donor who publishes it
  only for matching would undo Stage 5 in one query.

### The author snapshot is a trade-off

The name and photo on a post are a **snapshot taken at write time**, not a
reference resolved at read time. The alternative — reading `users/{uid}` for
every author of every card — costs one extra read per row on a Spark plan whose
whole design (§12) is built around keeping reads proportional to what the donor
is looking at. The price is staleness: a donor who changes their name or photo
keeps the old one on posts they already wrote. That is accepted, and it is
recorded in the entity's own documentation rather than left to be discovered.

### The mapper

`PostDocument` (`lib/features/feed/data/models/`) is a set of pure functions
over plain maps, in the shape §12 established for the profile:

| Direction | Behaviour |
| --- | --- |
| `toMap` | omits `id` (it is the document's address, so a field could disagree with it), writes `createdAt`/`updatedAt`/`editedAt` as `Timestamp.fromDate(…toUtc())`, writes the optional fields only when they are set, and always writes both image lists even when they are empty |
| `fromMap` | returns `Result<Post>`: `ValidationFailure` whose `messageKey` is the `PostIssue` name, or a `Post` |

The asymmetry in the image lists is the reason the shape is fixed: a key that is
always present is a key a rule can require, whereas an absent one makes every
rule test for absence too. It also means `0 images` reads back as `0 images`
rather than as a missing field that might mean something else.

`fromMap` never substitutes a value. Absent text is not an empty post, an
unknown counter is not zero, and a malformed image list is not an empty one;
each is refused with the issue that names the field. Anything the mapper does
not recognise — a field a later stage adds — is ignored, because a reader that
fails on unknown keys cannot survive being deployed before the writer. The
debug message names the field's `runtimeType` and never its content: a
malformed post must not put what a donor wrote into a log.

The mapper is the only file in `lib/features/feed` that imports
`cloud_firestore`, and it is in `data`, where §1 allows it. No repository, no
data source and no provider exist yet.

### The two refactors this stage needed

Neither is feed code, and both had to happen before a feed feature could be
built without copies:

- **`lib/core/media/`.** `PhotoValidator`, `PhotoCandidate`, `PhotoFormat`,
  `ValidatedPhoto`, `PhotoIssue` and `PhotoPicker` moved out of
  `features/profile/domain`. The avatar-shaped parts stayed where they were:
  `ProfilePhotoStorage` and `SupabasePhotoStorage` speak `uploadAvatar` and
  build `{uid}/avatar-{millis}.{ext}`, which is not a shape a post image has.
  The `image_picker` adapter moved too, which the brief did not name: leaving it
  in `features/profile/data` would force the feed to import another feature's
  data layer — an import across feature boundaries that §1's layering does not
  allow — or to re-derive the same
  `maxWidth`/`imageQuality`/`requestFullMetadata: false` arguments, and a
  second copy of those is how EXIF location ends up in a post.
- **`BloodGroupBadge` and `InitialsAvatar`.** Each existed twice after Stage 4
  wrote private copies in the dashboard. Both now live in `design/widgets`
  with an explicit variant — `pill`/`square`, `brand`/`muted` — because the two
  appearances were both approved and neither is a mistake. The dashboard's
  square 44 dp tile and its muted 40 dp disc are rendered by the shared widgets
  at exactly those sizes, so this is a consolidation with no visual change.

### What Stage 8.1 does not do

Nothing reads or writes `posts`, `comments` or `reports`; there is no
repository, no provider and no screen. Post images have no bucket and no client.
Stage 8.2 — the read path — and the rules stage both remain pending.

`firestore.rules` was **not modified** by Stage 8.1 or 8.1.1, but it is not empty
on the feed: `posts/{postId}`, its nested `comments`, and a top-level
`post_likes` block already exist. They were written before the feed was designed,
they are **not approved** for it, and the schema has not been reconciled with
them. `reports` has no rule. No Feed backend implementation has been authorised.
§14.1 records the differences and the proposal.

### 14.1 Proposed canonical schema (Stage 8.1.1 — proposed, not implemented)

The rules, the entities and the mapper disagree with each other. Nothing in the
table below has been applied to `firestore.rules` or to any Dart file; it is a
decision record for the stage that reconciles them.

| Concern | `firestore.rules` today | Stage 8.1 types | Proposed |
| --- | --- | --- | --- |
| Post fields | `authorUid` checked; every other field free | 9 required, plus `authorPhotoUrl` and `editedAt` | exactly the mapper's set, and nothing else |
| Post images | update permits the singular `imageUrl` | `imageUrls` + `imagePaths`, 0–4, paths ≤ urls | keep both lists; `imageUrl` is deleted |
| Comments | `posts/{id}/comments/{cid}`; create checks `authorUid` only; no update | `id`, `authorUid`, `authorName`, `authorPhotoUrl?`, `text`, `parentId?`, `replyToName?`, `createdAt` | same path and fields; rules gain the shape, text ≤ 500, `createdAt == request.time` |
| Likes | `post_likes/{likeId}`, field `userId` | `posts/{postId}/likes` (a constant only) | `posts/{postId}/likes/{uid}` — the document id is the liker's uid |
| Reports | no rule at all | `id`, `reporterUid`, `target`, `targetId`, `targetAuthorUid`, `reason`, `note?`, `createdAt` | new `reports/{reportId}`, create-only for the client |
| Required vs allowed | no `hasAll`/`hasOnly` on post create | `PostDocument.requiredFields` | rules mirror that list on create |
| Author identity | `authorUid == request.auth.uid` on create, immutable on update | `authorUid` plus name/photo snapshot | keep, and make the snapshot immutable on update too |
| Timestamps | posts unconstrained; the other validated collections require `createdAt == request.time` | mapper writes a client `Timestamp.fromDate(now)` | server timestamps on write; the entity keeps the optimistic value |

**Images: `imageUrls` + `imagePaths`, not `imageUrl`.** No client has ever
written the singular field — it exists only in an update allow-list, so it is a
field the update rule reserves and nothing produces. Two lists are needed for a
second reason the singular field cannot express: a URL cannot be turned back into
the storage object to delete it without parsing the URL, and the storage policies
for post images will key on the path. The paired list is also what makes
"delete an image from a post" possible without leaking the object.

**Likes: a subcollection, not `post_likes`.** `post_likes/{likeId}` needs a
chosen document id, a rule that binds that id to the caller — today's rule binds
only the `userId` field, so the same person can like the same post twice under
two ids — and a separate cleanup when a post is deleted. Three things that can
each be got wrong. `posts/{postId}/likes/{uid}` makes a duplicate like
impossible (the id is the uid), makes unliking a delete by address, and needs no
`postId` or `userId` field at all, because the path already carries both. The
card still reads the post's own `likeCount`, so the subcollection is addressed
one document at a time and never counted. Firestore does not delete
subcollections with their parent, so cleanup is a task either way — but this way
it is a task with an addressable list rather than a query.

**`donationRecordId`: drop it.** The rule accepts one and validates it deeply
against `donation_history`, but no screen offers it, no entity models it and no
design calls for it. A permissions rule for a field that cannot be written is a
field waiting to be written by someone. If the badge/feed link is wanted later,
it comes back as its own decision with its own test.

**`commentCount` needs a path.** No branch of the post update rule allows
`commentCount` to change, so a comment could be created and the count frozen
forever. The proposal is the same `±1` shape the like counter already has, with
the comment create and the counter increment committed together.

**Rules changes this will need** — all of them later, in the rules stage, none
of them now: the post create rule gains `hasAll`/`hasOnly`, text size and image
count checks; the post update rule swaps `imageUrl` for `imageUrls`,
`imagePaths`, `editedAt`, `updatedAt` and `commentCount`; `post_likes` is
replaced by the subcollection rules (which also removes a top-level collection
that nothing else references); `comments` gains a create shape and keeps its
current no-update stance; and `reports` is written from scratch, create-only.

## 14.2 The feed read path (Stage 8.2)

The feed is now **readable and still not writable**. One screen, one repository,
one provider, one query; no create, edit, delete, like, save, comment, report,
upload or transaction anywhere in `lib/features/feed`. Nothing in
`firestore.rules`, `firebase.json`, `.firebaserc`, the Firestore indexes or any
Supabase setting was touched, and nothing was deployed.

*This paragraph describes Stage 8.2's own scope, which was exactly that. It is no
longer a description of the tree: Stage 8.3 (§14.3) added the create path, the
image upload and the post storage adapter. Read "still not writable" as the stage
boundary, not as the project state.*

It was built against §14.1 as approved: `imageUrls` + `imagePaths`,
`posts/{postId}/likes/{uid}` as the future likes path (declared as a constant,
never addressed), `donationRecordId` not modelled. §14.1's table is still a
proposal with respect to the rules, and this stage did not move it.

### The layers

| Layer | File | Job |
| --- | --- | --- |
| `domain` | `feed_page.dart` | `FeedCursor` (an empty interface), `FeedPage` — posts, cursor, `hasMore`, `skipped` |
| `domain` | `feed_repository.dart` | the port: `pageSize = 10` and one method, `loadPage({after})` |
| `data` | `feed_documents.dart` | the transport seam: `FeedDocument` (id, fields, cursor) over `FeedDocuments.fetch({limit, after})` |
| `data` | `firestore_feed_documents.dart` | the only class holding a `Query`; `SnapshotCursor` lives here |
| `data` | `firestore_feed_repository.dart` | assembles a page: over-fetch by one, map, count refusals, cut the window |
| `application` | `feed_state.dart`, `feed_providers.dart` | `FeedState`, `FeedController`, `feedRepositoryProvider` |
| `presentation` | `feed_screen.dart`, `widgets/feed_post_tile.dart`, `expandable_post_text.dart`, `feed_messages.dart` | the screen, one card, the six-line clamp, and the copy mapping |

The split between the two `data` files is what makes the read path testable
without an emulator: `FeedDocuments` is four members wide, so a fake can answer
with exactly the documents a test wants to describe, while the query itself
stays in one file that a reader can check against the rules in a minute.

### The query, and the cursor

```
posts
  .orderBy('createdAt', descending: true)
  .limit(pageSize + 1)
  .startAfterDocument(lastSnapshot)   // every page after the first
```

- **`createdAt` descending** is the only `orderBy` and there is no `where`, which
  is why no composite index is needed: Firestore indexes single fields
  automatically, and a composite index only becomes necessary when a filter and
  a sort disagree. There is no `firestore.indexes.json` in this repository and
  this stage did not create one.
- **`limit(pageSize + 1)`** answers `hasMore` exactly rather than by guessing
  from a page that happens to be full. The extra document is never mapped and
  never drawn: the window is cut back to `pageSize`, so a page of exactly ten
  does not advertise an eleventh page that does not exist.
- **The cursor is the last kept `DocumentSnapshot`**, not an offset and not a
  field value. A post published between two reads therefore cannot shift the
  window — offsets skip and duplicate rows when the list grows from the front,
  which is exactly where a feed grows. `SnapshotCursor` is opaque outside
  `data`: `FeedCursor` is an empty interface, so `domain` and `application`
  pass a cursor around without importing Firestore.
- **A cursor from another producer is refused** with `ValidationFailure` rather
  than coerced into a query, because paging from a foreign snapshot would
  silently return whatever happens to sort after it.
- **No snapshot listener.** `get()` once per page. A realtime feed would bill
  every open screen for every post anyone publishes.

One page costs at most eleven document reads. Ten pages cost 110 plus their
round trips; nothing in the feature asks for the whole collection. An operation
that has to walk past unreadable pages costs up to five of those windows —
`maxEmptyPages`, see "Malformed documents, and why they are counted" below — and
still never asks for more than fifty documents in one go.

### Malformed documents, and why they are counted

Each document goes through `PostDocument.fromMap`. One that fails validation is
dropped and counted into `FeedPage.skipped` rather than replacing the page with
an error: one post written by a future version of the app, or by a console user,
should not empty a donor's feed. The count is asserted by tests and is the
number that tells a debugger whether the schema has drifted. No document's
content reaches a debug message.

**An empty page is not an empty feed.** The two facts above combine into a page
that carries no post while the collection still has plenty: `hasMore` is decided
from the **raw** window, before mapping, so eleven unreadable documents answer
"ten posts, none of them readable, more pages behind". Reading that as "no posts
yet" strands the donor, because the screen's empty state replaces the footer that
holds **Load more** — the only control that could reach the readable posts behind
the bad writes. Three changes close it, none of them in `domain` or `data`, whose
contract was already right:

- `FeedState.isEmptyResult` requires `!hasMore`. The empty card is now allowed to
  say "No posts yet" only when the collection is exhausted *and* empty, which is
  the only claim that sentence is entitled to make.
- `FeedController` **walks**. Each operation re-asks with the cursor the refused
  page returned, and stops at the first page that carries a post, at the end of the
  collection, or at `FeedController.maxEmptyPages`. Walking is correct because the
  cursor addresses raw Firestore documents rather than posts: a refused document
  still moves it, so the next window starts where this one ended and no post is
  skipped or repeated. A page that carries neither a post nor a position re-asks
  with the cursor it was given, so the loop cannot spin on it.
- The walk is **bounded at five pages** (`maxEmptyPages`). A collection malformed
  all the way down is a data incident, not the bottom of a list, and an unbounded
  loop would pay for a read every frame. Five is fifty documents scanned for one
  tap — far past any plausible run of bad writes — and **Load more** stays on
  screen throughout, so the walk continues by the donor's choice rather than by
  machinery.

The bound is a cost, and it is stated rather than hidden. A donor whose newest
fifty documents are unreadable spends five reads and sees a list with nothing in it
and a button under it: honest about there being more, silent about why this page is
blank, and no closer to the readable posts than five more taps. That is the intended
trade against an empty card that lies. Two limits stay open with it, and neither is
cheap to answer from here: "malformed" and "genuinely empty" are distinguishable
only because `hasMore` happens to say so — the query cannot express the difference,
so anything that wanted to explain it would have to read, and only the controller
knows which of the two it is holding — and `FeedPage.skipped` is **not surfaced to
anyone**: no operator view, no diagnostic screen, no log line carries it, so schema
drift today shows itself only as a feed with fewer posts than the collection
contains. A home for that count belongs with the rules stage, which is the only
other place that reads these documents.

### The controller: one read at a time

`FeedController` is a `Notifier<FeedState>` with three operations and one flag.

- `loadFirstPage()` replaces the list. It is what the screen calls on mount,
  what **Try again** calls after a fatal failure, and what the pull gesture
  calls. `refresh()` is the same request under the name the gesture uses, so
  there is one code path and no way for a refresh to forget to reset the cursor.
- `loadMore()` is the only operation that consumes the cursor, and it returns
  immediately when `hasMore` is false or the cursor is null.
- **`_fetching`** refuses a second read while one is in flight. A
  pull-to-refresh landing on a page-in-flight would write two halves of different
  windows into one list, and a second tap on **Load more** would pay for the same
  page twice. The flag is checked in the controller rather than by disabling a
  button because the refresh is a gesture, not a button. **A walk is one read at a
  time in the wider sense too:** the whole empty-page walk happens inside the
  single guarded operation, so two taps on **Load more** cannot start two walks
  racing through the same bad pages.
- **A refresh does not blank the list.** With posts on screen the status stays
  `ready` while the read runs; a spinner over an empty list is a worse answer
  than one more second of stale-but-true posts.
- **A failure keeps what is true.** A failed first page is `FeedStatus.failure`
  and fatal — the screen offers a retry. A failed `loadMore` or refresh keeps the
  posts, the cursor and `hasMore`, and surfaces the `Failure` so the screen can
  show a banner above a list that is still readable. The retry re-asks the same
  cursor rather than skipping the page it failed to read, **including mid-walk**:
  the failure branch returns before the walk consumes that page's cursor, so a
  refusal on the third page of a walk leaves the cursor on the second and the retry
  asks for the third again.
- **A capped walk does not blank what the donor can already see.** A first-page
  read that reaches `maxEmptyPages` without a readable document writes the empty
  page it ended on *appended* to the posts already in state, not over them:
  refusing to show *new* posts is what the bad writes earned, and replacing the
  good old ones would be a second, unearned penalty.
- **Duplicates are not appended.** A document rewritten with a new `createdAt`
  can legitimately appear in two windows; a feed that shows the same post twice
  looks broken even when the database agreed, so `_append` dedupes by id.

### The screen

| Concern | Decision |
| --- | --- |
| Measure | 560 dp narrow, 900 dp wide, switching at 720 — the same breakpoint `HomeScreen` uses, so a tablet does not change column count between the dashboard and the feed |
| Centring | calculated side padding on a `SliverPadding`, not a `ConstrainedBox`, so a narrow window keeps the 24 dp gutter and a wide one centres rather than stretching |
| Refresh | `RefreshIndicator` over a `CustomScrollView` with `AlwaysScrollableScrollPhysics`, so the gesture works on an empty or failing feed too |
| Paging | an explicit **Load more** button, not scroll-triggered paging. Every automatic trigger is a read the donor did not ask for, and on the Spark plan a mis-measured viewport can spend a page per frame |
| End of list | "You have reached the end of the feed" only after a second page has been drawn; a single short page is obviously the end and a label under it is noise |
| Text | `ExpandablePostText` measures with a `TextPainter` (same style, same scaler, same width) and offers **Read more** only when six lines are actually exceeded — not for a short post, and not at an unbounded width where the measurement would be meaningless |
| Images | up to four from `imageUrls`, one wide when alone and a two-column grid otherwise, each with `errorBuilder` and `loadingBuilder` so a missing object is a broken-image glyph rather than a failed layout. The draw is capped at 300 dp: at the 900 dp measure an uncapped cell was over 400 dp tall |
| Empty and error states | `EmptyStateCard` centred in the remaining height — which needed `mainAxisSize: MainAxisSize.min` on its text column, because the default stretched the card to the whole viewport inside `SliverFillRemaining` |
| Counters | `likeCount` and `commentCount` are read from the post document and displayed read-only. No subcollection is read, and no counter is tappable |
| Copy | copies the post's text to the clipboard and says so. There is no share sheet and no invented URL: a post has no public address |
| Errors | `feedFailureMessage` maps all nine `Failure` types to copy — a `PermissionFailure` says permission, not "no connection", because sending a donor to check their network when the rules said no is the wrong fix |
| Time | relative to the minute, hour and day, then a calendar date after `feedCalendarAfterDays` (7). The `now` is injectable, so the boundaries are asserted rather than observed |

The screen shows one of four exclusive states: a first-load spinner, a fatal
error card with **Try again**, an empty card, or the list. The empty card is
reached only through `isEmptyResult`, which now requires `!hasMore` — a page that
is empty because its documents were refused, not because the collection is, keeps
the list branch and therefore keeps the footer with **Load more** in it.
`pumpAndSettle` is
unusable in its tests for the same reason as everywhere else in this app — the
soft glow animates forever — so the widget tests pump explicit frames.

Five renders of these states are in `docs/visuals/stage8/`, produced by the
`SOLOVVO_VISUAL_REVIEW=1` harness rather than by a browser. They are what caught
the stretched empty card and the uncapped picture height; the assertions above
could confirm the text and the picture count but not how tall anything was.

### Read access: the audit, and the result

`firestore.rules` grants `allow read: if request.auth != null` on
`/posts/{postId}`. That rule has no field condition and no per-document shape
requirement, so it covers a **list** query over the collection as well as a
direct `get`, and the query above needed nothing added to satisfy it. The
repository checks `FirebaseAuth.currentUser` first so a missing session is
reported as `AuthFailure` rather than as the `permission-denied` the rules would
eventually send. No rule was edited and none was worked around.

What the rules still do not allow is a **write** that matches §14.1, and that is
unchanged by this stage: a post with `imageUrls` still cannot be corrected under
the current update rule, `commentCount` still cannot move, and `reports` still
has no rule. Reading a document the rules permit is not an endorsement of the
shape it is written in — which is why this stage draws counts and never touches
them.

### Navigation, and the dashboard's preview of the feed

Stage 7's two-tab shell is intact: `ShellTab` still has `home` and `profile`, and
the feed is a pushed route (`FeedScreen.route()`, a `FadeSlidePageRoute`) above
the shell rather than a third tab. `AppRoutes` still carries only the three auth
routes — pushed feature screens own their own `route()` factory, so the feed added
no route table entry and no duplicate navigation constant.

The dashboard's community section is the only way in, and it is now always
available rather than conditional on data existing:

| The preview shows | The control | Copy |
| --- | --- | --- |
| posts | **See all** in the section header, and a tap on any preview card | `homeSeeAll` — "See all" |
| nothing, because the collection is empty or the read walked to its cap | **Open the community** on the empty card | `homeFeedOpenAction` — "Open the community" |
| nothing, because the first read failed | **Try again** on the error card, which re-runs the read | `feedRetry` — "Try again" |
| nothing, because the read is in flight | a 22 dp spinner, the mark the feed's own footer uses | — |

Both entry points push the same `FeedScreen.route()`, and its back button pops to
the dashboard; there is one FeedScreen instance per push and no second copy of the
route. The section keeps the rule the requests section already had — no "See all"
over an empty list, because that is a link to nothing, and two existing tests
assert it in the negative. What changed is that an empty community section is no
longer a dead end: it offers the *page* rather than a list to see, which is where a
first post would be written. "See all" promises a list; "Open the community"
promises the screen, and both are true of what they open.

**The preview is a projection, not a second read.** `feedPreviewProvider` watches
`feedControllerProvider` and maps `state.posts.take(feedPreviewLimit)` — three, not
a page — into the `FeedPostPreview` view models the card already accepted. Its type
is unchanged, so every existing override still compiles and every layout test can
still hand the dashboard a preview without a read. The dashboard triggers the
controller's own `loadFirstPage()` once, in a post-frame callback, and only if the
state has not loaded: the paging, the cursor, the one-read-at-a-time rule, the
empty-page walk and the failure model all belong to the feed, and a dashboard that
queried `posts` for itself would have two answers to "what is the newest post" and
have to be told which one to believe. It also means a post the donor publishes is
visible on the dashboard without a refresh, because `FeedController.prepend` puts it
in the one list both screens read.

Two consequences of sharing that state are accepted rather than fixed. The preview
is as fresh as the last feed read and no fresher: it goes stale until someone
refreshes the feed, and the dashboard has no pull-to-refresh gesture of its own —
adding one would mean a second refresh path against the same controller, which is
the thing the projection exists to avoid. And the shell's `IndexedStack` keeps both
tabs mounted, so the dashboard's one read happens on sign-in whether or not anyone
is looking at it: at most eleven documents, before the donor has asked for anything.

## 14.3 Compose and publish (Stage 8.3)

The feed can now be written to. One screen, one controller, two new ports and one
new storage adapter; a post is text plus up to four photographs, and it is the
only thing this stage creates. No like, no comment, no save, no report, no edit,
no delete and no share. `firestore.rules` was **not modified** — the existing
create rule (`authorUid == request.auth.uid`) already permits exactly the write
this stage makes, and §14.1's reconciliation is still the rules stage's work.

### Two ports, not one

| Port | Layer | Methods | Implemented by |
| --- | --- | --- | --- |
| `PostRepository` | `domain/post_repository.dart` | `publish(PostDraft) → Result<Post>` | `FirestorePostRepository` |
| `PostImageStorage` | `domain/post_image_storage.dart` | `isConfigured`, `upload(ValidatedPhoto)`, `remove(objectPath)` | `SupabasePostImageStorage` |
| `PostWriter` | `data/post_writer.dart` | `authorUid`, `newPostId()`, `createPost(id, fields)` | `FirestorePostWriter` |

The write port is deliberately **not** a method on `FeedRepository`. Folding it
in would give both existing read implementations — `FakeFeedRepository` in the
test support and the scripted fake inside `feed_controller_test.dart` — a method
that can only throw, and a test double with a live landmine is worse than a
second interface. `FeedRepository` therefore stays one method wide and read-only.

`PostWriter` exists so `FirestorePostRepository` holds **no Firebase type at
all**. The uid comes off the port (`String? get authorUid`) rather than off a
`FirebaseAuth` constructor argument, which is what makes the publish logic
unit-testable: `FirebaseAuth` cannot be faked, so a repository that took one
could only be exercised through an app. The read side earned its testability the
same way, with `FeedDocuments`.

### The draft, and what it does not carry

`PostDraft` is `author` (a `PostAuthor` snapshot of name and photo URL), trimmed
text and the uploaded `StoredPostImage`s. It carries **no uid**: the repository
reads the author from the session, because `firestore.rules` compares
`authorUid` to `request.auth.uid` and a form that could choose the value would be
a form that can only produce a denied write. `PostAuthor.unknown()` is what a
donor with no profile document yet posts under — a name is not a precondition
for asking for blood.

The snapshot is the trade-off §14.1 already recorded: the document repeats the
author's name and photo as they were at publish time, so the feed costs no extra
reads and a renamed donor keeps the old name on old posts.

`PostDraft.issue` re-runs `PostValidator` — the same rules the mapper applies on
read — before any network call, so an unpublishable draft is refused locally and
costs no quota. The rules stage will enforce the same limits server-side; this is
the client half of a two-place check, and the bucket's own size and mime limits
are the third.

### The write

```
posts/{id}.set({ ...9 fields, createdAt/updatedAt: serverTimestamp })
```

- **`set` on a pre-allocated id, not `add`.** `newPostId()` is `collection.doc().id`,
  so the repository can return a fully-formed `Post` — including its address —
  without a second read. `add` is the same single write but hands the id back
  only afterwards, and then either the returned entity or the drawn card would
  need a placeholder id.
- **The document is stamped by the server, the entity by the client.**
  `PostDocument.toCreateMap` writes `FieldValue.serverTimestamp()` for
  `createdAt` and `updatedAt` and drops `editedAt`; the returned `Post` carries
  the client clock so the card that is prepended has a time to render. The two
  disagree by the round trip, and the disagreement is bounded and harmless — the
  next page read replaces the optimistic value with the stored one.
- **A failed write returns the failure and drops the entity.** A post that is not
  in the database must never appear in a feed as though it were.

### Photographs: upload on pick

The single most consequential decision in the stage is *when* the upload
happens.

- **Upload on pick**, not on publish. Four photographs in one request means one
  opaque result for four files: a donor cannot tell which one is stuck, and the
  publish button stays busy for as long as the slowest object. Uploading as each
  photo is chosen gives every file its own outcome while the text is still
  editable, and it makes the publish a single small document write.
- **The path is `{uid}/post-{millis}-{n}.{ext}`.** The sequence number
  distinguishes four photos picked inside one millisecond, so an upload can never
  overwrite a previous one — which is also why every URL is immutable and may be
  cached for a year. One folder level, because the bucket policy checks
  `array_length(storage.foldername(name), 1) = 1` against the token's `sub`.
- **Removal names the path, not the URL.** `Post.imagePaths` is stored beside
  `Post.imageUrls` for exactly this: cleaning up never has to parse a URL and
  guess. `SupabasePostImageStorage.ownPath` still refuses anything whose first
  segment is not the caller's uid, so a corrupt document cannot become a delete
  aimed at somebody else's photograph.
- **Removing a photo from the form** empties the slot first and deletes the
  object best-effort. A delete that fails is logged, not shown: the sentence
  would describe a file that is no longer on screen.
- **Abandoning the draft deletes its objects.** Confirming the discard prompt
  calls `ComposeController.discard()`, which empties the state and then removes
  every uploaded path. Without it each abandoned compose would leave up to four
  objects nothing names — the free tier counts bytes, not intentions. Since §14.4
  it takes the same `_busy` guard `addImage` and `publish` take, and answers `false`
  when it refuses, so a draft can no longer be thrown away underneath an upload that
  is still going up.
- **No bucket configured means no photo control**, not a control that fails on
  tap. The screen swaps the grid for one sentence saying upload is not set up,
  and the text half of the form still publishes. That is the same honest state
  the avatar sheet shows.

### The controller

`ComposeController` is a `Notifier<ComposeState>` living beside its providers in
`compose_providers.dart` — one file rather than two, because a separate
controller file would have to import the providers that import it.

- **One operation at a time.** A single `_busy` flag guards the whole flow, not
  one flag per method. The gaps are what matter: the picker is awaited before any
  state changes, so two fast taps on the add tile would otherwise open two
  pickers and race two uploads into the same four slots.
- **A cancelled pick is silence.** `PhotoPicker` reports a cancel as a successful
  `null` and the controller returns without touching the state — a donor who
  changed their mind is not an error.
- **A failed publish keeps the draft.** Text, images and the `Failure` all
  survive, so the retry is one tap rather than a retyped post.
- **A successful publish resets the form before returning.** The screen pops
  immediately afterwards; a draft left behind would let a back-navigation
  publish the same post twice.
- **The published post is prepended to the feed**, via a new
  `FeedController.prepend(post)`, rather than triggering a refresh the donor did
  not ask for. It is a no-op when the feed has not loaded — that feed will pick
  the post up in its own first page — and it dedupes by id, because the same
  document can arrive twice if a read lands between the write and the prepend.

### The screen

| Concern | Decision |
| --- | --- |
| Entry | `FloatingActionButton.extended` on the feed. Not a `SolovvoButton` in the FAB slot: an `Align` under bounded constraints stretches to full width, so `expand: false` would not have been false. The list's bottom padding grew by `huge + xl` so the last card clears it |
| Measure | 560 dp — the same column the feed and the profile editor use |
| Fields | text (6 lines, `feedComposeLimit(2000)` as helper text) and a 2×2 image grid that always shows four cells, so the ceiling is visible rather than discovered |
| Live validation | only `textTooLong` is shown as the donor types. An empty box is not an error yet — a disabled publish button already says so |
| Publish | disabled while the draft has an issue **or** anything is in flight, including an upload: publishing past a photo still in the air would write a document that is missing it |
| Leaving | `PopScope(canPop: !isDirty)` plus a discard dialog. An untouched form closes immediately; a dirty one asks. The confirmed discard pops imperatively, because a `canPop: false` guard would otherwise refuse the pop that the donor just agreed to, and it pops only on a `discard()` that really discarded — one the guard refuses leaves the form open (§14.4) |
| Errors | `composeFailureMessage` maps the `Failure` types; a `ValidationFailure` is resolved against the photo issues first and the post issues second, because both validators can produce one |
| Copy | one feed-local photo-source sheet and one feed-local `photoIssueMessage`, duplicating the profile's. Presentation is per feature: importing another feature's `presentation` is the one direction §1 forbids outright |

The confirmation snackbar is shown through the app's `ScaffoldMessenger` before
the pop, so it survives the route and lands on the feed the donor returns to.

### What this stage does not do

No like, comment, save, report, edit, delete or share. No draft persistence
across app launches. No post-images upload in the feed's own card path. No
change to `firestore.rules`, `firebase.json`, `firestore.indexes.json` or any
Supabase setting, and nothing deployed. The SQL in `docs/storage/` is delivered
and unapplied, so every claim above about storage behaviour is a test against a
fake — the gap §11 item 12 records and `docs/storage/README.md` repeats.

### The composer under test (hardening step 3, 2026-11-03)

The stage shipped with the controller, the repository and the storage adapter
covered and the form itself unobserved. That gap is closed: **74 widget tests**
across the two presentation files, built on the same fakes the logic tests use — a
repository over `FakePostWriter`, `FakePostImageStorage`, and a photo picker that
can be held open — with no network, no plugin and no arbitrary delay in any of
them. Seventy-three of them came from this step; the seventy-fourth is §14.4's
hold-open discard.

| File | Tests | What it pins |
| --- | --- | --- |
| `test/features/feed/compose_post_screen_test.dart` | 41 | the empty form, the text rules as messages, the photo path end to end, publishing, leaving, the no-bucket build, both languages, the narrowest phone, and what a screen reader hears — including a discard refused mid-upload keeping the form open (§14.4) |
| `test/features/feed/compose_image_grid_test.dart` | 33 | four cells whatever the draft holds, the add tile and its source sheet, removal naming the right photo, the in-place spinner, the grid frozen by a publish, and the same set of semantics assertions |

The behaviours worth naming, because they are the ones this document claims:

- **Add tile → source sheet → picker → upload → filled slot**, and the two ways it
  does not work: a cancelled pick is silence, and a failed upload says what went
  wrong and leaves the form usable.
- **Publish waits for the photo still going up**, and a second tap cannot write a
  second post.
- **The discard flow exists as a tested thing rather than a `PopScope`**:
  an untouched form closes without asking, a draft asks first, *keep editing* keeps
  it, confirming deletes the uploaded object, and the system back button is guarded
  the same way as the arrow. A draft holding only a photo is worth confirming too.
  A discard confirmed while a photograph is still going up is refused and the form
  stays open (§14.4), keeping both the draft and the object that upload is about to
  name — the upload's own "Uploading your photo…" is what tells the donor to wait.
- **The 2 000-character limit is a message, not a wall**; spaces are not a post;
  the text is trimmed on write without being trimmed in the field.
- **The unconfigured build says so and still publishes the text**, and a publish
  the rules reject says which rule.
- **Semantics, in both languages**: every control is named, the publish is called a
  button and stops being one while it is busy, and — the finding this pass produced
  — **a reader can press it, not only hear it**.

That last one is the only production change the step made. `SolovvoButton`'s
semantics node now carries the same `onTap` the `InkWell` below it gets: the widget
wraps its child in `ExcludeSemantics` so the label is not read twice, and that also
swallows the tap action Flutter would otherwise derive, leaving a node that
announced "button" with no way to activate it — a TalkBack or VoiceOver user hearing
a control they could not press. It is null while the button is disabled, so an inert
button is still not offered as pressable.

The visual-review harness gained a `compose` group: eleven captures — empty and
drafted across light/dark and both languages, the source sheet, the no-bucket build
and a wide four-photo draft. They run only under `SOLOVVO_VISUAL_REVIEW=1` and
contribute the eleven skips the suite now reports. They were run and they pass, and
they write to `build/review/`, which is gitignored: `docs/visuals/stage8/` still
holds only the five read-path renders, so **the composer has been reviewed without
having been committed**. Promoting those PNGs is an owner decision, not a code
change.

### Verification status (recovery reconciliation)

Everything above this line describes the design as built. This line records how
much of it has actually been demonstrated, because the two are not equal here. The
detailed record, with the commands and the numbers, is the Stage 8.3 entry in
`docs/PROJECT_STATE.md`; §11 item 13 points at it.

| Claim above | Implemented | Tested | Approved | Deployed | Live-verified |
| --- | --- | --- | --- | --- | --- |
| `publish` writes one `posts` document | Yes | Yes — 15 repository tests over `FakePostWriter` | No | No | No |
| Draft validated before the network | Yes | Yes — within the 34 controller tests, and shown on the form by the widget tests | No | No | No |
| Photographs upload on pick | Yes | Yes — 15 storage tests against a fake, plus the screen path from add tile to filled slot | No | No | **No — no byte has ever been transferred** |
| Abandoned drafts delete their objects | Yes | Yes — best-effort path pinned by tests, now including the confirm-and-close flow on the screen, and a discard refused mid-upload pinned by two tests on the controller and one on the screen (§14.4) | No | No | No |
| `ownPath()` blocks foreign deletes | Yes | Yes — guard tested directly | No | No | No (server-side enforcement is the unapplied policy) |
| `isUploading` means the storage upload, not the pick | Yes | Yes — pinned by two gating tests, one holding the upload open (`storage.uploadStarted`) and one holding the pick open (`picker.entered`); no delays involved, and the grid's in-place spinner is asserted separately | No | No | No |
| The compose form behaves as described | Yes | **Yes — 74 widget tests** over `ComposePostScreen` and `compose_image_grid`, on the same fakes | No | No | No |
| The form is usable by a screen reader | Yes | Yes for the contract: names, button state, and a press action a reader can activate (`SolovvoButton` now supplies `onTap`). Post photographs and the composer's slots now carry `semanticLabel`s (§14.4). No real TalkBack or VoiceOver pass has been made | No | No | No |
| The form renders as designed | Yes | **Partly** — eleven `compose` captures exist in the harness and pass under `SOLOVVO_VISUAL_REVIEW=1`, but they are written to gitignored `build/review/` and are not in `docs/visuals/stage8/` | No | No | No |
| The feed and composer can be reached from the dashboard | Yes | Yes — 21 pagination tests + the dashboard preview and navigation tests, and one shell-level push/pop test | No | No | No |
| A post tile says what it shows | Yes | **Yes — 13 direct `FeedPostTile` / `ExpandablePostText` tests** (§14.4), the first coverage that mounts a tile rather than a whole feed | No | No | No |
| A read that maps nothing but has more behind it says so | Yes | Yes — the refusal count reaches both screens, pinned by four tests (§14.4) | No | No | No |
| The whole stage meets the project gate | — | **Yes for today's tree** — 733 passed, 58 skipped, 0 failed and `flutter analyze` clean, measured on the working tree on 2026-11-03 with Step 5's changes in it; a standing gate to re-run each step, not an approval | **No** | No | No |

The design gaps this stage recorded, and where each one now stands:

- **`ComposeController.discard()` is not under the `_busy` guard.** `addImage` and
  `publish` both take the guard; `discard` checked `state.isPublishing` only. Confirm
  the discard prompt while a photo is still going up and the snapshot it deletes has
  already been taken, so the upload that completes afterwards names an object no
  state holds — an orphan in the bucket, and a form reset under an in-flight
  operation. **Closed by §14.4**: `discard()` now takes the guard, returns
  `Future<bool>`, and the screen only pops on a `true`.
- **An empty page was survivable but not explainable** (§14.2): a walk that reached
  its cap spent five reads and gave the donor a list with nothing in it and a
  **Load more** under it, while `FeedPage.skipped` — the number that says *why* —
  reached nobody. **Closed by §14.4** for the two screens that could carry it, and it
  still reaches no log a remote operator can query, which is not a client job.

What is left in this stage's own design is one item, and it is not a client defect:

- **Server-side enforcement does not exist yet.** The client guarantees this app's
  writes; the create rule checks `authorUid` and nothing else (§11 item 11, §14.1),
  so the field set, the 2 000-character ceiling and the four-image ceiling have no
  rules behind them and no rules tests around them. This is the blocking item for
  any deployment, and the feed's own reachability makes it more urgent rather than
  less: what the composer writes is now something a donor can actually do.

**The reconciliation that added this subsection fixed nothing**, and it is written
so that the design record above cannot be read as a verification record. Since it
was written, three rows have moved. The failing controller test closed on
2026-11-03 by `68f9ee8`, **test-side** — a test that asserted an in-flight state on
the line after an unawaited call, measuring the image-picker await rather than the
upload; `ComposeController`, `ComposeState` and every other file under `lib/` were
unchanged **by that fix**, and the upload-state contract is now stated rather than
inferred: waiting for the donor to choose a file is not uploading, `isUploading`
covers the storage phase alone, the controller's private `_busy` guard spans the
whole pick-then-upload flow, and a validator refusal never sets the flag. The two
presentation rows closed the same day under hardening step 3, which added the 73
widget tests and the `compose` captures and changed exactly one production file:
`SolovvoButton`'s semantics node. Step 4 then made the write path reachable and
closed the empty-page dead end, touching five feed and home files under `lib/` for
the first time since `d27aee3` — `feed_state.dart`, `feed_providers.dart`,
`home_providers.dart`, `home_screen.dart`, `home_section.dart` — plus one
localisation key in both catalogues. No `domain` or `data` file in either feature
changed, and no rule, index, bucket or Supabase file did.
Everything else in the table above still reads as it did, and the rows that say
**No** under *Approved*, *Deployed* and *Live-verified* are the ones to weight: the
suite being green is a gate, not a sign-off, and no Firestore Rules or Supabase
upload has been verified by any of this work.

## 14.4 Presentation hardening (Stage 8.4)

Step 5 changed no data path, no port and no rule. It took facts the app already
knew and made them sayable, on the two places they were being silently withheld and
on the one control class that had never been mounted on its own.

### The discard is a request, not an instruction

`ComposeController.discard()` was the one mutator that did not take the controller's
`_busy` guard, so confirming the discard prompt under an in-flight upload reset the
form and deleted a snapshot of the draft taken before that upload landed. The fix is
a signature change rather than a new guard: `discard()` returns `Future<bool>` and
`ComposePostScreen._confirmDiscard` pops only on `true`. A `void` refusal would have
been the worse design, because the screen would then have had to re-derive the
controller's busy flags to decide whether to close — two owners of one fact. The
caller is the only place that knows a pop was intended, and the return value is the
only thing that says whether it may happen.

A refusal is deliberately not announced. The grid already paints *"Uploading your
photo…"* in the slot the donor is looking at, and a snackbar saying "you cannot
discard now" over that would name a rule rather than the reason. The hold-open
behaviour is pinned on both halves: two controller tests (upload in flight, publish
in flight) and one widget test that asserts the screen is still on `ComposePostScreen`
after the confirmation.

### A refusal count is part of the read, not a detail of it

`FeedPage.skipped` already existed — the mapper counts the documents it refuses — but
nothing above it read the number. It is now carried on `FeedState` the same way
`hasMore` is: accumulated across the bounded empty-page walk by `FeedController._read`
(`skipped: (keepsExisting ? state.skipped : 0) + refused`), kept untouched by the
failure branch that preserves an existing list, and exposed as
`FeedState.isUnreadableResult` — empty, loaded, `hasMore`, and not in the middle of a
read. Two getters rather than one, because "nobody has posted" and "this app could not
read what it posted" are opposite claims about opposite subjects, and a screen that
collapses them tells a donor something false about other people.

Where it is shown, and where it is not:

- **Dashboard** (`_FeedSection`, state 3 of five): an unreadable preview no longer
  renders *"No posts yet"*. It says the feed could not be fully read, gives the
  count, and offers **Open the community** rather than *Try again* —
  `loadFirstPage()` re-asks the same window and earns the same answer, and §9 forbids
  a button that cannot work. The way past an unreadable document is paging forward,
  which is what opening the feed lets a donor do.
- **Feed screen**: the count appears as one inline line above the footer, and the
  footer's working **Load more** stays the primary affordance. A full-height
  unreadable card was built here first and reverted: `feed_pagination_test.dart`
  asserts `EmptyStateCard` is absent on exactly this screen, and that assertion is
  correct — an empty list with a live *Load more* under it is a better state than a
  card that hides it. A test that was not wrong was not changed to accommodate the
  new widget; the widget gave way.

`feedUnreadableTitle` and `feedUnreadableBody` are therefore dashboard-only strings.
The feed screen uses `feedSkippedNotice` alone. That is not an oversight to tidy up:
the two screens have different answers available to them.

### Direct tile coverage, and what a photograph must say

`FeedPostTile` and `ExpandablePostText` had no test that mounted them; they were only
ever exercised through `FeedScreen`, which drags the paging repository into every
assertion about one card. Thirteen tests now mount a tile at the feed's own phone
measure, covering the author line, the edited marker, the two counts, the copy
control (intercepted at the `SystemChannels.platform` messenger, because what reaches
the clipboard is the thing under test), the no-write guarantee, and the expander's
collapse/threshold behaviour including the unbounded-width case where it must not
offer a toggle it cannot measure. Every tile is mounted with an explicit `now:`, so
no relative date depends on the wall clock.

Accessibility work was bounded to real information loss rather than a sweep. Three
`Image.network` callsites rendered a `semanticLabel`-less image node, which a reader
announces as nothing but an image:

| Callsite | Label source |
| --- | --- |
| `feed_post_tile.dart` post photographs | `feedPostPhotoLabel(authorName)` — *"Photo shared by Ayesha Rahman"*, threaded through `_PostImages` → `_cell` → `_PostImage` |
| `compose_image_grid.dart` filled slots | reuses the existing `feedComposePhotosLabel` |
| `initials_avatar.dart` with a photo | `semanticLabel: name.trim()`, by symmetry with the same widget's own announced-initials fallback |

The like/comment row was left alone on purpose. Its `Text` already announces
"3 likes" and "1 comment", and wrapping it in further semantics would risk a double
reading for no gained information — the deliberate non-fix, disclosed rather than
forgotten.

### Documentation correction

`docs/storage/README.md` step 5 item 6 told a reviewer the Feed was unreachable from
normal navigation and that the post-photograph check therefore needed a temporary
route. Both halves were false by the time it was written: the dashboard reads the
feed's own controller on mount and every control in its community section opens
`FeedScreen`, whose labelled **Share an update** button pushes `ComposePostScreen`.
The step now names the real path (**From the community** → **Share an update**),
records that the gap was closed by navigation rather than worked around, and keeps
the one true limitation — there is still no per-post destination and nearby requests
are not wired, which is Stage 9 work, not storage work.

### What Step 5 does not claim

No Rules, index, bucket, SQL or Supabase file changed, and none was applied. Nothing
here was verified against a live backend: every new assertion runs against the same
fakes the rest of the suite uses. No real screen reader pass has been made, so the
three labels are correct by construction and by widget test, not by ear. The visual
review harness gained no captures in this step. The suite is **733 passed, 58
skipped, 0 failed** with `flutter analyze` clean, measured on the working tree
containing these changes.

