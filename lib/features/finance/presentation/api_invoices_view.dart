import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/data/client_finance_repository.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

String invoiceFilterLabel(AppLocalizations l10n, InvoiceFilter f) =>
    switch (f) {
      InvoiceFilter.all => l10n.filterAllStatus,
      InvoiceFilter.paid => l10n.statusPaid,
      InvoiceFilter.unpaid => l10n.statusUnpaid,
      InvoiceFilter.partiallyPaid => l10n.statusPartiallyPaid,
      InvoiceFilter.overdue => l10n.statusOverdue,
    };

String invoiceSortLabel(AppLocalizations l10n, InvoiceSort s) => switch (s) {
  InvoiceSort.newest => l10n.sortNewest,
  InvoiceSort.oldest => l10n.sortOldest,
  InvoiceSort.dueSoonest => l10n.sortDueSoonest,
  InvoiceSort.highestAmount => l10n.sortHighestAmount,
};

(String, BadgeTone) _status(AppLocalizations l10n, InvoiceRecord i) =>
    switch (i.status) {
      ApiInvoiceStatus.paid => (l10n.statusPaid, BadgeTone.success),
      _ when i.isOverdue => (l10n.statusOverdue, BadgeTone.danger),
      ApiInvoiceStatus.partiallyPaid => (
        l10n.statusPartiallyPaid,
        BadgeTone.warning,
      ),
      ApiInvoiceStatus.unpaid => (l10n.statusUnpaid, BadgeTone.neutral),
    };

/// "Invoices Management" (643:36002) backed by `GET /api/v1/client/invoices`.
/// Search, status, date and project filters, sorting and paging are done by
/// the server.
/// Clients have no invoice create, update or delete routes, so records are
/// read-only here; "Create Invoice" reports that nothing can be saved.
class ApiInvoicesView extends ConsumerStatefulWidget {
  const new({required this.onCreate, super.key});

  final VoidCallback onCreate;

  @override
  ConsumerState<ApiInvoicesView> createState() => _ApiInvoicesViewState();
}

class _ApiInvoicesViewState extends ConsumerState<ApiInvoicesView> {
  InvoiceFilter _filter = InvoiceFilter.all;
  InvoiceSort _sort = InvoiceSort.newest;
  int? _projectId;
  DateRange _range = DateRange.all;
  String _search = '';
  int _page = 1;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _search = v;
          _page = 1;
        });
      }
    });
  }

  InvoiceQuery get _query => (
    filter: _filter,
    sort: _sort,
    search: _search,
    from: _range.start(DateTime.now()),
    to: null,
    projectId: _projectId,
    page: _page,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query;
    final result = ref.watch(clientInvoicesProvider(query));
    // The client's projects name the invoices' `project_id`s and feed the
    // project filter; without them, cards show the id and no filter.
    final projects = ref.watch(clientProjectOptionsProvider).value;
    final projectTitles = <int, String>{
      for (final p in projects ?? const <ProjectOption>[]) p.id: p.title,
    };
    final stats = result.value?.stats;
    String n(int Function(InvoiceStats) pick) =>
        stats == null ? '—' : count(pick(stats));

    return ModulePage(
      title: l10n.invoicesTitle,
      description: l10n.invoicesDescription,
      onSearch: _onSearch,
      onCreate: widget.onCreate,
      createLabel: l10n.createInvoice,
      children: [
        const ExportReportChip(),
        MetricCard(
          title: l10n.metricTotalInvoices,
          value: n((s) => s.total),
          delta: '—',
        ),
        MetricCard(title: l10n.metricPaid, value: n((s) => s.paid), delta: '—'),
        MetricCard(
          title: l10n.metricOverdue,
          value: n((s) => s.overdue),
          delta: '—',
          negative: true,
        ),
        WfSearchBox(
          fieldKey: const Key('invoices-search'),
          hint: l10n.searchInvoicesHint,
          onChanged: _onSearch,
        ),
        ChipRow(
          children: [
            DropdownChip<DateRange>(
              value: _range,
              options: DateRange.values,
              labelOf: (r) => r.label(l10n),
              onChanged: (r) => setState(() {
                _range = r;
                _page = 1;
              }),
            ),
            DropdownChip<InvoiceSort>(
              key: const Key('invoice-sort'),
              value: _sort,
              options: InvoiceSort.values,
              labelOf: (s) => invoiceSortLabel(l10n, s),
              onChanged: (s) => setState(() {
                _sort = s;
                _page = 1;
              }),
            ),
            if (projects != null && projects.isNotEmpty)
              DropdownChip<int?>(
                key: const Key('invoice-project'),
                value: _projectId,
                options: [null, for (final p in projects) p.id],
                labelOf: (id) =>
                    id == null ? l10n.allProjects : projectTitles[id] ?? '#$id',
                onChanged: (id) => setState(() {
                  _projectId = id;
                  _page = 1;
                }),
              ),
          ],
        ),
        ChipRow(
          children: [
            for (final f in InvoiceFilter.values)
              FilterChipBox(
                key: Key('invoice-filter-${f.name}'),
                label: stats == null
                    ? invoiceFilterLabel(l10n, f)
                    : '${invoiceFilterLabel(l10n, f)} ${count(switch (f) {
                        InvoiceFilter.all => stats.total,
                        InvoiceFilter.paid => stats.paid,
                        InvoiceFilter.unpaid => stats.unpaid,
                        InvoiceFilter.partiallyPaid => stats.partiallyPaid,
                        InvoiceFilter.overdue => stats.overdue,
                      })}',
                selected: _filter == f,
                onTap: () => setState(() {
                  _filter = f;
                  _page = 1;
                }),
              ),
          ],
        ),
        AsyncSection(
          value: result,
          onRetry: () => ref.invalidate(clientInvoicesProvider(query)),
          builder: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.page.items.isEmpty) EmptyNotice(text: l10n.noRecords),
              for (final i in list.page.items) ...[
                ApiInvoiceCard(
                  invoice: i,
                  currency: list.currencies[i.currencyId],
                  projectTitle: projectTitles[i.projectId],
                ),
                const SizedBox(height: 16),
              ],
              if (list.page.lastPage > 1)
                Pager(
                  page: list.page.currentPage - 1,
                  pageSize: list.page.perPage,
                  total: list.page.total,
                  onPage: (p) => setState(() => _page = p + 1),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One invoice row from the API (reference, amount, derived status).
class ApiInvoiceCard extends StatelessWidget {
  const new({
    required this.invoice,
    required this.currency,
    this.projectTitle,
    super.key,
  });

  final InvoiceRecord invoice;
  final CurrencyRef? currency;

  /// From the client's projects; the invoice itself carries only the id.
  final String? projectTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final i = invoice;
    final fields = invoiceFields(l10n, i, currency, projectTitle);
    final (label, tone) = _status(l10n, i);
    return RecordCard(
      key: key ?? Key('api-invoice-${i.id}'),
      reference: '#${i.id}',
      title: invoiceMoney(i.amount, currency),
      status: label,
      tone: tone,
      fields: fields.where((f) => f.summary).map((f) => f.field).toList(),
      onView: () => showApiInvoiceDetails(
        context,
        row: i,
        currency: currency,
        projectTitle: projectTitle,
      ),
    );
  }
}

String invoiceMoney(double v, CurrencyRef? c) =>
    money(v, currency: c?.code ?? '', symbol: c?.symbol ?? '');

/// An invoice's rows; `summary` ones are also shown on the card.
List<({DetailField field, bool summary})> invoiceFields(
  AppLocalizations l10n,
  InvoiceRecord i,
  CurrencyRef? currency,
  String? projectTitle,
) {
  final fmt = DateFormat('MMM d, y', 'en');
  return [
    (
      field: DetailField(l10n.fieldAmount, invoiceMoney(i.amount, currency)),
      summary: false,
    ),
    (
      field: DetailField(l10n.fieldPaid, invoiceMoney(i.paidAmount, currency)),
      summary: false,
    ),
    (
      field: DetailField(
        l10n.fieldRemaining,
        invoiceMoney(i.remainingAmount, currency),
      ),
      summary: false,
    ),
    if (i.projectId != null)
      (
        field: DetailField(
          l10n.fieldProject,
          projectTitle ?? '#${i.projectId}',
        ),
        summary: true,
      ),
    (
      field: DetailField(l10n.fieldIssueDate, fmt.format(i.invoiceDate)),
      summary: true,
    ),
    if (i.dueDate != null)
      (
        field: DetailField(l10n.fieldDueDate, fmt.format(i.dueDate!)),
        summary: true,
      ),
  ];
}

/// Invoice details from `GET /client/invoices/{id}`: the row at once with a
/// loading bar, then the server's record; 403/404 or a network failure
/// shows the error with Retry and no stale amounts.
Future<void> showApiInvoiceDetails(
  BuildContext context, {
  required InvoiceRecord row,
  required CurrencyRef? currency,
  required String? projectTitle,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (_) => _InvoiceDetailsSheet(
    row: row,
    currency: currency,
    projectTitle: projectTitle,
  ),
);

class _InvoiceDetailsSheet extends ConsumerWidget {
  const new({
    required this.row,
    required this.currency,
    required this.projectTitle,
  });

  final InvoiceRecord row;
  final CurrencyRef? currency;
  final String? projectTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(clientInvoiceProvider(row.id));
    final shown = value.value ?? row;
    final (label, tone) = _status(l10n, shown);
    return RecordDetailsBody(
      key: const Key('invoice-details'),
      title: '#${shown.id}',
      status: label,
      tone: tone,
      fields: value.hasError
          ? const []
          : [
              for (final f in invoiceFields(
                l10n,
                shown,
                currency,
                projectTitle,
              ))
                f.field,
            ],
      footer: switch (value) {
        AsyncError(:final error) => ApiErrorCard(
          error: error,
          onRetry: () => ref.invalidate(clientInvoiceProvider(row.id)),
        ),
        AsyncData() => null,
        _ => const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(key: Key('invoice-details-loading')),
        ),
      },
    );
  }
}
