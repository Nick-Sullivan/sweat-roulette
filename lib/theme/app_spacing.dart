/// Spacing scale. Every gap in the app is one of these — no ad-hoc numbers.
abstract final class SweatSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

abstract final class SweatRadius {
  static const chip = 8.0;
  static const card = 16.0;
  static const pill = 999.0;
}

/// Touch targets, sized for VISION.md's "peoples hands will be tired" rule.
/// These are floors, not suggestions — Material's own 48dp minimum is too small
/// for someone mid-set.
abstract final class SweatSize {
  /// Absolute floor for anything tappable.
  static const minTarget = 56.0;

  /// Ordinary buttons.
  static const button = 64.0;

  /// The one primary action on a screen (the roll). Full-bleed width.
  static const primaryAction = 88.0;

  /// Minimum gap between adjacent targets, so a sloppy tap can't hit both.
  static const targetGap = 12.0;

  /// Screen edge padding.
  static const gutter = SweatSpace.lg;

  /// Height of one exercise slot's head row.
  ///
  /// A token rather than a screen-local constant because two screens draw the
  /// same slot: the roll reveals it, History replays it. They have to agree by
  /// reading the same number, not by coincidence.
  static const slot = 72.0;

  /// Width of a slot's intensity column. Fixed rather than sized to its text —
  /// `Heavy`, `Normal` and `Light` are three different widths, and letting the
  /// column shrink to fit would put the divider at a different x on every card.
  static const intensityColumn = 104.0;
}
