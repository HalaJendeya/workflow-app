// Live, read-only smoke of the employee repositories against the real
// backend. Skipped unless WF_LIVE_TOKEN is set for this run (never stored
// in the repo). Only GET routes are called. It prints counts and flags,
// never tokens, names, emails or amounts.
//
//   $env:WF_LIVE_TOKEN = '<bearer>'; $env:WF_LIVE_USER = '<users.id>'
//   flutter test test/live/employee_live_smoke_test.dart
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/data/conversations_repository.dart';
import 'package:workflow_app/features/meetings/data/meetings_repository.dart';
import 'package:workflow_app/features/notifications/data/notifications_repository.dart';
import 'package:workflow_app/features/profile/data/profile_repository.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/employee_work_repository.dart';
import 'package:workflow_app/features/work/data/work_options.dart';

class _Creds implements ApiCredentials {
  const new(this.token, this.companyId);
  @override
  final String? token;
  @override
  final int? companyId;
  @override
  void onUnauthorized() => fail('401: the live token was rejected');
}

void main() {
  final env = Platform.environment;
  final token = env['WF_LIVE_TOKEN'];
  final skip = token == null || token.isEmpty
      ? 'WF_LIVE_TOKEN not set (live smoke only)'
      : null;
  final base = env['WF_LIVE_BASE'] ?? 'https://api.workflownets.com';
  final company = int.tryParse(env['WF_LIVE_COMPANY'] ?? '');
  final user = int.tryParse(env['WF_LIVE_USER'] ?? '');

  late ApiClient client;
  setUpAll(() {
    client = ApiClient(baseUrl: base, credentials: _Creds(token, company));
  });

  void log(String s) => stdout.writeln('[live] $s');

  test('profile', () async {
    final p = await ApiProfileRepository(client, Portal.employee).fetch();
    expect(p, isNotNull);
    log('profile ok');
  }, skip: skip);

  test('dashboard, task figures, timesheets summary', () async {
    final r = EmployeeWorkRepository(client);
    await r.dashboard();
    final all = await r.taskStats();
    final mine = await r.taskStats(assignedTo: user);
    final ts = await r.timesheets();
    log(
      'stats all=${all.total} mine=${mine.total} '
      'timesheets=${ts.count} currencies=${ts.money.length}',
    );
  }, skip: skip);

  test('projects list, details and options', () async {
    final r = ProjectsRepository(client, Portal.employee);
    final list = await r.list((search: '', status: null, page: 1));
    log('projects page items=${list.page.items.length}');
    for (final p in list.page.items) {
      await r.show(p.id);
    }
    final o = WorkOptionsRepository(client);
    final all = await o.projects();
    final led = await o.projects(led: true);
    log('options=${all.length} led=${led.length}');
    for (final p in all) {
      await o.sprints(p.id);
    }
    await o.people();
  }, skip: skip);

  test('tasks: mine, team, every details screen', () async {
    final r = BoardRepository(client);
    final mine = await r.tasks(const TaskQuery(), assignedTo: user);
    final team = await r.tasks(const TaskQuery(scope: TaskScope.team));
    log(
      'my rows=${mine.page.items.length} hidden=${mine.hidden} '
      'team rows=${team.page.items.length}',
    );
    for (final row in team.page.items) {
      final d = await r.task(row.id);
      expect(d.id, row.id);
      expect(d.status, row.status);
      expect(d.assigneeId, row.assigneeId);
      expect(d.projectId, row.projectId);
      expect(d.sprintId, row.sprintId);
    }
    log('details parsed=${team.page.items.length}');
  }, skip: skip);

  test('board and planning', () async {
    final r = BoardRepository(client);
    final k = await r.kanban();
    final p = await r.planning();
    log('board tasks=${k.tasks.length} sprints=${p.sprints.length}');
  }, skip: skip);

  test('meetings, participants, invitations', () async {
    final r = MeetingsRepository(client, Portal.employee);
    final page = await r.list((search: '', status: null, page: 1));
    for (final m in page.items) {
      await r.get(m.id);
      await r.participants(m.id);
      await r.invitations(m.id);
    }
    final inv = await r.myInvitations();
    log('meetings=${page.items.length} my invitations=${inv.items.length}');
  }, skip: skip);

  test('conversations, messages, available users', () async {
    final r = ConversationsRepository(client, Portal.employee);
    final list = await r.list();
    for (final c in list) {
      await r.open(c.id);
      final m = await r.messages(c.id);
      log('conversation messages=${m.messages.length} more=${m.hasMore}');
    }
    await r.availableUsers();
    log('conversations=${list.length}');
  }, skip: skip);

  test('notifications and unread count', () async {
    final r = ApiNotificationsRepository(client, Portal.employee);
    final inbox = await r.list();
    final unread = await r.unreadCount();
    expect(inbox.unreadCount, unread);
    log('notifications items=${inbox.items.length} unread=$unread');
  }, skip: skip);
}
