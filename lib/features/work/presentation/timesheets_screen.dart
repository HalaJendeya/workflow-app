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
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demo = ref.watch(demoModeProvider);
    final all = ref.watch(timesheetsProvider);
    final q = _query.trim().toLowerCase();
    final filtered = all.where((e) {
      if (_status != null && e.status != _status) return false;
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
    final dt = DateFormat('yyyy/MM/dd - HH:mm', 'en');
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
      onSearch: (v) => setState(() => _query = v),
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
        WfSearchBox(
          fieldKey: const Key('timesheets-search'),
          hint: l10n.searchTimesheetsHint,
          onChanged: (v) => setState(() {
            _query = v;
            _page = 0;
          }),
        ),
        ChipRow(
          children: [
            FilterChipBox(
              label: '${l10n.filterAll} (${all.length})',
              selected: _status == null,
              onTap: () => setState(() => _status = null),
            ),
            for (final s in TimesheetStatus.values)
              FilterChipBox(
                label: '${timesheetStatusLabel(l10n, s)} (${n(s)})',
                selected: _status == s,
                onTap: () => setState(() {
                  _status = s;
                  _page = 0;
                }),
              ),
          ],
        ),
        if (visible.isEmpty) EmptyNotice(text: l10n.noRecords),
        for (final e in visible)
          StackedRecordCard(
            key: Key('timesheet-${e.id}'),
            title: e.task,
            subtitle: e.project,
            badge: StatusBadge(
              label: timesheetStatusLabel(l10n, e.status),
              tone: timesheetTone(e.status),
            ),
            amount: money(e.amount),
            rows: [
              (l10n.fieldProject, e.project),
              (l10n.fieldEmployee, e.employee),
              (l10n.startDate, dt.format(e.start)),
              (l10n.endDate, dt.format(e.end)),
              (l10n.duration, durationLabel(e.duration)),
            ],
            actions: TintedActions(
              onView: () => showRecordDetails(
                context,
                title: e.task,
                status: timesheetStatusLabel(l10n, e.status),
                tone: timesheetTone(e.status),
                fields: [
                  DetailField(l10n.fieldProject, e.project),
                  DetailField(l10n.fieldEmployee, e.employee),
                  DetailField(l10n.startDate, dt.format(e.start)),
                  DetailField(l10n.endDate, dt.format(e.end)),
                  DetailField(l10n.duration, durationLabel(e.duration)),
                  DetailField(l10n.fieldAmount, money(e.amount)),
                ],
              ),
              onEdit: () async {
                final s = await showModalBottomSheet<TimesheetStatus>(
                  context: context,
                  builder: (sheet) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final st in TimesheetStatus.values)
                          ListTile(
                            title: Text(timesheetStatusLabel(l10n, st)),
                            trailing: st == e.status
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () => Navigator.pop(sheet, st),
                          ),
                      ],
                    ),
                  ),
                );
                if (s != null) {
                  final applied = ref
                      .read(timesheetsProvider.notifier)
                      .replace(e.withStatus(s));
                  if (context.mounted) {
                    showLocalOutcome(context, applied: applied);
                  }
                }
              },
              onDelete: () async {
                if (await confirmDelete(context, e.task)) {
                  final removed = ref
                      .read(timesheetsProvider.notifier)
                      .remove(e.id);
                  if (context.mounted) {
                    showLocalOutcome(context, applied: removed, deleted: true);
                  }
                }
              },
            ),
          ),
        Pager(
          page: page,
          pageSize: _pageSize,
          total: filtered.length,
          onPage: (p) => setState(() => _page = p),
        ),
      ],
    );
  }
}
