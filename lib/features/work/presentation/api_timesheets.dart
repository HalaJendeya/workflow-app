import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/content_text.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/presentation/api_sprint_view.dart';
import 'package:workflow_app/features/work/presentation/task_details_screen.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/timesheets_screen.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

final _day = DateFormat('yyyy-MM-dd', 'en');

/// `2026-11` as "Nov 2026" in the app's language; the raw value when it is
/// not a month.
String timesheetMonthLabel(BuildContext context, String month) {
  final d = DateTime.tryParse('$month-01');
  if (d == null) return month;
  return DateFormat.yMMM(Localizations.localeOf(context).toString()).format(d);
}

/// Minutes as "160h 0m".
String minutesLabel(int minutes) => durationLabel(Duration(minutes: minutes));

String paymentTypeLabel(AppLocalizations l10n, String? type) => switch (type) {
  'hourly' => l10n.payHourly,
  'monthly' => l10n.payMonthly,
  null || '' => '—',
  final other => other,
};

/// A status the app knows as a badge; anything else as the server says it.
Widget timesheetBadge(AppLocalizations l10n, String raw) =>
    switch (timesheetStatusOf(raw)) {
      final s? => StatusBadge(
        label: timesheetStatusLabel(l10n, s),
        tone: timesheetTone(s),
        dot: true,
      ),
      null => StatusBadge(label: raw, tone: BadgeTone.neutral, dot: true),
    };

/// Figma timesheet "Record card" (729:38123) for a server row: who and
/// where, the status, the month's total, then Month, Date, Hours and Rate.
/// View only (approve and reject are refused to employees); "View" opens
/// the tasks the month is paid from.
class ApiTimesheetCard extends StatelessWidget {
  const new({required this.row, super.key});

  final ApiTimesheet row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = row;
    final label = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    String amount(double v) => money(
      v,
      currency: r.currencyCode ?? '',
      symbol: r.currencySymbol ?? '',
    );
    return ModuleCard(
      key: Key('api-timesheet-${r.id}'),
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
                ContentText(
                  r.userName ?? '—',
                  style: AppTextStyles.mobileLgSemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (r.companyName case final c?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ContentText(c, style: label),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: timesheetBadge(l10n, r.rawStatus),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            ltrIsolate(amount(r.total)),
            style: AppTextStyles.mobile2xlSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DetailGrid([
            DetailField(
              l10n.periodMonth,
              timesheetMonthLabel(context, r.month),
            ),
            if (r.date case final d?)
              DetailField(l10n.fieldDate, ltrIsolate(_day.format(d))),
            DetailField(l10n.fieldHours, ltrIsolate(minutesLabel(r.minutes))),
            DetailField(
              l10n.fieldRate,
              r.rate == null
                  ? paymentTypeLabel(l10n, r.paymentType)
                  : '${ltrIsolate(amount(r.rate!))} · '
                        '${paymentTypeLabel(l10n, r.paymentType)}',
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TintedActions(
              onView: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => TimesheetDetailsScreen(row: r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tasks one month's timesheet is paid from, grouped by project
/// (`GET /employee/timesheets/{id}/details`). Each task opens its details.
class TimesheetDetailsScreen extends ConsumerWidget {
  const new({required this.row, super.key});

  final ApiTimesheet row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(apiTimesheetDetailsProvider(row.id));
    final h16 = AppTextStyles.mobileLgSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    return ModulePage(
      key: const Key('timesheet-details'),
      title: l10n.timesheetDetails,
      description: timesheetMonthLabel(context, row.month),
      children: [
        AsyncSection<TimesheetBreakdown>(
          value: value,
          onRetry: () => ref.invalidate(apiTimesheetDetailsProvider(row.id)),
          builder: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ModuleCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            timesheetMonthLabel(context, b.month),
                            style: h16,
                          ),
                        ),
                        timesheetBadge(l10n, b.rawStatus),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DetailGrid([
                      DetailField(
                        l10n.countedHours,
                        ltrIsolate(minutesLabel(b.countedMinutes)),
                      ),
                      DetailField(l10n.countedTasks, '${b.tasksCount}'),
                      DetailField(
                        l10n.fieldRate,
                        paymentTypeLabel(l10n, b.payType ?? row.paymentType),
                      ),
                      if (b.from != null && b.to != null)
                        DetailField(
                          l10n.period,
                          ltrIsolate(
                            '${_day.format(b.from!)} – ${_day.format(b.to!)}',
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
              if (!b.inSync) ...[
                const SizedBox(height: AppSpacing.md),
                InfoNotice(
                  key: const Key('timesheet-out-of-sync'),
                  text: l10n.timesheetOutOfSync,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(l10n.timesheetCountedHelp, style: secondary),
              const SizedBox(height: AppSpacing.md),
              if (b.projects.isEmpty)
                EmptyNotice(
                  key: const Key('timesheet-no-tasks'),
                  text: l10n.timesheetNoTasks,
                ),
              for (final p in b.projects) ...[
                ModuleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: ContentText(p.title, style: h16)),
                          Text(
                            ltrIsolate(minutesLabel(p.countedMinutes)),
                            style: AppTextStyles.mobileBaseSemiBold.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      for (final t in p.tasks)
                        InkWell(
                          key: Key('timesheet-task-${t.id}'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => openApiTaskById(context, t.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ContentText(
                                        t.title,
                                        style: AppTextStyles.mobileBaseRegular
                                            .copyWith(
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                      Text(
                                        [
                                          if (t.taskDate case final d?)
                                            ltrIsolate(_day.format(d)),
                                          apiTaskStatusLabel(
                                            l10n,
                                            apiTaskStatus(t.rawStatus),
                                          ),
                                        ].join(' · '),
                                        style: secondary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  ltrIsolate(minutesLabel(t.countedMinutes)),
                                  style: secondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
