import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/data/local_collection.dart';

enum InvoiceStatus { paid, overdue, draft, pending }

enum PaymentStatus { completed, inProgress }

enum PaymentDirection { incoming, outgoing }

/// Presentation model for the Figma "Invoices Management" cards (643:36002).
class Invoice implements Identified {
  const new({
    required this.id,
    required this.reference,
    required this.amount,
    required this.currency,
    required this.company,
    required this.client,
    required this.project,
    required this.issueDate,
    required this.dueDate,
    required this.status,
  });

  @override
  final String id;
  final String reference;
  final double amount;
  final String currency;
  final String company;
  final String client;
  final String project;
  final DateTime issueDate;
  final DateTime dueDate;
  final InvoiceStatus status;

  Invoice copyWith({
    double? amount,
    String? currency,
    String? company,
    String? client,
    String? project,
    DateTime? issueDate,
    DateTime? dueDate,
    InvoiceStatus? status,
  }) => Invoice(
    id: id,
    reference: reference,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    company: company ?? this.company,
    client: client ?? this.client,
    project: project ?? this.project,
    issueDate: issueDate ?? this.issueDate,
    dueDate: dueDate ?? this.dueDate,
    status: status ?? this.status,
  );
}

/// Presentation model for the Figma "Payment Records" cards (643:35269).
class Payment implements Identified {
  const new({
    required this.id,
    required this.reference,
    required this.amount,
    required this.date,
    required this.method,
    required this.wallet,
    required this.company,
    required this.invoice,
    required this.status,
    required this.direction,
    this.employee,
    this.notes,
  });

  @override
  final String id;
  final String reference;
  final double amount;
  final DateTime date;
  final String method;
  final String wallet;
  final String company;
  final String invoice;
  final PaymentStatus status;
  final PaymentDirection direction;
  final String? employee;
  final String? notes;
}

/// Option lists for the demo forms (Figma shows "select" placeholders only).
abstract final class FinanceOptions {
  static const companies = ['Gaza', 'Tech Company', 'Ra', 'Test Corp'];
  static const clients = ['zeinab almudai', 'Liam Johnson', 'Amara Patel'];
  static const projects = ['UX UI', 'Project Manager', 'Graphic Design'];
  static const currencies = ['USD', 'EUR', 'ILS'];
  static const methods = ['Stripe', 'Credit Card', 'Bank Transfer'];
  static const wallets = ['Stripe', 'Visa •••• 4242', 'Bank Transfer'];
  static const employees = ['Ahmed Al-Saeed', 'Sara Khalil'];
}

final invoicesProvider =
    NotifierProvider<LocalCollection<Invoice>, List<Invoice>>(
      () => LocalCollection<Invoice>(
        () => [
          Invoice(
            id: 'inv-1',
            reference: '#INV-2026-0234',
            amount: 100000,
            currency: 'USD',
            company: 'Gaza',
            client: 'zeinab almudai',
            project: 'UX UI',
            issueDate: _ago(14),
            dueDate: _ago(4),
            status: InvoiceStatus.overdue,
          ),
          Invoice(
            id: 'inv-2',
            reference: '#INV-2026-0235',
            amount: 75000,
            currency: 'USD',
            company: 'Tech Company',
            client: 'Liam Johnson',
            project: 'Project Manager',
            issueDate: _ago(19),
            dueDate: _ago(-11),
            status: InvoiceStatus.paid,
          ),
          Invoice(
            id: 'inv-3',
            reference: '#INV-2026-0236',
            amount: 125500,
            currency: 'USD',
            company: 'Ra',
            client: 'Amara Patel',
            project: 'Graphic Design',
            issueDate: _ago(28),
            dueDate: _ago(2),
            status: InvoiceStatus.paid,
          ),
        ],
      ),
    );

final paymentsProvider =
    NotifierProvider<LocalCollection<Payment>, List<Payment>>(
      () => LocalCollection<Payment>(
        () => [
          Payment(
            id: 'pay-1',
            reference: '#PAY-78945',
            amount: 1500,
            date: _ago(3, 10, 30),
            method: 'Stripe',
            wallet: 'Stripe',
            company: 'Gaza',
            invoice: '#INV-2026-0234',
            status: PaymentStatus.completed,
            direction: PaymentDirection.incoming,
          ),
          Payment(
            id: 'pay-2',
            reference: '#INV-2026-0235',
            amount: 3200,
            date: _ago(2, 14, 15),
            method: 'Credit Card',
            wallet: 'Visa •••• 4242',
            company: 'Tech Company',
            invoice: '#INV-2026-0235',
            status: PaymentStatus.completed,
            direction: PaymentDirection.incoming,
          ),
          Payment(
            id: 'pay-3',
            reference: '#INV-2026-0236',
            amount: 950,
            date: _ago(1, 9, 45),
            method: 'Bank Transfer',
            wallet: 'Bank Transfer',
            company: 'Ra',
            invoice: '#INV-2026-0236',
            status: PaymentStatus.inProgress,
            direction: PaymentDirection.outgoing,
          ),
          Payment(
            id: 'pay-4',
            reference: '#INV-2026-0237',
            amount: 950,
            date: _ago(1, 9, 45),
            method: 'Bank Transfer',
            wallet: 'Bank Transfer',
            company: 'Test Corp',
            invoice: '#INV-2026-0236',
            status: PaymentStatus.inProgress,
            direction: PaymentDirection.outgoing,
          ),
        ],
      ),
    );

/// Demo dates relative to today so the default "Last 30 days" filter shows
/// the seeded records.
DateTime _ago(int days, [int hour = 9, int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days, hour, minute);
}
