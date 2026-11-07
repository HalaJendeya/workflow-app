import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';

/// Long-press-and-drag pieces shared by the demo and API sprint boards.
///
/// The phone board (Figma 729:24447) shows one status column at a time
/// behind the "Status tabs", so a card is dropped on a status rather than
/// on a side-by-side column: the page's status tabs accept drops, and
/// while a card is held a [KanbanDropBar] pinned to the top of the screen
/// lists every status the card may move to, so no target is ever off
/// screen and no horizontal scrolling is needed. A normal swipe still
/// scrolls the page; only a long press picks a card up.

/// A card that can be picked up with a long press. When [enabled] is false
/// (no permission, or a move already pending) it is a plain card.
class KanbanDraggable<T extends Object> extends StatelessWidget {
  const new({
    required this.data,
    required this.child,
    required this.onDragStarted,
    required this.onDragEnd,
    this.enabled = true,
    super.key,
  });

  final T data;
  final Widget child;
  final bool enabled;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return LayoutBuilder(
      builder: (context, constraints) => LongPressDraggable<T>(
        data: data,
        // In the root overlay, so the lifted card is drawn above the floating
        // navigation surface and the drop bar.
        rootOverlay: true,
        // The card hangs below the finger, so the status under the finger
        // stays visible while aiming.
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: onDragStarted,
        onDragEnd: (_) => onDragEnd(),
        feedback: Transform.translate(
          offset: Offset(-constraints.maxWidth * 0.85 / 2, 24),
          child: Transform.rotate(
            angle: 0.02,
            child: SizedBox(
              width: constraints.maxWidth * 0.85,
              child: Opacity(
                opacity: 0.95,
                child: Material(
                  key: const Key('kanban-drag-feedback'),
                  color: Colors.transparent,
                  elevation: 8,
                  shadowColor: AppColors.primary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: child),
        child: child,
      ),
    );
  }
}

/// Wraps [builder]'s widget in a drop target for [status]. [accepts] says
/// whether the held card may move there; `hovering` is true while an
/// acceptable card is over it.
class KanbanDropTarget<T extends Object, S> extends StatelessWidget {
  const new({
    required this.status,
    required this.accepts,
    required this.onDrop,
    required this.builder,
    super.key,
  });

  final S status;
  final bool Function(T data, S status) accepts;
  final void Function(T data, S status) onDrop;
  final Widget Function(BuildContext context, {required bool hovering}) builder;

  @override
  Widget build(BuildContext context) => DragTarget<T>(
    onWillAcceptWithDetails: (d) => accepts(d.data, status),
    onAcceptWithDetails: (d) => onDrop(d.data, status),
    builder: (context, candidates, _) =>
        builder(context, hovering: candidates.isNotEmpty),
  );
}

/// The statuses a held card can be dropped on, pinned under the status bar
/// in the style of the Figma status tabs. The card's own status is shown
/// but disabled; every other allowed status is outlined, and the one under
/// the finger is filled.
class KanbanDropBar<T extends Object, S> extends StatelessWidget {
  const new({
    required this.title,
    required this.statuses,
    required this.labelOf,
    required this.held,
    required this.accepts,
    required this.onDrop,
    super.key,
  });

  final String title;
  final List<S> statuses;
  final String Function(S) labelOf;
  final T held;
  final bool Function(T data, S status) accepts;
  final void Function(T data, S status) onDrop;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: top + 8,
      left: 20,
      right: 20,
      child: Material(
        key: const Key('kanban-drop-bar'),
        color: AppColors.white,
        elevation: 6,
        shadowColor: AppColors.navShadow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(3, 8, 3, 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 9, bottom: 6),
                child: Text(
                  title,
                  style: AppTextStyles.mobileXsSemiBold.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Five targets fit one row on wide phones; narrower ones use
              // rows of three so no status name breaks inside a word.
              LayoutBuilder(
                builder: (context, c) {
                  final perRow = c.maxWidth >= 5 * 96 ? 5 : 3;
                  final w = c.maxWidth / perRow;
                  return Wrap(
                    runSpacing: 4,
                    children: [
                      for (final s in statuses)
                        SizedBox(
                          width: w,
                          child: KanbanDropTarget<T, S>(
                            key: Key('drop-${s is Enum ? s.name : s}'),
                            status: s,
                            accepts: accepts,
                            onDrop: onDrop,
                            builder: (context, {required hovering}) => _Tile(
                              label: labelOf(s),
                              enabled: accepts(held, s),
                              hovering: hovering,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const new({
    required this.label,
    required this.enabled,
    required this.hovering,
  });

  final String label;
  final bool enabled;
  final bool hovering;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 120),
    height: 44,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: hovering ? AppColors.primary : AppColors.primary50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: enabled ? AppColors.primary : AppColors.borderSubtle,
        width: hovering ? 2 : 1,
      ),
    ),
    child: Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.mobileXsMedium.copyWith(
          height: 1.2,
          color: hovering ? AppColors.white : AppColors.primaryStrong,
        ),
      ),
    ),
  );
}

/// Shows and hides a [KanbanDropBar] in the root overlay while a card is
/// held. Mixed into the board's state.
mixin KanbanDropBarHost<W extends StatefulWidget> on State<W> {
  OverlayEntry? _bar;

  void showDropBar(WidgetBuilder bar) {
    hideDropBar();
    final entry = OverlayEntry(builder: bar);
    _bar = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void hideDropBar() {
    _bar?.remove();
    _bar?.dispose();
    _bar = null;
  }

  @override
  void dispose() {
    hideDropBar();
    super.dispose();
  }
}
