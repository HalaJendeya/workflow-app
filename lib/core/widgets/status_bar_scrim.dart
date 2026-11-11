import 'package:flutter/material.dart';

/// Keeps scrolled content from passing under the transparent status bar.
///
/// Above [child]'s vertical scrollable it paints a [color] strip as tall as
/// the top safe area once that scrollable leaves its start, so a masthead
/// drawn behind the status bar (an image, a gradient) is unchanged at rest.
class StatusBarScrim extends StatefulWidget {
  const new({required this.color, required this.child, super.key});

  final Color color;
  final Widget child;

  @override
  State<StatusBarScrim> createState() => _StatusBarScrimState();
}

class _StatusBarScrimState extends State<StatusBarScrim> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    // Only the page's own vertical scrollable, not nested chip rows.
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final scrolled = n.metrics.pixels > n.metrics.minScrollExtent;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
      PositionedDirectional(
        top: 0,
        start: 0,
        end: 0,
        height: MediaQuery.paddingOf(context).top,
        child: IgnorePointer(
          child: AnimatedOpacity(
            key: const Key('status-bar-scrim'),
            opacity: _scrolled ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: ColoredBox(color: widget.color),
          ),
        ),
      ),
    ],
  );
}
