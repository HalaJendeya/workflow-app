import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/meetings/data/meetings_repository.dart';
import 'package:workflow_app/features/meetings/domain/meeting.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_details_screen.dart';
import 'package:workflow_app/features/meetings/presentation/meetings_screen.dart';
import 'package:workflow_app/features/work/presentation/work_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// How a server meeting is labelled with the Figma status badges.
MeetingStatus displayStatus(ApiMeeting m, DateTime now) => switch (m.status) {
  ApiMeetingStatus.live => MeetingStatus.live,
  ApiMeetingStatus.ended => MeetingStatus.ended,
  ApiMeetingStatus.cancelled => MeetingStatus.cancelled,
  _ when m.isOverdue(now) => MeetingStatus.overdue,
  _ when m.type == ApiMeetingType.scheduled => MeetingStatus.scheduled,
  _ => MeetingStatus.waiting,
};

String apiMeetingFilterLabel(AppLocalizations l10n, ApiMeetingStatus s) =>
    switch (s) {
      ApiMeetingStatus.waiting => l10n.meetingWaiting,
      ApiMeetingStatus.live => l10n.meetingLive,
      ApiMeetingStatus.ended => l10n.meetingEnded,
      ApiMeetingStatus.cancelled => l10n.meetingCancelled,
      ApiMeetingStatus.other => '—',
    };

String invitationStatusLabel(AppLocalizations l10n, String s) => switch (s) {
  'pending' => l10n.statusPending,
  'accepted' => l10n.invitationStatusAccepted,
  'declined' => l10n.invitationStatusDeclined,
  'expired' => l10n.invitationStatusExpired,
  _ => s,
};

BadgeTone invitationTone(String s) => switch (s) {
  'pending' => BadgeTone.warning,
  'accepted' => BadgeTone.success,
  'declined' => BadgeTone.danger,
  _ => BadgeTone.neutral,
};

String secondsLabel(AppLocalizations l10n, int? seconds) {
  if (seconds == null) return '—';
  return l10n.durationSeconds(
    seconds ~/ 3600,
    seconds % 3600 ~/ 60,
    seconds % 60,
  );
}

enum _Tab { scheduled, live, overdue }

/// "Meetings Management" (643:38772) backed by
/// `GET /api/v1/{client|employee}/meetings`.
class ApiMeetingsView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ApiMeetingsView> createState() => _ApiMeetingsViewState();
}

class _ApiMeetingsViewState extends ConsumerState<ApiMeetingsView> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _day = DateTime.now();
  _Tab _tab = _Tab.scheduled;
  String _search = '';
  ApiMeetingStatus? _status;
  int _page = 1;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _search = v;
          _page = 1;
        });
      }
    });
  }

  Future<void> _open(ApiMeeting m) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ApiMeetingDetailsScreen(id: m.id)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final h16 = AppTextStyles.mobileLgSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    final counts = ref.watch(apiMeetingCountsProvider);
    final calendar = ref.watch(apiMeetingCalendarProvider);
    final query = (search: _search, status: _status, page: _page);
    final list = ref.watch(apiMeetingsProvider(query));
    String n(int Function(MeetingCounts) pick) =>
        counts.value == null ? '—' : count(pick(counts.value!));

    return ModulePage(
      title: l10n.meetingsTitle,
      description: l10n.meetingsDescription,
      onSearch: _onSearch,
      onCreate: () => showSnack(context, l10n.meetingCreateUnavailable),
      createLabel: l10n.scheduleMeeting,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilterChipBox(
            label: l10n.joinByCode,
            selected: true,
            onTap: () => showSnack(context, l10n.meetingJoinUnavailable),
          ),
        ),
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.meetingOverview, style: h16),
              const SizedBox(height: 16),
              if (counts case AsyncError(:final error))
                ApiErrorCard(
                  error: error,
                  // The counts are derived from the calendar page, whose
                  // error stays cached: retrying the counts alone failed
                  // again every time.
                  onRetry: () => ref
                    ..invalidate(apiMeetingCalendarProvider)
                    ..invalidate(apiMeetingCountsProvider),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: MeetingKpi(l10n.totalMeetings, n((c) => c.total)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MeetingKpi(
                        l10n.liveNow,
                        counts.value == null
                            ? '—'
                            : l10n.activeCount(counts.value!.live),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: MeetingKpi(
                        l10n.meetingWaiting,
                        n((c) => c.waiting),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MeetingKpi(l10n.meetingEnded, n((c) => c.ended)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const _MyInvitationsCard(),
        Text(l10n.meetingsCalendar, style: h16),
        AsyncSection(
          value: calendar,
          onRetry: () => ref.invalidate(apiMeetingCalendarProvider),
          builder: (page) {
            final all = page.items;
            final day = all.where((m) => isSameDay(m.anchor, _day)).where((m) {
              final s = displayStatus(m, now);
              return switch (_tab) {
                _Tab.scheduled =>
                  s == MeetingStatus.scheduled ||
                      s == MeetingStatus.waiting ||
                      s == MeetingStatus.live,
                _Tab.live => s == MeetingStatus.live,
                _Tab.overdue => s == MeetingStatus.overdue,
              };
            }).toList()..sort((a, b) => a.anchor.compareTo(b.anchor));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ModuleCard(
                  child: MeetingMonthCalendar(
                    month: _month,
                    selected: _day,
                    marked: {
                      for (final m in all)
                        if (m.anchor.year == _month.year &&
                            m.anchor.month == _month.month)
                          m.anchor.day,
                    },
                    onMonth: (d) => setState(() => _month = d),
                    onDay: (d) => setState(() => _day = d),
                  ),
                ),
                if (page.total > all.length) ...[
                  const SizedBox(height: 8),
                  Text(l10n.calendarShowsLatest(all.length), style: secondary),
                ],
                const SizedBox(height: 20),
                ChipRow(
                  children: [
                    for (final t in _Tab.values)
                      FilterChipBox(
                        label: switch (t) {
                          _Tab.scheduled => l10n.meetingScheduled,
                          _Tab.live => l10n.meetingLive,
                          _Tab.overdue => l10n.statusOverdue,
                        },
                        selected: _tab == t,
                        onTap: () => setState(() => _tab = t),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(l10n.timezoneLabel(utcOffsetLabel()), style: secondary),
                const SizedBox(height: 20),
                Text(
                  isSameDay(_day, now)
                      ? l10n.todaysMeetings
                      : DateFormat.yMMMMd('en').format(_day),
                  style: h16,
                ),
                const SizedBox(height: 20),
                if (day.isEmpty) EmptyNotice(text: l10n.noMeetingsThisDay),
                for (final m in day) ...[
                  _DayCard(meeting: m, now: now, onOpen: () => _open(m)),
                  const SizedBox(height: 20),
                ],
              ],
            );
          },
        ),
        Text(l10n.upcomingMeetings, style: h16),
        WfSearchBox(
          fieldKey: const Key('meetings-search'),
          hint: l10n.searchMeetingsHint,
          onChanged: _onSearch,
        ),
        ChipRow(
          children: [
            DropdownChip<ApiMeetingStatus?>(
              value: _status,
              options: const [
                null,
                ApiMeetingStatus.waiting,
                ApiMeetingStatus.live,
                ApiMeetingStatus.ended,
                ApiMeetingStatus.cancelled,
              ],
              labelOf: (s) => s == null
                  ? l10n.filterAllStatus
                  : apiMeetingFilterLabel(l10n, s),
              onChanged: (s) => setState(() {
                _status = s;
                _page = 1;
              }),
            ),
          ],
        ),
        AsyncSection(
          value: list,
          onRetry: () => ref.invalidate(apiMeetingsProvider(query)),
          builder: (page) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (page.items.isEmpty)
                EmptyNotice(
                  text: _search.trim().isEmpty && _status == null
                      ? l10n.noMeetingsYet
                      : l10n.noRecords,
                ),
              for (final m in page.items) ...[
                _MeetingRecord(meeting: m, now: now, onOpen: () => _open(m)),
                const SizedBox(height: 16),
              ],
              if (page.lastPage > 1)
                Pager(
                  page: page.currentPage - 1,
                  pageSize: page.perPage,
                  total: page.total,
                  onPage: (p) => setState(() => _page = p + 1),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _when(ApiMeeting m) {
  final t = hm(m.anchor);
  final end = m.endedAt;
  return end == null ? t : '$t – ${hm(end)}';
}

class _DayCard extends StatelessWidget {
  const new({required this.meeting, required this.now, required this.onOpen});

  final ApiMeeting meeting;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = meeting;
    final s = displayStatus(m, now);
    return ModuleCard(
      key: Key('today-${m.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            m.title,
            style: AppTextStyles.mobileLgSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [?m.projectTitle, _when(m)].join('\n'),
            style: AppTextStyles.mobileXsRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusBadge(
              label: meetingStatusLabel(l10n, s),
              tone: meetingTone(s),
              radius: 6,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
                textStyle: AppTextStyles.mobileBaseSemiBold,
              ),
              child: Text(l10n.viewDetails),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingRecord extends StatelessWidget {
  const new({required this.meeting, required this.now, required this.onOpen});

  final ApiMeeting meeting;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = meeting;
    final s = displayStatus(m, now);
    final type = switch (m.type) {
      ApiMeetingType.instant => l10n.meetingTypeInstant,
      ApiMeetingType.scheduled => l10n.meetingScheduled,
      ApiMeetingType.other => '—',
    };
    return RecordCard(
      key: Key('meeting-${m.id}'),
      reference: m.title,
      title: m.description?.trim().isNotEmpty ?? false ? m.description! : '—',
      status: meetingStatusLabel(l10n, s),
      tone: meetingTone(s),
      subtitle: m.projectTitle,
      fields: [
        DetailField(
          m.scheduledAt != null ? l10n.meetingScheduled : l10n.startedAt,
          DateFormat('yyyy-MM-dd · HH:mm', 'en').format(m.anchor),
        ),
        DetailField(
          l10n.codeTypeParticipants,
          '${m.code} · $type · ${m.peakParticipants ?? '—'}',
        ),
      ],
      onView: onOpen,
    );
  }
}

/// The caller's own pending invitations, answered with
/// `PUT …/meeting-invitations/{id}`.
class _MyInvitationsCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(apiMyInvitationsProvider);
    final pending = value.value?.items.where((i) => i.isPending).toList();
    if (value is AsyncData && (pending?.isEmpty ?? true)) {
      return const SizedBox.shrink();
    }
    return ModuleCard(
      key: const Key('my-invitations'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.myInvitations,
            style: AppTextStyles.mobileLgSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          AsyncSection(
            value: value,
            onRetry: () => ref.invalidate(apiMyInvitationsProvider),
            builder: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final i in pending!)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _InvitationTile(
                      invitationId: i.id,
                      title: i.meetingTitle ?? '#${i.meetingId ?? i.id}',
                      subtitle: i.inviterName == null
                          ? null
                          : l10n.invitedBy(i.inviterName!),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Accept / decline buttons for one invitation. Refreshes the invitation
/// lists and the meeting on success; errors are shown as they are.
class _InvitationTile extends ConsumerStatefulWidget {
  const new({
    required this.invitationId,
    required this.title,
    this.subtitle,
    this.meetingId,
  });

  final int invitationId;
  final String title;
  final String? subtitle;
  final int? meetingId;

  @override
  ConsumerState<_InvitationTile> createState() => _InvitationTileState();
}

class _InvitationTileState extends ConsumerState<_InvitationTile> {
  bool _busy = false;

  Future<void> _respond({required bool accept}) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(meetingsRepositoryProvider)
          .respond(widget.invitationId, accept: accept);
      if (!mounted) return;
      showSnack(
        context,
        accept ? l10n.invitationAccepted : l10n.invitationDeclined,
      );
      ref.invalidate(apiMyInvitationsProvider);
      if (widget.meetingId case final id?) {
        ref.invalidate(apiMeetingProvider(id));
      }
    } on Object catch (e) {
      if (mounted) showSnack(context, localizedError(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: AppTextStyles.mobileBaseSemiBold.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            style: AppTextStyles.mobileXsRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: FilledButton(
                  key: Key('accept-invitation-${widget.invitationId}'),
                  onPressed: _busy ? null : () => _respond(accept: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                    textStyle: AppTextStyles.mobileXsSemiBold,
                  ),
                  child: Text(l10n.acceptInvitation),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton(
                  key: Key('decline-invitation-${widget.invitationId}'),
                  onPressed: _busy ? null : () => _respond(accept: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                    textStyle: AppTextStyles.mobileXsSemiBold,
                  ),
                  child: Text(l10n.declineInvitation),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Meeting details (643:37740) from `GET …/meetings/{id}` and
/// `GET …/meetings/{id}/participants`; the employee also sees the
/// meeting's invitations.
class ApiMeetingDetailsScreen extends ConsumerWidget {
  const new({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final meeting = ref.watch(apiMeetingProvider(id));
    final isEmployee =
        ref.watch(meetingsRepositoryProvider).portal == Portal.employee;
    final h16 = AppTextStyles.mobileLgSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    final fmt = DateFormat('M/d/y, h:mm:ss a', 'en');
    String at(DateTime? t) => t == null ? '—' : fmt.format(t);
    Widget field(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: secondary),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.mobileBaseSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    return ModulePage(
      title: l10n.meetingsTitle,
      description: l10n.meetingsDescription,
      children: [
        AsyncSection(
          value: meeting,
          onRetry: () => ref.invalidate(apiMeetingProvider(id)),
          builder: (m) {
            final s = displayStatus(m, DateTime.now());
            final features = {
              if (m.allowChat) MeetingFeature.chat,
              if (m.allowScreenShare) MeetingFeature.screen,
              if (m.allowWhiteboard) MeetingFeature.whiteboard,
              if (m.allowFileShare) MeetingFeature.files,
            };
            final inv = m.myInvitation;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ModuleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.title, style: h16),
                      const SizedBox(height: 4),
                      Text(l10n.detailsBody, style: secondary),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusBadge(
                            label: '${l10n.meetingId}: ${m.code}',
                            tone: BadgeTone.info,
                          ),
                          StatusBadge(
                            label: meetingStatusLabel(l10n, s),
                            tone: meetingTone(s),
                          ),
                        ],
                      ),
                      field(l10n.fieldType, switch (m.type) {
                        ApiMeetingType.instant => l10n.meetingTypeInstant,
                        ApiMeetingType.scheduled => l10n.meetingScheduled,
                        ApiMeetingType.other => '—',
                      }),
                      field(l10n.scheduledAt, at(m.scheduledAt)),
                      field(
                        l10n.privacy,
                        m.isPrivate ? l10n.private : l10n.public,
                      ),
                      field(l10n.startedAt, at(m.startedAt)),
                      field(l10n.endedAt, at(m.endedAt)),
                      field(l10n.fieldProject, m.projectTitle ?? '—'),
                      field(l10n.duration, secondsLabel(l10n, m.runSeconds)),
                      field(l10n.createdBy, m.creatorName ?? '—'),
                      field(
                        l10n.peakParticipants,
                        '${m.peakParticipants ?? '—'}',
                      ),
                      field(
                        l10n.maxParticipants,
                        '${m.maxParticipants ?? '—'}',
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.features, style: secondary),
                      const SizedBox(height: 8),
                      ChipRow(
                        children: [
                          for (final f in MeetingFeature.values)
                            FilterChipBox(
                              label: featureLabel(l10n, f),
                              selected: features.contains(f),
                              onTap: () {},
                            ),
                        ],
                      ),
                      field(
                        l10n.description,
                        m.description?.trim().isNotEmpty ?? false
                            ? m.description!
                            : '—',
                      ),
                    ],
                  ),
                ),
                if (inv != null) ...[
                  const SizedBox(height: 20),
                  ModuleCard(
                    key: const Key('your-invitation'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.yourInvitation, style: h16),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: StatusBadge(
                            label: invitationStatusLabel(l10n, inv.status),
                            tone: invitationTone(inv.status),
                          ),
                        ),
                        if (inv.status == 'pending') ...[
                          const SizedBox(height: 4),
                          _InvitationTile(
                            invitationId: inv.id,
                            title: m.title,
                            meetingId: m.id,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        // Join only while the meeting can be joined.
        if (meeting.value case final m?
            when m.status == ApiMeetingStatus.waiting ||
                m.status == ApiMeetingStatus.live)
          _JoinCard(meetingId: id),
        _ParticipantsCard(meetingId: id),
        if (isEmployee) _InvitationsCard(meetingId: id),
      ],
    );
  }
}

/// `POST …/meetings/{id}/join`: on the roster (200) the caller joins and
/// may leave again; in an approval meeting (202) a join request waits for
/// the host. The app has no audio/video, so it says so instead of opening a
/// call.
class _JoinCard extends ConsumerStatefulWidget {
  const new({required this.meetingId});

  final int meetingId;

  @override
  ConsumerState<_JoinCard> createState() => _JoinCardState();
}

class _JoinCardState extends ConsumerState<_JoinCard> {
  JoinOutcome? _outcome;
  bool _busy = false;
  bool _left = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(apiParticipantsProvider(widget.meetingId));
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(context, localizedError(AppLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() => _run(() async {
    final outcome = await ref
        .read(meetingsRepositoryProvider)
        .join(widget.meetingId);
    if (mounted) {
      setState(() {
        _outcome = outcome;
        _left = false;
      });
    }
  });

  Future<void> _leave(int participantId) => _run(() async {
    await ref.read(meetingsRepositoryProvider).leave(participantId);
    if (mounted) {
      setState(() {
        _outcome = null;
        _left = true;
      });
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outcome = _outcome;
    final text = switch (outcome) {
      Joined() => l10n.joinedNoMedia,
      JoinRequested() => l10n.joinRequestPending,
      null => _left ? l10n.leftMeeting : null,
    };
    return ModuleCard(
      key: const Key('meeting-join-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (text != null) ...[
            Text(
              text,
              key: const Key('meeting-join-status'),
              style: AppTextStyles.mobileBaseRegular.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          switch (outcome) {
            Joined(:final participantId) => OutlinedButton(
              key: const Key('meeting-leave'),
              onPressed: _busy ? null : () => _leave(participantId),
              child: Text(l10n.leave),
            ),
            JoinRequested() => const SizedBox.shrink(),
            null => FilledButton(
              key: const Key('meeting-join'),
              onPressed: _busy ? null : _join,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.joinMeeting),
            ),
          },
        ],
      ),
    );
  }
}

class _ParticipantsCard extends ConsumerWidget {
  const new({required this.meetingId});

  final int meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(apiParticipantsProvider(meetingId));
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    final total = value.value?.total;
    return ModuleCard(
      key: const Key('participants'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.participants} (${total ?? '—'})',
            style: AppTextStyles.mobileLgSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          FilterChipBox(
            label: l10n.refreshList,
            selected: true,
            onTap: () => ref.invalidate(apiParticipantsProvider(meetingId)),
          ),
          AsyncSection(
            value: value,
            onRetry: () => ref.invalidate(apiParticipantsProvider(meetingId)),
            builder: (page) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (page.items.isEmpty) ...[
                  const SizedBox(height: 16),
                  EmptyNotice(text: l10n.noRecords),
                ],
                for (var i = 0; i < page.items.length; i++) ...[
                  const SizedBox(height: 16),
                  Text('#${i + 1} · ${l10n.user}', style: secondary),
                  const SizedBox(height: 4),
                  Text(
                    page.items[i].name,
                    style: AppTextStyles.mobileBaseSemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (page.items[i].isHost)
                        StatusBadge(label: l10n.host, tone: BadgeTone.info),
                      StatusBadge(
                        label: page.items[i].isConnected
                            ? l10n.connected
                            : l10n.disconnected,
                        tone: page.items[i].isConnected
                            ? BadgeTone.success
                            : BadgeTone.warning,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationsCard extends ConsumerWidget {
  const new({required this.meetingId});

  final int meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(apiMeetingInvitationsProvider(meetingId));
    final total = value.value?.total ?? 0;
    return ModuleCard(
      key: const Key('meeting-invitations'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.invitationsCount(total),
            style: AppTextStyles.mobileLgSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.invitationsBody,
            style: AppTextStyles.mobileXsRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          AsyncSection(
            value: value,
            onRetry: () =>
                ref.invalidate(apiMeetingInvitationsProvider(meetingId)),
            builder: (page) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (page.items.isEmpty) ...[
                  const SizedBox(height: 24),
                  const Center(child: WfSvg('invite_empty', size: 32)),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noInvitations,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.mobileBaseSemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                for (final i in page.items) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          i.userName ?? '—',
                          style: AppTextStyles.mobileBaseSemiBold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      StatusBadge(
                        label: invitationStatusLabel(l10n, i.status),
                        tone: invitationTone(i.status),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
