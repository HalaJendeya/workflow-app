import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/features/meetings/application/meeting_media_controller.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_room_screen.dart'
    show RoomColors;
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// The live meeting room (API mode): the dark in-call layout of the meeting
/// room frames (671:4034) over a real LiveKit session.
///
/// Opening it asks for the microphone (and the camera, which is optional)
/// and joins through `media/join`. Leaving — the Leave button, Back, or the
/// account/company changing — stops the camera and microphone and closes
/// this device's session on the server.
class ApiMeetingRoomScreen extends ConsumerStatefulWidget {
  const new({required this.meetingId, required this.title, super.key});

  final int meetingId;
  final String title;

  @override
  ConsumerState<ApiMeetingRoomScreen> createState() =>
      _ApiMeetingRoomScreenState();
}

class _ApiMeetingRoomScreenState extends ConsumerState<ApiMeetingRoomScreen> {
  MeetingMediaController get _media =>
      ref.read(meetingMediaProvider(widget.meetingId).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_media.join(camera: true));
    });
  }

  Future<void> _leave() async {
    await _media.leave();
    if (mounted) Navigator.of(context).maybePop();
  }

  TextStyle _t(double size, Color color, [FontWeight w = FontWeight.w500]) =>
      AppTextStyles.mobileBaseRegular.copyWith(
        fontSize: size,
        height: 1.4,
        color: color,
        fontWeight: w,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(meetingMediaProvider(widget.meetingId));
    final status = switch (s.phase) {
      MediaPhase.connected => (l10n.meetingLive.toUpperCase(), RoomColors.live),
      MediaPhase.reconnecting => (l10n.meetingReconnecting, RoomColors.host),
      _ => (null, null),
    };
    return Scaffold(
      backgroundColor: RoomColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(16, AppColors.white, FontWeight.w700),
                        ),
                        if (s.inRoom)
                          Text(
                            l10n.peopleCount(s.participants.length),
                            style: _t(11, RoomColors.sub),
                          ),
                      ],
                    ),
                  ),
                  if (status case (final String label, final Color color))
                    Container(
                      key: const Key('room-status'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '● $label',
                        style: _t(10, color, FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            if (s.phase == MediaPhase.reconnecting)
              Container(
                key: const Key('room-reconnecting'),
                width: double.infinity,
                color: RoomColors.mutedBg,
                padding: const EdgeInsets.all(8),
                child: Text(
                  l10n.meetingReconnecting,
                  textAlign: TextAlign.center,
                  style: _t(12, RoomColors.text),
                ),
              ),
            Expanded(child: s.inRoom ? _stage(l10n, s) : _notInRoom(l10n, s)),
            if (s.inRoom || s.phase == MediaPhase.leaving) _controls(l10n, s),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, {Key? key, List<Widget> actions = const []}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                key: key,
                textAlign: TextAlign.center,
                style: _t(14, RoomColors.text),
              ),
              for (final a in actions) ...[const SizedBox(height: 16), a],
            ],
          ),
        ),
      );

  Widget _busy(String text) => Center(
    key: const Key('room-connecting'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: RoomColors.blue),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: _t(13, RoomColors.sub),
          ),
        ),
      ],
    ),
  );

  Widget _button(String label, VoidCallback onTap, Key key) => FilledButton(
    key: key,
    style: FilledButton.styleFrom(backgroundColor: RoomColors.blue),
    onPressed: onTap,
    child: Text(label),
  );

  Widget _notInRoom(AppLocalizations l10n, MediaSessionState s) {
    void join() => unawaited(_media.join(camera: true));
    final back = TextButton(
      key: const Key('room-back'),
      onPressed: () => Navigator.of(context).maybePop(),
      child: Text(l10n.backToMeeting, style: _t(13, RoomColors.sub)),
    );
    return switch (s.phase) {
      MediaPhase.requestingPermission => _busy(
        l10n.meetingRequestingPermission,
      ),
      MediaPhase.joining ||
      MediaPhase.connecting ||
      MediaPhase.leaving => _busy(l10n.meetingConnecting),
      MediaPhase.waitingForHost => _message(
        '${l10n.joinRequestPending}\n${l10n.joinRequestCheckHint}',
        key: const Key('room-waiting'),
        actions: [
          _button(l10n.tryJoiningAgain, join, const Key('room-try-again')),
          back,
        ],
      ),
      MediaPhase.permissionDenied => _message(
        s.permanentlyDenied
            ? l10n.meetingMicDeniedSettings
            : l10n.meetingMicDenied,
        key: const Key('room-permission-denied'),
        actions: [
          if (s.permanentlyDenied)
            _button(
              l10n.openSettings,
              () => unawaited(_media.openSettings()),
              const Key('room-open-settings'),
            ),
          _button(l10n.retry, join, const Key('room-retry')),
          back,
        ],
      ),
      MediaPhase.failed => _message(
        switch (s.error) {
          final ApiException e => localizedError(l10n, e),
          _ => l10n.meetingConnectFailed,
        },
        key: const Key('room-error'),
        actions: [_button(l10n.retry, join, const Key('room-retry')), back],
      ),
      MediaPhase.ended => _message(
        s.error == null ? l10n.leftMeeting : l10n.meetingDisconnected,
        key: const Key('room-ended'),
        actions: [
          _button(l10n.joinMeeting, join, const Key('room-rejoin')),
          back,
        ],
      ),
      MediaPhase.idle => _message(
        l10n.mediaPending,
        actions: [_button(l10n.joinMeeting, join, const Key('room-join'))],
      ),
      MediaPhase.connected || MediaPhase.reconnecting => const SizedBox(),
    };
  }

  Widget _stage(AppLocalizations l10n, MediaSessionState s) {
    final people = s.participants;
    final cameraRefused = s.error is MediaPermissionDenied;
    return Column(
      children: [
        if (cameraRefused)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.meetingCameraDenied,
              key: const Key('room-camera-denied'),
              textAlign: TextAlign.center,
              style: _t(12, RoomColors.mutedFg),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final columns = people.length <= 1
                  ? 1
                  : box.maxWidth > 600
                  ? 3
                  : 2;
              return GridView.count(
                padding: const EdgeInsets.all(12),
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 3 / 4 : 3 / 4,
                children: [for (final p in people) _tile(l10n, p)],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tile(AppLocalizations l10n, MediaParticipant p) {
    final video = p.camera ? _media.videoOf(p.id) : null;
    final initials = p.name.trim().isEmpty
        ? '?'
        : p.name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((w) => w.characters.first.toUpperCase())
              .join();
    return Container(
      key: Key('room-tile-${p.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: RoomColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: p.speaking ? RoomColors.live : const Color(0xFF1E293B),
          width: p.speaking ? 2 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ?video,
          if (video == null)
            Center(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFFF1F5FF),
                child: Text(
                  initials,
                  style: _t(20, RoomColors.blue, FontWeight.w800),
                ),
              ),
            ),
          PositionedDirectional(
            start: 8,
            end: 8,
            bottom: 8,
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: RoomColors.chip,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      p.isLocal ? l10n.you : p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(11, RoomColors.text, FontWeight.w600),
                    ),
                  ),
                ),
                if (!p.microphone) ...[
                  const SizedBox(width: 6),
                  CircleAvatar(
                    key: Key('room-muted-${p.id}'),
                    radius: 11,
                    backgroundColor: RoomColors.leave,
                    child: const Icon(
                      Icons.mic_off,
                      size: 12,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(AppLocalizations l10n, MediaSessionState s) {
    final enabled = s.phase == MediaPhase.connected;
    Widget round({
      required Key key,
      required IconData icon,
      required String tip,
      required Color bg,
      required VoidCallback? onTap,
    }) => Tooltip(
      message: tip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          key: key,
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 48,
            child: Icon(
              icon,
              size: 22,
              color: AppColors.white,
              semanticLabel: tip,
            ),
          ),
        ),
      ),
    );
    return ColoredBox(
      color: RoomColors.bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            round(
              key: const Key('room-mic'),
              icon: s.microphone ? Icons.mic : Icons.mic_off,
              tip: s.microphone ? l10n.mute : l10n.unmute,
              bg: s.microphone ? RoomColors.button : RoomColors.mutedBg,
              onTap: enabled
                  ? () =>
                        unawaited(_media.setMicrophone(enabled: !s.microphone))
                  : null,
            ),
            const SizedBox(width: 16),
            round(
              key: const Key('room-camera'),
              icon: s.camera ? Icons.videocam : Icons.videocam_off,
              tip: s.camera ? l10n.turnOffCamera : l10n.turnOnCamera,
              bg: s.camera ? RoomColors.blue : RoomColors.button,
              onTap: enabled
                  ? () => unawaited(_media.setCamera(enabled: !s.camera))
                  : null,
            ),
            const Spacer(),
            Material(
              color: RoomColors.leave,
              borderRadius: BorderRadius.circular(AppRadii.button),
              child: InkWell(
                key: const Key('room-leave'),
                borderRadius: BorderRadius.circular(AppRadii.button),
                onTap: s.phase == MediaPhase.leaving
                    ? null
                    : () => unawaited(_leave()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Text(
                    l10n.leave,
                    style: _t(14, AppColors.white, FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
