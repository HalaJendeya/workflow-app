import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';

/// Server-derived invoice status. The stored column is `unpaid|paid`; lists
/// return the derived `unpaid|partially_paid|paid` (collection, 2026-10-22).
enum ApiInvoiceStatus { unpaid, partiallyPaid, paid }

/// `status` filter accepted by `GET /client/invoices`:
/// `paid|unpaid|partially_paid|overdue|all` (a bad value is a 422).
enum InvoiceFilter { all, paid, unpaid, partiallyPaid, overdue }

String _wire(Enum e) => switch (e) {
  ApiInvoiceStatus.partiallyPaid ||
  InvoiceFilter.partiallyPaid => 'partially_paid',
  _ => e.name,
};

/// One row of `GET /api/v1/client/invoices`, limited to the fields in the
/// collection's saved 200 example ("derived status, amounts, is_overdue and
/// stats"). The API returns ids only for client, project and currency.
class InvoiceRecord {
  const new({
    required this.id,
    required this.projectId,
    required this.currencyId,
    required this.invoiceDate,
    required this.dueDate,
    required this.amount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    required this.isOverdue,
  });

  factory fromJson(Json j) {
    final id = asInt(j['id']) ?? missingField('id');
    final amount = asDouble(j['amount']) ?? missingField('amount');
    final status = switch (j['status']) {
      'paid' => ApiInvoiceStatus.paid,
      'partially_paid' => ApiInvoiceStatus.partiallyPaid,
      'unpaid' => ApiInvoiceStatus.unpaid,
      _ => missingField('status'),
    };
    return InvoiceRecord(
      id: id,
      projectId: asInt(j['project_id']),
      currencyId: asInt(j['currency_id']),
      invoiceDate: asDate(j['invoice_date']) ?? missingField('invoice_date'),
      dueDate: asDate(j['due_date']),
      amount: amount,
      paidAmount: asDouble(j['paid_amount']) ?? 0,
      remainingAmount: asDouble(j['remaining_amount']) ?? amount,
      status: status,
      isOverdue: j['is_overdue'] == true,
    );
  }

  final int id;
  final int? projectId;
  final int? currencyId;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final double amount;
  final double paidAmount;
  final double remainingAmount;
  final ApiInvoiceStatus status;
  final bool isOverdue;
}

/// `totals[]` row: maps a `currency_id` to its code and symbol.
class CurrencyRef {
  const new({required this.code, required this.symbol});

  final String code;
  final String symbol;
}

Map<int?, CurrencyRef> _currencies(Object? totals) => {
  if (totals is List)
    for (final t in totals.whereType<Json>())
      if (t['code'] is String)
        asInt(t['currency_id']): CurrencyRef(
          code: t['code'] as String,
          symbol: (t['symbol'] as String?) ?? t['code'] as String,
        ),
};

/// `stats {total, paid, unpaid, partially_paid, overdue}`. They ignore the
/// `status` filter so tab counts stay put.
class InvoiceStats {
  const new({
    required this.total,
    required this.paid,
    required this.unpaid,
    required this.partiallyPaid,
    required this.overdue,
  });

  factory fromJson(Object? j) {
    final m = j is Json ? j : const <String, dynamic>{};
    int n(String k) => asInt(m[k]) ?? 0;
    return InvoiceStats(
      total: n('total'),
      paid: n('paid'),
      unpaid: n('unpaid'),
      partiallyPaid: n('partially_paid'),
      overdue: n('overdue'),
    );
  }

  final int total;
  final int paid;
  final int unpaid;
  final int partiallyPaid;
  final int overdue;
}

class InvoiceList {
  const new({
    required this.page,
    required this.stats,
    required this.currencies,
  });

  final ApiPage<InvoiceRecord> page;
  final InvoiceStats stats;
  final Map<int?, CurrencyRef> currencies;
}

/// Per-currency money row of `totals[]` on `GET /client/payments`
/// (`{currency_id|null, code, symbol, received, pending, paid_out}`).
class PaymentTotal {
  const new({
    required this.code,
    required this.symbol,
    required this.received,
    required this.pending,
  });

  final String code;
  final String symbol;
  final double received;
  final double pending;
}

/// Payment summary: `stats.total` (count, confirmed on the live server) and
/// money per currency from `totals[]`. `stats` amounts are not used because
/// they carry no currency.
class PaymentSummary {
  const new({required this.count, required this.totals});

  final int count;
  final List<PaymentTotal> totals;
}

/// Query for the invoice list; a record so it works as a provider key.
typedef InvoiceQuery = ({
  InvoiceFilter filter,
  String search,
  DateTime? from,
  DateTime? to,
  int page,
});

/// `05 Client / 04 Invoices` and `05 Client / 05 Payments` (read-only: the
/// client role has no create, update or delete routes for either).
class ClientFinanceRepository {
  new(this._client);

  final ApiClient _client;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<InvoiceList> invoices(InvoiceQuery q) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '/api/v1/client/invoices',
        query: {
          'page': q.page,
          'per_page': 15,
          'status': _wire(q.filter),
          if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
          if (q.from != null) 'from': _day(q.from!),
          if (q.to != null) 'to': _day(q.to!),
        },
      ),
    );
    final data = body['data'] as Json;
    return InvoiceList(
      page: ApiPage.parse(data, InvoiceRecord.fromJson),
      stats: InvoiceStats.fromJson(data['stats'] ?? body['stats']),
      currencies: _currencies(body['totals']),
    );
  }

  Future<PaymentSummary> paymentSummary() async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get('/api/v1/client/payments', query: {'per_page': 1}),
    );
    final stats = body['stats'];
    if (stats is! Json) missingField('stats');
    final totals = body['totals'];
    return PaymentSummary(
      count: asInt(stats['total']) ?? missingField('stats.total'),
      totals: [
        if (totals is List)
          for (final t in totals.whereType<Json>())
            PaymentTotal(
              code: (t['code'] as String?) ?? '',
              symbol: (t['symbol'] as String?) ?? (t['code'] as String?) ?? '',
              received: asDouble(t['received']) ?? 0,
              pending: asDouble(t['pending']) ?? 0,
            ),
      ],
    );
  }
}

final clientFinanceRepositoryProvider = Provider<ClientFinanceRepository>(
  (ref) => ClientFinanceRepository(ref.watch(apiClientProvider)),
);

final FutureProviderFamily<InvoiceList, InvoiceQuery> clientInvoicesProvider =
    FutureProvider.autoDispose.family<InvoiceList, InvoiceQuery>(
      (ref, q) => ref.watch(clientFinanceRepositoryProvider).invoices(q),
    );

final FutureProvider<PaymentSummary> clientPaymentSummaryProvider =
    FutureProvider.autoDispose<PaymentSummary>(
      (ref) => ref.watch(clientFinanceRepositoryProvider).paymentSummary(),
    );
