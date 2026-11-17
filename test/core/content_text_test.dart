import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/widgets/content_text.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

import '../helpers/viewport.dart';

/// F9, found on the Redmi 8 (2026-11-17): in the Arabic UI an English
/// notification from the server was laid out RTL, so its full stop and
/// quotes moved to the wrong end (`."… in "Team`). Server text now keeps
/// its own direction while the app stays RTL.

const _english = 'You were assigned to "Login page" in "Team".';
const _arabic = 'تم تعيينك في مهمة جديدة.';
const _arabicThenEnglish = 'تمت إضافة "Login page" إلى المشروع.';
const _englishThenArabic = 'Review مراجعة the design.';

void main() {
  group('contentDirection (first strong character)', () {
    test('Arabic is RTL, English is LTR', () {
      expect(contentDirection(_arabic), TextDirection.rtl);
      expect(contentDirection(_english), TextDirection.ltr);
    });

    test('mixed text follows its first word', () {
      expect(contentDirection(_arabicThenEnglish), TextDirection.rtl);
      expect(contentDirection(_englishThenArabic), TextDirection.ltr);
      // Leading punctuation and digits are neutral.
      expect(contentDirection('«مرحبا» team'), TextDirection.rtl);
      expect(contentDirection('#13 — Fix login'), TextDirection.ltr);
    });

    test('dates and numbers keep the app direction', () {
      expect(contentDirection('2026/11/17'), isNull);
      expect(contentDirection('160.0'), isNull);
      expect(contentDirection('—'), isNull);
      expect(contentDirection(''), isNull);
    });

    test('an email address is LTR', () {
      expect(contentDirection('qa.user@example.test'), TextDirection.ltr);
    });
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    useViewport(tester, const Size(390, 844));
    await loadAppFonts();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [child]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  RenderParagraph paragraph(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(text), matching: find.byType(RichText)),
      );

  /// Left edge of the glyph at [index] (first box), in global coordinates.
  double glyphLeft(RenderParagraph p, int index) {
    final box = p
        .getBoxesForSelection(
          TextSelection(baseOffset: index, extentOffset: index + 1),
        )
        .first;
    return p.localToGlobal(Offset(box.left, 0)).dx;
  }

  testWidgets('English in the Arabic UI reads LTR with the full stop last', (
    tester,
  ) async {
    await pump(tester, const ContentText(_english));
    final p = paragraph(tester, _english);
    expect(p.textDirection, TextDirection.ltr);
    // "Y" is on the left and the closing full stop on the right.
    expect(glyphLeft(p, 0), lessThan(glyphLeft(p, _english.length - 1)));
    // Left-aligned in its own direction.
    expect(p.localToGlobal(Offset.zero).dx, closeTo(16, 1));
  });

  testWidgets('Arabic stays RTL with the full stop on the left', (
    tester,
  ) async {
    await pump(tester, const ContentText(_arabic));
    final p = paragraph(tester, _arabic);
    expect(p.textDirection, TextDirection.rtl);
    expect(glyphLeft(p, 0), greaterThan(glyphLeft(p, _arabic.length - 1)));
  });

  testWidgets('Arabic with an English phrase stays RTL', (tester) async {
    await pump(tester, const ContentText(_arabicThenEnglish));
    final p = paragraph(tester, _arabicThenEnglish);
    expect(p.textDirection, TextDirection.rtl);
    const end = _arabicThenEnglish.length - 1;
    expect(glyphLeft(p, 0), greaterThan(glyphLeft(p, end)));
  });

  testWidgets('a date keeps the app direction', (tester) async {
    await pump(tester, const ContentText('2026/11/17'));
    expect(paragraph(tester, '2026/11/17').textDirection, TextDirection.rtl);
  });

  testWidgets('long English text wraps and is announced as written', (
    tester,
  ) async {
    final long = List.filled(12, 'Review the design.').join(' ');
    await pump(tester, ContentText(long, maxLines: 3));
    final p = paragraph(tester, long);
    expect(p.textDirection, TextDirection.ltr);
    expect(p.size.height, greaterThan(p.preferredLineHeight * 2));
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(long), findsOneWidget);
  });

  testWidgets('a task card keeps the RTL layout around an English title', (
    tester,
  ) async {
    await pump(
      tester,
      TaskCard(
        title: 'Fix login page.',
        description: 'Check the "Remember me" box.',
        status: const StatusBadge(
          key: Key('status'),
          label: 'قيد التنفيذ',
          tone: BadgeTone.info,
        ),
        onOpen: () {},
      ),
    );
    expect(
      paragraph(tester, 'Fix login page.').textDirection,
      TextDirection.ltr,
    );
    expect(
      paragraph(tester, 'Check the "Remember me" box.').textDirection,
      TextDirection.ltr,
    );
    // The card itself is still mirrored: the badge sits on the left.
    final badge = tester.getRect(find.byKey(const Key('status')));
    final title = tester.getRect(find.text('Fix login page.'));
    expect(badge.right, lessThanOrEqualTo(title.left));
    expect(
      Directionality.of(tester.element(find.byKey(const Key('status')))),
      TextDirection.rtl,
    );
  });

  testWidgets('a record card title follows its own direction', (tester) async {
    await pump(
      tester,
      RecordCard(
        reference: '#2',
        title: 'Mobile app.',
        subtitle: 'مشروع تجريبي.',
        status: '',
        tone: BadgeTone.neutral,
        fields: const [],
        onView: () {},
      ),
    );
    expect(paragraph(tester, 'مشروع تجريبي.').textDirection, TextDirection.rtl);
    final title = tester.renderObjectList<RenderParagraph>(
      find.descendant(
        of: find.byType(RecordCard),
        matching: find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Mobile'),
        ),
      ),
    );
    expect(title, isNotEmpty);
    expect(title.map((p) => p.textDirection), everyElement(TextDirection.ltr));
  });
}
