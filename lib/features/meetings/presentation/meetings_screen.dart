import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/meetings/domain/meeting.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_details_screen.dart';
import 'package:workflow_app/features/meetings/presentation/meeting_forms.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

String meetingStatusLabel(AppLocalizations l10n, MeetingStatus s) =>
    switch (s) {
      MeetingStatus.scheduled => l10n.meetingScheduled,
      MeetingStatus.live => l10n.meetingLive,
      MeetingStatus.waiting => l10n.meetingWaiting,
      MeetingStatus.overdue => l10n.statusOverdue,
      MeetingStatus.ended => l10n.meetingEnded,
    };

BadgeTone meetingTone(MeetingStatus s) => switch (s) {
  MeetingStatus.scheduled => BadgeTone.info,
  MeetingStatus.live => BadgeTone.success,
  MeetingStatus.waiting => BadgeTone.warning,
  MeetingStatus.overdue => BadgeTone.danger,
  MeetingStatus.ended => BadgeTone.neutral,
};

String hm(DateTime t) => DateFormat('HH:mm', 'en').format(t);

Future<void> openMeeting(BuildContext context, Meeting m) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => MeetingDetailsScreen(id: m.id)));

enum _Tab { scheduled, live, overdue }

/// Figma "Meetings Management" (643:38772).
class MeetingsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _day = DateTime.now();
  _Tab _tab = _Tab.scheduled;
  String _query = '';
  MeetingStatus? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demo = ref.watch(demoModeProvider);
    final all = ref.watch(meetingsProvider);
    final today = all.where((m) => m.isOn(_day)).where((m) {
      return switch (_tab) {
        _Tab.scheduled =>
          m.status == MeetingStatus.scheduled ||
              m.status == MeetingStatus.waiting ||
              m.status == MeetingStatus.live,
        _Tab.live => m.status == MeetingStatus.live,
        _Tab.overdue => m.status == MeetingStatus.overdue,
      };
    }).toList();
    final q = _query.trim().toLowerCase();
    final upcoming = all.where((m) {
      if (_status != null && m.status != _status) return false;
      return q.isEmpty ||
          '${m.title} ${m.company} ${m.code}'.toLowerCase().contains(q);
    }).toList()..sort((a, b) => a.start.compareTo(b.start));
    int n(MeetingStatus s) => all.where((m) => m.status == s).length;
    final h16 = AppTextStyles.mobileLgSemiBold.copyWith(
      color: AppColors.textPrimary,
    );

    return ModulePage(
      title: l10n.meetingsTitle,
      description: l10n.meetingsDescription,
      onSearch: (v) => setState(() => _query = v),
      onCreate: () => openScheduleMeeting(context),
      createLabel: l10n.scheduleMeeting,
      children: [
        if (!demo) const BackendPendingNotice(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilterChipBox(
            label: l10n.joinByCode,
            selected: true,
            onTap: () => openJoinByCode(context),
          ),
        ),
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.meetingOverview, style: h16),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _Kpi(l10n.totalMeetings, '${all.length}')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _Kpi(
                      l10n.liveNow,
                      l10n.activeCount(n(MeetingStatus.live)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Kpi(
                      l10n.meetingScheduled,
                      (n(MeetingStatus.scheduled) + n(MeetingStatus.waiting))
                          .toString(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _Kpi(l10n.meetingEnded, '${n(MeetingStatus.ended)}'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(l10n.meetingsCalendar, style: h16),
        ModuleCard(
          child: _MonthCalendar(
            month: _month,
            selected: _day,
            marked: {
              for (final m in all)
                if (m.start.year == _month.year &&
                    m.start.month == _month.month)
                  m.start.day,
            },
            onMonth: (d) => setState(() => _month = d),
            onDay: (d) => setState(() => _day = d),
          ),
        ),
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
        Text(
          l10n.timezoneLabel(_utcOffset()),
          style: AppTextStyles.mobileXsRegular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          _isToday(_day)
              ? l10n.todaysMeetings
              : DateFormat.yMMMMd('en').format(_day),
          style: h16,
        ),
        if (today.isEmpty) EmptyNotice(text: l10n.noMeetingsThisDay),
        for (final m in today)
          ModuleCard(
            key: Key('today-${m.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(m.title, style: h16),
                const SizedBox(height: 4),
                Text(
                  '${m.company}\n${hm(m.start)} – ${hm(m.end)}',
                  style: AppTextStyles.mobileXsRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusBadge(
                    label: meetingStatusLabel(l10n, m.status),
                    tone: meetingTone(m.status),
                    radius: 6,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: () => openMeeting(context, m),
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
          ),
        Text(l10n.upcomingMeetings, style: h16),
        WfSearchBox(
          fieldKey: const Key('meetings-search'),
          hint: l10n.searchMeetingsHint,
          onChanged: (v) => setState(() => _query = v),
        ),
        ChipRow(
          children: [
            DropdownChip<MeetingStatus?>(
              value: _status,
              options: const [null, ...MeetingStatus.values],
              labelOf: (s) => s == null
                  ? l10n.filterAllStatus
                  : meetingStatusLabel(l10n, s),
              onChanged: (s) => setState(() => _status = s),
            ),
          ],
        ),
        if (upcoming.isEmpty) EmptyNotice(text: l10n.noRecords),
        for (final m in upcoming)
          RecordCard(
            key: Key('meeting-${m.id}'),
            reference: m.title,
            title: m.description,
            status: meetingStatusLabel(l10n, m.status),
            tone: meetingTone(m.status),
            subtitle: m.company,
            fields: [
              DetailField(
                l10n.meetingScheduled,
                DateFormat('yyyy-MM-dd · HH:mm', 'en').format(m.start),
              ),
              DetailField(
                l10n.codeTypeParticipants,
                '${m.code} · ${meetingStatusLabel(l10n, m.status)} · '
                '+${m.participants.length}',
              ),
            ],
            onView: () => openMeeting(context, m),
            onEdit: () => openScheduleMeeting(context, existing: m),
            onDelete: () async {
              if (await confirmDelete(context, m.title)) {
                ref.read(meetingsProvider.notifier).remove(m.id);
                if (context.mounted) showSnack(context, l10n.deletedLocally);
              }
            },
          ),
      ],
    );
  }

  static bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  static String _utcOffset() {
    final o = DateTime.now().timeZoneOffset;
    final h = o.inHours;
    return 'GMT${h >= 0 ? '+' : ''}$h';
  }
}

class _Kpi extends StatelessWidget {
  const new(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.mobileXsRegular.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: AppTextStyles.mobileBaseSemiBold.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}

/// Month grid from the "Meetings Calendar" card: 38×34 cells, selected day
/// in a 12 px-radius primary tile, days outside the month in #9E9E9E.
class _MonthCalendar extends StatelessWidget {
  const new({
    required this.month,
    required this.selected,
    required this.marked,
    required this.onMonth,
    required this.onDay,
  });

  final DateTime month;
  final DateTime selected;
  final Set<int> marked;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final first = DateTime(month.year, month.month);
    final lead = first.weekday % 7; // Sunday-first grid.
    final start = first.subtract(Duration(days: lead));
    final days = List.generate(42, (i) => start.add(Duration(days: i)));
    final weekdays = DateFormat.E(locale);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat.yMMMM(locale).format(month),
                style: AppTextStyles.mobileBaseSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: _dirIcon(context, 'cal_prev', 'cal_next'),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: _dirIcon(context, 'cal_next', 'cal_prev'),
            ),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: Center(
                    child: Text(
                      weekdays.format(days[i]),
                      style: AppTextStyles.mobileXsRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var w = 0; w < 6; w++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(child: _cell(context, days[w * 7 + d])),
            ],
          ),
      ],
    );
  }

  Widget _dirIcon(BuildContext context, String ltr, String rtl) =>
      WfSvg(Directionality.of(context) == TextDirection.rtl ? rtl : ltr);

  Widget _cell(BuildContext context, DateTime day) {
    final inMonth = day.month == month.month;
    final isSel =
        day.year == selected.year &&
        day.month == selected.month &&
        day.day == selected.day;
    return InkWell(
      key: Key('cal-${day.month}-${day.day}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => onDay(day),
      child: Container(
        height: 34,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primary : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${day.day}',
              style: AppTextStyles.mobileBaseRegular.copyWith(
                fontWeight: FontWeight.w500,
                color: isSel
                    ? AppColors.white
                    : inMonth
                    ? AppColors.textPrimary
                    : ModuleColors.muted,
              ),
            ),
            if (inMonth && marked.contains(day.day) && !isSel)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
