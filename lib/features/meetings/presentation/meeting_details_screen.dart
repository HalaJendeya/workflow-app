import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/content_text.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/meetings/domain/meeting.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_forms.dart';
import 'package:workflow_app/features/meetings/presentation/meetings_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

final _at = DateFormat('yyyy/MM/dd HH:mm', 'en');

/// A meeting time as `2026/11/18 14:30` that keeps its order inside Arabic
/// text (left-to-right isolate), or "—".
String meetingTimeLabel(DateTime? t) =>
    t == null ? '—' : '$_lri${_at.format(t)}$_pdi';

final _lri = String.fromCharCode(0x2066);
final _pdi = String.fromCharCode(0x2069);

/// Figma meeting details (643:37740), demo data.
class MeetingDetailsScreen extends ConsumerWidget {
  const new({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final m = ref.watch(meetingsProvider).where((x) => x.id == id).firstOrNull;
    if (m == null) {
      return Scaffold(body: EmptyNotice(text: l10n.noRecords));
    }
    final h16 = AppTextStyles.mobileLgSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    final started =
        m.status == MeetingStatus.live || m.status == MeetingStatus.ended;
    final live = m.status == MeetingStatus.live;

    return ModulePage(
      title: l10n.meetingsTitle,
      description: l10n.meetingsDescription,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilterChipBox(
            label: l10n.joinByCode,
            selected: true,
            onTap: () => openJoinByCode(context, code: m.code),
          ),
        ),
        MeetingFactsCard(
          title: m.title,
          badges: [
            StatusBadge(
              label: '${l10n.meetingId}: ${m.code}',
              tone: BadgeTone.info,
            ),
            StatusBadge(
              label: meetingStatusLabel(l10n, m.status),
              tone: meetingTone(m.status),
            ),
          ],
          timing: [
            DetailField(l10n.scheduledAt, meetingTimeLabel(m.start)),
            DetailField(l10n.duration, l10n.minutes(m.duration.inMinutes)),
            DetailField(
              l10n.startedAt,
              meetingTimeLabel(started ? m.start : null),
            ),
            DetailField(
              l10n.endedAt,
              meetingTimeLabel(m.status == MeetingStatus.ended ? m.end : null),
            ),
          ],
          info: [
            DetailField(l10n.privacy, m.isPublic ? l10n.public : l10n.private),
            DetailField(l10n.fieldProject, m.project ?? '—'),
            DetailField(l10n.createdBy, m.createdBy),
            DetailField(l10n.peakParticipants, '${m.participants.length}'),
            DetailField(l10n.maxParticipants, '${m.maxParticipants}'),
          ],
          features: m.features,
          description: m.description,
        ),
        if (m.invitationOnly)
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(
                  label: l10n.invitationRequired,
                  tone: BadgeTone.info,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.invitationRequiredBody,
                  style: AppTextStyles.mobileBaseRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ModuleCard(
          key: const Key('participants'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MeetingSectionHeader(
                title: '${l10n.participants} (${m.participants.length})',
                subtitle: l10n.peakOf(m.participants.length, m.maxParticipants),
                onRefresh: () => showSnack(context, l10n.listUpToDate),
              ),
              for (final (i, name) in m.participants.indexed)
                MeetingParticipantRow(
                  name: name,
                  isHost: i == 0,
                  isConnected: live,
                ),
            ],
          ),
        ),
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.invitationsCount(0), style: h16),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.invitationsBody, style: secondary),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 44,
                child: FilledButton(
                  key: const Key('invite-participant'),
                  onPressed: () => openScheduleMeeting(context, existing: m),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                    textStyle: AppTextStyles.mobileXsSemiBold,
                  ),
                  child: Text('+ ${l10n.inviteParticipant}'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const WfSvg('invite_empty', size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.noInvitations,
                      style: AppTextStyles.mobileBaseSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.noInvitationsBody, style: secondary),
            ],
          ),
        ),
      ],
    );
  }
}

/// The meeting's facts in one card, shared by the demo and API details:
/// title and badges, then the timing and the other short facts as
/// [DetailGrid]s that use the width (two columns on a phone, more on a
/// tablet, label-and-value lines when only one fits), the enabled features
/// as badges, and the description in full. It replaced eleven stacked
/// label/value blocks after the Redmi 8 acceptance run.
class MeetingFactsCard extends StatelessWidget {
  const new({
    required this.title,
    required this.badges,
    required this.timing,
    required this.info,
    required this.features,
    required this.description,
    super.key,
  });

  final String title;
  final List<Widget> badges;
  final List<DetailField> timing;
  final List<DetailField> info;
  final Set<MeetingFeature> features;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = description?.trim() ?? '';
    final heading = AppTextStyles.mobileXsSemiBold.copyWith(
      color: AppColors.textSecondary,
    );
    Widget section(String title, Widget child, {Key? key}) => Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: AppSpacing.lg, color: ModuleColors.chipBorder),
        Text(title, style: heading),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
    return ModuleCard(
      key: const Key('meeting-facts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContentText(
            title,
            style: AppTextStyles.mobileLgSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: 8, runSpacing: 8, children: badges),
          section(
            l10n.meetingTiming,
            DetailGrid(timing, key: const Key('meeting-timing')),
          ),
          section(
            l10n.details,
            DetailGrid(info, key: const Key('meeting-info')),
          ),
          section(
            l10n.features,
            features.isEmpty
                ? Text(
                    '—',
                    style: AppTextStyles.mobileBaseSemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in MeetingFeature.values)
                        if (features.contains(f))
                          StatusBadge(
                            label: featureLabel(l10n, f),
                            tone: BadgeTone.neutral,
                          ),
                    ],
                  ),
            key: const Key('meeting-features'),
          ),
          if (text.isNotEmpty)
            section(
              l10n.description,
              ContentText(
                text,
                style: AppTextStyles.mobileBaseRegular.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              key: const Key('meeting-description'),
            ),
        ],
      ),
    );
  }
}

/// A card heading with an optional subtitle and a refresh icon at the end
/// (it used to be a full-width chip on its own line).
class MeetingSectionHeader extends StatelessWidget {
  const new({required this.title, this.subtitle, this.onRefresh, super.key});

  final String title;
  final String? subtitle;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.mobileLgSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: AppTextStyles.mobileXsRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onRefresh != null)
          IconButton(
            key: const Key('participants-refresh'),
            tooltip: l10n.refreshList,
            visualDensity: VisualDensity.compact,
            onPressed: onRefresh,
            icon: Icon(Icons.refresh, color: AppColors.primary),
          ),
      ],
    );
  }
}

/// One participant on one line: the name, then host and connection badges
/// at the end. Badges wrap under the name only when the line is too narrow.
class MeetingParticipantRow extends StatelessWidget {
  const new({
    required this.name,
    required this.isHost,
    required this.isConnected,
    super.key,
  });

  final String name;
  final bool isHost;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ContentText(
            name,
            style: AppTextStyles.mobileBaseSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (isHost) StatusBadge(label: l10n.host, tone: BadgeTone.info),
              StatusBadge(
                label: isConnected ? l10n.connected : l10n.disconnected,
                tone: isConnected ? BadgeTone.success : BadgeTone.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _featureLabel(AppLocalizations l10n, MeetingFeature f) => switch (f) {
  MeetingFeature.chat => l10n.featureChat,
  MeetingFeature.screen => l10n.featureScreen,
  MeetingFeature.whiteboard => l10n.featureWhiteboard,
  MeetingFeature.files => l10n.featureFiles,
};

String featureLabel(AppLocalizations l10n, MeetingFeature f) =>
    _featureLabel(l10n, f);
