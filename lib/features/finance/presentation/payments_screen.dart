import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/data/client_finance_repository.dart';
import 'package:workflow_app/features/finance/domain/finance_models.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Figma "Payment Records" (643:35269).
class PaymentsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  String _query = '';
  String? _method;
  DateRange _range = DateRange.last30;
  PaymentDirection? _direction;

  // API mode: server-side filters of `GET /client/payments`.
  PaymentStatusFilter _apiStatus = PaymentStatusFilter.all;
  DateRange _apiRange = DateRange.all;
  String _apiSearch = '';
  int _apiPage = 1;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onApiSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _apiSearch = v;
          _apiPage = 1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(paymentsProvider);
    final demo = ref.watch(demoModeProvider);
    final now = DateTime.now();
    final q = _query.trim().toLowerCase();
    final visible = all.where((p) {
      if (_method != null && p.method != _method) return false;
      if (_direction != null && p.direction != _direction) return false;
      if (!_range.contains(p.date, now)) return false;
      if (q.isEmpty) return true;
      return '${p.reference} ${p.invoice} ${p.company} ${p.method}'
          .toLowerCase()
          .contains(q);
    }).toList();
    final revenue = all
        .where((p) => p.status == PaymentStatus.completed)
        .fold<double>(0, (s, p) => s + p.amount);
    final pending = all.where((p) => p.status == PaymentStatus.inProgress);
    int dir(PaymentDirection d) => all.where((p) => p.direction == d).length;

    return ModulePage(
      title: l10n.paymentsTitle,
      description: l10n.paymentsDescription,
      onSearch: demo ? (v) => setState(() => _query = v) : _onApiSearch,
      onCreate: () => _openForm(context),
      createLabel: l10n.addPayment,
      children: [
        const ExportReportChip(),
        if (demo) ...[
          MetricCard(
            title: l10n.metricTotalRevenue,
            value: money(revenue),
            delta: '12.5% ${l10n.vsLastMonth}',
          ),
          MetricCard(
            title: l10n.metricPendingPayments,
            value: money(pending.fold<double>(0, (s, p) => s + p.amount)),
            delta: l10n.invoicesAwaiting(pending.length),
          ),
          MetricCard(
            title: l10n.metricTransactionVolume,
            value: count(all.length),
            delta: '5.2% ${l10n.vsLastMonth}',
          ),
        ] else
          ..._apiChildren(context),
        if (demo) ..._localRecords(context, visible, all.length, dir),
      ],
    );
  }

  /// `GET /client/payments`: metrics, filters and rows from one response.
  List<Widget> _apiChildren(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = (
      status: _apiStatus,
      search: _apiSearch,
      from: _apiRange.start(DateTime.now()),
      page: _apiPage,
    );
    final result = ref.watch(clientPaymentsProvider(query));
    String statusLabel(PaymentStatusFilter s) => switch (s) {
      PaymentStatusFilter.all => l10n.filterAllStatus,
      PaymentStatusFilter.confirmed => l10n.statusConfirmed,
      PaymentStatusFilter.pending => l10n.statusPending,
    };
    return [
      _ApiPaymentMetrics(result: result),
      InfoNotice(
        key: const Key('payment-rows-note'),
        text: l10n.paymentRowsNote,
      ),
      WfSearchBox(
        fieldKey: const Key('payments-search'),
        hint: l10n.searchPaymentsHint,
        onChanged: _onApiSearch,
      ),
      ChipRow(
        children: [
          DropdownChip<DateRange>(
            key: const Key('payment-range'),
            value: _apiRange,
            options: DateRange.values,
            labelOf: (r) => r.label(l10n),
            onChanged: (r) => setState(() {
              _apiRange = r;
              _apiPage = 1;
            }),
          ),
        ],
      ),
      ChipRow(
        children: [
          for (final s in PaymentStatusFilter.values)
            FilterChipBox(
              key: Key('payment-status-${s.name}'),
              label: statusLabel(s),
              selected: _apiStatus == s,
              onTap: () => setState(() {
                _apiStatus = s;
                _apiPage = 1;
              }),
            ),
        ],
      ),
      AsyncSection(
        value: result,
        onRetry: () => ref.invalidate(clientPaymentsProvider(query)),
        builder: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (list.page.items.isEmpty) EmptyNotice(text: l10n.noRecords),
            for (final p in list.page.items) ...[
              _ApiPaymentCard(payment: p, currency: list.onlyCurrency),
              const SizedBox(height: 16),
            ],
            if (list.page.lastPage > 1)
              Pager(
                page: list.page.currentPage - 1,
                pageSize: list.page.perPage,
                total: list.page.total,
                onPage: (p) => setState(() => _apiPage = p + 1),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _localRecords(
    BuildContext context,
    List<Payment> visible,
    int total,
    int Function(PaymentDirection) dir,
  ) {
    final l10n = AppLocalizations.of(context);
    return [
      WfSearchBox(
        fieldKey: const Key('payments-search'),
        hint: l10n.searchPaymentsHint,
        onChanged: (v) => setState(() => _query = v),
      ),
      ChipRow(
        children: [
          DropdownChip<String?>(
            value: _method,
            options: const [null, ...FinanceOptions.methods],
            labelOf: (m) => m ?? l10n.filterAllMethods,
            onChanged: (m) => setState(() => _method = m),
          ),
          DropdownChip<DateRange>(
            value: _range,
            options: DateRange.values,
            labelOf: (r) => r.label(l10n),
            onChanged: (r) => setState(() => _range = r),
          ),
        ],
      ),
      ChipRow(
        children: [
          FilterChipBox(
            label: '${l10n.filterAll} (${count(total)})',
            selected: _direction == null,
            onTap: () => setState(() => _direction = null),
          ),
          FilterChipBox(
            label:
                '${l10n.directionIncoming} '
                '(${count(dir(PaymentDirection.incoming))})',
            selected: _direction == PaymentDirection.incoming,
            onTap: () => setState(() => _direction = PaymentDirection.incoming),
          ),
          FilterChipBox(
            label:
                '${l10n.directionOutgoing} '
                '(${count(dir(PaymentDirection.outgoing))})',
            selected: _direction == PaymentDirection.outgoing,
            onTap: () => setState(() => _direction = PaymentDirection.outgoing),
          ),
        ],
      ),
      if (visible.isEmpty)
        EmptyNotice(text: l10n.noRecords)
      else
        for (final p in visible) _card(context, p),
    ];
  }

  Widget _card(BuildContext context, Payment p) {
    final l10n = AppLocalizations.of(context);
    final status = p.status == PaymentStatus.completed
        ? l10n.statusCompleted
        : l10n.statusInProgress;
    final tone = p.status == PaymentStatus.completed
        ? BadgeTone.success
        : BadgeTone.warning;
    final when = DateFormat('yyyy-MM-dd · HH:mm', 'en').format(p.date);
    return RecordCard(
      key: Key('payment-${p.id}'),
      reference: p.reference,
      title: money(p.amount),
      subtitle: when,
      status: status,
      tone: tone,
      fields: [
        DetailField(l10n.fieldMethod, p.method),
        DetailField(l10n.fieldWallet, p.wallet),
      ],
      onView: () => showRecordDetails(
        context,
        title: p.reference,
        status: status,
        tone: tone,
        fields: [
          DetailField(l10n.fieldAmount, money(p.amount)),
          DetailField(l10n.fieldPaymentDate, when),
          DetailField(l10n.fieldCompany, p.company),
          DetailField(l10n.fieldInvoice, p.invoice),
          DetailField(l10n.fieldMethod, p.method),
          DetailField(l10n.fieldWallet, p.wallet),
          if (p.employee != null) DetailField(l10n.fieldEmployee, p.employee!),
          if (p.notes != null && p.notes!.isNotEmpty)
            DetailField(l10n.fieldNotes, p.notes!),
        ],
      ),
      onEdit: () => _openForm(context, existing: p),
      onDelete: () async {
        if (await confirmDelete(context, p.reference)) {
          final removed = ref.read(paymentsProvider.notifier).remove(p.id);
          if (context.mounted) {
            showLocalOutcome(context, applied: removed, deleted: true);
          }
        }
      },
    );
  }

  Future<void> _openForm(BuildContext context, {Payment? existing}) =>
      openPaymentForm(context, existing: existing);
}

/// Add/edit payment. Demo only: the client role has no payment write
/// route, so in API mode this explains that instead of opening the form.
Future<void> openPaymentForm(BuildContext context, {Payment? existing}) =>
    openDemoForm(
      context,
      page: (_) => PaymentFormScreen(existing: existing),
      unavailable: AppLocalizations.of(context).paymentCreateUnavailable,
    );

/// Figma "Add Payment" (643:35666). Saves to the local demo collection.
class PaymentFormScreen extends ConsumerStatefulWidget {
  const new({this.existing, super.key});

  final Payment? existing;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _form = GlobalKey<FormState>();
  late String? _company = widget.existing?.company;
  late String? _invoice = widget.existing?.invoice;
  late String? _wallet = widget.existing?.wallet;
  late String? _employee = widget.existing?.employee;
  late String? _method = widget.existing?.method;
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late final _amount = TextEditingController(
    text: widget.existing?.amount.toStringAsFixed(0),
  );
  late final _notes = TextEditingController(text: widget.existing?.notes);

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!validateAndReveal(_form)) return;
    final existing = widget.existing;
    final payment = Payment(
      id: existing?.id ?? localId('pay'),
      reference:
          existing?.reference ??
          '#PAY-${DateTime.now().millisecondsSinceEpoch % 100000}',
      amount: double.parse(_amount.text),
      date: _date,
      method: _method!,
      wallet: _wallet!,
      company: _company!,
      invoice: _invoice!,
      status: existing?.status ?? PaymentStatus.inProgress,
      direction: existing?.direction ?? PaymentDirection.incoming,
      employee: _employee,
      notes: _notes.text.trim(),
    );
    final notifier = ref.read(paymentsProvider.notifier);
    final applied = existing == null
        ? notifier.add(payment)
        : notifier.replace(payment);
    showLocalOutcome(context, applied: applied);
    if (!applied) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invoices = ref.watch(invoicesProvider).map((i) => i.reference);
    String id(String s) => s;
    return FormPage(
      title: widget.existing == null ? l10n.addPayment : l10n.editPayment,
      formKey: _form,
      onSave: _save,
      fields: [
        SelectField<String>(
          label: l10n.fieldCompany,
          value: _company,
          options: FinanceOptions.companies,
          labelOf: id,
          onChanged: (v) => setState(() => _company = v),
        ),
        SelectField<String>(
          label: l10n.fieldInvoice,
          value: _invoice,
          options: {...invoices, ?_invoice}.toList(),
          labelOf: id,
          onChanged: (v) => setState(() => _invoice = v),
        ),
        SelectField<String>(
          label: l10n.fieldWallet,
          value: _wallet,
          options: FinanceOptions.wallets,
          labelOf: id,
          onChanged: (v) => setState(() => _wallet = v),
        ),
        SelectField<String>(
          label: l10n.fieldEmployee,
          value: _employee,
          options: FinanceOptions.employees,
          labelOf: id,
          required: false,
          onChanged: (v) => setState(() => _employee = v),
        ),
        TextInputField(
          fieldKey: const Key('payment-amount'),
          label: l10n.fieldAmount,
          controller: _amount,
          number: true,
          hint: '0',
          validator: (v) => positiveAmount(context, v),
        ),
        SelectField<String>(
          label: l10n.fieldPaymentMethod,
          value: _method,
          options: FinanceOptions.methods,
          labelOf: id,
          onChanged: (v) => setState(() => _method = v),
        ),
        DateField(
          label: l10n.fieldPaymentDate,
          value: _date,
          onChanged: (d) => setState(() => _date = d),
        ),
        TextInputField(
          label: l10n.fieldNotes,
          controller: _notes,
          maxLines: 5,
          required: false,
        ),
      ],
    );
  }
}

/// Payment metrics from `GET /api/v1/client/payments` (`stats.total` and
/// per-currency `totals[]`). Payment rows stay pending: the collection does
/// not document their fields.
class _ApiPaymentMetrics extends StatelessWidget {
  const new({required this.result});

  final AsyncValue<PaymentList> result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Metrics without data say nothing ("—"): the list below shows the
    // loading spinner or the error with Retry.
    final s = result.value;
    String sum(double Function(PaymentTotal) pick) => s == null
        ? '—'
        : s.totals.isEmpty
        ? '0'
        : s.totals
              .map((t) => money(pick(t), currency: t.code, symbol: t.symbol))
              .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricCard(
          key: const Key('api-payments-received'),
          title: l10n.metricTotalRevenue,
          value: sum((t) => t.received),
          delta: '—',
        ),
        const SizedBox(height: 16),
        MetricCard(
          title: l10n.metricPendingPayments,
          value: sum((t) => t.pending),
          delta: '—',
          negative: true,
        ),
        const SizedBox(height: 16),
        MetricCard(
          key: const Key('api-payments-count'),
          title: l10n.metricTransactionVolume,
          value: s == null ? '—' : count(s.count),
          delta: '—',
        ),
      ],
    );
  }
}

/// One payment row. Amount is shown in the list's currency only when the
/// totals name a single one; rows carry no currency of their own.
class _ApiPaymentCard extends StatelessWidget {
  const new({required this.payment, required this.currency});

  final PaymentRecord payment;
  final PaymentTotal? currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = payment;
    final amount = money(
      p.amount,
      currency: currency?.code ?? '',
      symbol: currency?.symbol ?? '',
    );
    final when = DateFormat('yyyy-MM-dd', 'en').format(p.date);
    final (status, tone) = switch (p.direction) {
      ApiPaymentDirection.incoming => (
        l10n.directionIncoming,
        BadgeTone.success,
      ),
      ApiPaymentDirection.outgoing => (
        l10n.directionOutgoing,
        BadgeTone.neutral,
      ),
      null => ('', BadgeTone.neutral),
    };
    final fields = [
      DetailField(l10n.fieldPaymentDate, when),
      if (p.method != null) DetailField(l10n.fieldMethod, p.method!),
      if (p.invoiceId != null)
        DetailField(l10n.fieldInvoice, '#${p.invoiceId}'),
    ];
    return RecordCard(
      key: Key('api-payment-${p.id}'),
      reference: '#${p.id}',
      title: amount,
      status: status,
      tone: tone,
      fields: fields,
      // The row is the whole documented record; `GET /client/payments/{id}`
      // documents only `data.id`, so details come from the row.
      onView: () => showRecordDetails(
        context,
        title: '#${p.id}',
        status: status,
        tone: tone,
        fields: [DetailField(l10n.fieldAmount, amount), ...fields],
      ),
    );
  }
}
