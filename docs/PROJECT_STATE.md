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
| 6 | Profile photo upload (Supabase Storage) | **Complete — awaiting approval** |
| 7 | Navigation & settings | Not started |
| 8 | Donor management & badges | Not started |
| 9 | Normal blood search & maps | Not started |
| 10 | Emergency blood request | Not started |
| 11 | Donor matching & notifications | Not started |
| 12 | Messaging & live location | Not started |
| 13 | Admin, security & testing | Not started |
| 14 | Production preparation | Not started |

Stage 6 was re-scoped by the client from the original plan's "social feed & image
upload" to **profile photo upload on Supabase Storage**. The feed is not on the
schedule any more; the names of Stages 7–14 are unchanged.

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

**Stage 7 — not started, waiting for approval.** Before Stage 6's storage claims
can be upgraded from "tested against fakes" to "verified", steps 1–5 of
`docs/storage/README.md` have to be performed and their output recorded: the
project, the Firebase provider, the applied SQL, the verification queries, and
the `curl` negative test that must come back `403`.

