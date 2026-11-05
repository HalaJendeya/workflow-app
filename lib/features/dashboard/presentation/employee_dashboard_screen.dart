import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/dashboard/domain/client_dashboard.dart';
import 'package:workflow_app/features/dashboard/domain/employee_dashboard.dart';
import 'package:workflow_app/features/dashboard/presentation/client_dashboard_screen.dart';
import 'package:workflow_app/features/dashboard/presentation/dashboard_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/features/projects/presentation/api_projects_view.dart';
import 'package:workflow_app/features/projects/presentation/projects_screen.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

String _hours(double h) => '${h.toStringAsFixed(1)}h';

/// Figma employee "Dashboard" (731:47939).
class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState
    extends ConsumerState<EmployeeDashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.week;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(employeeDashboardProvider);
    if (data == null) return const _ApiEmployeeDashboard();
    final tasks = ref.watch(workTasksProvider);
    final q = _query.trim().toLowerCase();
    final projects = ref
        .watch(projectsProvider)
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    final focus =
        tasks
            .where(
              (t) =>
                  q.isEmpty || '${t.title} ${t.code}'.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) => b.priority.index.compareTo(a.priority.index));

    return ModulePage(
      title: l10n.catDashboard,
      description: l10n.employeeDashboardBody,
      onSearch: (v) => setState(() => _query = v),
      children: [
        ChipRow(
          children: [
            for (final p in DashboardPeriod.values)
              FilterChipBox(
                key: Key('period-${p.name}'),
                label: periodLabel(l10n, p),
                selected: _period == p,
                onTap: () => setState(() => _period = p),
              ),
          ],
        ),
        _KpiGrid(data: data, tasks: tasks),
        _HoursCard(data: data),
        _DistributionCard(tasks: tasks, data: data),
        DashboardGroupHeader(
          title: l10n.activeTasksMilestones,
          chips: [
            FilterChipBox(
              key: const Key('view-backlog'),
              label: l10n.viewBacklog,
              selected: true,
              onTap: () => context.go(Routes.employeeSprints),
            ),
          ],
        ),
        if (focus.isEmpty) EmptyNotice(text: l10n.noRecords),
        for (final t in focus.take(3)) _FocusTaskCard(task: t),
        ...[
          AllocationCard(allocation: data.allocation),
          _RevenueTrajectoryCard(data: data),
        ],
        DashboardGroupHeader(
          title: l10n.activeClientProjects,
          chips: [
            FilterChipBox(
              label: l10n.runningCount(projects.length),
              selected: true,
              onTap: () => context.go(Routes.employeeProjects),
            ),
          ],
        ),
        if (projects.isEmpty) EmptyNotice(text: l10n.noRecords),
        for (final p in projects) DashboardProjectCard(project: p),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const new({required this.tint, required this.child, this.size = 28});

  final Color tint;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(size > 28 ? 12 : 8),
    ),
    child: child,
  );
}

class _KpiGrid extends StatelessWidget {
  const new({required this.data, required this.tasks});

  final EmployeeDashboard? data;
  final List<WorkTask> tasks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = data;
    final open = tasks.where((t) => t.status != TaskStatus.completed).length;
    final done = tasks.length - open;
    final urgent = tasks
        .where(
          (t) =>
              t.status != TaskStatus.completed &&
              t.priority.index >= TaskPriority.high.index,
        )
        .length;
    final velocity = tasks.isEmpty ? 0 : (done / tasks.length * 100).round();
    final tiles = <Widget>[
      if (d != null)
        _KpiTile(
          icon: Text(
            r'$',
            style: AppTextStyles.mobileBaseSemiBold.copyWith(
              color: AppColors.primaryStrong,
            ),
          ),
          tint: AppColors.statusInfoBackground,
          delta: '↗ +${d.revenueDelta}%',
          deltaTone: BadgeTone.success,
          label: l10n.revenue,
          value: money(d.revenue),
          footnote: l10n.targetShort(money(d.revenueTarget)),
          spark: const [3, 4, 3.5, 5, 4.5, 6],
          sparkColor: AppColors.statusInfo,
        ),
      _KpiTile(
        icon: const WfSvg('edash_tasks', size: 14),
        tint: AppColors.primary50,
        delta: l10n.tasksCount(open),
        deltaTone: BadgeTone.info,
        label: l10n.activeTasks,
        value: '$open',
        footnote: l10n.highPriorityCount(urgent),
        footnoteColor: ModuleColors.warningFg,
        spark: const [4, 3, 4.5, 4, 5, 4.2],
        sparkColor: ModuleColors.chartYellow,
      ),
      _KpiTile(
        icon: const WfSvg('edash_done', size: 14),
        tint: ModuleColors.tintTeal,
        delta: '$done/${tasks.length}',
        deltaTone: BadgeTone.success,
        label: l10n.completedUpper,
        value: '$done',
        footnote: l10n.velocityPercent(velocity),
        spark: const [2, 2.5, 3, 3.2, 4, 5],
        sparkColor: ModuleColors.successFg,
      ),
      if (d != null)
        _KpiTile(
          icon: const WfSvg('edash_hours', size: 14),
          tint: AppColors.primary50,
          delta: '${_hours(d.loggedHours)} / ${d.weeklyTarget.round()}h',
          deltaTone: BadgeTone.info,
          label: l10n.loggedHours,
          value: _hours(d.loggedHours),
          footnote: l10n.weeklyPercent(
            (d.loggedHours / d.weeklyTarget * 100).round(),
          ),
          spark: d.dailyHours.take(5).toList(),
          sparkColor: AppColors.primary,
        ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.tint,
    required this.delta,
    required this.deltaTone,
    required this.label,
    required this.value,
    required this.footnote,
    required this.spark,
    required this.sparkColor,
    this.footnoteColor,
  });

  final Widget icon;
  final Color tint;
  final String delta;
  final BadgeTone deltaTone;
  final String label;
  final String value;
  final String footnote;
  final Color? footnoteColor;
  final List<double> spark;
  final Color sparkColor;

  @override
  Widget build(BuildContext context) => ModuleCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _IconTile(tint: tint, child: icon),
            const SizedBox(width: 6),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _DeltaChip(label: delta, tone: deltaTone),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.mobileXsRegular.copyWith(
            fontSize: 11,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.mobileXlSemiBold.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.neutral900,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                footnote,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mobileXsRegular.copyWith(
                  fontSize: 10,
                  color: footnoteColor ?? AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 54,
              height: 16,
              child: CustomPaint(painter: _SparkPainter(spark, sparkColor)),
            ),
          ],
        ),
      ],
    ),
  );
}

/// 10 px delta label used in the KPI tiles (smaller than [StatusBadge]).
class _DeltaChip extends StatelessWidget {
  const new({required this.label, required this.tone});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone == BadgeTone.success
        ? (ModuleColors.successBg, ModuleColors.successFg)
        : (AppColors.statusInfoBackground, AppColors.statusInfo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.mobileXsSemiBold.copyWith(fontSize: 10, color: fg),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const new(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final hi = values.reduce(math.max);
    final lo = values.reduce(math.min);
    final span = hi == lo ? 1 : hi - lo;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(
        size.width * i / (values.length - 1),
        size.height - (values[i] - lo) / span * size.height,
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.color != color;
}

class _HoursCard extends StatelessWidget {
  const new({required this.data});

  final EmployeeDashboard data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final days = [
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];
    final today = DateTime.now().weekday - 1;
    Widget stat(String label, String value, Color bg, Color fg) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: AppTextStyles.mobileXsRegular.copyWith(
                fontSize: 9,
                letterSpacing: 0.5,
                color: fg,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.mobileXsSemiBold.copyWith(
                color: fg == AppColors.textSecondary
                    ? AppColors.neutral900
                    : fg,
              ),
            ),
          ],
        ),
      ),
    );
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.workingHoursTrend,
                style: AppTextStyles.mobileBaseSemiBold.copyWith(
                  color: AppColors.neutral900,
                ),
              ),
              StatusBadge(
                label: '+${data.hoursDelta} ${l10n.hrsUnit}',
                tone: BadgeTone.success,
                radius: 6,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              StatusBadge(
                label: l10n.currentWeek,
                tone: BadgeTone.info,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.hoursVsTarget, style: dashCaption),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            children: [
              _Legend(
                color: AppColors.primary,
                label: l10n.loggedLegend(_hours(data.loggedHours)),
              ),
              _Legend(
                color: ModuleColors.chartMuted,
                label: l10n.targetLegend(_hours(data.dailyTarget)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: l10n.workingHoursTrend,
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: CustomPaint(
                painter: _HoursPainter(data.dailyHours, data.dailyTarget),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        days[i],
                        style: AppTextStyles.mobileXsRegular.copyWith(
                          fontSize: 10,
                          color: i == today
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: i == today ? FontWeight.w700 : null,
                        ),
                      ),
                      Text(
                        _hours(data.dailyHours[i]),
                        style: AppTextStyles.mobileXsRegular.copyWith(
                          fontSize: 9,
                          color: i == today
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 28, color: ModuleColors.sectionDivider),
          Row(
            children: [
              stat(
                l10n.avgDaily,
                '${data.averageDaily.toStringAsFixed(1)} ${l10n.hrsUnit}',
                AppColors.pageContent,
                AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              stat(
                l10n.focusRate,
                '${data.focusRate}%',
                ModuleColors.successBg,
                ModuleColors.successFg,
              ),
              const SizedBox(width: 8),
              stat(
                l10n.timesheetLabel,
                data.timesheetApproved ? l10n.approved : l10n.statusPending,
                AppColors.primary50,
                AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const new({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: dashCaption),
    ],
  );
}

class _HoursPainter extends CustomPainter {
  const new(this.hours, this.target);

  final List<double> hours;
  final double target;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = math.max(hours.reduce(math.max), target) * 1.15;
    double y(double v) => size.height - v / maxV * size.height;
    final step = size.width / hours.length;
    final pts = [
      for (var i = 0; i < hours.length; i++)
        Offset(step * (i + 0.5), y(hours[i])),
    ];
    // Dashed daily target.
    final dash = Paint()
      ..color = ModuleColors.chartMuted
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, y(target)), Offset(x + 3, y(target)), dash);
    }
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas
      ..drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.18),
              AppColors.primary.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        line,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    for (final p in pts) {
      canvas
        ..drawCircle(p, 3.5, Paint()..color = AppColors.white)
        ..drawCircle(
          p,
          3.5,
          Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }
  }

  @override
  bool shouldRepaint(_HoursPainter old) =>
      old.hours != hours || old.target != target;
}

class _DistributionCard extends StatelessWidget {
  const new({required this.tasks, required this.data});

  final List<WorkTask> tasks;
  final EmployeeDashboard? data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    int n(TaskStatus s) => tasks.where((t) => t.status == s).length;
    final total = tasks.length;
    int pct(int v) => total == 0 ? 0 : (v / total * 100).round();
    final rows = [
      (TaskStatus.completed, AppColors.primary),
      (TaskStatus.inProgress, ModuleColors.chartCyan),
      (TaskStatus.todo, ModuleColors.chartAmber),
      (TaskStatus.backlog, ModuleColors.chartMuted),
    ];
    final d = data;
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.taskDistribution,
                      style: AppTextStyles.mobileBaseSemiBold.copyWith(
                        color: AppColors.neutral900,
                      ),
                    ),
                    Text(l10n.taskDistributionBody, style: dashCaption),
                  ],
                ),
              ),
              TextButton.icon(
                key: const Key('all-tasks'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryStrong,
                  textStyle: AppTextStyles.mobileXsSemiBold,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const TasksScreen()),
                ),
                iconAlignment: IconAlignment.end,
                icon: const WfSvg('edash_link', size: 12),
                label: Text(l10n.allTasks),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox.square(
                dimension: 112,
                child: CustomPaint(
                  painter: DonutPainter([
                    for (final (s, c) in rows) (n(s).toDouble(), c),
                  ], thickness: 14),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: AppTextStyles.mobileLgSemiBold.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral900,
                          ),
                        ),
                        Text(
                          l10n.tasksUpper,
                          style: AppTextStyles.mobileXsRegular.copyWith(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        StatusBadge(
                          label: l10n.percentDone(pct(n(TaskStatus.completed))),
                          tone: BadgeTone.info,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final (s, c) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                taskStatusLabel(l10n, s),
                                style: dashLabel,
                              ),
                            ),
                            Text(
                              '${n(s)} (${pct(n(s))}%)',
                              style: AppTextStyles.mobileXsSemiBold.copyWith(
                                color: AppColors.neutral900,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (d != null) ...[
            const Divider(height: 28, color: ModuleColors.sectionDivider),
            Row(
              children: [
                const WfSvg('edash_sprint', size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(d.sprint, style: dashLabel)),
                const SizedBox(width: 8),
                Flexible(
                  child: StatusBadge(
                    label: '• ${l10n.onTrackEta(d.sprintEtaDays)}',
                    tone: BadgeTone.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FocusTaskCard extends StatelessWidget {
  const new({required this.task});

  final WorkTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = task;
    final done = t.status == TaskStatus.completed;
    final progress = done ? 1.0 : t.progress;
    final (icon, tint) = switch (t.priority) {
      TaskPriority.urgent ||
      TaskPriority.high => ('edash_grid', AppColors.primary50),
      TaskPriority.medium => ('edash_code', ModuleColors.successBg),
      TaskPriority.low => ('edash_phone', ModuleColors.tintPurple),
    };
    final tone = switch (t.priority) {
      TaskPriority.urgent || TaskPriority.high => BadgeTone.danger,
      TaskPriority.medium => BadgeTone.warning,
      TaskPriority.low => BadgeTone.neutral,
    };
    final barColor = done ? ModuleColors.successFg : AppColors.primary;
    return ModuleCard(
      key: Key('focus-${t.id}'),
      onTap: () => showTaskDetails(context, t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconTile(tint: tint, size: 32, child: WfSvg(icon, size: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: AppTextStyles.mobileXsSemiBold.copyWith(
                        color: AppColors.neutral900,
                      ),
                    ),
                    Text(
                      '${t.code} • ${t.sprint} • ${t.project}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dashCaption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: priorityLabel(l10n, t.priority),
                tone: tone,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.percentComplete((progress * 100).round()),
                  style: dashCaption.copyWith(fontSize: 11),
                ),
              ),
              Text(
                '• ${taskStatusLabel(l10n, t.status)}',
                style: AppTextStyles.mobileXsSemiBold.copyWith(
                  fontSize: 11,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: barColor,
              backgroundColor: ModuleColors.chartTrack,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueTrajectoryCard extends StatelessWidget {
  const new({required this.data});

  final EmployeeDashboard data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final months = data.revenueMonths;
    final maxV = months
        .map((m) => math.max(m.actual, m.target))
        .reduce(math.max);
    final best = months.reduce((a, b) => a.actual >= b.actual ? a : b);
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.revenueTrajectory,
                      style: AppTextStyles.mobileBaseSemiBold.copyWith(
                        color: AppColors.neutral900,
                      ),
                    ),
                    Text(l10n.revenueTrajectoryBody, style: dashCaption),
                  ],
                ),
              ),
              StatusBadge(
                label: l10n.yoyDelta(data.revenueYoY),
                tone: BadgeTone.success,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            label: l10n.revenueTrajectory,
            child: SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in months)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _Bar(
                                  value: m.target / maxV,
                                  color: ModuleColors.chartTrack,
                                ),
                                if (m.actual > 0) ...[
                                  const SizedBox(width: 4),
                                  _Bar(
                                    value: m.actual / maxV,
                                    color: m == best
                                        ? AppColors.primaryStrong
                                        : AppColors.primary.withValues(
                                            alpha: 0.75,
                                          ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m.label,
                            style: AppTextStyles.mobileXsRegular.copyWith(
                              fontSize: 9,
                              color: m == best
                                  ? AppColors.primaryStrong
                                  : AppColors.textSecondary,
                              fontWeight: m == best ? FontWeight.w700 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const new({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: value.clamp(0.02, 1),
    child: Container(
      width: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    ),
  );
}

/// API-mode employee dashboard: the figures GET /employee/dashboard returns
/// live, task counts by status from GET /employee/tasks and the first page
/// of real projects. The hours chart, revenue trajectory and allocation
/// cards have no documented source, so they are not drawn with samples.
class _ApiEmployeeDashboard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(employeeDashboardSummaryProvider);
    final tasks = ref.watch(employeeTaskStatsProvider);
    const projectsQuery = (search: '', status: null, page: 1);
    final projects = ref.watch(apiProjectsProvider(projectsQuery));
    String amount(double v) => money(v, currency: '', symbol: '');
    return ModulePage(
      title: l10n.catDashboard,
      description: l10n.employeeDashboardBody,
      children: [
        AsyncSection(
          value: summary,
          onRetry: () => ref.invalidate(employeeDashboardSummaryProvider),
          builder: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MetricCard(
                key: const Key('emp-dash-tasks'),
                title: l10n.activeTasks,
                value: count(s.tasks),
                delta: '—',
              ),
              const SizedBox(height: 16),
              MetricCard(
                title: l10n.loggedHours,
                value: (s.loggedMinutes / 60).toStringAsFixed(1),
                delta: '—',
              ),
              const SizedBox(height: 16),
              MetricCard(
                title: l10n.totalEarned,
                value: amount(s.earned),
                delta: '—',
              ),
              const SizedBox(height: 16),
              MetricCard(
                title: l10n.paidSalary,
                value: amount(s.paid),
                delta: '—',
              ),
              const SizedBox(height: 16),
              MetricCard(
                title: l10n.unpaidSalary,
                value: amount(s.unpaid),
                delta: '—',
                negative: true,
              ),
            ],
          ),
        ),
        AsyncSection(
          value: tasks,
          onRetry: () => ref.invalidate(employeeTaskStatsProvider),
          builder: (t) => DashboardSection(
            title: l10n.taskDistribution,
            caption: l10n.taskDistributionBody,
            children: [
              for (final e in t.byStatus.entries)
                LabelValue(
                  label: serverTaskStatusLabel(l10n, e.key),
                  value: '${e.value}',
                ),
            ],
          ),
        ),
        DashboardGroupHeader(
          title: l10n.activeClientProjects,
          chips: [
            FilterChipBox(
              label: l10n.runningCount(projects.value?.stats.inProgress ?? 0),
              selected: true,
              onTap: () => context.go(Routes.employeeProjects),
            ),
          ],
        ),
        AsyncSection(
          value: projects,
          onRetry: () => ref.invalidate(apiProjectsProvider(projectsQuery)),
          builder: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.page.items.isEmpty) EmptyNotice(text: l10n.noRecords),
              for (final p in list.page.items.take(3)) ...[
                ApiProjectCard(project: p),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Localized label for a task status key the server reports in
/// `stats.by_status`; an unknown key is shown as sent.
String serverTaskStatusLabel(AppLocalizations l10n, String key) =>
    switch (key) {
      'backlog' => l10n.backlog,
      'todo' => l10n.toDo,
      'pending' => l10n.statusPending,
      'in_progress' => l10n.statusInProgress,
      'in_review' => l10n.inReview,
      'completed' => l10n.statusCompleted,
      _ => key,
    };
