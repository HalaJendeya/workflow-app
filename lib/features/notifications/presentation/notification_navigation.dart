import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/conversations/presentation/conversations_screens.dart';
import 'package:workflow_app/features/meetings/presentation/api_meetings_view.dart';
import 'package:workflow_app/features/notifications/domain/app_notification.dart';
import 'package:workflow_app/features/work/presentation/task_details_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// What tapping [n] would open for this account, or `null`. Tasks exist
/// only for employees; demo items carry no server subject.
NotificationTarget? openableTarget(WidgetRef ref, AppNotification n) {
  if (ref.read(demoModeProvider)) return null;
  final t = n.target;
  if (t == null) return null;
  final portal = ref.read(sessionControllerProvider).value?.portal;
  if (t.kind == NotificationTargetKind.task && portal != Portal.employee) {
    return null;
  }
  return t;
}

/// A notification tap: an unread item is marked read ([markRead], in the
/// background — a failure is reported but does not hold up the page), and
/// the item's task, conversation or meeting opens above the shell. Back
/// returns to where the tap happened. An item without a known subject is
/// only marked read, as before.
Future<void> openNotification(
  BuildContext context,
  WidgetRef ref,
  AppNotification n, {
  required Future<void> Function() markRead,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final target = openableTarget(ref, n);
  if (!n.isRead) {
    final read = markRead().catchError((Object e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(localizedError(l10n, e))));
    });
    if (target == null) return await read;
    unawaited(read);
  }
  if (target == null || !context.mounted) return;
  final page = switch (target.kind) {
    NotificationTargetKind.task => ApiTaskByIdScreen(id: target.id),
    NotificationTargetKind.conversation => ChatScreen(id: '${target.id}'),
    NotificationTargetKind.meeting => ApiMeetingDetailsScreen(id: target.id),
  };
  await Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => page));
}
