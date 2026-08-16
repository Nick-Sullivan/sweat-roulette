# Working on Sweat Roulette

How I like this repo worked on. [VISION.md](VISION.md) says what the app is,
[DESIGN.md](DESIGN.md) says what it looks like — both are binding, read them
before changing anything they cover.

## Move fast, let me confirm

**Don't verify your work in the emulator.** Implement, run `flutter analyze` and
`flutter test`, push it to the device, and hand it back to me. I will tell you
what's wrong. Screenshotting your own work step by step burns far more of my
time than a wrong guess does.

Ship it with:

```powershell
flutter run -d emulator-5554     # or `flutter emulators --launch <id>` first
```

`adb` is not on PATH — it lives at
`$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`.

## Keep the tests green

`flutter test` passes before you hand anything back. When a test breaks because
the design changed, rewrite it to assert the *new* intent and say so — don't
delete it and don't weaken it to pass.

## Never decide anything about training

VISION.md is explicit: you know nothing about muscles, workouts or biology. Any
exercise copy, rest interval or ordering rule is mine to supply. Where you need
content to size a layout, use text that is obviously a placeholder — never
plausible-sounding advice.

## Design feedback is about feel

I'll describe problems as I see them — "it jitters", "too quick", "it jumps".
Find the actual cause rather than tuning a number; most of those turned out to
be animations racing each other, not durations being wrong.

When there's a real fork with no obvious default, ask me once with concrete
options. Don't ask about things with a sensible default, and don't guess on
things that would waste an iteration.

## Tell me what you changed, briefly

Lead with what's different and anything I should decide. Skip the play-by-play.
Flag it when you traded away a rule in DESIGN.md to do what I asked.
