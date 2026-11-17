import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Bidi;

/// The direction of user- or server-written [text] from its first strong
/// character, as HTML's `dir="auto"` does: Arabic first → RTL, Latin first
/// → LTR. Null when it has no strong character (only digits, dates,
/// punctuation), so the caller keeps the app's direction.
TextDirection? contentDirection(String text) {
  if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
  if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
  return null;
}

/// Lays [child] out in the direction of [text] (see [contentDirection]),
/// for widgets that read [Directionality] themselves. Only wrap a widget
/// that shows [text] alone: a row or icon inside would be mirrored too.
class ContentDirectionality extends StatelessWidget {
  const new({required this.text, required this.child, super.key});

  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final direction = contentDirection(text);
    if (direction == null || direction == Directionality.of(context)) {
      return child;
    }
    return Directionality(textDirection: direction, child: child);
  }
}

/// [Text] for content that comes from the server or another user (task
/// titles and descriptions, project and conversation names, messages,
/// notifications). It keeps its own direction inside the app's: an English
/// sentence in the Arabic UI reads left to right with its full stop at the
/// end (F9), while the screen around it stays RTL. Labels from the ARB
/// files use plain [Text].
class ContentText extends StatelessWidget {
  const new(
    this.data, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.semanticsLabel,
    super.key,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Resolved against the text's own direction; defaults to its start.
  final TextAlign? textAlign;
  final bool? softWrap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Text(
    data,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: semanticsLabel,
    textAlign: textAlign ?? TextAlign.start,
    textDirection: contentDirection(data) ?? Directionality.of(context),
  );
}
