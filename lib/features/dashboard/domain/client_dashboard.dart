import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/data/local_collection.dart';

enum DashboardPeriod { day, week, month, year }

/// A "label · tag / value" line inside a dashboard summary card.
class DashboardLine {
  const new(this.label, this.tag, this.value);

  final String label;
  final String tag;
  final String value;
}

/// One point of the "Expenditure & Invoiced Trends" chart.
class TrendPoint {
  const new(this.label, this.invoiced, this.settled);

  final String label;
  final double invoiced;
  final double settled;
}

/// Presentation model for the client "Dashboard" frame (643:32669).
///
/// `GET /api/v1/client/dashboard` is in the Postman collection but has no
/// documented response, so this model is only filled by the demo seed and
/// the screen shows a backend-pending notice in API mode.
class ClientDashboard {
  const new({
    required this.overview,
    required this.revenue,
    required this.revenueDelta,
    required this.revenueTarget,
    required this.work,
    required this.trends,
    required this.allocation,
    required this.milestones,
    required this.finance,
  });

  final List<DashboardLine> overview;
  final double revenue;
  final double revenueDelta;
  final double revenueTarget;
  final List<DashboardLine> work;
  final Map<DashboardPeriod, List<TrendPoint>> trends;

  /// Completed / active in sprint / review & QA item counts.
  final (int, int, int) allocation;

  /// Completed / in progress / pending review / total sprints.
  final (int, int, int, int) milestones;
  final List<DashboardLine> finance;

  int get allocationTotal => allocation.$1 + allocation.$2 + allocation.$3;
}

final clientDashboardProvider = Provider<ClientDashboard?>((ref) {
  if (!ref.watch(demoModeProvider)) return null;
  return const ClientDashboard(
    overview: [
      DashboardLine('Entities & Teams', '2 Linked', 'Apex Labs, Nova FinCorp'),
      DashboardLine(
        'Billing & Escrow',
        'USD & EUR',
        r'$82,000 processed YTD · All clear',
      ),
      DashboardLine(
        'Active Projects',
        '3 Active',
        'Next release Oct 28 · Sprint 14 in dev',
      ),
      DashboardLine(
        'Support & Comms',
        '3 New',
        'Engineering sync @ 3:00 · 2 unread threads',
      ),
    ],
    revenue: 38450,
    revenueDelta: 14.2,
    revenueTarget: 42000,
    work: [
      DashboardLine('My Active Tasks', '+8 Tasks', '24 — 4 high priority'),
      DashboardLine('Completed Tasks', '+22.5%', '18 — 75% completion'),
      DashboardLine('Logged Hours', '36.5h / 40h', '36.5h — 91% of week'),
    ],
    trends: {
      DashboardPeriod.day: [
        TrendPoint('08', 400, 300),
        TrendPoint('10', 900, 700),
        TrendPoint('12', 650, 600),
        TrendPoint('14', 1300, 1100),
        TrendPoint('16', 1100, 900),
        TrendPoint('18', 1500, 1400),
      ],
      DashboardPeriod.week: [
        TrendPoint('Mon', 3200, 2800),
        TrendPoint('Tue', 4100, 3900),
        TrendPoint('Wed', 3900, 3500),
        TrendPoint('Thu', 5200, 4800),
        TrendPoint('Fri', 4600, 4100),
        TrendPoint('Sat', 6100, 5600),
      ],
      DashboardPeriod.month: [
        TrendPoint('May', 9000, 7800),
        TrendPoint('Jun', 14000, 12500),
        TrendPoint('Jul', 13500, 12800),
        TrendPoint('Aug', 22000, 20500),
        TrendPoint('Sep', 18000, 17000),
        TrendPoint('Oct', 24800, 23500),
      ],
      DashboardPeriod.year: [
        TrendPoint('2021', 42000, 39000),
        TrendPoint('2022', 51000, 47000),
        TrendPoint('2023', 49000, 46000),
        TrendPoint('2024', 66000, 61000),
        TrendPoint('2025', 71000, 69000),
        TrendPoint('2026', 82000, 78500),
      ],
    },
    allocation: (9, 7, 4),
    milestones: (9, 7, 4, 20),
    finance: [
      DashboardLine('Current Balance Due', '', r'$3,500.00 USD'),
      DashboardLine('Aggregated Billed', '6 Invoices Issued', r'$82,000.00'),
      DashboardLine(
        'Settled Disbursements',
        '5 Invoices Fully Paid',
        r'$78,500.00',
      ),
      DashboardLine(
        'Outstanding Receivable',
        '1 Invoice Under Review',
        r'$3,500.00',
      ),
    ],
  );
});
