# Sweat Roulette — design system

The visual rules for the app, and the reasoning behind them.
[VISION.md](VISION.md) says what the app is; this says what it looks like.

**These rules are binding.** They are not preferences to weigh against
convenience — several are enforced by tests, and the rest hold the look
together. Where a rule has a reason, the reason is written down, because a token
table without a "why" invites someone to helpfully undo it.

Two standing instructions before anything else:

- **Never write a raw `Color(0x...)` outside `lib/theme/`.** Read colours from
  `Theme.of(context).colorScheme` or `context.sweatColors`.
- **Never edit an icon PNG.** Every image in `android/.../res/` and `store/` is
  build output. Change the painter and regenerate.

---

## Decision log

| Decision | Why |
|---|---|
| **Graphite & Cognac** palette | Chosen over neon-casino and Vegas-felt directions. Restrained luxury: cool graphite reads as steel, cognac as leather. |
| **Dark only** | The champagne reward colour has to *glow*, and glow needs a dark canvas. A light theme would always be the weaker one, so there isn't one. |
| **Bebas Neue** for display | Inter was tried first and read as generic — it's the most-seen UI font there is. Bebas is caps-only gym signage and casino board at once. |
| **Chivo** for text | Everything Bebas structurally cannot do: body copy, mixed-case titles, small labels. |
| **Fonts bundled, not fetched** | VISION.md: the phone is the only source of truth. That includes the UI, so no `google_fonts` (it downloads at runtime). |
| **Plate-wheel** mark | A bumper plate and a roulette wheel share a silhouette. One shape says gym and gamble simultaneously. |
| **Cognac ground** for the icon | A dark-on-dark icon disappears against dark wallpapers. Warm brown holds its own in a grid of loud icons. |
| **Mark-only splash** | The app boots in well under a second; a wordmark would be gone before it could be read. |
| **One pill, many compartments** | The roll screen's action row and History's back/prev/next are the same shape in the same place, so a thumb never learns a second position. [lib/app/ui/action_pill.dart](lib/app/ui/action_pill.dart). |
| **Cognac only on the roll's pill** | History's pill is graphite. Three brand-filled compartments on a screen with no action would spend the colour that makes the roll screen's one button mean something. |
| **Champagne marks the selection, not the achievement** | A month grid tinting every completed day gold would put the reward colour on screen twenty times. Cognac says "a session happened"; champagne says "this is the one you're looking at", exactly once per screen. |

---

## Colour

Defined in [lib/theme/app_palette.dart](lib/theme/app_palette.dart) — the only
file in the project containing colour literals.

| Token | Hex | Role |
|---|---|---|
| `canvas` | `#121315` | App background |
| `surfaceLow` | `#17191C` | Recessed panel |
| `surface` | `#1C1E21` | Raised card |
| `surfaceHigh` | `#23262A` | Card on card |
| `surfaceAlt` | `#2A2D31` | Chip, input, inactive track |
| `sink` | `#0D0E10` | Wells, scrim base |
| `outline` | `#3D4147` | Decorative hairline **only** |
| `outlineStrong` | `#7A828C` | Interactive borders (clears 3:1) |
| `cognac` | `#A9673B` | The roll action, active states |
| `cognacDeep` | `#33221A` | Container fill |
| `cognacLight` | `#E3B58C` | Text on `cognacDeep` |
| `champagne` | `#D9B26A` | Win / jackpot / sheen **only** |
| `inkHigh` | `#EDEBE7` | Primary text |
| `inkLow` | `#9A9EA5` | Secondary text |
| `inkOnBrand` | `#14100C` | Anything sitting on cognac or champagne |
| `errorInk` | `#E0776A` | Error text and icons |
| `errorFill` | `#5C241C` | Error container |
| `errorInkOnFill` | `#FFD9D3` | Text on `errorFill` |

### The three colour rules

**1. Champagne is a reward colour.** A landed roll, a completed set, a streak,
the sheen that sweeps the wheel. Never a resting surface, never body text. If it
starts appearing three times per screen it stops meaning "you won something" —
that scarcity *is* the design.

**2. Layers separate by value, not shadow.** Elevation is `0` everywhere and
surface tint is off; a card is a step up the graphite ramp plus a 1px `outline`
hairline. Don't add shadows to create hierarchy — use the next surface token.

**3. The grey ramp is cool on purpose.** Blue-leaning greys make the cognac read
as leather. Warm the greys and the whole thing muddies.

### The contrast constraint

Both brand colours sit mid-value, which caps how much contrast anything on top
of them can reach. **Cognac cannot clear 4.5:1 against any foreground** —
neither white nor black. The system works around it rather than fighting it:

- `inkOnBrand` on cognac is **4.2:1** — AA for large text, not for body.
- So **nothing small ever sits on a brand fill.** Button labels are 17px+ and
  qualify as large text at the 3:1 threshold. A 13px label on cognac is a bug.
- Chips use `surfaceAlt`, not `primary`, for exactly this reason.
- Outlined buttons take a **cognac** border rather than a grey one: it clears
  3:1 against the canvas and keeps the variant on-brand.

If a pairing fails, darken the ramp — don't swap the pairing and hope.

---

## Type

Defined in [lib/theme/app_typography.dart](lib/theme/app_typography.dart).
Bundled under `assets/fonts/` (about 370KB for both families).

### Bebas Neue — display

Caps-only, one weight, tall and condensed. Used for display styles, metrics and
button labels. Three constraints that catch people:

- **No lowercase.** Any string in a display style renders as capitals whatever
  you type. `'87.5 kg'` comes out `87.5 KG`.
- **No bold.** Emphasis has to come from size, colour or tracking.
- **Illegible below ~16px.** Anything smaller is Chivo.

### Chivo — text

Body copy, mixed-case titles, small labels. Weights 400/500/600/700.

### The scale

| Style | Face | Size | Weight | Use |
|---|---|---|---|---|
| `displayLarge` | Bebas | 52 | 400 | The rolled exercise name |
| `displayMedium` | Bebas | 40 | 400 | Secondary display |
| `displaySmall` | Bebas | 32 | 400 | Section headline |
| `headlineMedium` | Bebas | 26 | 400 | Screen headline |
| `titleLarge` | Chivo | 19 | 600 | Mixed-case title |
| `titleMedium` | Chivo | 16 | 600 | List row title |
| `bodyLarge` | Chivo | 16 | 400 | Body copy |
| `bodyMedium` | Chivo | 15 | 400 | Body copy |
| `bodySmall` | Chivo | 13 | 400 | Captions |
| `labelLarge` | Bebas | 21 | 400 | Button labels |
| `labelMedium` | Chivo | 12 | 500 | Chips, section labels |
| `labelSmall` | Chivo | 11 | 500 | Smallest label |

Plus four styles Material has no slot for, on the `SweatTextStyles` extension
(`context.sweatText`): `wordmark`, `sectionLabel`, `metric`, `metricSmall`, and
the paired `metricUnit` / `metricUnitSmall`.

### Numbers

Use `MetricText('87.5', unit: 'kg')` — Bebas digits, a small dimmed Chivo unit,
one shared baseline. `small: true` for list rows.

**Never bake a unit into the value string.** It's a widget rather than a style
precisely because the unit needs a second typeface; `'$weight kg'` in a display
style shouts `KG` back at you.

Metric styles carry `FontFeature.tabularFigures()` so digits don't jitter as a
value counts up.

---

## Space, shape and targets

Defined in [lib/theme/app_spacing.dart](lib/theme/app_spacing.dart).

- **Spacing** — 4 / 8 / 12 / 16 / 24 / 32 / 48. Every gap is one of these.
- **Radii** — 8 chip, 16 card, 999 pill.

### Touch targets

VISION.md: *"peoples hands will be tired so don't expect the ability for precise
button presses."* These are floors, not suggestions — Material's own 48dp
minimum is too small for someone mid-set.

| Token | Value | |
|---|---|---|
| `minTarget` | 56dp | Absolute floor for anything tappable |
| `button` | 64dp | Ordinary buttons |
| `primaryAction` | 88dp | The one primary action, full-bleed |
| `targetGap` | 12dp | Minimum gap, so a sloppy tap can't hit two things |

Two shared measurements sit alongside them, because two screens draw the same
exercise slot — the roll reveals it, History replays it — and they have to agree
by reading one number rather than by coincidence:

| Token | Value | |
|---|---|---|
| `slot` | 72dp | Height of a slot's head row |
| `intensityColumn` | 104dp | Width of the intensity column, fixed so the divider lands at the same x on every card |

**The floor is why History's calendar isn't tappable.** Seven columns inside the
gutters leaves about 47dp a cell. A grid you can tap is a grid that asks for the
precise press VISION.md says tired hands don't have, so the month is a map and
the moving is done by the swipe and by two 131dp compartments at the bottom.

---

## The mark

[lib/theme/brand/plate_wheel.dart](lib/theme/brand/plate_wheel.dart). Drawn by
`PlateWheelPainter`, not stored as an asset, so one painter feeds the in-app
logo, every Android icon slot and — later — the wheel that spins. All geometry
is a fraction of the radius, so the same numbers hold at 48px and 512px.

### What makes it read correctly

A **narrow band of many short segments** (12, spanning 0.54–0.80 of the radius),
with **solid cognac inside and outside** it, a champagne hairline at 0.91, and a
bore at 0.28.

The first attempt used 8 wide wedges spanning most of the radius and came out as
a **wagon wheel** — wide wedges read as spokes. What makes it a roulette wheel is
the ring of many short segments; what makes it a plate is the solid field around
them. Don't widen the band.

The margin outside `wedgeOuter` doubles as the adaptive icon's safe zone.

### Presets

| Preset | For |
|---|---|
| `PlateWheelStyle.mark` | The full mark: cognac field, graphite segments |
| `PlateWheelStyle.iconForeground` | Adaptive foreground — **no field**, the cognac comes from the background layer |
| `PlateWheelStyle.monochrome` | Themed-icon silhouette, segments punched through to transparency |

`PlateWheelPainter` already takes a `rotation`, so the spin animation can drive
it without the geometry changing.

### Regenerating

```
flutter test tool/generate_icons.dart
```

Run it after any change to `PlateWheelStyle` or the palette. It writes 20 PNGs
plus both store assets:

| Output | Slot |
|---|---|
| `mipmap-*/ic_launcher.png` | Legacy launcher, 48→192px |
| `mipmap-*/ic_launcher_foreground.png` | Adaptive foreground, 108dp canvas, mark at 66dp |
| `mipmap-*/ic_launcher_monochrome.png` | Android 13+ themed icon |
| `drawable-*/splash_logo.png` | Launch screen |
| `store/play_icon_512.png` | Play listing icon |
| `store/feature_graphic.png` | Play feature graphic, 1024×500 |

The generator lives outside `test/` on purpose: `flutter test` only walks
`test/`, so CI never runs it and never writes into a checkout.

Two traps it works around, worth knowing before editing it:

1. `Picture.toImage()` needs the real event loop. Use a plain `test()`; inside
   `testWidgets` the fake-async clock deadlocks it.
2. Bundled fonts are **not** registered in the test environment. The feature
   graphic's wordmark loads Bebas by hand via `FontLoader`, or it silently falls
   back to the test font.

Android wiring is hand-written beside the generated PNGs:
`mipmap-anydpi-v26/ic_launcher.xml` (adaptive), `values/colors.xml` (the two
hex values Android can't read from Dart — keep them in step with the palette),
`drawable*/launch_background.xml`, and `values-v31/styles.xml`, which exists
because **Android 12+ ignores `windowBackground` for the splash** and shows the
launcher icon on its own near-white background unless
`windowSplashScreenBackground` is set.

---

## File map

```
lib/theme/
  app_palette.dart      the ONLY place hex literals live
  app_colors.dart       SweatColors — roles ColorScheme has no slot for
  app_typography.dart   TextTheme, SweatTextStyles, MetricText
  app_spacing.dart      spacing, radii, touch-target floors, shared slot sizes
  app_theme.dart        SweatTheme.dark + context.sweatColors / .sweatText
  brand/plate_wheel.dart  the mark
lib/app/ui/
  action_pill.dart      the one fixed control, shared by both screens
tool/generate_icons.dart  rasterises every icon (not run by CI)
assets/fonts/             Bebas Neue + Chivo
```

`lib/home/ui/home_screen.dart` is **temporary** — a showcase of the system
(swatches, type scale, components) so it can be reviewed on a device. It gets
replaced wholesale by the real home screen when the roll feature lands.

---

## How the rules are enforced

Three test files turn design rules into build failures rather than good
intentions:

- **[test/theme/contrast_test.dart](test/theme/contrast_test.dart)** — computes
  WCAG relative luminance for every pairing the system actually uses; 4.5:1 for
  body text, 3:1 for large text and UI. Also asserts the graphite ramp steps are
  separable by value, since nothing else distinguishes the layers.
- **[test/theme/app_theme_test.dart](test/theme/app_theme_test.dart)** — the app
  stays dark with the platform in light mode, buttons clear the target floors,
  surfaces stay flat.
- **[test/theme/plate_wheel_test.dart](test/theme/plate_wheel_test.dart)** — the
  mark survives 48px, is symmetric about the vertical axis (catching a
  half-period error in the wedge angle that only shows once it spins), and the
  themed-icon layer is genuinely punched through. That last one is checked by
  reading the alpha channel because transparent and white are indistinguishable
  in any image viewer.

---

## Open decisions

Recorded so a later session starts from here rather than re-deriving — and so
nothing below is mistaken for settled.

### Motion vocabulary — direction agreed, details open

Agreed in principle: **restrained shimmer**. Drama comes from motion, weight and
gold — the wheel blurs, the rim catches a champagne sheen, the result lands
heavily. **The palette is never broken**, not even at the loudest moment: no
strobes, no confetti, no colour from outside the system. Premium, like a watch
bezel, not a slot machine.

Undecided: durations, curves, the landing treatment, whether the wheel lands on
a marker, and how the result is revealed.

### Feedback on landing — undecided

- **Haptics only** — `HapticFeedback` is built into Flutter. No dependency, no
  assets, works offline.
- **Haptics plus sound** — needs an audio package and royalty-free clips
  committed to the repo. Note that those clips would be placeholders chosen by
  whoever implements it, not by the app's owner.

### Storage — designed, and deliberately dull

Sessions are JSON lines under the app support directory: an append-only
`sessions.jsonl` that is never rewritten, plus a small `session.live.json` for
the one session under way, rewritten atomically on each phase change. A record
is ~250 bytes and a year gzips to under 6KB, which is the "compresses well" part
of the brief and also what makes the later cloud upload cheap. The reasoning,
the failure modes and the schema-version rules are all in
[lib/history/data/session_record.dart](lib/history/data/session_record.dart) and
[session_store.dart](lib/history/data/session_store.dart).

Two rules that are load-bearing rather than incidental:

- **A slot the roll didn't fill is not in the file at all.** VISION.md rolls 2
  *or* 3 pools, so an empty third slot is the app working. Anything that tints,
  counts or scores a slot keys off `SlotOutcome.isShortfall`, never off the enum
  identity, so a two-pool day can never be rendered as a miss.
- **The reward colour follows that rule too.** A clean two-pool day gets the
  same cognac disc on the calendar as a clean three-pool one.

**Open:** whether an interrupted session should offer to *resume* rather than be
recorded as abandoned at the next launch — and if so, for how long afterwards.
Recovery is what's built; the format supports either with no migration.

### The catalogue — structured, but empty of real content

[lib/exercises/data/exercise_catalogue.dart](lib/exercises/data/exercise_catalogue.dart)
is one list and nothing else, and replacing it is the only edit needed to give
the app real movements. Every entry in it today is a NATO alphabet word
round-robined across the five pools — nonsense on purpose, because an entry now
carries a `MovementPool` and putting a real movement in a real pool is a claim
about training.

No test reads that file except the one checking its *shape* — ids unique and
slug-shaped, names unique, pools non-empty. Everything else runs against a
fixture, so replacing the list cannot turn the suite red.

Two rules worth knowing before editing it:

- **Ids are written down, never derived from names.** History stores an id plus
  a name snapshot so a rename isn't a migration; deriving the id would re-key
  every past record the first time you renamed something.
- **The pool is not shown anywhere in the UI.** It steers the roll — one
  movement from each of two or three pools, which is what VISION.md asks for —
  and that is all. The Exercises screen is a flat A–Z list for the same reason
  the roll screen has no pool labels: which pool something came from is how the
  app chose, not what you do.

### Everything downstream — not designed

The hybrid anchor model, weekly volume targets, RIR capture,
casual-vs-hardcore configuration. [VISION.md](VISION.md) is the source for all
of it; none of it has been designed yet. `SweatColors` names the movement-pool
tints and the RIR effort ramp as its expected next additions, but neither has
fields or values — nothing yet needs a colour per pool, and five brand-adjacent
colours would each need a contrast-test entry and a decision about competing
with cognac.

One of those rules has a visual consequence worth flagging early: VISION.md
rule 4 asks the app to *teach* — "help people learn more about what is and isn't
good and healthy". That means real explanatory prose, not just labels and
numbers, so body copy is load-bearing rather than decorative. `bodyLarge` at
16/1.45 in Chivo is set for reading at length and should carry it; the thing to
design is where explanation *lives* (inline, expandable, a separate surface)
without crowding the tired-hands rule.
