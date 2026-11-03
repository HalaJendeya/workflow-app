import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/data/local_collection.dart';

/// One month of the "Revenue Trajectory" bars.
class RevenueMonth {
  const new(this.label, this.actual, this.target);

  final String label;
  final double actual;
  final double target;
}

/// Presentation model for the employee "Dashboard" frame (731:47939).
///
/// Task counts and the active-task list come from the task collection; the
/// figures below have no documented source (`GET /api/v1/employee/dashboard`
/// lists no response fields), so they are only filled by the demo seed.
class EmployeeDashboard {
  const new({
    required this.revenue,
    required this.revenueDelta,
    required this.revenueTarget,
    required this.dailyHours,
    required this.dailyTarget,
    required this.weeklyTarget,
    required this.hoursDelta,
    required this.focusRate,
    required this.timesheetApproved,
    required this.revenueMonths,
    required this.revenueYoY,
    required this.allocation,
    required this.sprint,
    required this.sprintEtaDays,
  });

  final double revenue;
  final double revenueDelta;
  final double revenueTarget;

  /// Monday → Sunday logged hours.
  final List<double> dailyHours;
  final double dailyTarget;
  final double weeklyTarget;
  final double hoursDelta;
  final double focusRate;
  final bool timesheetApproved;
  final List<RevenueMonth> revenueMonths;
  final int revenueYoY;
  final (int, int, int) allocation;
  final String sprint;
  final int sprintEtaDays;

  double get loggedHours => dailyHours.fold(0, (s, h) => s + h);

  double get averageDaily {
    final worked = dailyHours.where((h) => h > 0);
    return worked.isEmpty ? 0 : loggedHours / worked.length;
  }
}

final employeeDashboardProvider = Provider<EmployeeDashboard?>((ref) {
  if (!ref.watch(demoModeProvider)) return null;
  return const EmployeeDashboard(
    revenue: 38450,
    revenueDelta: 14.2,
    revenueTarget: 42000,
    dailyHours: [6.2, 8.4, 7.5, 9, 5.4, 0, 0],
    dailyTarget: 8,
    weeklyTarget: 40,
    hoursDelta: 4.5,
    focusRate: 86.4,
    timesheetApproved: true,
    revenueMonths: [
      RevenueMonth('Jan', 21000, 24000),
      RevenueMonth('Feb', 26000, 25000),
      RevenueMonth('Mar', 38450, 30000),
      RevenueMonth('Apr', 0, 32000),
      RevenueMonth('May', 0, 34000),
    ],
    revenueYoY: 18,
    allocation: (9, 7, 4),
    sprint: 'Sprint cycle 4',
    sprintEtaDays: 3,
  );
});
