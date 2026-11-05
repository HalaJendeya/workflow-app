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
/// Search, status and date filters and paging are done by the server.
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
    search: _search,
    from: _range.start(DateTime.now()),
    to: null,
    page: _page,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query;
    final result = ref.watch(clientInvoicesProvider(query));
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
  const new({required this.invoice, required this.currency, super.key});

  final InvoiceRecord invoice;
  final CurrencyRef? currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final i = invoice;
    final fmt = DateFormat('MMM d, y', 'en');
    String m(double v) => money(
      v,
      currency: currency?.code ?? '',
      symbol: currency?.symbol ?? '',
    );
    final (label, tone) = _status(l10n, i);
    final fields = [
      if (i.projectId != null)
        DetailField(l10n.fieldProject, '#${i.projectId}'),
      DetailField(l10n.fieldIssueDate, fmt.format(i.invoiceDate)),
      if (i.dueDate != null)
        DetailField(l10n.fieldDueDate, fmt.format(i.dueDate!)),
    ];
    return RecordCard(
      key: key ?? Key('api-invoice-${i.id}'),
      reference: '#${i.id}',
      title: m(i.amount),
      status: label,
      tone: tone,
      fields: fields,
      onView: () => showRecordDetails(
        context,
        title: '#${i.id}',
        status: label,
        tone: tone,
        fields: [
          DetailField(l10n.fieldAmount, m(i.amount)),
          DetailField(l10n.fieldPaid, m(i.paidAmount)),
          DetailField(l10n.fieldRemaining, m(i.remainingAmount)),
          ...fields,
        ],
      ),
    );
  }
}
