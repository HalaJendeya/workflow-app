import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/content_text.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/conversations/data/chat_attachments.dart';
import 'package:workflow_app/features/conversations/data/file_picker_attachments.dart';
import 'package:workflow_app/features/conversations/presentation/chat_attachment_widgets.dart';
import 'package:workflow_app/features/meetings/data/meeting_collaboration_repository.dart';
import 'package:workflow_app/features/meetings/data/meetings_repository.dart'
    show apiMeetingProvider;
import 'package:workflow_app/features/meetings/presentation/meeting_room_screen.dart'
    show RoomColors;
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// The meeting tools of the in-call frames (chat 670:2505, polls 671:3024,
/// notes 672:5044 — "Meeting Tool Navigation Tabs"). A client sends chat
/// messages (with one file when the meeting allows file sharing) and votes
/// in polls; notes, decisions and action items are view only (their writes
/// need `meetings.update`, which clients lack). Decisions and action items
/// have no frame; they reuse the notes panel's layout.
enum MeetingTool { chat, polls, notes, decisions, actionItems }

String meetingToolLabel(AppLocalizations l10n, MeetingTool t) => switch (t) {
  MeetingTool.chat => l10n.featureChat,
  MeetingTool.polls => l10n.polls,
  MeetingTool.notes => l10n.notes,
  MeetingTool.decisions => l10n.meetingDecisions,
  MeetingTool.actionItems => l10n.meetingActionItems,
};

/// The tools a meeting offers: chat only when the meeting allows it.
List<MeetingTool> meetingToolsFor({required bool allowChat}) => [
  if (allowChat) MeetingTool.chat,
  MeetingTool.polls,
  MeetingTool.notes,
  MeetingTool.decisions,
  MeetingTool.actionItems,
];

TextStyle _t(double size, Color color, [FontWeight w = FontWeight.w500]) =>
    AppTextStyles.mobileBaseRegular.copyWith(
      fontSize: size,
      height: 1.4,
      color: color,
      fontWeight: w,
    );

/// The horizontal tool tabs of the room frames. Tapping the selected tab
/// again deselects it ([onSelect] with `null`) when [allowNone].
class MeetingToolTabs extends StatelessWidget {
  const new({
    required this.tools,
    required this.selected,
    required this.onSelect,
    this.allowNone = false,
    super.key,
  });

  final List<MeetingTool> tools;
  final MeetingTool? selected;
  final ValueChanged<MeetingTool?> onSelect;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 48,
      child: ListView(
        key: const Key('meeting-tool-tabs'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final t in tools)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Semantics(
                selected: t == selected,
                button: true,
                child: Material(
                  color: t == selected ? RoomColors.blue : RoomColors.chip,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: Key('meeting-tool-${t.name}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () =>
                        onSelect(t == selected && allowNone ? null : t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Center(
                        child: Text(
                          meetingToolLabel(l10n, t),
                          style: _t(
                            12,
                            t == selected
                                ? AppColors.white
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One tool's content for [meetingId].
class MeetingToolPanel extends StatelessWidget {
  const new({required this.meetingId, required this.tool, super.key});

  final int meetingId;
  final MeetingTool tool;

  @override
  Widget build(BuildContext context) => switch (tool) {
    MeetingTool.chat => _ChatPanel(meetingId: meetingId),
    MeetingTool.polls => _PollsPanel(meetingId: meetingId),
    MeetingTool.notes => _NotesPanel(meetingId: meetingId),
    MeetingTool.decisions => _DecisionsPanel(meetingId: meetingId),
    MeetingTool.actionItems => _ActionItemsPanel(meetingId: meetingId),
  };
}

/// The meeting tools outside a call ("Meeting records" on the meeting
/// details): the same tabs and panels on the room's dark surface. Back
/// returns to the details.
class ApiMeetingToolsScreen extends StatefulWidget {
  const new({
    required this.meetingId,
    required this.title,
    required this.tools,
    this.initial,
    super.key,
  });

  final int meetingId;
  final String title;
  final List<MeetingTool> tools;
  final MeetingTool? initial;

  @override
  State<ApiMeetingToolsScreen> createState() => _ApiMeetingToolsScreenState();
}

class _ApiMeetingToolsScreenState extends State<ApiMeetingToolsScreen> {
  late MeetingTool _tool = widget.initial ?? widget.tools.first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: RoomColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const BackButtonIcon(),
                    color: AppColors.white,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.meetingRecords,
                          style: _t(16, AppColors.white, FontWeight.w700),
                        ),
                        ContentText(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(11, RoomColors.sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            MeetingToolTabs(
              tools: widget.tools,
              selected: _tool,
              onSelect: (t) => setState(() => _tool = t ?? _tool),
            ),
            Expanded(
              child: MeetingToolPanel(meetingId: widget.meetingId, tool: _tool),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared panel pieces

/// Loading / error / empty / rows on the dark panel. A 403 is the
/// participants-only rule (live: "You must be a participant of this
/// meeting …"), said as such rather than as a missing permission.
class _RoomAsync<T> extends StatelessWidget {
  const new({
    required this.value,
    required this.onRetry,
    required this.isEmpty,
    required this.empty,
    required this.builder,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final bool Function(T) isEmpty;
  final String empty;
  final Widget Function(T) builder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Center(
        key: Key('meeting-tool-loading'),
        child: CircularProgressIndicator(color: RoomColors.blue),
      ),
      error: (e, _) {
        final participantsOnly =
            e is ApiException && e.kind == ApiFailureKind.forbidden;
        return _Notice(
          key: Key(
            participantsOnly ? 'meeting-tool-forbidden' : 'meeting-tool-error',
          ),
          text: participantsOnly
              ? l10n.meetingToolsParticipantsOnly
              : localizedError(l10n, e),
          action: participantsOnly
              ? null
              : TextButton(
                  key: const Key('meeting-tool-retry'),
                  onPressed: onRetry,
                  child: Text(l10n.retry),
                ),
        );
      },
      data: (d) => isEmpty(d)
          ? _Notice(key: const Key('meeting-tool-empty'), text: empty)
          : builder(d),
    );
  }
}

class _Notice extends StatelessWidget {
  const new({required this.text, this.action, super.key});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: _t(13, RoomColors.text),
          ),
          if (action case final a?) ...[const SizedBox(height: 12), a],
        ],
      ),
    ),
  );
}

/// The panel card of the notes frame: title row with a refresh action.
class _PanelCard extends StatelessWidget {
  const new({
    required this.title,
    required this.onRefresh,
    required this.child,
    this.footer,
    this.filters,
  });

  final String title;
  final VoidCallback onRefresh;
  final Widget child;
  final Widget? footer;
  final Widget? filters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: BoxDecoration(
        color: RoomColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: _t(13, AppColors.white, FontWeight.w700),
                  ),
                ),
                IconButton(
                  key: const Key('meeting-tool-refresh'),
                  tooltip: l10n.refreshList,
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, color: RoomColors.sub),
                ),
              ],
            ),
          ),
          ?filters,
          const Divider(height: 1, color: Color(0x1AFFFFFF)),
          Expanded(child: child),
          if (footer case final f?) ...[
            const Divider(height: 1, color: Color(0x1AFFFFFF)),
            f,
          ],
        ],
      ),
    );
  }
}

/// "View only" line under the panels a client cannot change (notes,
/// decisions, action items: their writes answer 403 for clients).
class _ReadOnlyFooter extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('meeting-tool-read-only'),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: Text(
      AppLocalizations.of(context).meetingToolsReadOnly,
      style: _t(11, RoomColors.sub),
    ),
  );
}

/// One record on a panel: title, optional body and badges.
class _RecordTile extends StatelessWidget {
  const new({
    required this.title,
    this.body,
    this.badges = const [],
    this.meta,
    super.key,
  });

  final String title;
  final String? body;
  final List<Widget> badges;
  final String? meta;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: RoomColors.input,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContentText(title, style: _t(14, AppColors.white, FontWeight.w600)),
        if (body case final b?) ...[
          const SizedBox(height: 4),
          ContentText(b, style: _t(13, RoomColors.text, FontWeight.w400)),
        ],
        if (badges.isNotEmpty || meta != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...badges,
              if (meta case final m?) Text(m, style: _t(11, RoomColors.sub)),
            ],
          ),
        ],
      ],
    ),
  );
}

/// Status filter chips (documented `status` query values).
class _FilterRow<T> extends StatelessWidget {
  const new({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget chip(String label, VoidCallback tap, Key key, {required bool on}) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: Material(
            color: on ? RoomColors.blue : RoomColors.chip,
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(99),
              onTap: tap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  label,
                  style: _t(11, on ? AppColors.white : const Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ),
        );
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        children: [
          chip(
            l10n.filterAll,
            () => onSelect(null),
            const Key('meeting-tool-filter-all'),
            on: selected == null,
          ),
          for (final v in values)
            chip(
              labelOf(v),
              () => onSelect(v),
              Key('meeting-tool-filter-$v'),
              on: selected == v,
            ),
        ],
      ),
    );
  }
}

String _day(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(d);

// ---------------------------------------------------------------------------
// Chat

class _ChatPanel extends ConsumerStatefulWidget {
  const new({required this.meetingId});

  final int meetingId;

  @override
  ConsumerState<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<_ChatPanel> {
  bool _older = false;
  final _opening = <int>{};
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// After a send: the new message is the last one.
  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });

  Future<void> _loadEarlier() async {
    setState(() => _older = true);
    try {
      await ref
          .read(meetingChatProvider(widget.meetingId).notifier)
          .loadEarlier();
    } on Object catch (e) {
      if (mounted) _say(localizedError(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _older = false);
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(meetingChatProvider(widget.meetingId).notifier).refresh();
    } on Object catch (e) {
      if (mounted) _say(localizedError(AppLocalizations.of(context), e));
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// `GET …/meeting-attachments/{id}/download`, then the shared preview
  /// with "Save to device". One download per attachment at a time.
  Future<void> _open(int attachmentId) async {
    if (_opening.contains(attachmentId)) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _opening.add(attachmentId));
    try {
      final file = await ref
          .read(meetingCollaborationRepositoryProvider)
          .downloadAttachment(attachmentId);
      if (!mounted) return;
      // Downloaded: the chip is no longer busy while the preview is open.
      setState(() => _opening.remove(attachmentId));
      await showAttachmentPreview(
        context,
        file,
        save: ref.read(attachmentSaverProvider),
      );
    } on Object catch (e) {
      if (mounted) {
        _say(l10n.attachmentDownloadFailed(localizedError(l10n, e)));
      }
    } finally {
      if (mounted) setState(() => _opening.remove(attachmentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(meetingChatProvider(widget.meetingId));
    final allowFiles =
        ref.watch(apiMeetingProvider(widget.meetingId)).value?.allowFileShare ??
        false;
    return _PanelCard(
      title: l10n.featureChat,
      onRefresh: _refresh,
      // Only once the chat could be read: a non-participant (403) gets
      // the notice, not a send bar the server would refuse.
      footer: value.hasValue
          ? _ChatComposer(
              meetingId: widget.meetingId,
              allowFiles: allowFiles,
              onSent: _toEnd,
            )
          : null,
      child: _RoomAsync<MeetingMessagePage>(
        value: value,
        onRetry: () => ref.invalidate(meetingChatProvider(widget.meetingId)),
        isEmpty: (p) => p.items.isEmpty,
        empty: l10n.noMeetingMessages,
        builder: (p) => ListView(
          key: const Key('meeting-chat-list'),
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          children: [
            if (p.hasOlder)
              Center(
                child: TextButton(
                  key: const Key('meeting-chat-earlier'),
                  onPressed: _older ? null : _loadEarlier,
                  child: Text(l10n.loadEarlierMessages),
                ),
              ),
            for (final m in p.items)
              Container(
                key: Key('meeting-message-${m.id}'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RoomColors.input,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.text case final t?)
                      ContentText(
                        t,
                        style: _t(13, RoomColors.text, FontWeight.w400),
                      ),
                    for (final a in m.attachmentIds) ...[
                      const SizedBox(height: 8),
                      AttachmentChip(
                        key: Key('meeting-attachment-$a'),
                        label: l10n.attachment,
                        busy: _opening.contains(a),
                        onOpen: () => _open(a),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Picks one file for a meeting message; `null` when the person cancels.
typedef MeetingFilePicker = Future<OutgoingFile?> Function();

/// The platform picker, limited to the route's file types. Tests replace
/// it; `null` hides the attach button.
final meetingFilePickerProvider = Provider<MeetingFilePicker?>(
  (_) =>
      () => pickOneFile(
        extensions: MeetingFileRules.extensions,
        maxBytes: MeetingFileRules.maxBytes,
      ),
);

String _meetingFileProblem(AppLocalizations l10n, AttachmentProblem p) =>
    switch (p) {
      AttachmentProblem.tooLarge => l10n.meetingFileTooLarge,
      AttachmentProblem.typeNotAllowed => l10n.meetingFileTypeNotAllowed,
      _ => attachmentProblemText(l10n, p),
    };

/// A refused send or vote: 403 is the participants-only rule; anything
/// else is the shared localized error (a 422 shows the server's field
/// message when it is safe to show).
String _writeError(AppLocalizations l10n, Object e) =>
    e is ApiException && e.kind == ApiFailureKind.forbidden
    ? l10n.meetingSendParticipantsOnly
    : localizedError(l10n, e);

/// The send bar of the chat frame (670:2505): attach, text, send. Text is
/// at most 5000 characters; a file is checked before anything is uploaded.
/// The bar is busy while a message is on the way, so it cannot be sent
/// twice; text and file stay after a failure so Retry sends them again.
class _ChatComposer extends ConsumerStatefulWidget {
  const new({
    required this.meetingId,
    required this.allowFiles,
    required this.onSent,
  });

  final int meetingId;
  final bool allowFiles;
  final VoidCallback onSent;

  @override
  ConsumerState<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<_ChatComposer> {
  final _text = TextEditingController();
  OutgoingFile? _file;
  String? _fileError;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canSend => _text.text.trim().isNotEmpty || _file != null;

  Future<void> _attach() async {
    final pick = ref.read(meetingFilePickerProvider);
    if (pick == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      final f = await pick();
      if (!mounted || f == null) return;
      final problem = checkMeetingFile(f);
      setState(() {
        _file = problem == null ? f : _file;
        _fileError = problem == null
            ? null
            : _meetingFileProblem(l10n, problem);
      });
    } on AttachmentRejected catch (e) {
      if (mounted) {
        setState(() => _fileError = _meetingFileProblem(l10n, e.problem));
      }
    } on Object {
      if (mounted) setState(() => _fileError = l10n.attachmentsPending);
    }
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final file = _file;
    setState(() => _progress = file == null ? null : 0);
    final sent = await ref
        .read(meetingMessageSenderProvider(widget.meetingId).notifier)
        .send(
          text: _text.text,
          file: file,
          onProgress: file == null
              ? null
              : (p) {
                  if (mounted) setState(() => _progress = p);
                },
        );
    if (!mounted) return;
    setState(() {
      _progress = null;
      if (sent) {
        _text.clear();
        _file = null;
        _fileError = null;
      }
    });
    if (sent) widget.onSent();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(meetingMessageSenderProvider(widget.meetingId));
    final busy = state.isLoading;
    final error = state.hasError && !busy ? state.error : null;
    final file = _file;
    return Padding(
      key: const Key('meeting-chat-composer'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (file != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                key: const Key('meeting-chat-file'),
                children: [
                  const Icon(
                    Icons.insert_drive_file_outlined,
                    size: 18,
                    color: RoomColors.sub,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ContentText(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(12, RoomColors.text),
                    ),
                  ),
                  IconButton(
                    key: const Key('meeting-chat-file-remove'),
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.meetingChatRemoveFile,
                    onPressed: busy ? null : () => setState(() => _file = null),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: RoomColors.sub,
                    ),
                  ),
                ],
              ),
            ),
          if (busy && _progress != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(
                key: const Key('meeting-chat-progress'),
                value: _progress,
                color: RoomColors.blue,
                backgroundColor: RoomColors.chip,
              ),
            ),
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 2, 4, 2),
            decoration: BoxDecoration(
              color: RoomColors.input,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.allowFiles &&
                    ref.watch(meetingFilePickerProvider) != null)
                  IconButton(
                    key: const Key('meeting-chat-attach'),
                    tooltip: l10n.meetingChatAttach,
                    onPressed: busy ? null : _attach,
                    icon: const Icon(Icons.attach_file, color: RoomColors.sub),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('meeting-chat-input'),
                    controller: _text,
                    enabled: !busy,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(meetingMessageMaxLength),
                    ],
                    style: _t(13, RoomColors.text, FontWeight.w400),
                    cursorColor: RoomColors.blue,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: l10n.meetingChatHint,
                      hintStyle: _t(13, RoomColors.sub, FontWeight.w400),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Material(
                    color: _canSend && !busy
                        ? RoomColors.blue
                        : RoomColors.chip,
                    shape: const CircleBorder(),
                    child: IconButton(
                      key: const Key('meeting-chat-send'),
                      tooltip: busy
                          ? l10n.meetingChatSending
                          : l10n.meetingChatSend,
                      onPressed: _canSend && !busy ? _send : null,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: AppColors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_fileError case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                e,
                key: const Key('meeting-chat-file-error'),
                style: _t(12, RoomColors.mutedFg),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.meetingChatSendFailed(_writeError(l10n, error)),
                      key: const Key('meeting-chat-send-error'),
                      style: _t(12, RoomColors.mutedFg),
                    ),
                  ),
                  if (_canSend)
                    TextButton(
                      key: const Key('meeting-chat-retry'),
                      onPressed: _send,
                      child: Text(l10n.retry),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Polls

class _PollsPanel extends ConsumerWidget {
  const new({required this.meetingId});

  final int meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(meetingPollsProvider(meetingId));
    return _PanelCard(
      title: l10n.polls,
      onRefresh: () => ref.invalidate(meetingPollsProvider(meetingId)),
      child: _RoomAsync<List<MeetingPoll>>(
        value: value,
        onRetry: () => ref.invalidate(meetingPollsProvider(meetingId)),
        isEmpty: (l) => l.isEmpty,
        empty: l10n.noMeetingPolls,
        builder: (polls) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final p in polls)
              _PollTile(
                meetingId: meetingId,
                poll: p,
                key: Key('poll-${p.id}'),
              ),
          ],
        ),
      ),
    );
  }
}

/// A poll: its question; expanding reads `GET meeting-polls/{id}` for the
/// options and offers the vote. No result is shown (not documented).
class _PollTile extends ConsumerStatefulWidget {
  const new({required this.meetingId, required this.poll, super.key});

  final int meetingId;
  final MeetingPoll poll;

  @override
  ConsumerState<_PollTile> createState() => _PollTileState();
}

class _PollTileState extends ConsumerState<_PollTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final question = widget.poll.question ?? l10n.pollUntitled(widget.poll.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: RoomColors.input,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('poll-open-${widget.poll.id}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ContentText(
                      question,
                      style: _t(14, AppColors.white, FontWeight.w600),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: RoomColors.sub,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _PollOptions(
                meetingId: widget.meetingId,
                pollId: widget.poll.id,
              ),
            ),
        ],
      ),
    );
  }
}

/// The poll's options as choices, with Vote (`POST meeting-polls/{id}/vote`,
/// one option id: whether a poll takes several is not on the read model).
/// Vote is off until an option is chosen and while a vote is on the way;
/// after a 200 it shows the documented `total_votes` and stays off until
/// another option is chosen. Per-option results are not documented.
class _PollOptions extends ConsumerStatefulWidget {
  const new({required this.meetingId, required this.pollId});

  final int meetingId;
  final int pollId;

  @override
  ConsumerState<_PollOptions> createState() => _PollOptionsState();
}

class _PollOptionsState extends ConsumerState<_PollOptions> {
  int? _choice;
  int? _votedFor;

  Future<void> _vote() async {
    final choice = _choice;
    if (choice == null) return;
    final ok = await ref
        .read(pollVoterProvider(widget.pollId).notifier)
        .vote(meetingId: widget.meetingId, optionIds: [choice]);
    if (ok && mounted) setState(() => _votedFor = choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pollId = widget.pollId;
    final value = ref.watch(meetingPollProvider(pollId));
    final voter = ref.watch(pollVoterProvider(pollId));
    final busy = voter.isLoading;
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator(color: RoomColors.blue)),
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e is ApiException && e.kind == ApiFailureKind.forbidden
                ? l10n.meetingToolsParticipantsOnly
                : localizedError(l10n, e),
            style: _t(12, RoomColors.text),
          ),
          TextButton(
            key: Key('poll-retry-$pollId'),
            onPressed: () => ref.invalidate(meetingPollProvider(pollId)),
            child: Text(l10n.retry),
          ),
        ],
      ),
      data: (d) {
        final canVote = !busy && _choice != null && _choice != _votedFor;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.pollChooseOption, style: _t(11, RoomColors.sub)),
            const SizedBox(height: 6),
            for (final o in d.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Semantics(
                  selected: _choice == o.id,
                  inMutuallyExclusiveGroup: true,
                  button: true,
                  child: Material(
                    color: _choice == o.id
                        ? const Color(0x330066FF)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: _choice == o.id
                            ? RoomColors.blue
                            : const Color(0x33FFFFFF),
                      ),
                    ),
                    child: InkWell(
                      key: Key('poll-option-${o.id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: busy ? null : () => setState(() => _choice = o.id),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          10,
                          8,
                          12,
                          8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _choice == o.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: _choice == o.id
                                  ? RoomColors.blue
                                  : RoomColors.sub,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ContentText(
                                o.title,
                                style: _t(13, RoomColors.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                key: Key('poll-vote-$pollId'),
                style: FilledButton.styleFrom(
                  backgroundColor: RoomColors.blue,
                  disabledBackgroundColor: RoomColors.chip,
                  foregroundColor: AppColors.white,
                  disabledForegroundColor: RoomColors.sub,
                ),
                onPressed: canVote ? _vote : null,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.how_to_vote_outlined, size: 18),
                label: Text(l10n.pollVote),
              ),
            ),
            if (voter case AsyncData(value: final r?))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.pollVoteRecorded(r.totalVotes),
                  key: Key('poll-voted-$pollId'),
                  style: _t(12, RoomColors.live),
                ),
              ),
            if (voter.hasError && !busy)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.pollVoteFailed(_writeError(l10n, voter.error!)),
                  key: Key('poll-vote-error-$pollId'),
                  style: _t(12, RoomColors.mutedFg),
                ),
              ),
            const SizedBox(height: 6),
            Text(l10n.pollResultsNotShown, style: _t(11, RoomColors.sub)),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Notes, decisions, action items

class _NotesPanel extends ConsumerWidget {
  const new({required this.meetingId});

  final int meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(meetingNotesProvider(meetingId));
    return _PanelCard(
      title: l10n.notes,
      onRefresh: () => ref.invalidate(meetingNotesProvider(meetingId)),
      footer: const _ReadOnlyFooter(),
      child: _RoomAsync<List<MeetingNote>>(
        value: value,
        onRetry: () => ref.invalidate(meetingNotesProvider(meetingId)),
        isEmpty: (l) => l.isEmpty,
        empty: l10n.noMeetingNotes,
        builder: (notes) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final n in notes)
              _RecordTile(
                key: Key('note-${n.id}'),
                title: n.title ?? n.content,
                body: n.title == null ? null : n.content,
                badges: [
                  if (n.status == NoteStatus.draft)
                    StatusBadge(
                      label: l10n.statusDraft,
                      tone: BadgeTone.neutral,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String decisionStatusLabel(AppLocalizations l10n, DecisionStatus s) =>
    switch (s) {
      DecisionStatus.pending => l10n.statusPending,
      DecisionStatus.approved => l10n.approved,
      DecisionStatus.rejected => l10n.rejected,
    };

BadgeTone _decisionTone(DecisionStatus s) => switch (s) {
  DecisionStatus.pending => BadgeTone.warning,
  DecisionStatus.approved => BadgeTone.success,
  DecisionStatus.rejected => BadgeTone.danger,
};

class _DecisionsPanel extends ConsumerStatefulWidget {
  const new({required this.meetingId});

  final int meetingId;

  @override
  ConsumerState<_DecisionsPanel> createState() => _DecisionsPanelState();
}

class _DecisionsPanelState extends ConsumerState<_DecisionsPanel> {
  DecisionStatus? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = (meetingId: widget.meetingId, status: _status);
    final value = ref.watch(meetingDecisionsProvider(q));
    return _PanelCard(
      title: l10n.meetingDecisions,
      onRefresh: () => ref.invalidate(meetingDecisionsProvider(q)),
      footer: const _ReadOnlyFooter(),
      filters: _FilterRow<DecisionStatus>(
        values: DecisionStatus.values,
        selected: _status,
        labelOf: (s) => decisionStatusLabel(l10n, s),
        onSelect: (s) => setState(() => _status = s),
      ),
      child: _RoomAsync<List<MeetingDecision>>(
        value: value,
        onRetry: () => ref.invalidate(meetingDecisionsProvider(q)),
        isEmpty: (l) => l.isEmpty,
        empty: l10n.noMeetingDecisions,
        builder: (rows) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final d in rows)
              _RecordTile(
                key: Key('decision-${d.id}'),
                title: d.title,
                body: d.description,
                badges: [
                  if (d.status case final s?)
                    StatusBadge(
                      label: decisionStatusLabel(l10n, s),
                      tone: _decisionTone(s),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String actionItemStatusLabel(AppLocalizations l10n, ActionItemStatus s) =>
    switch (s) {
      ActionItemStatus.pending => l10n.statusPending,
      ActionItemStatus.inProgress => l10n.statusInProgress,
      ActionItemStatus.completed => l10n.statusCompleted,
      ActionItemStatus.cancelled => l10n.meetingCancelled,
    };

BadgeTone _actionTone(ActionItemStatus s) => switch (s) {
  ActionItemStatus.pending => BadgeTone.warning,
  ActionItemStatus.inProgress => BadgeTone.info,
  ActionItemStatus.completed => BadgeTone.success,
  ActionItemStatus.cancelled => BadgeTone.neutral,
};

String _priorityLabel(AppLocalizations l10n, ActionItemPriority p) =>
    switch (p) {
      ActionItemPriority.low => l10n.priorityLow,
      ActionItemPriority.medium => l10n.priorityMedium,
      ActionItemPriority.high => l10n.priorityHigh,
      ActionItemPriority.urgent => l10n.priorityUrgent,
    };

class _ActionItemsPanel extends ConsumerStatefulWidget {
  const new({required this.meetingId});

  final int meetingId;

  @override
  ConsumerState<_ActionItemsPanel> createState() => _ActionItemsPanelState();
}

class _ActionItemsPanelState extends ConsumerState<_ActionItemsPanel> {
  ActionItemStatus? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = (meetingId: widget.meetingId, status: _status);
    final value = ref.watch(meetingActionItemsProvider(q));
    return _PanelCard(
      title: l10n.meetingActionItems,
      onRefresh: () => ref.invalidate(meetingActionItemsProvider(q)),
      footer: const _ReadOnlyFooter(),
      filters: _FilterRow<ActionItemStatus>(
        values: ActionItemStatus.values,
        selected: _status,
        labelOf: (s) => actionItemStatusLabel(l10n, s),
        onSelect: (s) => setState(() => _status = s),
      ),
      child: _RoomAsync<List<MeetingActionItem>>(
        value: value,
        onRetry: () => ref.invalidate(meetingActionItemsProvider(q)),
        isEmpty: (l) => l.isEmpty,
        empty: l10n.noMeetingActionItems,
        builder: (rows) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final a in rows)
              _RecordTile(
                key: Key('action-item-${a.id}'),
                title: a.title,
                body: a.description,
                badges: [
                  if (a.status case final s?)
                    StatusBadge(
                      label: actionItemStatusLabel(l10n, s),
                      tone: _actionTone(s),
                    ),
                  if (a.priority case final p?)
                    StatusBadge(
                      label: '${l10n.priority}: ${_priorityLabel(l10n, p)}',
                      tone:
                          p == ActionItemPriority.urgent ||
                              p == ActionItemPriority.high
                          ? BadgeTone.danger
                          : BadgeTone.neutral,
                    ),
                ],
                meta: a.dueDate == null
                    ? null
                    : '${l10n.dueDate}: ${_day(context, a.dueDate!)}',
              ),
          ],
        ),
      ),
    );
  }
}
