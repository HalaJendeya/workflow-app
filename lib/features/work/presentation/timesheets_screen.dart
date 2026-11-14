import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
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
    final monthLabel = DateFormat('MMM yyyy', 'en').format;
    // API mode: `stats` and per-currency `totals` of GET /employee/timesheets.
    final api = demo ? null : ref.watch(employeeTimesheetSummaryProvider);
    final sum = api?.value;
    String apiMoney(TimesheetSummary s) => s.money.isEmpty
        ? '0'
        : s.money
              .map((m) => money(m.approved, currency: m.code, symbol: m.symbol))
              .join(' · ');

    return ModulePage(
      title: l10n.timesheetsTitle,
      description: l10n.timesheetsBody,
      // API mode loads no rows (their fields are undocumented), so there
      // is nothing to search, filter or page: those controls showed
      // "Approved (0)" and "No records" beside the server's real counts.
      onSearch: demo
          ? (v) => setState(() {
              _query = v;
              _page = 0;
            })
          : null,
      children: [
        if (!demo) const BackendPendingNotice(),
        if (api case AsyncError(:final error))
          ApiErrorCard(
            error: error,
            onRetry: () => ref.invalidate(employeeTimesheetSummaryProvider),
          ),
        IconMetricCard(
          icon: 'metric_ts_0',
          tint: ModuleColors.successBg,
          iconSize: 20,
          title: l10n.approved,
          value: demo
              ? '${n(TimesheetStatus.approved)}'
              : '${sum?.approved ?? '—'}',
        ),
        IconMetricCard(
          icon: 'metric_ts_1',
          tint: ModuleColors.warningBg,
          iconSize: 20,
          title: l10n.statusPending,
          value: demo
              ? '${n(TimesheetStatus.pending)}'
              : '${sum?.pending ?? '—'}',
        ),
        IconMetricCard(
          icon: 'metric_ts_2',
          tint: AppColors.primary50,
          iconSize: 20,
          title: l10n.totalHours,
          value: demo
              ? hours.toStringAsFixed(1)
              : sum == null
              ? '—'
              : (sum.totalMinutes / 60).toStringAsFixed(1),
        ),
        IconMetricCard(
          icon: 'metric_ts_3',
          tint: AppColors.surfaceSubtle,
          iconSize: 20,
          title: l10n.totalSalaries,
          value: demo
              ? money(salaries)
              : sum == null
              ? '—'
              : apiMoney(sum),
        ),
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
