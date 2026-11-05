import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_response.dart';

/// One page of a Laravel paginator. Every list in the collection keeps it
/// inside `data`: `data.data` (array) with `current_page`, `per_page`,
/// `total` and `last_page` (asserted by the collection's tests and seen live
/// on `client/projects`, `client/invoices`, `client/payments`).
class ApiPage<T> {
  const new({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory parse(Json data, T Function(Json) item) {
    final rows = data['data'];
    final current = asInt(data['current_page']);
    final last = asInt(data['last_page']);
    final per = asInt(data['per_page']);
    final total = asInt(data['total']);
    if (rows is! List ||
        current == null ||
        last == null ||
        per == null ||
        total == null) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Expected a paginator in data.',
      );
    }
    return ApiPage(
      items: rows.whereType<Json>().map(item).toList(growable: false),
      currentPage: current,
      lastPage: last,
      perPage: per,
      total: total,
    );
  }

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

/// Integer from a JSON number or numeric string; null otherwise.
int? asInt(Object? v) => switch (v) {
  final int i => i,
  final num n => n.toInt(),
  final String s => int.tryParse(s),
  _ => null,
};

/// Decimal from a JSON number or numeric string (Laravel returns money
/// columns such as `amount` as `"1000.00"`); null otherwise.
double? asDouble(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

/// Calendar date from `YYYY-MM-DD` (or a full ISO timestamp); null otherwise.
DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Throws [ApiFailureKind.invalidResponse] naming the missing [field].
Never missingField(String field) => throw ApiException(
  kind: ApiFailureKind.invalidResponse,
  message: 'Response is missing `$field`.',
);
