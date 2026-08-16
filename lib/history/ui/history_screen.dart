import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ui/action_pill.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../data/session_record.dart';
import '../state/history_providers.dart';

/// What was and wasn't achieved, one session at a time.
///
/// ## Shape
///
/// A fixed calendar band on top, a swipeable session below it, and the action
/// pill at the bottom. The month follows the selection rather than being
/// steered on its own — there is exactly **one** axis of navigation, the
/// session, and swiping off the start of a month simply carries the grid back
/// with you. Two controls that both moved time would need explaining.
///
/// ## The calendar is a map, not a control
///
/// Its cells are not tappable. Seven columns inside the gutters leaves about
/// 47dp a cell, and [SweatSize.minTarget] is 56 — a grid you can tap is a grid
/// that asks for the precise press VISION.md says tired hands don't have. So
/// the grid says *where you are and what you've done*, and moving is the
/// swipe or the two large compartments at the bottom, both of which clear the
/// floor comfortably.
///
/// ## Chrome
///
/// No [AppBar]. Back is the left compartment of the pill, in the same place on
/// screen the roll screen's menu button occupies, so the thumb never learns a
/// second position.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final PageController _pages;

  /// Index into the oldest-first session list. Opens on the most recent.
  late int _selected;

  @override
  void initState() {
    super.initState();
    final count = ref.read(sessionHistoryProvider).length;
    _selected = count == 0 ? 0 : count - 1;
    _pages = PageController(initialPage: _selected);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Moves the selection, and lets the page animation move it back — so the
  /// buttons and the swipe end up in exactly the same place by the same route.
  void _goTo(int index) => _pages.animateToPage(
    index,
    duration: _pageTravel,
    curve: Curves.easeInOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionHistoryProvider);
    final byDay = ref.watch(sessionCalendarProvider);

    // Guard the index rather than the list: seeding history from the roll
    // screen can grow it underneath a screen that is already open.
    final selected = sessions.isEmpty
        ? null
        : sessions[_selected.clamp(0, sessions.length - 1)];

    final today = dayOf(DateTime.now());
    final month = selected?.day ?? today;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Keyed on the month, so a selection that stays inside one month
            // changes nothing here. One driver, fired discretely from
            // `onPageChanged` — interpolating the grid off the page controller's
            // continuous value would put a second animation in a race with the
            // swipe that started it.
            AnimatedSwitcher(
              duration: _monthTravel,
              child: _MonthGrid(
                key: ValueKey((month.year, month.month)),
                month: month,
                byDay: byDay,
                selected: selected?.day,
                today: today,
              ),
            ),
            Expanded(
              child: sessions.isEmpty
                  ? const _NothingYet()
                  : PageView.builder(
                      key: const Key('history-pages'),
                      controller: _pages,
                      itemCount: sessions.length,
                      onPageChanged: (index) =>
                          setState(() => _selected = index),
                      itemBuilder: (context, index) =>
                          _SessionPage(record: sessions[index]),
                    ),
            ),
            _HistoryActionRow(
              onBack: () => context.pop(),
              onPrev: _selected > 0 ? () => _goTo(_selected - 1) : null,
              onNext: _selected < sessions.length - 1
                  ? () => _goTo(_selected + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The calendar band
// ---------------------------------------------------------------------------

/// One month, read-only.
///
/// Always [_weekRows] rows tall, even for a month that fits in five. A band
/// that changed height between months would shove the session below it up and
/// down every time the swipe crossed a boundary.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selected,
    required this.today,
    super.key,
  });

  /// Any day in the month to draw.
  final DateTime month;

  final Map<DateTime, List<SessionRecord>> byDay;

  /// The day the selected session started on, if there is one.
  final DateTime? selected;

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = MaterialLocalizations.of(context);

    final first = DateTime(month.year, month.month);
    // Day zero of the next month is the last day of this one.
    final length = DateTime(month.year, month.month + 1, 0).day;

    // Both sides converted to a Sunday-first index before subtracting: Dart's
    // `weekday` is Monday-first, and the locale's start-of-week is not.
    final firstColumn = (first.weekday % 7 - l10n.firstDayOfWeekIndex + 7) % 7;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SweatSize.gutter,
        SweatSpace.lg,
        SweatSize.gutter,
        SweatSpace.md,
      ),
      child: Column(
        children: [
          Text(
            l10n.formatMonthYear(first),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: SweatSpace.sm),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.narrowWeekdays[(l10n.firstDayOfWeekIndex + i) % 7],
                      style: context.sweatText.sectionLabel,
                    ),
                  ),
                ),
            ],
          ),
          for (var week = 0; week < _weekRows; week++)
            SizedBox(
              height: _dayRowHeight,
              child: Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final dayOfMonth =
                              week * 7 + column - firstColumn + 1;
                          if (dayOfMonth < 1 || dayOfMonth > length) {
                            return const SizedBox.shrink();
                          }

                          final date = DateTime(
                            month.year,
                            month.month,
                            dayOfMonth,
                          );
                          final sessions = byDay[date];

                          return _DayCell(
                            dayOfMonth: dayOfMonth,
                            // One dot a day however many sessions it holds —
                            // the grid answers "did you train", and History
                            // pages through the rest.
                            worked: sessions != null && sessions.isNotEmpty,
                            complete:
                                sessions?.any((s) => s.isComplete) ?? false,
                            isSelected: date == selected,
                            isToday: date == today,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One day.
///
/// Cognac carries "a session happened"; champagne carries "this is the one
/// you're looking at", and appears exactly once on the screen. DESIGN.md is
/// explicit that champagne stops meaning "you won something" if it turns up
/// three times — and a month of twenty gold discs is precisely that failure, so
/// the reward colour marks the *selection*, not the achievement.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayOfMonth,
    required this.worked,
    required this.complete,
    required this.isSelected,
    required this.isToday,
  });

  final int dayOfMonth;

  /// A session was recorded on this day, whatever became of it.
  final bool worked;

  /// At least one of that day's sessions had nothing fall short. Note this is
  /// false for a day whose only session was abandoned, and **true** for a clean
  /// two-pool day — an unfilled third slot is the roll working, not a miss.
  final bool complete;

  final bool isSelected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sweat = context.sweatColors;

    final (Color? disc, Color ink) = switch ((worked, complete)) {
      (true, true) => (scheme.primary, scheme.onPrimary),
      (true, false) => (sweat.surfaceAlt, scheme.onSurface),
      _ => (null, scheme.onSurfaceVariant),
    };

    final ring = switch ((isSelected, isToday)) {
      (true, _) => BorderSide(color: sweat.champagne, width: 2),
      (false, true) => BorderSide(color: sweat.outlineStrong),
      _ => BorderSide.none,
    };

    return Center(
      child: Container(
        width: _dayDiscSize,
        height: _dayDiscSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disc,
          shape: BoxShape.circle,
          border: ring == BorderSide.none ? null : Border.fromBorderSide(ring),
        ),
        child: Text(
          '$dayOfMonth',
          style: theme.textTheme.bodySmall?.copyWith(
            color: ink,
            // Tabular, or a grid of 1s and 8s sits at visibly different widths.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One past session
// ---------------------------------------------------------------------------

/// A day, replayed in the roll screen's own grammar.
///
/// Same slot height, same fixed intensity column, same hairline — so a session
/// you are reading looks like the session you lived. It is a static widget
/// rather than a reuse of the roll screen's slot, which is a state machine
/// wrapped around three animation controllers for reels that will never spin
/// here.
class _SessionPage extends StatelessWidget {
  const _SessionPage({required this.record});

  final SessionRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = MaterialLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        SweatSize.gutter,
        0,
        SweatSize.gutter,
        SweatSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.formatMediumDate(record.day),
            style: theme.textTheme.headlineMedium,
          ),
          Text(
            record.outcome == SessionOutcome.finished
                ? 'Finished'
                : 'Left unfinished',
            style: context.sweatText.sectionLabel,
          ),
          const SizedBox(height: SweatSpace.lg),

          for (var i = 0; i < record.slotCount; i++) ...[
            if (i > 0)
              _RestGap(
                seconds: i < record.slots.length
                    ? record.slots[i].restBefore
                    : null,
              ),
            _HistorySlot(
              outcome: record.outcomeAt(i),
              slot: i < record.slots.length ? record.slots[i] : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// The gap the roll put between two movements. Silent when there was nothing on
/// the other side of it.
class _RestGap extends StatelessWidget {
  const _RestGap({required this.seconds});

  final int? seconds;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _restGapHeight,
      child: Center(
        child: Text(
          seconds == null ? '' : 'Rest $seconds s',
          style: context.sweatText.sectionLabel,
        ),
      ),
    );
  }
}

class _HistorySlot extends StatelessWidget {
  const _HistorySlot({required this.outcome, required this.slot});

  final SlotOutcome outcome;

  /// Null for a slot the roll never filled.
  final SlotRecord? slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Value, never shadow — DESIGN.md's second colour rule. A slot that fell
    // short recedes; one that was never rolled is a ghost, exactly as it is on
    // the roll screen, so it cannot be read as a miss.
    final (
      Color? fill,
      Color ink,
      IconData? mark,
      Color? markInk,
    ) = switch (outcome) {
      SlotOutcome.completed => (
        scheme.surface,
        scheme.onSurface,
        Icons.check,
        scheme.primary,
      ),
      SlotOutcome.skipped => (
        scheme.surfaceContainerLow,
        scheme.onSurfaceVariant,
        Icons.close,
        scheme.onSurfaceVariant,
      ),
      // Reached and under way when the session stopped. Neither a tick nor
      // a cross — the app genuinely does not know how it went.
      SlotOutcome.inProgress => (
        scheme.surfaceContainerLow,
        scheme.onSurfaceVariant,
        Icons.more_horiz,
        scheme.onSurfaceVariant,
      ),
      SlotOutcome.notReached ||
      SlotOutcome.notRolled ||
      SlotOutcome.unknown => (null, scheme.onSurfaceVariant, null, null),
    };

    final label = slot?.name ?? _emptyLabel(outcome);

    return Container(
      height: SweatSize.slot,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(SweatRadius.card),
      ),
      // Foreground, so a filled slot is not 2dp taller than a ghost one — the
      // same reason the roll screen paints its hairline over the child.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SweatRadius.card),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SweatSpace.lg),
              child: Row(
                children: [
                  if (mark != null) ...[
                    Icon(mark, size: 18, color: markInk),
                    const SizedBox(width: SweatSpace.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.titleLarge?.copyWith(color: ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: scheme.outline),
          SizedBox(
            width: SweatSize.intensityColumn,
            child: Center(
              child: Text(
                slot?.intensity ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What a slot with no movement in it says.
  ///
  /// The two are deliberately different sentences. *Not rolled* is the roll
  /// deciding on a two-pool day, which VISION.md asks for and which is not a
  /// shortfall; *not reached* is the session stopping early, which is.
  static String _emptyLabel(SlotOutcome outcome) => switch (outcome) {
    SlotOutcome.notRolled => 'Not rolled',
    SlotOutcome.notReached => 'Not reached',
    _ => 'Not recorded',
  };
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

/// Back, and the two big steps through history.
///
/// The same pill as the roll screen, and deliberately **not** cognac. DESIGN.md
/// reserves the brand fill for the roll and for active states; three cognac
/// compartments on a screen that contains no action would spend the colour that
/// makes the roll screen's one button mean something. Graphite with an
/// [SweatColors.outlineStrong] hairline keeps the silhouette and gives the
/// colour back.
class _HistoryActionRow extends StatelessWidget {
  const _HistoryActionRow({
    required this.onBack,
    required this.onPrev,
    required this.onNext,
  });

  final VoidCallback onBack;

  /// Null at the ends of history. The compartment dims and stops responding —
  /// a live-looking control that does nothing is worse than one that says so.
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sweat = context.sweatColors;

    return ActionPill(
      fill: sweat.surfaceAlt,
      ink: scheme.onSurface,
      border: sweat.outlineStrong,
      // The same machined groove, one step down the graphite ramp: the cut,
      // then the light catching its far wall.
      seamCut: scheme.surfaceContainerLowest,
      seamLight: sweat.outlineStrong,
      compartments: [
        PillAction(
          actionKey: const Key('history-back'),
          onTap: onBack,
          child: const Icon(Icons.arrow_back),
        ),
        PillAction(
          actionKey: const Key('history-prev'),
          flex: 2,
          onTap: onPrev,
          ink: onPrev == null ? scheme.onSurfaceVariant : null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(Icons.chevron_left), Text('PREV')],
          ),
        ),
        PillAction(
          actionKey: const Key('history-next'),
          flex: 2,
          onTap: onNext,
          ink: onNext == null ? scheme.onSurfaceVariant : null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text('NEXT'), Icon(Icons.chevron_right)],
          ),
        ),
      ],
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SweatSize.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No sessions yet'.toUpperCase(),
              style: context.sweatText.sectionLabel,
            ),
            const SizedBox(height: SweatSpace.md),
            Text(
              'Roll a day and walk it through. It lands here when it ends, '
              'finished or not.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Measurements
// ---------------------------------------------------------------------------

/// Always six, so the band is the same height in every month. February in a
/// common year starting on the first day of the week needs four; drawing four
/// would move everything below it.
const _weekRows = 6;

const _dayRowHeight = 36.0;

/// Comfortably inside [_dayRowHeight] and the ~47dp a column gets, so the
/// selection ring never touches its neighbours.
const _dayDiscSize = 30.0;

/// Stands in for the roll screen's rest bar. It only has to separate two slots
/// and name the interval; nothing here is counting down.
const _restGapHeight = 32.0;

/// Long enough to read as travel between two days rather than a cut, short
/// enough that holding the button steps briskly.
const _pageTravel = Duration(milliseconds: 280);

/// Slower than the page: the month is the context changing underneath, and it
/// should settle after the thing that caused it.
const _monthTravel = Duration(milliseconds: 380);
