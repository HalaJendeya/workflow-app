import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/network/api_client.dart';
import 'package:workflow_app/core/network/api_page.dart';
import 'package:workflow_app/core/network/api_response.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';

/// Server-derived invoice status. The stored column is `unpaid|paid`; lists
/// return the derived `unpaid|partially_paid|paid` (collection, 2026-10-22).
enum ApiInvoiceStatus { unpaid, partiallyPaid, paid }

/// `status` filter accepted by `GET /client/invoices`:
/// `paid|unpaid|partially_paid|overdue|all` (a bad value is a 422).
enum InvoiceFilter { all, paid, unpaid, partiallyPaid, overdue }

/// `sort` of `GET /client/invoices` (`invoice_date`, `created_at`,
/// `due_date`, `amount`, `status`; `-` = descending). The four the screen
/// offers, with their wire values.
enum InvoiceSort {
  newest('-invoice_date'),
  oldest('invoice_date'),
  dueSoonest('due_date'),
  highestAmount('-amount');

  new(this.wire);
  final String wire;
}

String _wire(Enum e) => switch (e) {
  ApiInvoiceStatus.partiallyPaid ||
  InvoiceFilter.partiallyPaid => 'partially_paid',
  _ => e.name,
};

/// One invoice of `GET /client/invoices` or `GET /client/invoices/{id}`.
///
/// Fields are those of the collection's saved 200 example ("derived status,
/// amounts, is_overdue and stats"). Every money field and the overdue flag
/// is required: a missing value is an invalid response, never a made-up 0,
/// full balance or `false`. The API returns ids only for project and
/// currency.
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
    final overdue = j['is_overdue'];
    return InvoiceRecord(
      id: asInt(j['id']) ?? missingField('id'),
      projectId: asInt(j['project_id']),
      currencyId: asInt(j['currency_id']),
      invoiceDate: asDate(j['invoice_date']) ?? missingField('invoice_date'),
      dueDate: asDate(j['due_date']),
      amount: asDouble(j['amount']) ?? missingField('amount'),
      paidAmount: asDouble(j['paid_amount']) ?? missingField('paid_amount'),
      remainingAmount:
          asDouble(j['remaining_amount']) ?? missingField('remaining_amount'),
      status: switch (j['status']) {
        'paid' => ApiInvoiceStatus.paid,
        'partially_paid' => ApiInvoiceStatus.partiallyPaid,
        'unpaid' => ApiInvoiceStatus.unpaid,
        _ => missingField('status'),
      },
      isOverdue: overdue is bool ? overdue : missingField('is_overdue'),
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

/// `totals[]` of the invoice and payment lists. `code` is documented on
/// every row; a row without it is invalid rather than skipped.
Map<int?, CurrencyRef> _currencies(Object? totals) {
  if (totals is! List) missingField('totals');
  return {
    for (final t in totals.whereType<Json>())
      asInt(t['currency_id']): _currency(t),
  };
}

CurrencyRef _currency(Json t) {
  final code = t['code'];
  if (code is! String || code.isEmpty) missingField('totals[].code');
  final symbol = t['symbol'];
  return CurrencyRef(
    code: code,
    symbol: symbol is String && symbol.isNotEmpty ? symbol : code,
  );
}

/// `stats {total, paid, unpaid, partially_paid, overdue}`. They ignore the
/// `status` filter so tab counts stay put. All five are required.
class InvoiceStats {
  const new({
    required this.total,
    required this.paid,
    required this.unpaid,
    required this.partiallyPaid,
    required this.overdue,
  });

  factory fromJson(Object? j) {
    if (j is! Json) missingField('stats');
    int n(String k) => asInt(j[k]) ?? missingField('stats.$k');
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

  factory fromJson(Json t) {
    final c = _currency(t);
    return PaymentTotal(
      code: c.code,
      symbol: c.symbol,
      received: asDouble(t['received']) ?? missingField('totals[].received'),
      pending: asDouble(t['pending']) ?? missingField('totals[].pending'),
    );
  }

  final String code;
  final String symbol;
  final double received;
  final double pending;
}

/// `direction` of a payment row (collection, 2026-10-26).
enum ApiPaymentDirection { incoming, outgoing }

/// One row of `GET /client/payments`. Fields are those of the saved 200
/// example of the same controller (`PaymentController@index`, company admin
/// folder): `id`, `invoice_id`, `wallet_id`, `amount`, `payment_method`,
/// `payment_date`, plus `direction`, which the client route documents. A
/// row's status and currency are not part of the example and are not read.
class PaymentRecord {
  const new({
    required this.id,
    required this.amount,
    required this.date,
    this.invoiceId,
    this.method,
    this.direction,
  });

  factory fromJson(Json j) => PaymentRecord(
    id: asInt(j['id']) ?? missingField('id'),
    amount: asDouble(j['amount']) ?? missingField('amount'),
    date: asDate(j['payment_date']) ?? missingField('payment_date'),
    invoiceId: asInt(j['invoice_id']),
    method: j['payment_method'] is String && j['payment_method'] != ''
        ? j['payment_method'] as String
        : null,
    direction: switch (j['direction']) {
      'incoming' => ApiPaymentDirection.incoming,
      'outgoing' => ApiPaymentDirection.outgoing,
      _ => null,
    },
  );

  final int id;
  final double amount;
  final DateTime date;
  final int? invoiceId;
  final String? method;
  final ApiPaymentDirection? direction;
}

/// `status` filter of `GET /client/payments` (`confirmed|pending`).
enum PaymentStatusFilter { all, confirmed, pending }

class PaymentList {
  const new({required this.page, required this.count, required this.totals});

  final ApiPage<PaymentRecord> page;

  /// `stats.total`.
  final int count;
  final List<PaymentTotal> totals;

  /// The currency every row is in, when the totals name exactly one. Rows
  /// carry no currency, so with several currencies none is assumed.
  PaymentTotal? get onlyCurrency => totals.length == 1 ? totals.single : null;
}

/// Query for the invoice list; a record so it works as a provider key.
typedef InvoiceQuery = ({
  InvoiceFilter filter,
  InvoiceSort sort,
  String search,
  DateTime? from,
  DateTime? to,
  int? projectId,
  int page,
});

/// The list's first page with no filters (dashboard, first open).
const InvoiceQuery defaultInvoiceQuery = (
  filter: InvoiceFilter.all,
  sort: InvoiceSort.newest,
  search: '',
  from: null,
  to: null,
  projectId: null,
  page: 1,
);

typedef PaymentQuery = ({
  PaymentStatusFilter status,
  String search,
  DateTime? from,
  int page,
});

const PaymentQuery defaultPaymentQuery = (
  status: PaymentStatusFilter.all,
  search: '',
  from: null,
  page: 1,
);

/// A project the invoice filter can offer: `id` and `title` of
/// `GET /client/projects`.
typedef ProjectOption = ({int id, String title});

/// A page of the project picker: the typed search and the page number.
typedef ProjectSearch = ({String search, int page});

const projectSearchPageSize = 20;

/// `05 Client / 04 Invoices` and `05 Client / 05 Payments`. Read-only:
/// paying an invoice (`POST /pay`, Stripe Checkout) is not part of this
/// repository; the client has no create, update or delete routes.
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
          'sort': q.sort.wire,
          if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
          if (q.from != null) 'from': _day(q.from!),
          if (q.to != null) 'to': _day(q.to!),
          'project_id': ?q.projectId,
        },
      ),
    );
    final data = body['data'];
    if (data is! Json) missingField('data');
    return InvoiceList(
      page: ApiPage.parse(data, InvoiceRecord.fromJson),
      stats: InvoiceStats.fromJson(data['stats'] ?? body['stats']),
      currencies: _currencies(body['totals']),
    );
  }

  /// `GET /client/invoices/{id}`: the invoice is `data` (the collection's
  /// test asserts `data.id`). 403 / 404 for an invoice the client may not
  /// see.
  Future<InvoiceRecord> invoice(int id) async => InvoiceRecord.fromJson(
    ApiEnvelope.unwrapObject(await _client.get('/api/v1/client/invoices/$id')),
  );

  Future<PaymentList> payments(PaymentQuery q) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '/api/v1/client/payments',
        query: {
          'page': q.page,
          if (q.status != PaymentStatusFilter.all) 'status': q.status.name,
          if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
          if (q.from != null) 'from': _day(q.from!),
        },
      ),
    );
    final data = body['data'];
    if (data is! Json) missingField('data');
    final stats = body['stats'];
    if (stats is! Json) missingField('stats');
    final totals = body['totals'];
    if (totals is! List) missingField('totals');
    return PaymentList(
      page: ApiPage.parse(data, PaymentRecord.fromJson),
      count: asInt(stats['total']) ?? missingField('stats.total'),
      totals: [
        for (final t in totals.whereType<Json>()) PaymentTotal.fromJson(t),
      ],
    );
  }

  /// One page of the client's projects for the invoice project filter:
  /// `GET /client/projects` with its documented server-side `search` and
  /// `page`. Pages are small and loaded on demand, so no eligible project is
  /// left out and nothing is downloaded up front.
  Future<ApiPage<ProjectOption>> searchProjects(ProjectSearch q) async {
    final body = ApiEnvelope.unwrapBody(
      await _client.get(
        '/api/v1/client/projects',
        query: {
          'page': q.page,
          'per_page': projectSearchPageSize,
          if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
        },
      ),
    );
    final data = body['data'];
    if (data is! Json) missingField('data');
    return ApiPage<ProjectOption>.parse(data, (j) {
      final title = j['title'];
      return (
        id: asInt(j['id']) ?? missingField('id'),
        title: title is String ? title : missingField('title'),
      );
    });
  }
}

final clientFinanceRepositoryProvider = Provider<ClientFinanceRepository>(
  (ref) => ClientFinanceRepository(ref.watch(apiClientProvider)),
);

/// Financial data belongs to one account in one company: every finance
/// provider is rebuilt when either changes, so another account or company
/// never sees it.
void _scope(Ref ref) => ref.watch(
  sessionControllerProvider.select(
    (s) => (s.value?.userId, s.value?.companyId),
  ),
);

final FutureProviderFamily<InvoiceList, InvoiceQuery> clientInvoicesProvider =
    FutureProvider.autoDispose.family<InvoiceList, InvoiceQuery>((ref, q) {
      _scope(ref);
      return ref.watch(clientFinanceRepositoryProvider).invoices(q);
    });

final FutureProviderFamily<InvoiceRecord, int> clientInvoiceProvider =
    FutureProvider.autoDispose.family<InvoiceRecord, int>((ref, id) {
      _scope(ref);
      return ref.watch(clientFinanceRepositoryProvider).invoice(id);
    });

final FutureProviderFamily<PaymentList, PaymentQuery> clientPaymentsProvider =
    FutureProvider.autoDispose.family<PaymentList, PaymentQuery>((ref, q) {
      _scope(ref);
      return ref.watch(clientFinanceRepositoryProvider).payments(q);
    });

final FutureProviderFamily<ApiPage<ProjectOption>, ProjectSearch>
clientProjectSearchProvider = FutureProvider.autoDispose
    .family<ApiPage<ProjectOption>, ProjectSearch>((ref, q) {
      _scope(ref);
      return ref.watch(clientFinanceRepositoryProvider).searchProjects(q);
    });
