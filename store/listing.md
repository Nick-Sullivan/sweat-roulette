# Play Store listing content

Everything to paste into Play Console → Store presence → Main store listing.

`play_icon_512.png` (App icon, 512×512) and `feature_graphic.png` (1024×500)
are both generated — run `flutter test tool/generate_icons.dart` to redraw them
from the plate-wheel painter rather than editing them by hand. Still needed:
at least 2 phone screenshots (see the bottom of this file).

Placeholder copy for now — rewrite once the app actually does something.

## App name (30 chars max)

    Sweat Roulette

## Short description (80 chars max)

    Spin the wheel and get your next workout.

## Full description (4000 chars max)

Sweat Roulette picks your workout so you don't have to.

This is an early build — the app is still being developed and does not do
anything useful yet. It is published to a testing track so the release
pipeline can be validated end to end.

## Console form answers (quick reference)

- Category: Health & Fitness
- Ads: No ads
- Data safety: No data collected, no data shared
- App access: All functionality available without special access
- Content rating questionnaire: utility/fitness app → Everyone
- Target audience: 18+ (avoids the extra child-safety obligations)
- Privacy policy URL: https://<your-github-username>.github.io/<repo>/privacy-policy.html
  (enable GitHub Pages: repo Settings → Pages → Deploy from branch → main,
  folder /docs)

## Screenshots

Play requires at least 2 phone screenshots (PNG/JPEG, shortest side ≥320px).

    flutter run --release
    # then for each screen you want:
    adb exec-out screencap -p > store/screenshot_1.png
