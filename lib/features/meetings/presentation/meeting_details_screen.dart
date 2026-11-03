import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/meetings/domain/meeting.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_forms.dart';
import 'package:workflow_app/features/meetings/presentation/meetings_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Figma meeting details (643:37740).
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
    final fmt = DateFormat('M/d/y, h:mm:ss a', 'en');
    final h16 = AppTextStyles.mobileLgSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    final secondary = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
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
    final started =
        m.status == MeetingStatus.live || m.status == MeetingStatus.ended;

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
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.details, style: h16),
              const SizedBox(height: 4),
              Text(l10n.detailsBody, style: secondary),
              const SizedBox(height: 16),
              StatusBadge(
                label: '${l10n.meetingId}: ${m.code}',
                tone: BadgeTone.info,
              ),
              field(l10n.fieldType, meetingStatusLabel(l10n, m.status)),
              field(l10n.scheduledAt, fmt.format(m.start)),
              field(l10n.privacy, m.isPublic ? l10n.public : l10n.private),
              field(l10n.startedAt, started ? fmt.format(m.start) : '—'),
              field(
                l10n.endedAt,
                m.status == MeetingStatus.ended ? fmt.format(m.end) : '—',
              ),
              field(l10n.fieldProject, m.project ?? '—'),
              field(l10n.duration, l10n.minutes(m.duration.inMinutes)),
              field(l10n.createdBy, m.createdBy),
              field(l10n.peakParticipants, '${m.participants.length}'),
              field(l10n.maxParticipants, '${m.maxParticipants}'),
              const SizedBox(height: 16),
              Text(l10n.features, style: secondary),
              const SizedBox(height: 8),
              ChipRow(
                children: [
                  for (final f in MeetingFeature.values)
                    FilterChipBox(
                      label: _featureLabel(l10n, f),
                      selected: m.features.contains(f),
                      onTap: () {},
                    ),
                ],
              ),
              field(l10n.description, m.description),
            ],
          ),
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
                const SizedBox(height: 16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.participants} (${m.participants.length})',
                style: h16,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.peakOf(m.participants.length, m.maxParticipants),
                style: secondary,
              ),
              const SizedBox(height: 16),
              FilterChipBox(
                label: l10n.refreshList,
                selected: true,
                onTap: () => showSnack(context, l10n.listUpToDate),
              ),
              for (var i = 0; i < m.participants.length; i++) ...[
                const SizedBox(height: 16),
                Text('#${i + 1} · ${l10n.user}', style: secondary),
                const SizedBox(height: 4),
                Text(
                  m.participants[i],
                  style: AppTextStyles.mobileBaseSemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (i == 0)
                      StatusBadge(label: l10n.host, tone: BadgeTone.info),
                    StatusBadge(
                      label: m.status == MeetingStatus.live
                          ? l10n.connected
                          : l10n.disconnected,
                      tone: m.status == MeetingStatus.live
                          ? BadgeTone.success
                          : BadgeTone.warning,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.invitationsCount(0), style: h16),
              const SizedBox(height: 4),
              Text(l10n.invitationsBody, style: secondary),
              const SizedBox(height: 16),
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
              const SizedBox(height: 8),
              Text(
                l10n.noInvitationsBody,
                textAlign: TextAlign.center,
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

String _featureLabel(AppLocalizations l10n, MeetingFeature f) => switch (f) {
  MeetingFeature.chat => l10n.featureChat,
  MeetingFeature.screen => l10n.featureScreen,
  MeetingFeature.whiteboard => l10n.featureWhiteboard,
  MeetingFeature.files => l10n.featureFiles,
};

String featureLabel(AppLocalizations l10n, MeetingFeature f) =>
    _featureLabel(l10n, f);
