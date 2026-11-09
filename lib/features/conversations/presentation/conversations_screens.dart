import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/conversations/data/conversations_repository.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

enum ConversationType { direct, group }

class ChatMessage {
  const new({
    required this.author,
    required this.text,
    required this.at,
    this.mine = false,
  });

  final String author;
  final String text;
  final DateTime at;
  final bool mine;
}

/// Presentation model for conversation cards and the chat screen.
class Conversation implements Identified {
  const new({
    required this.id,
    required this.name,
    required this.type,
    required this.role,
    required this.messages,
    this.unread = 0,
    this.members = const [],
  });

  @override
  final String id;
  final String name;
  final ConversationType type;

  /// Blue line under the name ("Lead Developer", "3 unread"…).
  final String role;
  final List<ChatMessage> messages;
  final int unread;
  final List<String> members;

  ChatMessage? get last => messages.isEmpty ? null : messages.last;

  String get initials => type == ConversationType.group
      ? '#${name.split('#').last.characters.take(3)}'
      : name
            .split(' ')
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p.characters.first.toUpperCase())
            .join();

  Conversation copyWith({List<ChatMessage>? messages, int? unread}) =>
      Conversation(
        id: id,
        name: name,
        type: type,
        role: role,
        messages: messages ?? this.messages,
        unread: unread ?? this.unread,
        members: members,
      );
}

/// Maps an API conversation onto the Figma presentation model.
Conversation conversationFromApi(ApiConversation c, int? me, String you) =>
    Conversation(
      id: '${c.id}',
      name: c.name,
      type: c.isGroup ? ConversationType.group : ConversationType.direct,
      role: '',
      unread: c.unread,
      members: c.members,
      messages: [
        for (final m in c.messages)
          ChatMessage(
            author: m.senderId == me ? you : m.senderName,
            text: m.text.isEmpty && m.attachments > 0
                ? '📎 ×${m.attachments}'
                : m.text,
            at: m.createdAt,
            mine: m.senderId == me,
          ),
      ],
    );

DateTime _today(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

final conversationsProvider =
    NotifierProvider<LocalCollection<Conversation>, List<Conversation>>(
      () => LocalCollection<Conversation>(
        () => [
          Conversation(
            id: 'cv1',
            name: 'Yousef',
            type: ConversationType.direct,
            role: 'Lead Developer',
            members: const ['Yousef'],
            messages: [
              ChatMessage(
                author: 'Yousef',
                text:
                    'Hello! I have configured the webhook triggers for the '
                    'new WorkFlow microservice cluster. Everything is syncing '
                    'seamlessly with the analytics database.',
                at: _today(12, 30),
              ),
              ChatMessage(
                author: 'You',
                mine: true,
                text:
                    'Great job Yousef! Could you send over the updated '
                    'latency payload logs? We need to review before the '
                    'board meeting tomorrow.',
                at: _today(12, 32),
              ),
              ChatMessage(
                author: 'Yousef',
                text: 'Hey! Check the new API response latency report...',
                at: _today(12, 33),
              ),
            ],
          ),
          Conversation(
            id: 'cv2',
            name: 'Innovatech #general',
            type: ConversationType.group,
            role: '',
            unread: 3,
            members: const ['Sarah', 'Omar', 'Lina'],
            messages: [
              ChatMessage(
                author: 'Sarah',
                text: 'Sprint 24 deployment is scheduled for 4 PM.',
                at: _today(11, 15),
              ),
            ],
          ),
          Conversation(
            id: 'cv3',
            name: 'Lina Haddad',
            type: ConversationType.direct,
            role: 'Product Designer',
            members: const ['Lina Haddad'],
            unread: 1,
            messages: [
              ChatMessage(
                author: 'Lina Haddad',
                text: 'Updated the Figma tokens for the sidebar.',
                at: DateTime.now().subtract(const Duration(days: 1)),
              ),
            ],
          ),
          Conversation(
            id: 'cv4',
            name: 'Ahmed Al-Saeed',
            type: ConversationType.direct,
            role: 'Financial Director',
            members: const ['Ahmed Al-Saeed'],
            messages: [
              ChatMessage(
                author: 'Ahmed Al-Saeed',
                text: 'The Q3 invoice clearance was signed.',
                at: DateTime.now().subtract(const Duration(days: 22)),
              ),
            ],
          ),
        ],
      ),
    );

String _stamp(BuildContext context, DateTime t) {
  final now = DateTime.now();
  final sameDay =
      t.year == now.year && t.month == now.month && t.day == now.day;
  return sameDay
      ? DateFormat.jm('en').format(t)
      : DateFormat('MMM d', 'en').format(t);
}

enum _Filter { all, direct, groups, unread }

/// Figma "Conversations" list (643:36662).
class ConversationsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demo = ref.watch(demoModeProvider);
    final me = ref.watch(sessionControllerProvider).value?.userId;
    final source = demo
        ? AsyncData(ref.watch(conversationsProvider))
        : ref
              .watch(apiConversationsProvider)
              .whenData(
                (list) => [
                  for (final c in list) conversationFromApi(c, me, l10n.you),
                ],
              );
    final all = source.value ?? const <Conversation>[];
    final q = _query.trim().toLowerCase();
    final unreadCount = all.where((c) => c.unread > 0).length;
    final visible = all.where((c) {
      final ok = switch (_filter) {
        _Filter.all => true,
        _Filter.direct => c.type == ConversationType.direct,
        _Filter.groups => c.type == ConversationType.group,
        _Filter.unread => c.unread > 0,
      };
      return ok &&
          (q.isEmpty ||
              '${c.name} ${c.last?.text ?? ''}'.toLowerCase().contains(q));
    }).toList();

    return ModulePage(
      title: l10n.catConversations,
      description: '',
      onSearch: (v) => setState(() => _query = v),
      // Demo only: the form lists demo people and the API's create and
      // available-users routes are not wired in yet.
      onCreate: () => openDemoForm(
        context,
        page: (_) => const NewConversationScreen(),
        unavailable: l10n.conversationCreateUnavailable,
      ),
      createLabel: l10n.newConversation,
      children: [
        ChipRow(
          children: [
            for (final f in _Filter.values)
              FilterChipBox(
                label: switch (f) {
                  _Filter.all => l10n.filterAll,
                  _Filter.direct => l10n.filterDirect,
                  _Filter.groups => l10n.filterTeams,
                  _Filter.unread => '${l10n.filterUnread} ($unreadCount)',
                },
                selected: _filter == f,
                onTap: () => setState(() => _filter = f),
              ),
          ],
        ),
        if (source is! AsyncData)
          AsyncSection(
            value: source,
            onRetry: () => ref.invalidate(apiConversationsProvider),
            builder: (_) => const SizedBox.shrink(),
          )
        else if (visible.isEmpty)
          EmptyNotice(text: l10n.noRecords),
        for (final c in visible)
          ModuleCard(
            key: Key('conversation-${c.id}'),
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: (_) => ChatScreen(id: c.id)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    WfAvatar(initials: c.initials),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: AppTextStyles.mobileLgSemiBold.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (c.last != null)
                            Text(
                              _stamp(context, c.last!.at),
                              style: AppTextStyles.mobileXsRegular.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  c.unread > 0 && c.type == ConversationType.group
                      ? l10n.unreadCount(c.unread)
                      : c.role,
                  style: AppTextStyles.mobileXsRegular.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  c.last == null
                      ? ''
                      : c.type == ConversationType.group
                      ? '${c.last!.author}: ${c.last!.text}'
                      : c.last!.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.mobileBaseRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Figma chat detail (643:37061).
class ChatScreen extends ConsumerStatefulWidget {
  const new({required this.id, super.key});

  final String id;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(demoModeProvider)) {
        unawaited(_markRead());
        return;
      }
      final n = ref.read(conversationsProvider.notifier);
      final c = n.byId(widget.id);
      if (c != null && c.unread > 0) n.replace(c.copyWith(unread: 0));
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int get _apiId => int.parse(widget.id);
  bool _sending = false;

  /// Clears the unread badge on the server; a failure only leaves the badge.
  Future<void> _markRead() async {
    try {
      await ref.read(conversationsRepositoryProvider).markRead(_apiId);
      ref.invalidate(apiConversationsProvider);
    } on ApiException {
      // Not a user action: the conversation still opens and stays unread.
    }
  }

  Future<void> _sendApi(String text) async {
    setState(() => _sending = true);
    try {
      await ref.read(conversationsRepositoryProvider).send(_apiId, text);
      _text.clear();
      ref
        ..invalidate(apiConversationProvider(_apiId))
        ..invalidate(apiConversationsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(context, localizedError(AppLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    if (!ref.read(demoModeProvider)) {
      unawaited(_sendApi(text));
      return;
    }
    final n = ref.read(conversationsProvider.notifier);
    final c = n.byId(widget.id);
    if (c == null) return;
    n.replace(
      c.copyWith(
        messages: [
          ...c.messages,
          ChatMessage(
            author: AppLocalizations.of(context).you,
            text: text,
            at: DateTime.now(),
            mine: true,
          ),
        ],
      ),
    );
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Conversation? found;
    if (ref.watch(demoModeProvider)) {
      found = ref
          .watch(conversationsProvider)
          .where((x) => x.id == widget.id)
          .firstOrNull;
    } else {
      final api = ref.watch(apiConversationProvider(_apiId));
      if (api is! AsyncData<ApiConversation>) {
        return Scaffold(
          backgroundColor: AppColors.appBackground,
          appBar: AppBar(),
          body: AsyncSection(
            value: api,
            onRetry: () => ref.invalidate(apiConversationProvider(_apiId)),
            builder: (_) => const SizedBox.shrink(),
          ),
        );
      }
      found = conversationFromApi(
        api.value,
        ref.watch(sessionControllerProvider).value?.userId,
        l10n.you,
      );
    }
    final c = found;
    if (c == null) {
      return Scaffold(body: EmptyNotice(text: l10n.noRecords));
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    void pending() => showSnack(context, l10n.callsPending);
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppRadii.masthead),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          onPressed: () => Navigator.of(context).maybePop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 40,
                          ),
                          icon: RotatedBox(
                            quarterTurns: rtl ? 3 : 1,
                            child: const WfSvg(
                              'field_arrow_down',
                              size: 20,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          // Shrinks before it truncates: at 320 px with
                          // large text the name was cut to its first letter.
                          child: FitText(
                            c.name,
                            minScale: 0.55,
                            style: AppTextStyles.mobile5xlBold.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ),
                        _HeaderIcon('chat_phone', l10n.call, pending),
                        _HeaderIcon('chat_video', l10n.videoCall, pending),
                        _HeaderIcon(
                          'chat_info',
                          l10n.conversationInfo,
                          () => showRecordDetails(
                            context,
                            title: c.name,
                            status: c.type == ConversationType.group
                                ? l10n.groupChat
                                : l10n.privateChat,
                            tone: BadgeTone.info,
                            fields: [
                              DetailField(
                                l10n.participants,
                                c.members.join(', '),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '● ${_presence(l10n, c)}',
                      style: AppTextStyles.mobileBaseRegular.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                for (final m in c.messages.reversed) ...[
                  _Bubble(message: m),
                  const SizedBox(height: 20),
                ],
                Text(
                  DateFormat(
                    'EEEE, MMMM d, y',
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(
                    c.messages.isEmpty ? DateTime.now() : c.messages.first.at,
                  ),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.mobileXsRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: StatusBadge(
                    label: c.type == ConversationType.group
                        ? l10n.groupChat
                        : l10n.privateChat,
                    tone: BadgeTone.info,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border.all(color: ModuleColors.chipBorder),
            ),
            padding: const EdgeInsets.all(12),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('chat-input'),
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: AppTextStyles.mobileBaseRegular.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: l10n.messageHint,
                      hintStyle: AppTextStyles.mobileBaseRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // 40 px targets (a 20 px icon and the Figma 20 px
                      // gap), each saying why it is not available yet.
                      for (final (key, icon, tip, why) in [
                        (
                          'chat-emoji',
                          'chat_smile',
                          l10n.tipEmoji,
                          l10n.emojiUseKeyboard,
                        ),
                        (
                          'chat-attach',
                          'chat_attach',
                          l10n.tipAttachFile,
                          l10n.attachmentsPending,
                        ),
                        (
                          'chat-image',
                          'chat_image',
                          l10n.tipAttachImage,
                          l10n.attachmentsPending,
                        ),
                        (
                          'chat-mic',
                          'chat_mic',
                          l10n.tipVoice,
                          l10n.voiceNotSupported,
                        ),
                      ])
                        Tooltip(
                          message: tip,
                          child: InkResponse(
                            key: Key(key),
                            radius: 20,
                            onTap: () => showSnack(context, why),
                            child: SizedBox.square(
                              dimension: 40,
                              child: Center(child: WfSvg(icon, size: 20)),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: const Key('chat-send'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: _sending ? null : _send,
                          child: SizedBox.square(
                            dimension: 40,
                            child: Center(
                              // A spinner while the server has the message.
                              child: _sending
                                  ? const SizedBox.square(
                                      key: Key('chat-sending'),
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.white,
                                      ),
                                    )
                                  : const WfSvg('chat_send', size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const new(this.icon, this.tooltip, this.onTap);
  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: WfSvg(icon, size: 20),
  );
}

class _Bubble extends StatelessWidget {
  const new({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = message;
    final avatar = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        m.author.characters.first.toUpperCase(),
        style: AppTextStyles.desktopXsSemiBold.copyWith(
          color: AppColors.primary,
        ),
      ),
    );
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: m.mine ? AppColors.primary50 : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: m.mine ? null : Border.all(color: ModuleColors.chipBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${m.mine ? l10n.you : m.author} · '
              '${DateFormat.jm('en').format(m.at)}',
              style: AppTextStyles.mobileBaseSemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: m.mine ? 10 : 16),
            Text(
              m.text,
              style: AppTextStyles.mobileBaseRegular.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (m.mine) ...[
              const SizedBox(height: 10),
              Text(
                '${l10n.delivered} ✓',
                style: AppTextStyles.mobileXsRegular.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: m.mine
          ? [
              const SizedBox(width: 12),
              bubble,
              const SizedBox(width: 10),
              avatar,
            ]
          : [
              avatar,
              const SizedBox(width: 10),
              bubble,
              const SizedBox(width: 12),
            ],
    );
  }
}

class _Person {
  const new(this.name, this.email, this.role, this.company);
  final String name;
  final String email;
  final String role;
  final String company;
}

const _people = [
  _Person(
    'Alaa Eldin Aldohdar',
    'alaamhammad2003@gmail.com',
    'EMPLOYEE',
    'WORKFLOW',
  ),
  _Person('Yousef', 'yousefnaim047@gmail.com', 'EMPLOYEE', 'WORKFLOW'),
  _Person('Mahmoud', 'mahmoudsalem3321@gmail.com', 'EMPLOYEE', 'WORKFLOW'),
  _Person('علي', 'yousefnaim04700@gmail.com', 'CLIENT', 'WORKFLOW'),
  _Person(
    'Omar Demo-Rashed',
    'employee2@gmail.com',
    'EMPLOYEE',
    'WORKFLOW DEMO COMPANY',
  ),
  _Person(
    'Layla Demo-Jaber',
    'employee1@gmail.com',
    'EMPLOYEE',
    'WORKFLOW DEMO COMPANY',
  ),
];

/// Figma "Create a new conversation" (643:37434).
class NewConversationScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  ConversationType _type = ConversationType.group;
  final _selected = <String>{};
  String _query = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final l10n = AppLocalizations.of(context);
    if (!validateAndReveal(_form)) return;
    if (_selected.isEmpty ||
        (_type == ConversationType.direct && _selected.length != 1)) {
      showSnack(
        context,
        _type == ConversationType.direct
            ? l10n.selectOnePerson
            : l10n.selectParticipants,
      );
      return;
    }
    final members = _selected.toList();
    final conversation = Conversation(
      id: localId('cv'),
      name: _type == ConversationType.group ? _name.text.trim() : members.first,
      type: _type,
      role: '',
      members: members,
      messages: const [],
    );
    if (!ref.read(conversationsProvider.notifier).add(conversation)) {
      showLocalOutcome(context, applied: false);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ChatScreen(id: conversation.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final groups = <String, List<_Person>>{};
    for (final p in _people) {
      if (q.isNotEmpty && !'${p.name} ${p.email}'.toLowerCase().contains(q)) {
        continue;
      }
      groups.putIfAbsent(p.company, () => []).add(p);
    }
    final label = AppTextStyles.mobileBaseSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Form(
          key: _form,
          // Built all at once so the group name keeps its error while the
          // user is down at the participant list.
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
                          // A direct chat has one other person: keep only the
                          // first pick instead of a selection that can't be
                          // submitted.
                          if (_type == ConversationType.direct &&
                              _selected.length > 1) {
                            final keep = _selected.first;
                            _selected
                              ..clear()
                              ..add(keep);
                          }
                        }),
                      ),
                      if (_type == ConversationType.group) ...[
                        const SizedBox(height: 16),
                        TextInputField(
                          fieldKey: const Key('group-name'),
                          label: l10n.groupName,
                          hint: l10n.groupName,
                          controller: _name,
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.groupPicture, style: label),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              showSnack(context, l10n.attachmentsPending),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: AlignmentDirectional.centerStart,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: ModuleColors.chipBorder,
                              ),
                            ),
                            child: Text(
                              '${l10n.chooseFile}   ·   ${l10n.noFileChosen}',
                              style: AppTextStyles.mobileBaseRegular.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.participants,
                  style: AppTextStyles.mobileLgSemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                ModuleCard(
                  child: Text(
                    _type == ConversationType.group
                        ? l10n.selectParticipants
                        : l10n.selectOnePerson,
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
                for (final entry in groups.entries) ...[
                  const SizedBox(height: 20),
                  Text(entry.key, style: label),
                  for (final p in entry.value) ...[
                    const SizedBox(height: 20),
                    InkWell(
                      key: Key('participant-${p.email}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() {
                        if (_type == ConversationType.direct) _selected.clear();
                        _selected.contains(p.name)
                            ? _selected.remove(p.name)
                            : _selected.add(p.name);
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
                              _selected.contains(p.name)
                                  ? 'checkbox_checked'
                                  : 'checkbox_empty',
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${p.name}\n${p.email}\n${p.role}',
                                style: AppTextStyles.mobileXsRegular.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const Key('create-conversation'),
                    onPressed: _create,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                        side: const BorderSide(color: AppColors.borderDefault),
                      ),
                      textStyle: AppTextStyles.mobileBaseSemiBold,
                    ),
                    child: Text(
                      _type == ConversationType.group
                          ? l10n.createGroup
                          : l10n.startChat,
                    ),
                  ),
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
}

String _presence(AppLocalizations l10n, Conversation c) =>
    c.type == ConversationType.group
    ? l10n.membersCount(c.members.length)
    : l10n.activeNow;
