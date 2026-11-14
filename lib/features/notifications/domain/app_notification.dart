import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/network/api_response.dart';

/// Inbox item. Fields follow the contract asserted by the collection's
/// `List Notifications` test: id, type, category, title, message, data,
/// subject, actor, company_id, is_read, read_at, created_at.
///
/// `data`, `subject` and `actor` have no documented inner shape, so they are
/// kept as raw maps and must not be relied on by UI until specified.
class AppNotification {
  const new({
    required this.id,
    required this.isRead,
    this.type,
    this.category,
    this.title,
    this.message,
    this.companyId,
    this.readAt,
    this.createdAt,
    this.data,
    this.subject,
    this.actor,
  });

  factory fromJson(Json json) {
    final id = json['id'];
    if (id == null) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Notification without id.',
      );
    }
    // `is_read` is part of the documented contract of every item.
    final isRead = json['is_read'];
    if (isRead is! bool) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'Notification without a boolean is_read.',
      );
    }
    return AppNotification(
      id: id.toString(),
      isRead: isRead,
      type: json['type'] as String?,
      category: json['category'] as String?,
      title: json['title'] as String?,
      message: json['message'] as String?,
      companyId: json['company_id'] is int ? json['company_id'] as int : null,
      readAt: _date(json['read_at']),
      createdAt: _date(json['created_at']),
      data: _map(json['data']),
      subject: _map(json['subject']),
      actor: _map(json['actor']),
    );
  }

  final String id;
  final bool isRead;
  final String? type;
  final String? category;
  final String? title;
  final String? message;
  final int? companyId;
  final DateTime? readAt;
  final DateTime? createdAt;
  final Json? data;
  final Json? subject;
  final Json? actor;

  AppNotification markedRead(DateTime? at) => AppNotification(
    id: id,
    isRead: true,
    type: type,
    category: category,
    title: title,
    message: message,
    companyId: companyId,
    readAt: at ?? readAt,
    createdAt: createdAt,
    data: data,
    subject: subject,
    actor: actor,
  );
}

class NotificationInbox {
  const new({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.unreadCount,
  });

  final List<AppNotification> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int unreadCount;

  bool get hasMore => currentPage < lastPage;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
Json? _map(Object? v) => v is Map<String, dynamic> ? v : null;
