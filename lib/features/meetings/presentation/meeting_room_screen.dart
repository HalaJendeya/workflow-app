import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/meetings/domain/meeting.dart';
import 'package:workflow_app/features/profile/data/profile_repository.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Dark in-call palette from the meeting room frames (671:4034, 670:2505…).
abstract final class RoomColors {
  static const bg = Color(0xFF0B1220);
  static const top = Color(0xFF101820);
  static const button = Color(0xE61E293B);
  static const chip = Color(0xE6121A2D);
  static const panel = Color(0xFF0F172A);
  static const input = Color(0xFF0D1424);
  static const blue = Color(0xFF0066FF);
  static const live = Color(0xFF34D399);
  static const liveBg = Color(0x3310B981);
  static const leave = Color(0xFFDC2626);
  static const mutedBg = Color(0x33EF4444);
  static const mutedFg = Color(0xFFFDA4AF);
  static const host = Color(0xFFFBBF24);
  static const text = Color(0xFFF1F5F9);
  static const sub = Color(0xFF94A3B8);
  static const faint = Color(0xFFB1B1B1);
}

enum _Panel { stage, chat, polls, notes, participants }

class _RoomMessage {
  const new(this.author, this.text, this.at, {this.mine = false});
  final String author;
  final String text;
  final DateTime at;
  final bool mine;
}

/// In-call room built from the meeting room frames. Audio/video need the
/// LiveKit backend, so controls only change local UI state in this build.
class MeetingRoomScreen extends ConsumerStatefulWidget {
  const new({required this.id, super.key});

  final String id;

  @override
  ConsumerState<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends ConsumerState<MeetingRoomScreen> {
  _Panel _panel = _Panel.stage;
  bool _micOn = false;
  bool _camOn = false;
  bool _hand = false;
  final _started = DateTime.now();
  late final Timer _ticker;
  final _input = TextEditingController();
  final _noteTitle = TextEditingController();
  final _noteBody = TextEditingController();
  final _notes = <String>[];
  late final _messages = <_RoomMessage>[
    _RoomMessage(
      'Rania El-Masri',
      'Hello everyone, please review the Q2 budget forecast before we dive '
          'into the agenda items.',
      DateTime.now().subtract(const Duration(minutes: 3)),
    ),
    _RoomMessage(
      'Karim Abdullah',
      'I reviewed the updated forecasts, looks very promising!',
      DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];
  final _poll = <String, int>{
    'Optimizing call performance & audio': 12,
    'Server response acceleration': 4,
    'Additional UI integrations': 2,
  };
  String? _vote;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    _input.dispose();
    _noteTitle.dispose();
    _noteBody.dispose();
    super.dispose();
  }

  String get _elapsed {
    final d = DateTime.now().difference(_started);
    String two(int n) => n.toString().padLeft(2, '0');
    final mins = two(d.inMinutes % 60);
    return '${two(d.inHours)}:$mins:${two(d.inSeconds % 60)}';
  }

  TextStyle _t(double size, Color c, [FontWeight w = FontWeight.w400]) =>
      TextStyle(
        fontFamily: AppTextStyles.family,
        fontSize: size,
        fontWeight: w,
        color: c,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = ref
        .watch(meetingsProvider)
        .where((x) => x.id == widget.id)
        .firstOrNull;
    if (m == null) return const Scaffold(backgroundColor: RoomColors.bg);
    final people = ['Rania El-Masri', l10n.you, ...m.participants.skip(1)];

    // Light status-bar icons on the dark call chrome, as in 671:4034.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RoomColors.bg,
        body: Column(
          children: [
            ColoredBox(
              color: RoomColors.top,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      _square(
                        Icons.chevron_left,
                        l10n.minimize,
                        () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  m.code,
                                  style: _t(
                                    12,
                                    AppColors.white,
                                    FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RoomColors.liveBg,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    '● ${l10n.meetingLive.toUpperCase()}',
                                    style: _t(
                                      10,
                                      RoomColors.live,
                                      FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_elapsed  •  '
                              '${l10n.peopleCount(people.length)}',
                              style: _t(11, RoomColors.sub),
                            ),
                          ],
                        ),
                      ),
                      _square(
                        Icons.grid_view_rounded,
                        l10n.participants,
                        () => setState(() => _panel = _Panel.participants),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  _tab(l10n.featureChat, _Panel.chat, badge: _messages.length),
                  _tab(l10n.polls, _Panel.polls),
                  _tab(l10n.notes, _Panel.notes),
                  _tab(
                    '${l10n.participants} (${people.length})',
                    _Panel.participants,
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_panel) {
                _Panel.stage => _stage(l10n),
                _Panel.chat => _chat(l10n),
                _Panel.polls => _polls(l10n),
                _Panel.notes => _notesPanel(l10n),
                _Panel.participants => _participants(l10n, people),
              },
            ),
            ColoredBox(
              color: RoomColors.bg,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _round(
                              'room_ctl_0',
                              _micOn ? l10n.mute : l10n.unmute,
                              () => setState(() => _micOn = !_micOn),
                              bg: _micOn
                                  ? RoomColors.button
                                  : RoomColors.mutedBg,
                              // The Figma SVG is the muted (crossed) mic;
                              // unmuted showed it too, contradicting the
                              // "Mute" label and the blue badge on the tile.
                              glyph: _micOn
                                  ? const Icon(
                                      Icons.mic,
                                      key: Key('room-mic-on'),
                                      size: 20,
                                      color: AppColors.white,
                                    )
                                  : null,
                            ),
                            _round(
                              'room_ctl_1',
                              l10n.camera,
                              () => setState(() => _camOn = !_camOn),
                              bg: _camOn ? RoomColors.blue : RoomColors.button,
                            ),
                            _round(
                              'room_ctl_2',
                              l10n.raiseHand,
                              () => setState(() => _hand = !_hand),
                              bg: _hand ? RoomColors.host : RoomColors.button,
                            ),
                            _round(
                              'room_ctl_3',
                              l10n.reactions,
                              () => showSnack(context, '👏'),
                            ),
                            _round(
                              'room_ctl_4',
                              l10n.moreOptions,
                              () => setState(
                                () => _panel = _panel == _Panel.stage
                                    ? _Panel.chat
                                    : _Panel.stage,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _LeaveButton(
                        label: l10n.leave,
                        style: _t(13, AppColors.white),
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The 32 px Figma square, with a tooltip like the other room controls
  /// and a 44 px touch area (32 px was easy to miss on a phone).
  Widget _square(IconData icon, String tip, VoidCallback onTap) => Tooltip(
    message: tip,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: Material(
            color: const Color(0xB31E293B),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: SizedBox.square(
                dimension: 32,
                child: Icon(
                  icon,
                  size: 18,
                  color: AppColors.white,
                  semanticLabel: tip,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _round(
    String icon,
    String tip,
    VoidCallback onTap, {
    Color bg = RoomColors.button,
    Widget? glyph,
  }) => Padding(
    padding: EdgeInsets.zero,
    child: Tooltip(
      message: tip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Center(child: glyph ?? WfSvg(icon, size: 20)),
          ),
        ),
      ),
    ),
  );

  Widget _tab(String label, _Panel p, {int? badge}) {
    final sel = _panel == p;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: sel ? RoomColors.blue : RoomColors.chip,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _panel = sel ? _Panel.stage : p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  label,
                  style: _t(
                    10,
                    sel ? AppColors.white : const Color(0xFFCBD5E1),
                  ),
                ),
                if (badge != null && badge > 0) ...[
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: AppColors.white,
                    child: Text('$badge', style: _t(9, RoomColors.blue)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stage(AppLocalizations l10n) {
    // My own tile shows my initials, and my name beside the "You" badge
    // (671:4034 shows the signed-in user there, not a fixed sample).
    final me = ref.watch(profileProvider).value;
    final fullName = me?.name?.trim() ?? '';
    final myName = fullName.isNotEmpty ? fullName : me?.displayName ?? l10n.you;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 192,
          height: 238,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: RoomColors.blue.withValues(alpha: 0.2),
                blurRadius: 80,
                spreadRadius: 10,
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 144,
                  height: 144,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF475569),
                      width: 4,
                    ),
                  ),
                  child: Text(
                    me?.initials ?? '',
                    key: const Key('room-self-initials'),
                    style: _t(36, RoomColors.blue, FontWeight.w800),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 8,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: _micOn
                        ? RoomColors.blue
                        : RoomColors.leave,
                    child: Icon(
                      _micOn ? Icons.mic : Icons.mic_off,
                      size: 14,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: RoomColors.chip,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: RoomColors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.you,
                      style: _t(10, AppColors.white, FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _hand ? '✋ $myName' : myName,
                    key: const Key('room-self-name'),
                    style: _t(12, RoomColors.text, FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (!_micOn) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: RoomColors.mutedBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l10n.micMuted,
                  style: _t(11, RoomColors.mutedFg, FontWeight.w500),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Wrapped against both screen edges, left-aligned, at 130 %
            // text on a 427 dp phone.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Text(
                l10n.mediaPending,
                key: const Key('room-media-pending'),
                textAlign: TextAlign.center,
                style: _t(11, RoomColors.sub),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chat(AppLocalizations l10n) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Text(
                l10n.meetingStartedAt(DateFormat.jm('en').format(_started)),
                style: _t(10, RoomColors.faint),
              ),
            ),
            for (final msg in _messages) ...[
              const SizedBox(height: 16),
              Align(
                alignment: msg.mine
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Column(
                  crossAxisAlignment: msg.mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${msg.mine ? l10n.you : msg.author}  '
                      '${DateFormat.jm('en').format(msg.at)}',
                      style: _t(11, RoomColors.sub),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 270),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: msg.mine ? RoomColors.blue : RoomColors.panel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg.text, style: _t(12, AppColors.white)),
                    ),
                    if (msg.mine) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.delivered} ✓',
                        style: _t(10, RoomColors.faint),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      Container(
        color: RoomColors.input,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('room-chat-input'),
                controller: _input,
                style: _t(13, AppColors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendChat(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.messageParticipantsHint,
                  hintStyle: _t(13, const Color(0xFF64748B)),
                ),
              ),
            ),
            // Icon-only: the tooltip is also its TalkBack label.
            Tooltip(
              message: l10n.tipSend,
              child: Material(
                color: RoomColors.blue,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('room-chat-send'),
                  customBorder: const CircleBorder(),
                  onTap: _sendChat,
                  child: const SizedBox.square(
                    dimension: 32,
                    child: Icon(Icons.send, size: 16, color: AppColors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  void _sendChat() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_RoomMessage('You', t, DateTime.now(), mine: true));
      _input.clear();
    });
  }

  Widget _polls(AppLocalizations l10n) {
    final total = _poll.values.fold<int>(0, (s, v) => s + v);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RoomColors.panel,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.livePoll} · ${l10n.votesCount(total)}',
                style: _t(10, RoomColors.live, FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'What is the top priority for Q2 launch?',
                style: _t(14, AppColors.white, FontWeight.w600),
              ),
              const SizedBox(height: 12),
              for (final e in _poll.entries) ...[
                InkWell(
                  key: Key('poll-${e.key}'),
                  onTap: () => setState(() {
                    if (_vote != null) _poll[_vote!] = _poll[_vote!]! - 1;
                    _vote = e.key;
                    _poll[e.key] = e.value + 1;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: _t(
                                  12,
                                  _vote == e.key
                                      ? RoomColors.live
                                      : RoomColors.text,
                                ),
                              ),
                            ),
                            Text(
                              '${(e.value * 100 / total).round()}%',
                              style: _t(12, RoomColors.text, FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: e.value / total,
                          minHeight: 6,
                          backgroundColor: RoomColors.chip,
                          color: RoomColors.blue,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _vote == null ? l10n.tapToVote : l10n.votedAs(l10n.you),
                style: _t(11, RoomColors.sub),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notesPanel(AppLocalizations l10n) {
    InputDecoration dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: _t(13, const Color(0xFF64748B)),
      filled: true,
      fillColor: RoomColors.input,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${l10n.notes.toUpperCase()} (${_notes.length})',
          style: _t(11, RoomColors.sub, FontWeight.w700),
        ),
        for (final n in _notes)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('• $n', style: _t(13, RoomColors.text)),
          ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('note-title'),
          controller: _noteTitle,
          style: _t(13, AppColors.white),
          decoration: dec(l10n.noteTitleHint),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteBody,
          minLines: 3,
          maxLines: 5,
          style: _t(13, AppColors.white),
          decoration: dec(l10n.noteBodyHint),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('note-save'),
          style: FilledButton.styleFrom(backgroundColor: RoomColors.blue),
          onPressed: () {
            final t = _noteTitle.text.trim();
            if (t.isEmpty) return;
            setState(() {
              _notes.add(t);
              _noteTitle.clear();
              _noteBody.clear();
            });
          },
          child: Text(l10n.saveNote),
        ),
      ],
    );
  }

  Widget _participants(AppLocalizations l10n, List<String> people) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.peopleCount(people.length).toUpperCase(),
              style: _t(11, RoomColors.sub, FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _micOn = false),
            child: Text(l10n.muteAll, style: _t(12, RoomColors.mutedFg)),
          ),
        ],
      ),
      for (var i = 0; i < people.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: RoomColors.chip,
            child: Text(
              people[i].characters.first.toUpperCase(),
              style: _t(12, AppColors.white, FontWeight.w700),
            ),
          ),
          title: Text(people[i], style: _t(13, RoomColors.text)),
          subtitle: Text(
            i == 0 ? l10n.host : l10n.participant,
            style: _t(11, i == 0 ? RoomColors.host : RoomColors.sub),
          ),
        ),
      const SizedBox(height: 12),
      Text('🔒 ${l10n.encryptedMeeting}', style: _t(11, RoomColors.sub)),
    ],
  );
}

/// Opens the room for [m].
Future<void> openRoom(BuildContext context, Meeting m) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => MeetingRoomScreen(id: m.id)));

/// "Leave" from the room toolbar. Five 40 px controls plus the labelled
/// pill need 308 px; on narrower phones (320 px wide, or large text) the
/// pill becomes a 40 px round button with the same tooltip and semantics
/// label, so the toolbar never overflows.
class _LeaveButton extends StatelessWidget {
  const new({required this.label, required this.style, required this.onTap});

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).width;
    final text = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // 32 px page padding, five 40 px controls, a 12 px gap, and the pill's
    // own 36 px padding + 16 px icon + 6 px gap.
    final needed = 32 + 5 * 40 + 12 + 36 + 16 + 6 + text.width;
    text.dispose();
    final compact = needed > screen;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: RoomColors.leave,
          shape: const StadiumBorder(),
          child: InkWell(
            key: const Key('room-leave'),
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: compact
                ? const SizedBox.square(
                    dimension: 40,
                    child: Center(child: WfSvg('room_leave', size: 16)),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const WfSvg('room_leave', size: 16),
                        const SizedBox(width: 6),
                        Text(label, style: style),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
