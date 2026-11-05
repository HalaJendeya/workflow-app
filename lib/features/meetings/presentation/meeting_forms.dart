import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/domain/finance_models.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/meetings/domain/meeting.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_details_screen.dart'
    show featureLabel;
import 'package:workflow_app/features/meetings/presentation/meeting_room_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

Future<void> openScheduleMeeting(BuildContext context, {Meeting? existing}) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ScheduleMeetingScreen(existing: existing),
      ),
    );

Future<void> openJoinByCode(BuildContext context, {String? code}) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => JoinByCodeScreen(code: code)),
    );

const _slots = [
  '08:00',
  '09:00',
  '09:30',
  '10:00',
  '10:30',
  '11:00',
  '14:00',
  '14:30',
  '15:00',
  '15:30',
  '16:00',
];

const _people = [
  'Ahmed Al-Saeed',
  'Sara Ali',
  'Rania El-Masri',
  'Karim Abdullah',
];

/// Figma "Schedule a New Meeting" (643:39086).
class ScheduleMeetingScreen extends ConsumerStatefulWidget {
  const new({this.existing, super.key});

  final Meeting? existing;

  @override
  ConsumerState<ScheduleMeetingScreen> createState() =>
      _ScheduleMeetingScreenState();
}

class _ScheduleMeetingScreenState extends ConsumerState<ScheduleMeetingScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _agenda = TextEditingController(
    text: widget.existing?.description,
  );
  final _external = TextEditingController();
  late DateTime _date = widget.existing?.start ?? DateTime.now();
  late String _slot = widget.existing == null
      ? '10:00'
      : DateFormat('HH:mm', 'en').format(widget.existing!.start);
  late String? _company = widget.existing?.company;
  late MeetingStatus _status =
      widget.existing?.status ?? MeetingStatus.scheduled;
  late final _participants = <String>[...?widget.existing?.participants];
  late final _features = <MeetingFeature>{
    ...?widget.existing?.features,
    if (widget.existing == null) ...[
      MeetingFeature.chat,
      MeetingFeature.screen,
      MeetingFeature.whiteboard,
    ],
  };
  String _query = '';

  @override
  void dispose() {
    _title.dispose();
    _agenda.dispose();
    _external.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final parts = _slot.split(':').map(int.parse).toList();
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      parts[0],
      parts[1],
    );
    final e = widget.existing;
    final meeting = Meeting(
      id: e?.id ?? localId('mtg'),
      title: _title.text.trim(),
      description: _agenda.text.trim(),
      company: _company ?? '—',
      code: e?.code ?? 'WF-${start.millisecondsSinceEpoch % 10000}',
      start: start,
      end: start.add(const Duration(hours: 1)),
      status: _status,
      participants: _participants,
      features: _features,
    );
    final n = ref.read(meetingsProvider.notifier);
    final applied = e == null ? n.add(meeting) : n.replace(meeting);
    showLocalOutcome(context, applied: applied);
    if (!applied) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final h16 = AppTextStyles.mobileLgSemiBold.copyWith(
      color: AppColors.textPrimary,
    );
    final sub = AppTextStyles.mobileXsRegular.copyWith(
      color: AppColors.textSecondary,
    );
    final q = _query.trim().toLowerCase();
    final suggestions = _people
        .where((p) => !_participants.contains(p))
        .where((p) => q.isEmpty || p.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Form(
        key: _form,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ModuleMasthead(
                title: widget.existing == null
                    ? l10n.scheduleMeetingTitle
                    : l10n.editMeeting,
                description: l10n.scheduleMeetingBody,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              sliver: SliverList.list(
                children: [
                  ModuleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.stepDateTime, style: h16),
                        const SizedBox(height: 4),
                        Text(l10n.stepDateTimeBody, style: sub),
                        const SizedBox(height: 16),
                        CalendarDatePicker(
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          onDateChanged: (d) => setState(() => _date = d),
                        ),
                        Text(l10n.availableTimes, style: sub),
                        const SizedBox(height: 8),
                        const StatusBadge(
                          label: 'GMT+3 (Riyadh / Gaza)',
                          tone: BadgeTone.info,
                        ),
                        const SizedBox(height: 12),
                        ChipRow(
                          children: [
                            for (final s in _slots)
                              FilterChipBox(
                                label: s,
                                selected: _slot == s,
                                onTap: () => setState(() => _slot = s),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.inviteDispatchNote,
                          style: AppTextStyles.mobileXsRegular.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ModuleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.stepDetails, style: h16),
                        const SizedBox(height: 4),
                        Text(l10n.stepDetailsBody, style: sub),
                        const SizedBox(height: 16),
                        TextInputField(
                          fieldKey: const Key('meeting-title'),
                          label: '${l10n.meetingTitle} *',
                          controller: _title,
                        ),
                        const SizedBox(height: 16),
                        TextInputField(
                          label: l10n.agenda,
                          controller: _agenda,
                          maxLines: 4,
                          required: false,
                        ),
                        const SizedBox(height: 16),
                        SelectField<String>(
                          label: l10n.meetingType,
                          value: l10n.onlineVideoMeeting,
                          options: [l10n.onlineVideoMeeting],
                          labelOf: (s) => s,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 16),
                        SelectField<MeetingStatus>(
                          label: l10n.meetingStatus,
                          value: _status,
                          options: const [
                            MeetingStatus.scheduled,
                            MeetingStatus.waiting,
                          ],
                          labelOf: (s) => s == MeetingStatus.scheduled
                              ? l10n.meetingScheduled
                              : l10n.meetingWaiting,
                          onChanged: (s) =>
                              setState(() => _status = s ?? _status),
                        ),
                        const SizedBox(height: 16),
                        SelectField<String>(
                          label: l10n.companyClient,
                          value: _company,
                          options: {
                            ...FinanceOptions.companies,
                            ?_company,
                          }.toList(),
                          labelOf: (s) => s,
                          required: false,
                          onChanged: (v) => setState(() => _company = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ModuleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.stepParticipants, style: h16),
                        const SizedBox(height: 4),
                        Text(l10n.stepParticipantsBody, style: sub),
                        const SizedBox(height: 16),
                        WfSearchBox(
                          hint: l10n.searchEmployeesHint,
                          onChanged: (v) => setState(() => _query = v),
                        ),
                        for (final p in suggestions.take(3))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(p),
                            trailing: const Icon(
                              Icons.add,
                              color: AppColors.primary,
                            ),
                            onTap: () => setState(() => _participants.add(p)),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _external,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'email@example.com',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilterChipBox(
                              label: '+ ${l10n.addExternal}',
                              selected: true,
                              onTap: () {
                                final v = _external.text.trim();
                                if (v.contains('@')) {
                                  setState(() => _participants.add(v));
                                  _external.clear();
                                }
                              },
                            ),
                          ],
                        ),
                        for (final p in _participants)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              p,
                              style: AppTextStyles.mobileBaseSemiBold.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: l10n.delete,
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _participants.remove(p)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ModuleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.collaborationFeatures, style: h16),
                        for (final f in MeetingFeature.values)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _features.contains(f),
                            title: Text(featureLabel(l10n, f)),
                            onChanged: (v) => setState(
                              () => v! ? _features.add(f) : _features.remove(f),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('● ${l10n.encryptedRoom}', style: sub),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const Key('meeting-save'),
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                        textStyle: AppTextStyles.mobileBaseSemiBold,
                      ),
                      child: Text(l10n.save),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: AppColors.white,
                        side: const BorderSide(color: ModuleColors.chipBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                      ),
                      child: Text(l10n.cancel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma "Join by Code" (643:38034).
class JoinByCodeScreen extends ConsumerStatefulWidget {
  const new({this.code, super.key});

  final String? code;

  @override
  ConsumerState<JoinByCodeScreen> createState() => _JoinByCodeScreenState();
}

class _JoinByCodeScreenState extends ConsumerState<JoinByCodeScreen> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.code);
  final _password = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final code = _code.text.trim().toUpperCase();
    final m = ref
        .read(meetingsProvider)
        .where((x) => x.code.toUpperCase() == code)
        .firstOrNull;
    if (m == null) {
      showSnack(context, l10n.meetingNotFound);
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => MeetingRoomScreen(id: m.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FormPage(
      title: l10n.joinByCodeTitle,
      formKey: _form,
      onSave: _join,
      saveLabel: l10n.joinMeeting,
      fields: [
        TextInputField(
          fieldKey: const Key('join-code'),
          label: '${l10n.meetingCode} *',
          controller: _code,
          hint: 'BHU-232-CEK',
        ),
        TextInputField(
          label: l10n.roomPassword,
          controller: _password,
          hint: 'password123',
          required: false,
        ),
      ],
    );
  }
}
