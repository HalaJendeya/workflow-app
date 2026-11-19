import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/content_text.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/conversations/presentation/chat_attachment_widgets.dart';
import 'package:workflow_app/features/meetings/data/meeting_collaboration_repository.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_room_screen.dart'
    show RoomColors;
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// The meeting tools of the in-call frames (chat 670:2505, polls 671:3024,
/// notes 672:5044 — "Meeting Tool Navigation Tabs"), read-only. Decisions
/// and action items have no frame; they reuse the notes panel's layout.
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

/// "View only" line under panels whose frame shows sending or voting.
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
    return _PanelCard(
      title: l10n.featureChat,
      onRefresh: _refresh,
      footer: const _ReadOnlyFooter(),
      child: _RoomAsync<MeetingMessagePage>(
        value: value,
        onRetry: () => ref.invalidate(meetingChatProvider(widget.meetingId)),
        isEmpty: (p) => p.items.isEmpty,
        empty: l10n.noMeetingMessages,
        builder: (p) => ListView(
          key: const Key('meeting-chat-list'),
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
      footer: const _ReadOnlyFooter(),
      child: _RoomAsync<List<MeetingPoll>>(
        value: value,
        onRetry: () => ref.invalidate(meetingPollsProvider(meetingId)),
        isEmpty: (l) => l.isEmpty,
        empty: l10n.noMeetingPolls,
        builder: (polls) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final p in polls) _PollTile(poll: p, key: Key('poll-${p.id}')),
          ],
        ),
      ),
    );
  }
}

/// A poll: its question; expanding reads `GET meeting-polls/{id}` for the
/// options. No vote is sent and no result is shown (not documented).
class _PollTile extends ConsumerStatefulWidget {
  const new({required this.poll, super.key});

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
              child: _PollOptions(pollId: widget.poll.id),
            ),
        ],
      ),
    );
  }
}

class _PollOptions extends ConsumerWidget {
  const new({required this.pollId});

  final int pollId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(meetingPollProvider(pollId));
    return value.when(
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
      data: (d) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.pollOptionsTitle, style: _t(11, RoomColors.sub)),
          const SizedBox(height: 6),
          for (final o in d.options)
            Container(
              key: Key('poll-option-${o.id}'),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: ContentText(o.title, style: _t(13, RoomColors.text)),
            ),
          Text(l10n.pollResultsNotShown, style: _t(11, RoomColors.sub)),
        ],
      ),
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
