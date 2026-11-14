import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/conversations/data/conversations_repository.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// The chat's info sheet in API mode: who is in the conversation and the
/// actions the client route table documents for it.
///
/// - **Rename** (`PUT …/{id}` with `title`) for group conversations only:
///   a direct chat is named after the other person.
/// - **Delete for me** (`DELETE …/{id}`): hides the conversation for the
///   caller; the others keep it.
///
/// Adding or removing members and changing roles are documented as "admin
/// members only", but no response says who is an admin, so they are not
/// offered (`docs/api-contract-gaps.md` M11).
Future<void> showApiConversationInfo(
  BuildContext context, {
  required int id,
  required String name,
  required bool isGroup,
  required List<String> members,
}) {
  final l10n = AppLocalizations.of(context);
  // The chat's own messenger and navigator: the sheet's context is gone by
  // the time a delete has closed the chat.
  final chat = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheet) => RecordDetailsBody(
      title: name,
      status: isGroup ? l10n.groupChat : l10n.privateChat,
      tone: BadgeTone.info,
      fields: [DetailField(l10n.participants, members.join(', '))],
      footer: _ConversationActions(
        id: id,
        name: name,
        isGroup: isGroup,
        onDeleted: () {
          Navigator.of(sheet).pop();
          chat.maybePop();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(l10n.conversationDeletedForMe)),
            );
        },
      ),
    ),
  );
}

class _ConversationActions extends ConsumerStatefulWidget {
  const new({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.onDeleted,
  });

  final int id;
  final String name;
  final bool isGroup;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ConversationActions> createState() =>
      _ConversationActionsState();
}

class _ConversationActionsState extends ConsumerState<_ConversationActions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(context, localizedError(AppLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context);
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: widget.name),
    );
    if (title == null || title == widget.name || !mounted) return;
    await _run(() async {
      await ref.read(conversationsRepositoryProvider).rename(widget.id, title);
      ref
        ..invalidate(apiConversationProvider(widget.id))
        ..invalidate(apiConversationsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, l10n.conversationRenamed);
    });
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDelete(
      context,
      widget.name,
      title: l10n.deleteConversationForMe,
      body: l10n.deleteConversationForMeBody,
      confirmLabel: l10n.deleteConversationForMe,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await ref.read(conversationsRepositoryProvider).deleteForMe(widget.id);
      ref.invalidate(apiConversationsProvider);
      if (mounted) widget.onDeleted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isGroup) ...[
            OutlinedButton(
              key: const Key('conversation-rename'),
              onPressed: _busy ? null : _rename,
              child: Text(l10n.renameConversation),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton(
            key: const Key('conversation-delete-for-me'),
            onPressed: _busy ? null : _delete,
            style: OutlinedButton.styleFrom(
              foregroundColor: ModuleColors.dangerFg,
            ),
            child: _busy
                ? const SizedBox.square(
                    key: Key('conversation-action-busy'),
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.deleteConversationForMe),
          ),
        ],
      ),
    );
  }
}

/// `title`: required, ≤ 255 characters (the route's validation).
class _RenameDialog extends StatefulWidget {
  const new({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_title.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.renameConversation),
      content: Form(
        key: _form,
        child: TextInputField(
          fieldKey: const Key('conversation-title'),
          label: l10n.conversationName,
          controller: _title,
          validator: (v) =>
              (v ?? '').trim().length > 255 ? l10n.validationMax255 : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('conversation-title-save'),
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
