import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/content_text.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/meetings/presentation/api_meetings_view.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/features/projects/presentation/api_projects_view.dart';
import 'package:workflow_app/features/reports/data/employee_report_repository.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/presentation/api_sprint_view.dart';
import 'package:workflow_app/features/work/presentation/api_timesheets.dart';
import 'package:workflow_app/features/work/presentation/task_details_screen.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

final _day = DateFormat('yyyy-MM-dd', 'en');

String _associationLabel(AppLocalizations l10n, String a) => switch (a) {
  'leader' => l10n.reportLeader,
  'member' => l10n.reportMember,
  'assignee' => l10n.reportAssignee,
  _ => a,
};

ApiProjectStatus _projectStatus(String s) => switch (s) {
  'pending' => ApiProjectStatus.pending,
  'in_progress' => ApiProjectStatus.inProgress,
  'completed' => ApiProjectStatus.completed,
  _ => ApiProjectStatus.other,
};

String _meetingStatusLabel(AppLocalizations l10n, String s) => switch (s) {
  'waiting' => l10n.meetingWaiting,
  'live' => l10n.meetingLive,
  'ended' => l10n.meetingEnded,
  'cancelled' => l10n.meetingCancelled,
  _ => s,
};

/// "My report" (`GET /employee/report`): the signed-in employee's own
/// tasks, projects, time, timesheets and meetings for a month or a year.
/// The report is always the caller's: no person or company is chosen.
///
/// No Figma frame exists for this screen; it is built only from the
/// design system's existing parts (masthead, filter chips, metric group,
/// cards, status badges) so it matches the Timesheets and Dashboard
/// frames, and needs a design review.
class EmployeeReportScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<EmployeeReportScreen> createState() =>
      _EmployeeReportScreenState();
}

class _EmployeeReportScreenState extends ConsumerState<EmployeeReportScreen> {
  late ReportQuery _query = ReportQuery(
    span: ReportSpan.month,
    anchor: DateTime(DateTime.now().year, DateTime.now().month),
  );

  /// The period after the current one would be empty, so it is not offered.
  bool get _atLatest {
    final now = DateTime.now();
    final a = _query.anchor;
    return _query.span == ReportSpan.year
        ? a.year >= now.year
        : (a.year > now.year || (a.year == now.year && a.month >= now.month));
  }

  void _step(int by) => setState(() {
    final a = _query.anchor;
    _query = _query.copyWith(
      anchor: _query.span == ReportSpan.year
          ? DateTime(a.year + by)
          : DateTime(a.year, a.month + by),
      page: 1,
    );
  });

  /// The period as shown ("Nov 2026", as the report's timesheet rows) and
  /// as read aloud ("November 2026").
  (String shown, String spoken) _periodLabel(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    if (_query.span == ReportSpan.year) {
      final y = DateFormat.y(locale).format(_query.anchor);
      return (y, y);
    }
    return (
      DateFormat.yMMM(locale).format(_query.anchor),
      DateFormat.yMMMM(locale).format(_query.anchor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(employeeReportProvider(_query));
    final period = _periodLabel(context);
    return ModulePage(
      key: const Key('employee-report'),
      title: l10n.myReport,
      description: l10n.myReportBody,
      children: [
        // One card for the whole period choice: previous and next at the
        // edges, the period and the Month/Year chips between them on one
        // line when they fit, wrapped onto two (never clipped) on a narrow
        // phone or with large text.
        ModuleCard(
          key: const Key('report-period-controls'),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                key: const Key('report-previous'),
                tooltip: l10n.previousPeriod,
                onPressed: () => _step(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: 6,
                    children: [
                      Semantics(
                        label: period.$2,
                        excludeSemantics: true,
                        child: Text(
                          period.$1,
                          key: const Key('report-period'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.mobileBaseSemiBold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      ChipRow(
                        children: [
                          for (final (span, label) in [
                            (ReportSpan.month, l10n.periodMonth),
                            (ReportSpan.year, l10n.periodYear),
                          ])
                            FilterChipBox(
                              key: Key('report-span-${span.name}'),
                              label: label,
                              selected: _query.span == span,
                              onTap: () => setState(
                                () => _query = _query.copyWith(
                                  span: span,
                                  page: 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: const Key('report-next'),
                tooltip: l10n.nextPeriod,
                onPressed: _atLatest ? null : () => _step(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        AsyncSection<EmployeeReport>(
          value: value,
          onRetry: () => ref.invalidate(employeeReportProvider(_query)),
          builder: (r) => _ReportBody(
            report: r,
            onPage: (p) =>
                setState(() => _query = _query.copyWith(page: p + 1)),
          ),
        ),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  const new({required this.report, required this.onPage});

  final EmployeeReport report;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = report;
    final e = r.earnings;
    final h16 = AppTextStyles.mobileLgSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    String amount(double v) =>
        ltrIsolate(money(v, currency: e.code ?? '', symbol: e.symbol ?? ''));
    Widget section(String key, String title, List<Widget> children) =>
        ModuleCard(
          key: Key('report-$key'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: h16),
              const SizedBox(height: AppSpacing.sm),
              ...children,
            ],
          ),
        );
    Widget row({
      required String title,
      String? meta,
      Widget? trailing,
      VoidCallback? onTap,
      Key? key,
    }) => InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentText(
                    title,
                    style: AppTextStyles.mobileBaseRegular.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (meta != null && meta.isNotEmpty)
                    Text(meta, style: secondary),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing,
            ],
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricGroup(
          key: const Key('report-summary'),
          metrics: [
            Metric(
              label: l10n.reportTasksDone,
              value: l10n.reportOf(r.completedTasks, r.taskCount),
            ),
            Metric(
              label: l10n.reportLoggedTime,
              value: ltrIsolate(minutesLabel(r.workingMinutes)),
            ),
            Metric(
              label: l10n.reportMeetingsAttended,
              value: l10n.reportOf(r.meetingsAttended, r.meetingsCount),
            ),
            Metric(label: l10n.navProjects, value: '${r.projects.length}'),
            Metric(label: l10n.reportEarnings, value: amount(e.total)),
            Metric(label: l10n.approved, value: amount(e.approved)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        section('status', l10n.reportTasksByStatus, [
          DetailGrid([
            for (final s in reportStatuses)
              DetailField(
                apiTaskStatusLabel(l10n, apiTaskStatus(s)),
                '${r.byStatus[s]}',
              ),
          ]),
        ]),
        const SizedBox(height: AppSpacing.lg),
        section('tasks', l10n.tasksTitle, [
          if (r.tasks.items.isEmpty) Text(l10n.reportNoTasks, style: secondary),
          for (final t in r.tasks.items)
            row(
              key: Key('report-task-${t.id}'),
              title: t.title,
              meta: [
                ?t.projectTitle,
                if (t.taskDate case final d?) ltrIsolate(_day.format(d)),
              ].join(' · '),
              trailing: StatusBadge(
                label: apiTaskStatusLabel(l10n, apiTaskStatus(t.status)),
                tone: apiTaskStatusTone(apiTaskStatus(t.status)),
              ),
              onTap: () => openApiTaskById(context, t.id),
            ),
          if (r.tasks.lastPage > 1)
            Pager(
              page: r.tasks.currentPage - 1,
              pageSize: r.tasks.perPage,
              total: r.tasks.total,
              onPage: onPage,
            ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        section('projects', l10n.navProjects, [
          if (r.projects.isEmpty) Text(l10n.reportNoProjects, style: secondary),
          for (final p in r.projects)
            row(
              key: Key('report-project-${p.id}'),
              title: p.title,
              meta: [
                for (final a in p.associations) _associationLabel(l10n, a),
                l10n.reportTasksOf(p.completedTasks, p.tasks),
              ].join(' · '),
              trailing: StatusBadge(
                label: apiProjectStatusLabel(l10n, _projectStatus(p.status)),
                tone: apiProjectTone(_projectStatus(p.status)),
              ),
            ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        section('timesheets', l10n.timesheetsShort, [
          if (r.timesheets.isEmpty)
            Text(l10n.reportNoTimesheets, style: secondary),
          for (final t in r.timesheets)
            row(
              key: Key('report-timesheet-${t.id}'),
              title: timesheetMonthLabel(context, t.month),
              meta: [
                ltrIsolate(minutesLabel(t.minutes)),
                amount(t.earnings),
              ].join(' · '),
              trailing: timesheetBadge(l10n, t.status),
            ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        // A plain section name like the others, not the module's page title.
        section('meetings', l10n.catMeetings, [
          if (r.meetings.isEmpty) Text(l10n.reportNoMeetings, style: secondary),
          for (final m in r.meetings)
            row(
              key: Key('report-meeting-${m.id}'),
              title: m.title,
              meta: [
                _meetingStatusLabel(l10n, m.status),
                if (m.invitationStatus case final s?)
                  invitationStatusLabel(l10n, s),
                if (m.attended) l10n.reportAttended,
              ].join(' · '),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => ApiMeetingDetailsScreen(id: m.id),
                ),
              ),
            ),
        ]),
      ],
    );
  }
}
