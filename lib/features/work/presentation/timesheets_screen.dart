import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/export_csv_chip.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/data/employee_exports.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/features/work/presentation/api_timesheets.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

String timesheetStatusLabel(AppLocalizations l10n, TimesheetStatus s) =>
    switch (s) {
      TimesheetStatus.approved => l10n.approved,
      TimesheetStatus.pending => l10n.statusPending,
      TimesheetStatus.rejected => l10n.rejected,
    };

BadgeTone timesheetTone(TimesheetStatus s) => switch (s) {
  TimesheetStatus.approved => BadgeTone.success,
  TimesheetStatus.pending => BadgeTone.warning,
  TimesheetStatus.rejected => BadgeTone.danger,
};

/// Figma "Timesheets Dashboard" (729:37832).
class TimesheetsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TimesheetsScreen> createState() => _TimesheetsScreenState();
}

class _TimesheetsScreenState extends ConsumerState<TimesheetsScreen> {
  static const _pageSize = 5;
  String _query = '';
  TimesheetStatus? _status;
  DateTime? _month;

  /// API mode: `month` filter as YYYY-MM (from `available_months`).
  String? _apiMonth;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demo = ref.watch(demoModeProvider);
    final all = ref.watch(timesheetsProvider);
    final q = _query.trim().toLowerCase();
    final filtered = all.where((e) {
      if (_status != null && e.status != _status) return false;
      if (_month case final m?
          when e.start.year != m.year || e.start.month != m.month) {
        return false;
      }
      return q.isEmpty ||
          '${e.task} ${e.project} ${e.employee}'.toLowerCase().contains(q);
    }).toList();
    final page = _page.clamp(
      0,
      ((filtered.length - 1) ~/ _pageSize).clamp(0, 999),
    );
    final visible = filtered.skip(page * _pageSize).take(_pageSize).toList();
    int n(TimesheetStatus s) => all.where((e) => e.status == s).length;
    final hours = all.fold<int>(0, (s, e) => s + e.duration.inMinutes) / 60;
    final salaries = all
        .where((e) => e.status == TimesheetStatus.approved)
        .fold<double>(0, (s, e) => s + e.amount);
    final months = {
      for (final e in all) DateTime(e.start.year, e.start.month),
    }.toList()..sort((a, b) => b.compareTo(a));
    final monthLabel = DateFormat('MMM yyyy').format;
    // API mode: `stats` and per-currency `totals` of GET /employee/timesheets.
    final api = demo ? null : ref.watch(employeeTimesheetSummaryProvider);
    final sum = api?.value;
    String apiMoney(TimesheetSummary s) => s.money.isEmpty
        ? '0'
        : s.money
              // "Total salaries" is `totals[].total` (every status), not
              // `approved` (root-cause audit B, 2026-11-19).
              .map((m) => money(m.total, currency: m.code, symbol: m.symbol))
              .join(' · ');

    return ModulePage(
      title: l10n.timesheetsTitle,
      description: l10n.timesheetsBody,
      // API mode lists only the employee's own timesheets (one per month),
      // so a text search adds nothing beyond the status and month filters.
      onSearch: demo
          ? (v) => setState(() {
              _query = v;
              _page = 0;
            })
          : null,
      children: [
        if (api case AsyncError(:final error))
          ApiErrorCard(
            error: error,
            onRetry: () => ref.invalidate(employeeTimesheetSummaryProvider),
          ),
        MetricGroup(
          metrics: [
            Metric(
              label: l10n.approved,
              value: demo
                  ? '${n(TimesheetStatus.approved)}'
                  : '${sum?.approved ?? '—'}',
            ),
            Metric(
              label: l10n.statusPending,
              value: demo
                  ? '${n(TimesheetStatus.pending)}'
                  : '${sum?.pending ?? '—'}',
            ),
            Metric(
              label: l10n.totalHours,
              value: demo
                  ? hours.toStringAsFixed(1)
                  : sum == null
                  ? '—'
                  : (sum.totalMinutes / 60).toStringAsFixed(1),
            ),
            Metric(
              key: const Key('timesheets-total-pay'),
              label: l10n.totalSalaries,
              value: demo
                  ? money(salaries)
                  : sum == null
                  ? '—'
                  : apiMoney(sum),
            ),
          ],
        ),
        if (!demo) ..._apiRows(context, l10n),
        if (demo) ...[
          WfSearchBox(
            fieldKey: const Key('timesheets-search'),
            hint: l10n.searchTimesheetsHint,
            onChanged: (v) => setState(() {
              _query = v;
              _page = 0;
            }),
          ),
          // Figma 729:38117: "All Status" and "Month".
          ChipRow(
            children: [
              DropdownChip<TimesheetStatus?>(
                key: const Key('timesheet-status-filter'),
                value: _status,
                options: const [null, ...TimesheetStatus.values],
                labelOf: (s) => s == null
                    ? l10n.filterAllStatus
                    : timesheetStatusLabel(l10n, s),
                onChanged: (s) => setState(() {
                  _status = s;
                  _page = 0;
                }),
              ),
              DropdownChip<DateTime?>(
                key: const Key('timesheet-month-filter'),
                value: _month,
                options: [null, ...months],
                labelOf: (m) => m == null ? l10n.periodMonth : monthLabel(m),
                onChanged: (m) => setState(() {
                  _month = m;
                  _page = 0;
                }),
              ),
            ],
          ),
          if (visible.isEmpty) EmptyNotice(text: l10n.noRecords),
          for (final e in visible) TimesheetCard(entry: e),
          Pager(
            page: page,
            pageSize: _pageSize,
            total: filtered.length,
            onPage: (p) => setState(() => _page = p),
          ),
        ],
      ],
    );
  }

  /// API mode: the employee's own timesheet rows with the documented
  /// `status` and `month` filters (Figma 729:38117), the server's CSV of
  /// the same filters, and the server's pages.
  List<Widget> _apiRows(BuildContext context, AppLocalizations l10n) {
    final query = (month: _apiMonth, status: _status, page: _page + 1);
    final rows = ref.watch(apiTimesheetRowsProvider(query));
    // Months come with the rows; the chosen one stays offered while the
    // next page loads.
    final months = {?_apiMonth, ...?rows.value?.months}.toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      ChipRow(
        children: [
          DropdownChip<TimesheetStatus?>(
            key: const Key('timesheet-status-filter'),
            value: _status,
            options: const [null, ...TimesheetStatus.values],
            labelOf: (s) => s == null
                ? l10n.filterAllStatus
                : timesheetStatusLabel(l10n, s),
            onChanged: (s) => setState(() {
              _status = s;
              _page = 0;
            }),
          ),
          DropdownChip<String?>(
            key: const Key('timesheet-month-filter'),
            value: _apiMonth,
            options: [null, ...months],
            labelOf: (m) =>
                m == null ? l10n.periodMonth : timesheetMonthLabel(context, m),
            onChanged: (m) => setState(() {
              _apiMonth = m;
              _page = 0;
            }),
          ),
          ExportCsvChip(
            download: () => ref
                .read(employeeExportsProvider)
                .timesheets(month: _apiMonth, status: _status?.name),
          ),
        ],
      ),
      AsyncSection<TimesheetRows>(
        value: rows,
        onRetry: () => ref.invalidate(apiTimesheetRowsProvider(query)),
        builder: (r) {
          final page = r.page;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (page.items.isEmpty)
                EmptyNotice(
                  key: const Key('timesheets-empty'),
                  text: _status == null && _apiMonth == null
                      ? l10n.noTimesheetsYet
                      : l10n.noRecords,
                ),
              for (final t in page.items) ...[
                ApiTimesheetCard(row: t),
                const SizedBox(height: AppSpacing.md),
              ],
              if (page.lastPage > 1)
                Pager(
                  page: page.currentPage - 1,
                  pageSize: page.perPage,
                  total: page.total,
                  onPage: (p) => setState(() => _page = p),
                ),
            ],
          );
        },
      ),
    ];
  }
}

/// Figma timesheet "Record card" (729:38123): who and where in a bordered
/// identity block, the status, the amount, then Task, Date, Hours and Rate.
///
/// View only: the employee role may not approve, reject or delete
/// timesheets (the collection lists those routes as 403 for employees),
/// so the Figma Approve/Reject actions and the old Edit/Delete are not
/// offered.
class TimesheetCard extends StatelessWidget {
  const new({required this.entry, super.key});

  final TimesheetEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final e = entry;
    final date = DateFormat('yyyy-MM-dd', 'en');
    final time = DateFormat('HH:mm', 'en');
    final label = AppTextStyles.mobileBaseRegular.copyWith(
      color: AppColors.textPrimary,
    );
    return ModuleCard(
      key: Key('timesheet-${e.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.button),
              border: Border.all(color: ModuleColors.chipBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.employee,
                  style: AppTextStyles.mobileLgSemiBold.copyWith(
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  e.project,
                  style: AppTextStyles.mobileXsRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusBadge(
              label: timesheetStatusLabel(l10n, e.status),
              tone: timesheetTone(e.status),
              dot: true,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            money(e.amount),
            style: AppTextStyles.mobile2xlSemiBold.copyWith(
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 14),
          for (final (k, v) in [
            (l10n.taskCode, e.task),
            (l10n.fieldDate, date.format(e.start)),
            (l10n.fieldHours, durationLabel(e.duration)),
            (l10n.fieldRate, money(e.rate)),
          ]) ...[
            Text(k, style: label),
            Text(v, style: label),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TintedActions(
              onView: () => showRecordDetails(
                context,
                title: e.employee,
                status: timesheetStatusLabel(l10n, e.status),
                tone: timesheetTone(e.status),
                fields: [
                  DetailField(l10n.taskCode, e.task),
                  DetailField(l10n.fieldProject, e.project),
                  DetailField(l10n.fieldDate, date.format(e.start)),
                  DetailField(
                    l10n.duration,
                    '${time.format(e.start)} – ${time.format(e.end)}',
                  ),
                  DetailField(l10n.fieldHours, durationLabel(e.duration)),
                  DetailField(l10n.fieldRate, money(e.rate)),
                  DetailField(l10n.fieldAmount, money(e.amount)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
