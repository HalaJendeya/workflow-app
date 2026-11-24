import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/export_csv_chip.dart';
import 'package:workflow_app/core/widgets/filter_sheet.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/data/client_finance_repository.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/projects/data/projects_repository.dart';
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
  const new({this.onCreate, super.key});

  /// Null in API mode: clients have no invoice create route.
  final VoidCallback? onCreate;

  @override
  ConsumerState<ApiInvoicesView> createState() => _ApiInvoicesViewState();
}

/// Every invoice filter and the sort, applied together from one sheet.
@immutable
class InvoiceFilters {
  const new({
    this.status = InvoiceFilter.all,
    this.range = DateRange.all,
    this.project,
    this.sort = InvoiceSort.newest,
  });

  final InvoiceFilter status;
  final DateRange range;
  final ProjectOption? project;

  /// `newest` is the default.
  final InvoiceSort sort;

  /// What the Filters button counts: everything that differs from the
  /// defaults, sort included.
  int get count =>
      (status != InvoiceFilter.all ? 1 : 0) +
      (range != DateRange.all ? 1 : 0) +
      (project != null ? 1 : 0) +
      (sort != InvoiceSort.newest ? 1 : 0);

  InvoiceFilters copyWith({
    InvoiceFilter? status,
    DateRange? range,
    ({ProjectOption? value})? project,
    InvoiceSort? sort,
  }) => InvoiceFilters(
    status: status ?? this.status,
    range: range ?? this.range,
    project: project == null ? this.project : project.value,
    sort: sort ?? this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is InvoiceFilters &&
      other.status == status &&
      other.range == range &&
      other.project == project &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(status, range, project, sort);
}

class _ApiInvoicesViewState extends ConsumerState<ApiInvoicesView> {
  InvoiceFilters _filters = const InvoiceFilters();
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
    filter: _filters.status,
    sort: _filters.sort,
    search: _search,
    from: _filters.range.start(DateTime.now()),
    to: null,
    projectId: _filters.project?.id,
    page: _page,
  );

  /// Applies [next] from page 1; an unchanged value sends nothing.
  void _apply(InvoiceFilters next) {
    if (next == _filters) return;
    setState(() {
      _filters = next;
      _page = 1;
    });
  }

  Future<void> _openFilters(InvoiceStats? stats) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showFilterSheet<InvoiceFilters>(
      context,
      id: 'invoice',
      title: l10n.invoiceFiltersTitle,
      initial: _filters,
      defaults: const InvoiceFilters(),
      sections: (context, draft, setDraft) => [
        FilterSection(
          title: l10n.fieldStatus,
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
                selected: draft.status == f,
                onTap: () => setDraft(draft.copyWith(status: f)),
              ),
          ],
        ),
        FilterSection(
          title: l10n.filterPeriod,
          children: [
            for (final r in DateRange.values)
              FilterChipBox(
                key: Key('invoice-range-${r.name}'),
                label: r.label(l10n),
                selected: draft.range == r,
                onTap: () => setDraft(draft.copyWith(range: r)),
              ),
          ],
        ),
        FilterSection(
          title: l10n.filterProject,
          children: [
            // Searchable, paged picker over all of the client's projects.
            FilterChipBox(
              key: const Key('invoice-project'),
              label: '${draft.project?.title ?? l10n.allProjects} ⌄',
              selected: draft.project != null,
              onTap: () async {
                final choice = await showProjectPicker(context);
                if (choice == null || !context.mounted) return;
                setDraft(draft.copyWith(project: (value: choice.project)));
              },
            ),
          ],
        ),
        FilterSection(
          title: l10n.sortBy,
          children: [
            for (final s in InvoiceSort.values)
              FilterChipBox(
                key: Key('invoice-sort-${s.name}'),
                label: invoiceSortLabel(l10n, s),
                selected: draft.sort == s,
                onTap: () => setDraft(draft.copyWith(sort: s)),
              ),
          ],
        ),
      ],
    );
    if (picked != null && mounted) _apply(picked);
  }

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
      // One search, in the masthead (the inline second field is gone, as
      // on Employee Tasks).
      searchHint: l10n.searchInvoicesHint,
      searchFieldKey: const Key('invoices-search'),
      onSearch: _onSearch,
      onCreate: widget.onCreate,
      createLabel: l10n.createInvoice,
      children: [
        MetricGroup(
          metrics: [
            Metric(
              label: l10n.metricTotalInvoices,
              value: n((s) => s.total),
              delta: '—',
            ),
            Metric(label: l10n.metricPaid, value: n((s) => s.paid), delta: '—'),
            Metric(
              label: l10n.metricOverdue,
              value: n((s) => s.overdue),
              delta: '—',
              negative: true,
            ),
          ],
        ),
        // Status, period, project and sort live in one sheet; the applied
        // ones show here as removable chips. Export sits beside the button:
        // it downloads what the list shows (same filters and sort, every
        // page).
        FilterBar(
          key: const Key('invoice-filter-bar'),
          buttonKey: const Key('invoice-filters'),
          count: _filters.count,
          onOpen: () => _openFilters(stats),
          onReset: () => _apply(const InvoiceFilters()),
          trailing: ExportCsvChip(
            key: const Key('invoices-export'),
            label: l10n.exportReport,
            download: () =>
                ref.read(clientFinanceRepositoryProvider).invoicesCsv(query),
          ),
          active: [
            if (_filters.status != InvoiceFilter.all)
              ActiveFilter(
                'status',
                invoiceFilterLabel(l10n, _filters.status),
                () => _apply(_filters.copyWith(status: InvoiceFilter.all)),
              ),
            if (_filters.range != DateRange.all)
              ActiveFilter(
                'range',
                _filters.range.label(l10n),
                () => _apply(_filters.copyWith(range: DateRange.all)),
              ),
            if (_filters.project case final p?)
              ActiveFilter(
                'project',
                p.title,
                () => _apply(_filters.copyWith(project: (value: null))),
              ),
            if (_filters.sort != InvoiceSort.newest)
              ActiveFilter(
                'sort',
                invoiceSortLabel(l10n, _filters.sort),
                () => _apply(_filters.copyWith(sort: InvoiceSort.newest)),
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
                  projectTitle: i.projectId == _filters.project?.id
                      ? _filters.project?.title
                      : null,
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
class ApiInvoiceCard extends ConsumerWidget {
  const new({
    required this.invoice,
    required this.currency,
    this.projectTitle,
    super.key,
  });

  final InvoiceRecord invoice;
  final CurrencyRef? currency;

  /// Known title of the invoice's project. The invoice carries only the
  /// id; otherwise the title is looked up with `GET /client/projects/{id}`
  /// (one request per distinct project) and `#id` shows until then or if
  /// the project cannot be read.
  final String? projectTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final i = invoice;
    final projectTitle =
        this.projectTitle ??
        switch (i.projectId) {
          final id? => ref.watch(apiProjectProvider(id)).value?.title,
          null => null,
        };
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
  final fmt = DateFormat('MMM d, y');
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
/// shows the error with Retry and no stale amounts. Under the details: the
/// payments recorded against the invoice.
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
    invoiceId: row.id,
    row: row,
    currency: currency,
    projectTitle: projectTitle,
  ),
);

/// Invoice details opened from somewhere that knows only the id (a payment
/// row's `invoice_id`): a loading bar until `GET /client/invoices/{id}`
/// answers. The invoice carries only a `currency_id` and no list `totals`
/// name it here, so amounts show without a currency rather than a guessed
/// one; the project title is looked up as on the cards.
Future<void> showApiInvoiceDetailsById(BuildContext context, int invoiceId) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _InvoiceDetailsSheet(invoiceId: invoiceId),
    );

class _InvoiceDetailsSheet extends ConsumerWidget {
  const new({
    required this.invoiceId,
    this.row,
    this.currency,
    this.projectTitle,
  });

  final int invoiceId;
  final InvoiceRecord? row;
  final CurrencyRef? currency;
  final String? projectTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(clientInvoiceProvider(invoiceId));
    final shown = value.value ?? row;
    final (label, tone) = shown == null
        ? ('', BadgeTone.neutral)
        : _status(l10n, shown);
    final title =
        projectTitle ??
        switch (shown?.projectId) {
          final id? => ref.watch(apiProjectProvider(id)).value?.title,
          null => null,
        };
    return RecordDetailsBody(
      key: const Key('invoice-details'),
      title: '#$invoiceId',
      status: label,
      tone: tone,
      fields: value.hasError || shown == null
          ? const []
          : [
              for (final f in invoiceFields(l10n, shown, currency, title))
                f.field,
            ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (value) {
            AsyncError(:final error) => ApiErrorCard(
              error: error,
              onRetry: () => ref.invalidate(clientInvoiceProvider(invoiceId)),
            ),
            AsyncData() => const SizedBox.shrink(),
            _ => const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                key: Key('invoice-details-loading'),
              ),
            ),
          },
          // An invoice the client may not read has no payments to show.
          if (!value.hasError) InvoicePaymentsSection(invoiceId: invoiceId),
        ],
      ),
    );
  }
}

/// "Payments for this invoice": `GET /client/payments?invoice_id=` one page
/// at a time with "Load more". Rows show only documented list fields
/// (amount, date, method); the amount carries a currency only when the
/// answer's `totals` name exactly one, as on the payments list.
class InvoicePaymentsSection extends ConsumerStatefulWidget {
  const new({required this.invoiceId, super.key});

  final int invoiceId;

  @override
  ConsumerState<InvoicePaymentsSection> createState() =>
      _InvoicePaymentsSectionState();
}

class _InvoicePaymentsSectionState
    extends ConsumerState<InvoicePaymentsSection> {
  int _pages = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <Widget>[];
    var more = false;
    for (var page = 1; page <= _pages; page++) {
      final q = (invoiceId: widget.invoiceId, page: page);
      switch (ref.watch(clientInvoicePaymentsProvider(q))) {
        case AsyncData(:final value):
          for (final p in value.page.items) {
            rows.add(
              _InvoicePaymentRow(payment: p, currency: value.onlyCurrency),
            );
          }
          if (page == 1 && value.page.items.isEmpty) {
            rows.add(
              EmptyNotice(
                key: const Key('invoice-payments-empty'),
                text: l10n.invoicePaymentsEmpty,
              ),
            );
          }
          more = page == _pages && value.page.hasMore;
        case AsyncError(:final error):
          rows.add(
            ApiErrorCard(
              error: error,
              onRetry: () => ref.invalidate(clientInvoicePaymentsProvider(q)),
            ),
          );
        default:
          rows.add(
            const Padding(
              key: Key('invoice-payments-loading'),
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
      }
    }
    return Column(
      key: const Key('invoice-payments'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.invoicePaymentsTitle,
          style: AppTextStyles.mobileLgSemiBold.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
        if (more)
          TextButton(
            key: const Key('invoice-payments-more'),
            onPressed: () => setState(() => _pages++),
            child: Text(l10n.loadMore),
          ),
      ],
    );
  }
}

class _InvoicePaymentRow extends StatelessWidget {
  const new({required this.payment, required this.currency});

  final PaymentRecord payment;
  final PaymentTotal? currency;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final when = DateFormat('yyyy-MM-dd', 'en').format(p.date);
    final secondary = AppTextStyles.mobileBaseRegular.copyWith(
      color: AppColors.textSecondary,
    );
    return Padding(
      key: Key('invoice-payment-${p.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${p.id} · $when', style: secondary),
                if (p.method != null) Text(p.method!, style: secondary),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            money(
              p.amount,
              currency: currency?.code ?? '',
              symbol: currency?.symbol ?? '',
            ),
            style: AppTextStyles.mobileBaseSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The picker's answer: a project, or `null` for all projects.
typedef ProjectChoice = ({ProjectOption? project});

/// Searchable project picker for the invoice filter: server-side `search`,
/// pages of [projectSearchPageSize] loaded on demand with "Load more", so
/// every project can be reached without downloading them all. `null` when
/// dismissed.
Future<ProjectChoice?> showProjectPicker(BuildContext context) =>
    showModalBottomSheet<ProjectChoice>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const _ProjectPicker(),
    );

class _ProjectPicker extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ProjectPicker> createState() => _ProjectPickerState();
}

class _ProjectPickerState extends ConsumerState<_ProjectPicker> {
  String _search = '';
  int _pages = 1;
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
          _pages = 1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <Widget>[
      ListTile(
        key: const Key('project-option-all'),
        title: Text(l10n.allProjects),
        onTap: () => Navigator.pop(context, (project: null)),
      ),
    ];
    var more = false;
    for (var page = 1; page <= _pages; page++) {
      final q = (search: _search, page: page);
      final value = ref.watch(clientProjectSearchProvider(q));
      switch (value) {
        case AsyncData(:final value):
          for (final p in value.items) {
            rows.add(
              ListTile(
                key: Key('project-option-${p.id}'),
                title: Text(p.title),
                onTap: () => Navigator.pop(context, (project: p)),
              ),
            );
          }
          if (page == 1 && value.items.isEmpty) {
            rows.add(EmptyNotice(text: l10n.noRecords));
          }
          more = page == _pages && value.hasMore;
        case AsyncError(:final error):
          rows.add(
            ApiErrorCard(
              error: error,
              onRetry: () => ref.invalidate(clientProjectSearchProvider(q)),
            ),
          );
        default:
          rows.add(
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
      }
    }
    if (more) {
      rows.add(
        TextButton(
          key: const Key('project-picker-more'),
          onPressed: () => setState(() => _pages++),
          child: Text(l10n.loadMore),
        ),
      );
    }
    return SafeArea(
      child: Padding(
        key: const Key('project-picker'),
        padding: EdgeInsetsDirectional.only(
          start: 20,
          end: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WfSearchBox(
                fieldKey: const Key('project-picker-search'),
                hint: l10n.searchProjectsHint,
                onChanged: _onSearch,
              ),
              const SizedBox(height: 8),
              // Pages arrive 20 rows at a time on demand, so the loaded rows
              // are laid out together.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rows,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
