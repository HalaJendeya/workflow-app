import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/domain/finance_models.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
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
      onSearch: (v) => setState(() => _query = v),
      onCreate: () => _openForm(context),
      createLabel: l10n.addPayment,
      children: [
        if (!demo) const BackendPendingNotice(),
        const ExportReportChip(),
        MetricCard(
          title: l10n.metricTotalRevenue,
          value: money(revenue),
          delta: demo ? '12.5% ${l10n.vsLastMonth}' : '—',
        ),
        MetricCard(
          title: l10n.metricPendingPayments,
          value: money(pending.fold<double>(0, (s, p) => s + p.amount)),
          delta: l10n.invoicesAwaiting(pending.length),
        ),
        MetricCard(
          title: l10n.metricTransactionVolume,
          value: count(all.length),
          delta: demo ? '5.2% ${l10n.vsLastMonth}' : '—',
        ),
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
              label: '${l10n.filterAll} (${count(all.length)})',
              selected: _direction == null,
              onTap: () => setState(() => _direction = null),
            ),
            FilterChipBox(
              label:
                  '${l10n.directionIncoming} '
                  '(${count(dir(PaymentDirection.incoming))})',
              selected: _direction == PaymentDirection.incoming,
              onTap: () =>
                  setState(() => _direction = PaymentDirection.incoming),
            ),
            FilterChipBox(
              label:
                  '${l10n.directionOutgoing} '
                  '(${count(dir(PaymentDirection.outgoing))})',
              selected: _direction == PaymentDirection.outgoing,
              onTap: () =>
                  setState(() => _direction = PaymentDirection.outgoing),
            ),
          ],
        ),
        if (visible.isEmpty)
          EmptyNotice(text: l10n.noRecords)
        else
          for (final p in visible) _card(context, p),
      ],
    );
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
          ref.read(paymentsProvider.notifier).remove(p.id);
          if (context.mounted) showSnack(context, l10n.deletedLocally);
        }
      },
    );
  }

  Future<void> _openForm(BuildContext context, {Payment? existing}) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentFormScreen(existing: existing),
        ),
      );
}

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
    if (!_form.currentState!.validate()) return;
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
    existing == null ? notifier.add(payment) : notifier.replace(payment);
    showSnack(context, AppLocalizations.of(context).savedLocally);
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
