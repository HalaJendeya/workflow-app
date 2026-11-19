// Live, read-only smoke of the client repositories against the real
// backend. Skipped unless WF_LIVE_CLIENT_TOKEN is set for this run (never
// stored in the repo, never an employee token: the client role's own
// authorization is what this checks). Only GET routes are called — no
// join, read mark, payment, or any other write. It prints counts, flags
// and CSV column counts only, never tokens, names, emails or amounts.
//
//   $env:WF_LIVE_CLIENT_TOKEN = '<client bearer>'
//   $env:WF_LIVE_COMPANY = '<company id, optional>'
//   flutter test test/live/client_live_smoke_test.dart
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/companies/data/client_companies_repository.dart';
import 'package:workflow_app/features/conversations/data/conversations_repository.dart';
import 'package:workflow_app/features/dashboard/data/client_dashboard_repository.dart';
import 'package:workflow_app/features/finance/data/client_finance_repository.dart';
import 'package:workflow_app/features/meetings/data/meeting_collaboration_repository.dart';
import 'package:workflow_app/features/meetings/data/meetings_repository.dart';
import 'package:workflow_app/features/notifications/data/notifications_repository.dart';
import 'package:workflow_app/features/profile/data/profile_repository.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';

class _Creds implements ApiCredentials {
  const new(this.token, this.companyId);
  @override
  final String? token;
  @override
  final int? companyId;
  @override
  void onUnauthorized() => fail('401: the live client token was rejected');
}

void main() {
  final env = Platform.environment;
  final token = env['WF_LIVE_CLIENT_TOKEN'];
  final skip = token == null || token.isEmpty
      ? 'WF_LIVE_CLIENT_TOKEN not set (live client smoke only)'
      : null;
  final base = env['WF_LIVE_BASE'] ?? 'https://api.workflownets.com';
  final company = int.tryParse(env['WF_LIVE_COMPANY'] ?? '');

  late ApiClient client;
  setUpAll(() {
    client = ApiClient(baseUrl: base, credentials: _Creds(token, company));
  });

  void log(String s) => stdout.writeln('[live-client] $s');

  test('profile answers on the client portal', () async {
    final p = await ApiProfileRepository(client, Portal.client).fetch();
    expect(p, isNotNull);
    log('profile ok');
  }, skip: skip);

  test('dashboard counts', () async {
    final d = await ClientDashboardRepository(client).summary();
    expect(d, isNotNull);
    log('dashboard ok');
  }, skip: skip);

  test('my companies', () async {
    final list = await ClientCompaniesRepository(client).list();
    log('companies=${list.length}');
  }, skip: skip);

  test('projects list and every details screen on page 1', () async {
    final r = ProjectsRepository(client, Portal.client);
    final list = await r.list((search: '', status: null, page: 1));
    for (final p in list.page.items) {
      expect((await r.show(p.id)).id, p.id);
    }
    log('projects total=${list.page.total} details=${list.page.items.length}');
  }, skip: skip);

  test('invoices: list, every details, filters the app sends', () async {
    final r = ClientFinanceRepository(client);
    final list = await r.invoices(defaultInvoiceQuery);
    for (final i in list.page.items) {
      expect((await r.invoice(i.id)).id, i.id);
    }
    for (final f in InvoiceFilter.values) {
      await r.invoices((
        filter: f,
        sort: InvoiceSort.newest,
        search: '',
        from: null,
        to: null,
        projectId: null,
        page: 1,
      ));
    }
    for (final s in InvoiceSort.values) {
      await r.invoices((
        filter: InvoiceFilter.all,
        sort: s,
        search: '',
        from: null,
        to: null,
        projectId: null,
        page: 1,
      ));
    }
    log(
      'invoices total=${list.stats.total} rows=${list.page.items.length} '
      'currencies=${list.currencies.length}',
    );
  }, skip: skip);

  test('payments: list and status filters', () async {
    final r = ClientFinanceRepository(client);
    final list = await r.payments(defaultPaymentQuery);
    for (final s in PaymentStatusFilter.values) {
      await r.payments((status: s, search: '', from: null, page: 1));
    }
    log('payments total=${list.count} rows=${list.page.items.length}');
  }, skip: skip);

  test('CSV exports (read-only GET): BOM, header, rows', () async {
    final r = ClientFinanceRepository(client);
    for (final (name, file) in [
      ('invoices', await r.invoicesCsv(defaultInvoiceQuery)),
      ('payments', await r.paymentsCsv(defaultPaymentQuery)),
    ]) {
      final b = file.bytes;
      final bom = b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF;
      final text = utf8.decode(bom ? b.sublist(3) : b, allowMalformed: true);
      final lines = const LineSplitter()
          .convert(text)
          .where((l) => l.isNotEmpty)
          .toList();
      final columns = lines.isEmpty ? 0 : lines.first.split(',').length;
      log(
        '$name export bom=$bom columns=$columns '
        'data lines=${lines.isEmpty ? 0 : lines.length - 1}',
      );
    }
  }, skip: skip);

  test('payment details route (contract probe, read-only)', () async {
    // Only data.id is documented; this records which keys the live server
    // returns so the contract can be completed. Key names only.
    final r = ClientFinanceRepository(client);
    final list = await r.payments(defaultPaymentQuery);
    if (list.page.items.isEmpty) {
      log('payment details: BLOCKED — no payment on this account');
      return;
    }
    final id = list.page.items.first.id;
    final res = await client.get('/api/v1/client/payments/$id');
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    final keys = data is Map
        ? (data.keys.map((k) => '$k').toList()..sort()).join(',')
        : '${data.runtimeType}';
    log('payment details keys=$keys');
  }, skip: skip);

  test('meetings, participants, my invitations', () async {
    final r = MeetingsRepository(client, Portal.client);
    final page = await r.list((search: '', status: null, page: 1));
    for (final m in page.items) {
      await r.get(m.id);
      await r.participants(m.id);
    }
    final inv = await r.myInvitations();
    log('meetings=${page.items.length} my invitations=${inv.items.length}');
  }, skip: skip);

  test('meeting collaboration (C3): read-only, participants only', () async {
    // Live rule (employee role, 2026-11-19): a meeting the caller has not
    // joined answers 403 "must be a participant". Counts and key names
    // only; no message, poll, note or file content is printed.
    final meetings = await MeetingsRepository(
      client,
      Portal.client,
    ).list((search: '', status: null, page: 1));
    final c = MeetingCollaborationRepository(client, Portal.client);
    var forbidden = 0;
    for (final m in meetings.items) {
      final reads = <String, Future<Object?> Function()>{
        'messages': () => c.messages(m.id),
        'polls': () => c.polls(m.id),
        'notes': () => c.notes(m.id),
        'decisions': () => c.decisions(m.id),
        'action-items': () => c.actionItems(m.id),
      };
      for (final MapEntry(:key, :value) in reads.entries) {
        try {
          final r = await value();
          final n = switch (r) {
            final List<Object?> l => l.length,
            final MeetingMessagePage p => p.items.length,
            _ => 0,
          };
          log('meeting $key rows=$n');
          if (key == 'messages' && n > 0) {
            final raw = await client.get(
              '/api/v1/client/meetings/${m.id}/messages',
              query: {'per_page': 1},
            );
            final body = raw.data;
            final rows = body is Map && body['data'] is Map
                ? (body['data'] as Map)['data']
                : null;
            if (rows is List && rows.isNotEmpty && rows.first is Map) {
              final keys = (rows.first as Map).keys.map((k) => '$k').toList()
                ..sort();
              log('message row keys=${keys.join(',')}');
            }
          }
        } on ApiException catch (e) {
          if (e.statusCode != 403) rethrow;
          forbidden++;
        }
      }
    }
    log(
      'collaboration: meetings=${meetings.items.length} '
      'not-a-participant (403)=$forbidden',
    );
  }, skip: skip);

  test('conversations, messages, available users', () async {
    final r = ConversationsRepository(client, Portal.client);
    final list = await r.list();
    for (final c in list) {
      await r.open(c.id);
      await r.messages(c.id);
    }
    await r.availableUsers();
    log('conversations=${list.length}');
  }, skip: skip);

  test('notifications and unread count', () async {
    final r = ApiNotificationsRepository(client, Portal.client);
    final inbox = await r.list();
    final unread = await r.unreadCount();
    expect(inbox.unreadCount, unread);
    log('notifications items=${inbox.items.length} unread=$unread');
  }, skip: skip);

  test('client routes refuse what the client may not see', () async {
    Future<int?> status(String path) async {
      try {
        await client.get(path);
        return 200;
      } on ApiException catch (e) {
        return e.statusCode;
      }
    }

    expect(await status('/api/v1/employee/account'), 403);
    expect(await status('/api/v1/client/projects/999999999'), 404);
    expect(await status('/api/v1/client/invoices/999999999'), anyOf(403, 404));
    expect(await status('/api/v1/client/payments/999999999'), anyOf(403, 404));
    log('role and not-found boundaries ok');
  }, skip: skip);
}
