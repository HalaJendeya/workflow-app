import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Date windows offered by the "Last 30 days ⌄" chip.
enum DateRange { last30, last90, thisYear, all }

extension DateRangeX on DateRange {
  /// First day of the range, for server-side `from` filters; null = no bound.
  DateTime? start(DateTime now) => switch (this) {
    DateRange.last30 => DateTime(now.year, now.month, now.day - 30),
    DateRange.last90 => DateTime(now.year, now.month, now.day - 90),
    DateRange.thisYear => DateTime(now.year),
    DateRange.all => null,
  };

  bool contains(DateTime d, DateTime now) => switch (this) {
    DateRange.last30 => now.difference(d).inDays <= 30,
    DateRange.last90 => now.difference(d).inDays <= 90,
    DateRange.thisYear => d.year == now.year,
    DateRange.all => true,
  };

  String label(AppLocalizations l10n) => switch (this) {
    DateRange.last30 => l10n.rangeLast30,
    DateRange.last90 => l10n.rangeLast90,
    DateRange.thisYear => l10n.rangeThisYear,
    DateRange.all => l10n.rangeAll,
  };
}

/// Formats [v] in [currency]. An API row whose currency the response does
/// not name passes `symbol: ''`, so no currency is guessed.
String money(double v, {String currency = 'USD', String? symbol}) =>
    NumberFormat.currency(
      locale: 'en',
      name: currency,
      symbol:
          symbol ??
          switch (currency) {
            'EUR' => '€',
            'ILS' => '₪',
            'USD' => r'$',
            _ => '$currency ',
          },
      decimalDigits: v == v.roundToDouble() ? 0 : 2,
    ).format(v).trim();

String count(int v) => NumberFormat.decimalPattern('en').format(v);

/// "↓ Export Report" chip. Exports need the backend, so it explains that.
class ExportReportChip extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FilterChipBox(
      label: '↓ ${AppLocalizations.of(context).exportReport}',
      onTap: () =>
          showSnack(context, AppLocalizations.of(context).exportPending),
    ),
  );
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Reports a `LocalCollection` mutation honestly: the demo message when it
/// was applied on the device, otherwise that nothing was saved because the
/// action has no verified server endpoint.
void showLocalOutcome(
  BuildContext context, {
  required bool applied,
  bool deleted = false,
}) {
  final l10n = AppLocalizations.of(context);
  showSnack(
    context,
    !applied
        ? l10n.actionNeedsBackend
        : deleted
        ? l10n.deletedLocally
        : l10n.savedLocally,
  );
}

/// Read-only detail sheet opened by "View Details".
Future<void> showRecordDetails(
  BuildContext context, {
  required String title,
  required String status,
  required BadgeTone tone,
  required List<DetailField> fields,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.mobileXlSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              StatusBadge(label: status, tone: tone),
            ],
          ),
          const SizedBox(height: 16),
          for (final f in fields)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      f.label,
                      style: AppTextStyles.mobileBaseRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      f.value,
                      style: AppTextStyles.mobileBaseSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  ),
);
