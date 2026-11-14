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
import 'package:workflow_app/features/conversations/presentation/api_conversation_actions.dart';
import 'package:workflow_app/features/conversations/presentation/api_new_conversation_screen.dart';
import 'package:workflow_app/features/conversations/presentation/chat_attachment_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/profile/data/profile_repository.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

enum ConversationType { direct, group }

/// Where a message I wrote is: on the server ([sent]), on its way
/// ([sending]) or refused ([failed], with Retry).
enum ChatSendState { sent, sending, failed }

class ChatMessage {
  const new({
    required this.author,
    required this.text,
    required this.at,
    this.mine = false,
    this.key,
    this.sendState = ChatSendState.sent,
    this.attachmentIds = const [],
    this.uploadProgress,
  });

  final String author;
  final String text;
  final DateTime at;
  final bool mine;

  /// Stable identity in the list: `server-<id>` or `local-<n>`.
  final String? key;
  final ChatSendState sendState;

  /// Server attachment ids (`null` for a row without one); for my queued
  /// message, one `null` per file.
  final List<int?> attachmentIds;

  /// 0–1 while my message's files upload.
  final double? uploadProgress;
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
            key: 'server-${m.id}',
            author: m.senderId == me ? you : m.senderName,
            text: m.text,
            attachmentIds: [for (final a in m.attachments) a.id],
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

  /// API mode: the list (unread counts, latest messages) refreshes while it
  /// is open; the rows stay on screen during the refresh.
  static const refreshEvery = Duration(seconds: 30);
  Timer? _refresher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(demoModeProvider)) return;
      _refresher = Timer.periodic(refreshEvery, (_) {
        // Only while the list is what the person sees: not in the
        // background, not under an open chat (which marks read and
        // refreshes the list itself).
        if (!mounted) return;
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
          return;
        }
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        ref.invalidate(apiConversationsProvider);
      });
    });
  }

  @override
  void dispose() {
    _refresher?.cancel();
    super.dispose();
  }

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
      // API mode: who can be added and which type to create come from
      // `available-users`; demo mode keeps the demo form.
      onCreate: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => demo
              ? const NewConversationScreen()
              : const ApiNewConversationScreen(),
        ),
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
        // A failed refresh says so above the rows it could not update; only
        // a first load shows the spinner.
        if (source case AsyncError(:final error))
          ApiErrorCard(
            error: error,
            onRetry: () => ref.invalidate(apiConversationsProvider),
          )
        else if (!source.hasValue)
          AsyncSection(
            value: source,
            onRetry: () => ref.invalidate(apiConversationsProvider),
            builder: (_) => const SizedBox.shrink(),
          )
        else if (visible.isEmpty)
          // "No records match these filters" only when a filter or search
          // hid them; an empty inbox says so.
          EmptyNotice(
            text: _filter == _Filter.all && _query.trim().isEmpty
                ? l10n.noConversationsYet
                : l10n.noRecords,
          ),
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
                      ? '${c.last!.author}: ${_preview(c.last!)}'
                      : _preview(c.last!),
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

/// A message as one line: its text, or a paperclip and the file count.
String _preview(ChatMessage m) => m.text.isEmpty && m.attachmentIds.isNotEmpty
    ? '📎 ×${m.attachmentIds.length}'
    : m.text;

/// Figma chat detail (643:37061).
class ChatScreen extends ConsumerStatefulWidget {
  const new({required this.id, super.key});

  final String id;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

/// A message typed in this chat that the server has not confirmed yet.
class _Outgoing {
  new(this.localId, this.text, this.at, [this.files = const []]);

  final int localId;
  final String text;
  final DateTime at;

  /// Checked against the route's rules before it was queued.
  final List<OutgoingFile> files;
  bool failed = false;
  double? progress;
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();

  /// How often an open chat asks for newer messages (`after_id`). There is
  /// no realtime channel for conversations in the app.
  static const pollEvery = Duration(seconds: 10);
  Timer? _poller;

  /// Set while the latest poll failed; cleared by the next success. Shown
  /// as a quiet "reconnecting" line, never a full-screen error.
  bool _offline = false;

  /// Typed messages waiting for (or refused by) the server, oldest first.
  final _outgoing = <_Outgoing>[];
  int _nextLocalId = 0;
  bool _sending = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(demoModeProvider)) {
        WidgetsBinding.instance.addObserver(this);
        unawaited(_markRead());
        _poller = Timer.periodic(pollEvery, (_) => _tick());
        return;
      }
      final n = ref.read(conversationsProvider.notifier);
      final c = n.byId(widget.id);
      if (c != null && c.unread > 0) n.replace(c.copyWith(unread: 0));
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _poller?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  /// Back in the foreground (or back online after the phone slept): catch
  /// up at once instead of waiting for the next tick.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_poll());
  }

  bool get _alive => mounted && !_disposed;

  /// The timer polls only while this chat is what the person sees: not in
  /// the background, not under another page or sheet.
  void _tick() {
    if (!_alive) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    unawaited(_poll());
  }

  int get _apiId => int.parse(widget.id);

  /// Newer messages; other people's arrivals are marked read since the chat
  /// is open. A failed poll keeps the thread and flags the connection; the
  /// next tick retries.
  Future<void> _poll({bool fresh = false}) async {
    if (!_alive) return;
    try {
      final n = await ref
          .read(conversationThreadProvider(_apiId).notifier)
          .poll(fresh: fresh);
      if (!_alive) return;
      if (_offline) setState(() => _offline = false);
      if (n > 0) await _markRead();
    } on ApiException {
      if (_alive && !_offline) setState(() => _offline = true);
    }
  }

  /// Clears the unread badge on the server; a failure only leaves the badge.
  Future<void> _markRead() async {
    if (!_alive) return;
    try {
      await ref.read(conversationsRepositoryProvider).markRead(_apiId);
      if (_alive) ref.invalidate(apiConversationsProvider);
    } on ApiException {
      // Not a user action: the conversation still opens and stays unread.
    }
  }

  /// Sends queued messages one at a time, in the order they were typed.
  Future<void> _drain() async {
    if (_sending) return;
    _sending = true;
    try {
      while (_alive) {
        final next = _outgoing.where((o) => !o.failed).firstOrNull;
        if (next == null) break;
        if (!await _deliver(next)) break;
      }
    } finally {
      _sending = false;
      if (_alive) setState(() {});
    }
  }

  /// One message. On success it leaves the outgoing list and joins the
  /// thread (from the send response, or the next poll); on failure it stays
  /// as "Not sent" with Retry, and later messages wait behind it.
  Future<bool> _deliver(_Outgoing o) async {
    final repo = ref.read(conversationsRepositoryProvider);
    final thread = ref.read(conversationThreadProvider(_apiId).notifier);
    try {
      final sent = await repo.send(
        _apiId,
        o.text,
        files: o.files,
        onProgress: o.files.isEmpty
            ? null
            : (p) {
                if (_alive) setState(() => o.progress = p);
              },
      );
      if (!_alive) return false;
      if (sent != null) thread.addSent(sent);
      setState(() => _outgoing.remove(o));
      if (sent == null) await _poll(fresh: true);
      if (_alive) ref.invalidate(apiConversationsProvider);
      return true;
    } on ApiException catch (e) {
      if (!mounted || _disposed) return false;
      setState(() {
        o
          ..failed = true
          ..progress = null;
      });
      showSnack(context, localizedError(AppLocalizations.of(context), e));
      return false;
    }
  }

  void _retry(int localId) {
    final o = _outgoing.where((x) => x.localId == localId).firstOrNull;
    if (o == null) return;
    setState(() => o.failed = false);
    unawaited(_drain());
  }

  void _discard(int localId) =>
      setState(() => _outgoing.removeWhere((x) => x.localId == localId));

  /// Files from the platform picker (none without one), checked against
  /// the route's limits before anything is queued or uploaded. The typed
  /// text goes with them.
  Future<void> _attach({required bool images}) async {
    final l10n = AppLocalizations.of(context);
    final pick = ref.read(attachmentPickerProvider);
    if (pick == null) {
      showSnack(context, l10n.attachmentsPending);
      return;
    }
    final files = await pick(context, images: images);
    if (!mounted || _disposed || files == null || files.isEmpty) return;
    if (checkAttachments(files) case final problem?) {
      showSnack(context, attachmentProblemText(l10n, problem));
      return;
    }
    final text = _text.text.trim();
    setState(() {
      _outgoing.add(_Outgoing(_nextLocalId++, text, DateTime.now(), files));
      _text.clear();
    });
    unawaited(_drain());
  }

  /// Attachments whose bytes are on the way: a second tap waits for them.
  final _opening = <int>{};

  Future<void> _openAttachment(int? attachmentId) async {
    final l10n = AppLocalizations.of(context);
    if (attachmentId == null) {
      showSnack(context, l10n.attachmentUnavailable);
      return;
    }
    if (!_opening.add(attachmentId)) return;
    setState(() {});
    try {
      final file = await ref
          .read(conversationsRepositoryProvider)
          .downloadAttachment(
            _apiId,
            attachmentId,
            companyId: ref.read(sessionControllerProvider).value?.companyId,
          );
      // The chip is ready again before the preview opens.
      _opening.remove(attachmentId);
      if (!mounted || _disposed) return;
      setState(() {});
      await showAttachmentPreview(context, file);
    } on ApiException catch (e) {
      _opening.remove(attachmentId);
      if (!mounted || _disposed) return;
      setState(() {});
      showSnack(context, localizedError(l10n, e));
    }
  }

  Future<void> _loadEarlier() async {
    try {
      await ref.read(conversationThreadProvider(_apiId).notifier).loadEarlier();
    } on ApiException catch (e) {
      if (mounted && !_disposed) {
        showSnack(context, localizedError(AppLocalizations.of(context), e));
      }
    } finally {
      if (_alive) setState(() {});
    }
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    if (!ref.read(demoModeProvider)) {
      // The input clears at once; the message shows as "Sending…" until the
      // server confirms it, so typing the next one never races the send.
      setState(() {
        _outgoing.add(_Outgoing(_nextLocalId++, text, DateTime.now()));
        _text.clear();
      });
      unawaited(_drain());
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
    var earlier = false;
    AsyncValue<MessageThread>? thread;
    if (ref.watch(demoModeProvider)) {
      found = ref
          .watch(conversationsProvider)
          .where((x) => x.id == widget.id)
          .firstOrNull;
    } else {
      final api = ref.watch(apiConversationProvider(_apiId));
      // A refresh keeps the conversation on screen; only the first load
      // (or a failure with nothing to show) replaces it.
      final detail = api.value;
      if (detail == null) {
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
      final loaded = ref.watch(conversationThreadProvider(_apiId));
      thread = loaded;
      earlier = loaded.value?.hasEarlier ?? false;
      found = conversationFromApi(
        detail.withMessages(loaded.value?.messages ?? detail.messages),
        ref.watch(sessionControllerProvider).value?.userId,
        l10n.you,
      );
    }
    final c = found;
    if (c == null) {
      return Scaffold(body: EmptyNotice(text: l10n.noRecords));
    }
    // Server messages (by id), then what I typed that is still on its way.
    final shown = [
      ...c.messages,
      for (final o in _outgoing)
        ChatMessage(
          key: 'local-${o.localId}',
          author: l10n.you,
          text: o.text,
          at: o.at,
          mine: true,
          sendState: o.failed ? ChatSendState.failed : ChatSendState.sending,
          attachmentIds: [for (final _ in o.files) null],
          uploadProgress: o.progress,
        ),
    ];
    final loadingEarlier =
        thread != null &&
        ref.read(conversationThreadProvider(_apiId).notifier).loadingEarlier;
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
                          () => thread != null
                              ? showApiConversationInfo(
                                  context,
                                  id: _apiId,
                                  name: c.name,
                                  isGroup: c.type == ConversationType.group,
                                  members: c.members,
                                )
                              : showRecordDetails(
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
                for (final m in shown.reversed) ...[
                  _Bubble(
                    key: m.key == null ? null : ValueKey('message-${m.key}'),
                    message: m,
                    opening: _opening,
                    onOpenAttachment: m.key?.startsWith('server-') ?? false
                        ? _openAttachment
                        : null,
                    onRetry: m.key?.startsWith('local-') ?? false
                        ? () => _retry(int.parse(m.key!.substring(6)))
                        : null,
                    onDiscard: m.key?.startsWith('local-') ?? false
                        ? () => _discard(int.parse(m.key!.substring(6)))
                        : null,
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  DateFormat(
                    'EEEE, MMMM d, y',
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(shown.isEmpty ? DateTime.now() : shown.first.at),
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
                // Top of the (reversed) list: older history and thread
                // errors.
                if (thread case AsyncError(:final error) when !thread.hasValue)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ApiErrorCard(
                      error: error,
                      onRetry: () =>
                          ref.invalidate(conversationThreadProvider(_apiId)),
                    ),
                  ),
                if (earlier)
                  Center(
                    child: loadingEarlier
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox.square(
                              key: Key('chat-loading-earlier'),
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton(
                            key: const Key('chat-load-earlier'),
                            onPressed: () => unawaited(_loadEarlier()),
                            child: Text(l10n.loadEarlierMessages),
                          ),
                  ),
              ],
            ),
          ),
          if (_offline)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              child: Text(
                l10n.chatReconnecting,
                key: const Key('chat-offline'),
                textAlign: TextAlign.center,
                style: AppTextStyles.mobileXsRegular.copyWith(
                  color: AppColors.textSecondary,
                ),
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
                            onTap:
                                thread != null &&
                                    (key == 'chat-attach' ||
                                        key == 'chat-image')
                                ? () => unawaited(
                                    _attach(images: key == 'chat-image'),
                                  )
                                : () => showSnack(context, why),
                            child: SizedBox.square(
                              dimension: 40,
                              child: Center(child: WfSvg(icon, size: 20)),
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Icon-only: the tooltip is also its TalkBack label.
                      Tooltip(
                        message: l10n.tipSend,
                        child: Material(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            key: const Key('chat-send'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: _send,
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

class _Bubble extends ConsumerWidget {
  const new({
    required this.message,
    this.onRetry,
    this.onDiscard,
    this.onOpenAttachment,
    this.opening = const {},
    super.key,
  });
  final ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;
  final void Function(int? attachmentId)? onOpenAttachment;
  final Set<int> opening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final m = message;
    // My own bubbles carry my initials. The author of a mine message is the
    // localized "You", whose first letter would mimic the other person's.
    final mineInitials = m.mine
        ? ref.watch(profileProvider).value?.initials ?? ''
        : '';
    final initials = mineInitials.isNotEmpty
        ? mineInitials
        : m.author.characters.first.toUpperCase();
    final avatar = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        key: m.mine ? const Key('chat-mine-avatar') : null,
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
            if (m.text.isNotEmpty)
              Text(
                m.text,
                style: AppTextStyles.mobileBaseRegular.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            if (m.attachmentIds.isNotEmpty) ...[
              if (m.text.isNotEmpty) const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < m.attachmentIds.length; i++)
                    AttachmentChip(
                      key: Key(
                        m.attachmentIds[i] == null
                            ? 'attachment-${m.key}-$i'
                            : 'attachment-${m.attachmentIds[i]}',
                      ),
                      label: m.attachmentIds.length == 1
                          ? l10n.attachment
                          : '${l10n.attachment} ${i + 1}',
                      busy: opening.contains(m.attachmentIds[i]),
                      onOpen: onOpenAttachment == null
                          ? null
                          : () => onOpenAttachment!(m.attachmentIds[i]),
                    ),
                ],
              ),
            ],
            if (m.uploadProgress case final p?
                when m.sendState == ChatSendState.sending) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                key: const Key('chat-upload-progress'),
                value: p,
              ),
            ],
            if (m.mine) ...[
              const SizedBox(height: 10),
              switch (m.sendState) {
                ChatSendState.sent => Text(
                  '${l10n.delivered} ✓',
                  style: AppTextStyles.mobileXsRegular.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                ChatSendState.sending => Text(
                  l10n.messageSending,
                  key: const Key('chat-message-sending'),
                  style: AppTextStyles.mobileXsRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                ChatSendState.failed => Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      l10n.messageNotSent,
                      key: const Key('chat-message-failed'),
                      style: AppTextStyles.mobileXsRegular.copyWith(
                        color: ModuleColors.dangerFg,
                      ),
                    ),
                    TextButton(
                      key: const Key('chat-message-retry'),
                      onPressed: onRetry,
                      child: Text(l10n.retry),
                    ),
                    TextButton(
                      key: const Key('chat-message-discard'),
                      onPressed: onDiscard,
                      child: Text(l10n.discard),
                    ),
                  ],
                ),
              },
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
