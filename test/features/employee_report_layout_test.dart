import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/features/reports/presentation/employee_report_screen.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/viewport.dart';
import 'employee_completion_test.dart' show pumpEmployeeScreen;
import 'employee_report_test.dart' show reportJson;

/// My report's period controls (owner review, 2026-11-19): previous, the
/// period, Month/Year and next share one card, so the first figure comes
/// earlier. Before this the chips and the stepper were two blocks taking
/// 129 dp (134 dp at 130 % text) above the figures. Mocked HTTP.

const _key = Key('report-period-controls');

Future<void> _pump(
  WidgetTester tester,
  Size size,
  double scale,
  String lang,
) async {
  await loadAppFonts();
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpEmployeeScreen(
    tester,
    const EmployeeReportScreen(),
    handlers: {'GET /api/v1/employee/report': (_) => (200, ok(reportJson()))},
    size: size,
    locale: Locale(lang),
  );
}

/// Height from the top of the controls to the first figure.
double _controlsBlock(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const Key('report-summary'))).dy -
    tester.getTopLeft(find.byKey(_key)).dy;

bool _onOneLine(WidgetTester tester) =>
    (tester.getCenter(find.byKey(const Key('report-period'))).dy -
            tester.getCenter(find.byKey(const Key('report-span-month'))).dy)
        .abs() <
    4;

String _period(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('report-period'))).data!;

void main() {
  final cases = <(Size, double, String, bool, double)>[
    // size, text scale, language, one line expected, max block height
    (const Size(411, 914), 1, 'en', true, 80),
    (const Size(360, 740), 1, 'en', true, 80),
    (const Size(360, 740), 1, 'ar', true, 80),
    (const Size(320, 640), 1, 'en', false, 100),
    (const Size(320, 640), 1.3, 'en', false, 110),
    (const Size(320, 640), 1.3, 'ar', false, 110),
  ];

  for (final (size, scale, lang, oneLine, maxBlock) in cases) {
    final name = '$lang ${size.width.toInt()} dp x$scale';

    testWidgets('$name: compact, nothing clipped or covered', (tester) async {
      await _pump(tester, size, scale, lang);
      expect(tester.takeException(), isNull);

      expect(_controlsBlock(tester), lessThanOrEqualTo(maxBlock));
      expect(_onOneLine(tester), oneLine);

      // Every control sits inside the card and on screen, at full size.
      final card = tester.getRect(find.byKey(_key));
      for (final k in [
        'report-previous',
        'report-next',
        'report-period',
        'report-span-month',
        'report-span-year',
      ]) {
        final r = tester.getRect(find.byKey(Key(k)));
        expect(
          card.contains(r.topLeft) && card.contains(r.bottomRight),
          isTrue,
          reason: '$k $r is outside the card $card',
        );
        expect(r.right, lessThanOrEqualTo(size.width), reason: k);
      }
      // The arrows keep a 48 dp touch target.
      expect(
        tester.getSize(find.byKey(const Key('report-previous'))).width,
        greaterThanOrEqualTo(48),
      );
      // The period is never cut or squeezed onto a second line.
      final label = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const Key('report-period')),
          matching: find.byType(RichText),
        ),
      );
      expect(label.didExceedMaxLines, isFalse);
      expect(
        label.size.width,
        greaterThanOrEqualTo(label.getMaxIntrinsicWidth(double.infinity) - 1),
      );
      for (final k in ['report-span-month', 'report-span-year']) {
        final chip = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(Key(k)),
            matching: find.byType(RichText),
          ),
        );
        expect(
          chip.size.width,
          greaterThanOrEqualTo(chip.getMaxIntrinsicWidth(double.infinity) - 1),
          reason: k,
        );
      }
    });
  }

  testWidgets('Arabic: previous at the reading start (right)', (tester) async {
    await _pump(tester, const Size(320, 640), 1.3, 'ar');
    expect(
      tester.getCenter(find.byKey(const Key('report-previous'))).dx,
      greaterThan(tester.getCenter(find.byKey(const Key('report-next'))).dx),
    );
  });

  testWidgets('month and year still work in the compact card', (tester) async {
    await _pump(tester, const Size(320, 640), 1.3, 'en');
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    // Short on screen, the full month for screen readers.
    expect(_period(tester), DateFormat.yMMM('en').format(month));
    expect(
      find.bySemanticsLabel(DateFormat.yMMMM('en').format(month)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('report-previous')));
    await tester.pumpAndSettle();
    expect(
      _period(tester),
      DateFormat.yMMM('en').format(DateTime(now.year, now.month - 1)),
    );
    await tester.tap(find.byKey(const Key('report-span-year')));
    await tester.pumpAndSettle();
    final year = DateTime(now.year, now.month - 1).year;
    expect(_period(tester), '$year');
    expect(tester.takeException(), isNull);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('$lang 320 dp x1.3: a custom range label fits the card', (
      tester,
    ) async {
      await _pump(tester, const Size(320, 640), 1.3, lang);
      await tester.tap(find.byKey(const Key('report-choose-dates')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'picker open');
      // The picker's confirm button (Save / its Arabic label).
      final picker = tester.element(find.byType(DateRangePickerDialog));
      await tester.tap(
        find.text(MaterialLocalizations.of(picker).saveButtonLabel),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_period(tester), contains(' – '));
      final card = tester.getRect(find.byKey(_key));
      final label = tester.getRect(find.byKey(const Key('report-period')));
      expect(card.left <= label.left && label.right <= card.right, isTrue);
      final text = tester.renderObject<RenderParagraph>(
        find.byKey(const Key('report-period')),
      );
      expect(text.didExceedMaxLines, isFalse);
    });
  }
}
