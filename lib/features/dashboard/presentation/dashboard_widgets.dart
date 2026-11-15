import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/projects/presentation/projects_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Building blocks shared by the client (643:32669) and employee
/// (731:47939) dashboards.

/// Text styles shared by the dashboard cards.
TextStyle get dashTitle =>
    AppTextStyles.mobileLgSemiBold.copyWith(color: AppColors.textPrimary);
TextStyle get dashCaption =>
    AppTextStyles.mobileXsRegular.copyWith(color: AppColors.textSecondary);
TextStyle get dashLabel =>
    AppTextStyles.mobileXsRegular.copyWith(color: AppColors.textPrimary);
TextStyle get dashValue =>
    AppTextStyles.mobileLgSemiBold.copyWith(color: AppColors.textPrimary);

class DashboardSection extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    super.key,
    this.badge,
    this.tone = BadgeTone.info,
    this.caption,
  });

  final String title;
  final String? badge;
  final BadgeTone tone;
  final String? caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ModuleCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: dashTitle),
        if (badge != null) ...[
          const SizedBox(height: 10),
          StatusBadge(label: badge!, tone: tone),
        ],
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(caption!, style: dashCaption),
        ],
        for (final c in _compact(children)) ...[const SizedBox(height: 12), c],
      ],
    ),
  );

  /// Short figures side by side: a run of [LabelValue]s whose values are
  /// all short becomes a two-column grid; sentences stay full width.
  static List<Widget> _compact(List<Widget> children) {
    final out = <Widget>[];
    var run = <LabelValue>[];
    void flush() {
      if (run.length >= 2 && run.every((v) => v.value.length <= 22)) {
        out.add(LabelValueGrid(items: run));
      } else {
        out.addAll(run);
      }
      run = [];
    }

    for (final c in children) {
      if (c is LabelValue) {
        run.add(c);
      } else {
        flush();
        out.add(c);
      }
    }
    flush();
    return out;
  }
}

/// Two short figures per row; an odd last one takes the full row.
class LabelValueGrid extends StatelessWidget {
  const new({required this.items, super.key});

  final List<LabelValue> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: items[i]),
            if (i + 1 < items.length) ...[
              const SizedBox(width: 12),
              Expanded(child: items[i + 1]),
            ],
          ],
        ),
      ],
    ],
  );
}

class LabelValue extends StatelessWidget {
  const new({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: dashLabel),
      const SizedBox(height: 2),
      Text(value, style: dashValue),
    ],
  );
}

/// "Work & Task Allocation" donut card shared by both dashboards.
class AllocationCard extends StatelessWidget {
  const new({required this.allocation, super.key});

  /// Completed / active in sprint / review & QA item counts.
  final (int, int, int) allocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (done, active, review) = allocation;
    final total = done + active + review;
    int pct(int v) => total == 0 ? 0 : (v / total * 100).round();
    return DashboardSection(
      title: l10n.workAllocation,
      badge: l10n.onSchedule,
      tone: BadgeTone.success,
      caption: l10n.deliverableBreakdown,
      children: [
        // The ring beside its legend: one block instead of a 160 px ring
        // above three stacked figures.
        Row(
          children: [
            SizedBox.square(
              dimension: 112,
              child: CustomPaint(
                painter: DonutPainter([
                  (done.toDouble(), ModuleColors.successFg),
                  (active.toDouble(), AppColors.primary),
                  (review.toDouble(), ModuleColors.chartYellow),
                ], thickness: 18),
                child: Center(
                  child: Text(
                    '${pct(done) + pct(active)}%',
                    style: dashValue.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Legend(
                    ModuleColors.successFg,
                    l10n.completedMilestones,
                    l10n.percentItems(pct(done), done),
                  ),
                  const SizedBox(height: 10),
                  _Legend(
                    AppColors.primary,
                    l10n.activeInSprint,
                    l10n.percentItems(pct(active), active),
                  ),
                  const SizedBox(height: 10),
                  _Legend(
                    ModuleColors.chartYellow,
                    l10n.reviewQa,
                    l10n.percentItems(pct(review), review),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const new(this.color, this.label, this.value);

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 10,
        height: 10,
        margin: const EdgeInsetsDirectional.only(top: 4, end: 8),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Expanded(
        child: LabelValue(label: label, value: value),
      ),
    ],
  );
}

/// Ring chart: one arc per (value, color) segment, clockwise from 12 o'clock.
class DonutPainter extends CustomPainter {
  const new(this.segments, {this.thickness = 26});

  final List<(double, Color)> segments;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(thickness / 2);
    final total = segments.fold<double>(0, (s, e) => s + e.$1);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (final (v, c) in segments) {
      final sweep = v / total * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter old) => old.segments != segments;
}

class DashboardGroupHeader extends StatelessWidget {
  const new({required this.title, required this.chips, super.key});

  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: dashTitle),
      const SizedBox(height: 16),
      ChipRow(children: chips),
    ],
  );
}

class DashboardProjectCard extends ConsumerWidget {
  const new({required this.project, super.key});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = project;
    final target = DateTime.now().add(Duration(days: p.daysLeft));
    return ModuleCard(
      key: Key('dash-project-${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(p.name, style: dashTitle)),
              const SizedBox(width: 8),
              StatusBadge(
                label: projectStatusLabel(l10n, p.status),
                tone: projectTone(p.status),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${p.client} • ${p.company}', style: dashCaption),
          const SizedBox(height: 12),
          // Budget and delivery date side by side.
          LabelValueGrid(
            items: [
              LabelValue(
                label: l10n.contractBudget,
                value: money(p.budget, currency: p.currency),
              ),
              LabelValue(
                label: l10n.targetDelivery,
                value: DateFormat.yMMMd(l10n.localeName).format(target),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(l10n.fieldProgress, style: dashCaption)),
              Text(
                '${p.progress}%',
                style: AppTextStyles.mobileXsSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: p.progress / 100,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: ModuleColors.sectionDivider,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                key: Key('dash-view-${p.id}'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.primary,
                  textStyle: AppTextStyles.mobileXsSemiBold,
                ),
                onPressed: () => showProjectDetails(context, p),
                child: Text(l10n.viewDetails),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.edit,
                onPressed: () => openProjectForm(context, existing: p),
                icon: const WfSvg('action_edit', size: 20),
              ),
              IconButton(
                key: Key('dash-delete-${p.id}'),
                tooltip: l10n.delete,
                onPressed: () async {
                  if (await confirmDelete(context, p.name)) {
                    final removed = ref
                        .read(projectsProvider.notifier)
                        .remove(p.id);
                    if (context.mounted) {
                      showLocalOutcome(
                        context,
                        applied: removed,
                        deleted: true,
                      );
                    }
                  }
                },
                icon: const WfSvg('action_delete', size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
