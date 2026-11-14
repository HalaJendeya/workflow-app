import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/conversations/data/conversations_repository.dart';
import 'package:workflow_app/features/conversations/presentation/conversations_screens.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Figma "Create a new conversation" (643:37434) against the API.
///
/// `GET …/available-users` says who can be added, which `type` to create
/// (`default_type`) and whether groups are allowed (`can_create_group`; a
/// client may not). `POST …/conversations` creates it and the chat opens.
class ApiNewConversationScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ApiNewConversationScreen> createState() =>
      _ApiNewConversationScreenState();
}

class _ApiNewConversationScreenState
    extends ConsumerState<ApiNewConversationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  ConversationType _type = ConversationType.direct;
  final _selected = <int>{};
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create(ConversationOptions options) async {
    final l10n = AppLocalizations.of(context);
    if (_busy || !validateAndReveal(_form)) return;
    final group = _type == ConversationType.group;
    if (_selected.isEmpty || (!group && _selected.length != 1)) {
      showSnack(
        context,
        group ? l10n.selectParticipants : l10n.selectOnePerson,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(conversationsRepositoryProvider)
          .create(
            users: _selected.toList(),
            type: options.defaultType,
            title: group ? _name.text : null,
          );
      ref.invalidate(apiConversationsProvider);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ChatScreen(id: '$id')),
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, localizedError(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = ref.watch(conversationOptionsProvider);
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.newConversationTitle,
                  style: AppTextStyles.mobile2xlSemiBold.copyWith(
                    fontSize: 22,
                    height: 31 / 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.newConversationBody,
                  style: AppTextStyles.mobileBaseRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                AsyncSection(
                  value: options,
                  onRetry: () => ref.invalidate(conversationOptionsProvider),
                  builder: (o) => _body(l10n, o),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: ModuleColors.chipBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                      textStyle: AppTextStyles.mobileBaseSemiBold,
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, ConversationOptions o) {
    final group = o.canCreateGroup && _type == ConversationType.group;
    final q = _query.trim().toLowerCase();
    final people = [
      for (final u in o.users)
        if (q.isEmpty || u.name.toLowerCase().contains(q)) u,
    ];
    final label = AppTextStyles.mobileLgSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Groups only where the server allows them.
        if (o.canCreateGroup)
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectField<ConversationType>(
                  label: l10n.conversationType,
                  value: _type,
                  options: ConversationType.values,
                  labelOf: (t) => t == ConversationType.group
                      ? l10n.typeGroup
                      : l10n.typeDirect,
                  onChanged: (t) => setState(() {
                    _type = t ?? _type;
                    if (_type == ConversationType.direct &&
                        _selected.length > 1) {
                      final keep = _selected.first;
                      _selected
                        ..clear()
                        ..add(keep);
                    }
                  }),
                ),
                if (group) ...[
                  const SizedBox(height: 16),
                  TextInputField(
                    fieldKey: const Key('group-name'),
                    label: l10n.groupName,
                    hint: l10n.groupName,
                    controller: _name,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text(l10n.participants, style: label),
        const SizedBox(height: 20),
        ModuleCard(
          child: Text(
            group ? l10n.selectParticipants : l10n.selectOnePerson,
            style: AppTextStyles.mobileBaseRegular.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        WfSearchBox(
          hint: l10n.searchConversationsHint,
          onChanged: (v) => setState(() => _query = v),
        ),
        if (o.users.isEmpty) ...[
          const SizedBox(height: 20),
          EmptyNotice(
            key: const Key('no-available-users'),
            text: l10n.noAvailableUsers,
          ),
        ],
        for (final u in people) ...[
          const SizedBox(height: 20),
          InkWell(
            key: Key('participant-${u.id}'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              if (!group) _selected.clear();
              _selected.contains(u.id)
                  ? _selected.remove(u.id)
                  : _selected.add(u.id);
            }),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ModuleColors.chipBorder),
              ),
              child: Row(
                children: [
                  WfSvg(
                    _selected.contains(u.id)
                        ? 'checkbox_checked'
                        : 'checkbox_empty',
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      u.name,
                      style: AppTextStyles.mobileBaseRegular.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton(
            key: const Key('create-conversation'),
            onPressed: o.users.isEmpty || _busy ? null : () => _create(o),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
                side: const BorderSide(color: AppColors.borderDefault),
              ),
              textStyle: AppTextStyles.mobileBaseSemiBold,
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      key: Key('create-conversation-busy'),
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(group ? l10n.createGroup : l10n.startChat),
          ),
        ),
      ],
    );
  }
}
