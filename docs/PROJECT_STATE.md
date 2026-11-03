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
| 8 | Social feed | **In progress — 8.1 and 8.1.1 complete (awaiting approval), 8.2 complete (awaiting approval), 8.3 IMPLEMENTED — HARDENING IN PROGRESS** |
| 9 | Normal blood search & maps | Not started |
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
   the dashboard's feed provider still returns `const []`, so no rendered screen
   in this tree changes.

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
3. **`feedPreviewProvider` is still empty**, so the dashboard's "See all" is
   wired but not reachable in the shipped app (see the decision above).
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

Two things have happened since that entry was written: the owner committed the
reconciliation documentation (`bbf1543`) and the **Step 2 test fix** (`68f9ee8`),
which resolved the one failing test below. That makes the suite green; it does not
make the stage complete. Defects 2–9 and tasks 3–7 are all still open, and the
gate at the top of this file is met *today*, not *once and for all* — every later
hardening step has to re-run it.

### What "implemented" means here, and what it does not

Five different states get conflated easily, and this stage is in only the first
and second of them:

| State | Stage 8.3 | Evidence |
| --- | --- | --- |
| **Implemented** | Yes | Every file below exists in the committed tree and is wired: `FeedScreen`'s `FloatingActionButton.extended` pushes `ComposePostScreen.route()`, and a publish calls `FeedController.prepend` |
| **Unit-tested** | Partly | 62 composer tests exist and **all pass** (whole suite: 612 passed, 47 skipped, 0 failed). The controller, the repository and the storage adapter are covered; the screens are not covered at all |
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
100-file diff. There is still no `firestore.indexes.json`.

**Changed later, test-side only:** Step 2 (`68f9ee8`) modified
`test/features/feed/compose_controller_test.dart`, `test/support/fake_compose.dart`
and `test/support/fake_photo_services.dart`. **Nothing under `lib/` has changed
since `d27aee3`** — verified with `git diff d27aee3 HEAD -- lib`, which is empty.

### Known defects — one closed, the rest recorded without being fixed

Only defect 1 has been closed, and it was closed by the Step 2 test fix. Nothing
else on this list was touched, and each item below says which side of the
line (code, tests, backend, deployment) it is still open on.

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
   defect.** No Dart source changed — `git diff d27aee3 HEAD -- lib` is empty, and
   `ComposeController` is exactly what Stage 8.3 committed.
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
   three files. The 47 skips are unchanged (the opt-in visual-review harness).
2. **`ComposePostScreen` has no widget tests and no visual review.** No file under
   `test/` imports `ComposePostScreen` or quotes a `feedCompose*` key — verified by
   search, and still true after Step 2. So unverified by any test: the
   `PopScope`/discard flow, the
   publish-disabled-while-uploading rule, the unconfigured-bucket fallback message,
   the text counter, and all of `compose_image_grid`. `test/review/visual_review_test.dart`
   has a `feed` group and **no compose group**, and `docs/visuals/stage8/` holds
   only the five read-path renders. The 62 tests cover the logic around the screen,
   not the screen, and the presentation layer of this stage is the largest
   unverified surface in it (282 + 389 lines).
3. **The malformed-document pagination dead-end** (found in 8.2, still present).
   `FirestoreFeedRepository` computes `hasMore` from the raw document count
   (`firestore_feed_repository.dart:39`) while dropping refused documents, so a
   page can return zero posts with `hasMore: true`. `FeedState.isEmptyResult` is
   then true, and the screen's empty branch (`feed_screen.dart:186-197`) returns
   **before** the footer that holds **Load more**. A run of eleven malformed
   newest documents renders a permanently empty feed, and pull-to-refresh re-reads
   the same window. `loadMore()` itself would work; there is no control to press.
   No test in `firestore_feed_repository_test.dart` or `feed_screen_test.dart`
   covers "zero kept with `hasMore: true`".
4. **The feed and the composer are unreachable in the shipped app.**
   `feedPreviewProvider` still returns `const []` (`home_providers.dart:49-50`), and
   the dashboard hides its community **See all** over an empty list
   (`home_screen.dart:249-251`). `FeedScreen` is the only route to
   `ComposePostScreen`, and the dashboard is the only route to `FeedScreen`. The
   whole Stage 8 surface — read path, composer, image upload — therefore exists in
   code and cannot be opened by a donor. This is disclosed here because it changes
   the risk assessment of every other item: it is not a live exposure today, and it
   is a blocker on shipping it. It also means `docs/storage/README.md` step 5.6,
   which tells the owner to verify post photos by opening the feed, cannot be
   followed as written.
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

### Outstanding tasks — hardening, in order

Task 1 was completed by the Step 2 test fix. **None of the rest has been started.**

1. ~~Disposition defect 1: the failing test — test-side or controller-side, an owner
   decision.~~ **Done in Step 2 (2026-11-03, `68f9ee8`)**: it was a test
   synchronisation defect, fixed test-side; no controller behaviour or public
   interface changed, and the pick/upload distinction now has its own regression
   test.
2. **A standing gate, not a one-off task.** `flutter test` green and `flutter analyze`
   clean on the committed tree, re-measured at the end of every hardening step. Met
   today (612 / 47 / 0 and no analyzer issues), which satisfies the gate at the top
   of this file for the current tree and nothing more: meeting it does not approve
   the stage, and tasks 3–7 below are what still stand between 8.3 and "complete".
3. Widget tests for `ComposePostScreen` and `compose_image_grid`, and a `compose`
   capture group in the visual-review harness with renders in `docs/visuals/stage8/`.
4. Fix the pagination dead-end (defect 3) and pin it with tests.
5. Decide the reachability question (defect 4): populate `feedPreviewProvider`, or
   add an explicit feed entry point, before any release.
6. The rules stage reconciling `firestore.rules` with §14.1, **plus** the first
   feed-collection rules tests. This now gates any live deployment, because the
   write path exists in code.
7. An owner-approved live session: apply `supabase-avatars.sql` and
   `supabase-post-images.sql`, confirm the Firebase third-party-auth setting, then
   one real publish with two photographs.

### Verification

Measured twice, in full, on the committed tree — nothing below is inferred from a
partial run.

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

### Git state

`main`, no stash, no tags, one remote (`origin`). When this entry was written HEAD
was `d27aee3`; the owner has since committed the reconciliation documentation as
`bbf1543` and the Step 2 test fix as `68f9ee8`, so **HEAD is now `68f9ee8` with a
clean working tree**. `refs/remotes/origin/main` equalled `HEAD` locally at the
reconciliation; that has not been re-verified against the network since.
Stage boundaries are still not separable in Git: `d27aee3` squashes Stages 7 → 8.3
into one commit, so **8.3 cannot be separated from 8.2 by Git alone**, which
matters if Stage 8.2's approval is later withheld. The only post-`d27aee3` changes
to the feed are test-side.

### Next stage

Stage 8.3 must be hardened and approved before Stage 9 (normal blood search &
maps) or any feed write is treated as shipped. The rules reconciliation is the
blocking dependency for deployment, not for code.

