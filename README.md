# Sweat Roulette

A Flutter app (Android). Currently a do-nothing shell with the full release
path to Google Play already wired up.

| | |
|---|---|
| Dart package | `sweat_roulette` |
| Application ID | `com.nicksullivan.sweat_roulette` |
| Flutter | 3.32.8 (pinned in CI) |

## Architecture

```
lib/
  main.dart              bootstrap -> resolve platform values -> runApp
  app/
    app.dart             SweatRouletteApp: MaterialApp.router, dark-only theme
    providers.dart       injectable singletons (overridden in main)
    router.dart          GoRouter route table
  theme/
    app_palette.dart     the ONLY place hex literals live
    app_colors.dart      SweatColors: roles ColorScheme has no slot for
    app_typography.dart  TextTheme + wordmark/metric styles
    app_spacing.dart     spacing, radii, touch-target floors
    app_theme.dart       SweatTheme.dark + context.sweatColors / .sweatText
  home/ui/
    home_screen.dart     TEMPORARY: design-system showcase
```

Riverpod for DI/state, go_router for navigation. Everything platform-dependent
is resolved in `main()` and injected through `ProviderScope.overrides` — no
lazy service-locator lookups, so widget tests supply their own values.

## Design system

**Read [DESIGN.md](DESIGN.md) before touching any UI.** Graphite & Cognac, dark
only; Bebas Neue and Chivo; the plate-wheel mark. It carries the tokens, the
rules and — importantly — the reasons, so a rule doesn't get helpfully undone.

The three that bite soonest:

- **Hex lives in one file.** Widgets read `Theme.of(context).colorScheme` or
  `context.sweatColors` — never `SweatPalette` directly.
- **Champagne is a reward colour**, never a resting surface or body text.
- **Icon PNGs are build output.** Change the painter and run
  `flutter test tool/generate_icons.dart`; don't edit the images.

Several rules are enforced by tests under `test/theme/` rather than left to
good intentions — contrast against WCAG AA, the touch-target floors, and the
mark's legibility at 48px.

## Dev commands

```
flutter pub get
flutter run
flutter test
flutter analyze

# Redraw every launcher, splash and store icon from the painter.
# Run after changing PlateWheelStyle or the palette.
flutter test tool/generate_icons.dart
```

## Releasing to Google Play

Deploys are automatic:

- **Push to `main`** → builds, tests, and ships to the **internal** testing track.
- **Manual production release**: Actions tab → *Deploy to Google Play* → *Run
  workflow* → choose `production`.

Versioning is fully derived — nothing to bump by hand:

- `versionCode` = `VERSION_CODE_BASE` (1000) + the workflow run number
- `versionName` = `YYYY.MM.DD.<run number>` (UTC)

> ⚠️ Run numbers are scoped to the workflow **filename**. Renaming
> `.github/workflows/release.yml` resets them, which would push `versionCode`
> backwards and Play would reject the upload. If it ever must be renamed, raise
> `VERSION_CODE_BASE` above the highest code already published.

### One-time setup

**1. Upload keystore**

```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep it **outside this repo** and back it up — losing it means you can't update
the app without Google's key-reset flow. For local release builds, create
`android/key.properties` (gitignored):

```
storeFile=<absolute path to upload-keystore.jks>
storePassword=...
keyAlias=upload
keyPassword=...
```

Without that file, `flutter build --release` falls back to debug signing so a
fresh clone still builds.

**2. Google Cloud service account**

1. <https://console.cloud.google.com> → create/pick a project
2. APIs & Services → Library → enable **Google Play Android Developer API**
3. IAM & Admin → Service Accounts → create one (no project roles needed)
4. Keys → Add key → Create new key → **JSON**. Keep it outside this repo.

**3. Play Console**

1. <https://play.google.com/console> (Developer account, US$25 one-time)
2. All apps → **Create app**: *Sweat Roulette*, App, Free
3. Setup → App integrity → enrol in **Play App Signing**
4. **Users and permissions → Invite new users**: add the service account email,
   scope it to this app, grant *Release to testing tracks*, *Release apps to
   production*, and *View app information*

**4. GitHub secrets** (Settings → Secrets and variables → Actions)

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64 of `upload-keystore.jks` |
| `KEYSTORE_PASSWORD` | keystore password |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | full contents of the service-account JSON |

PowerShell for the base64:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('upload-keystore.jks')) | Set-Clipboard
```

**5. First bundle must be uploaded by hand.** The Play API cannot create the
very first release. Build locally with `android/key.properties` present:

```
flutter build appbundle --release --build-name=0.1.0 --build-number=1000
```

Upload `build/app/outputs/bundle/release/app-release.aab` under Testing →
Internal testing → Create new release. Using `1000` means CI's first run
(`1000 + run_number`) lands strictly above it.

**6. Complete the Console forms** — Play blocks releases until Store listing,
Privacy policy URL, App access, Ads, Content rating, Target audience, Data
safety, Government apps, and Financial features are all done. Answers to paste
are in [`store/listing.md`](store/listing.md).

**7. GitHub Pages** for the privacy policy: Settings → Pages → Deploy from a
branch → `main`, folder `/docs`. The URL is
`https://<user>.github.io/<repo>/privacy-policy.html`.
