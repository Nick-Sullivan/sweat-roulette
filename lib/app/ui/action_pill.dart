import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// One compartment of an [ActionPill].
@immutable
class PillAction {
  const PillAction({
    required this.child,
    this.onTap,
    this.flex = 1,
    this.actionKey,
    this.ink,
  });

  final Widget child;

  /// Null disables the compartment: it stops responding and takes no ripple.
  /// Dim [ink] to match — a live-looking control that does nothing is worse
  /// than one that says so.
  final VoidCallback? onTap;

  /// Share of the pill's width. The roll screen's navigation is 1 against the
  /// action's 4; History's three compartments are 1, 2, 2.
  final int flex;

  /// The key the tap target carries, so tests can find it.
  final Key? actionKey;

  /// Overrides [ActionPill.ink] for this compartment alone.
  final Color? ink;
}

/// The app's one fixed control: a long stadium pill, divided into compartments
/// by a machined seam.
///
/// Shared rather than duplicated because the seam is the fiddly part and there
/// must only be one of it. The roll screen is `[menu | ACTION]`; History is
/// `[back | PREV | NEXT]`. One silhouette, in the same place on screen, so a
/// thumb never has to learn a second position — which is the whole point of
/// VISION.md's tired-hands rule.
///
/// It carries its own padding: a pill inset differently on two screens would
/// move between them, and moving is exactly what it must not do.
class ActionPill extends StatelessWidget {
  const ActionPill({
    required this.compartments,
    this.fill,
    this.ink,
    this.seamCut,
    this.seamLight,
    this.border,
    super.key,
  });

  final List<PillAction> compartments;

  /// Defaults to the brand fill — the roll action. History passes a graphite
  /// surface instead: DESIGN.md reserves cognac for the roll and active states,
  /// and a navigation bar in full brand would put three of it on a screen that
  /// contains no action at all.
  final Color? fill;

  final Color? ink;

  /// The two halves of the seam: the cut, and the light catching its far wall.
  /// Default to the cognac pairing, so the roll screen is unchanged.
  final Color? seamCut;
  final Color? seamLight;

  /// A hairline around the pill. Unnecessary on a brand fill, which separates
  /// itself; needed on a graphite one, which otherwise dissolves into the
  /// canvas.
  final Color? border;

  /// The label treatment inside a compartment. Chivo rather than the Bebas of
  /// `labelLarge`: wide tracking on a caps-only face at this size closes up the
  /// counters, and this text has to read at a glance mid-set.
  static TextStyle labelStyle(BuildContext context, Color ink) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
        color: ink,
        letterSpacing: 4.0,
        fontWeight: FontWeight.w700,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final surface = fill ?? scheme.primary;
    final foreground = ink ?? scheme.onPrimary;
    final cut = seamCut ?? scheme.inversePrimary;
    final light = seamLight ?? scheme.onPrimaryContainer;

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
          color: surface,
          shape: const StadiumBorder(),
        ),
        // The hairline goes in the *foreground*, because a border on the
        // background decoration also insets the child by its width — which
        // would make an outlined pill's compartments 2dp shorter than a filled
        // pill's, and the one fixed control on two screens has to be the same
        // height on both. Same reason the roll screen's cards paint theirs over
        // the child.
        foregroundDecoration: border == null
            ? null
            : ShapeDecoration(
                shape: StadiumBorder(side: BorderSide(color: border!)),
              ),
        child: Material(
          type: MaterialType.transparency,
          child: Row(
            // Stretch so every compartment — and the seams between them — run
            // the full height of the pill.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < compartments.length; i++) ...[
                if (i > 0) _ActionSeam(cut: cut, light: light),
                Expanded(
                  flex: compartments[i].flex,
                  child: _Compartment(
                    action: compartments[i],
                    ink: compartments[i].ink ?? foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Compartment extends StatelessWidget {
  const _Compartment({required this.action, required this.ink});

  final PillAction action;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: action.actionKey,
      onTap: action.onTap,
      child: Center(
        child: IconTheme(
          data: IconThemeData(color: ink),
          child: DefaultTextStyle(
            style: ActionPill.labelStyle(context, ink),
            child: action.child,
          ),
        ),
      ),
    );
  }
}

/// The join between two compartments.
///
/// Not a drawn line but a machined one: a dark groove with a lit edge beside
/// it, the way a seam in a solid object catches light. That reads as one piece
/// of metal parted rather than two shapes butted together — DESIGN.md's
/// restrained-luxury direction, a watch bezel rather than a border.
///
/// Runs edge to edge and stays only as wide as itself, so pressing either side
/// fills its colour right up to the seam with no dead strip beside it. It also
/// swells through the middle and eases off at the ends, which is what stops
/// three flat pixels from reading as a rule someone forgot to remove.
///
/// The cost is DESIGN.md's 12dp gap between adjacent targets: the compartments
/// are a hair apart, so a tap by the seam can land on either. What guards it
/// instead is distance — a seam sits at a fifth of the width or at a third,
/// nowhere near where a thumb aims.
class _ActionSeam extends StatelessWidget {
  const _ActionSeam({required this.cut, required this.light});

  final Color cut;
  final Color light;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 3,
      child: Row(
        // Stretch, or the two edges size to their own content — which is
        // nothing — and the seam disappears entirely.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The cut, then the light catching its far wall.
          Expanded(child: _SeamEdge(cut)),
          Expanded(child: _SeamEdge(light)),
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
