# Solovvo — Project State

Living status file. Updated at the end of every stage with what was **verified**,
not what was attempted. A stage is only marked done when `flutter analyze` and
`flutter test` both pass on the committed tree.

## Stage tracker

| Stage | Name | Status |
| --- | --- | --- |
| 0 | New project setup & architecture | **Complete — approved** |
| 1 | Design system & splash screen | **Complete — approved** |
| 2 | Login, registration & authentication | **Complete — approved** |
| 3 | Bangla/English & dark/light theme | **Complete — approved** |
| 4 | Home dashboard UI | **Complete — approved** |
| 5 | User profile system | **Complete — approved** |
| 6 | Profile photo upload (Supabase Storage) | **Complete — approved** |
| 7 | Navigation & settings | **Complete — awaiting approval** |
| 8 | Social feed | **In progress — 8.1 and 8.1.1 complete (awaiting approval), 8.2 complete (awaiting approval), 8.3 IMPLEMENTED — HARDENING IN PROGRESS (steps 1–5 done; defects 10, 13, 14 and 15 closed; not approved, not deployed, not live-verified)** |
| 9 | Normal blood search & maps | **Not started as a whole. 9.1 — open blood requests, read path — is IMPLEMENTED against fakes (awaiting approval; not deployed, not live-verified); 9.2 — Firestore rules audit, first emulator run and the feed reconciliation — is IMPLEMENTED AND EMULATOR-VERIFIED (96/96; awaiting approval; not deployed); 9.3 — the first production compatibility audit (live, read-only), the deploy-safe rule refinements and the donor-directory rules — is IMPLEMENTED AND EMULATOR-VERIFIED (106/106; awaiting approval; not deployed); donor search UI, maps and any request write are still not started** |
| 10 | Emergency blood request | Not started |
| 11 | Donor matching & notifications | Not started |
| 12 | Messaging & live location | Not started |
| 13 | Admin, security & testing | Not started |
| 14 | Production preparation | Not started |

Stage 6 was re-scoped by the client from the original plan's "social feed & image
upload" to **profile photo upload on Supabase Storage**, and the feed left the
schedule at that point. The Stage 8.0 assessment brought it back: **Stage 8 is the
social feed again**, and the donor management and badge work that used to occupy
that slot is now unscheduled rather than renumbered, so the names of Stages 9–14
are unchanged. Stage 8.1 delivered the feed's foundations only, Stage 8.1.1
corrected this file's and the other documents' claims about the rules, and Stage
8.2 delivered the read path — one paged, read-only `FeedScreen`.

**Stage 8.3 — post image storage and the composer — is implemented and committed,
and is neither hardened nor signed off.** That is a correction to this file, not
a new plan: until this reconciliation the tracker stopped at 8.2, and the Stage
8.2 entry below closed with "Stage 8.3 has not been started", while the same
commit that delivered 8.2 (`d27aee3`) also delivered `ComposePostScreen`,
`ComposeController`, the `PostRepository`/`PostWriter` ports and their Firestore
and Supabase implementations, the `post-images` SQL and the composer tests — 61
in that commit, **62 today** after the Step 2 fix added one.
`docs/ARCHITECTURE.md` §14.3 documented that work as it was built; this file never
caught up. The entry at the end of this file records what is actually in the tree,
what is not yet verified — including, at the reconciliation, one failing test in
`flutter test` since resolved **test-side** — and what
hardening is outstanding. Nothing about the 8.3 implementation was rebuilt,
replaced or reverted by this reconciliation, and the Step 2 fix changed no Dart
source.

**Stage 9.1 — open blood requests, read path — is implemented, and is the first
work on top of Stage 8 that the 8.3 reconciliation did not gate.** That needs
reading carefully, because the paragraph above it says Stage 9 "should not start
on top of an unapproved, unenforced write path". 9.1 writes nothing: it reads
`blood_requests` through a rule that already exists and already allows any signed
in user to read (`allow read: if request.auth != null`), it changed no rule, no
index, no bucket and no SQL file, and it does not touch the feed's unreconciled
write path at all. The blocking dependency for *deployment* — the feed rules
reconciliation — is untouched and still stands. What 9.1 delivered is the dashboard
requests section and an **Open requests** screen over a real query, verified
against fakes only, in the entry at the end of this file.

---

## Stage 0 — New Project Setup & Architecture

### Pre-existing state (found, not assumed)

The workspace was not empty. Discovery before any change:

- Flutter scaffold `sholovvo_app` (Android, iOS, web) with the default counter
  demo still in `lib/main.dart`.
- Firebase project `sholovvo-blood-donation` already registered for Android, iOS
  and web: `lib/firebase_options.dart`, `android/app/google-services.json`,
  `.firebaserc`, `firebase.json`.
- A 269-line `firestore.rules` implementing atomic donor claiming, request
  responses, notification authorisation, donation history and ratings.
- A Node test suite for those rules in `firestore-rules-tests/`.
- Brand logo at `Images/logo.jpeg`.
- No git repository.
- `firebase.json` referenced a `functions/` directory that did not exist.

Decision (with user approval): build on these assets rather than discarding them.

### Completed

- Architecture contract written and enforced by import direction.
- Core primitives: `Result<T>`, `Failure` hierarchy with codes, `AppLogger`,
  `AppConfig`, brand constants.
- Real Firebase initialisation with a sealed outcome type — no fake success path.
- Composition root: `main() → bootstrap() → ProviderScope → SolovvoApp`.
- Strict lint policy, including `unawaited_futures` promoted to an **error**
  (a dropped write in this app means a lost emergency request).
- `firebase.json` corrected for the Spark plan.
- Git repository initialised; no commit made.
- `.gitignore` hardened against service-account and signing material leakage.

### Files created

```
lib/main.dart
lib/app/app.dart
lib/app/bootstrap.dart
lib/app/bootstrap_gate.dart
lib/core/brand/app_brand.dart
lib/core/config/app_config.dart
lib/core/error/failure.dart
lib/core/result/result.dart
lib/core/logging/app_logger.dart
lib/core/firebase/firebase_bootstrap.dart
test/app/bootstrap_gate_test.dart
test/core/result_test.dart
test/core/failure_test.dart
test/core/app_config_test.dart
docs/ARCHITECTURE.md
docs/PROJECT_STATE.md
```

### Files modified

```
pubspec.yaml            added firebase_core 5.1.0, flutter_riverpod 3.4.3
analysis_options.yaml    extra lints, unawaited_futures as error
firebase.json           removed non-existent functions block
.gitignore              node_modules, emulator logs, secret patterns
README.md               rewritten for this project
```

### Files deleted

```
test/widget_test.dart   template counter test; referenced the removed MyApp and
                        could not compile after main.dart was replaced
```

### Database changes

None. The existing `firestore.rules` was left untouched and is not yet deployed
from this machine — deployment needs the Firebase CLI, which is currently broken
in this environment (see Remaining issues).

### Packages added

| Package | Version | Reason |
| --- | --- | --- |
| `firebase_core` | 5.1.0 | Initialise Firebase |
| `flutter_riverpod` | 3.4.3 | State management and dependency injection |

### Verification

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** |
| Unit + widget tests | `flutter test` | **20/20 passed** |
| Dependency resolution | `flutter pub get` | Clean |
| Android debug build | `flutter build apk --debug` | **Built** `build/app/outputs/flutter-apk/app-debug.apk` (146.8 MB, 560 s first run) |

Test coverage in this stage:

- `Result`: success/failure accessors, `fold`, `map`, `guard` (success, timeout
  classification, unknown exception classification, `Failure` pass-through).
- `Failure`: exception mapping, stack trace retention, validation metadata.
- `AppConfig` / `AppFlavor`: parsing, case tolerance, safe fallback to
  development, brief-pinned radius policy.
- `BootstrapGate`: renders brand identity, renders connected state with the real
  project id, renders the classified failure code on failure.

### Remaining issues

1. **Design reference image not supplied.** Stage 1 will follow the written
   palette spec; it must be reviewed against the real mockup before Stage 2.
2. **Brand spelling conflict.** Logo says "Sholovvo", brief says "Solovvo".
   Currently "Solovvo", isolated in `app_brand.dart`.
3. **Firebase CLI is broken on this machine.** `C:\WINDOWS\system32\firebase.cmd`
   is a stale shim that shadows the npm install, and PowerShell execution policy
   blocks the `.ps1` wrapper, so rules cannot be deployed or emulated from here
   yet. Needed before Stage 13.
4. **No iOS verification possible.** Windows host; no macOS toolchain.
5. **`applicationId` is still `com.example.*`.** Tied to the Firebase Android
   registration; a production rename requires re-registering the app.
6. **No push notifications on Spark.** Documented in `docs/ARCHITECTURE.md` §7.
7. **`firebase_core` still applies the Kotlin Gradle Plugin.** The Android build
   prints a Flutter warning that future Flutter releases will fail for plugins
   that apply KGP instead of using Built-in Kotlin. It is a warning today, not a
   failure; track it upstream and upgrade `firebase_core` when a migration lands.
8. **Debug APK is 146.8 MB.** Expected for an un-split debug build with an
   unstripped engine; release builds with ABI splits and obfuscation are a
   Stage 14 concern.

### Next stage

**Stage 1 — Design system & splash screen.** Deliverables: burgundy/cream token
set, typography scale, elevation and radius primitives, reusable buttons/inputs/
cards, animated floating blood drops, splash → auth transition.

---

## Stage 1 — Design System & Splash Screen

### Completed

- Token layer under `lib/design/tokens/`: colour ramp, 4-point spacing scale,
  radius scale, elevation (soft shadow) set, type scale, motion durations/curves.
- `AppTheme.light` composed from those tokens — the only place a `ThemeData` is
  built. Brand is `#A50024`, surface is `#FBF7F2`.
- Reusable widgets: `SolovvoButton` (primary/secondary/ghost, two sizes, loading
  and disabled states, press feedback), `SolovvoTextField` (uppercase label,
  prefix icon, password reveal, inline error row), `SolovvoCard` (rounded, soft
  shadow, optional ink tap), `BloodDropMark` (vector brand mark), `SoftGlowBackground`
  and `FloatingBloodDrops`.
- `FadeSlidePageRoute` for screen transitions.
- Splash screen: 2 s brand reveal (mark scale/fade, wordmark fade+rise, progress
  rule) driven by one `AnimationController`, then `pushReplacementNamed` welcome.
  The hand-over is guarded so a double status callback cannot push twice.
- Welcome screen: brand row, hero medallion, headline "A Drop of Hope, Give Blood,
  Give Life", supporting paragraph, `Get Started`, and a "Sign in" link — both
  route to the auth entry point.
- Auth entry placeholder for Stage 2: no login logic, no fake success path, and it
  says so on screen.
- Router (`AppRoutes`, `AppRouter.onGenerateRoute`); `BootstrapGate` now shows the
  splash when Firebase is ready and the diagnostic view when it is not.
- Continuous ambient animation honours `MediaQuery.disableAnimationsOf`.

### Files created

```
lib/design/tokens/app_colors.dart
lib/design/tokens/app_spacing.dart
lib/design/tokens/app_radius.dart
lib/design/tokens/app_elevation.dart
lib/design/tokens/app_typography.dart
lib/design/tokens/app_motion.dart
lib/design/app_theme.dart
lib/design/motion/fade_slide_route.dart
lib/design/widgets/blood_drop_mark.dart
lib/design/widgets/floating_blood_drops.dart
lib/design/widgets/soft_glow_background.dart
lib/design/widgets/solovvo_button.dart
lib/design/widgets/solovvo_text_field.dart
lib/design/widgets/solovvo_card.dart
lib/features/splash/presentation/splash_screen.dart
lib/features/welcome/presentation/welcome_screen.dart
lib/features/auth/presentation/auth_entry_screen.dart
lib/app/router/app_routes.dart
test/design/app_theme_test.dart
test/design/solovvo_button_test.dart
test/design/solovvo_field_and_card_test.dart
test/design/effects_and_mark_test.dart
test/features/splash_screen_test.dart
test/features/welcome_screen_test.dart
docs/visuals/stage1/{splash,welcome-portrait,welcome-short-window,auth-placeholder}.png
```

### Files modified

```
pubspec.yaml            flutter_web_plugins (SDK) — the generated web plugin
                        registrant imports it; without it `flutter build web` fails
lib/app/app.dart        AppTheme.light + onGenerateRoute
lib/app/bootstrap_gate.dart  splash when ready, diagnostic view when not
test/app/bootstrap_gate_test.dart  rewritten for the new gate behaviour
```

### Database changes

None. `firestore.rules` and `firebase.json` untouched.

### Packages added

None from pub.dev. `flutter_web_plugins` is an SDK package pulled in with
`flutter pub`, not a download; it is required for the web target to compile.

### Verification

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** |
| Unit + widget tests | `flutter test` | **57/57 passed** |
| Web build | `flutter build web --release` | **Built** `build/web` |
| Browser review | Chrome, three window sizes | Splash, welcome and auth entry render; no console errors |

Layout and motion assertions in the suite include: splash stays until 2 s then
hands over; splash lockup is horizontally centred; the loading rule is 4 px tall
and advances; welcome fits 320×568, 430×932 and 280×653 with no RenderFlex
overflow; both actions stay above the fold on a 700×420 short window; the auth
placeholder is reachable from both actions.

### Bugs found during verification and fixed

1. **`RenderFlex overflow … on the right` in the welcome actions.** "Already have
   an account?" plus the "Sign in" button outgrew a narrow slot. Replaced the
   `Row` with a centred `Wrap` so the pair reflows.
2. **Splash lockup pinned to the left edge.** A loose `Stack` let the brand
   `Column` shrink-wrap to its widest child. Fixed with `StackFit.expand`, and
   covered by a centring test.
3. **Splash loading rule invisible.** Unpositioned `ColoredBox`/`DecoratedBox`
   children of a loose `Stack` collapse to zero height. Both layers are now
   `Positioned.fill`; a test asserts a 4 px-tall fill that grows.
4. **Actions falling below the fold on short windows.** The welcome screen no
   longer distributes one scrolling column; the brand row and the actions are
   fixed and only the hero band scrolls.
5. **Clipped half-sentences when the hero band is very short.** The medallion is
   dropped below a 340 px band and the supporting paragraph below 230 px, so the
   screen degrades to headline + actions instead of truncating text.
6. **Hero medallion reading almost black.** The deep gradient started at
   `#4E0011`; it now starts at `#7A001B` so the surface still reads burgundy on
   cream.

### Remaining issues

1. **Design reference image still not supplied.** The build follows the written
   spec plus the screenshots in `docs/visuals/stage1/`. Review against the real
   mockup before Stage 2 if that mockup exists.
2. **Typography uses the platform face.** No font is bundled, so Bengali coverage
   is deferred to Stage 3 rather than half-solved here.
3. **The real app still cannot run on web**: `web/index.html` has no Firebase JS
   SDK script tags, so `Firebase.initializeApp` fails there and the bootstrap
   gate correctly shows the diagnostic view. The design was reviewed through a
   temporary preview entrypoint (since deleted). Add the JS SDK when web becomes
   a supported target.
4. **Screenshots are captured on a desktop Chrome window**, not on a phone. No
   Android emulator and no iOS toolchain on this machine.
5. Carried over from Stage 0: broken Firebase CLI, `com.example.*` applicationId,
   no push notifications on Spark, `firebase_core` KGP warning, 146.8 MB debug APK.

### Next stage

**Stage 2 — Login, registration & authentication.** Not started.

---

## Stage 2 — Login, Registration & Authentication

### Completed

- `auth` feature in four layers. **domain**: `AuthUser` (immutable, `shortName`,
  `copyWith`, value equality), `AuthRepository` (5 commands + `currentUser` +
  `authStateChanges`), `AuthValidators` (email, sign-in password, new password,
  display name). **data**: `FirebaseAuthRepository`, `auth_error_mapper`.
  **application**: `authRepositoryProvider`, `authStateProvider`.
  **presentation**: four screens plus a shared scaffold, error banner and message
  catalogue.
- Real email/password sign-in, registration with display name, email verification
  with resend, password reset, sign-out. No fake success path anywhere: every
  command returns `Result<T>` and every failure reaches the UI.
- **Session persistence** through `FirebaseAuth.authStateChanges` mapped to
  `Stream<AuthUser?>`. A stored session survives a restart; the app opens
  straight to the right screen.
- **`AuthGate`** is the single owner of the session → screen decision
  (`welcome` / `verify email` / `home`), with the 2 s brand reveal held by the gate
  instead of the splash screen navigating. The splash screen no longer imports
  `Navigator`. See `docs/ARCHITECTURE.md` §6.
- **Loading state while checking auth**: the gate keeps the splash up until the
  stream has a value, so a returning user never sees the welcome screen flash.
- **Error handling**: Firebase error codes → `AuthFailureReason` → one sentence per
  reason, with an exhaustive switch, so adding a failure type is a compile error.
  Credential rejections are collapsed (anti-enumeration) and a reset request for an
  unknown address still reports success.
- **Form behaviour**: inline field validation before any network call, a failure
  banner above the fields, disabled inputs and a spinner while in flight, and a
  guard against double submission.
- Verification screen: resend with a real 60 s cooldown, "check again" that calls
  `reloadUser` and then invalidates the auth provider, and sign-out.
- `HomeScreen`: greeting, verified chip, account details and sign-out — a landing
  place for the authenticated state that Stage 4 replaces.
- Shared `AuthScaffold` centres the form on a tall screen and anchors it to the top
  when the form is taller than the window, so the heading is never scrolled out of
  reach.

### Files created

```
lib/features/auth/domain/auth_user.dart
lib/features/auth/domain/auth_repository.dart
lib/features/auth/domain/auth_validators.dart
lib/features/auth/data/firebase_auth_repository.dart
lib/features/auth/data/auth_error_mapper.dart
lib/features/auth/application/auth_providers.dart
lib/features/auth/presentation/auth_messages.dart
lib/features/auth/presentation/login_screen.dart
lib/features/auth/presentation/register_screen.dart
lib/features/auth/presentation/forgot_password_screen.dart
lib/features/auth/presentation/verify_email_screen.dart
lib/features/auth/presentation/widgets/auth_scaffold.dart
lib/features/auth/presentation/widgets/auth_error_banner.dart
lib/features/home/presentation/home_screen.dart
lib/app/auth_gate.dart
test/support/fake_auth_repository.dart
test/support/auth_harness.dart
test/app/auth_gate_test.dart
test/features/auth/auth_validators_test.dart
test/features/auth/auth_error_mapper_test.dart
test/features/auth/login_screen_test.dart
test/features/auth/register_screen_test.dart
test/features/auth/forgot_password_screen_test.dart
test/features/auth/verify_email_screen_test.dart
docs/visuals/stage2/{login,register,forgot-password,verify-email,authenticated-home,login-short-window}.png
```

### Files modified

```
pubspec.yaml                        firebase_auth 7.0.1
lib/core/error/failure.dart         AuthFailureReason + `reason` on AuthFailure
lib/app/bootstrap_gate.dart         FirebaseReady → AuthGate
lib/app/router/app_routes.dart      login/register/forgot-password only; welcome,
                                    verify and home belong to the gate
lib/features/splash/presentation/splash_screen.dart
                                    navigation removed, onRevealComplete added
lib/features/welcome/presentation/welcome_screen.dart
                                    separate Get Started / Sign in destinations
lib/design/widgets/solovvo_button.dart
                                    label wrapped in Flexible + ellipsis
test/app/bootstrap_gate_test.dart   rewritten for AuthGate
test/features/splash_screen_test.dart  callback hand-over instead of navigation
test/features/welcome_screen_test.dart rewritten for the two destinations
```

### Files deleted

```
lib/features/auth/presentation/auth_entry_screen.dart
    Stage 1's placeholder; replaced by the four real screens
```

### Database changes

None. No Firestore collection, index or rule was touched — Stage 2 stores no
donor data. `firestore.rules` and `firebase.json` are unchanged, and no Firebase
console setting was modified from this machine.

### Packages added

| Package | Version | Reason |
| --- | --- | --- |
| `firebase_auth` | 7.0.1 | Email/password identity, email verification, password reset, session persistence. 7.x is the release line that pairs with the installed `firebase_core` 5.1.0. |

### Verification

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** |
| Unit + widget tests | `flutter test` | **102/102 passed** (57 in Stage 1) |
| Web build | `flutter build web --release` | **Built** `build/web` |
| Preview build for review | `flutter build web --release -t lib/preview_main.dart` | **Built**; entrypoint deleted after capture |
| Browser review | Chrome, 6 screens | Login, register, reset, verification and home render; 430×932 and a deliberately short 430×340 canvas; no console errors |

The suite covers, beyond the Stage 1 tests:

- Validators: empty, malformed, too-short, whitespace-only input; the confirm
  password mismatch is decided by the form, not the validator.
- Error mapping: every credential rejection collapses to one reason, throttling and
  connectivity are classified separately, an unknown code becomes
  `UnexpectedFailure` with the code retained in `debugMessage`, cause and stack
  trace survive.
- Messages: every `AuthFailureReason` has a distinct non-empty sentence, and no
  developer string leaks into user-visible copy.
- Gate: splash → welcome / verify / home, unresolvable stream keeps the splash, a
  stream error shows the retry view, sign-out returns to welcome, verification
  flips verify → home.
- Each form: empty submission does not call the backend, a rejected sign-in stays on
  the form and shows the failure, a successful sign-in lands on home, wrong
  confirmation blocks registration, a duplicate address is reported, reset swaps to
  the neutral confirmation panel, resend sends once and then refuses.
- `AuthScaffold`: on a 400×420 window the wordmark and heading stay inside the
  viewport, and a taller window still centres the body.

### Bugs found during verification and fixed

1. **`valueOrNull` does not exist in Riverpod 3.** The gate now checks
   `AsyncValue.hasValue` and then reads `AsyncValue.value`; a nullable payload makes
   that the only reliable discriminator between "signed out" and "not resolved".
2. **`signIn` returned the SDK's `User`.** Caught by the compiler; it now returns
   the mapped `AuthUser`.
3. **`RenderFlex overflowed by 99 pixels` in `SolovvoButton`.** A long label ("I've
   confirmed my email") plus the icon exceeded a 304 px phone width; the label is
   now `Flexible` with ellipsis. Found by the widget tests, not by eye.
4. **The gate stayed on the splash forever in 13 tests.** The reveal's `setState`
   lands during the frame that completes the animation, so a zero-duration follow-up
   pump never rebuilds. Diagnosed with a temporary probe, fixed by ending the
   hand-over helper with `pump(100 ms)`.
5. **The top of the login form could not be scrolled to.** `Center` inside
   `SingleChildScrollView` on a window shorter than the form left the wordmark and
   the heading outside the scrollable range. The frame now uses
   `LayoutBuilder` + `ConstrainedBox(minHeight)` + `Center`, which centres when the
   form fits and anchors to the top when it does not. Covered by two tests.
6. **A reported "validation error on load" on the reset screen did not reproduce.**
   A first browser pass claimed the email field was already red with "Enter your
   email address" before any interaction. Re-captured with a strict no-interaction
   script in a fixed-size canvas: no error state, no red border. The initial
   screenshot had been taken after automation had clicked the button. No code
   change; the report would have been wrong.

### Remaining issues

1. **No runtime test against the real Firebase project.** No emulator, no test
   account, and the browser pass used an in-memory stub (the web target cannot
   initialise Firebase yet). Everything below the repository boundary is tested;
   the network path is not. The first real sign-in on a device is the first
   integration test.
2. **Email/password sign-in is assumed to be enabled** in the Firebase console.
   Not verifiable from this machine. If it is off, every form correctly reports
   `operationNotAllowed` rather than failing silently.
3. **Email verification delivery depends on the console's SMTP settings.** On the
   Spark plan the default sender is rate-limited; a throttled send surfaces as
   `RateLimitedFailure` and is shown to the user, but cannot be fixed in app code.
4. **The web target still has no Firebase JS SDK**, so `main.dart` cannot boot on
   web. Screens were reviewed through a stub entrypoint that has been deleted.
5. **`HomeScreen` is a Stage 2 landing pad**, not a dashboard. Stage 4 replaces it.
6. **No Bangla or dark theme yet** (Stage 3). All copy is hard-coded English behind
   `auth_messages.dart` and the screen strings, so localisation is a mechanical
   follow-up rather than a rewrite. *Resolved in Stage 3.*
7. **iOS remains unverified** (Windows host).
8. Carried over: broken Firebase CLI, `com.example.*` applicationId, no push
   notifications on Spark, `firebase_core` KGP warning, 146.8 MB debug APK.

### Next stage

**Stage 3 — Bangla/English & dark/light theme.** Completed; see the Stage 3 section
below.

---

## Stage 3 — Bangla/English & Dark/Light Theme

### Decisions taken before any code was written

| Question | Choice | Why |
| --- | --- | --- |
| How to localise | `gen_l10n` + ARB files, generated in tree | Typed getters make a missing string a compile error; no key strings at call sites; `flutter_localizations` gives framework copy (`bn` Material strings) for free |
| Where the switchers live | One shared "Appearance & language" sheet, opened from a header icon on Welcome **and** Home | A Bengali speaker can change language *before* the English sign-up flow; Stage 7 re-hosts the same widget in Settings instead of growing a second copy |
| Bengali font | The platform face (Noto Sans Bengali / Kohinoor Bangla), nothing bundled | Correct on both targets; bundling would add ~500 KB per install for a rendering path the OS already provides. Risk recorded as an open item |

### Completed

- **`SolovvoPalette`, a `ThemeExtension`.** Semantic roles (`surface`,
  `surfaceMuted`, `textPrimary`, `textSecondary`, `brandInk`, `brandTint`,
  `onBrandTint`, `outline`, `outlineStrong`, `danger`, `success`, `warning`, …)
  with `light` and `dark` instances, read as `context.palette.<role>`. A role
  missing from a theme is a compile error, and Flutter interpolates the extension
  during the theme animation so switching fades instead of flashing.
- **`AppTheme.dark`.** Not an inversion: brand ink becomes a rose that reads on
  charcoal, surfaces step down to a warm near-black instead of pure black, status
  colours are re-picked for contrast, and `onPrimary` flips to a dark ink so a
  filled button is legible on the lighter rose.
- **Every design primitive migrated** — card, button, text field, mark, background,
  chip — so no screen names a raw colour. `AppColors` survives as the brand ramp
  for theme-invariant values only (the mark drawn on the brand disc).
- **Localisation scaffolding.** `generate: true`, `l10n.yaml`, `lib/l10n/app_en.arb`
  and `app_bn.arb` (~90 keys each), output to `lib/l10n/generated`, plus
  `context.l10n` as the single access path. `untranslated.json` is `{}`.
- **Typed validation.** `AuthValidators` now returns `AuthFieldIssue?` instead of
  prose, and `auth_messages.dart` renders it. Because a form stores the *rule* it
  broke, an error already on screen re-renders in the newly chosen language.
- **Every screen migrated** to `context.l10n`: splash, welcome, login, register,
  forgot password, verification, home, both gate failure views, the error banner
  and the auth scaffold (back tooltip now comes from `MaterialLocalizations`).
- **The joined date** on home uses `MaterialLocalizations.formatShortMonthDay`
  rather than `intl.DateFormat`, so no locale data has to be initialised before the
  first frame.
- **Preferences.** `PreferencesStore` (shared_preferences, enum *names* not
  indices), `themeModeProvider` and `localeProvider`, loaded once in `bootstrap()`
  before `runApp` — the first painted frame is already in the saved theme and
  language.
- **`AppearanceSheet`** with two languages and three theme modes, the active row
  derived from `Localizations.localeOf(context)` so "follow the device" highlights
  truthfully; capped at 520 px so it does not become a tablet-wide bar.
- **No language escaping the framework**: `SolovvoApp` is the only widget reading
  the two providers; everything below sees `Theme.of(context)` and `context.l10n`.

### Files created

```
lib/design/tokens/app_palette.dart
lib/l10n/app_en.arb
lib/l10n/app_bn.arb
lib/l10n/l10n.dart
lib/l10n/untranslated.json                  (generated; must stay {})
lib/l10n/generated/app_localizations*.dart  (generated, checked in)
l10n.yaml
lib/core/preferences/app_preferences.dart
lib/app/appearance_sheet.dart
test/support/test_app.dart
test/core/preferences_test.dart
test/app/appearance_sheet_test.dart
test/app/app_personalisation_test.dart
test/features/auth/localised_auth_test.dart
test/l10n/arb_parity_test.dart
test/review/visual_review_test.dart         (opt-in screenshot harness)
docs/visuals/stage3/*.png                   (10 renders, see Verification)
docs/visuals/stage3-browser/*.png           (10 real-browser captures)
```

### Files modified

```
pubspec.yaml                     flutter_localizations, intl, shared_preferences,
                                 generate: true
lib/design/app_theme.dart        light + dark from the palette; filled button,
                                 bottom sheet and selection themes
lib/design/tokens/app_typography.dart
                                 textThemeFor(palette) instead of a const theme
lib/design/widgets/{solovvo_card,solovvo_button,solovvo_field,blood_drop_mark,
                    soft_glow_background}.dart
                                 palette roles instead of AppColors
lib/app/app.dart                 ConsumerWidget; reads themeMode + locale
lib/app/bootstrap.dart           PreferencesStore.load() before runApp, override
lib/app/bootstrap_gate.dart      localised failure view, palette colours
lib/app/auth_gate.dart           localised error view, palette colours
lib/features/auth/domain/auth_validators.dart   returns AuthFieldIssue
lib/features/auth/presentation/auth_messages.dart   issue → sentence, failure → sentence
lib/features/auth/presentation/{login,register,forgot_password,
                                verify_email}_screen.dart
lib/features/auth/presentation/widgets/{auth_scaffold,auth_error_banner}.dart
lib/features/welcome/presentation/welcome_screen.dart
lib/features/home/presentation/home_screen.dart
lib/features/splash/presentation/splash_screen.dart
test/support/auth_harness.dart   locale/themeMode/preferences parameters
test/features/auth/auth_validators_test.dart      rewritten around AuthFieldIssue
test/features/auth/auth_error_mapper_test.dart    English catalogue + Bangla coverage
test/features/{+app,features/auth}/*_test.dart    harness migration to testApp
test/design/app_theme_test.dart  dark theme + palette lerp/copyWith groups
docs/ARCHITECTURE.md             new §5 theming & languages; §4 updated; packages
docs/PROJECT_STATE.md            this section
README.md                        languages, themes, how to add a string
```

### Files deleted

```
None.
```

### Database changes

None. `firestore.rules` and `firebase.json` are untouched; no Firebase console
setting was modified. Theme and language preferences are device-local
(`shared_preferences`), deliberately not stored in Firestore: they must survive a
signed-out state and must be readable before the first authenticated read.

### Packages added

| Package | Version | Reason |
| --- | --- | --- |
| `flutter_localizations` | SDK | Material/Cupertino strings for `bn`; `gen_l10n` delegate |
| `intl` | 0.20.3 | Used by the generated `AppLocalizations` |
| `shared_preferences` | 2.5.6 | Persist the two choices across launches |

### Verification

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** |
| Unit + widget tests | `flutter test` | **149 passed, 10 skipped** (the skipped ones are the opt-in screenshot harness) |
| Translation completeness | `lib/l10n/untranslated.json` | `{}` — zero keys present in English and missing in Bengali |
| Web build | `flutter build web --release` | **Built** `build/web` |
| Android debug build | `flutter build apk --debug` | **Built** `build/app/outputs/flutter-apk/app-debug.apk` |
| Visual review, 4 combinations | `SOLOVVO_VISUAL_REVIEW=1 flutter test test/review/visual_review_test.dart` | 10 renders at 430×932 in `docs/visuals/stage3/` |
| Visual review, real browser | headless Chrome at 430×932 against `build/web`, driven over the DevTools protocol | 10 captures in `docs/visuals/stage3-browser/` — both languages, both themes, the sheet, and the sign-in form |

The suite covers, beyond the Stage 2 tests:

- **Catalogue parity**: identical key sets, every `{placeholder}` preserved, no
  Bengali message left as its English sentence, the same numbers in both languages,
  Bengali numerals (`৮`) rather than Western digits, and `untranslated.json` empty.
- **Palette**: the dark theme is dark, flips its surfaces, swaps brand ink for the
  rose, re-picks status colours, and ships as a theme extension; `lerp` swaps
  surfaces at the midpoint and `copyWith` leaves untouched roles alone.
- **Persistence**: defaults are `system` + follow-the-device, both choices
  round-trip through a relaunch, an undecodable stored value degrades to the
  default instead of throwing, values are stored as enum names, re-selecting the
  current value neither notifies nor rewrites, and an un-overridden store throws a
  message that names the missing override.
- **The sheet**: offers both languages and all three modes, marks the *active*
  rows (including when following a Bengali device), re-renders its own copy in
  Bengali while still open, repaints the app behind it, repaints *itself* when the
  theme is switched from inside it, and stays 520 px wide on a tablet and
  overflow-free at 280 px.
- **End to end through `SolovvoApp`**: a language chosen at the door carries into
  the pushed sign-up form, dark repaints the screen below the navigator, a saved
  choice is in effect on the very first frame of the brand reveal, and the system
  brightness drives the palette when nothing is stored.
- **Auth in Bengali**: the form opens translated, validates in Bengali, reports a
  rejected sign-in in Bengali, and an error already on screen follows a live
  language change.

### Bugs found during verification and fixed

1. **`Override` is not exported by `flutter_riverpod` 3.4.3.** A test helper that
   took an `extraOverrides` list could not name the type. Removed the parameter;
   callers inline their own `ProviderScope`, so the literal's type is inferred.
2. **`toImage` never completes inside a widget test's fake-async zone.** The
   screenshot harness hung until the capture was moved inside `tester.runAsync`.
3. **The choice tiles were silent to a screen reader.** `ExcludeSemantics` kept the
   option to one node but also dropped the label, so a tile announced as
   "button, selected" with no name. The label is now declared on the `Semantics`
   node itself.
4. **`SharedPreferences` mocked values initially deadlocked the store test** — the
   binding has to be initialised before the platform channel is touched.
5. **Choosing Dark left the sheet's own surface cream.** Found in the browser pass,
   not by any test: `showModalBottomSheet` was given `backgroundColor:
   context.palette.surface`, a colour resolved once when the sheet opened. The
   route paints that background, so switching the theme from *inside* the sheet
   repainted every label and tile inside it but not the card they sit on — pale
   dark-mode text on cream, in the one place a user changes the theme. The
   argument is gone; the colour now comes from `AppTheme`'s `bottomSheetTheme`,
   which is rebuilt per palette. Regression test added (asserts the `BottomSheet`'s
   painted colour), and the fixed flow is in
   `docs/visuals/stage3-browser/05-sheet-dark-after-switching-bn.png`.

### Remaining issues

1. **Bengali typography is only as good as the device.** No font is bundled. The
   review renders used Nirmala UI (the Windows face); Noto Sans Bengali on Android
   and Kohinoor Bangla on iOS have close but not identical metrics. Layout was
   checked at 280 px, 320 px, 430 px and tablet width with no clipping, but a
   real-device pass is still owed before Stage 14.
2. **The pixel review is Chromium-only.** The four combinations were checked twice:
   through Flutter's own rasteriser (deterministic, in `docs/visuals/stage3/`) and
   in a real headless Chrome against the built web app
   (`docs/visuals/stage3-browser/`). The second pass is the one that caught the
   sheet-surface bug in item 5 above. Not covered: Android's Noto Sans Bengali and
   iOS's Kohinoor Bangla metrics, touch and scroll behaviour, and any signed-in
   screen — there is no test account in this environment.
3. **No third language yet.** The sheet hard-codes two rows. Adding one is an ARB
   file plus one `_Choice`; it is not modelled as an open list because a language
   selector with unsupported entries is worse than a short correct one.
4. **`ThemeMode.system` follows `platformBrightness` at launch**, and Flutter
   rebuilds the app when the OS toggles it. Verified in tests via the platform
   dispatcher; not verified on a device that changes theme while the app is open.
5. Carried over: no runtime Firebase test, email/password assumed enabled in the
   console, throttled verification mail on Spark, `HomeScreen` is still a landing
   pad, iOS unverified, broken Firebase CLI, `com.example.*` applicationId,
   `firebase_core` KGP warning. The web target declares no Firebase script in
   `web/index.html`; it nevertheless boots to the welcome screen (the JS SDK is
   fetched at runtime), so Stage 2's "web cannot boot" note is out of date — but no
   Firestore read has been exercised on web.

### Next stage

**Stage 4 — Home dashboard UI.** Completed; see the Stage 4 section below.

---

## Stage 4 — Home Dashboard UI

### Decisions taken before any code was written

| Question | Choice | Why |
| --- | --- | --- |
| Where the dashboard's data comes from | Three provider *seams* (`donorSnapshotProvider`, `nearbyRequestsProvider`, `feedPreviewProvider`), all empty in this stage | The screen gets its empty and populated paths on day one, and the stage that owns each collection replaces one provider instead of rewriting the layout. A hard-coded sample row would be indistinguishable from real data on a screenshot, and "12 requests nearby" shown before anything was queried is a lie someone could act on |
| Which sections | The full donor dashboard: header, verified chip, greeting, status strip, the two headline actions, nearby requests, community preview, sign-out | The brief's home screen is a work surface, not a menu. Sections that will fill later are rendered empty rather than omitted, so their placement is settled now |
| Navigation | **No** bottom navigation bar | Stage 7 owns the app shell. A bar with four dead tabs would be worse than none, and adding it later would move every element on this screen once |

### Completed

- **`home` is now a three-layer feature.** `domain` holds three immutable view
  models — `DonorSnapshot` (four nullable facts), `NearbyRequestSummary`
  (`id`, `bloodGroup`, `area`, `neededBy`, `units`) and `FeedPostPreview`
  (`id`, `authorName`, `excerpt`, `createdAt`). They are view models, not Firestore
  documents: each carries only the fields the widget that renders it can show.
- **`application` holds the three seams.** All three providers are deliberately
  synchronous and return `null` / `const []`; each section will get its own async
  state when it gets data, rather than a page-level spinner over three surfaces
  that will eventually fetch independently.

  *Note for a reader of this record: the shape described here still holds and the
  `const []` no longer does. `feedPreviewProvider` became a synchronous projection
  of the feed's `FeedController` in Stage 8.3 hardening Step 4 (2026-11-03), and the
  community section grew its own spinner, error card and empty card — one section,
  not a page-level overlay. `nearbyRequestsProvider` became the same kind of
  projection in Stage 9.1 — the `take(3)` head of `requestsControllerProvider`'s
  window, still a synchronous `Provider<List<BloodRequest>>` so a layout test can
  still override it with a plain list — and `blood_requests` is read now, by that
  entry at the end of this file.*
- **`DonorStatusCard`.** Blood group, last donation and availability in one card,
  with `null` rendering "Not set yet" instead of a `0` or an invented group. A
  wrong blood group on a donor dashboard is a medical-severity mistake, so no
  value is ever fabricated. A donation count renders as an ICU-plural phrase; a
  donor who has never given reads "No donations yet" rather than a blank date.
- **`HomeQuickActions`.** "Request blood" and "Find donors". Both are real,
  enabled buttons whose screens do not exist yet, so the tap shows a localised
  "Coming soon" — a disabled button would read as a bug and a fake screen would
  be a lie.
- **`HomeHeader`** — wordmark and the shared `AppearanceButton`. No avatar
  (it would be a letter derived from an email until Stage 5) and no notification
  bell (nothing behind it until Stage 11).
- **`VerifiedChip`** is rendered only when `user.isEmailVerified` is true; the
  badge is not decoration.
- **Sections.** `HomeSectionHeader` takes its trailing action as a parameter, so
  "Nearby requests" omits "See all" over an empty list instead of linking to
  nothing. `HomeEmptyCard` is muted and shadowless: an empty section should read
  as calm and finished, not as a failed card.
- **`NearbyRequestCard`** shows only what the summary carries — group, area, units,
  date. No distance, recipient name or live status, because none of those exist
  until the request is actually read (Stage 9).

  *Dated correction, Stage 9.1: the request is read now. `NearbyRequestCard` and its
  `NearbyRequestSummary` view model were deleted and the dashboard renders the
  feature's own `RequestTile` instead, so there is one row design for one entity. The
  section is titled **Open requests** rather than "near you", because no distance is
  computed, and the tile still shows no recipient name — that part of the Stage 4
  reasoning was correct and was made permanent in the read model.*
- **`FeedPostCard`** with an initials avatar, author, date and a two-line excerpt.
- **Responsive.** One `LayoutBuilder` decides everything: below 720 dp the
  sections stack inside a 560 dp column; at 720 dp and above they pair inside
  900 dp and the two actions sit side by side instead of stretching full width.
- **Localisation and theming carry over unchanged.** Every string is from
  `context.l10n`; every colour is a `SolovvoPalette` role. Counts and dates come
  through the catalogue, so Bengali gets Bengali numerals (`৩ বার রক্তদান`,
  `২ ইউনিট দরকার`) without any widget knowing the language. Dates use
  `MaterialLocalizations.formatShortMonthDay`.
- **Authentication is untouched.** `HomeScreen` still signs out through
  `authRepositoryProvider` and still shows `AuthErrorBanner` when the sign-out is
  rejected; `AuthGate` still owns the session → screen decision.

### Files created

```
lib/features/home/domain/home_dashboard.dart
lib/features/home/application/home_providers.dart
lib/features/home/presentation/widgets/home_header.dart
lib/features/home/presentation/widgets/donor_status_card.dart
lib/features/home/presentation/widgets/home_quick_actions.dart
lib/features/home/presentation/widgets/home_section.dart
lib/features/home/presentation/widgets/home_cards.dart
test/features/home/home_screen_test.dart
docs/visuals/stage4/*.png                  (8 widget renders)
docs/visuals/stage4-browser/*.png          (8 real-browser captures)
```

### Files modified

```
lib/features/home/presentation/home_screen.dart   rewritten from the Stage 2
                                                  landing pad into the dashboard
lib/l10n/app_en.arb            home dashboard keys; homeUnitsNeeded and
                               homeDonationsCount became ICU plurals with a
                               decimalPattern count
lib/l10n/app_bn.arb            the same keys in Bengali; homeNeededBy changed
                               from "{date} এর মধ্যে প্রয়োজন" to
                               "শেষ তারিখ: {date}"
lib/l10n/generated/*           regenerated by gen_l10n (not hand-edited)
test/app/auth_gate_test.dart   ensureVisible before the Sign-out tap
test/review/visual_review_test.dart   size / donor / requests / feed parameters
                                      and a "home dashboard" render group
docs/ARCHITECTURE.md           feature table, the seam rule, the number rule
docs/PROJECT_STATE.md          this section
README.md                      status and dashboard pointer
```

### Files deleted

```
lib/preview_main.dart   temporary review entrypoint, used only to photograph the
                        dashboard past the auth gate; deleted after capture
```

### Database changes

None. `firestore.rules`, `firebase.json` and `google-services.json` are untouched,
no Firestore collection or index was created, and no Firebase console setting was
modified. The dashboard reads no database at all in this stage — which is why the
three providers are empty rather than optimistic.

### Packages added

None. `flutter_riverpod`, `flutter_localizations`, `intl` and
`shared_preferences` were already present from Stages 0 and 3.

### Verification

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** |
| Unit + widget tests | `flutter test` | **172 passed, 18 skipped** (the skipped ones are the opt-in screenshot harness; 149/10 in Stage 3) |
| Translation completeness | `lib/l10n/untranslated.json` | `{}` |
| Web build | `flutter build web --release` | **Built** `build/web` — `main.dart.js` 3,066,085 bytes, 188.7 s |
| Android debug build | `flutter build apk --debug` | **Built** `build/app/outputs/flutter-apk/app-debug.apk` (181,743,245 bytes ≈ 173.3 MB, 47.6 s) |
| Visual review, widget renders | `SOLOVVO_VISUAL_REVIEW=1 flutter test test/review/visual_review_test.dart` | 8 dashboard renders in `docs/visuals/stage4/`: four theme × language combinations empty, populated light/en, populated dark/bn, 900×1100 tablet, 320×640 Bengali |
| Visual review, real browser | headless Chrome at 430×932 (900×1100 for the tablet frame) against a web build of a temporary preview entrypoint, driven over the DevTools protocol | 8 captures in `docs/visuals/stage4-browser/`, including a scrolled frame that proves the page scrolls and the singular reads "1 unit needed" |

The suite covers, beyond the Stage 3 tests:

- **Empty state**: the greeting, the verified chip (present when confirmed, absent
  when not), the address fallback name, three "Not set yet" values, both actions
  present and both reporting "Coming soon", two `HomeEmptyCard`s, and **no**
  "See all".
- **Populated state**: the status strip reads `O+` / a short date / "Available" /
  "3 donations"; a donor with a zero count and no date reads "No donations yet"
  and "Not available"; a request row shows group, area, units and date and leaves
  the other section empty; "See all" appears only when the list is not empty; a
  feed card shows the right initials.
- **Copy correctness**: `1 donation` and `1 unit needed` in the singular, and
  neither `1 donations` nor `1 units` anywhere.
- **Bengali**: the whole dashboard in Bengali and `৩ বার রক্তদান` /
  `২ ইউনিট দরকার` — Bengali numerals, not Western ones.
- **Layout**: stacked below `HomeScreen.twoColumnBreakpoint` and side by side
  above it; actions stacked on a phone and paired when wide; the three status
  values share a baseline at 320 dp in Bengali; 320 dp empty and populated render
  with no overflow.
- **Theme**: a card paints `palette.surface` in light and the dark surface in
  dark.
- **Sign-out**: a rejected sign-out shows `AuthErrorBanner` and stays on the
  dashboard.

### Bugs found during verification and fixed

1. **`expect(repo.signOutCalls, 1)` started failing in `auth_gate_test`.** The
   dashboard is taller than the 400×900 window the gate test uses, so the Sign-out
   button had moved below the fold and `tester.tap` hit nothing. The test now
   calls `ensureVisible` and pumps before tapping — a real property of the new
   screen, not a flake.
2. **"1 units needed".** The plural was a missing catalogue branch, not a layout
   problem. `homeUnitsNeeded` and `homeDonationsCount` became ICU plurals.
3. **Bengali counts rendered Western digits** while the Bengali date beside them
   rendered `৯`. The count placeholders were plain `String`s; declaring them
   `"type": "num"` with `"format": "decimalPattern"` makes gen_l10n emit
   `NumberFormat.decimalPattern(localeName)` per locale, so the widget formats
   nothing and Bengali gets `২`.
4. **"{date} এর মধ্যে প্রয়োজন" was ungrammatical** with an abbreviated month
   ("৯ নভে এর মধ্যে") because the genitive clitic cannot be space-separated.
   Rewritten as "শেষ তারিখ: {date}".
5. **At 320 dp in Bengali the third status value dropped out of line** with the
   other two: "সর্বশেষ রক্তদান" wraps where "Last donation" does not, and a `Row`
   of three tiles puts each value on its own baseline. Replaced with a two-row
   `Table` (labels / values), asserted by comparing `getTopLeft(...).dy`.
6. **The two actions stretched to 852 px on a tablet**, reading as banners. They
   are now paired side by side above the breakpoint; asserted by a test.

Items 2–6 were all found by looking at the rendered images, not by the tests that
existed at the time; each then became an assertion.

### Remaining issues

1. **The dashboard has no real data.** Every section is empty until Stages 5/8,
   9 and 6. That is the stage's design, but it means "the dashboard works" has
   only been verified against provider overrides.
2. **The browser pass used a temporary entrypoint.** The dashboard is behind the
   auth gate and there is no test account in this environment, so the web build
   that was photographed mounted `HomeScreen` directly with a const `AuthUser`.
   The layout, theme, language and scrolling are real; the session in front of
   them is not. The entrypoint has been deleted.
3. **No real-device or iOS verification.** Windows host, no emulator. Bengali
   metrics on Noto Sans Bengali / Kohinoor Bangla are unverified; the renders used
   Nirmala UI.
4. **Scrolling was verified in the browser and in tests, not by touch.** The
   web capture scrolled with a synthetic mouse wheel; momentum, overscroll and
   pull-to-refresh on a device are still owed.
5. **"Coming soon" is a placeholder by design.** Four controls (both headline
   actions, "See all", and every request and feed row) report it. They are the
   entry points Stages 6, 9 and 10 fill.
6. Carried over: no runtime Firebase test, throttled verification mail on Spark,
   iOS unverified, broken Firebase CLI, `com.example.*` applicationId,
   `firebase_core` KGP warning, ~173 MB debug APK, no third language, Bengali
   font not bundled.

### Next stage

**Stage 5 — User profile system.** Completed; see the Stage 5 section below.

---

## Stage 5 — User Profile System

### Decisions taken before any code was written

| Question | Choice | Why |
| --- | --- | --- |
| Where private fields live | A **private subcollection** `users/{uid}/private/profile`, not flags on the public document | `users/{uid}` is readable by every signed-in account, so a `showPhone: false` flag would protect nothing: the number is still in a document anyone can fetch. Privacy has to be placement |
| Profile photo | Displayed, never written | No image storage is wired until Stage 6. The field is rendered when it exists and carried across a save unchanged; the form says photo upload "arrives with photo upload" rather than offering a control that cannot work |
| The dashboard's donor strip | Wired to the real profile and history **in this stage** | `donorSnapshotProvider` was a seam waiting for exactly this data. A dashboard reading "Not set yet" beside a profile that had just been filled in would be a visible lie |
| Donation history | Read-only, and statistics count **confirmed** records only | Records are written by the request flow (Stages 10/11), the only path the rules allow. A `pending` row is the donor's own claim; counting it would overstate what the person has given |
| Editing | One form for create and update | "No profile yet" and "profile exists" differ by a document, not by a workflow. A separate first-run wizard would be a second form to keep in step |
| Completion indicator | Counts the seven fillable fields, and names the **missing** ones | A percentage alone invites the donor to guess. Naming them turns the card into a to-do list, and nothing is invented to make the number look better |

### Completed

- **`profile` is a four-layer feature.** `domain` holds `UserProfile` (one model
  for two documents), `DonationRecord` / `DonationHistory`, `ProfileValidators`
  and the `ProfileRepository` interface; `data` holds `ProfileDocuments` (the
  exact map written to, and read from, each document), `FirestoreProfileRepository`
  and `firestore_error_mapper.dart`; `application` holds the three providers and
  `ProfileController`; `presentation` holds the screen, the edit form and six
  widgets.
- **The privacy split is real, not cosmetic.** Phone, street address, date of
  birth, gender and the publication flag are written only to the owner-only
  subcollection. `area` is written to both: the private copy is the source of
  truth, the public copy exists only while "show my area" is on, and switching it
  off writes `FieldValue.delete()` so the value becomes unreadable rather than
  merely hidden.
- **Editing cannot be pointed at someone else.** `ProfileRepository` has no `uid`
  parameter — every call is addressed from `FirebaseAuth.currentUser` — and
  `saveProfile` refuses a payload naming a different account. The screens take a
  `UserProfile?` for the form's initial values and nothing else.
- **`ProfileScreen`.** Identity card (initials avatar, name, blood-group badge,
  area, verified chip, sign-in email), completion card, availability card,
  personal details with per-field `Private` markers, the privacy card, and the
  donation history. Above 720 dp the cards pair into two columns at the dashboard's
  breakpoint; below it they stack.
- **`ProfileEditScreen`.** Name, blood group chips (the eight the rules accept),
  phone, area, address, date of birth (date picker, clearable), gender chips, the
  area-publication switch and the sign-in email as read-only. Validation runs on
  save and then live, so a field does not turn red while it is being typed for the
  first time.
- **Availability is a manual switch and nothing else.** It writes three fields
  (`isAvailable`, `role`, `updatedAt`), is disabled while a write is in flight so
  two half-applied writes cannot race, and is not shown as flipped until the write
  succeeds. A donor with no blood group sees a warning instead of a switch that
  would make them unmatchable.
- **Honesty rules on screen.** "Not set yet" wherever a value is genuinely absent;
  no `0 donations` (the card reads "No donations yet"); pending records listed but
  excluded from the count; the completion card names what is missing instead of
  rounding up; a failed history read shows "Try again" rather than an empty list.
- **Nothing is written to `donation_history`.** The list is read-only by design.
- **Design system reused, not extended.** `SolovvoCard`, `SolovvoButton`,
  `SolovvoTextField`, `ErrorBanner`, `EmptyStateCard`, `SectionHeader`,
  `InitialsAvatar`, `BloodGroupBadge`, `SoftGlowBackground`, `AppSpacing`,
  `AppRadius` and `SolovvoPalette` — no new token, no new colour.
- **Home wiring.** `HomeHeader` gained the avatar entry point that opens
  `ProfileScreen`; `donorSnapshotProvider` now projects the profile and history
  instead of returning `null`; the greeting prefers the profile's name over the
  account's.
- **Localisation carried over.** ~50 new keys in both catalogues, counts through
  the catalogue so Bengali reads `২ টি রক্তদান`, dates through
  `MaterialLocalizations`.

### Files created

```
lib/features/profile/domain/user_profile.dart
lib/features/profile/domain/donation_record.dart
lib/features/profile/domain/profile_validators.dart
lib/features/profile/domain/profile_repository.dart
lib/features/profile/data/profile_documents.dart
lib/features/profile/data/firestore_profile_repository.dart
lib/features/profile/data/firestore_error_mapper.dart
lib/features/profile/application/profile_providers.dart
lib/features/profile/presentation/profile_screen.dart
lib/features/profile/presentation/profile_edit_screen.dart
lib/features/profile/presentation/profile_messages.dart
lib/features/profile/presentation/widgets/profile_identity_card.dart
lib/features/profile/presentation/widgets/profile_completion_card.dart
lib/features/profile/presentation/widgets/profile_availability_card.dart
lib/features/profile/presentation/widgets/profile_details_card.dart
lib/features/profile/presentation/widgets/profile_privacy_card.dart
lib/features/profile/presentation/widgets/donation_history_section.dart
lib/design/widgets/initials_avatar.dart
lib/design/widgets/blood_group_badge.dart
lib/design/widgets/section_header.dart
lib/design/widgets/empty_state_card.dart
lib/design/widgets/error_banner.dart
test/support/fake_profile_repository.dart
test/features/profile/profile_validators_test.dart       (18 tests)
test/features/profile/user_profile_test.dart             (15)
test/features/profile/donation_record_test.dart          (8)
test/features/profile/profile_documents_test.dart        (22)
test/features/profile/firestore_error_mapper_test.dart   (9)
test/features/profile/profile_screen_test.dart           (21)
test/features/profile/profile_edit_screen_test.dart      (15)
test/features/home/home_profile_test.dart                (7)
docs/visuals/stage5/*.png                               (12 widget renders)
docs/visuals/stage5-browser/*.png                       (8 browser captures)
```

### Files modified

```
pubspec.yaml                   + cloud_firestore 7.1.0
lib/l10n/app_en.arb            ~50 profile keys; completion and history counts
lib/l10n/app_bn.arb            the same keys in Bengali, Bengali numerals
lib/l10n/generated/*           regenerated by gen_l10n (not hand-edited)
lib/features/home/presentation/home_screen.dart      passes the user's profile in
lib/features/home/presentation/widgets/home_header.dart  avatar entry point
lib/features/home/presentation/widgets/home_section.dart  HomeSectionHeader and
                                                          HomeEmptyCard became
                                                          aliases over the shared
                                                          design widgets
lib/features/home/application/home_providers.dart    donor strip now projects the
                                                     profile + history
lib/features/profile/presentation/widgets/profile_completion_card.dart
                               count wrapped in Flexible (320 dp Bengali overflow)
test/support/auth_harness.dart          profile override
test/features/home/home_screen_test.dart  profile parameter
test/review/visual_review_test.dart     appBarTheme font patch + profile group
docs/ARCHITECTURE.md           new §12 profile data model and privacy; §2, §3, §10
docs/PROJECT_STATE.md          this section
README.md                      status and profile pointer
```

### Files deleted

```
lib/preview_main.dart   temporary review entrypoint used only to photograph the
                        profile past the auth gate; deleted after capture
```

### Database changes

**None deployed.** `firestore.rules`, `firebase.json` and `google-services.json`
are untouched, no collection or index was created, no console setting changed and
nothing was deployed. The documents written are ones the existing rules already
govern: `users/{uid}` (owner write, any signed-in read) and
`users/{uid}/private/profile` (owner only). `donation_history` is read only.

### Packages added

| Package | Version | Why |
| --- | --- | --- |
| `cloud_firestore` | 7.1.0 | The first stage that needs a database. The profile cannot be read without it, and it is the official FlutterFire plugin for the collection the rules already define |

No paid service, no Blaze upgrade, no storage package (Stage 6).

### Verification

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** |
| Unit + widget tests | `flutter test` | **287 passed, 32 skipped** (172/18 in Stage 4; the 32 skips are the opt-in screenshot harness) |
| Translation completeness | `lib/l10n/untranslated.json` | `{}` |
| Web build | `flutter build web --release` | **Built** `build/web` — `main.dart.js` 3,574,787 bytes, 187.6 s |
| Android debug build | `flutter build apk --debug` | **Built** `app-debug.apk` (182,206,206 bytes ≈ 173.8 MB, 259.9 s) |
| Visual review, widget renders | `SOLOVVO_VISUAL_REVIEW=1 flutter test test/review/visual_review_test.dart` | 12 profile renders in `docs/visuals/stage5/`: four theme × language combinations populated, two empty, whole page with history in light/en and dark/bn, 900×1100 tablet, 320×640 Bengali, both edit-form states |
| Visual review, real browser | headless Chrome at 430×932 (900×1100 tablet, 320×640 narrow) against a web build of a temporary preview entrypoint, driven over the DevTools protocol | 8 captures in `docs/visuals/stage5-browser/`, including a scrolled frame showing the donation history; **no console errors** |

The suite covers, beyond the Stage 4 tests:

- **Documents**: the exact public and private field sets (no private field in the
  public map), `area` published only while the switch is on, the canonical private
  area preserved, date of birth pinned to UTC midnight, `FieldValue.delete()` for
  every empty value, reading `null` for a missing public document, tolerating a
  missing private one, and an unknown donation `status` read as `pending`.
- **Validators**: empty/whitespace/one-character names, phone shapes that could
  and could not be dialled (`+8801…`, `01…`, spaces and dashes), area length,
  and that no rule fires on an untouched field.
- **Model**: completion counts per field, blank strings and unknown blood groups
  treated as missing, `copyWith` not widening what it was not given, value equality.
- **Profile screen**: the create prompt when no document exists (and that its CTA
  opens the form seeded with the sign-in name), the populated layout with four
  `Private` markers, availability written on toggle and **not** shown flipped when
  the write is rejected, the missing-blood-group warning, the privacy switch
  refusing to publish without an area and withdrawing publication through the full
  save, empty history, confirmed + pending history with the count excluding
  pending, a failed history read with a working retry, a stream error that is not
  misread as "no profile", Bengali labels and numerals, no overflow at 320 dp, and
  two columns at 720 dp.
- **Edit form**: prefill (including the read-only email), chosen chips and switch,
  each validation rule, no premature error while typing, the full payload written
  to the session's own uid with `photoUrl`/`isAvailable` carried across, the
  confirmation and the pop, a rules rejection staying on the form with a translated
  reason, the live stream never overwriting what is being typed, the date picker
  (pick and clear), the publication switch needing an area, and Bengali labels and
  rules.
- **Dashboard seam**: the strip built from the real profile and history, no
  invented count, the strip following an emitted change, the honest empty strip,
  the greeting preferring the profile name, and the header avatar opening the
  profile.

### Bugs found during verification and fixed

1. **`RenderFlex overflowed by 87 pixels` in the completion card at 320 dp in
   Bengali.** The header is a `Row` with the title and the count; the Bengali count
   ("৭ টির মধ্যে ৫ টি পূর্ণ হয়েছে") is longer than the English one and neither side
   could shrink. Found by the layout test, not by eye, and fixed in the widget —
   the count is now `Flexible` with `TextAlign.end` — not in the test.
2. **The edit form's save button was found by its English label.** In Bengali the
   finder matched nothing. Changed to `find.byType(SolovvoButton)`, which is also
   what the form asserts about itself: one save action.
3. **"Confirms and returns" still saw the form on screen.** The test pumped one
   frame after the save and read the tree during the pop transition; a second pump
   of 500 ms lets the route finish. A test-timing bug, but it mirrors what a slow
   device does.
4. **A history-retry test had nothing to retry.** The failure was installed after
   the first frame, by which time the read had already succeeded. The failure is now
   configured on the repository before the screen is mounted.
5. **The visual harness rendered the app bar title as a solid black bar.** The
   harness patches `textTheme` with a real font so glyphs render; the `AppBar`
   carries a *resolved* `titleTextStyle` built at theme-construction time, which
   that patch never reached. `appBarTheme.titleTextStyle` / `toolbarTextStyle` are
   now patched too. A harness bug, but it made every Stage 5 render unreadable at
   the one place a user looks first.
6. **Two of these (`_completeProfile` claiming completeness while missing a date
   of birth) were wrong fixtures rather than wrong code** — recorded because a
   fixture that asserts the opposite of its name is how a false "all green" starts.

### Remaining issues

1. **No runtime test against the real Firebase project.** Every test crosses the
   repository boundary and stops: `FakeProfileRepository` stands in for Firestore
   and there is no emulator run in this environment (the rules tests in
   `firestore-rules-tests/` need the emulator and were not run). The first real
   save and the first real history read on a device are still the first
   integration test.
2. **`firestore.rules` does not validate the profile's fields.** It checks
   ownership only, so the *client* is what keeps `role`, the eight blood groups and
   the private-document shape honest. That was already true before this stage and
   the brief forbade touching the rules; it is the first thing to fix in a
   hardening pass.
3. **The browser pass used a temporary entrypoint.** The profile is behind the
   auth gate and there is no test account here, so the photographed build mounted
   `ProfileScreen` against an in-memory repository with one fixed profile. Layout,
   theme, language and scrolling are real; the account and the backend are not. The
   entrypoint has been deleted.
4. **No real-device or iOS verification.** Windows host, no emulator. Bengali
   metrics are the Windows face (Nirmala UI), not Noto Sans Bengali or Kohinoor
   Bangla.
5. **Profile photo upload is deferred to Stage 6** by agreement. Until then a
   donor cannot add or change one, and the completion card will keep naming it as
   missing for anyone who has not set one elsewhere.
6. **Donation history is empty for every real account.** Nothing writes
   `donation_history` until the request flow is built (Stages 10/11), so the
   statistics path is verified against seeded test data only.
7. **`createProfile` is the first save.** An account that has never opened the
   profile has no document, so `blood_requests` matching rules (`role == 'donor'`)
   cannot see them — expected, but it means Stage 9 must send donors through the
   profile first.
8. Carried over: no push notifications on Spark, throttled verification mail,
   broken Firebase CLI, `com.example.*` applicationId, `firebase_core` KGP warning,
   ~173.8 MB debug APK, no third language, Bengali font not bundled, iOS unverified.

### Next stage

**Stage 6 — Profile photo upload (Supabase Storage).** Delivered below.

---

## Stage 6 — Profile Photo Upload (Supabase Storage)

### Decisions taken before any code was written

| Question | Choice | Why |
| --- | --- | --- |
| How Supabase learns who the donor is | **Claim-checked `anon` policies**: Supabase verifies the Firebase ID token, and every storage policy proves `iss`, `aud` and `sub == first folder` itself | A Firebase ID token carries no `role` claim, so Supabase assigns the `anon` Postgres role whatever we do. Minting `role: 'authenticated'` needs a Firebase blocking function, and that needs Blaze. The policy therefore carries the whole proof instead of a role |
| Which Supabase client | `storage_client` (the REST client), not `supabase_flutter` | `supabase_flutter` wants a Supabase Auth session and a singleton. This app's identity is Firebase; one client per operation carrying the current Firebase ID token is the entire integration, and it cannot silently sign in as somebody else |
| Whether to wait for a Supabase project | **Scaffold now, SQL delivered**: build behind a seam with an honest "not configured" state | No Supabase project exists in this workspace and creating one needs the owner's account. Building first means the feature is complete and testable now, and the bucket and policies ship as a file the owner applies |
| Object layout | One public `avatars` bucket, path `{firebaseUid}/avatar-{millis}.{ext}` | Bucket count is a project-wide resource, so per-donor *folders* are what the policies address. A unique name per upload makes every object immutable, which is what allows a one-year cache header and removes any reason to allow an update |
| What "replace" means | Upload a **new** object, publish it, delete the new object if the publish fails | Overwriting in place (`upsert`) destroys the current photo before the new URL is stored, so a failed write would leave the profile pointing at a half-written file. The chosen order's worst case is an object nobody links to |
| What "remove" means | Clear the profile field **first**, then delete the object | The opposite order can leave the donor card pointing at a deleted file. This order's worst case is an orphan |
| Where type and size are enforced | Magic bytes and 5 MB in the client, `file_size_limit` and `allowed_mime_types` on the bucket | The bucket is the enforcement; the client check exists to fail fast and to produce a translated sentence. Neither re-encodes the image |

### Completed

- **Configuration is a build define, and a privileged key is refused.**
  `SupabaseConfig.fromEnvironment()` reads `SUPABASE_URL` / `SUPABASE_ANON_KEY`,
  accepts only `https://` with a dotted host, and
  `rejectPrivilegedKey` drops an `sb_secret_…` key or any JWT whose payload
  carries `role: service_role` — which leaves the app reporting itself
  unconfigured rather than carrying a bypass. `toString` never prints the key.
- **Validation is by content, not by file name.** `PhotoValidator` sniffs the
  magic bytes (JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`, WebP
  `RIFF….WEBP`), caps at 5 MB, and returns a `ValidatedPhoto` whose constructor
  is private, so an upload cannot be built from an unchecked buffer. Each
  rejection is one `PhotoIssue` with its own translated sentence: empty, too
  large, unsupported, access denied, unreadable.
- **One storage adapter, addressed from the session.** `SupabasePhotoStorage`
  builds `{uid}/avatar-{millis}.{ext}` from `FirebaseAuth.currentUser`, uploads
  with the sniffed `contentType` and `cacheControl: 31536000`, and returns
  `bucket.getPublicUrl(path)`. It refuses to upload without a signed-in user,
  and `objectPathOf` refuses any URL that is not the configured project's
  `avatars` bucket — a foreign URL in `photoUrl` can never become a delete of
  somebody else's object.
- **Every Supabase answer is translated, not leaked.** `storage_error_mapper.dart`
  maps 401 / `Invalid JWT` to the auth sentence, 403 / row-level-security /
  `insufficient privilege` to the permission sentence, 404, 409, 413 to the same
  too-large sentence the client uses, 415 to the same unsupported sentence, 429
  to rate limited, 5xx and socket and timeout to the network sentence, and
  anything else to unexpected with the status kept for the log.
- **One controller owns the order.** `ProfilePhotoController` is the only writer:
  pick → validate → stop if unconfigured → upload → `setPhotoUrl` → compensate on
  failure; and remove → `setPhotoUrl(null)` → best-effort delete. One operation
  at a time (`ConflictFailure` for a second), and a cancelled picker returns
  "nothing happened" rather than an error.
- **The screen tells the truth.** `ProfileIdentityCard` shows the photo or the
  initials fallback with **Add photo** / **Change photo**. While an upload runs
  the spinner sits over the *existing* photo and the button is disabled; when an
  upload fails the old photo stays visible and the reason appears in the banner.
  The sheet offers gallery and camera, and **Remove photo** only when there is a
  photo, behind a confirmation that says the initials come back and the stored
  image is deleted. With no Supabase defines the sheet says so and offers only
  Close — no control that could only fail.
- **Firestore is touched in exactly one field.** `ProfileRepository.setPhotoUrl(String?)`
  is a narrow merge of `users/{uid}.photoUrl` (delete-on-null), addressed from
  `FirebaseAuth.currentUser` like every other write, so it cannot be pointed at
  another account.
- **Localisation and theme carried over.** 18 new keys in both catalogues
  (`untranslated.json` is `{}`), Bengali numerals in the size sentence, and the
  sheet and the confirmation dialog are rendered in light and dark.

### Files created

```
lib/core/config/supabase_config.dart
lib/features/profile/domain/profile_photo.dart
lib/features/profile/domain/profile_photo_storage.dart
lib/features/profile/domain/photo_picker.dart
lib/features/profile/data/supabase_photo_storage.dart
lib/features/profile/data/storage_error_mapper.dart
lib/features/profile/data/image_picker_photo_picker.dart
lib/features/profile/application/profile_photo_providers.dart
lib/features/profile/presentation/widgets/profile_photo_sheet.dart
test/support/fake_photo_services.dart
test/core/supabase_config_test.dart                      (15 tests)
test/features/profile/profile_photo_test.dart            (16)
test/features/profile/storage_error_mapper_test.dart     (16)
test/features/profile/supabase_photo_storage_test.dart   (14)
test/features/profile/profile_photo_controller_test.dart (12)
test/features/profile/profile_photo_flow_test.dart       (17)
test/features/profile/profile_messages_test.dart         (9)
docs/storage/supabase-avatars.sql
docs/storage/README.md
docs/visuals/stage6/*.png                                (5 widget renders)
```

99 new tests. **No production file was written outside `lib/features/profile`
except one**: the configuration belongs to no feature.

### Files modified

```
pubspec.yaml                    + storage_client ^2.8.1, image_picker ^1.2.4
lib/core/error/failure.dart     + ConfigurationFailure — a sealed member, so every
                                existing switch had to say what a missing setting
                                means instead of falling through
lib/app/bootstrap.dart          supabaseConfigProvider override
lib/features/profile/domain/profile_repository.dart         + setPhotoUrl
lib/features/profile/data/firestore_profile_repository.dart + setPhotoUrl
lib/features/profile/presentation/profile_screen.dart      sheet, busy state,
                                                            snackbars
lib/features/profile/presentation/widgets/profile_identity_card.dart
                                photo slot, Add/Change, spinner over the photo
lib/features/profile/presentation/profile_messages.dart    photo sentences
lib/l10n/app_en.arb             + 18 photo keys
lib/l10n/app_bn.arb             the same keys in Bengali, Bengali numerals
lib/l10n/generated/*            regenerated by gen_l10n (not hand-edited)
test/support/fake_profile_repository.dart   + setPhotoUrl and its call log
test/review/visual_review_test.dart         photo overrides + 5 captures
docs/ARCHITECTURE.md            §8, §10 and the new §13
docs/PROJECT_STATE.md           this section
README.md                       status and the storage pointer
```

### Files deleted

```
none
```

### Database changes

**None deployed, on either provider.** `firestore.rules`, `firebase.json` and
`google-services.json` are untouched; nothing was deployed; no Supabase project
was created, so the bucket and the two policies in
`docs/storage/supabase-avatars.sql` have **never been created either**. That
file is delivery material for the owner to run in their own project.

The only data shape this stage adds is a value in an existing field:
`users/{uid}.photoUrl` (a public URL, or absent). The rules already allow the
owner to write it and already expose it to signed-in readers; nothing had to
change for that to work — which is also why it is still unvalidated.

### Packages added

| Package | Version | Why |
| --- | --- | --- |
| `storage_client` | 2.8.1 | The low-level Supabase Storage REST client. Chosen over `supabase_flutter` because it holds no session and no singleton: one client per operation can carry the current Firebase ID token and nothing else |
| `image_picker` | 1.2.4 | Gallery/camera on Android, iOS and web. Picks the file, and is asked for `requestFullMetadata: false` so EXIF and GPS never leave the device |

Both are free, both are official first-party packages, and neither needs a paid
tier. `supabase_flutter` was deliberately **not** added. No Blaze, no paid
service.

### Verification

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** |
| Unit + widget tests | `flutter test` | **386 passed, 37 skipped** (287/32 in Stage 5; +99 tests, +5 skips from the new visual captures) |
| Translation completeness | `lib/l10n/untranslated.json` | `{}` |
| Web release build | `flutter build web --release` | **Built** `build/web` — `main.dart.js` 3,693,644 bytes (+118,857 on Stage 5) |
| Android debug build | `flutter build apk --debug` | **Built** `app-debug.apk` (182,633,039 bytes ≈ 174.2 MB, +0.4 MB) |
| Visual review, widget renders | `$env:SOLOVVO_VISUAL_REVIEW=1; flutter test test/review/visual_review_test.dart` | 37 renders written to `build/review/`; five archived in `docs/visuals/stage6/`: profile with photo (light/en), sheet (light/en), sheet (dark/bn), unconfigured sheet (light/bn), remove confirmation (dark/en). Three were opened and read |
| **Live storage** | — | **Not performed.** No Supabase project exists here, so no upload, download or delete has ever run against real storage, and the SQL has never been executed |

What the tests actually cover, since the last row is the one that matters:

- **Client checks**: magic-byte sniffing per format, the RIFF trap (a WAV is a
  RIFF file and must not pass as WebP), the 5 MB boundary (the limit itself is
  accepted, one byte more is not), every `PhotoIssue`, the private
  `ValidatedPhoto` constructor.
- **Configuration**: `https`-only URLs, a dotted host, the accepted key shapes,
  and both privileged-key refusals (an `sb_secret_` key and a service-role JWT),
  plus the guarantee that `toString` prints no key.
- **Paths**: the generated path per format, and `objectPathOf` accepting the
  donor's own folder and a nested path inside it while refusing another uid,
  another bucket, another origin, an external URL, a non-URL, and an empty uid.
- **Error mapping**: each status and each Supabase sentence to its `Failure`,
  the cause and stack trace preserved, and an unmapped status keeping its code.
- **Ordering**: with recording fakes, `upload → publish`;
  `upload → publish → delete` when the publish fails, with the *previous* URL
  still in the profile; `clear → delete` on removal; only `clear` when the clear
  fails; a failed delete still reported as success. One operation at a time.
- **The screen**: Add vs Change, the stored URL actually reaching
  `NetworkImage`, gallery vs camera, a cancelled picker producing no snackbar, an
  unsupported file and a denied permission each producing their own sentence, a
  failed upload leaving the old photo on screen, the spinner over the existing
  photo with the button disabled, the removal confirmation (and that the field is
  not written before it is confirmed), and Bengali and dark rendering.

### Bugs found during verification and fixed

1. **A crash where a permission decision belonged.** `objectPathOf` compared
   origins with `Uri.origin`, which *throws* — `Bad state: Cannot use origin
   without a scheme` — for a `photoUrl` that is not an absolute http(s) URL. The
   field is whatever the document holds, including a relative path somebody once
   put there, so a delete could have taken the whole screen down. Found by a
   unit test that fed it `'not a url'`, fixed in the adapter (compare scheme,
   host and port; refuse instead of throwing).
2. **Two "Profile photo" widgets on screen.** The sheet title and the completion
   card's field chip share the key's value, and in Bengali the button label is
   the sheet title too, so `find.text` matched two or three nodes. Assertions are
   now scoped to `ProfilePhotoSheet`. The duplication is real and intended: the
   card names the field, the sheet names itself.
3. **A mapper test that asserted the wrong wording.** `'not found'` does not
   contain `'object not found'`, and `'The content type is not allowed'` matched
   the *permission* branch's `'not allowed'` before reaching the content-type
   branch. Both were test bugs — the mapper was right — and both were fixed in
   the tests rather than by loosening the mapper.
4. **Bengali numerals make a digit-literal assertion wrong.** The generated
   size formatter localises `5` to `৫`, so `contains('5')` failed in Bangla. The
   test now asserts against `errorPhotoTooLarge(PhotoValidator.maxMegabytes)` and
   a Bengali-digit range.
5. **A concurrency test asserted a state the notifier cannot hold.** It expected
   `AsyncLoading` during the first operation and saw `AsyncData`: the notifier's
   initial `build()` future completes *after* the operation sets loading and
   overwrites it. The pre-existing `ProfileController` has the same shape, so the
   production code was left alone and the assertion replaced — recorded because
   deleting the assertion quietly would have hidden the question of whether the
   screen ever shows progress. It does: the screen tracks its own in-flight flag,
   and the widget test proves the spinner.
6. **The visual harness could not type its override list.** `Override` is not
   exported by `flutter_riverpod`, so `...<Override>[…]` did not compile;
   replaced with two separate conditional elements.

### Remaining issues

1. **Nothing has been uploaded for real.** There is no Supabase project in this
   workspace: the bucket does not exist, the SQL has never run, and no policy has
   ever allowed or refused anything. Everything above about storage behaviour is
   verified against fakes, and `docs/storage/README.md` says so at the top.
   *Reconciled 2026-11-03 (Stage 8.3 recovery):* the substance of this item still
   holds — no upload has ever run and neither SQL file has been executed from this
   repository — but "there is no Supabase project in this workspace" was written
   before local, gitignored Supabase CLI state appeared on the development machine
   (`supabase/.temp/`). Linking a project is not applying it, and whether either
   bucket exists remotely cannot be established from the repository. See
   `docs/ARCHITECTURE.md` §11 items 10 and 12 and the top of
   `docs/storage/README.md` for the corrected wording. The historical record above
   is kept as written.
2. **The Firebase → Supabase third-party auth integration is unverified.** Supabase
   must be told to trust the Firebase project `sholovvo-blood-donation` (step 2 of
   the README) before any token is accepted. Whether the project's plan offers
   that setting was never seen from here. If it does not, the alternatives — a
   Blaze blocking function that mints `role: authenticated`, or moving to
   Supabase Auth — change the authentication model and need the owner's decision.
   **No workaround has been implemented.**
3. **The bucket's security rests on three predicates.** Requests arrive as the
   `anon` role, so `iss`, `aud` and `sub == (storage.foldername(name))[1]` are the
   entire boundary. Relaxing any one of them relaxes ownership for everyone. No
   policy was weakened to make anything work, and none has been exercised.
4. **The bucket is public-read by design.** A photo URL is not a secret and is
   cached for a year (`max-age=31536000`), which is only safe because every upload
   gets a fresh path. A deleted object may stay visible from a CDN edge for a
   while. Nothing private may ever be stored in `avatars`.
5. **Orphans, and the object left behind by a replacement.** Replacing a photo
   always leaves the previous object, and a compensating delete that fails (offline
   straight after a failed profile write) leaves an orphan. Collecting them needs
   a scheduled job — a paid feature on both providers — or a manual query, so
   nothing collects them.
6. **No server-side re-encoding.** The bucket checks size and content type, the
   client sniffs magic bytes; neither transforms the image, so a well-formed but
   hostile JPEG is stored as-is and served to other donors.
7. **The photo outlives the account.** Deleting a Firebase user removes nothing
   from storage; only the app's own removal path deletes objects.
8. **`photoUrl` is still an unvalidated string in Firestore.** The rules were
   neither modified nor deployed, as instructed. `objectPathOf`'s origin check
   limits what a bad value can do inside this app, but it is a mitigation inside
   the client, not a boundary.
9. **No browser pass this stage.** The five renders in `docs/visuals/stage6/`
   come from the widget harness, which cannot load `Image.network` — the avatar in
   `01-…` shows the initials fallback even though the URL is real. A live upload
   cannot be photographed without a Supabase project, and the temporary
   entrypoint used in Stage 5 was not recreated.
10. Carried over from Stages 2–5: no runtime test against the real Firebase
    project, `firestore.rules` does not validate profile field shapes or values,
    no real-device or iOS verification, `donation_history` is empty for every real
    account, `createProfile` is still the first save, `com.example.*`
    applicationId, `firebase_core` KGP warning, no push notifications on Spark,
    Bengali font not bundled.

### Next stage

**Stage 6 was approved by the owner on 2 November 2026.** The approval covers the
client-side work verified above; the storage backend remains unverified. Issue 1
in the list above is now partly stale: `supabase/.temp/linked-project.json`
shows the CLI is linked to a project named "Sholovvo blood donation", so a
project does exist. Whether the SQL, the bucket or the policies were ever applied
to it is still unknown, so issues 2 and 3 stand unchanged.

**Stage 7 was not started at that point.** Before Stage 6's storage claims can be
upgraded from "tested against fakes" to "verified", steps 1–5 of
`docs/storage/README.md` have to be performed and their output recorded: the
project, the Firebase provider, the applied SQL, the verification queries, and
the `curl` negative test that must come back `403`.

The approved next workstream was not Stage 7. It was the Firestore rules
remediation arising from the four P0 findings, because the application writes
none of the affected collections yet: closing them now was a rules-only change,
whereas closing them after Stages 10–11 would have forced a client migration.
**That remediation is complete — see "Security remediation — the four P0
findings".**

Stage 7 followed it and is now **complete, awaiting approval — see "Stage 7 —
Navigation & Settings"**. The storage verification above is still outstanding and
is not a Stage 7 dependency: neither the shell nor Settings reads or writes
storage.

---

## Security remediation — the four P0 findings

Completed 2 November 2026, after Stage 6 was approved. Rules-only: no Dart file
was touched, because the application writes neither `blood_requests`, nor
`donation_history`, nor `notifications` yet (verified by grep over `lib/`).

### What changed in `firestore.rules`

**Finding 1 — fabricated donation history.** `blood_requests.create` no longer
only compares `userId` with the caller. It requires the ten mandatory keys, a
`hasOnly` allow-list, `status == 'open'`, no `assignedDonorId`/`acceptedAt`/
`completedAt`/`cancelledAt`, a server `createdAt`, and a valid blood group. The
confirmed branch of `donation_history.create` now also requires that the donor is
not the caller, that the request is `donation_completed` or `fulfilled`, that
`bloodGroup` and `hospitalName` match the request, and that `donationDate` is a
timestamp.

**Finding 2 — notification recipient reassignment.** The self-addressed branch
is gone and `recipientUid != request.auth.uid` is now a precondition of every
type. The recipient's update branch is restricted to `affectedKeys().hasOnly
(['isRead'])`, so a notification can no longer be retyped or handed to another
user.

**Finding 3 — unauthorized `new_request`.** `new_request` now requires the
caller to own the request *and* the request to still be `open`. A new
`request_cancelled` type was added for the owner to tell the assigned donor that
the request is off, valid both inside the cancelling batch (`status == 'accepted'`)
and after it (`status == 'cancelled'`).

**Finding 4 — unrestricted owner update.** The owner branch is now four named
transitions and nothing else: edit details while `open`; cancel while `open` or
`accepted`; confirm `donation_completed` → `fulfilled`. `userId` is immutable,
`assignedDonorId` cannot be set or swapped by the owner, and self-claim is
impossible because the donor branch excludes `auth.uid == resource.data.userId`.

### Verified

- `node --test firestore.test.js` against the Firestore emulator: **67 tests,
  67 pass, 0 fail**, 8 suites. The 43 original tests are unchanged and all pass.
  The 14 discovery tests were rewritten to assert the closed behaviour and 10
  new contract tests were added.
- `flutter analyze`: no issues found. `flutter test`: 386 passed, 37 skipped.
- Two defects were found by the suite itself during this pass: `Set.has()` does
  not exist in the rules language (`hasAny` does), and an owner may legitimately
  correct the blood group of a request nobody has claimed yet.

### Limitation that remains

Rules cannot prove a real donation happened. They can only guarantee that a
confirmed record is written by the owner of a request that a specific donor
claimed and completed, with matching blood group and hospital. A patient and a
collaborating donor can still manufacture a mutual donation by going through the
claim and completion steps, and a confirmed record still cannot be corrected by
the donor it names (`allow update: if false`). Closing either gap needs a
trusted server process, which the Spark plan does not provide.

### Unplanned change, disclosed

`pubspec.yaml` declared `supabase: ^3.0.0-dev.15`, which is imported nowhere and
conflicts with `storage_client ^2.8.1` through `supabase_common`. `flutter pub
get` could not resolve at all, so `analyze` and `test` could not run. The line
was removed. Nothing else in the dependency set changed and `pubspec.lock` was
not modified.

---

## Stage 7 — Navigation & Settings

Completed 2 November 2026.

### The three decisions, and why I did not wait for the answers

The Stage 7 brief asked the owner to choose three things. The instruction to start
arrived before those answers did, so the three recommendations in that brief were
implemented as written. They are recorded here so any one of them can be
reversed on its own without touching the other two.

| Question | Implemented | Why |
| --- | --- | --- |
| Tab set | **Two live tabs** — Home and Profile. Settings is pushed above the shell | A third tab needs a third live destination, and Stage 7 has two. Stage 4's decision table already ruled out a bar whose tabs go nowhere: "A bar with four dead tabs would be worse than none" |
| Settings contents | Account, Preferences (the existing appearance sheet), About, Sign out | Every row does something. A notification switch was refused: there is no push channel on Spark, and nothing reads such a flag until Stage 11 |
| Sign-out | Settings only; the dashboard's button removed | Sign-out was the last control on a work surface, where a mis-tap costs a session, and the dashboard is now the first of two tabs rather than a page you leave |

### What changed

- **`lib/app/app_shell.dart` (new).** A `Scaffold` holding an `IndexedStack` of
the two tabs, a `NavigationBar` below 720px and a `NavigationRail` beside the
content at or above it. The enum `ShellTab` has exactly two members because two
destinations exist; a third becomes one member and one destination. Both tabs
are built and kept alive, so switching is instant and each keeps its scroll
position.
- **`lib/features/settings/` (new).** `SettingsScreen` (Account, Preferences,
About, Sign out) and `SettingsTile`. The account row is read-only and says the
address is managed by the sign-in account rather than showing a greyed-out field
that looks broken.
- **`lib/app/auth_gate.dart`.** A verified session now returns `AppShell`, not the
dashboard.
- **`lib/features/home/presentation/home_screen.dart`.** No longer owns a
`Scaffold`, a sign-out button or the push to the profile. It takes a **required**
`onOpenProfile` callback so a host that forgets to wire it cannot ship a header
button that silently does nothing.
- **`lib/features/profile/presentation/profile_screen.dart`.** No back arrow (it
is a tab now, not a pushed page) and a settings gear in the AppBar. The screen's
own state loading is unchanged.
- **`lib/design/app_theme.dart`.** `navigationBarTheme` and
`navigationRailTheme`, both resolved from the role palette: surface background,
no surface tint, a `brandTint` selection indicator, and `brandInk` versus
`textSecondary` for the selected and unselected labels — so the bar follows the
dark palette without a second set of constants.
- **`lib/l10n/app_en.arb` + `app_bn.arb`.** Eleven new keys, translated in both
languages (`lib/l10n/untranslated.json` is `{}`), regenerated in-tree. Existing
keys were reused rather than duplicated: `signOut`, `emailLabel`,
`appearanceAndLanguage`, `profileTitle`, `profileEmailManaged`.

### Deliberately not built

Two things the obvious build would have included and this one does not:

- **The palette button did not move off the Home header.** The Stage 3 record
says the appearance sheet is opened from a header icon on Welcome *and* Home,
and three existing tests assert that button is there. Replacing it with a gear
would have traded a one-tap theme switch for a two-tap one and regressed an
approved behaviour. Settings therefore re-hosts the same `AppearanceSheet`
widget — not a copy of it — reached from the Profile tab's AppBar gear.
- **There is no version row in About.** `pubspec.yaml` carries a version, but
nothing in the app can read it without a platform plugin (`package_info_plus`),
and a constant copied by hand drifts from the manifest. The card shows the brand
and the build flavour instead, and the omission is documented in the widget.

### Verified

- `flutter analyze`: **no issues found**.
- `flutter test`: **401 passed, 42 skipped, 0 failed** (the tree before this stage
was 386 / 37). The 15 extra passing tests are the 15 added in the two new files,
minus the dashboard sign-out test that moved, plus the header test that was split
in two. The five extra skips are the new review captures.
- **A real defect was found by the suite, not by review.** Walking the gate →
Profile → Settings → Sign out path in `auth_gate_test.dart` failed with "Found 0
widgets with type WelcomeScreen": the gate replaces the signed-in surface
*underneath* the pushed Settings route but cannot pop it, so a donor would have
signed out and been left staring at Settings. Fixed in `SettingsScreen._signOut`
with `popUntil((route) => route.isFirst)` on success.
- Five renders in `docs/visuals/stage7/`, produced with
`$env:SOLOVVO_VISUAL_REVIEW=1; flutter test test/review/visual_review_test.dart`
and the Nirmala plus MaterialIcons fonts loaded: the shell over the dashboard in
light and dark, the Profile tab in Bengali, and Settings in English and Bengali.
They are widget renders, not browser screenshots — see issue 6.

### How the tests were changed

The brief promised "two tests migrate". The honest figure is **four test files
migrated and two added**:

| File | Change |
| --- | --- |
| `test/features/home/home_screen_test.dart` | Hosts `HomeScreen` inside a `Scaffold`, as the shell does, and supplies `onOpenProfile`. The dashboard's sign-out tests were removed with the button they tested |
| `test/features/home/home_profile_test.dart` | `onOpenProfile` is optional here because this file tests the header, not the tab. The one test that asserted "opens the profile" became two: "shows the initials" and "asks its host" |
| `test/app/auth_gate_test.dart` | The sign-out test now walks Profile tab → gear → Sign out, which is the path a donor actually takes |
| `test/review/visual_review_test.dart` | Five `HomeScreen` mounts became `AppShell`, plus the five new captures |
| `test/support/auth_harness.dart` | Overrides `appConfigProvider`, which Settings reads and which throws by design when nothing has provided it |
| `test/app/app_shell_test.dart` | **New**, 8 tests: both tab switches, the header avatar handing the tab over, no back arrow on the profile tab, Bangla labels, 320px Bangla with no overflow, and the rail replacing the bar above the breakpoint |
| `test/features/settings/settings_screen_test.dart` | **New**, 7 tests: the account row, the build name for two flavours, the appearance sheet opening from the tile, a successful sign-out, a rejected sign-out that stays on screen, and Bangla at 320px |

### Remaining issues

1. **The eleven new Bengali strings have not been read by a native speaker.**
They are mine, in the same position as the Stage 3 translations. The difference
is that two of them (`হোম`, `সেটিংস`) are navigation labels a donor sees on every
screen and cannot avoid, so a wrong word here is louder than wrong copy inside a
sheet nobody has to open.
2. **Both tabs stay alive.** `IndexedStack` keeps the unselected tab built, which
is what makes switching instant and preserves its scroll offset. The cost is that
the profile query runs before the donor opens that tab, and a future tab that
starts a listener will be started on sign-in whether or not it is visited.
3. **The rail has only been seen at one width.** A widget test at 720px and a
phone-width render exist; no real tablet, landscape phone or foldable was run.
`railBreakpoint = 720` matches `HomeScreen.twoColumnBreakpoint` on purpose, but it
is a constant chosen to agree with the dashboard rather than a measurement.
4. **The shell does not restore which tab was open.** A rebuild returns to Home,
and nothing can open Settings directly — there are no deep links yet.
5. **`popUntil(isFirst)` is blunt.** It assumes exactly one route above the gate's
root, which is true today. A later stage that pushes something above the shell and
then signs out from Settings will have to say which routes to keep.
6. **No browser pass this stage.** The five stage renders come from the widget
harness. The temporary browser entrypoint used in Stage 3 was not recreated, so
nothing was checked in a real browser, and `Image.network` still cannot load
inside the harness.
7. **The account row is session state, not Firestore.** It shows the address the
session signed in with, read from `AuthUser`. It therefore cannot show anyone
else's address, but it is also not re-validated against the auth backend on open.
8. Carried over from Stages 2–6, unchanged: no runtime test against the real
Firebase project, no real-device or iOS verification, Supabase storage still
unverified against a live project, `com.example.*` applicationId, and no push
notifications on Spark.

### Unplanned changes, disclosed

- **`Material(type: MaterialType.transparency)` in `HomeScreen`.** Removing the
Scaffold removed the `Material` ancestor the header's `InkWell` needs, and 31
tests failed with "No Material widget found". The shell supplies one in the app;
the wrapper covers any host that does not, and paints nothing, so
`SoftGlowBackground` still shows through.
- **`auth_harness.dart` gained an `appConfigProvider` override.** That provider is
deliberately unimplemented until something provides it, and Settings is the first
screen that reads it. The override is one line, but it means a future screen that
reads config can pass tests that never exercise the "nothing provided it" path.

### Next stage

**Stage 8 — donor management & badges has not been started.** Stage 7 delivered
no badge surface and no donor list, so Stage 8 owns all of that. It inherits two
facts from here: the Profile tab is the natural home for a badge row, and the
shell grows a third tab by adding one enum member and one destination — but only
once a third destination actually exists.

Nothing is committed or deployed. The working tree holds the stage for review;
the five renders above and this document are part of it.

---

## Stage 8.1 — Feed foundations

Completed 3 November 2026.

### Scope confirmed: Stage 8 is the social feed

The Stage 8.0 assessment recommended it and the recommendation stands: **Stage 8
is the social feed**, and the donor management and badge work that the tracker
previously listed against Stage 8 is unscheduled rather than renumbered. This
supersedes the closing paragraph of the Stage 7 entry above, which was written
before 8.0 ran. Stage 8.1 is foundations only: entities, a mapper, and the two
refactors they need. There is no feed screen, no repository, no provider, no
Firestore read or write, no sample data and no rules change.

### What changed

| Path | Change |
| --- | --- |
| `lib/core/media/photo.dart` | **Moved** from `features/profile/domain/profile_photo.dart`. `PhotoIssue`, `PhotoFormat`, `PhotoCandidate`, `ValidatedPhoto`, `PhotoValidator`; logic unchanged, docs generalised from "profile photo" to "photo" |
| `lib/core/media/photo_picker.dart` | **Moved** from `features/profile/domain/photo_picker.dart`, unchanged |
| `lib/core/media/image_picker_photo_picker.dart` | **Moved** from `features/profile/data/`. See the disclosure below — this one went further than the brief |
| `lib/features/feed/domain/entities/{post,comment,report}.dart` | **New.** Three immutable entities, three validators, three issue enums, two report enums |
| `lib/features/feed/data/models/post_document.dart` | **New.** `PostDocument.toMap` / `fromMap`, pure, over plain maps |
| `lib/design/widgets/blood_group_badge.dart` | `BloodGroupBadgeVariant {pill, square}` and a `size`, so the dashboard's 44 dp tile and the pill are one widget with two approved looks |
| `lib/design/widgets/initials_avatar.dart` | `InitialsAvatarVariant {brand, muted}` and one shared initials derivation |
| `lib/features/home/presentation/widgets/home_cards.dart` | Its private `BloodGroupBadge` and `_InitialsAvatar` deleted; the shared widgets render the same 44 dp tile and 40 dp disc |
| `ios/Runner/Info.plist` | Both photo purpose strings widened to cover "a profile picture or a photo to share in a post". No new key, no behaviour change |
| 6 lib files, 6 test files | Imports only, reordered to keep `directives_ordering` satisfied |

Deleted: `lib/features/profile/domain/profile_photo.dart`,
`lib/features/profile/domain/photo_picker.dart`,
`lib/features/profile/data/image_picker_photo_picker.dart`, and
`test/features/profile/profile_photo_test.dart` (moved, not dropped — see the test
table below).

### The move that went further than the brief, disclosed

The brief named `PhotoValidator`, `PhotoCandidate`, `PhotoFormat` and
`PhotoPicker`. The `image_picker` adapter went too. Leaving it in
`features/profile/data` would have left the feed two bad options: import another
feature's data layer, which the layering in `docs/ARCHITECTURE.md` §1 does not
allow, or re-derive `maxWidth: 1024`, `imageQuality: 85` and
`requestFullMetadata: false` — and a second hand-written copy of those three is
how a photo's GPS coordinates end up in a post. It is an adapter with no profile
knowledge, so it moved. `ProfilePhotoStorage` and `SupabasePhotoStorage` did
**not** move: `uploadAvatar`, `removeAvatar` and the `{uid}/avatar-{millis}.{ext}`
path are avatar-shaped, and a post image has different ownership rules.

### Two behaviour differences, disclosed

Both are small, both are in the consolidated widgets, and neither changes the
dashboard:

1. **A nameless muted avatar shows a person icon, not `?`.** The two private
   copies disagreed — the shared one drew `?`, the dashboard's drew the icon.
   The icon won, because an invented `?` in a 40 dp disc reads as a name the
   donor chose, and the design system's own rationale for the brand variant says
   the same thing.
2. **One initials rule for both variants: first letter of the first and last
   word.** The dashboard's copy used the first two characters of the name, so a
   three-word name would have read differently in the two places. This is
   identical for every one- and two-word name, which covers every name in the
   tests and the visual harness (including the Bengali two-word fixture), and
   the dashboard's feed provider returned `const []` at that point (Step 4 made it
   a projection of the feed controller; see the Stage 8.3 entry), so no rendered
   screen in this tree changes.

### Deliberately not built

No rule, index, bucket or policy was added; no repository, no provider, no
screen, no publish/edit/delete/like/comment/save/report operation, no fake feed
data, no moderation status and no follow graph. The last two were considered and
recorded as absences in the entities: a status field implies an enforcement
pipeline Spark cannot run, and following needs counters and rules that no part
of Stage 8 reads.

### Verified

- `flutter analyze`: **no issues found**.
- `flutter test`: **497 passed, 42 skipped, 0 failed** (the tree before this
  stage was 404 / 42 / 0). The 93 extra passes are 70 feed tests and 23 shared
  widget tests; `PhotoValidator`'s tests moved with the file and count the same.
  The 42 skips are unchanged — they are the visual-review captures, which still
  need `SOLOVVO_VISUAL_REVIEW=1`.
- **`dart format` was run on the touched paths and that turned out to be wrong.**
  It reformatted six test files this stage never modified, because the tree is
  not format-clean under the current SDK. Those six were restored with
  `git checkout --`, and the six files this stage *did* touch were restored and
  had their one-line import change re-applied by hand, so the diff contains no
  formatting churn outside new files.
- **A real defect was found by the suite.** `PostDocument.fromMap` returned
  timestamps through `Timestamp.toDate()`, which answers in the device's zone,
  while `DateTime` equality is false for the same instant in two zones. A post
  read on a phone in Dhaka would not have equalled the post that was written.
  The mapper now normalises to UTC, and one new test pins it.
- Not run, and why: `firestore-rules-tests/` (`npm test`) needs the Firestore
  emulator and this stage changed no rules; `flutter pub get` was not needed
  because no dependency changed; no visual-render pass, because no screen
  changed.

### How the tests were changed

| File | Change |
| --- | --- |
| `test/core/media/photo_test.dart` | **Moved** from `test/features/profile/profile_photo_test.dart`, assertions unchanged, import path updated |
| `test/features/feed/post_test.dart` | **New**, 14 tests: text boundaries at 2 000/2 001, 0/4/5 images, more paths than URLs, negative counters, unmodifiable lists, value equality, no text in `toString` |
| `test/features/feed/comment_test.dart` | **New**, 9 tests: the 500 boundary, a reply without a parent, the comment id being separate from its path |
| `test/features/feed/report_test.dart` | **New**, 15 tests: wire-name round trips, `hateSpeech` → `hate_speech`, unknown values refused rather than folded into `other`, the 300-note limit |
| `test/features/feed/post_document_test.dart` | **New**, 32 tests: required-field set, optional omission, UTC timestamps (including the local-time regression), full round trip, every missing and malformed field, 0/4/5 images, 2 000/2 001 text, and that no donor text reaches a debug message |
| `test/design/blood_group_badge_test.dart` | **New**, 7 tests: pill radius, padding and type, the large pill, the 44 dp square with the medium radius, a 36 dp square, `large` ignored by the square, and both colours following light and dark |
| `test/design/initials_avatar_test.dart` | **New**, 16 tests: initial derivation (one, two and three words, stray whitespace, Bengali runes, empty name), the brand disc scaling with its size, the muted disc keeping `labelMedium`, the photo path, a blank URL, both sizes, and theming |
| 6 profile/support test files | Imports only |

No existing test was weakened, deleted or skipped.

### Public API changes

- `PhotoValidator`, `PhotoCandidate`, `PhotoFormat`, `ValidatedPhoto`,
  `PhotoIssue`, `PhotoPicker` and `PhotoSource` are now at
  `package:sholovvo_app/core/media/photo.dart` and
  `.../core/media/photo_picker.dart`. Every importer was updated; nothing else
  about them changed.
- `BloodGroupBadge` gained `variant` and `size` and kept `large`; the default is
  still the pill, so existing call sites are untouched.
- `InitialsAvatar` gained `variant`; the default is still `brand`.
- No package id, machine identifier, ARB key, provider name or route changed.

### Remaining issues

1. **The existing feed rules do not match these types — and were not touched.**
   `firestore.rules` already contains `posts/{postId}`,
   `posts/{postId}/comments/{commentId}` and a top-level `post_likes` block,
   written before the feed was designed. They are **not approved** for this
   feed, and the schema has not been reconciled with them: the update rule
   allows `imageUrl` (singular) where the mapper writes `imageUrls` +
   `imagePaths`; likes are `post_likes/{likeId}` with a `userId` field rather
   than the per-post subcollection the mapper names; create permits a
   `donationRecordId` that `Post` does not model; no branch lets `commentCount`
   change; and post create checks no field shape at all. `reports` has no rule.
   Nothing reads or writes the feed, so nothing is exposed today. This item
   originally said the rules "know nothing about the feed"; that was false, and
   Stage 8.1.1 records the correction and the proposed schema
   (`docs/ARCHITECTURE.md` §14.1).
2. **Post images are unverified in every sense.** `Post.imagePaths` names
   objects that no bucket can hold yet. The `avatars` bucket is deliberately not
   reused: its policies require the first path segment to equal the caller's
   `sub`, which is an avatar layout, not a post layout. Bucket, policies and
   client are all unbuilt.
3. **Nothing in this stage has run against a live backend.** Every claim is a
   test over literal maps and fakes, as in Stages 2–7.
4. **Author names and photos will go stale by design.** A post carries a
   snapshot rather than a reference, which costs zero extra reads and leaves old
   posts showing old names. Recorded in the entity's documentation.
5. **The limits are chosen, not measured.** 2 000 characters, 4 images, 500 per
   comment and 300 per report are my judgements; none has been checked against a
   Firestore document limit or a rules expression, and the rules stage may have
   to restate them — two copies of a limit is exactly how they drift.
6. **Brand spelling is still unresolved.** The brief for this stage asks for
   "Sholovvo" in user-facing documentation. The codebase says "Solovvo"
   everywhere — `core/brand/app_brand.dart`, the iOS purpose strings, the README
   heading and every document — and `docs/ARCHITECTURE.md` §11 item 2 records it
   as a one-line change pending a decision. Nothing was renamed here: a
   foundations stage is the wrong place to rename a product, and doing it
   half-way (new text in one spelling, existing text in the other) would be
   worse than either. The new text in this stage avoids the brand name rather
   than picking a side, so the decision is still one change to one constant plus
   a search-and-replace.

### Next stage

**Stage 8.1.1 — schema and documentation alignment — followed this entry.** It
changed three documents and nothing else; this entry is left as it was written,
with the corrections recorded below.

**Stage 8.2 — the feed read path — has not been started.** It inherits three
things: the entity and mapper contracts are fixed and tested, so it can be built
against them without changing them; the existing rules disagree with those
contracts, so the reconciliation below has to be approved before anything is
written to Firestore; and the author snapshot means the feed does not need a
join to render a card.

Nothing is committed or deployed. No rules, index, bucket, policy or Firebase
configuration was touched, and no network call was made by the app.

---

## Stage 8.1.1 — Feed schema and documentation alignment

**Status: complete, awaiting approval. Documents and a decision record only — no
Dart file, rule, index, bucket or configuration was changed.**

### Why it exists

The Stage 8.1 verification read `firestore.rules` instead of trusting the notes
that said the feed had no rules, and found the opposite: `posts`,
`posts/{id}/comments` and `post_likes` rules have existed since before Stage 8.
They disagree with the Stage 8.1 model in five places, and `reports` is unruled
altogether. Three documents claimed otherwise. This stage fixes the statements
and records the decision that the rules stage will implement.

### What changed

| File | Change |
| --- | --- |
| `README.md` | The `## Feed` closing paragraph no longer claims the rules are empty. It states that `posts`/`comments`/`post_likes` rules exist, are not approved for this feed, that the schema is unreconciled, that `reports` has no rule, and that no Feed backend work is authorised. |
| `docs/ARCHITECTURE.md` | §11 item 11 rewritten from "knows nothing about the feed" to the five specific mismatches. §14's closing subsection rewritten, and a new §14.1 added with the audit table, the four schema decisions and the Rules changes they will need. |
| `docs/PROJECT_STATE.md` | Tracker row 8, the stage note under it, Stage 8.1's remaining issue 1, and this section. |

No `lib/` file, test, rule, index, manifest, ARB file or configuration was
touched, so the analysis and test results from Stage 8.1 still stand.

### The disagreements, in one line each

- **Images.** The post update rule permits `imageUrl`; `PostDocument` writes
  `imageUrls` and `imagePaths`. A post with images could be corrected by nothing.
- **Likes.** Rules use a top-level `post_likes/{likeId}` with a `userId` field;
  the mapper declares `posts/{postId}/likes`. Both cannot be right.
- **`donationRecordId`.** Create accepts one and validates it against
  `donation_history`; no entity, screen or design asks for it.
- **`commentCount`.** No update branch allows it to change, so the counter the
  feed card reads could never move.
- **`reports`.** No rule of any kind. Nothing can write a report today, and
  nothing would allow one if the UI arrived first.
- **Create shape.** The collections here that fix a document shape
  (`blood_requests`, `response_claims`, `donation_ratings`, `donation_history`)
  all assert `keys().hasAll`/`hasOnly` and `createdAt == request.time`; the post
  create rule asserts `authorUid` and nothing else. `/users` is deliberately
  permissive; `/posts` looks like a rule nobody finished.

### Decisions proposed (none applied)

`docs/ARCHITECTURE.md` §14.1 carries the table and the reasoning. In short:
keep `imageUrls` + `imagePaths`; move likes to `posts/{postId}/likes/{uid}` so
the document id is the liker; drop `donationRecordId` rather than model a field
with no surface; add a create-only `reports/{reportId}`; write timestamps as
server timestamps while the entity keeps its optimistic `DateTime`.

### Deliberately not done

- `firestore.rules` was not edited, even where the audit found a gap. Rules are a
  separate, separately reviewed stage, and changing them here would ship an
  unreviewed permission change alongside a documentation fix.
- `PostDocument`, `Post`, `Comment` and `Report` were not touched, so no test
  changed and no mapper behaviour moved.
- No repository, provider, screen, index or bucket; no Stage 8.2 work.

### Verified

- `flutter analyze`: **no issues found** (19.7 s). No Dart file changed, so the
  suite was not re-run; Stage 8.1's 497 passed / 42 skipped / 0 failed stands.
- No documentation linter exists in this repository, so consistency was checked
  by reading the three files back against `firestore.rules` line by line. The
  only cross-references that remain unverified are the ones a build cannot see:
  whether §14.1's proposal is the schema the owner wants.
- `git status` shows the same 48 entries as before this stage (modified, staged
  and untracked together); the three files above are the only ones this stage
  changed. `firestore.rules`, `firebase.json`, `.firebaserc`, `pubspec.yaml`,
  `pubspec.lock` and `firestore-rules-tests/` produce no diff at all.

### Remaining issues

1. **The mismatches are still real.** Documentation now describes them; only the
   rules stage can close them, and it must not be skipped before any write path
   ships.
2. **`reports` remains unruled.** Correct as a deny-all default, wrong the moment
   a Report button exists.
3. **The proposal is a proposal.** Stage 8.2 must be built against an approved
   schema, not against §14.1 as if it were decided.
4. **Subcollections outlive their parents.** Neither the current rules nor the
   proposal deletes comments or likes when a post is deleted; that cleanup needs
   an explicit decision.
5. **Brand spelling is still open** — see Stage 8.1's remaining issue 6. This
   stage again avoids the name in new text rather than picking a side.

### Next stage

**Stage 8.2 — the feed read path — has not been started, and should not begin
until the §14.1 schema is approved or amended.**

> Stage 8.2 followed this entry. §14.1 was approved as written, so 8.2 was built
> against it — `imageUrls` + `imagePaths`, `posts/{postId}/likes/{uid}` declared
> but never addressed, no `donationRecordId` in `Post` — and the rules were left
> untouched, so this entry's remaining issues still stand. See below.

## Stage 8.2 — Feed read path and UI

**Status: complete, awaiting approval. One paged, read-only feed. No Firestore
write, no rules change, no index, no deployment, no Supabase change.**

### The audit that came first

The brief required a read-access audit before any code, because a feed that is
built and then refused by the rules is a wasted stage. Four questions, four
answers, all checked against `firestore.rules` itself rather than against notes:

| Question | Answer |
| --- | --- |
| Can a signed-in user read posts? | Yes. `match /posts/{postId} { allow read: if request.auth != null; }` |
| Is the intended query compatible with that rule? | Yes. The rule has no field condition, so it authorises a **list** over the collection as well as a `get`; `orderBy` + `limit` + `startAfterDocument` needs nothing added |
| Does `PostDocument` match the approved schema? | Yes for reads. It maps `imageUrls`/`imagePaths`, `likeCount`, `commentCount`, the three timestamps and the author snapshot; it does not model `donationRecordId`. No mapper change was required |
| Does the required composite index exist? | None is required. One collection, one `orderBy` on `createdAt`, no `where` — Firestore's automatic single-field index serves it. No `firestore.indexes.json` exists and none was added |

The audit therefore cleared the stage to proceed, and nothing had to be worked
around. The rule is permissive enough that a **write** gap remains the real risk;
that is why this stage only reads.

### What changed

**Created — `lib/features/feed`**

| File | Job |
| --- | --- |
| `domain/feed_page.dart` | `FeedCursor` (empty interface), `FeedPage` — posts, cursor, `hasMore`, `skipped` |
| `domain/feed_repository.dart` | the port: `pageSize = 10`, one method `loadPage({after})` |
| `data/feed_documents.dart` | `FeedDocument` + the `FeedDocuments` transport seam |
| `data/firestore_feed_documents.dart` | the query, `SnapshotCursor`, the auth check |
| `data/firestore_feed_repository.dart` | page assembly: over-fetch by one, map, count refusals, cut the window |
| `application/feed_state.dart` | `FeedStatus` and `FeedState` with the four display predicates |
| `application/feed_providers.dart` | `feedRepositoryProvider`, `FeedController`, `feedControllerProvider` |
| `presentation/feed_messages.dart` | `Failure` → copy, and relative time |
| `presentation/expandable_post_text.dart` | the six-line clamp with a measured **Read more** |
| `presentation/widgets/feed_post_tile.dart` | one post: header, text, up to four images, read-only counts, copy |
| `presentation/feed_screen.dart` | the screen: four exclusive states, paging, refresh, responsive measure |

**Created — tests**

| File | Tests |
| --- | --- |
| `test/support/fake_feed.dart` | fake documents seam and fake repository (no tests of its own) |
| `test/features/feed/firestore_feed_repository_test.dart` | 13 |
| `test/features/feed/feed_controller_test.dart` | 13 |
| `test/features/feed/feed_messages_test.dart` | 10 |
| `test/features/feed/feed_screen_test.dart` | 16 |
| `test/review/visual_review_test.dart` | 5 captures in a `feed` group, gated like the rest of the file |

**Modified**

| File | Change |
| --- | --- |
| `lib/features/home/presentation/home_screen.dart` | the community section's **See all** now pushes `FeedScreen.route()` instead of reporting "Coming soon" |
| `lib/core/error/firestore_error_mapper.dart` | moved out of `features/profile/data` so the feed can map Firestore codes without importing another feature's data layer (§1). Import paths updated in `firestore_profile_repository.dart`, `storage_error_mapper.dart` and their tests |
| `lib/l10n/app_en.arb`, `app_bn.arb` + generated | 19 feed keys in both catalogues; `untranslated.json` stayed empty |
| `test/features/home/home_screen_test.dart` | one new test (23 total) and an optional `feedRepository` override on the harness |
| `lib/design/widgets/empty_state_card.dart` | `mainAxisSize: MainAxisSize.min` on the text column — see the unplanned change below |
| `test/review/visual_review_test.dart` | a `feed` capture group loading the harness's `_PushedFeed` and a seeded `FakeFeedRepository` |
| `docs/visuals/stage8/` | five renders: populated light en, populated dark bn, wide with pictures, empty, and a failed read |
| `README.md`, `docs/ARCHITECTURE.md` (§14.2, §11 item 11), this file | documentation |

### The query, and what it costs

```
posts.orderBy('createdAt', descending: true)
     .limit(FeedRepository.pageSize + 1)
     .startAfterDocument(last kept DocumentSnapshot)
```

Ten posts per page, at most eleven document reads per page, no listener, no
`where`, no subcollection, and no query that can return the collection. `hasMore`
is exact because of the lookahead, and the eleventh document is never mapped or
drawn. The cursor is the last **kept** snapshot, so a post published between two
reads cannot shift the window; a cursor from another producer is refused with a
`ValidationFailure` rather than coerced. A malformed document is dropped and
counted in `FeedPage.skipped`, because one bad document must not empty a news
feed.

### Two decisions worth naming

- **"Load more" is a button, not a scroll trigger.** Automatic paging spends a
  read the donor did not ask for, and on the Spark plan a mis-measured viewport
  can spend a page per frame. The cost is one tap; the benefit is that every read
  corresponds to an intent.
- **The dashboard's "See all" appears only when the preview has a post in it.**
  That is the rule the requests section already used and two existing tests
  assert ("no See all over nothing"), so the new navigation was wired behind that
  condition rather than replacing it. **Consequence, disclosed:**
  `feedPreviewProvider` still returns an empty list, so on the shipped dashboard
  the button does not yet appear. The route, the wiring and its test exist; the
  preview is populated by a later stage. Nothing about the dashboard's
  appearance changed.

  *Superseded by hardening Step 4 (2026-11-03): the paragraph above is kept as this
  stage's own record, and its consequence is gone. `feedPreviewProvider` is now a
  projection of the feed's controller, **See all** appears whenever there is a post
  to see, and an empty section offers **Open the community** instead — see the
  Stage 8.3 entry, defect 4. The "no See all over nothing" rule this stage
  preserved is still in force and still asserted by the same two tests.*

### Deliberately not built

No create, edit, delete, like, unlike, save, unsave, comment, reply, report,
image upload, Supabase post storage, batch, transaction or any other Firestore
write. No realtime listener. No fake or hardcoded post in production code — the
only posts anywhere are in `test/`. No third tab: the shell still has exactly
`home` and `profile`.

### Screenshots

Five widget renders are in [`docs/visuals/stage8/`](visuals/stage8). They are
produced by the existing `SOLOVVO_VISUAL_REVIEW=1` harness and are *not* golden
tests: it asserts nothing, it loads a real font, and it seeds posts through the
same `feedRepositoryProvider` seam the widget tests use.

| File | What it shows |
| --- | --- |
| `01-feed-light-en.png` | populated, light, English — a six-line collapse with **Read more**, four posts, read-only counts |
| `02-feed-dark-bn.png` | populated, dark, Bangla — Bengali digits in the counts and the relative times |
| `03-feed-wide-with-images-light-en.png` | the 900 dp measure on a 1000 dp window, with one and four pictures |
| `04-feed-empty-light-en.png` | the empty card, centred and compact |
| `05-feed-error-dark-en.png` | a failed first read: the sentence for the failure, and **Try again** |

Two caveats, both visible in the files: the harness answers every network image
with 400, so pictures draw the tile's broken-image glyph rather than a photo;
and these are widget renders, not browser captures, because the temporary web
entrypoint used in Stage 3 was not recreated.

### Two unplanned changes, disclosed

Neither was in the brief. Both were found by looking at the renders, which is the
one thing the widget assertions could not do.

- **`EmptyStateCard` stretched to the full viewport.** Its inner `Column` used
  the default `MainAxisSize.max`, which is invisible inside the unbounded scroll
  views every other caller puts it in, and stretched the card to the whole
  remaining height in the feed's `SliverFillRemaining` — an 864 dp card with one
  line of text at the top. Fixed with `mainAxisSize: MainAxisSize.min`. Every
  existing caller is inside an unbounded column, so their appearance is
  unchanged; two assertions in `feed_screen_test.dart` now pin the compact height.
- **Pictures had no height cap.** At the 900 dp measure a square grid cell was
  over 400 dp tall and a single 16:10 picture over 500, so one photograph filled
  the screen. `_PostImages` now measures its own width and caps the draw at
  300 dp, keeping the cell width and cropping instead. At a phone width nothing
  changes: the single picture is still 16:10 and the cells are still square.

### Verified

- `dart format` on the files this stage changed.
- `flutter analyze`: **no issues found** (9.6 s).
- `flutter test`: **550 passed, 47 skipped, 0 failed**.
  - 53 new tests over the 497/42 baseline: 13 repository + 13 controller + 10
    messages + 16 screen + 1 dashboard navigation.
  - The skips are 47 rather than 42 because five new captures joined
    `test/review/visual_review_test.dart`, which is gated on
    `SOLOVVO_VISUAL_REVIEW=1` and contributes every skip in this repository.
    Nothing was skipped to make this stage pass, and the same five captures pass
    when the variable is set (`flutter test test/review/visual_review_test.dart`
    → 47 passed).
- Existing tests were not weakened and no assertion was deleted. The one place
  this stage had to be careful is the dashboard's "See all" rule, which two
  existing tests assert in the negative; both still pass unchanged.
- `firestore.rules`, `firebase.json`, `.firebaserc`, `pubspec.yaml`,
  `pubspec.lock` and `firestore-rules-tests/` produce **no diff at all**, and
  nothing was deployed.

### Remaining issues

1. **The feed cannot be written, by design and by rules.** Every §14.1 mismatch
   is still real: `imageUrls` cannot be corrected under the current update rule,
   `commentCount` cannot move, `reports` has no rule, and `post_likes` disagrees
   with the declared likes path. The rules stage must run before any write path
   ships.
2. **The feed has never run against a real Firestore project.** There is no
   emulator or test account on this machine, so the query is verified by unit
   tests over a fake documents seam, not by a live read. The audit confirms the
   shape is permitted; it cannot confirm the data.
3. ~~**`feedPreviewProvider` is still empty**, so the dashboard's "See all" is
   wired but not reachable in the shipped app (see the decision above).~~
   **Closed by hardening Step 4 (2026-11-03)**: the provider is a projection of
   `feedControllerProvider`, and the community section reaches the feed whether or
   not the preview has anything in it. See the Stage 8.3 entry, defect 4.
4. **Post images are drawn but never load in tests.** The test renderer answers
   every network image with 400, so the tile's `errorBuilder` is what keeps the
   four-image test green — it proves the layout, not the picture. There is also
   still no bucket, policy or upload client for post images.
5. **Paging is manual.** A donor who wants fifty posts taps **Load more** five
   times. That is the deliberate trade recorded above, not an oversight, but it
   is a UX decision the owner may want to revisit once the write path exists.
6. **No realtime updates.** A newly published post appears only after a refresh.
7. **Brand spelling is still open** — see Stage 8.1's remaining issue 6.

### Next stage

**Stage 8.3 has not been started.** It must not begin until Stage 8.2 is approved,
and any write path still depends on the rules stage reconciling `firestore.rules`
with §14.1.

**Addendum, added by the Stage 8.3 recovery reconciliation — the paragraph above
is left as it was written because it was true at the time, and it is no longer
true.** Stage 8.3 was subsequently implemented and committed in `d27aee3`, the
same commit as this stage, and **it was built before this stage was approved** —
Stage 8.2 is still recorded as "awaiting approval" above, and no approval record
for it exists in this file or in the Git history. Two consequences for anyone
reading only this entry:

- The **"Deliberately not built"** list above no longer describes the tree. This
  stage genuinely built no create path, no image upload and no Supabase post
  storage; Stage 8.3 has since built the create path, the image upload and the
  post storage adapter. Read that list as the scope of 8.2, not as the state of
  the repository.
- Remaining issue 1 above — "The feed cannot be written, by design and by rules"
  — is **half obsolete**. The rules half is still exactly as stated and still
  unreconciled; the design half is not, because the feed can now be written. That
  makes the rules reconciliation more urgent than this entry assumed, not less.

See the Stage 8.3 entry below for the current state.

---

## Stage 8.3 — Post image storage and composer

**Status: IMPLEMENTED — HARDENING IN PROGRESS. Not complete, not signed off, not
deployed, not live-verified.** Committed in `d27aee3` ("Sholovvo UI and Feed
implementation"), which also carries Stages 7, 8.1, 8.1.1 and 8.2 — the stage
boundaries are not separable in Git. This entry was written by the recovery
reconciliation, from the source tree and measured command results, not from the
stage brief; there is no original Stage 8.3 completion report.

Three things have happened since that entry was written: the owner committed the
reconciliation documentation (`bbf1543`), the **Step 2 test fix** (`68f9ee8`)
resolved the one failing test below, and the **Step 3 and Step 4** hardening was
committed by the owner as `a1e102f`. **Step 5** then closed defects 10, 13, 14 and
15, and found and closed a sixteenth (a `README.md` claim that contradicted this file).
That makes the suite green; it does not make the stage complete. Defects 2, 3, 4,
10, 13, 14, 15 and 16 below are **closed** — 14 only as far as a client can close it — and
defects 5–9 remain open exactly as recorded at the reconciliation. Outstanding tasks 8,
9, 10 and 12 are done; tasks 6, 7 and 11 and the standing gate (task 2) are what is
left. The gate at the top of this file is met *today*, not *once and for all* — every
later hardening step has to re-run it.

**Five hardening steps have now run, and the Stage 8.3 entry below records all of
them.** Step 1 was the documentation reconciliation this file is written in; Step 2
closed the one failing test, test-side; Step 3 put the composer's presentation layer
under test — 73 widget tests, a `compose` capture group in the visual-review
harness, and one accessibility fix in `SolovvoButton`; Step 4 made the feed and the
composer reachable from the dashboard, projected the dashboard's community preview
onto the feed's own controller, and closed the malformed-document pagination dead end
with a bounded empty-page walk; Step 5 hardened the presentation of what Step 4 had
made reachable — the refusal count on both screens, the `discard()` guard, direct
coverage for a post tile, three missing image labels, and one false documentation
claim. Steps 3, 4 and 5 changed Dart source under `lib/` and changed **no** `domain`
or `data` file, no Firestore rule, no index, no bucket, no Supabase file and no
dependency. Nothing has been deployed and nothing has been verified against a live
backend; the suite is **733 passed, 58 skipped, 0 failed** and `flutter analyze` is
clean.

### What "implemented" means here, and what it does not

Five different states get conflated easily, and this stage is in only the first
and second of them:

| State | Stage 8.3 | Evidence |
| --- | --- | --- |
| **Implemented** | Yes | Every file below exists in the committed tree and is wired: `FeedScreen`'s `FloatingActionButton.extended` pushes `ComposePostScreen.route()`, a publish calls `FeedController.prepend`, and the dashboard's community section now opens `FeedScreen` whether or not it has posts to preview |
| **Unit-tested** | Widely, and still not live | 64 composer logic tests **plus 74 widget tests** over `ComposePostScreen` and `compose_image_grid` (Step 3, with Step 5's discard refusal), 21 pagination tests and the dashboard preview/navigation coverage (Steps 4 and 5), and **13 direct `FeedPostTile` / `ExpandablePostText` tests** (Step 5) — all passing. Whole suite: **733 passed, 58 skipped, 0 failed**. What no test covers: a real device, a real Firestore read, a real upload, or a real screen reader |
| **Approved** | **No** | No approval record exists for 8.3, and neither Stage 8.2 nor Stage 7 has been approved — 8.3 was built on top of an unapproved stage |
| **Deployed** | **No** | `firestore.rules`, `firebase.json` and `docs/storage/*.sql` were not applied by this stage and nothing was deployed |
| **Live-verified** | **No** | No post has ever been written to a real Firestore project, and no post photograph has ever been uploaded to real storage |

### What is in the tree

**Created — `lib/features/feed`**

| File | Job |
| --- | --- |
| `domain/post_repository.dart` | the write port: `publish(PostDraft) → Result<Post>` |
| `domain/post_image_storage.dart` | the storage port: `isConfigured`, `upload(ValidatedPhoto)`, `remove(objectPath)`, and `StoredPostImage` (url + path) |
| `domain/post_draft.dart` | `PostDraft` (author snapshot, text, uploaded images), `PostAuthor` and `PostAuthor.unknown()`; **carries no uid** — the repository takes it from the session, because the create rule compares `authorUid` to `request.auth.uid` |
| `data/post_writer.dart` | the narrow write seam: `authorUid`, `newPostId()`, `createPost(id, fields)`, so the repository holds no Firebase type |
| `data/firestore_post_writer.dart` | `FirestorePostWriter` over `FirebaseAuth` + `FirebaseFirestore` — the only file in the write path that touches a Firebase type |
| `data/firestore_post_repository.dart` | `FirestorePostRepository.publish`: session check, draft validation **before** any network call, `PostDocument.toCreateMap`, one `set` on a pre-allocated id, failure drops the entity |
| `data/supabase_post_image_storage.dart` | `SupabasePostImageStorage`: `{uid}/post-{millis}-{n}.{ext}`, one-year cache control, a fresh ID token per call, and `ownPath()` refusing any delete whose first segment is not the caller's uid |
| `application/compose_state.dart` | `ComposeState`: text, images, two busy flags, `isDirty`, and `issue` — the same `PostValidator` the mapper runs on read |
| `application/compose_providers.dart` | `postRepositoryProvider`, `postImageStorageProvider`, `postPhotoPickerProvider`, `composeAuthorProvider`, and `ComposeController` (`updateText`/`addImage`/`removeImage`/`discard`/`publish`) under one `_busy` guard |
| `presentation/compose_post_screen.dart` | the form: 560 dp measure, 6-line field, `PopScope(canPop: !isDirty)` + discard dialog, publish disabled while the draft has an issue **or** anything is in flight |
| `presentation/compose_messages.dart` | `composeFailureMessage`, resolving a `ValidationFailure` against photo issues first and post issues second |
| `presentation/widgets/compose_image_grid.dart` | an always-visible 2×2 grid of four cells, so the ceiling is visible rather than discovered |

**Created — delivery material and tests**

| File | Job / tests |
| --- | --- |
| `docs/storage/supabase-post-images.sql` | the `post-images` bucket and its two storage policies. **Delivered, not applied** |
| `test/features/feed/compose_controller_test.dart` | **32 tests, all passing** (31 at `d27aee3`, one of them failing — see defect 1; the 32nd pins the pick/upload distinction) |
| `test/features/feed/firestore_post_repository_test.dart` | 15 tests over `FakePostWriter`, pinning the exact document shape |
| `test/features/feed/supabase_post_image_storage_test.dart` | 15 tests, including the `ownPath()` delete guard |
| `test/support/fake_compose.dart` | fakes for the three ports; no tests of its own |

**Modified**

| File | Change |
| --- | --- |
| `lib/core/config/supabase_config.dart` | `postImagesBucket`, default `post-images`, as a **second bucket** rather than a subfolder of `avatars` |
| `lib/features/feed/presentation/feed_screen.dart` | the compose FAB, and the bottom padding that clears it |
| `lib/features/feed/application/feed_providers.dart` | `FeedController.prepend(post)` — no-ops before a page has loaded, dedupes by id, touches no cursor |
| `lib/l10n/app_en.arb`, `app_bn.arb` + generated | **18 `feedCompose*` keys in both catalogues** (37 `feed*` keys in total); `untranslated.json` stayed `{}` |
| `README.md`, `docs/ARCHITECTURE.md` (§14.3, §11 items 11–12), `docs/storage/README.md` | documentation |

**Not changed:** `firestore.rules`, `firebase.json`, `.firebaserc`, `pubspec.yaml`,
`pubspec.lock`, `firestore-rules-tests/` — none of them appears in the commit's
100-file diff. There is still no `firestore.indexes.json`. They are still unchanged
after the hardening steps: `git diff d27aee3 HEAD` over those paths returns only
`docs/storage/README.md`, which Step 1 rewrote as prose, and the last commit to
touch `firestore.rules` at all is `c9af690`, the four P0 findings.

**Added or changed by the hardening steps (2026-11-03, committed as `a1e102f`)**

Step 3 — the composer's presentation layer, and one accessibility fix:

| File | Change |
| --- | --- |
| `test/features/feed/compose_post_screen_test.dart` | **new — 40 tests**: the empty form, the text rules as messages, add tile → sheet → picker → upload → slot, publish gating, the discard flow, the no-bucket build, both languages, 320 dp, the tablet measure, and what a screen reader hears |
| `test/features/feed/compose_image_grid_test.dart` | **new — 33 tests**: four cells whatever the draft holds, the source sheet, removal naming the right photo, the in-place spinner, the grid frozen by a publish, its own semantics set |
| `lib/design/widgets/solovvo_button.dart` | the semantics node now carries the same `onTap` the `InkWell` gets (null while disabled). `ExcludeSemantics` was swallowing the derived press action, so the node announced a button nobody could press — the only production file Step 3 touched |
| `test/design/solovvo_button_test.dart` | 5 → **7 tests**: a pressable node, and a disabled one that is not offered as pressable |
| `test/review/visual_review_test.dart` | a `compose` group: 5 new declarations, **11 new captures** — which is where 11 of the suite's 58 skips come from |

Step 4 — reachability, the dashboard preview, and the pagination walk:

| File | Change |
| --- | --- |
| `lib/features/feed/application/feed_state.dart` | `isEmptyResult` now requires `!hasMore`, so "No posts yet" is only said of an exhausted collection |
| `lib/features/feed/application/feed_providers.dart` | `FeedController.maxEmptyPages = 5` and the bounded empty-page walk; a walk that reaches its cap appends rather than blanking what is on screen |
| `lib/features/home/application/home_providers.dart` | `feedPreviewLimit = 3`; `feedPreviewProvider` is a projection of `feedControllerProvider` instead of `const []` — same type, so every existing override still compiles |
| `lib/features/home/presentation/home_screen.dart` | the community section triggers the feed's own first read once, and renders four states: cards, a spinner, an error card with **Try again**, an empty card with **Open the community**; a preview card tap and **See all** both push `FeedScreen.route()` |
| `lib/features/home/presentation/widgets/home_section.dart` | `HomeEmptyCard` passes `action` through instead of dropping it |
| `lib/l10n/app_en.arb`, `app_bn.arb` + generated | one new key, `homeFeedOpenAction` ("Open the community" / "কমিউনিটি খুলুন"), in both catalogues; `untranslated.json` stayed `{}` |
| `test/features/feed/feed_pagination_test.dart` | **new — 17 tests**: repository cursor arithmetic over unreadable pages, the controller's walk, its cap, its concurrency and its retry, and three screen renders |
| `test/features/home/home_screen_test.dart` | 23 → **30 tests**: five preview states, the three-card cap, and two navigation cases |
| `test/app/app_shell_test.dart` | 11 → **12 tests**: the community opens above the shell and closes back to the dashboard |
| `test/support/fake_feed.dart`, `test/support/auth_harness.dart`, `test/features/home/home_profile_test.dart` | `FakeFeedDocuments.requestedAfter`; a `feedRepositoryProvider` override in both Home-mounting harnesses, so a dashboard test cannot reach `FirebaseFirestore.instance` |

Neither step touched `domain` or `data` in either feature: `git diff d27aee3 HEAD --
lib/features/feed/domain lib/features/feed/data lib/features/home/domain
lib/features/home/data` is empty.

**Test-side only, for the record:** Step 2 (`68f9ee8`) modified
`test/features/feed/compose_controller_test.dart`, `test/support/fake_compose.dart`
and `test/support/fake_photo_services.dart`, and nothing else. The older claim here
that **nothing under `lib/` has changed since `d27aee3`** was true when it was
written and is **no longer true**: Steps 3 and 4 changed eleven files under `lib/`
(six Dart, two ARB catalogues, three generated localisation classes), listed above.

### Known defects — four closed, the rest recorded without being fixed

Defects 1 to 4 have been closed — 1 by the Step 2 test fix, and 2, 3 and 4 by the
Step 3 and Step 4 hardening. Each closure below says what replaced it, because a
defect that is closed by a different mechanism than the one originally guessed at is
worth reading twice. Nothing on this list was closed by deleting its test, and
items 10–15 were recorded, not fixed.

1. **RESOLVED IN STEP 2 (2026-11-03, `68f9ee8`) — the suite was red, and this stage
   failed the project's own completion gate.** The failure, quoted as recorded at
   the reconciliation:

   ```
   test/features/feed/compose_controller_test.dart
     group:  ComposeController.addImage
     test:   reports uploading while the object is in flight
     expect: state().isUploading — Expected: true, Actual: <false>   (line 138)
   ```

   **Root cause: a test-synchronisation defect, not a production controller
   defect.** No Dart source changed **by that fix** — `git diff d27aee3 68f9ee8 --
   lib` is empty, and `ComposeController` was, and is, exactly what Stage 8.3
   committed. (Steps 3 and 4 later did change `lib/`; neither touched a compose
   file — the only `lib/features/feed/application` diffs since `d27aee3` are
   `feed_providers.dart` and `feed_state.dart`, both Step 4's feed work.)
   `addImage` awaits the **picker** before it sets `isUploading`, so at the instant
   the test asserted, three steps before that assignment, the controller was still
   inside `pick`. The un-awaited call meant the assertion measured the *pick* and
   not the upload, and the storage gate the test had installed had not been
   reached at all.

   **The fix, test-side and deterministic.** The test now waits for the upload to
   have actually started — `await storage.uploadStarted.future` — before asserting
   `isUploading`, then releases the gate, awaits the call, and checks the settled
   state. `uploadStarted` is a `Completer<void>` the fake completes on entry to
   `upload()`, so no delay, no `Future.delayed`, and no counting of microtasks is
   involved. `test/support/fake_compose.dart` (+11) and
   `test/support/fake_photo_services.dart` (+21) gained that entry signal, plus a
   `gate` on `FakePhotoPicker`; both are additive, and the picker's gate await only
   executes when a test installs it, so no existing consumer shifted timing
   (verified by running `test/features/profile` and `test/core/media`).

   **The state contract that was ambiguous is now explicit and tested:**

   - **Waiting for the picker is not reported as uploading.** A dedicated
     regression test, `waiting for the picker is not reported as uploading`, holds
     the pick open on `picker.gate`, asserts from inside `picker.entered` that
     `isUploading` and `isBusy` are both false with nothing uploaded, and then lets
     the flow finish. Anyone who later hoists `isUploading: true` above the pick
     will fail that test rather than silently change what the form promises.
   - **The controller's private `_busy` flag protects the whole
     image-selection-plus-upload flow**, including the window before any state has
     changed — which is the gap the pre-existing
     `a second tap while a pick is in flight opens no second picker` test pins.
   - **`ComposeState.isUploading` means the storage upload phase only** — bytes on
     the wire to `post-images`. It is what the add tile's spinner and
     `feedComposeUploading` render, and the platform picker owns the screen during
     the wait it deliberately does not cover.
   - A photo refused by `PhotoValidator` never sets the flag either, now asserted
     on the `bytes that are not an image never reach the network` test.

   The count went 31 → **32** in this file, and 61 → **62** across the composer's
   three files. The 47 skips were unchanged at that point (the opt-in visual-review
   harness); they are **58** today, and item 2 below says why.
2. **RESOLVED IN STEP 3 (2026-11-03) — `ComposePostScreen` had no widget tests and
   no visual review.** As recorded: no file under `test/` imports
   `ComposePostScreen` or quotes a `feedCompose*` key. So unverified by any test:
   the `PopScope`/discard flow, the
   publish-disabled-while-uploading rule, the unconfigured-bucket fallback message,
   the text counter, and all of `compose_image_grid`. `test/review/visual_review_test.dart`
   had a `feed` group and **no compose group**, and `docs/visuals/stage8/` holds
   only the five read-path renders. The 62 tests covered the logic around the screen,
   not the screen, and the presentation layer of this stage was the largest
   unverified surface in it (282 + 389 lines).

   **What closed it:** 73 widget tests — 40 in the new
   `test/features/feed/compose_post_screen_test.dart`, 33 in the new
   `test/features/feed/compose_image_grid_test.dart` — over the same fake ports, with
   a holdable picker and no delays; every item named above is now asserted, including
   the discard flow and the system back button. The harness gained a `compose` group
   of eleven captures, which is the +11 skips, and they pass under
   `SOLOVVO_VISUAL_REVIEW=1`. It also produced one real fix: `SolovvoButton`'s
   semantics node was announcing a button with no press action, because
   `ExcludeSemantics` swallowed the action Flutter derived from the `InkWell`.
   **What this defect has *not* closed:** the captures are written to gitignored
   `build/review/`, and `docs/visuals/stage8/` still holds only the five read-path
   renders — so the composer has been reviewed and never committed as a picture; and
   no real TalkBack or VoiceOver pass has been made on any device.
3. **RESOLVED IN STEP 4 (2026-11-03) — the malformed-document pagination dead-end**
   (found in 8.2). As recorded:
   `FirestoreFeedRepository` computes `hasMore` from the raw document count
   (`firestore_feed_repository.dart:39`) while dropping refused documents, so a
   page can return zero posts with `hasMore: true`. `FeedState.isEmptyResult` was
   then true, and the screen's empty branch (`feed_screen.dart:186-197`) returns
   **before** the footer that holds **Load more**. A run of eleven malformed
   newest documents rendered a permanently empty feed, and pull-to-refresh re-read
   the same window. `loadMore()` itself would work; there was no control to press.
   No test in `firestore_feed_repository_test.dart` or `feed_screen_test.dart`
   covered "zero kept with `hasMore: true`".

   **What closed it — three changes, none of them in `domain` or `data`, whose
   arithmetic was already right.** `FeedState.isEmptyResult` now requires
   `!hasMore`; `FeedController` walks past a page that carries no post, re-asking
   with the cursor that page returned, and stops at the first readable page, at the
   end of the collection, or at `FeedController.maxEmptyPages` = **5**; and a walk
   that reaches the cap appends to what is already on screen instead of blanking it.
   Increasing the page size was explicitly not the fix: it would delay the dead end
   rather than remove it, and would charge eleven reads per page for a problem only
   the *page* semantics had. `test/features/feed/feed_pagination_test.dart` pins all
   of it in 17 tests, including that the cursor advances over unreadable documents,
   that a run of them does not duplicate or skip a readable post, that a failure
   mid-walk is re-asked from the same place, that two taps start one walk, and that
   a wholly unreadable newest window still draws **Load more** rather than "No posts
   yet". The costs of the fix are items 11–14 below.
4. **RESOLVED IN STEP 4 (2026-11-03) — the feed and the composer were unreachable in
   the shipped app.**
   As recorded, `feedPreviewProvider` returned `const []`
   (`home_providers.dart:49-50`), and the dashboard hid its community **See all**
   over an empty list
   (`home_screen.dart:249-251`). `FeedScreen` is the only route to
   `ComposePostScreen`, and the dashboard is the only route to `FeedScreen`. The
   whole Stage 8 surface — read path, composer, image upload — therefore existed in
   code and could not be opened by a donor. That disclosure mattered because it
   changed the risk assessment of every other item: it was not a live exposure then,
   and it was a blocker on shipping. It also meant `docs/storage/README.md` step 6,
   which tells the owner to verify post photos by opening the feed, could not be
   followed as written.

   **What closed it:** `feedPreviewProvider` is now a projection of
   `feedControllerProvider` — three view models from the page the feed has already
   read, same provider type, so no override anywhere needed changing — and the
   community section renders four states, each with a way forward: cards, a spinner
   while the read runs, an error card with **Try again**, and an empty card with a
   new key, `homeFeedOpenAction` ("Open the community"), because **See all** may not
   be offered over nothing and an empty community is still a page worth opening. A
   preview card tap and **See all** both push the same `FeedScreen.route()`; nothing
   was added to `AppRoutes`, and no second feed data path was built. Coverage: 8
   tests in `home_screen_test.dart`, 1 in `app_shell_test.dart`, and a
   `feedRepositoryProvider` override in both Home-mounting harnesses so a dashboard
   test cannot reach `FirebaseFirestore.instance`. **The reachability makes defect 5
   more urgent, not less**: what the unenforced create rule now governs is something
   a donor can actually press.
5. **Firestore Rules still do not match the approved §14.1 schema, and a write path
   now exists.** `firestore.rules` is unchanged: post create checks only
   `authorUid == request.auth.uid` plus an optional `donationRecordId` the entity
   does not model; the update allow-list still names the singular `imageUrl` that
   nothing writes; no branch lets `commentCount` change; likes remain a top-level
   `post_likes/{likeId}` bound to a `userId` **field** rather than the document id,
   so the same donor can like a post twice; and `reports` has no rule at all.
   §14.1's decisions are preserved unchanged and remain unapplied. **`firestore-rules-tests/`
   covers no feed collection at all** — its groups are donation history,
   `response_claims`, notifications, `blood_requests` and the four P0 findings — so
   the create path has no automated guard on either side.
6. **Nothing in this stage has run against a live backend.** The `post-images`
   bucket, its policies and the Firebase third-party-auth setting are unapplied
   delivery material; no image byte has been transferred; and the app answers
   `isConfigured: false` and hides the photo control when the `SUPABASE_*` defines
   are absent, so the unconfigured path is the only one ever exercised here.
7. **Client-side validation only.** `PostValidator`'s limits (2 000 characters, 4
   images) are re-run before the write, but no rule enforces them; a different
   client can write anything the create rule tolerates.
8. **Optimistic time skew, by design.** `toCreateMap` writes
   `FieldValue.serverTimestamp()` while the returned `Post` and the prepended card
   carry the client clock. A donor with a wrong clock can see their post in the
   wrong position until the next read — bounded, documented in §14.3, and
   unverified against a real server.
9. **Orphans on abandoned drafts are only best-effort cleaned.** `discard()` deletes
   every uploaded object, but a failed delete is logged and not shown, and a
   process killed mid-compose leaves the objects behind. There is no sweep job.
10. **RESOLVED IN STEP 5 (2026-11-03) — `ComposeController.discard()` was not under
    the `_busy` guard.** It had been carried forward from Step 2 and deliberately not
    fixed by Step 3 or Step 4, because both were briefed to leave the compose
    upload-state contract alone. As it stood: `addImage` and `publish` both took the
    guard and `discard()` checked `state.isPublishing` only, so confirming the discard
    prompt while a photograph was still going up deleted a snapshot of the draft taken
    before that upload landed, and the object that arrived afterwards was named by
    nothing — an orphan in the bucket, under a form the donor believed they had thrown
    away.

    **What closed it.** `discard()` returns `Future<bool>`, takes the same `_busy`
    guard as its two siblings, and answers `false` when it refuses. `ComposePostScreen`
    pops only on `true`, so a refused discard leaves the form open rather than looking
    like it worked — the control-that-does-nothing §9 forbids. Widening the return type
    rather than re-checking the flags in the screen matters: the screen would otherwise
    have had to re-derive the controller's busy state to decide whether to close, giving
    one fact two owners. No new localisation key was added, because the grid already
    paints *"Uploading your photo…"* in the slot the donor is looking at, and a snackbar
    on top of that would name the rule instead of the reason. Three tests pin it — two on
    the controller (upload in flight, publish in flight) and one on the screen asserting
    the form is still open after the confirmation — and the three pre-existing `discard()`
    calls in `compose_controller_test.dart` now assert `isTrue` instead of ignoring a
    value that did not exist before. See `docs/ARCHITECTURE.md` §14.4.
11. **The empty-page walk is bounded, and a bound is not free.** One operation can
    spend five reads — fifty-five documents, because the repository over-fetches one
    per page — before it gives up and shows the donor an empty list with **Load
    more** under it. Tapping that button spends five more. The cap is what stops an
    unbounded loop charging a read every frame; it does not make scanning a
    malformed collection cheap. `docs/ARCHITECTURE.md` §7 states the plan's limits
    in kinds rather than numbers, so this is recorded as "fifty-five documents per
    operation, worst case" and left to the owner to weigh against the quota.
12. **The dashboard preview is as fresh as the last feed read, and no fresher.**
    The projection means one state, so the preview changes only when that state
    does: the dashboard's own first read on mount, or a read the feed screen
    triggers. There is no pull-to-refresh on Home and no listener, so a post
    somebody else publishes is invisible to a donor who stays on the dashboard —
    the donor's *own* post appears, because `FeedController.prepend` writes it into
    the same list. Adding a Home refresh would mean a second refresh path against
    one controller, which is the duplication the projection exists to prevent, and
    realtime is the stage that owns this properly. Deliberate, not overlooked.
13. **RESOLVED IN STEP 5 (2026-11-03) — "malformed" and "genuinely empty" were one claim on the dashboard.**
    `FeedScreen` could tell them apart, because `isEmptyResult` requires `!hasMore`:
    exhausted-and-empty draws "No posts yet", refused-and-more-coming keeps the list and
    its footer. The dashboard's section picked its card by fallthrough — no posts, not
    fatal, not loading — so after a walk that reached its cap it read **"No posts yet"**
    over a collection whose newest fifty documents are unreadable. That overstates it:
    "nobody has posted" is a fact about the community and "this app could not read what
    it posted" is a fact about the app, and saying the first when the second is true is a
    false report about other people.

    **What closed it.** `FeedState.isUnreadableResult` — empty, loaded, `hasMore`, and
    not in the middle of a read — and `_FeedSection` now has five states instead of four,
    with the new one sitting between the refused read and the spinner. It says the feed
    could not be fully read, gives the count, and offers **Open the community** rather
    than *Try again*: `loadFirstPage()` re-asks the same window and earns the same
    answer, so a retry button there would be the §9 failure mode again, and the way past
    an unreadable document is paging forward, which is what the feed screen lets a donor
    do. Pinned by one new dashboard test that asserts *"No posts yet"* is absent, the
    count is present, and the control lands on `FeedScreen`. See §14.4.
14. **CLOSED FOR THE DONOR IN STEP 5, STILL OPEN FOR THE OPERATOR — `FeedPage.skipped` now reaches a screen.**
    It used to exist, be computed and be asserted by tests while nothing in the app read
    it: schema drift showed itself only as a feed with fewer posts than the collection
    contained.

    **What closed the visible half.** The refusals accumulate across the bounded walk
    into `FeedState.skipped`, and both screens say it: the feed draws one line above its
    footer ("*N posts could not be shown*") with the working **Load more** left as the
    primary affordance, and the dashboard names the count inside its unreadable card
    (defect 13). `FeedController` also logs
    `_logger.warning('Feed read skipped N unreadable post document(s)')` on the
    `feed.read` tag — warnings survive a release build, so that line reaches `adb logcat`
    or the browser console. Four tests in `feed_pagination_test.dart` pin the arithmetic:
    that a full walk reports the total rather than the last page's number, that a later
    page adds to what is already on screen, that a failure which keeps the list on screen
    does not rewrite the count, and that the rendered string is the one the state carries.

    **What is still open.** There is no counter a remote operator can query without a
    device in hand, and there is no admin surface. That is a monitoring and backend
    question, not a client one, and it stays on the list as outstanding task 10's second
    half. See §14.4.
15. **RESOLVED IN STEP 5 (2026-11-03) — the `docs/storage/README.md` claim was false.**
    It still stated, under step 5 item 6, that "**The Feed is not currently reachable
    through normal navigation.** `feedPreviewProvider` returns an empty list and the
    dashboard hides its *See all* action", and told the reviewer the post-photo check
    was therefore not executable on a stock build without a temporary route. Step 4 made
    both halves untrue and the file was out of that step's permitted set.

    **What closed it.** Step 5 rewrote the item to name the real path — dashboard
    **From the community** → **FeedScreen** → **Share an update** → `ComposePostScreen`
    — recorded that the gap was closed by navigation rather than worked around, and kept
    the limitation that is actually true: the step is reachable now, but still not
    followable until the buckets and policies in that directory have been applied, which
    remains nobody's verified fact. There is still no per-post destination and nearby
    requests are still unwired, which is Stage 9 work rather than storage work.

    *Dated correction, Stage 9.1: the last clause is now false. `blood_requests` is
    read, the dashboard section and the **Open requests** screen are wired, and the
    storage file was corrected to say so. What remains true is the half this step
    could not close: there is still no per-post destination, still no destination for
    one request either, and nothing here has been verified against a live backend.*
16. **FOUND AND FIXED IN STEP 5'S DOCUMENTATION PASS — the root `README.md` contradicted
    `docs/PROJECT_STATE.md` about the composer's visual review.** Its *Getting started*
    visual-review paragraph said "**The composer has no render at all** —
    `test/review/visual_review_test.dart` has a `feed` group and no `compose` group",
    while the same file's own Status section said the harness "has a `compose` group of
    eleven captures" and Step 3's record said the same. The grep is decisive: the
    harness has `profile`, `feed` **and** `compose` groups. The sentence was a leftover
    from before Step 3 and survived the Step 4.1 synchronisation, which is what §12
    exists to catch. **Corrected** to the true shape — the captures exist and pass, and
    what is missing is a committed render under `docs/visuals/stage8/`, because
    `build/review/` is gitignored. No behaviour changed and no test moved; the claim was
    wrong, not the code. This is the kind of defect a documentation pass is expected to
    find rather than only to propagate, and it is recorded here rather than quietly
    edited, because a doc that has contradicted itself once can do it again.

### Outstanding tasks — hardening, in order

Tasks 1, 3, 4, 5, 8, 9, 10 and 12 have been completed — 1 by Step 2, 3 by Step 3, 4
and 5 by Step 4, and 8, 9 and 12 by Step 5, with 10 done as far as a client can do it.
Task 2 is a gate that has to be re-met, not a task that stays met. **Tasks 6, 7 and 11
below are what still stands between Stage 8.3 and "complete"** — and after Step 5 none
of the three is client code: the rules reconciliation, a live session only the owner can
authorise, and committing review art.

1. ~~Disposition defect 1: the failing test — test-side or controller-side, an owner
   decision.~~ **Done in Step 2 (2026-11-03, `68f9ee8`)**: it was a test
   synchronisation defect, fixed test-side; no controller behaviour or public
   interface changed, and the pick/upload distinction now has its own regression
   test.
2. **A standing gate, not a one-off task.** `flutter test` green and `flutter analyze`
   clean on the committed tree, re-measured at the end of every hardening step. Met
   again after Step 5 (733 / 58 / 0 and no analyzer issues, measured on the working tree
   that holds this step's documentation), which satisfies the gate at the top of this
   file for the current tree and nothing
   more: meeting it does not approve the stage, and tasks 6–12 below are what still
   stand between 8.3 and "complete".
3. ~~Widget tests for `ComposePostScreen` and `compose_image_grid`, and a `compose`
   capture group in the visual-review harness with renders in
   `docs/visuals/stage8/`.~~ **Done in Step 3 (2026-11-03)**, except the last clause:
   73 widget tests and eleven `compose` captures exist and pass, but the captures are
   written to gitignored `build/review/`, so **`docs/visuals/stage8/` still has no
   composer render**. Promoting them is an owner decision about committing binary
   review material, not a code task.
4. ~~Fix the pagination dead-end (defect 3) and pin it with tests.~~ **Done in Step 4
   (2026-11-03)**: `isEmptyResult` requires `!hasMore`, the controller walks past up
   to five unreadable pages, and 17 tests in `feed_pagination_test.dart` pin the
   cursor, the ordering, the duplicates, the cap, the retry and the concurrency.
5. ~~Decide the reachability question (defect 4): populate `feedPreviewProvider`, or
   add an explicit feed entry point, before any release.~~ **Done in Step 4, by the
   first of the two options and not the second**: the provider is a projection of the
   feed's own controller rather than a second read, and the empty section offers **Open
   the community** so the entry point no longer depends on data existing. No new
   route, no new tab, no new data path.
6. The rules stage reconciling `firestore.rules` with §14.1, **plus** the first
   feed-collection rules tests. This now gates any live deployment, because the
   write path exists in code **and is now reachable by a donor**.
7. An owner-approved live session: apply `supabase-avatars.sql` and
   `supabase-post-images.sql`, confirm the Firebase third-party-auth setting, then
   one real publish with two photographs. Step 4 removed the excuse that the feed
   could not be opened to check it; the bucket still has to exist first.
8. ~~Fix defect 10, the `discard()` / `_busy` race, in `ComposeController`, with a
   test that holds the picker or the upload open.~~ **Done in Step 5 (2026-11-03)**: the
   deferred step arrived, the guard was taken, `discard()` became `Future<bool>`, and the
   hold-open tests are on both halves — two on the controller, one on the screen.
9. ~~Give the dashboard preview the same honesty the feed screen got (defect 13): consult
   `hasMore` before saying "No posts yet" over a collection that is merely unreadable.~~
   **Done in Step 5**, by `FeedState.isUnreadableResult` and a fifth section state, with
   the affordance being **Open the community** rather than a retry that cannot change the
   answer.
10. ~~Surface `FeedPage.skipped` somewhere an operator can see it (defect 14)~~ —
    **done in Step 5 as far as a client can**: the count reaches the feed's own line, the
    dashboard's card and a release-surviving warning on the `feed.read` tag. **The half
    that stays open is a counter a remote operator can query without a device**, which
    belongs with the monitoring or backend stage rather than this one.
11. **Commit the composer's visual review** (remainder of task 3), and give Stage 8 a
    real browser pass — Stages 3, 4 and 5 have one and 6, 7 and 8 have widget renders
    only. Step 5 added no captures, so this stands exactly where Step 3 left it.
12. ~~Correct `docs/storage/README.md` (defect 15)~~ — **done in Step 5**, and the step
    now names the real navigation path. **The second half of this task is not a code task
    and is not done:** re-verify the approval record. Stages 7, 8.1, 8.1.1, 8.2 and 8.3
    are all still unapproved, so the tracker at the top of this file cannot move past
    "hardening in progress" on the strength of a green suite — and a fifth hardening step
    being green changes that in no way.

### Verification

Measured three times, in full, on the committed tree — nothing below is inferred
from a partial run.

**At the Step 1 reconciliation, on `d27aee3`.** Kept as the record of what the
audit found; the rows about test status are superseded by the next table.

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** (98.3 s) |
| Full suite | `flutter test` | **610 passed, 47 skipped, 1 failed** — the failure was defect 1 |
| The failing test alone | `flutter test test/features/feed/compose_controller_test.dart` | `+30 -1`, reproducible (before Step 2) |
| Baseline for comparison | Stage 8.2's entry above | 550 passed, 47 skipped, 0 failed. The +61 executed tests were exactly this stage's three files (31 + 15 + 15), and one of them failed |
| Format | `dart format --output=none --set-exit-if-changed lib test` (inspection only, wrote nothing) | **77 of 180 files** are not format-clean under Dart 3.13.7 — inherited from Stage 8.1's decision to avoid formatting churn, not caused by this stage |
| Toolchain | `flutter --version` | Flutter 3.47.9 stable, Dart 3.13.7 |
| Rules tests | `npm test` in `firestore-rules-tests/` | **Not run** — needs the Firestore emulator, and no rules changed here |
| Live Firebase / Supabase | — | **Not run.** No emulator session, no device build, no browser pass, no network write |

**After the Step 2 test fix, on `68f9ee8`.** This is the current state.

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** (26.4 s) |
| Full suite | `flutter test` | **612 passed, 47 skipped, 0 failed** — defect 1 closed, one test added |
| The formerly failing test alone | `flutter test test/features/feed/compose_controller_test.dart --name "reports uploading while the object is in flight"` | **`+1`, 0 failed** |
| Its file | `flutter test test/features/feed/compose_controller_test.dart` | **`+32`, 0 failed** (was `+30 -1`) |
| All feed tests | `flutter test test/features/feed` | **184 passed, 0 failed** |
| Shared-picker regression | `flutter test test/features/profile` | **176 passed, 0 failed** — `FakePhotoPicker` is used by both features |
| Shared photo primitives | `flutter test test/core/media` | **16 passed, 0 failed** |
| Composer test count | `test(` counted per file | **62** — 32 controller + 15 repository + 15 storage |
| Format | `dart format --output=none --set-exit-if-changed` on the three changed test files **and** on copies of their `HEAD` versions (inspection only, nothing written) | Both changed and unchanged versions report "Changed", so **no new formatting deviation was introduced**; no repo-wide formatting was run |
| Rules tests | `npm test` in `firestore-rules-tests/` | **Not run** — needs the Firestore emulator, and no rules changed |
| Live Firebase / Supabase | — | **Not run.** No emulator session, no device build, no browser pass, no network write |

**After hardening Steps 3 and 4, on `a1e102f`.** This was the state until Step 5; the
next table supersedes its counts. The
arithmetic reconciles exactly: 612 passed + 75 (Step 3: 40 + 33 widget tests, 2
semantics tests) + 25 (Step 4: 17 pagination, 7 dashboard, 1 shell) = **712**; and
47 skips + 11 `compose` captures = **58**.

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** (18.5 s) |
| Full suite | `flutter test` | **712 passed, 58 skipped, 0 failed** |
| Composer screen | `flutter test test/features/feed/compose_post_screen_test.dart` | **40 passed, 0 failed** (new file) |
| Composer grid | `flutter test test/features/feed/compose_image_grid_test.dart` | **33 passed, 0 failed** (new file) |
| Pagination | `flutter test test/features/feed/feed_pagination_test.dart` | **17 passed, 0 failed** (new file) |
| All feed tests | `flutter test test/features/feed` | **274 passed, 0 failed** (was 184 after Step 2) |
| Dashboard, shell | `flutter test test/features/home`, `flutter test test/app` | **38** and **37 passed, 0 failed** — 75 together |
| Design system | `flutter test test/design/solovvo_button_test.dart` | **7 passed, 0 failed** (5 before the semantics fix) |
| Opt-in visual review | `$env:SOLOVVO_VISUAL_REVIEW=1; flutter test test/review/visual_review_test.dart` | **58 passed, 0 failed** — the 47 that existed after Step 2 plus the 11 `compose` captures, run against this tree, so the dashboard captures pass with the feed preview reading the fake repository. PNGs land in gitignored `build/review/`; **none has been committed to `docs/visuals/`** |
| Localisation parity | `test/l10n/arb_parity_test.dart` inside the suite, plus `lib/l10n/untranslated.json` | passes; the file is **`{}`** — one new key (`homeFeedOpenAction`) present in both catalogues |
| Format | `dart format --output=none --set-exit-if-changed lib test` (inspection only, wrote nothing) | **79 of 183 files** are not format-clean under Dart 3.13.7. The move from Step 1's 77 of 180 is exactly the two new Step 3 test files: **no pre-existing file changed state**, and Step 4's new file is clean. No repo-wide formatting was run, in either step — the inherited condition is Stage 8.1's decision, not a new deviation |
| Trailing whitespace | `git diff --check` | **no output** |
| Rules tests | `npm test` in `firestore-rules-tests/` | **Not run** — needs the Firestore emulator, and no rule changed in either step |
| Live Firebase / Supabase | — | **Not run.** No emulator session, no device build, no browser pass, no network write, no bucket, no policy |

**After hardening Step 5 (Stage 8.4).** This is the current state, measured on the
tree that carries this step — Step 5's Dart and localisation changes are in `9298fb5`
and `ee8aba0`, and its documentation, the two formatted test files and the removal of
two scratch logs are in `5d18d4d`, so **no Dart or test file differs between the tree
measured below and `5d18d4d`**; only this file was still being written when the last
`flutter test` finished. The arithmetic reconciles exactly: 712 + 21 = **733**, and the 21
are Step 5's 13 tile tests + 4 pagination tests + 2 controller discard tests + 1
composer-screen discard test + 1 dashboard test. Skips are unchanged at **58**, because
Step 5 added no visual-review capture.

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** (19.1 s; 20.5 s on the first run of the step) |
| Full suite | `flutter test` | **733 passed, 58 skipped, 0 failed** — twice, before and after the two files `dart format` wrote |
| Post tile | `flutter test test/features/feed/feed_post_tile_test.dart` | **13 passed, 0 failed** (new file) |
| Pagination | `flutter test test/features/feed/feed_pagination_test.dart` | **21 passed, 0 failed** (was 17) |
| Composer controller and screen | `flutter test test/features/feed/compose_controller_test.dart test/features/feed/compose_post_screen_test.dart` | **75 passed, 0 failed** (was 72: 32 → 34 and 40 → 41) |
| All feed tests | `flutter test test/features/feed` | **294 passed, 0 failed** (was 274 after Step 4) |
| Dashboard, shell | `flutter test test/features/home`, `flutter test test/app` | **39** and **37 passed, 0 failed** |
| Localisation parity | `flutter gen-l10n`, then `test/l10n/arb_parity_test.dart` inside the suite, plus `lib/l10n/untranslated.json` | gen-l10n exits 0 and regenerates the three tracked files; parity passes; the file is **`{}`** — four new keys (`feedUnreadableTitle`, `feedUnreadableBody`, `feedSkippedNotice`, `feedPostPhotoLabel`) in both catalogues, the plural routed through `decimalPattern` so a Bangla count is written in Bengali digits, and no ASCII digit anywhere in `app_bn.arb` |
| Format | `dart format --output=none --set-exit-if-changed lib test` | **79 of 184 files** not format-clean — Step 4's 79-of-183 count with one more file in the denominator, so **no pre-existing file changed state**. Two files of this step's own were dirty and *were* formatted **with** a write (`test/features/feed/feed_pagination_test.dart`, `test/features/feed/feed_post_tile_test.dart`), after which both the two files and the whole suite were re-run; no repo-wide formatting was run |
| Trailing whitespace | `git diff --check` | **no output** |
| Toolchain | `flutter --version` | Flutter 3.47.9 stable, Dart 3.13.7 — unchanged |
| Rules tests | `npm test` in `firestore-rules-tests/` | **Not run** — needs the Firestore emulator, and `firestore.rules` was not touched by this step or by any hardening step |
| Screen reader | — | **Not run.** No TalkBack or VoiceOver pass has been made on any stage; the three new `semanticLabel`s and the copy control's tooltip are asserted by widget test, which proves the node carries a string, not that the string reads well out loud |
| Live Firebase / Supabase | — | **Not run.** No emulator session, no device build, no browser pass, no network write, no bucket, no policy, no SQL |

**Step 5 also removed two files from the repository root** — `analyze_baseline.txt`
and `test_baseline.txt`, scratch logs of this step's first `flutter analyze` and
`flutter test` runs, which had been swept into `9298fb5` by an `add -A` (Git stores them
as binary blobs). They are command output, not project material, and the numbers they
held are recorded in this table instead. The owner committed the deletion in `5d18d4d`.

**Documentation-only pass, Step 4.1.** This synchronisation edited `README.md`,
`docs/ARCHITECTURE.md` and this file and nothing else. It ran `flutter test`,
`flutter analyze`, the opt-in review harness and `dart format` in inspection mode
(writing nothing) in order to measure the numbers above rather than copy them
forward; it changed no Dart source, no test, no localisation file, no Firestore
rule and no Supabase file, and it staged and committed nothing.

### Git state

`main`, no stash, no tags, one remote (`origin`). When this entry was written HEAD
was `d27aee3`; the owner then committed the Step 1 reconciliation documentation as
`bbf1543`, the Step 2 test fix as `68f9ee8`, and the **Step 3 and Step 4 hardening,
together with the Step 2.1 documentation, as `a1e102f`** on 2026-11-03 — 24 files,
+3 164/−118 — and pushed it, so `refs/remotes/origin/main` was **also `a1e102f`** as of
21:38 the same day. **Step 5 was committed in three pieces while it was still being
written**: `9298fb5` (22:50) took the feed-state foundation, the four localisation keys
and their generated output, and the Step 4.1 documentation, together with the two
scratch logs named above; `ee8aba0` (23:04) took the eight `lib/` files and the six test
files; `5d18d4d` (23:29) took this step's documentation, the two formatted test files
and the deletion of those logs. So **HEAD is `5d18d4d`** and `origin/main` is
**`5d18d4d`** — level, 0 ahead and 0 behind — which means the whole of Stage 8.4 is on
the remote except this file's final edits.
That was the owner's action throughout, not this pass's: **Step 5 staged, committed and
pushed nothing**, and it ran no Git command that writes. It did not discard anything
either — the pre-existing uncommitted documentation edits it inherited from Step 4.1 are
all present in `9298fb5`.
Pushing the branch is not deploying anything: no rule has been released with
`firebase deploy`, no build has reached a device, a store or a browser, and no
Supabase migration or bucket policy has been applied — so *deployed* and
*live-verified* stay **No** for the whole of Stage 8.3, `a1e102f` and Step 5's three
commits included.
Stage boundaries are still not separable in Git: `d27aee3` squashes Stages 7 → 8.3
into one commit, so **8.3 cannot be separated from 8.2 by Git alone**, which
matters if Stage 8.2's approval is later withheld. Steps 3 and 4 are separable from
that only by this file's account, since `a1e102f` carries both: the feed's own
`lib/` diff is Step 4's, and `solovvo_button.dart` plus the two compose test files
are Step 3's. Step 5 is the harder case, because its own work is split across three
commits that each also carry something else: `feed_state.dart` is patched in **both**
`9298fb5` and `ee8aba0`, and `9298fb5` carries Step 4.1's documentation as well. No
remote state has been re-verified against the network.

### Next stage

Stage 8.3 must be hardened and approved before Stage 9 (normal blood search &
maps) or any feed write is treated as shipped. The rules reconciliation is the
blocking dependency for deployment, not for code.

**What the hardening steps changed about that sentence.** Five of the seven
outstanding tasks are done, the two that blocked a donor using the feature at all —
reachability and the pagination dead-end — are closed, and the three client items that
Step 4 left recorded (defects 10, 13 and 14) are closed too, so there is a working path
from the dashboard to the feed to the composer and back, a composer that cannot be
thrown away underneath its own upload, and a feed that says when it could not read what
is there. What still blocks *shipping* is one item and it is not code: the write path is
reachable and still has no rule behind it (defect 5), and nothing in Stage 8 has ever
been verified against a live backend (defects 6 and 7). The next step is therefore the
rules reconciliation with §14.1 plus the first feed-collection rules tests — the only
remaining task that gates deployment, and one that needs the owner's security approval
before `firestore.rules` moves. Stage 9 (normal blood search and maps) should not start
on top of an unapproved, unenforced write path that a donor can now actually reach.

**What happened after that was written.** Stage 9.1 has since been built — the entry
at the end of this file — and it is not a breach of the sentence above. 9.1 is a
read: it writes nothing, it needed no rule to move, and it does not touch the feed's
unenforced write path. The two items that gate *deployment* — the rules
reconciliation (defect 5) and the first live pass against a real backend (defects 6
and 7) — are untouched and still stand, for Stage 8 and Stage 9.1 alike. What that
sentence was guarding against, a donor being led to believe a request can be raised
or answered from this build, is still not possible: 9.1 shows a list and says so in
one line under it.

---

## Stage 9.1 — Open blood requests, read path

**Status: IMPLEMENTED against fakes. Not approved, not deployed, not live-verified.**
The whole of this stage has never read a real Firestore project. Every claim below
about what the app *shows* is backed by a widget test over a fake; every claim about
what the collection *contains* is backed by `firestore.rules` and by the seed
documents in `firestore-rules-tests/firestore.test.js`, which is the only place in
this repository where a `blood_requests` document has ever been written — and only
into an emulator that this stage did not run.

The stage's own architecture record is `docs/ARCHITECTURE.md` §15. This entry
records the scope decisions, the files, the measurements and what is outstanding.

### Why a read path could be built now

`firestore.rules` already answers the only permission question this stage asks:

```
match /blood_requests/{id}
  allow read: if request.auth != null;
```

That rule is **frozen and was not edited** — no rule, no field, no index, no
`firebase.json`, no SQL and no bucket was touched by this stage, and nothing was
deployed or `firebase deploy`-ed. The read needs no approval it does not already
have, which is the difference between this stage and the feed's write path. The
consequence of that same rule is worth stating plainly: any signed-in user can
already read `patientName` and `phoneNumber` out of a `blood_requests` document.
This app chooses not to put them into its read model, and §15 records why the
choice had to be made in the mapper rather than in the rules.

### Scope, and what it deliberately is not

Stage 9.1 is the first slice of Stage 9 and only the first. Named explicitly,
because the stage's title promises more than it delivers:

| In 9.1 | Not in 9.1 |
| --- | --- |
| Read `blood_requests` where `status == 'open'` | any write of any kind |
| One window of 25, sorted soonest-needed-first | paging, cursors, a **Load more** |
| The dashboard's requests section, with real rows | donor search (Stage 9's other half) |
| `RequestsScreen` behind **See all** | maps, distance, location permission |
| Loading / empty / error / retry / refusal states | a per-request destination or detail |
| Group, units, place, date as typed | accepting, claiming, contacting — Stage 10's transaction |

The two headline actions on the dashboard (**Request blood**, **Find donors**) still
answer with the *coming soon* notice, and that is correct rather than unfinished:
the first needs Stage 10's write rule and the second needs a donor search that does
not exist yet.

### The query, and the Firestore ordering fact that shaped everything

The read is one call, with no `orderBy` and no cursor (field names are constants in
`FirestoreRequestDocuments`, and the collection is `blood_requests`):

```dart
collection('blood_requests')
    .where('status', isEqualTo: 'open')
    .limit(RequestRepository.window + 1)
    .get();
```

Before it, `fetch` checks `_auth.currentUser` and answers a signed-out call with an
`AuthFailure` rather than with the `permission-denied` the rules would send, and a
non-positive `limit` never reaches the network at all.

**Why there is no `orderBy` on the date.** `requiredDateTime` is free **TEXT** in
this collection — the create rule requires the *key* and constrains no type for it,
and the rules-test seed writes `'2026-11-10 10:00 AM'`. Firestore orders by *type*
before it orders by value: bind a `Timestamp` and every text document sorts after
it, `orderBy` a field that is sometimes a string and sometimes a timestamp and the
read either returns nothing useful or throws a composite-index error. Either
mistake does not look like a bug — it looks like "there are no open requests", on
screen, over a full collection. So the urgency sort happens client-side, in
`compareByUrgency`, where a mixed-type field can be reasoned about and tested.

**Why there is no cursor.** An unordered window cannot be paged forward: a cursor
needs a stable sort key, and the sort key here is computed after the read. The
over-fetch of one document is what makes `OpenRequests.truncated` *measured* rather
than inferred — a collection of exactly 25 open requests does not get a notice about
requests that are not there.

**Index cost: none.** A single equality filter with the default `__name__` order is
served by the automatic single-field index on `status`, so no composite index is
required and `firestore.indexes.json` does not exist in this project and was not
created.

### The five states, and the one precedence rule that decides between them

`RequestsState` exposes four resolved predicates plus an in-flight case, and both
surfaces — the dashboard section and `RequestsScreen` — read the same ones:

| State | Predicate | What the donor sees |
| --- | --- | --- |
| First read in flight | `isInitialLoading` | a spinner, and nothing is claimed |
| Nothing open | `isEmptyResult` | *No open requests* + "when someone needs blood, their request appears here first" |
| Read failed | `isFatalError` | *The requests could not be loaded* + a working **Try again** |
| Read partly unreadable | `isUnreadableResult` | *could not be fully read*, **no button** — the window is not empty and retrying re-asks the same documents |
| Ready, with caveats | `truncated` / `skipped` | the rows, plus "only the first 25 are shown" and/or "*n* requests could not be shown" |

`isEmptyResult` is `requests.isEmpty && loaded && !truncated && skipped == 0 &&
status != loading`, and `isUnreadableResult` is its mirror. **The refusal count is
part of the definition of empty**, which is the whole point: an empty list that came
from documents the mapper could not read is not "no open requests", and saying so is
the difference between an honest screen and one that tells a donor nobody needs blood
today. Both surfaces test `isFatalError` *before* `isEmptyResult`, so a failed refresh
of an empty window says "could not be loaded" and never "no open requests". There is
a test for exactly that case on both surfaces.

Retry appears only where a retry could change something: on a fatal error, and as
pull-to-refresh on the screen. The unreadable state deliberately has no button.

### Decisions taken before any code was written

1. **Read model, not document dump.** `BloodRequest` carries id, group, hospital,
   address, units and two date fields. No `patientName`, no `phoneNumber`, no
   `notes`, no `latitude`/`longitude` — those keys are never read into the entity at
   all, so no log line, `toString()`, test failure or widget can print them. Both
   `BloodRequest.toString()` and `OpenRequests.toString()` name numbers and no place.
2. **Two fields for one date.** `neededBy` (a real instant, when the text could be
   read as one) and `neededByText` (the stored text verbatim). Neither invents a value
   for the other; a row with no readable date shows what the person typed, and one
   with no text at all shows *No date given*. An undated request sorts **after** every
   dated one, because "we do not know when" is not the same claim as "on Friday".
3. **Refuse, and count.** A document whose blood group is not one of the eight the
   rules accept, or whose units are not an `int >= 1`, is dropped and counted in
   `skipped`. One malformed document cannot empty the list.
4. **One tile, one controller, two surfaces.** `nearbyRequestsProvider` is
   `requestsControllerProvider`'s window `.take(3)`. The dashboard's three rows and
   the screen's twenty-five are the same list from the same read, so the two cannot
   disagree about what is urgent — the same pattern Stage 8.4 used for the feed
   preview (§14.2).
5. **No dead controls.** Nothing in a row is tappable, because there is nowhere for a
   row to go until Stage 10. `RequestTile` has no `onTap`, no `InkWell`, no
   `GestureDetector`, no chevron — and a widget test asserts their absence, so adding
   one without a destination fails the suite rather than shipping a lie.
6. **Never a false empty.** See the precedence rule above; it is tested on both
   surfaces and on both the `skipped` and the `truncated` path.

### What is in the tree

**Created — `lib/features/requests` (13 files, four layers)**

| File | Job |
| --- | --- |
| `domain/entities/blood_request.dart` | the read model; the privacy decision is made here, and documented in the class doc |
| `domain/open_requests.dart` | `OpenRequests` — the window: `requests`, `truncated`, `skipped`; immutable, and the test that it cannot be mutated after hand-out is in the repository suite |
| `domain/request_ordering.dart` | `compareByUrgency` and `orderRequests` — dated before undated, soonest first, past dates left first, read order preserved inside a tie, input list never mutated |
| `domain/request_repository.dart` | the read port, one method, and `window = 25` with the reason it is a window and not a page |
| `data/models/blood_request_document.dart` | the pure mapper: `fromMap(id:, data:)`, `parseRequiredText`, the 12-hour clock, the calendar check, and the refuse-and-count rules |
| `data/request_documents.dart` | the narrow seam — `RequestDocument` (id plus the wire's own field map, unreconstructed) and `RequestDocuments.fetch({required int limit})`, so no Firestore type crosses into the repository |
| `data/firestore_request_documents.dart` | the only file in the feature that touches `FirebaseFirestore`: the one `where`/`limit`/`get`, a non-positive limit answered without a round trip, and `FirebaseException`/`Exception` classified by `mapFirestoreCodeToFailure`/`mapExceptionToFailure` |
| `data/firestore_request_repository.dart` | `FirestoreRequestRepository`: seam call at `window + 1`, failure passed through untouched, map with refuse-and-count, `truncated` measured from the over-fetch, `orderRequests` applied above the repository |
| `application/requests_state.dart` | `RequestsStatus`, `RequestsState`, the four predicates, `copyWith`, and a `toString` that names counts and no place |
| `application/requests_providers.dart` | `requestRepositoryProvider` (built lazily, so a tree that never asks for requests never touches `FirebaseFirestore.instance`) and `requestsControllerProvider` over `RequestsController` (`load`/`refresh` under one in-flight guard) — two public providers, and the repository is the one seam every test of this feature overrides |
| `presentation/requests_messages.dart` | the one place that turns a state into a sentence, shared by both surfaces so the dashboard and the screen cannot word the same failure differently |
| `presentation/requests_screen.dart` | the **See all** destination: window of 25, footer note instead of a **Load more**, pull-to-refresh, retry on fatal error, 900 dp measure |
| `presentation/widgets/request_tile.dart` | the row both surfaces share: badge, units · needed-by, hospital, area — and nothing tappable |

**Created — tests (109 tests)**

| File | Tests | Covers |
| --- | --- | --- |
| `test/features/requests/blood_request_document_test.dart` | 27 | the mapper, both date shapes, the 12-hour clock, the eight groups, every refusal |
| `test/features/requests/request_ordering_test.dart` | 13 | comparator direction, ties, undated last, past dates first, idempotence, no input mutation, a full reversed window |
| `test/features/requests/firestore_request_repository_test.dart` | 15 | the limit asks for `window + 1`, ordering applied above the repository, `truncated` exact at 25 and 26, refusals counted only inside the window, failure pass-through, no privacy leak in `toString` |
| `test/features/requests/requests_controller_test.dart` | 20 | every state transition, one read at a time under concurrent calls, a failed refresh keeping the list, caveats surviving a failure, retry always possible |
| `test/features/requests/request_tile_test.dart` | 10 | the four facts, the combined units · date node, address suppression, the no-dead-control assertion, a 320 px long name, Bangla, dark |
| `test/features/requests/requests_screen_test.dart` | 24 | order on screen, footer note, honest empty, error-before-empty, retry, unreadable with no button, both notices, pull-to-refresh and a refused second pull, wide measure, three Bangla cases |
| `test/support/fake_requests.dart` | — | `FakeRequestRepository` + `FakeRequestDocuments` in the house harness style: `gate` (`Completer<void>?`), `calls`, `lastLimit`, `failure` |

**Modified — `lib`**

| File | Change |
| --- | --- |
| `features/home/application/home_providers.dart` | `nearbyRequestsProvider` stops being an empty-list stub and becomes the `take(3)` projection of the controller; `nearbyRequestLimit` names the three |
| `features/home/presentation/home_screen.dart` | the requests section is a real five-state surface: rows, notices, honest empty, fatal error with **Try again**, unreadable without a button, **See all** pushing `RequestsScreen`; the two headline actions are unchanged |
| `features/home/presentation/widgets/home_cards.dart` | `NearbyRequestCard` is gone; the dashboard renders the shared `RequestTile` instead, so there is one row design for one entity |
| `features/home/domain/home_dashboard.dart` | the `NearbyRequestCard` view model and its fake-friendly constructor are deleted — the projection now returns real `BloodRequest`s |
| `l10n/app_en.arb`, `l10n/app_bn.arb`, `l10n/generated/*` | 14 keys added, 3 renamed (below) |

**Modified — tests that had to be migrated (not weakened)**

| File | Why it changed |
| --- | --- |
| `test/features/home/home_screen_test.dart` | asserted the *stub*: "Requests near you" and "No open requests nearby" are now "Open requests" and "No open requests", and the section has states to test, so the file grew to cover them |
| `test/features/home/home_profile_test.dart`, `test/app/app_shell_test.dart`, `test/support/auth_harness.dart` | the dashboard now reads the window on mount, so every harness that mounts it must override `requestRepositoryProvider` with `FakeRequestRepository()` — the same treatment the feed got in Stage 8.4, and for the same stated reason: a fresh fake holds nothing, which is what a collection nobody wrote to holds |
| `test/review/visual_review_test.dart` | a `requests` capture group — populated light English, populated dark Bangla, window-full light English, empty light English, read-failed dark Bangla — and the same repository override for the dashboard shots |

**Deleted** — nothing outside the two view-model/card names above; `git status`
shows no deletion.

### Localisation

14 keys added to **both** catalogues, in the same commit, and `test/l10n/arb_parity_test.dart`
guards that they stay paired:

- `requestsTitle`, `requestsEmptyTitle`, `requestsEmptyBody`, `requestsErrorTitle`,
  `requestsRetry`, `requestsUnreadableTitle`, `requestsUnreadableBody`,
  `requestsSkippedNotice`, `requestsTruncatedNotice`, `requestsNoActionNote`;
- `homeRequestsTitle`, `homeRequestsEmptyTitle`, `homeRequestsEmptyBody`,
  `homeNeededByUnknown`.

**Three keys were renamed, not added.** `homeNearbyTitle`, `homeNearbyEmptyTitle`
and `homeNearbyEmptyBody` ("Requests near you" / "No open requests nearby") became
`homeRequests*` with the "near you" wording **removed on purpose**. Nothing in 9.1
knows where the donor is: `latitude`/`longitude` are in the document and are not read
into the entity, and no distance is computed. "Near you" over a list that cannot
compute near is a claim about the world the app has not checked, so the section is
called **Open requests** and the tile's place line is the typed address or hospital.

`requestsSkippedNotice` is a plural routed through `decimalPattern`, so a Bangla
count is written in Bengali digits; `lib/l10n/untranslated.json` is `{}` and
`app_bn.arb` contains no ASCII digit, both of which the parity test enforces.

### Database changes

**None.** `firestore.rules` is frozen and was not edited, moved, deployed or
weakened; `firebase.json`, `firestore-rules-tests/`, `docs/storage/*.sql`
and the Supabase project were not touched. No composite index is needed by this read
and none was created.

### Packages added

**None.** No dependency, no `pubspec.yaml` line, no `pubspec.lock` change.

### Bugs found during verification, and fixed

Both are in the mapper, both were found by tests written for this stage, and **both
exist in the commit that is currently on `origin/main`** — see Git state below.

1. **Every AM/PM date was silently refused.** `_meridiem` captures the marker's
   *first letter* (`([AaPp])\.?[Mm]\.?`), so that `P.M.` and `pm` share one pattern,
   but `_applyMeridiem` switched on the whole word — `'AM' => …, 'PM' => …`. The
   switch never matched, fell to `_ => null`, and every request whose
   `requiredDateTime` was written the way this collection actually writes it
   (`'2026-11-10 10:00 AM'`) arrived as *undated* and sorted to the bottom of an
   urgency-sorted list. Fixed by switching on the captured letter (`'A'`/`'P'`), with
   the parameter renamed and the contract documented.
2. **An impossible date was rolled over, not refused.** `DateTime.parse` does not
   range-check: `2026-13-40` becomes a real instant in February of the next year. The
   mapper accepted it, so a typo'd request would be ordered on a day nobody wrote —
   in a list whose entire purpose is ordering by how soon blood is needed. Fixed by
   `_dateParts` + `_isRealDate`, which compare the parsed fields against the ones as
   written and refuse the roll-over. The check runs on the **text**, not on the
   returned value, because a `+06:00` value that crosses midnight in UTC would
   otherwise be rejected for a day it never claimed to be.

Neither was a test-side fix: the tests were right and the production code was wrong,
so the suite drove the change rather than the change driving the suite.

### Verification

Every number below was measured on this tree in this pass, not copied forward.

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found!** — twice in this pass, and the second run was after every documentation edit |
| Whole suite | `flutter test` | **851 passed, 63 skipped, 0 failed** — also run twice, before and after the documentation, with the same counts |
| Trailing whitespace | `git diff --check` | **no output** |
| Requests feature | `flutter test test/features/requests` | **109 passed, 0 failed** |
| Migrated surfaces | `flutter test test/features/home test/app test/l10n` | **93 passed, 0 failed** |
| Visual review harness | `$env:SOLOVVO_VISUAL_REVIEW=1; flutter test test/review/visual_review_test.dart` | **63 passed, 0 failed** — the 63 skips in the row above are this file's opt-in captures, and they were *run*, not merely counted as skips; five new `requests-*` captures are among them, including `requests, read failed, dark bn` |
| Committed renders | `docs/visuals/stage9/01..06` | six PNGs promoted from `build/review/`: `01-requests-light-en`, `02-requests-dark-bn`, `03-requests-truncated-light-en`, `04-requests-empty-light-en`, `05-requests-error-dark-bn`, `06-home-open-requests-light-en` (126–249 KB) |
| Format | `dart format --output=none --set-exit-if-changed` (inspection only, **nothing written**) | the repository is **not** format-clean under Dart 3.13's tall-style formatter — 16 of the 36 files sampled were already-dirty files this stage never touched, so no repo-wide format was run and long lines in the new files were hand-wrapped instead |
| Rules tests | `npm test` in `firestore-rules-tests/` | **Not run.** Needs the Firestore emulator; `firestore.rules` was not touched by this stage, and the suite's `blood_requests` seeds are the *source* of this stage's date-shape assumption, not its verification |
| Screen reader | — | **Not run.** No TalkBack or VoiceOver pass has been made on any stage. `RequestTile` composes from labelled widgets (`BloodGroupBadge`, plain `Text`), which is asserted by widget test — that proves the node carries a string, not that it reads well aloud |
| Live Firebase | — | **Not run.** No emulator session, no device build, no browser pass, no network read, no query cost incurred. The `blood_requests` collection has never been read by this app |

### Remaining issues

1. **Nothing is live-verified.** The single-equality-filter query, the default
   `__name__` order, the read cost of a 26-document window and the actual spelling
   mix in the real collection are all inferred from the rules and the rules-test
   seeds. The first live pass has to confirm that a real `blood_requests` read
   returns rows at all — the failure mode this design avoids (a type-ordered
   collection that looks empty) is exactly the one only a live read can rule out.
2. **`requiredDateTime` stays untyped data.** 9.1 tolerates both shapes; nobody has
   made the collection write one. Until a create path exists (Stage 10), the mapper's
   refusal count is the only defence, and it is client-side.
3. **The window has no refresh timer.** A donor who leaves the screen open sees a
   stale list until they pull. Deliberate — a background poll on the Spark plan's
   daily read quota is a decision for the owner, not an implementation detail.
4. **No distance, no filter, no search.** Stage 9's other half. `latitude` and
   `longitude` are in the document and are not in the read model.
5. **A row cannot be acted on.** Accepting or claiming is Stage 10's transaction,
   behind rules that already describe it (`request_responses`, `response_claims`) and
   a write path this app has not built. The footer line under the list says so in
   both languages rather than leaving the donor to discover it.
6. **`FeedState.isEmptyResult` still lacks the `skipped == 0` term** that
   `RequestsState.isEmptyResult` has — recorded as `docs/ARCHITECTURE.md` §11 item 14,
   not fixed here, because fixing it changes `test/features/feed/feed_pagination_test.dart`
   expectations and the feed's own suite is the thing Stage 8.3 is hardening. The two
   features now disagree about when to say "nothing here", and this file says so.
7. **Not approved.** No approval record exists for Stage 7, 8.2, 8.3 or 9.1.

### Git state

HEAD is **`eb1b5e4`** ("Describe your changes", 2026-11-04 06:22 +0600) and
`origin/main` is **`eb1b5e4`** — level, 0 ahead, 0 behind. That commit is the
**owner's**, and it took Stage 9.1 mid-flight: the thirteen `lib/features/requests`
files as they stood then, `home_providers.dart`'s projection, the `home_dashboard.dart`
view-model deletion, the 14 localisation keys and their generated output, and the
`README.md` / `ARCHITECTURE.md` / `PROJECT_STATE.md` edits of that moment — 24 files,
+1 977/−239.

**It also took the mapper before both bug fixes.** `git show eb1b5e4` still has
`switch (marker)` over `'AM'`/`'PM'` against a regex that captures one letter, and no
calendar check. So the two defects under "Bugs found during verification" above are
**live on `origin/main`**, and the code that fixes them, plus all 109 tests that catch
them (`test/features/requests/` and `test/support/fake_requests.dart` are untracked),
plus `home_screen.dart`, `home_cards.dart`, `blood_request_document.dart`,
`requests_screen.dart`, `visual_review_test.dart` and the three migrated harness files,
are **uncommitted working-tree state** as this entry was written. Nothing about that is
this pass's doing and nothing about it will be this pass's repair: **this pass staged,
committed and pushed nothing, and ran no Git command that writes** (§11 — the owner
commits). Remote state has not been re-verified against the network.

### Next stage

9.1 is one read and it is finished; the honest next steps are, in order:

1. **The owner's security approval and the rules reconciliation** — still the only
   thing that gates *deployment*, for the feed's write path (defect 5) and for
   anything in Stage 10 that writes `blood_requests`.
2. **The first live pass** — a real `blood_requests` read against the project, which
   is the only check that can confirm the shape this whole design inferred from the
   rules and the rules-test seeds. It costs 26 documents and needs the owner to run
   it or to authorise running it.
3. **Stage 9's second half** — donor search, which is where maps and distance become
   real and where the "near you" wording this stage removed can honestly come back.
4. **Stage 10 — the emergency request** — the write path, the `request_responses`
   transaction, and the per-request destination that would let a `RequestTile` grow an
   `onTap` without failing its own test.

**What happened after that list was written.** Item 1 was executed on
4 November 2026 as **Stage 9.2** — the owner's directive of that date authorised the
rules work verbatim ("Audit existing Firestore Rules. Modify firestore.rules. Add
security-rule tests. Run Firestore Emulator tests."), the reconciliation was applied
to `firestore.rules`, and the whole suite is now emulator-verified at 96/96. Items 2,
3 and 4 stand as written. See the Stage 9.2 entry below.

---

## Stage 9.2 — Firestore rules audit, first emulator run, feed reconciliation

**Status: IMPLEMENTED AND EMULATOR-VERIFIED. Not approved, not deployed.** Every
number below was measured in this pass under `firebase-tools emulators:exec` against
the offline emulator, project `demo-solovvo-tests`. Nothing was deployed, and no
request to the live `sholovvo-blood-donation` project was made except two read-only
CLI listings (§10 posture below).

### Why this stage ran now

The Stage 9.1 "Next stage" list opened with "the owner's security approval and the
rules reconciliation — still the only thing that gates deployment". The owner's
master directive of 4 November 2026 granted that approval in one line — *"Audit
existing Firestore Rules. Modify firestore.rules. Add security-rule tests. Run
Firestore Emulator tests."* — with the boundary clauses attached: "Do not weaken
security to make a feature work" and "Do not treat client validation as the only
security boundary". This entry is that reconciliation.

**No line of `lib/` changed, and none needed to.** The point of reconciliation was
to make the rules match the schema the app already writes; the shipped create path
passes the new rules in the emulator unchanged (feed test 1). That is the difference
between a rules stage that follows a decision record and one that invents a new
contract nobody implemented.

### What was found before anything changed

1. **The rules suite had never been executed in this project's recorded history.**
   Every stage entry through 9.1 carries "Rules tests: Not run". The stated blocker
   was the environment; it was checked, not assumed: node v24.22.0, OpenJDK 21.0.12.1
   and `firebase-tools` via `npx` are all present, and the Firestore emulator runs
   offline under `--project demo-solovvo-tests`.
2. **Baseline: 67 tests, 67 pass, 0 fail** (8 suites, 27.1 s) against the untouched
   rules. Everything previously claimed as rule-enforced — donation history, response
   claims, notifications, the four P0 remediations — became *proven* for the first
   time here, rather than assumed from the file.
3. **A write-path inventory of the whole tree**: the app performs exactly one
   Firestore write, `FirestorePostWriter.createPost` →
   `posts.doc(id).set(PostDocument.toCreateMap(post))` — the nine
   `requiredFields` plus optional `authorPhotoUrl`, server timestamps, both counters
   zero, validated before the network. **No client code writes comments, likes or
   reports, and no client code updates a post.** Every rule permission beyond that
   shape is surface for *other* clients, not for this one — which is exactly what
   §14.1 said the rules must be tightened against.
4. **The feed collections had zero rules tests** (`grep` of
   `firestore.test.js`: 38 `blood_requests` references, no `'posts'`), and
   `firestore.rules` disagreed with the shipped Dart schema on five points, all of
   them in §14.1's table.

### Discovery pass, run before any rule was touched

The house workflow the file itself documents: write behaviour-discovery tests
naming what the rules *currently permit*, run them, then harden, then flip the
assertions. `firestore-rules-tests/firestore-feed.test.js` was created (25 tests,
5 suites — posts create, posts update, comments, likes, reports), and four
Stage 9.1 read-path tests were appended to `firestore.test.js`. The baseline run —
new tests, **untouched rules** — was **95 tests, 95 pass, 0 fail** (14 suites,
22.0 s): every P0 finding reproduced.

| Finding (all live pre-stage) | Reproduced by |
| --- | --- |
| post create checks `authorUid` and nothing else — missing keys, 5 000-char text, ten images, paths > urls, pre-filled counters and a client-stamped `createdAt` all accepted | feed tests 4–9 |
| the `donationRecordId` branch admits a key the canonical schema does not carry | feed test 10 |
| **any signed-in stranger can forge `likeCount ±1`** with no paired like write — the integrity hole | feed test 14 |
| author edits are broken by the stale singular `imageUrl` allow-list | feed test 13 |
| comment create has no shape, no size bound, no parent-existence check | feed tests 17–19 |
| `post_likes/{likeId}` is unbound: any id, any or absent `postId`, duplicates undetectable | feed tests 21–22 |
| `reports` has **no rule at all** while `Report` is a shipped entity | feed test 24 |

The four `blood_requests` tests are the first emulator proof that Stage 9.1's
actual query works: a signed-in `where('status','==','open').limit(26)` succeeds
and returns the text-typed `requiredDateTime` document alongside a timestamp-typed
sibling (the mixed-type collection, served without a composite index); an
anonymous caller is refused the same query and the same document get; a stranger
cannot reach another user's `notifications`.

### The reconciliation, applied

`firestore.rules` grew 348 → 459 lines; the posts/comments/post_likes block was
replaced and a `reports` block added. `git diff --stat` counts 150 changed lines in
the file. In full:

| Collection | After |
| --- | --- |
| `posts` create | `hasAll` the nine `PostDocument.requiredFields`, `hasOnly` those plus `authorPhotoUrl`; `authorUid == uid`; text 1–2 000; `imageUrls`/`imagePaths` lists ≤ 4 with **paths ≤ urls**; both counters `== 0`; `createdAt == request.time && updatedAt == request.time`; the `donationRecordId` branch is **gone** |
| `posts` update | author only; affected keys ⊆ `['text','imageUrls','imagePaths','editedAt','updatedAt']`; `authorUid`, `authorName`, both counters and `createdAt` immutable; `updatedAt == request.time` (an edit must restamp); `editedAt == request.time` when set; **the stranger `±1` branch is gone** |
| `posts/{id}/comments/{cid}` create | shape enforced: `hasAll(['authorUid','authorName','text','createdAt'])`, `hasOnly` + the three optional reply fields; text 1–500; `createdAt == request.time`; parent post must exist |
| comments update | `if false` — append-only; edit is delete-and-rewrite, so a thread cannot change under a reply |
| `posts/{id}/likes/{likeId}` | new: `likeId == request.auth.uid` by construction, payload `hasOnly(['likedAt'])`, `likedAt == request.time`; update `if false`; delete by the liker only |
| `post_likes` | `allow read, write: if false` — retired with the move; stranded documents stop being client-reachable (the app never read them) |
| `reports` | new, create-only: `reporterUid == uid`, `hasAll` six / `hasOnly` seven (optional `note`), `target in ['post','comment']`, `reason in` the five `ReportReason` wire names, note ≤ 300, `createdAt == request.time`; **every read denied** — moderation reads from the console, and no user context needs the collection |
| `blood_requests`, everything else | **unchanged.** The claiming, notification and history rules were re-verified, not rewritten |

Three deliberate deviations from §14.1, recorded rather than quiet:

1. **No `±1` branch for either counter** — §14.1 proposed re-opening `likeCount`
   paired with the like write and adding the same shape for `commentCount`. Both
   are closed instead. A rules condition cannot require that a *second write*
   happened in the same batch except by checking the other document's existence —
   and for comments that check is impossible, because comment ids are not
   deterministic (the path carries no id the counter rule could name). A half-
   paired rule is worse than a closed one: it says the pairing is enforced when
   only the step is. When the like/comment write paths land, each counter branch
   comes back in the same change as its `existsAfter`/`getAfter` pairing, with
   its own test.
2. **List element types are not checked** — an emulator defect, in the next
   section; §14.1's own "none of them now" deferral applies.
3. **An edit must restamp `updatedAt`** — stricter than §14.1's allow-list, which
   named `updatedAt` but did not require it. Without the requirement an edited
   post keeps its publish stamp and the feed order silently lies about it.

### An emulator defect, pinned not hidden

The first reconciled run failed three tests with
`Function not found error: Name: [all]`. The element-type comprehensions
(`imageUrls.all(u, u is string)`) were attempted three ways — a parameterised
function, the file's proven parameterless-function idiom, and the parenthesised
lambda form — and failed in all three, inconsistently *within one run*: a
one-element list evaluated cleanly at one call site while the empty list errored
at another. Removing both `.all()` clauses made the whole suite green; the exact
engine trigger is the emulator's, not this project's, and chasing it is not worth
blocking the stage on. The residual gap is written into the rules file as a
comment and here: **a non-string element inside `imageUrls`/`imagePaths` is
admittable by the rules today.** The blast radius is a garbage document, not a
forged one — `PostDocument.fromMap` refuses any non-string element at read time,
so a poisoned list renders as a rejected post, never as someone else's picture.
The checks go back with the first rules-engine that proves them in this suite.

### Verification

| Check | Command | Result |
| --- | --- | --- |
| Rules suite, baseline (untouched rules) | `npx firebase-tools emulators:exec --only firestore --project demo-solovvo-tests "node --test --test-concurrency=1 firestore-rules-tests/firestore.test.js firestore-rules-tests/firestore-feed.test.js"` | **95 tests, 95 pass, 0 fail** — discovery assertions, all findings reproduced |
| Rules suite, first reconciled run | same | 96 tests, **93 pass, 3 fail** — the `[all]` defect, recorded above |
| Rules suite, final | same | **96 tests, 14 suites, 96 pass, 0 fail** (27.8 s), "Script exited successfully (code 0)" |
| Static analysis | `flutter analyze` | **No issues found!** (13.0 s) |
| Whole Dart suite | `flutter test` | **851 passed, 63 skipped, 0 failed** — identical to the Stage 9.1 gate; no Dart file changed in this stage, and the count proves it |
| Trailing whitespace | `git diff --check` | **no output** |

`firestore-rules-tests/package.json` now runs `node --test --test-concurrency=1`
instead of a single hard-coded file. The flag is load-bearing, not cosmetic: two
test files, one emulator, and `clearFirestore` in each file's `afterEach` — run in
parallel (the `node --test` default) one file wipes the other's seeds.

### Deployment posture

* **Feasible, deliberately not executed.** `firebase-tools login:list` reports
  **arifovibd24@gmail.com**, and `apps:list --project sholovvo-blood-donation`
  returns the three real apps (android/ios/web, project number 419478547476) — the
  token is live and the project is reachable from this machine.
* **Why not deployed anyway.** §10's pre-change ritual demands an impact check on
  what already exists, and two questions cannot be answered offline: whether the
  live `posts` collection holds documents that fail the new update rule's shape
  check (a legacy document without `imageUrls` would become uneditable), and
  whether any installed client build performs the now-closed `likeCount ±1` write.
  Nothing is broken by waiting: today's production rules already accept exactly
  what the app writes. This stage changed what *other* clients can do — which is
  the owner's call to ship, on the owner's timing, after reading this file.
* **Recovery artefacts.** `git show HEAD:firestore.rules` is the exact
  pre-reconciliation file (tracked, committed at `eb1b5e4`); the deploy command is
  `firebase deploy --only firestore:rules`, in either direction.

### Indexes

**None needed, none created.** The app's only query is one equality filter with a
limit, which Firestore serves from the automatic single-field index; read-path
test 1 exercised exactly that in the emulator. There is still no
`firestore.indexes.json` and this stage had no reason to add one.

### Files

| File | Change |
| --- | --- |
| `firestore-rules-tests/firestore-feed.test.js` | **created** — 25 tests, 5 suites, the discovery-then-closed record of every feed collection |
| `firestore-rules-tests/firestore.test.js` | five `firebase/firestore` imports added (`collection`, `query`, `where`, `limit`, `getDocs`); one new suite, four Stage 9.1 read-path tests (+76 lines) |
| `firestore-rules-tests/package.json` | test script → `node --test --test-concurrency=1`; description now names the three phases the file covers |
| `firestore.rules` | the reconciliation above; 348 → 459 lines |
| `docs/ARCHITECTURE.md`, `docs/PROJECT_STATE.md`, `README.md` | §14.1 dated as applied; this entry; the README's rules paragraphs |

**Not touched:** `lib/` (nothing), `firebase.json`, `.firebaserc`, the
`blood_requests` rules, `docs/storage/*.sql`, the Supabase project.

### Remaining issues

1. **Not deployed.** Until `firebase deploy --only firestore:rules` runs, the live
   project enforces the *pre-reconciliation* rules; everything in this entry is
   emulator-scoped.
2. **Element types in the image lists are unchecked** (the emulator `[all]`
   defect), with the read-side refusal analysed above.
3. **Neither counter has an update path.** Liking and commenting are therefore
   *client-impossible* as well as unbuilt; the pairing rule comes back with the
   transaction stage that needs it, not before.
4. **The `blood_requests` create rule's `hasOnly` excludes `assignedDonorId`,**
   while the rules-test seed writes `assignedDonorId: null` through the admin
   bypass. Harmless today — no client creates requests — but a Stage 10 client
   create must omit the key entirely, and the seed would hide a rule regression
   that broke it. Recorded, unchanged.
5. **The rules bound raw text length; the Dart validator measures the trimmed
   length.** A post with padding around exactly 2 000 trimmed characters passes
   the client and fails the rules. The rules being stricter is the safe
   direction — refused writes, never forged ones — so it is documented, not
   patched.
6. **The Stage 9.1 read-path proofs are emulator-only.** A live `blood_requests`
   read still has not run.
7. **Not approved.** No approval record exists for Stage 7, 8.2, 8.3, 9.1 or 9.2.

### Git state

The working tree now additionally carries the modified `firestore.rules`,
`firestore.test.js` and `package.json`, and the untracked
`firestore-feed.test.js`, on top of the Stage 9.1 state (`eb1b5e4`, HEAD =
`origin/main`, 0/0). Nothing was staged, committed, pushed or deployed by this
pass; no Git or Firebase command that writes was run.

### Next stage

1. **Owner review, then the deploy decision** for `firestore.rules` — the one
   command above, with the recovery artefact in the same section.
2. **The first live pass** — unchanged from Stage 9.1's list, item 2.
3. **Stage 9's second half** — donor search, unchanged.
4. **Stage 10 — the emergency request** — and with it the paired counter rules,
   the `assignedDonorId` create-shape fix, and the like/comment write paths this
   stage closed the door on deliberately.

---

## Stage 9.3 — Production compatibility audit (live, read-only), deploy-safe refinements, donor-directory rules

**Status: IMPLEMENTED AND EMULATOR-VERIFIED. Not approved, not deployed. Rules
enforcement of writes remains emulator-only; the *data* audit, for the first
time, is live.**

### Why this stage ran now

The owner's directive of 4 November 2026 ("CONTINUE AUTONOMOUS DEVELOPMENT —
POST STAGE 9.2 BACKEND PRIORITY") put a read-only **production compatibility
audit** first (§2), then the remaining security findings (§3), then the next
backend stage (§4), and made deployment conditional on the audit's outcome (§5).
Stage 9.2 had closed with "the §10 impact check cannot be answered offline" —
this stage answers as much of it as the live project allows.

### What the live audit found (the first real production reads in this project's history)

Read-only, through the authenticated CLI user credential over the Admin REST API
(rules bypassed for *reads only*; nothing was written). Full evidence: the
shape tables in `firestore-rules-tests/production-audit/REPORT.md`; the probe is
reproducible (`probe.mjs collections | schema | subcollection | subs`).

Eight top-level collections live: 20 posts, 42 post_likes, 11 blood_requests,
8 request_responses, 8 notifications, 5 donors, 5 legacy `requests`, 3 users.
Three things changed the deployment picture:

1. **19 of 20 production posts carry the legacy shape** — `authorEmail` plus a
   singular `imageUrl`, and none of `imageUrls`/`imagePaths`/`commentCount`/
   `updatedAt`. Reads are unaffected by the reconciliation (unchanged
   `auth != null`), so the feed still loads. But any still-installed pre-Stage-8
   build would have its post *create* rejected, and one post already carries a
   legacy `comments` subcollection whose rows have a `postId` field the new
   comment `hasOnly` does not allow.
2. **`post_likes` is not empty: 42 live documents** `{postId, userId,
   createdAt}`, and the deployed rules let signed-in users read them today.
   Stage 9.2's `allow read, write: if false` would have orphaned real data and
   broken any installed client still counting likes.
3. **`donors` has five live rows and NO rule at all** — deny-all, meaning
   donor discovery could never have read the collection from a client. The
   legacy `requests` collection (5 rows, an older emergency model) is in the
   same deny-all, unowned state; recorded, untouched.

### The rule changes this stage made, and why each is safe

| Change | Rationale | Security posture vs deployed |
| --- | --- | --- |
| `post_likes`: `read: auth != null; write: false` (was `read, write: false` in 9.2's file) | 42 live rows; production already serves reads. Closing the read is a breaking change, not a hardening one. | Writes fully closed (stricter than deployed); reads unchanged; stranded rows survive until a migration copies them to `posts/{id}/likes/{uid}`, then the read flips closed. |
| New `donors` block: signed-in `read`; owner-keyed shape-checked `create` (`latlng` location, enum blood group, server clock); update limited to the six directory fields; `delete: false` | The backend prerequisite for Stage 9's donor search, which was impossible against a deny-all collection. | Read is a deliberate **widening** from deny-all — name and phone become visible to every signed-in user — flagged for owner approval in §Remaining, not assumed. Write is tighter than the equivalent `users` rule (full shape checks). |
| `blood_requests`: **no rule change** — the create shape already matches the production documents exactly | Verified, not modified. | Unchanged. |

### The §3 findings, resolved with the audit's evidence

- **`assignedDonorId` / create-shape hazard (9.2 remaining issue 4) — closed
  with executed client-context tests.** The hazard was that only the
  admin-bypass seed ever touched the create shape, so a regression that let a
  *client* pre-assign a donor would pass silently. Four new tests in
  `Stage 9.3 blood_requests client create shape` prove in a real authenticated
  context: the exact 14-key production shape is accepted; adding
  `assignedDonorId` (null *or* a uid) is refused by `hasOnly`; a request born
  `accepted`/`fulfilled` is refused; wrong-author, unauthenticated and
  device-clocked creates are refused.
- **Raw-vs-trimmed length (9.2 remaining issue 5) — the premise was wrong, and
  the record is corrected.** Tracing every `PostValidator.validate` call site:
  publish trims once (`state.text.trim()` at `compose_providers` L267, already
  pinned by an existing controller test), so the stored value the rules measure
  *is* the trimmed value the validator measures. No divergence exists in the
  shipped path; a first attempt to "fix" this by tightening the validator to the
  raw length was caught by its own new test failing against that pinned
  behaviour and reverted. What landed instead: doc comments on both validators
  stating where the agreement lives, and the padding test extended to assert
  both sides (raw over, trimmed at limit, accepted).
- **Duplicate responses / forged counters / atomic claiming** — verified
  against the deployed model rather than re-earned: `response_claims` is the
  transactional anchor, `posts/{id}/likes/{uid}` makes a duplicate like an
  update (refused), and both counters stay closed until the batched-write stage
  that can pair them. No change; recorded as still true.

### An emulator defect pinned on the way

`is geoPoint` does not compile: the rules type identifier for a geopoint is
`latlng`. The first Stage 9.3 suite run died with a whole-file compile error
(L400/L417, every test cancelled). The failure is worth keeping in the record
because a compile error in `firestore.rules` is silent until *something* loads
the file — the emulator run is that something, and it is one more reason the
suite must gate any deploy.

### Verification

| Gate | Result |
| --- | --- |
| Rules suite after the audit | **106 tests, 106 pass, 0 fail** (96 baseline + 10 new) |
| `latlng` compile defect run (before the fix) | whole file cancelled — the defect above |
| `flutter analyze` | No issues found (61.5 s) |
| `flutter test` | **851 passed, 63 skipped, 0 failed** — unchanged baseline |
| `git diff --check` | clean |

### §6 live verification — what was and was not verified, separately from the emulator

- **Live, executed:** the Admin API reads above (every collection, every shape);
  CLI credential validity (`apps:list`, 3 apps); Supabase reachability —
  `GET /storage/v1/object/list/post-images` on `qiipuczhgacwrysyndij` returned
  **HTTP 400, auth-gated**: the endpoint and the bucket path resolve.
- **Live, blocked by a named limitation:** the deployed ruleset source cannot be
  fetched — the Firebase Rules API is not enabled for this project, and the
  Admin `datasets/(default)/links` call answers with an HTML enable page, not
  JSON. Rule enforcement of *writes* in production, authenticated Supabase
  storage reads/writes, and a Firebase-ID-token Supabase round-trip were not
  performed: they would need test credentials or writes to real collections,
  which the read-only convention and §2 forbid. **The rules remain
  emulator-verified only.**

### §5 deployment — reviewed, authorised, and still deliberately not executed

The owner's authorisation to deploy is conditional on a safe audit outcome, and
the audit produced the opposite: a deploy of the current file would change
behaviour for legacy writers, not just for the reconciled collections. The
precise blockers, each with its safe path:

1. **Legacy post writes.** A normalising migration rewrites the 19 legacy
   documents (`imageUrl` → `imageUrls`/`imagePaths`, drop `authorEmail`, add the
   counter/timestamp fields, admin-side, document by document, after a backup
   export) — or the owner confirms no pre-Stage-8 build is still installing.
2. **`donors` read widening.** An owner privacy decision (name + phone to every
   signed-in user); if declined, keep donors deny-all and donor search moves to
   a server-side function instead.
3. **No deployed-rules diff.** Until the Rules API is enabled (or the owner
   exports the active ruleset from the console), "what changes on deploy" is
   not fully answerable, and §10's second step cannot be completed.

If the owner accepts all three, the deploy command is
`firebase deploy --only firestore:rules --project sholovvo-blood-donation`, and
the recovery artefact is `git show eb1b5e4:firestore.rules` (the
pre-reconciliation file; HEAD `c5faf7f` already carries Stage 9.2).

### Indexes

No composite index is required by anything verified here: the Stage 9.1 window
query (one equality) and the donor directory query (two equalities, no order)
are both served by automatic single-field indexes, and the emulator run confirms
the rule behaviour. This statement is about the queries tested, not a survey of
the console.

### Files changed

| File | What happened |
| --- | --- |
| `firestore.rules` | `post_likes` read/write split; new `donors` block (459 → 525 lines) |
| `firestore-rules-tests/firestore.test.js` | +10 client-context tests; `GeoPoint` import |
| `firestore-rules-tests/firestore-feed.test.js` | test 21 rewritten: legacy row seeded, read succeeds, all three write verbs fail |
| `firestore-rules-tests/production-audit/probe.mjs`, `REPORT.md` | new: the read-only probe and the full audit tables |
| `post.dart`, `comment.dart`, `post_test.dart` | agreement recorded in the validators' comments; the padding test extended (behaviour unchanged) |

### Remaining issues

1. **Nothing is deployed and nothing is approved** — Stages 7, 8.2, 8.3, 9.1,
   9.2, 9.3 all wait on the owner.
2. **Rule enforcement in production is unverified** (emulator only, §6).
3. **`donors` read-widening needs an owner decision** (above).
4. **No donor-search UI exists yet** — Stage 9.3 built the security half only.
5. **`response_claims` and `donation_ratings` have no live collection** — the
   rules are ready for Stage 10; first use is untested against the real backend.
6. **Legacy `requests` and legacy comment `postId` fields stay stranded** by
   decision, not oversight.

### Git state

The owner committed the whole Stage 9.2 tree as `c5faf7f` ("Describe your
changes", 4 November 2026) and it is pushed (`main` = `origin/main`, 0/0). This
stage's work sits on top of it, uncommitted: the six modified files and the
untracked `production-audit/` directory. Nothing was staged, committed, pushed
or deployed.

### Next stage

1. **Owner decisions**: the three deploy blockers above, item by item.
2. **Donor search client** over the now-readable `donors` collection.
3. **Stage 10** — and with it the paired counter rules, the legacy-post
   migration test, and the like/comment write paths.

---

## Stage 9.4 — Donor Search on a privacy-minimized read model, donors read-widening reverted, legacy-post migration prepared

Executed 4 November 2026. This stage **supersedes one line of the Stage 9.3 "Next
stage" plan**: 9.3 proposed building donor search "over the now-readable `donors`
collection." That collection holds each donor's **phone number**, so opening it to every
signed-in user is exactly the privacy widening the owner has *not* approved. Stage 9.4
therefore **reverted the `donors` read-widening to owner-only** and built the search on a
consent-safe read model instead (see below). Nothing was deployed. At the time of writing the
work lived in the uncommitted working tree on top of `c5faf7f`; as of the independent audit
below it has since been committed (HEAD is now `605bf53`, working tree clean). Committing is
not deploying — the `firestore.rules` change is still **undeployed**, gated on the owner.

### The privacy decision that shaped the feature (§4)

Donor Search reads the **public `users/{uid}` profile documents**, filtered to
`role == 'donor'`, and projects **only** the fields that profile already exposes publicly:
`displayName`, `bloodGroup`, `isAvailable`, `area` (only while the donor published it) and
`photoUrl`. **Phone number, street address, date of birth and gender are never read** — they
live in the owner-only private `donors` row / private subcollection, which the discovery path
structurally cannot reach. `lib/features/donors/data/models/donor_profile_document.dart`
maps a fixed allow-list of keys, so even if a `users` document later grew a phone field it
would not land on a `Donor` entity. Discoverability is the donor's own `role`/`isAvailable`
switches; a donor who does not present as a discoverable `donor` simply is not matched.

**No new Firestore rule is required for discovery.** The working-tree `users` read rule is
already `allow read: if request.auth != null` with no per-field condition, so a signed-in
client can already read the public profile. What Stage 9.4 does is keep the *private* `donors`
collection closed and prove both halves in the emulator:

| Rule fact pinned by the suite | Emulator test |
| --- | --- |
| A signed-in user can run the discovery query over public `users` profiles | Stage 9.4 §9.4.1 ✅ |
| A signed-in user can read another donor's public profile | §9.4.2 ✅ |
| An unauthenticated client cannot browse profiles | §9.4.3 ✅ |
| The private subcollection that holds the phone stays owner-only | §9.4.4 ✅ |
| The `donors` directory is **owner-only again** (widening reverted) | Stage 9.3 donors block ✅ |

### What was built (Clean Architecture, mirrors the `requests` feature)

`lib/features/donors/` — domain (`Donor` entity, `DonorQuery` normalisation, `DonorOrdering`
availability-then-name stable sort, `DonorRepository` port, `DiscoveredDonors` window),
data (`donor_documents` port + `DonorIssue` refuse-and-count mapper, Firestore data source
running one equality-only query — no composite index — with over-fetch-by-one to measure
`truncated`, `firestore_donor_repository`), application (`DonorSearchState`, `Notifier`
controller with a one-read-at-a-time flag, providers whose default is the **real**
`FirestoreDonorRepository`), presentation (`DonorSearchScreen` with loading / empty
(filtered vs all) / error+retry / unreadable-partial states, `_FilterBar` for blood group,
availability and area, `DonorCard`, `DonorDetailsScreen`). English **and** Bangla strings
(25 `donor*` keys, ICU `donorSkippedNotice`/`donorTruncatedNotice`, parity-clean,
`untranslated.json` = `{}`). Home's **Find donors** now pushes the screen
(`home_screen.dart`, `_openDonorSearch`) instead of "coming soon".

Bounded window of 30 (over-fetched by one); ordering is client-side after decode because a
DB `orderBy` would need a deployed composite index. Pagination beyond one window is
intentionally deferred to Stage 10.

### Integration blocker (documented, not worked around)

The provider default is the real `FirestoreDonorRepository`, so the feature is **ready for
live Firestore**. It is exercised in tests through an isolated `FakeDonorRepository`
(`test/support/fake_donors.dart`) — **never as production data**. The exact blocker to a live
run is the owner's pending deploy decision on the held working-tree `firestore.rules`
(Stage 9.3 deploy decision + this stage's `donors` revert). Until those rules land, discovery
against real data is unverified; the rules themselves already permit it.

### Legacy-post migration prepared (§5) — NOT executed against production

`firestore-rules-tests/legacy-post-migration/` — `migration.js` (pure `classifyPost` /
`normalizePost` / `planMigration` / `applyMigration`), `migration.test.js` (20 pure tests, no
emulator), `migration_emulator.test.js` (5 emulator round-trip tests under
`withSecurityRulesDisabled`, admin-style), and `MIGRATION_PLAN.md` (before/after schema, exact
field transforms, idempotency, backup/rollback, installed-app compatibility and deploy
ordering, emulator evidence, production-safety guarantees). It normalises the **19 audited
legacy posts** forward to the modern create shape so the rule tightening never forces a
weaker rule or loses data. It only ever points at the emulator (`demo-solovvo-tests`); no
live project, no credential, no delete, and `firestore.rules` is unchanged. **Execution
against production remains gated on the owner.**

### Supabase follow-up (§7) — verification plan only

`docs/storage/SUPABASE-VERIFICATION-PLAN.md` records exactly what is *required* to prove an
authenticated upload works (a dedicated test Firebase identity + a synthetic object +
Firebase third-party-auth confirmed + the SQL applied to a test project), and states plainly
that the previously seen **HTTP 400 on `GET /object/list` proves reachability, NOT
authenticated Storage access**. Nothing was uploaded/listed/deleted; no credential is exposed.
The real authenticated path stays unverified, gated on the owner.

### Verification (all gates re-run after the two test-code fixes this session)

| Gate | Result |
| --- | --- |
| Firestore Rules emulator suite (whole folder, incl. migration round-trip) | **135 passed / 0 failed / 0 skipped**, `emulators:exec` exit 0 |
| Pure migration unit tests (no emulator) | 20 passed |
| `flutter analyze` | **No issues found** |
| `flutter test` (full suite) | **939 passed / 63 skipped / 0 failed** (was 851/63 at 9.3; +88 donor + home) |
| ARB parity + `untranslated.json` | parity test green; `untranslated.json` = `{}` |
| `git diff --check` | clean (exit 0) |
| Donor-search phone/address review | public `users` allow-list only; `donors` collection unreferenced; no phone/address/dob/gender mapped |

Two defects were found and fixed by the honest run (neither was a weakened test): the
emulator migration test first used `testEnv.adminFirestore` (the rules-testing package's own
Firestore class) with the app's modular `collection()/doc()`, which rejects it — switched to
a context `.firestore()` handle; and `withSecurityRulesDisabled` does not forward the
callback's return value, so the cycle result is captured into an outer binding.

### Files (Stage 9.4)

| Path | What happened |
| --- | --- |
| `lib/features/donors/**` (new) | the whole feature, Clean Architecture |
| `test/features/donors/**`, `test/support/fake_donors.dart` (new) | mapper/query/ordering/repository/controller/widget suites |
| `lib/home/.../home_screen.dart`, `test/.../home_screen_test.dart` | Find donors wired to the screen; the old "coming soon" assertion upgraded to a real navigation check |
| `lib/l10n/app_en.arb`, `app_bn.arb`, `generated/**` | 25 donor keys, EN+BN, parity-clean |
| `firestore.rules` | `donors` read-widening **reverted** to owner-only (Stage 9.3 change undone for privacy) |
| `firestore-rules-tests/firestore.test.js` | +4 Stage 9.4 public-profile discovery tests |
| `firestore-rules-tests/legacy-post-migration/**` (new) | migration logic + pure/emulator tests + plan doc |
| `docs/storage/SUPABASE-VERIFICATION-PLAN.md` (new) | §7 authenticated-upload verification plan |

### Remaining issues / owner decisions

1. **Nothing is deployed.** Stages 7, 8.2, 8.3, 9.1, 9.2, 9.3, 9.4 all wait on the owner.
2. **Real donor-search integration is unverified** until the working-tree rules deploy; the
   emulator proves the rules permit the privacy-safe read, and the fake proves the client.
3. **`donors` phone-visibility stays a deliberate owner decision** — Stage 9.4 chose the
   conservative public-profile read and left the `donors` collection owner-only.
4. **Legacy-post migration is prepared, not run** (§5 / `MIGRATION_PLAN.md`), and the
   installed-base impact check is still the owner's.
5. **Supabase authenticated storage access remains unverified** (plan only; no prod writes).
6. **Donor-search pagination** past a single 30-window is deferred to Stage 10.

### Git state

At completion HEAD was `c5faf7f` and the whole of Stage 9.3 + 9.4 sat uncommitted in the
working tree. Since then the work was committed (a normal project commit, not by this audit):
**as of the independent audit below, HEAD is `605bf53` and `git status` reports a clean tree.**
Committing is not a deploy — no rule was deployed, no branch was switched by the audit, no
production write / migration / billing change / privacy-widening was performed. The
`firestore.rules` change and the legacy-post migration remain gated on the owner.

### Independent security & architecture audit (Stage 9.4-ISA) — 4 November 2026

A fresh, evidence-based re-audit performed **without** relying on the completion report above.
Every claim below was re-read from source or re-run in this session. No production write, no
rule deploy, no migration, no billing change and no Git write were performed; the only files
touched by the audit are this `docs/PROJECT_STATE.md` (appending this section and correcting
two stale Git-state sentences — see "Git state" above).

**Gates re-run (all green):**

| Gate | Result |
| --- | --- |
| Firestore Rules emulator suite (`firebase emulators:exec --only firestore --project demo-solovvo-tests`, incl. migration round-trip) | **135 passed / 0 failed / 0 skipped**, exit 0 |
| `flutter analyze` | **No issues found** |
| `flutter test` (full suite) | **939 passed / 63 skipped / 0 failed**; the 63 skips are the `visual_review_test.dart` capture suite gated behind an env flag, not donor logic |
| ARB / localisation parity | covered by `test/l10n/arb_parity_test.dart` inside the green run |
| `git diff --check` | clean (exit 0) |

Note the toolchain path had to be worked around: the `System32` `firebase.cmd` shim is broken
in this environment; the suite was driven through `node …\firebase-tools\lib\bin\firebase.js`
(15.34.2). This is a local tooling detail, not a project defect.

**Privacy model — verified correct (No finding):**
- Consent (`publishAreaInSearch`) is enforced on the *write* side: `ProfileDocuments.publicFields`
  projects `area` to the public doc only while the flag is on, else `FieldValue.delete()` (the
  value becomes unreadable, not merely hidden). The canonical `area` and all of phone / address /
  dob / gender are written only to `users/{uid}/private/profile` (owner-only, pinned by emulator
  test §9.4.4).
- The discovery read path (`FirestoreDonorDocuments` → `DonorProfileDocument.fromUserDoc` →
  `FirestoreDonorRepository` → `DonorSearchController` → `DonorCard`/`DonorDetailsScreen`) reads,
  maps and renders **only** `role, bloodGroup, displayName, isAvailable, area, photoUrl`. A
  `Donor` carries no phone/address/dob/gender field, so no query, mapper, log line or UI can
  surface one.
- Logs are value-free: `_describe()` returns `runtimeType` only; `DiscoveredDonors`/`Donor`
  `toString()` carry counts / uid / group / availability, never a name or area; the repository
  logs only the skip `Failure`.
- Availability visibility is the donor's own switch; discovery never flips it.
- Real vs fake contract parity holds: the provider default is the **real** `FirestoreDonorRepository`
  (`donor_search_providers.dart`), fakes live only under `test/`, and both fake classes document
  exactly which responsibilities they stand in for (filtering is emulator-covered; window logic is
  fake-covered). No fake is presented as production.

**Findings by severity:**

- **Critical — none.**
- **High — none** introduced or left by Stage 9.4. The `donors` read-widening was correctly
  reverted to owner-only; request/response/claim/notification/post/donation_history rules show
  no privilege-escalation or unintended-field path (ownership fixed at create, response claims are
  immutable transaction anchors, counters/identity are pinned on update).
- **Medium:**
  - **M1 — No global discoverability opt-out / consent-withdrawal affordance.** Discoverability is
    exactly `role == 'donor'` on the public doc, and `publicFields` always writes `role: 'donor'`.
    There is no in-app way for a donor to stop being listed while keeping the account, and no
    profile/account deletion in this stage; `isAvailable=false` only hides them under the default
    "available only" filter, not under "show all". §4's "opt-out and withdrawal" is therefore met
    at the *area* level only. Owner/product decision; not safely auto-fixable inside audit scope.
  - **M2 — Public `users/{uid}` write has no field allow-list in `firestore.rules`**
    (`allow write: if auth.uid == userId`). The privacy split is enforced by the client writer +
    the read-model mapper, **not** by rules: a client (bug or a donor self-sabotaging their own
    doc) could place `phone` into the globally-readable public document and rules would accept it,
    where any signed-in user could then read it at the DB layer. Not directly exploitable against
    *another* user (write is owner-only) and the `Donor` mapper would still refuse to surface it,
    so this is a defense-in-depth hardening, not an active leak. A rules change → deploy-gated, so
    this is report-only; recommend a field allow-list (or forbid phone/address/dob/gender keys on
    the public doc) plus an emulator test if the owner accepts it.
  - **M3 — (Pre-existing, outside 9.4 scope) `blood_requests` reads expose patient contact data.**
    `allow read: if request.auth != null` makes `phoneNumber`/`hospitalAddress`/`patientName`
    readable by every signed-in user before any match. This is the legacy open-request-board
    design, was **not** introduced by Stage 9.4, and is only in scope for the Stage 10 contact flow.
    Recorded as an observation for that decision, not a 9.4 defect.
- **Low:**
  - **L1 — Stale Git-state documentation** (fixed this session): the 9.4 report claimed all work was
    uncommitted at HEAD `c5faf7f`; it is in fact committed at HEAD `605bf53` with a clean tree.
    Corrected in the intro and the "Git state" section above. Documentation-only; no behaviour change.
- **No finding** for: consent enforcement, availability visibility, unauthorised private-field
  access, phone/address exposure through query/mapper/logs/UI, repository contract parity,
  no-fake-as-production, privilege escalation, request/response atomicity, feed/legacy
  compatibility, and all five verification gates.

**Migration safety — verified (No finding):** `migration.js` talks to no database by itself;
the only caller passes the emulator (`demo-solovvo-tests`), with no project id / credential /
default connection to `sholovvo-blood-donation`. It never deletes, takes a verbatim pre-write
backup, is idempotent (second pass plans zero writes — emulator-pinned), leaves modern docs
byte-for-byte and refuses unreadable docs (preservation tests green). `MIGRATION_PLAN.md` backup
/rollback/deploy-ordering text matches the code. Accidental prod selection is guarded by the
explicit `--project demo-solovvo-tests` in the documented command; note the repo-wide
`.firebaserc` default is still the live project, so **any bare `firebase deploy`/CLI run without
`--project` would target production** — the owner must keep passing `--project` until they choose
otherwise.

**Missing integration tests / production blockers:**
1. No live donor-search test against real Firestore — blocked on the owner deploying the held
   `firestore.rules`; the emulator proves the rules permit the privacy-safe read, the fakes prove
   the client. This is the single gating blocker to calling discovery "live".
2. If M2 is accepted, add an emulator test asserting a stranger cannot read a phone that was
   self-written into the public doc (this is currently unenforceable — the exact gap M2 describes).
3. No end-to-end test that flipping `publishAreaInSearch` off removes the public `area` at the DB
   level (unit + widget cover the client write; rules cannot, since it is a client projection).
4. Pagination beyond one 30-window is deferred to Stage 10 (documented).

**Stage 10 readiness recommendation:** Stage 10 (donor "respond"/contact flow, paired counter
rules, pagination, `post_likes`→subcollection migration) **may begin**, with three conditions:
(i) M1 (discoverability opt-out/withdrawal) and M2 (public-doc field allow-list) are decided by
the owner — M1 especially, because Stage 10 adds the contact path that makes being discoverable
consequential; (ii) the reconciled `firestore.rules` (with the `donors` revert) is deployed and a
live donor-search verification test is added before donor discovery is described as production;
and (iii) the Stage 10 contact flow must not reintroduce phone/address into any globally-readable
document. No confirmed Stage 9.4 defect blocks starting Stage 10 development work; the blockers
above are owner decisions and live-verification steps, not code faults.

### Next stage

1. **Owner decisions**: deploy the reconciled `firestore.rules` (with the `donors` revert),
   then run the prepared legacy-post migration against production, then confirm the
   installed base — or force-upgrade.
2. **Live donor-search integration test** against real Firestore once the rules land.
3. **Stage 10** — donor-search pagination, a donor "respond" flow (which is where a contact
   path legitimately belongs, behind a request), the paired counter rules, and the
   `post_likes` → `posts/{id}/likes/{uid}` like migration.

## Stage 9.5 — Privacy hardening: donor-discovery consent, public-profile field allow-list, request-contact PII split

Stage 9.4-ISA identified three privacy defects that Stage 9.4 itself did not close: (M1) donor
discovery had no per-donor consent, so a signed-in account could list every user with
`role == 'donor'`; (M2) the `users/{uid}` public projection accepted *any* owner write, so a
buggy or hostile client could put phone, address or date-of-birth onto a document every signed-in
account reads; (M3) the request document stored `patientName` and `phoneNumber` on a document
with `allow read: if request.auth != null`, which made a directory of every blood recipient's
contact details available to every signed-in account. Stage 9.5 closes all three at the rules
layer. **Production data is not migrated and rules are not deployed as part of Stage 9.5** — the
owner has not authorised either. What is delivered here is the reconciled rule set, the consent
surface, the read-model plumbing and the emulator evidence, so the owner can decide when to
deploy and when (and whether) to run the historical-PII cleanup.

### 9.5.1 — M1: donor discovery requires an explicit opt-in

`UserProfile.allowDonorDiscovery` is a new boolean (default `false`, opt-in) that lands beside
`publishAreaInSearch` on the private `users/{uid}/private/profile` subcollection and mirrors onto
the public `users/{uid}` projection only while true. `FirestoreDonorDocuments.fetch` adds
`where('allowDonorDiscovery', '==', true)` to the query — legacy documents that do not carry the
key at all also drop out, so a donor who has never seen Stage 9.5 is not silently listed.
`DonorProfileDocument.fromMap` re-checks the flag at the mapper boundary (defence-in-depth: a
test seam that hands the mapper a raw map cannot bypass the consent gate). The privacy card
renders three independent switches (availability, publish area, allow discovery), each addressed
by a `ValueKey` so a widget test can target it without ambiguity. Withdrawal writes
`FieldValue.delete()` on the public mirror so a stale `true` does not sit on the projection after
the opt-out.

| Evidence | Location | Result |
|---|---|---|
| Consent field carried through the value object | `test/features/profile/user_profile_test.dart` (copyWith, withPhoto, draft) | ✅ |
| Consent re-check refuses opted-out, missing-key, null and truthy-non-bool values | `test/features/donors/donor_profile_document_test.dart` (7-case Stage 9.5 group) | ✅ |
| Repository skips opted-out and legacy documents without disturbing the truncation over-count | `test/features/donors/firestore_donor_repository_test.dart` (3 new cases) | ✅ |
| Consent switch has its own key on both the view and edit screens | `test/features/profile/profile_screen_test.dart`, `test/features/profile/profile_edit_screen_test.dart` | ✅ |
| English and Bengali labels present, placeholders preserved, no ASCII digits in Bengali | `test/l10n/arb_parity_test.dart` (auto-extended by the new strings) | ✅ |
| Rules query filters on the consent flag | `firestore-rules-tests/firestore.test.js` — *Stage 9.5 donor discovery requires an explicit opt-in* (5 tests) | ✅ |

### 9.5.2 — M2: public profile Firestore field allow-list

The `users/{userId}` rule no longer says `allow write: if request.auth != null &&
request.auth.uid == userId`. It splits into `create`, `update` and `delete`, and both write
verbs are gated against a fixed eight-key allow-list: `displayName`, `role`, `isAvailable`,
`updatedAt`, `bloodGroup`, `photoUrl`, `area`, `allowDonorDiscovery`. `create` uses
`request.resource.data.keys().hasOnly([...])` on the whole new shape; `update` uses
`request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])` on what the write
changes, which is what lets a legacy `users/{uid}` document (still carrying pre-Stage-9.5 keys
like `fullName`, `uid`) be updated normally through the profile-save path — an untouched legacy
key is not part of `affectedKeys()`, only writing a new sensitive key is refused. The private
subcollection is unchanged and stays the sink for every field the allow-list refuses.

| Evidence | Location | Result |
|---|---|---|
| Eight-key allow-list matches what `ProfileDocuments.publicFields` writes | `firestore.test.js` M2 test 12 (sanity assertion) | ✅ |
| Owner cannot create or inject phone, addressLine, dateOfBirth, gender, publishAreaInSearch | `firestore.test.js` M2 tests 2–4 | ✅ |
| Owner can still legitimately update displayName / isAvailable / photoUrl / allowDonorDiscovery | `firestore.test.js` M2 tests 5–6 | ✅ |
| Stranger cannot write anything, unauthenticated cannot write anything | `firestore.test.js` M2 tests 7, 9 | ✅ |
| Owner can still delete their public document | `firestore.test.js` M2 test 8 | ✅ |
| A legacy doc with pre-M2 keys still accepts legal updates on allow-listed keys but refuses phone | `firestore.test.js` M2 test 10 | ✅ |
| Private subcollection holds every sensitive key the public allow-list refuses | `firestore.test.js` M2 test 11 | ✅ |

### 9.5.3 — M3: request contact PII moves to `blood_requests/{requestId}/private/contact`

Corrected in **M3-C1** (hospitalAddress) and **M3-C2** (authoritative donor
authorization). Three patient-identifying fields — `patientName`, `phoneNumber`
**and** `hospitalAddress` — are gone from the public `blood_requests/{requestId}`
create shape (both `hasAll` and `hasOnly`), gone from the "patient edits details"
update branch's affected-keys set, and now live on a one-document subcollection
pinned to id `contact`. The subcollection's write shape is exactly
`['patientName', 'phoneNumber', 'hospitalAddress']` (`patientName`/`phoneNumber`
non-empty strings; `hospitalAddress` a string, permitted empty), owner-only via
`get(parent).userId == request.auth.uid`. The public projection keeps only
`hospitalName` (plus the optional coarse `latitude`/`longitude` pin);
`BloodRequest.area` resolves to `hospitalName` and the request row no longer
renders a street address, so **no private address is exposed through the public
document or the UI**.

**Reads are owner-only in this stage (M3-C2).** The intended "matched donor may
read" branch was NOT landed, because the existing architecture cannot prove a
legitimate match inside a rule without a shortcut, and the reviewer directed that
no shortcut be invented. What was verified:

- **How a donor legitimately becomes matched:** the booking transaction writes
  three documents atomically — `request_responses/{uuid}` (donor/request/status),
  the immutable `response_claims/{claimId}` (create-only, `update`/`delete` are
  `if false`, and creation requires `existsAfter` a matching `request_responses`
  row), and the `blood_requests` assignment update. The `response_claims` row is
  the tamper-evident anchor.
- **Forgeability confirmed:** a matching, available donor can set
  `assignedDonorId = self` and `status = accepted` with a **single public
  `blood_requests` update, without any claim** (the existing claim branch does not
  require a `response_claims` row). So the earlier three-signal gate
  (`assignedDonorId` + status + role) is forgeable and is explicitly not trusted.
- **The authoritative anchor is unreachable from a rule:** the `response_claims`
  id is length-prefixed (`req_{requestId.length}_{requestId}_donor_{donorId.length}_{donorId}`)
  and **Firestore security rules cannot cast an int to a string** — the `+`
  operator rejects `string + int` (empirically confirmed: the emulator raised
  "Received: string + int" when a rule tried to rebuild the id), and there is no
  `string()` builtin. `request_responses` ids are opaque uuids and rules cannot
  query. So neither authoritative record is addressable from
  `(requestId, request.auth.uid)`.

Minimum safe interim: **owner-only contact read**, which is strictly safe and
unregressing (the app reads no contact today). The full response/claim invariants
are left untouched. Unlocking a donor read is a Stage-10 architecture decision —
either (a) a rule-derivable anchor whose id uses only strings
(`blood_requests/{requestId}/private/match/{donorId}` written in the same
transaction), or (b) a length-free `RequestResponseService.getClaimId` (a
production data-shape change, out of scope). The `contactDoc == 'contact'` guard on
every clause keeps the shape one-per-request and closes the alternate-id burial hole.

`BloodRequest` no longer carries `hospitalAddress`; its `area` getter returns
`hospitalName`, and `BloodRequestDocument` no longer reads `hospitalAddress`.
`RequestTile` drops the address line and renders `request.area` only.

**What Stage 9.5 does NOT do.** Nothing in this stage writes `blood_requests` from Dart — the
requests screen is still read-only, and M3 does not add a write path. Existing production
`blood_requests` documents still carry `patientName`/`phoneNumber`/`hospitalAddress` on the public
document; the new rules only stop future writes. **M3-C3 prepares (does NOT execute) the
historical-PII migration** — see `firestore-rules-tests/request-pii-migration/`
(`MIGRATION_PLAN.md`, the pure `migration.js` copy-then-delete contract with backup, idempotency,
read-before-delete verification, rollback and dry-run/reporting, plus 19 pure tests and 7 emulator
round-trip tests). The owner has not authorised a production run.

| Evidence | Location | Result |
|---|---|---|
| Public create refuses `patientName`, `phoneNumber`, `hospitalAddress` injection | `firestore.test.js` M3 tests 1–2, 2b | ✅ |
| Public create still accepts the eleven-key shape without PII | `firestore.test.js` M3 test 3 | ✅ |
| Owner can create/update/delete the `private/contact` doc | `firestore.test.js` M3 tests 4, 19 | ✅ |
| Contact shape is exactly `{patientName, phoneNumber, hospitalAddress}`; extra/missing keys and blank name/phone refused; blank address allowed | `firestore.test.js` M3 tests 5–7 | ✅ |
| Stranger cannot create contact; unauth cannot read | `firestore.test.js` M3 tests 8, 15 | ✅ |
| Owner reads own contact | `firestore.test.js` M3 test 9 | ✅ |
| **Owner-only interim: every donor read refused** — accepted, donation_completed, fulfilled, open — with a real claim present | `firestore.test.js` M3 tests 10–13 | ✅ |
| Stranger / role-changed / deleted-user caller cannot read | `firestore.test.js` M3 tests 14, 16, 17 | ✅ |
| `private/{id != contact}` is unreachable — the fixed-name guard | `firestore.test.js` M3 test 18 | ✅ |
| Patient-edits-details branch no longer permits changing PII on a legacy doc | `firestore.test.js` M3 test 21 | ✅ |
| Shape sanity: exactly the three keys | `firestore.test.js` M3 test 22 | ✅ |
| **Forged self-assignment (no claim) does NOT open the contact** | `firestore.test.js` M3 test 23 | ✅ |
| **Unrelated donor cannot read even attempting to forge** | `firestore.test.js` M3 test 24 | ✅ |
| **Even the full legitimate booking transaction does NOT open a donor read yet (reported blocker)** | `firestore.test.js` M3 test 25 | ✅ |
| Migration: pure contract (classify/extract/plan/verify/apply ordering/rollback) | `request-pii-migration/migration.test.js` (19 tests) | ✅ |
| Migration: emulator round-trip closes the read leak, idempotent, partial-doc, rollback | `request-pii-migration/migration_emulator.test.js` (7 tests) | ✅ |

### 9.5.4 — Verification evidence (all three milestones)

| Gate | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | ✅ No issues found |
| Widget/unit suite | `flutter test` | ✅ 962 pass, 63 skipped, 0 fail (M3-C1 removed `hospitalAddress` from the read model, fixtures and tile) |
| ARB parity | `flutter test test/l10n/arb_parity_test.dart` | ✅ 8 pass |
| Rules + migration emulator suite | `firebase emulators:exec --only firestore --project demo-solovvo-tests "npm test"` | ✅ **204 pass, 0 fail** (M1+M2+M3-C1+M3-C2 rules, plus the 7 M3-C3 migration emulator tests) |
| Migration pure suite | part of `npm test` (`node --test`) | ✅ 19 pass, 0 fail |
| Whitespace check | `git diff --check` | ✅ clean |

All emulator commands ran against the `demo-solovvo-tests` project. No production project was
touched, no rules deployed, no data migrated, no billing or Git-write operation performed.

### Files (Stage 9.5)

| File | Change |
|---|---|
| `lib/features/profile/domain/user_profile.dart` | `allowDonorDiscovery` field on the value object, default `false`, `copyWith`/`withPhoto`/equality carried through |
| `lib/features/profile/data/profile_documents.dart` | Private-subcollection read of `allowDonorDiscovery`; public write mirrors the flag while consent is on and writes `FieldValue.delete()` on withdrawal |
| `lib/features/donors/data/firestore_donor_documents.dart` | Query filter `where('allowDonorDiscovery', '==', true)` |
| `lib/features/donors/data/models/donor_profile_document.dart` | Consent re-check at the mapper boundary (refuses missing-key, `null`, and truthy-non-bool values) |
| `lib/features/profile/presentation/widgets/profile_privacy_card.dart` | New "Discoverable" switch with its own `ValueKey`, alongside the existing availability and publish-area switches |
| `lib/features/profile/presentation/profile_screen.dart`, `profile_edit_screen.dart` | Read/save wiring for `allowDonorDiscovery` |
| `lib/l10n/app_en.arb`, `lib/l10n/app_bn.arb` | Consent strings in both locales (parity test passes) |
| `lib/features/requests/domain/entities/blood_request.dart` | M3-C1: drops the `hospitalAddress` field; `area` getter returns `hospitalName`; doc comment rewritten for the post-M3 rules |
| `lib/features/requests/data/models/blood_request_document.dart` | M3-C1: mapper no longer reads `hospitalAddress`; doc comment rewritten for the eleven-key create shape |
| `lib/features/requests/presentation/widgets/request_tile.dart` | M3-C1: removes the address line; renders `request.area` (hospital name) only |
| `firestore.rules` | M2 (`users/{userId}` field allow-list) and M3-C1/M3-C2 (`blood_requests/{id}/private/contact` split to three keys, updated create/update shape, owner-only read with the M3-C2 blocker documented) |
| `firestore-rules-tests/firestore.test.js` | Three new describes: 5 M1 tests, 12 M2 tests, 25 M3 tests (incl. forgery/owner-only controls). `p0OpenRequestData`/`p0RequestDoc`/`productionRequestData` fixtures trimmed to the eleven-key public shape |
| `firestore-rules-tests/request-pii-migration/MIGRATION_PLAN.md` | M3-C3: prepared (not executed) historical-PII migration plan — fields, backup, idempotency, read-before-delete verification, rollback, dry-run/reporting |
| `firestore-rules-tests/request-pii-migration/migration.js` | M3-C3: pure two-document copy-then-delete migration (plan/apply/verify/rollback) |
| `firestore-rules-tests/request-pii-migration/migration.test.js` | M3-C3: 19 pure contract tests (classification, extract/normalize, plan split, write-ordering, rollback) |
| `firestore-rules-tests/request-pii-migration/migration_emulator.test.js` | M3-C3: 7 emulator round-trip tests (leak closed to a stranger, idempotent, partial doc, rollback) |
| `test/features/profile/user_profile_test.dart`, `profile_documents_test.dart`, `profile_screen_test.dart`, `profile_edit_screen_test.dart` | M1 consent coverage; `ValueKey` disambiguation for the three privacy switches |
| `test/features/donors/donor_profile_document_test.dart`, `firestore_donor_repository_test.dart` | M1 mapper refusal coverage |
| `test/support/fake_donors.dart` | Consent-aware fake writer for tests that opt donors in |

### Stage 10 readiness recommendation (post-9.5)

Stage 9.5 completion is **NOT approved**; Stage 10 is **not started**. The M3-C1
(hospitalAddress) and M3-C3 (migration plan) corrections are landed and green. One
M3-C2 item remains an explicit, reported **blocker** rather than a code gap. Decisions
that stand outside this stage:

1. Deploy the reconciled `firestore.rules` (M2 allow-list on `users/{uid}`, M3-C1/M3-C2
   `blood_requests/{id}/private/contact` split and owner-only read). Nothing is enforced
   on production until the rules land.
2. **M3-C2 blocker — matched-donor contact read.** The contact is owner-only because the
   authoritative `response_claims` anchor cannot be addressed from a rule (length-prefixed
   id; rules cannot stringify an int, cannot query; `assignedDonorId`/`status` are
   forgeable and not trusted). No shortcut was invented. To enable a donor read, the owner
   must pick a minimum safe design: (a) add a rule-derivable, string-only-id anchor such as
   `blood_requests/{requestId}/private/match/{donorId}` written inside the existing booking
   transaction, or (b) change `RequestResponseService.getClaimId` to a length-free composite
   id (a production data-shape change). Until one lands, `firestore.test.js` M3 test 25 stays
   a failing-if-relaxed owner-only guard and MUST flip to `assertSucceeds` only together with
   the chosen anchor plus new emulator tests proving a still-forged read fails.
3. Execute the **prepared** historical-PII migration (M3-C3) only after the owner authorises
   it: run `request-pii-migration/migration.js` first against the emulator (the round-trip
   tests already do), then a dry-run report against production, then the copy-then-delete
   with read-before-delete verification. Rules have no field-level read filter, so historical
   `patientName`/`phoneNumber`/`hospitalAddress` on public docs remain exposed to a raw-SDK
   reader until this migration physically removes them.

Stage 10's donor "respond"/contact flow is the natural place to build the write path for
`blood_requests/{requestId}/private/contact` and to land whichever M3-C2 anchor the owner
chooses, then to complete the historical-PII cleanup the owner authorises alongside it.

### Next stage (Stage 10)

1. **Owner decisions**: resolve the M3-C2 matching-anchor design; deploy the reconciled
   `firestore.rules` (M2 + M3-C1/M3-C2); run the prepared M3-C3 migration against the
   emulator and a production dry-run first, then against production only on approval.
2. **Stage 10 development** — donor "respond"/contact flow, which is where the
   `private/contact` write path is legitimately raised by the app for the first time; paired
   counter rules; `post_likes` → `posts/{id}/likes/{uid}` like migration; donor-search
   pagination beyond the single 30-window.
