import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/dashboard/data/client_dashboard_repository.dart';
import 'package:workflow_app/features/dashboard/domain/client_dashboard.dart';
import 'package:workflow_app/features/dashboard/presentation/dashboard_widgets.dart';
import 'package:workflow_app/features/finance/data/client_finance_repository.dart';
import 'package:workflow_app/features/finance/domain/finance_models.dart';
import 'package:workflow_app/features/finance/presentation/api_invoices_view.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/finance/presentation/invoices_screen.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/features/projects/presentation/api_projects_view.dart';
import 'package:workflow_app/features/projects/presentation/projects_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

String periodLabel(AppLocalizations l10n, DashboardPeriod p) => switch (p) {
  DashboardPeriod.day => l10n.periodDay,
  DashboardPeriod.week => l10n.periodWeek,
  DashboardPeriod.month => l10n.periodMonth,
  DashboardPeriod.year => l10n.periodYear,
};

/// Figma client "Dashboard" (643:32669).
class ClientDashboardScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.week;
  bool _showInvoiced = true;
  bool _showSettled = true;
  InvoiceStatus? _invoiceStatus;
  String _query = '';

  bool _matches(String text) =>
      _query.trim().isEmpty ||
      text.toLowerCase().contains(_query.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(clientDashboardProvider);
    if (data == null) return const _ApiClientDashboard();
    final projects = ref
        .watch(projectsProvider)
        .where((p) => _matches('${p.name} ${p.client} ${p.company}'))
        .toList();
    final allInvoices = ref.watch(invoicesProvider);
    final invoices =
        allInvoices
            .where((i) => _invoiceStatus == null || i.status == _invoiceStatus)
            .where((i) => _matches('${i.reference} ${i.project} ${i.company}'))
            .toList()
          ..sort((a, b) => b.issueDate.compareTo(a.issueDate));
    final latest = invoices.take(3).toList();

    return ModulePage(
      title: l10n.catDashboard,
      description: l10n.dashboardBody,
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
        ...[
          DashboardSection(
            title: l10n.overviewMetrics,
            badge: l10n.activeHub,
            caption: l10n.kpisTracked(8),
            children: [for (final line in data.overview) _Line(line)],
          ),
          _RevenueCard(data: data),
          DashboardSection(
            title: l10n.workOverview,
            children: [for (final line in data.work) _Line(line)],
          ),
          _TrendCard(
            points: data.trends[_period]!,
            showInvoiced: _showInvoiced,
            showSettled: _showSettled,
            onToggleInvoiced: () => setState(() {
              _showInvoiced = !_showInvoiced || !_showSettled;
            }),
            onToggleSettled: () => setState(() {
              _showSettled = !_showSettled || !_showInvoiced;
            }),
          ),
          AllocationCard(allocation: data.allocation),
          _MilestonesCard(data: data),
          DashboardSection(
            title: l10n.financialSummary,
            badge: l10n.verifiedClientAccount,
            tone: BadgeTone.success,
            children: [for (final line in data.finance) _Line(line)],
          ),
        ],
        DashboardGroupHeader(
          title: l10n.activeClientProjects,
          chips: [
            FilterChipBox(
              label: l10n.runningCount(projects.length),
              selected: true,
              onTap: () => goToProjects(context),
            ),
            FilterChipBox(
              key: const Key('new-milestone'),
              label: '+ ${l10n.newMilestoneRequest}',
              onTap: () => showSnack(context, l10n.backendPending),
            ),
          ],
        ),
        if (projects.isEmpty) EmptyNotice(text: l10n.noRecords),
        for (final p in projects) DashboardProjectCard(project: p),
        DashboardGroupHeader(
          title: l10n.latestInvoices,
          chips: [
            FilterChipBox(
              label: l10n.recentCount(latest.length),
              selected: true,
              onTap: () {},
            ),
            DropdownChip<InvoiceStatus?>(
              value: _invoiceStatus,
              options: const [null, ...InvoiceStatus.values],
              labelOf: (s) =>
                  s == null ? l10n.filterStatus : invoiceStatusLabel(l10n, s),
              onChanged: (s) => setState(() => _invoiceStatus = s),
            ),
            FilterChipBox(
              key: const Key('view-all-invoices'),
              label: l10n.viewAllCount(allInvoices.length),
              onTap: () => context.go(Routes.clientInvoices),
            ),
          ],
        ),
        if (latest.isEmpty) EmptyNotice(text: l10n.noRecords),
        for (final i in latest) _DashboardInvoiceCard(invoice: i),
      ],
    );
  }

  void goToProjects(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const ProjectsScreen()));
}

class _Line extends StatelessWidget {
  const new(this.line);

  final DashboardLine line;

  @override
  Widget build(BuildContext context) => LabelValue(
    label: line.tag.isEmpty ? line.label : '${line.label} · ${line.tag}',
    value: line.value,
  );
}

class _RevenueCard extends StatelessWidget {
  const new({required this.data});

  final ClientDashboard data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pct = (data.revenue / data.revenueTarget * 100).toStringAsFixed(1);
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.monthlyRevenue,
            style: AppTextStyles.mobileBaseSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            money(data.revenue),
            style: AppTextStyles.mobile2xlSemiBold.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          StatusBadge(
            label: '• +${data.revenueDelta}%',
            tone: BadgeTone.success,
            radius: 6,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.revenueTarget(money(data.revenueTarget), pct),
            style: dashCaption,
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const new({
    required this.points,
    required this.showInvoiced,
    required this.showSettled,
    required this.onToggleInvoiced,
    required this.onToggleSettled,
  });

  final List<TrendPoint> points;
  final bool showInvoiced;
  final bool showSettled;
  final VoidCallback onToggleInvoiced;
  final VoidCallback onToggleSettled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final peak = points.reduce((a, b) => a.invoiced >= b.invoiced ? a : b);
    final first = points.first.invoiced;
    final growth = first == 0
        ? 0
        : ((points.last.invoiced - first) / first * 100).round();
    return DashboardSection(
      title: l10n.expenditureTrends,
      badge: l10n.efficiencyDelta('+$growth%'),
      caption: l10n.expenditureTrendsBody,
      children: [
        Wrap(
          spacing: 12,
          children: [
            FilterChipBox(
              key: const Key('series-invoiced'),
              label: l10n.invoicedSeries,
              selected: showInvoiced,
              onTap: onToggleInvoiced,
            ),
            FilterChipBox(
              key: const Key('series-settled'),
              label: l10n.settledSeries,
              selected: showSettled,
              onTap: onToggleSettled,
            ),
          ],
        ),
        Semantics(
          label: l10n.expenditureTrends,
          child: SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendPainter(
                points: points,
                showInvoiced: showInvoiced,
                showSettled: showSettled,
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (final p in points) Text(p.label, style: dashCaption)],
        ),
        Text(
          l10n.peakValue(peak.label, money(peak.invoiced)),
          style: dashLabel,
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const new({
    required this.points,
    required this.showInvoiced,
    required this.showSettled,
  });

  final List<TrendPoint> points;
  final bool showInvoiced;
  final bool showSettled;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = AppColors.borderSubtle;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.1 + i * 0.35);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), grid);
    }
    final maxV = points.map((p) => p.invoiced).reduce(math.max) * 1.1;
    Path curve(double Function(TrendPoint) v) {
      final pts = [
        for (var i = 0; i < points.length; i++)
          Offset(
            size.width * i / (points.length - 1),
            size.height - v(points[i]) / maxV * size.height * 0.9,
          ),
      ];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1];
        final b = pts[i];
        final mx = (a.dx + b.dx) / 2;
        path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
      }
      return path;
    }

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    if (showSettled) {
      canvas.drawPath(
        curve((p) => p.settled),
        stroke(ModuleColors.successFg, 2),
      );
    }
    if (showInvoiced) {
      canvas.drawPath(curve((p) => p.invoiced), stroke(AppColors.primary, 3));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points ||
      old.showInvoiced != showInvoiced ||
      old.showSettled != showSettled;
}

class _MilestonesCard extends StatelessWidget {
  const new({required this.data});

  final ClientDashboard data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (done, progress, review, sprints) = data.milestones;
    final total = done + progress + review;
    int pct(int v) => total == 0 ? 0 : (v / total * 100).round();
    Widget cell(String label, String value) => Expanded(
      child: LabelValue(label: label, value: value),
    );
    return DashboardSection(
      title: l10n.milestoneVelocity,
      badge: l10n.milestonesTotal(total),
      caption: l10n.realtimeOverview,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(l10n.statusCompleted, l10n.achievedValue(done, pct(done))),
            cell(
              l10n.statusInProgress,
              l10n.inDevValue(progress, pct(progress)),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(l10n.pendingReview, l10n.queuedValue(review, pct(review))),
            cell(l10n.totalSprints, l10n.roadmapValue(sprints)),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (done > 0)
                  Expanded(
                    flex: done,
                    child: const ColoredBox(color: ModuleColors.successFg),
                  ),
                if (progress > 0)
                  Expanded(
                    flex: progress,
                    child: const ColoredBox(color: AppColors.primary),
                  ),
                if (review > 0)
                  Expanded(
                    flex: review,
                    child: const ColoredBox(color: ModuleColors.chartYellow),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardInvoiceCard extends StatelessWidget {
  const new({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final i = invoice;
    return ModuleCard(
      key: Key('dash-invoice-${i.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i.reference, style: dashTitle),
          const SizedBox(height: 8),
          Text(
            i.project,
            style: AppTextStyles.mobileBaseRegular.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabelValue(
                  label: l10n.issueDate,
                  value: DateFormat.yMMMd(l10n.localeName).format(i.issueDate),
                ),
              ),
              Expanded(
                child: LabelValue(
                  label: l10n.fieldAmount,
                  value: money(i.amount, currency: i.currency),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(
                  label: invoiceStatusLabel(l10n, i.status),
                  tone: invoiceTone(i.status),
                ),
                TextButton(
                  key: Key('receipt-${i.id}'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: AppTextStyles.mobileXsSemiBold,
                  ),
                  onPressed: () => showSnack(context, l10n.backendPending),
                  child: Text('${l10n.downloadReceipt} ↓'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// API-mode dashboard: the three counts `GET /client/dashboard` returns, then
/// the first page of real projects and invoices. The remaining Figma
/// sections (trends, allocation, milestones, escrow) have no documented
/// source and are not filled with sample data.
class _ApiClientDashboard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(clientDashboardSummaryProvider);
    const projectsQuery = (search: '', status: null, page: 1);
    final projects = ref.watch(apiProjectsProvider(projectsQuery));
    const invoicesQuery = (
      filter: InvoiceFilter.all,
      search: '',
      from: null,
      to: null,
      page: 1,
    );
    final invoices = ref.watch(clientInvoicesProvider(invoicesQuery));
    return ModulePage(
      title: l10n.catDashboard,
      description: l10n.dashboardBody,
      children: [
        AsyncSection(
          value: summary,
          onRetry: () => ref.invalidate(clientDashboardSummaryProvider),
          builder: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MetricCard(
                key: const Key('dash-projects-count'),
                title: l10n.dashProjects,
                value: count(s.projects),
                delta: '—',
              ),
              const SizedBox(height: 16),
              MetricCard(
                title: l10n.dashInProgress,
                value: count(s.inProgress),
                delta: '—',
              ),
              const SizedBox(height: 16),
              MetricCard(
                title: l10n.dashCompleted,
                value: count(s.completed),
                delta: '—',
              ),
              const SizedBox(height: 12),
              Text(l10n.dashLiveOnly, style: dashCaption),
            ],
          ),
        ),
        DashboardGroupHeader(
          title: l10n.activeClientProjects,
          chips: [
            FilterChipBox(
              label: l10n.runningCount(projects.value?.stats.inProgress ?? 0),
              selected: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProjectsScreen()),
              ),
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
        DashboardGroupHeader(
          title: l10n.latestInvoices,
          chips: [
            FilterChipBox(
              key: const Key('view-all-invoices'),
              label: l10n.viewAllCount(invoices.value?.page.total ?? 0),
              onTap: () => context.go(Routes.clientInvoices),
            ),
          ],
        ),
        AsyncSection(
          value: invoices,
          onRetry: () => ref.invalidate(clientInvoicesProvider(invoicesQuery)),
          builder: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.page.items.isEmpty) EmptyNotice(text: l10n.noRecords),
              for (final i in list.page.items.take(3)) ...[
                ApiInvoiceCard(
                  invoice: i,
                  currency: list.currencies[i.currencyId],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
