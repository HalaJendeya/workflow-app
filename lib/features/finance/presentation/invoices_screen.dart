import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/domain/finance_models.dart';
import 'package:workflow_app/features/finance/presentation/api_invoices_view.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Figma "Invoices Management" (643:36002).
class InvoicesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _query = '';
  InvoiceStatus? _status;
  InvoiceStatus? _pill;
  DateRange _range = DateRange.last30;
  String? _company;

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoModeProvider);
    if (!demo) return ApiInvoicesView(onCreate: () => _openForm(context));
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(invoicesProvider);
    final now = DateTime.now();
    final q = _query.trim().toLowerCase();
    final visible = all.where((i) {
      if (_status != null && i.status != _status) return false;
      if (_pill != null && i.status != _pill) return false;
      if (_company != null && i.company != _company) return false;
      if (!_range.contains(i.issueDate, now)) return false;
      if (q.isEmpty) return true;
      return '${i.reference} ${i.company} ${i.client} ${i.project}'
          .toLowerCase()
          .contains(q);
    }).toList();
    int n(InvoiceStatus s) => all.where((i) => i.status == s).length;

    return ModulePage(
      title: l10n.invoicesTitle,
      description: l10n.invoicesDescription,
      onSearch: (v) => setState(() => _query = v),
      onCreate: () => _openForm(context),
      createLabel: l10n.createInvoice,
      children: [
        const ExportReportChip(),
        MetricCard(
          title: l10n.metricTotalInvoices,
          value: count(all.length),
          delta: demo ? '+12.5% ${l10n.vsLastMonth}' : '—',
        ),
        MetricCard(
          title: l10n.metricPaid,
          value: count(n(InvoiceStatus.paid)),
          delta: demo ? '+8.4% ${l10n.vsLastMonth}' : '—',
        ),
        MetricCard(
          title: l10n.metricOverdue,
          value: count(n(InvoiceStatus.overdue)),
          delta: demo ? '-5.2% ${l10n.vsLastMonth}' : '—',
          negative: true,
        ),
        WfSearchBox(
          fieldKey: const Key('invoices-search'),
          hint: l10n.searchInvoicesHint,
          onChanged: (v) => setState(() => _query = v),
        ),
        ChipRow(
          children: [
            DropdownChip<InvoiceStatus?>(
              value: _status,
              options: const [null, ...InvoiceStatus.values],
              labelOf: (s) => s == null
                  ? l10n.filterAllStatus
                  : invoiceStatusLabel(l10n, s),
              onChanged: (s) => setState(() => _status = s),
            ),
            DropdownChip<DateRange>(
              value: _range,
              options: DateRange.values,
              labelOf: (r) => r.label(l10n),
              onChanged: (r) => setState(() => _range = r),
            ),
            DropdownChip<String?>(
              value: _company,
              options: const [null, ...FinanceOptions.companies],
              labelOf: (c) => c ?? l10n.filterAllCompanies,
              onChanged: (c) => setState(() => _company = c),
            ),
          ],
        ),
        ChipRow(
          children: [
            FilterChipBox(
              label: '${l10n.filterAll} ${count(all.length)}',
              selected: _pill == null,
              onTap: () => setState(() => _pill = null),
            ),
            for (final s in const [
              InvoiceStatus.paid,
              InvoiceStatus.overdue,
              InvoiceStatus.draft,
            ])
              FilterChipBox(
                label: '${invoiceStatusLabel(l10n, s)} ${count(n(s))}',
                selected: _pill == s,
                onTap: () => setState(() => _pill = s),
              ),
          ],
        ),
        if (visible.isEmpty)
          EmptyNotice(text: l10n.noRecords)
        else
          for (final i in visible) _card(context, i),
      ],
    );
  }

  Widget _card(BuildContext context, Invoice i) {
    final l10n = AppLocalizations.of(context);
    final date = DateFormat('MMM d, y', 'en').format(i.issueDate);
    final fields = [
      DetailField(l10n.fieldClient, i.client),
      DetailField(l10n.fieldProject, i.project),
      DetailField(l10n.fieldIssueDate, date),
    ];
    return RecordCard(
      key: Key('invoice-${i.id}'),
      reference: i.reference,
      title: money(i.amount, currency: i.currency),
      status: invoiceStatusLabel(l10n, i.status),
      tone: invoiceTone(i.status),
      fields: fields,
      onView: () => showRecordDetails(
        context,
        title: i.reference,
        status: invoiceStatusLabel(l10n, i.status),
        tone: invoiceTone(i.status),
        fields: [
          DetailField(l10n.fieldAmount, money(i.amount, currency: i.currency)),
          DetailField(l10n.fieldCompany, i.company),
          ...fields,
          DetailField(
            l10n.fieldDueDate,
            DateFormat('MMM d, y', 'en').format(i.dueDate),
          ),
        ],
      ),
      onEdit: () => _openForm(context, existing: i),
      onDelete: () async {
        if (await confirmDelete(context, i.reference)) {
          final removed = ref.read(invoicesProvider.notifier).remove(i.id);
          if (context.mounted) {
            showLocalOutcome(context, applied: removed, deleted: true);
          }
        }
      },
    );
  }

  Future<void> _openForm(BuildContext context, {Invoice? existing}) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => InvoiceFormScreen(existing: existing),
        ),
      );
}

String invoiceStatusLabel(AppLocalizations l10n, InvoiceStatus s) =>
    switch (s) {
      InvoiceStatus.paid => l10n.statusPaid,
      InvoiceStatus.overdue => l10n.statusOverdue,
      InvoiceStatus.draft => l10n.statusDraft,
      InvoiceStatus.pending => l10n.statusPending,
    };

BadgeTone invoiceTone(InvoiceStatus s) => switch (s) {
  InvoiceStatus.paid => BadgeTone.success,
  InvoiceStatus.overdue => BadgeTone.danger,
  InvoiceStatus.draft => BadgeTone.neutral,
  InvoiceStatus.pending => BadgeTone.warning,
};

/// Figma "Create Invoice" (643:36437). Saves to the local demo collection.
class InvoiceFormScreen extends ConsumerStatefulWidget {
  const new({this.existing, super.key});

  final Invoice? existing;

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _form = GlobalKey<FormState>();
  late String? _company = widget.existing?.company;
  late String? _client = widget.existing?.client;
  late String? _project = widget.existing?.project;
  late String? _currency = widget.existing?.currency ?? 'USD';
  late final _amount = TextEditingController(
    text: widget.existing?.amount.toStringAsFixed(0),
  );
  late DateTime _issue = widget.existing?.issueDate ?? DateTime.now();
  late DateTime _due =
      widget.existing?.dueDate ?? DateTime.now().add(const Duration(days: 30));
  late InvoiceStatus? _status = widget.existing?.status;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final notifier = ref.read(invoicesProvider.notifier);
    final existing = widget.existing;
    final amount = double.parse(_amount.text);
    final bool applied;
    if (existing == null) {
      final n = ref.read(invoicesProvider).length + 237;
      applied = notifier.add(
        Invoice(
          id: localId('inv'),
          reference: '#INV-${_issue.year}-${n.toString().padLeft(4, '0')}',
          amount: amount,
          currency: _currency!,
          company: _company!,
          client: _client!,
          project: _project!,
          issueDate: _issue,
          dueDate: _due,
          status: _status!,
        ),
      );
    } else {
      applied = notifier.replace(
        existing.copyWith(
          amount: amount,
          currency: _currency,
          company: _company,
          client: _client,
          project: _project,
          issueDate: _issue,
          dueDate: _due,
          status: _status,
        ),
      );
    }
    showLocalOutcome(context, applied: applied);
    if (applied) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String id(String s) => s;
    return FormPage(
      title: widget.existing == null ? l10n.createInvoice : l10n.editInvoice,
      formKey: _form,
      onSave: _save,
      fields: [
        SelectField<String>(
          key: const Key('invoice-company'),
          label: l10n.fieldCompany,
          value: _company,
          options: FinanceOptions.companies,
          labelOf: id,
          onChanged: (v) => setState(() => _company = v),
        ),
        SelectField<String>(
          label: l10n.fieldClient,
          value: _client,
          options: FinanceOptions.clients,
          labelOf: id,
          onChanged: (v) => setState(() => _client = v),
        ),
        SelectField<String>(
          label: l10n.fieldProject,
          value: _project,
          options: FinanceOptions.projects,
          labelOf: id,
          onChanged: (v) => setState(() => _project = v),
        ),
        SelectField<String>(
          label: l10n.fieldCurrency,
          value: _currency,
          options: FinanceOptions.currencies,
          labelOf: id,
          onChanged: (v) => setState(() => _currency = v),
        ),
        TextInputField(
          fieldKey: const Key('invoice-amount'),
          label: l10n.fieldAmount,
          controller: _amount,
          number: true,
          hint: '0',
        ),
        DateField(
          label: l10n.fieldInvoiceDate,
          value: _issue,
          onChanged: (d) => setState(() => _issue = d),
        ),
        DateField(
          label: l10n.fieldDueDate,
          value: _due,
          onChanged: (d) => setState(() => _due = d),
        ),
        SelectField<InvoiceStatus>(
          label: l10n.fieldStatus,
          value: _status,
          options: InvoiceStatus.values,
          labelOf: (s) => invoiceStatusLabel(l10n, s),
          onChanged: (v) => setState(() => _status = v),
        ),
      ],
    );
  }
}
