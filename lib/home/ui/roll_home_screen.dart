import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../state/roll_session.dart';

/// **UI design only.** No storage, no persistence — the session is real enough
/// to walk through, and nothing survives a restart.
///
/// ## One action, five states
///
/// The whole screen is driven by [rollSessionProvider] and a single primary
/// action that changes its label rather than its position:
///
/// | Phase | Button | Screen |
/// |---|---|---|
/// | clear | ROLL | three empty slots — the shape of a day before it exists |
/// | rolled | START | two or three filled cards, nothing under way |
/// | exercising | NEXT / FINISH | the current card expanded and scrolled to the top |
/// | resting | NEXT | the rest grown into a focus panel, counting down |
/// | done | ROLL | the finished day, every slot receded |
///
/// The last exercise reads **FINISH**, not NEXT: there is nothing after it, and
/// a button that says "next" should not be the one that ends the day.
///
/// ## The day advances upward
///
/// Whatever is being done now — the open card, or the rest counting down — is
/// scrolled to the top of the viewport. Finished slots recede down the graphite
/// ramp and scroll off above; the ones still to come sit below. You never hunt
/// for where you are.
///
/// When only two pools come up, the third slot stays in place and says it was
/// skipped, **and so does the rest gap above it**. A short day should read as
/// *shorter*, not as a screen whose cards sit somewhere else.
///
/// ## What it deliberately does not say
///
/// No pool labels: which pool an exercise came from is how the app chose, not
/// what you do. Also absent, all still open: sets and reps, the rest interval's
/// real range, where the 1–3 RIR target gets stated, and the warm-up set.
///
/// ## Chrome
///
/// None. The only fixed element is the action row at the bottom, and the way
/// off this screen is the narrow button on its left — so navigation costs no
/// vertical space at all and sits in the same place your thumb already is.
///
/// The plate-wheel mark is absent from every resting state — it belongs to the
/// roll animation, appearing, spinning and clearing. `PlateWheelPainter` already
/// takes a `rotation`, so nothing about the mark needs to change to build that.
class RollHomeScreen extends ConsumerStatefulWidget {
  const RollHomeScreen({super.key});

  @override
  ConsumerState<RollHomeScreen> createState() => _RollHomeScreenState();
}

class _RollHomeScreenState extends ConsumerState<RollHomeScreen>
    with SingleTickerProviderStateMixin {
  /// One key per slot, held for the life of the screen so that scrolling can
  /// find whichever is currently being done.
  ///
  /// Deliberately *not* a single key moved onto the focused widget: a
  /// [GlobalKey] that appears somewhere new is treated as a reparent, so the
  /// element — and its half-finished size animation — would migrate from the
  /// card to the rest bar as the session advanced.
  late final _cardKeys = List.generate(slots, (_) => GlobalKey());
  late final _restKeys = List.generate(slots, (_) => GlobalKey());

  /// Drives the scroll for as long as the slots are still resizing.
  ///
  /// Built in [initState] rather than lazily: a `late final` would be
  /// constructed by whoever touched it first, and on a screen that was never
  /// advanced that is [dispose] — which builds a ticker against an element
  /// already on its way out.
  late final AnimationController _reveal;
  late final Animation<double> _revealCurve;

  /// Whichever slot is being done right now, or null between sessions.
  GlobalKey? _focus;

  /// How far down the screen the focused slot sat when the move began.
  ///
  /// Deliberately a *screen* distance rather than a scroll offset. Captured on
  /// the first frame of the run rather than up front, because the run starts
  /// from a provider listener and the scroll position is only reachable
  /// through the focused slot's context.
  double? _fromDy;

  @override
  void initState() {
    super.initState();
    // Only the travel — the opening that follows moves nothing the scroll
    // cares about, because a slot grows downward from a top edge that has
    // already stopped.
    _reveal = AnimationController(vsync: this, duration: _travel)
      ..addListener(_followFocus)
      ..addStatusListener(_onRevealDone);
    _revealCurve = CurvedAnimation(
      parent: _reveal,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _revealFocus(RollSession session) {
    _focus = switch (session.phase) {
      SessionPhase.exercising => _cardKeys[session.index],
      SessionPhase.resting => _restKeys[session.index],
      _ => null,
    };
    if (_focus == null) return;
    _fromDy = null;
    _reveal.forward(from: 0);
  }

  /// Eases the list from where it was to the focused slot's top edge, tracking
  /// the target as the slots resize under it.
  ///
  /// Both halves of that matter. Advancing the session resizes two slots at
  /// once — the one just finished collapses while the new one grows — and the
  /// collapsing one is *above* the target, so a scroll animation aimed once at
  /// the old layout overshoots and strands the focused slot off the top. But
  /// simply pinning the target to the top every frame is no better: it arrives
  /// there on the very first frame, which is the jump. So the destination is
  /// recomputed every frame while the journey to it is interpolated, and the
  /// slot rises to the top over the same [_settle] the cards are opening in.
  void _followFocus() => _scrollTo(_revealCurve.value);

  void _scrollTo(double t) {
    final target = _focus?.currentContext;
    if (!mounted || target == null) return;

    final box = target.findRenderObject();
    if (box is! RenderBox || !box.attached) return;

    final position = Scrollable.of(target).position;
    if (!position.hasPixels || !position.hasContentDimensions) return;

    // Where the list would have to sit, in this frame's layout, for the slot
    // to rest just below the top rather than jammed against it.
    final flush =
        RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset -
        _focusInset;

    // Drive the slot's distance down the screen, not the scroll offset.
    //
    // The offset that puts the slot at the top moves while the animation runs:
    // the slot above it is collapsing, so the content shrinks under the list
    // and `flush` falls frame by frame. Easing towards it as an absolute
    // number therefore aims past where it ends up, and the slot sails above
    // the top before being pulled back down — the bounce. Easing the *screen*
    // distance to zero instead is immune to that: however the layout moves
    // underneath, the slot descends onto the top edge once and stays there.
    final fromDy = _fromDy ??= flush - position.pixels;

    position.jumpTo(
      (flush - fromDy * (1 - t)).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  /// One last correction once everything has stopped moving.
  ///
  /// Every frame's destination is computed from the previous frame's layout, so
  /// the final frame lands a pixel or two short. Invisible at that distance,
  /// but it is what keeps the focused slot exactly flush with the top.
  void _onRevealDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(1));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(rollSessionProvider, (previous, next) {
      // Only when the focus actually moves — not on every countdown tick.
      if (previous?.phase != next.phase || previous?.index != next.index) {
        _revealFocus(next);
      }
    });

    final session = ref.watch(rollSessionProvider);
    final notifier = ref.read(rollSessionProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Room beneath the last slot so it can still reach the top of
                  // the viewport. Measured rather than guessed: exactly a
                  // viewport less the slot that has to sit in it.
                  final trailing = session.isRunning
                      ? (constraints.maxHeight -
                                _cardHeight -
                                _focusInset -
                                SweatSpace.xl)
                            .clamp(SweatSpace.lg, double.infinity)
                      : SweatSpace.lg;

                  return Center(
                    // Centred while short — a two-slot day would otherwise sit
                    // in the top third with a void beneath it. Once a session
                    // is running the content outgrows the viewport and this
                    // stops having any effect.
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SweatSize.gutter,
                      ),
                      // Animated, because this is what makes START smooth.
                      // Gaining the trailing room in one frame takes the
                      // content from shorter than the viewport to far taller,
                      // so the centring above stops applying instantly and the
                      // whole list leaps up before anything has animated.
                      // Grown over the same [_settle], the list rises into
                      // place with everything else.
                      child: AnimatedPadding(
                        duration: _travel,
                        curve: Curves.easeInOutCubic,
                        padding: EdgeInsets.only(
                          top: SweatSpace.lg,
                          bottom: trailing,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _slotWidgets(session),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _ActionRow(
              label: session.actionLabel,
              onPressed: notifier.advance,
              onNavigate: () => _openNavSheet(context, onReset: notifier.reset),
            ),
          ],
        ),
      ),
    );
  }

  /// How long the reel at reveal position [step] turns for.
  ///
  /// Every reel starts together, so a reel's spin is the shared lead-in plus
  /// however many stops come before its own. The animation therefore ends at
  /// the same moment the session marks it landed — and since it is animating
  /// towards a value that was already decided, even a few frames of drift are
  /// invisible.
  Duration _spinFor(int step) => kSpinDuration + kRevealStep * step;

  List<Widget> _slotWidgets(RollSession session) {
    return [
      for (var i = 0; i < slots; i++) ...[
        if (i > 0)
          _RestSlot(
            key: ValueKey('rest-$i'),
            anchor: _restKeys[i],
            status: session.restStatusAt(i),
            seconds: session.secondsLeft,
            // Null means this gap leads into a slot the day didn't fill, so
            // its reel stops on nothing.
            landsOn: i < session.exercises.length ? kRestSeconds : null,
            spinFor: _spinFor(RollSession.restStep(i)),
          ),

        _ExerciseSlot(
          key: ValueKey('card-$i'),
          anchor: _cardKeys[i],
          status: session.statusOf(i),
          // A slot that hasn't landed shows nothing, even though the day
          // already knows what is in it. Handing the widget its exercise early
          // would print the answer above a reel that hasn't spun yet.
          exercise: switch (session.statusOf(i)) {
            SlotStatus.ghost => null,
            SlotStatus.skipped when !session.isRolling => null,
            _ => i < session.exercises.length ? session.exercises[i] : null,
          },
          spinFor: _spinFor(RollSession.cardStep(i)),
        ),
      ],
    ];
  }
}

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

/// The way off this screen, opened from the narrow button beside the action.
///
/// A sheet rather than a row of icons: VISION.md names three more screens and
/// will likely name more, and a sheet grows to fit them without spending any of
/// the roll screen on chrome that is used once a session at most.
void _openNavSheet(BuildContext context, {required VoidCallback onReset}) {
  final theme = Theme.of(context);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SweatRadius.card),
      ),
    ),
    builder: (sheetContext) {
      void goTo(String location) {
        Navigator.of(sheetContext).pop();
        // The screen's context, not the sheet's — the sheet sits in its own
        // navigator and go_router isn't reachable from there.
        context.push(location);
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: SweatSpace.sm),
            const _SheetGrabber(),
            ListTile(
              key: const Key('nav-history'),
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () => goTo('/history'),
            ),
            ListTile(
              key: const Key('nav-exercises'),
              leading: const Icon(Icons.list),
              title: const Text('Exercises'),
              onTap: () => goTo('/exercises'),
            ),
            ListTile(
              key: const Key('nav-config'),
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Config'),
              onTap: () => goTo('/config'),
            ),

            // TEMPORARY: the owner's testing affordance, so a session can be
            // thrown away from any phase without walking it to the end. Delete
            // this divider and tile together with `kRestSeconds`.
            const Divider(),
            ListTile(
              key: const Key('reset'),
              leading: Icon(
                Icons.restart_alt,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                'Reset',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              subtitle: Text(
                'Temporary — for testing',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onReset();
              },
            ),
            const SizedBox(height: SweatSpace.sm),
          ],
        ),
      );
    },
  );
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: SweatSpace.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(SweatRadius.pill),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The action row
// ---------------------------------------------------------------------------

/// The only fixed chrome: one long pill, split about 20/80.
///
/// One shape rather than two buttons — the navigation is a compartment of the
/// action, not a rival to it. It costs no vertical space of its own and sits
/// where the thumb already is, which is the point of VISION.md's tired-hands
/// rule.
///
/// The split is a groove, not just a line: [SweatSize.targetGap] of the pill
/// between the two halves belongs to neither and responds to nothing. DESIGN.md
/// asks for that gap so a sloppy tap can't hit two things, and merging the
/// halves into one silhouette is not a reason to give it up — it just moves the
/// gap inside the shape.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.onPressed,
    required this.onNavigate,
  });

  final String label;
  final VoidCallback onPressed;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SweatSize.gutter,
        SweatSpace.sm,
        SweatSize.gutter,
        SweatSpace.lg,
      ),
      child: Container(
        height: SweatSize.primaryAction,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: theme.colorScheme.primary,
          shape: const StadiumBorder(),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Row(
            // Stretch so both halves — and the seam between them — run the
            // full height of the pill.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('nav-menu'),
                  onTap: onNavigate,
                  child: Center(
                    child: Icon(
                      Icons.menu,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const _ActionSeam(),
              Expanded(
                flex: 4,
                child: InkWell(
                  key: const Key('primary-action'),
                  onTap: onPressed,
                  child: Center(
                    child: Text(
                      label,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        letterSpacing: 4.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The join between the two halves of the action pill.
///
/// Not a drawn line but a machined one: a dark groove with a lit edge beside
/// it, the way a seam in a solid object catches light. That reads as one piece
/// of metal parted rather than two shapes butted together — DESIGN.md's
/// restrained-luxury direction, a watch bezel rather than a border.
///
/// Runs edge to edge and stays only as wide as itself, so pressing either half
/// fills its colour right up to the seam with no dead strip beside it. It also
/// swells through the middle and eases off at the ends, which is what stops
/// three flat pixels from reading as a rule someone forgot to remove.
///
/// The cost is DESIGN.md's 12dp gap between adjacent targets: the two halves
/// are a hair apart, so a tap by the seam can land on either. What guards it
/// instead is distance — the seam sits at a fifth of the width, nowhere near
/// where a thumb aims for the action.
class _ActionSeam extends StatelessWidget {
  const _ActionSeam();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 3,
      child: Row(
        // Stretch, or the two edges size to their own content — which is
        // nothing — and the seam disappears entirely.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The cut, then the light catching its far wall.
          Expanded(child: _SeamEdge(scheme.inversePrimary)),
          Expanded(child: _SeamEdge(scheme.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _SeamEdge extends StatelessWidget {
  const _SeamEdge(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Never fully transparent: the line still has to reach both edges.
          colors: [
            color.withValues(alpha: 0.4),
            color,
            color.withValues(alpha: 0.4),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise slots
// ---------------------------------------------------------------------------

/// One slot in the day, in whichever of its five states it is currently in.
///
/// A single widget rather than one per state so the reel head is provably
/// identical across all of them: the head is [_cardHeight] tall with the
/// divider at [_intensityWidth] from the right, whatever else the slot is
/// doing. The reels have to line up down the screen or they don't read as
/// reels.
class _ExerciseSlot extends StatefulWidget {
  const _ExerciseSlot({
    required this.status,
    required this.exercise,
    required this.anchor,
    required this.spinFor,
    super.key,
  });

  final SlotStatus status;

  /// Null for a ghost slot, or a landed skipped one.
  final RolledExercise? exercise;

  /// This slot's scroll anchor, held by the screen for the session's lifetime.
  final GlobalKey anchor;

  /// How long this slot's reels turn for, if they are turning.
  final Duration spinFor;

  @override
  State<_ExerciseSlot> createState() => _ExerciseSlotState();
}

class _ExerciseSlotState extends State<_ExerciseSlot>
    with SingleTickerProviderStateMixin {
  /// Drives the detail open and shut.
  ///
  /// Explicit rather than an [AnimatedSize] around a child that appears and
  /// disappears: that animates the box while the contents vanish on the first
  /// frame, which is the jump. Driving it directly lets the detail be clipped
  /// and faded *as* the card closes, so one motion covers the whole thing.
  late final AnimationController _expand;
  late final Animation<double> _open;

  bool get _expanded => widget.status == SlotStatus.active;

  bool get _turning =>
      widget.status == SlotStatus.spinning ||
      widget.status == SlotStatus.settling;

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(
      vsync: this,
      duration: _settle,
      value: _expanded ? 1 : 0,
    );
    // Held shut through the travel, then opened. Reversed, the interval runs
    // from the far end, so a card closing gets out of the way *first* and the
    // list is still moving after it has finished — nothing left to correct.
    _open = CurvedAnimation(
      parent: _expand,
      curve: const Interval(
        _openingBegins,
        1,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(_ExerciseSlot old) {
    super.didUpdateWidget(old);
    if (_expanded != (old.status == SlotStatus.active)) {
      _expanded ? _expand.forward() : _expand.reverse();
    }
  }

  @override
  void dispose() {
    _expand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = widget.status;
    final exercise = widget.exercise;

    // Layers separate by value, never shadow — DESIGN.md's second colour rule.
    // A finished slot steps *down* the graphite ramp rather than fading: an
    // `Opacity` wrapper would be a shortcut around the ramp the system is
    // built on.
    final (Color? fill, Color border, Color ink) = switch (status) {
      SlotStatus.ghost ||
      SlotStatus.skipped => (null, scheme.outline, scheme.onSurfaceVariant),
      SlotStatus.pending ||
      // A reel with others still to stop before it is just noise — marking
      // every one of them would point at nothing.
      SlotStatus.spinning => (
        scheme.surface,
        scheme.outline,
        scheme.onSurface,
      ),
      // Cognac is DESIGN.md's colour for the roll itself, and this is where the
      // roll is about to say something.
      SlotStatus.settling => (
        scheme.surface,
        scheme.primary,
        scheme.onSurface,
      ),
      // `outlineStrong` is the token for a border that carries meaning, and it
      // clears 3:1. Champagne stays reserved for rewards — an exercise in
      // progress has not been won yet.
      SlotStatus.active => (
        scheme.surface,
        context.sweatColors.outlineStrong,
        scheme.onSurface,
      ),
      SlotStatus.complete => (
        scheme.surfaceContainerLow,
        scheme.outline,
        scheme.onSurfaceVariant,
      ),
    };

    return KeyedSubtree(
      key: widget.anchor,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(SweatRadius.card),
        ),
        // A hairline, not a shadow. In the *foreground* decoration, because a
        // `Container`'s background border also insets its child by its width —
        // which would make a filled card 2dp taller than a ghost or skipped
        // one, and a two-pool day would stop lining up with a three-pool one.
        // Painting over the child instead keeps every reel head a true 72dp.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SweatRadius.card),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _cardHeight,
              child: exercise == null && !_turning
                  ? _EmptyHead(status: status, ink: ink)
                  : _ReelHead(
                      exercise: exercise,
                      ink: ink,
                      spinning: _turning,
                      spinFor: widget.spinFor,
                    ),
            ),
            // Clipped and faded together as the card opens and shuts, so the
            // contents leave with the space rather than before it. Built only
            // while there is something to show — a shut card holds no detail
            // at zero height, it holds none at all.
            AnimatedBuilder(
              animation: _expand,
              builder: (context, child) => _expand.isDismissed
                  ? const SizedBox.shrink()
                  : SizeTransition(
                      sizeFactor: _open,
                      axisAlignment: -1,
                      child: FadeTransition(opacity: _open, child: child),
                    ),
              child: const _ExerciseDetail(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two reels: the movement on the left, the intensity on the right,
/// divided by a full-height rule.
///
/// The halves are meant to spin independently, so the divider is structural
/// rather than decorative — it's the boundary between two strips. That's why
/// the right column is a fixed [_intensityWidth] instead of sizing to its text:
/// `Heavy`, `Normal` and `Light` are three different widths, and letting the
/// column shrink to fit would put the rule at a different x on every card.
/// While [spinning], the two halves really do spin, and they stop one after
/// the other — the movement first, then how hard. Landing them together would
/// read as one reveal; landing them apart is the second beat that makes it a
/// slot machine.
class _ReelHead extends StatelessWidget {
  const _ReelHead({
    required this.exercise,
    required this.ink,
    required this.spinFor,
    this.spinning = false,
  });

  /// Null while a slot the day didn't fill is spinning — its reels stop on
  /// `Skipped today` and a blank, so it turns exactly like the others and only
  /// gives itself away at the end.
  final RolledExercise? exercise;

  final Color ink;
  final Duration spinFor;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget name(String value) => Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SweatSpace.lg),
        child: Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(color: ink),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    Widget intensity(String value) => Center(
      child: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    // A slot that comes up empty stops on the words instead of a movement, and
    // on nothing at all in the intensity reel.
    final landsOnName = exercise?.name ?? _skippedLabel;
    final landsOnIntensity = exercise?.intensity ?? '';

    return Row(
      // Stretch so the divider runs the full height of the head, edge to edge,
      // the way a reel boundary would.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: spinning
              ? _Reel(
                  items: _reelItems(sampleNames, landsOnName, name),
                  height: _cardHeight,
                  // Stops a beat early, so the movement is read before its
                  // weight — the second beat is what makes it a machine rather
                  // than a reveal.
                  duration: spinFor - _reelStagger,
                )
              : name(landsOnName),
        ),
        const _ReelDivider(),
        SizedBox(
          width: _intensityWidth,
          child: spinning
              ? _Reel(
                  items: _reelItems(intensities, landsOnIntensity, intensity),
                  height: _cardHeight,
                  duration: spinFor,
                )
              : intensity(landsOnIntensity),
        ),
      ],
    );
  }
}

/// A slot with nothing in it — not rolled yet, or a pool this day didn't use.
///
/// A ghost keeps the reel division so the boundary doesn't appear out of
/// nowhere when the roll fills it. A skipped slot has no reels to spin, so it
/// carries no divider — it says so in words instead.
class _EmptyHead extends StatelessWidget {
  const _EmptyHead({required this.status, required this.ink});

  final SlotStatus status;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    if (status == SlotStatus.skipped) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SweatSpace.lg),
          child: Text(
            _skippedLabel,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: ink),
          ),
        ),
      );
    }

    return const Row(
      key: Key('ghost-head'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: SizedBox()),
        _ReelDivider(),
        SizedBox(width: _intensityWidth),
      ],
    );
  }
}

/// The body of the card being worked on.
///
/// **Every word of this is a placeholder and is marked as one.** VISION.md rule
/// 4 asks the app to teach — "help people learn more about what is and isn't
/// good and healthy" — which makes this real explanatory prose about a movement,
/// and that is the app owner's to write, not Claude's. What is being designed
/// here is where the explanation lives and how much room it needs; the copy is
/// deliberately obvious filler so it can never be mistaken for advice.
class _ExerciseDetail extends StatelessWidget {
  const _ExerciseDetail();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SweatSpace.lg,
        SweatSpace.lg,
        SweatSpace.lg,
        SweatSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reserved, not built. A demonstration still or loop goes here; the
          // box holds the space so the card's proportions are judged with it
          // rather than without.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.sweatColors.canvas,
                borderRadius: BorderRadius.circular(SweatRadius.chip),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Text('Image', style: context.sweatText.sectionLabel),
            ),
          ),
          const SizedBox(height: SweatSpace.lg),
          Text('How to', style: context.sweatText.sectionLabel),
          const SizedBox(height: SweatSpace.sm),
          Text(
            'Placeholder — the movement description has not been written. '
            'This block sizes the card for a short paragraph of real copy, '
            'which is the app owner’s to supply.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The spin
// ---------------------------------------------------------------------------

/// A strip of candidates that scrolls past and stops on the first one.
///
/// The value it lands on is decided before the widget is built — see
/// [RollSessionNotifier]. Nothing here chooses anything; the other entries are
/// blur frames and mean nothing, which is why they are allowed to repeat.
///
/// Items travel downward, the way a physical reel does, and decelerate into
/// place rather than stopping dead.
class _Reel extends StatefulWidget {
  const _Reel({
    required this.items,
    required this.height,
    this.duration = kSpinDuration,
  });

  /// Where it stops is [items] first; the rest go past on the way there.
  final List<Widget> items;

  final double height;
  final Duration duration;

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _spin;

  /// Total travel in pixels, a whole number of strip-lengths plus [_reelLead],
  /// so that whatever the spin's length it always finishes exactly on the
  /// landing item — and never starts on it.
  late final double _distance;

  /// The share of the run spent at full speed, before it starts settling.
  late final double _cruise;

  /// How fast the strip is moving right now, as a fraction of full speed.
  ///
  /// Constant while cruising, falling to zero as the reel settles — which is
  /// what makes the blur do the pointing. Every reel still turning is a smear;
  /// the one coming up next is the only one resolving into words.
  double get _speed {
    final t = _controller.value;
    if (t <= _cruise) return 1;
    return 1 - (t - _cruise) / (1 - _cruise);
  }

  @override
  void initState() {
    super.initState();

    final millis = widget.duration.inMilliseconds;
    final cruise = (1 - kReelTail.inMilliseconds / millis).clamp(0.0, 0.95);
    _cruise = cruise;

    // Enough travel that the blur runs at the same rate on every reel, however
    // long that reel happens to spin for.
    final wanted = _reelItemsPerSecond * (millis / 1000) * (1 + cruise) / 2;
    final laps = ((wanted - _reelLead) / widget.items.length).round().clamp(
      1,
      40,
    );
    _distance =
        (laps * widget.items.length + _reelLead) * widget.height;

    _controller = AnimationController(vsync: this, duration: widget.duration);
    _spin = CurvedAnimation(parent: _controller, curve: _ReelCurve(cruise));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lap = widget.items.length * widget.height;

    return ClipRect(
      child: SizedBox(
        height: widget.height,
        // The strip is many items long inside a one-item window, so it has to
        // be allowed to overflow its box vertically — and then be clipped back
        // to it. Width stays inherited, so a long movement name still
        // ellipsises against the reel's real width.
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final strip = Transform.translate(
                // Wrapped to one lap, so a short strip can turn for as long as
                // it likes. Remaining travel counts down to zero, which is the
                // landing item — the only frame that means anything.
                offset: Offset(0, -(((1 - _spin.value) * _distance) % lap)),
                child: child,
              );

              final blur = _reelBlur * _speed;
              if (blur < 0.2) return strip;

              // Vertical only: a reel smears along the direction it travels.
              // `decal` so the smear doesn't drag colour in from outside the
              // strip's own edges.
              return ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaY: blur,
                  tileMode: TileMode.decal,
                ),
                child: strip,
              );
            },
            // Twice round, so the window always has an item under it even at
            // the moment the strip wraps.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.items.length * 2; i++)
                  SizedBox(
                    height: widget.height,
                    child: widget.items[i % widget.items.length],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full speed, then a settle — the shape of a reel losing momentum.
///
/// Position runs linearly for [cruise] of the time, then decelerates to a stop
/// exactly on the landing item. The two halves are joined at matching speed, so
/// there is no kink where one becomes the other: covering `2k/(1+k)` of the
/// distance in the linear part is the value that makes the slopes agree.
@immutable
class _ReelCurve extends Curve {
  const _ReelCurve(this.cruise);

  /// Fraction of the run spent at full speed.
  final double cruise;

  @override
  double transformInternal(double t) {
    if (cruise <= 0) return 2 * t - t * t; // no room to cruise: all settle
    if (t <= cruise) return _linearDistance * t / cruise;

    final s = (t - cruise) / (1 - cruise);
    return _linearDistance + (1 - _linearDistance) * (2 * s - s * s);
  }

  double get _linearDistance => 2 * cruise / (1 + cruise);
}

/// How fast the blur runs, in items per second. The same on every reel, so a
/// reel that has been turning for three seconds looks no different from one
/// that has been turning for one.
const _reelItemsPerSecond = 14.0;

/// How far short of a whole number of laps a reel starts.
///
/// Without it the strip would begin and end on the same item, and every reel
/// would show its answer in its first frame before spinning away from it.
const _reelLead = 3;

/// How many symbols are on a reel.
const _reelFrames = 8;

/// Blur applied to a reel at full speed, in logical pixels.
///
/// Enough that a turning reel is unreadable. That is the point rather than a
/// side effect: five legible reels all cycling at once is five things asking
/// to be read, and the eye ends up nowhere. Blurred, the only reel resolving
/// into words is the one about to stop, so attention arrives there before the
/// value does.
const _reelBlur = 7.0;

/// How far ahead of its intensity a card's movement reel stops.
const _reelStagger = Duration(milliseconds: 180);

/// What a slot the day didn't fill says, spinning or landed.
const _skippedLabel = 'Skipped today';

/// Builds a reel's contents: [landing] first, then blur frames drawn from
/// [pool] by walking it, so they repeat when the pool is short — exactly as a
/// physical reel with few symbols would.
List<Widget> _reelItems<T>(
  List<T> pool,
  T landing,
  Widget Function(T) build, {
  int frames = _reelFrames,
}) {
  // A landing value that isn't in the pool — `Skipped today`, or the blank a
  // rest leaves when the slot after it isn't happening — just starts the walk
  // from the top.
  final start = pool.indexOf(landing).clamp(0, pool.length - 1);
  return [
    build(landing),
    for (var i = 1; i < frames; i++) build(pool[(start + i) % pool.length]),
  ];
}

/// The boundary between the two reels.
class _ReelDivider extends StatelessWidget {
  const _ReelDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('reel-divider'),
      width: 1,
      color: Theme.of(context).colorScheme.outline,
    );
  }
}

// ---------------------------------------------------------------------------
// Rest slots
// ---------------------------------------------------------------------------

/// The rest interval sitting between two exercises.
///
/// At rest — before and after it runs — it is deliberately subordinate to the
/// cards it separates: shorter than the touch-target floor, recessed rather
/// than raised, and inset horizontally so the eye groups it as a connector
/// rather than a peer. It carries no tap target, and that is what earns it the
/// right to be small; NEXT skips a rest, the bar itself is never pressed.
///
/// **While it runs it stops being a connector and becomes the thing you are
/// doing**, so it grows to card height, takes a cognac border, states the
/// remaining seconds in the metric face, and drains a track along its foot.
/// Nothing else on the screen looks like that. It is also what gets scrolled to
/// the top, so the growth costs no hunting.
///
/// The two sizes never coexist: only one rest can be live, and the layout
/// stability the ghost bar exists to protect is a property of the resting
/// states, where every bar is the small one.
class _RestSlot extends StatefulWidget {
  const _RestSlot({
    required this.status,
    required this.seconds,
    required this.anchor,
    required this.landsOn,
    required this.spinFor,
    super.key,
  });

  final RestStatus status;

  /// The interval this gap's reel is turning towards, or null when the slot
  /// after it isn't happening and the reel stops on nothing.
  final int? landsOn;

  /// How long this gap's reel turns for, if it is turning.
  final Duration spinFor;

  /// Only read while [status] is [RestStatus.active]; an idle bar always shows
  /// the full interval.
  final int seconds;

  /// This slot's scroll anchor, held by the screen for the session's lifetime.
  final GlobalKey anchor;

  @override
  State<_RestSlot> createState() => _RestSlotState();
}

class _RestSlotState extends State<_RestSlot>
    with SingleTickerProviderStateMixin {
  /// Drives the bar between connector height and focus height.
  ///
  /// Explicit rather than an [AnimatedSize], because an implicit animation only
  /// starts on the layout pass *after* the size changes — a frame behind the
  /// scroll that is chasing it. That one frame is the whole of the jitter as
  /// the bar arrives at the top: the scroll finishes, then the bar moves once
  /// more, then the scroll corrects. Driven directly, the two run off the same
  /// clock and land together.
  late final AnimationController _grow;
  late final Animation<double> _height;

  bool get _live => widget.status == RestStatus.active;

  @override
  void initState() {
    super.initState();
    _grow = AnimationController(
      vsync: this,
      duration: _settle,
      value: _live ? 1 : 0,
    );
    // Same two-phase shape as a card: come to the top first, then grow.
    _height = Tween<double>(begin: _restBarHeight, end: _cardHeight).animate(
      CurvedAnimation(
        parent: _grow,
        curve: const Interval(_openingBegins, 1, curve: Curves.easeInOutCubic),
      ),
    );
  }

  @override
  void didUpdateWidget(_RestSlot old) {
    super.didUpdateWidget(old);
    if (_live != (old.status == RestStatus.active)) {
      _live ? _grow.forward() : _grow.reverse();
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = widget.status;

    return Padding(
      padding: _restBarInset,
      child: KeyedSubtree(
        key: widget.anchor,
        child: AnimatedBuilder(
          animation: _height,
          builder: (context, child) => Container(
            height: _height.value,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: switch (status) {
                // A gap that isn't a rest holds its height and says nothing.
                RestStatus.ghost => null,
                RestStatus.spinning ||
                RestStatus.settling ||
                RestStatus.pending ||
                RestStatus.active => context.sweatColors.surfaceAlt,
                // Served: down the ramp, like the card above it.
                RestStatus.complete => scheme.surfaceContainerLow,
              },
              borderRadius: BorderRadius.circular(SweatRadius.chip),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SweatRadius.chip),
              border: switch (status) {
                RestStatus.ghost => Border.all(color: scheme.outline),
                // Cognac for the gap about to be filled in, and for the one
                // actually running — DESIGN.md's colour for the roll and for
                // active states. A gap merely turning is left unmarked.
                RestStatus.settling => Border.all(color: scheme.primary),
                RestStatus.active =>
                  Border.all(color: scheme.primary, width: 2),
                _ => null,
              },
            ),
            child: child,
          ),
          child: _live
              ? _LiveRest(seconds: widget.seconds)
              : _IdleRest(
                  status: status,
                  landsOn: widget.landsOn,
                  spinFor: widget.spinFor,
                ),
        ),
      ),
    );
  }
}

class _IdleRest extends StatelessWidget {
  const _IdleRest({
    required this.status,
    required this.landsOn,
    required this.spinFor,
  });

  final RestStatus status;
  final int? landsOn;
  final Duration spinFor;

  bool get _turning =>
      status == RestStatus.spinning || status == RestStatus.settling;

  @override
  Widget build(BuildContext context) {
    if (status == RestStatus.ghost) {
      return const SizedBox.shrink(key: Key('ghost-rest'));
    }

    final theme = Theme.of(context);

    // A null second is the blank a gap stops on when the slot after it isn't
    // happening — it turns like the rest of them and comes up empty.
    Widget label(int? seconds) => Center(
      child: Text(
        seconds == null ? '' : 'REST · ${seconds}s',
        style: context.sweatText.sectionLabel.copyWith(
          color: _turning
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (!_turning) return label(kRestSeconds);

    return _Reel(
      items: _reelItems<int?>(_restBlurFrames, landsOn, label),
      height: _restBarHeight,
      duration: spinFor,
    );
  }
}

class _LiveRest extends StatelessWidget {
  const _LiveRest({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'REST',
                style: context.sweatText.sectionLabel.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: SweatSpace.lg),
              // The metric styles carry tabular figures, so the number doesn't
              // jitter sideways as it counts down.
              MetricText('$seconds', unit: 's', small: true),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (seconds / kRestSeconds).clamp(0.0, 1.0),
            child: Container(
              key: const Key('rest-progress'),
              height: _restTrackHeight,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

/// Height of a slot's reel head. Fixed so a ghost, a skipped slot and a filled
/// card are exactly the same size — the reveal changes what's in the slot,
/// never where the slot is. An expanded card grows *below* this.
const _cardHeight = 72.0;

/// Width of the intensity reel. Fixed rather than sized to its text so the
/// divider lands at the same x on every card — see [_ReelHead].
const _intensityWidth = 104.0;

const _restBarHeight = 32.0;
const _restTrackHeight = 4.0;

/// What the rest reel shows on its way to [kRestSeconds].
///
/// Blur frames, not candidates. VISION.md says the interval is randomised but
/// leaves its range open, and nothing here is a proposal for what that range
/// should be — these are spaced around the landing value purely so the reel
/// reads as spinning. The only number that means anything is the one it stops
/// on, and that is a fixed placeholder too.
const _restBlurFrames = [kRestSeconds, 7, 13, 9, 16, 8, 12];

const _restBarInset = EdgeInsets.symmetric(
  horizontal: SweatSpace.xxl,
  vertical: SweatSpace.sm,
);

/// How long the layout takes to resolve after the session moves.
///
/// One value for every growth and shrink on the screen — and for the scroll
/// that follows them — so a card closing, a rest bar growing and the list
/// moving are all one gesture rather than three overlapping ones.
///
/// Long enough to read as a transition rather than a cut: at half this the
/// card's contents and the scroll both resolve inside a few frames, which
/// registers as a jump even though everything is technically animated.
/// DESIGN.md leaves the motion vocabulary undecided, so this stays a private
/// constant rather than a token until it is settled.
const _settle = Duration(milliseconds: 680);

/// How far below the top edge the slot being worked on comes to rest.
///
/// Not flush: a card hard against the top reads as cut off rather than placed,
/// and leaves nothing between it and the status bar.
const _focusInset = SweatSpace.lg;

/// The first half of a move: the list brings the next slot up to the top, and
/// whatever slot is finishing collapses out of the way.
const _travel = Duration(milliseconds: 380);

/// The second half: the slot that has arrived opens downward.
///
/// Deliberately after the travel rather than alongside it. Run together, the
/// list is still settling while the slot is already changing height beneath the
/// scroll that is chasing it, and the arrival stutters. Run in sequence, the
/// opening cannot disturb the top edge at all — it grows downward from a slot
/// that has already stopped moving.
///
/// Shorter than [_travel] on purpose, so a slot collapsing on the way out is
/// always finished before the list stops moving, and there is nothing left to
/// correct when it does.
///
/// Expressed as where it begins within [_settle] — 380ms of travel, then the
/// remaining 300ms opening — because that is the form [Interval] wants.
const _openingBegins = 380 / 680;
