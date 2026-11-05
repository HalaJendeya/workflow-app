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
          const SizedBox(height: 16),
          StatusBadge(label: badge!, tone: tone),
        ],
        if (caption != null) ...[
          const SizedBox(height: 12),
          Text(caption!, style: dashCaption),
        ],
        for (final c in children) ...[const SizedBox(height: 16), c],
      ],
    ),
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
        Center(
          child: SizedBox.square(
            dimension: 160,
            child: CustomPaint(
              painter: DonutPainter([
                (done.toDouble(), ModuleColors.successFg),
                (active.toDouble(), AppColors.primary),
                (review.toDouble(), ModuleColors.chartYellow),
              ]),
              child: Center(
                child: Text(
                  '${pct(done) + pct(active)}%',
                  style: AppTextStyles.choiceTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        LabelValue(
          label: l10n.completedMilestones,
          value: l10n.percentItems(pct(done), done),
        ),
        LabelValue(
          label: l10n.activeInSprint,
          value: l10n.percentItems(pct(active), active),
        ),
        LabelValue(
          label: l10n.reviewQa,
          value: l10n.percentItems(pct(review), review),
        ),
      ],
    );
  }
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
          Text(p.name, style: dashTitle),
          const SizedBox(height: 8),
          Text('${p.client} • ${p.company}', style: dashCaption),
          const SizedBox(height: 16),
          StatusBadge(
            label: projectStatusLabel(l10n, p.status),
            tone: projectTone(p.status),
          ),
          const SizedBox(height: 16),
          LabelValue(
            label: l10n.contractBudget,
            value: money(p.budget, currency: p.currency),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          LabelValue(
            label: l10n.targetDelivery,
            value: DateFormat.yMMMd(l10n.localeName).format(target),
          ),
          const SizedBox(height: 8),
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
