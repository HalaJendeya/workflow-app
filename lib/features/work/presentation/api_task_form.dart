import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/work/data/board_repository.dart';
import 'package:workflow_app/features/work/data/work_options.dart';
import 'package:workflow_app/features/work/domain/work_models.dart';
import 'package:workflow_app/features/work/presentation/api_sprint_view.dart';
import 'package:workflow_app/features/work/presentation/tasks_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Opens the API task form: a new task (optionally on [projectId]) or an
/// edit of [existing]. Only offered for projects the user leads; the
/// server is still the one that decides (403 is shown as such).
Future<void> openApiTaskForm(
  BuildContext context, {
  ApiTask? existing,
  int? projectId,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => ApiTaskFormScreen(existing: existing, projectId: projectId),
  ),
);

/// Whether the signed-in user may edit [t] from the app: a project they
/// lead (from `projects/options?led=1`) and a row that does not say
/// `can.update: false`.
bool canEditApiTask(Set<int> led, ApiTask t) =>
    t.projectId != null && led.contains(t.projectId) && t.canUpdate != false;

/// Create/edit form for `POST /employee/tasks` and
/// `PUT /employee/tasks/{task}`. Fields follow the documented validation
/// rules: project (create only), sprint, assignee (`users.id`), title,
/// description, story points, priority, status, planned work date and an
/// optional start/end time (end after start, at most 4 hours).
class ApiTaskFormScreen extends ConsumerStatefulWidget {
  const new({this.existing, this.projectId, super.key});

  final ApiTask? existing;
  final int? projectId;

  @override
  ConsumerState<ApiTaskFormScreen> createState() => _ApiTaskFormScreenState();
}

class _ApiTaskFormScreenState extends ConsumerState<ApiTaskFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TaskDraft? _original = widget.existing == null
      ? null
      : TaskDraft.fromTask(widget.existing!);
  late final _title = TextEditingController(text: _original?.title);
  late final _description = TextEditingController(text: _original?.description);
  late final _points = TextEditingController(
    text: _original?.storyPoints?.toString(),
  );
  late int? _project = _original?.projectId ?? widget.projectId;
  late int? _sprint = _original?.sprintId;
  late int? _assignee = _original?.assignedTo;
  // Defaults apply to a new task only: an edit starts from exactly what the
  // row said, so an untouched empty field is never sent as a change.
  late TaskPriority? _priority = _original == null
      ? TaskPriority.medium
      : _original.priority;
  late ApiTaskStatus? _status = _original == null
      ? ApiTaskStatus.todo
      : _original.status;
  late DateTime _date =
      _original?.taskDate ?? DateUtils.dateOnly(DateTime.now());

  /// Whether the date was picked; an edited row without a date keeps none
  /// until one is picked.
  bool _datePicked = false;
  late TimeOfDay? _start = _clock(_original?.start);
  late TimeOfDay? _end = _clock(_original?.end);
  bool _saving = false;
  Object? _error;

  /// The project the form will save on: the one picked, or the only
  /// project the user leads.
  int? _resolvedProject;

  static TimeOfDay? _clock(ClockTime? t) =>
      t == null ? null : TimeOfDay(hour: t.hour, minute: t.minute);

  static ClockTime? _time(TimeOfDay? t) =>
      t == null ? null : (hour: t.hour, minute: t.minute);

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _points.dispose();
    super.dispose();
  }

  String? _timeProblem(AppLocalizations l10n) =>
      switch (taskTimeProblem(_time(_start), _time(_end))) {
        TaskTimeProblem.endWithoutStart => l10n.taskEndWithoutStart,
        TaskTimeProblem.endNotAfterStart => l10n.taskEndNotAfterStart,
        TaskTimeProblem.overFourHours => l10n.taskOverFourHours,
        null => null,
      };

  Future<void> _save() async {
    if (_saving || !validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    final draft = TaskDraft(
      projectId: _resolvedProject!,
      title: _title.text,
      description: _description.text,
      storyPoints: int.tryParse(_points.text.trim()),
      priority: _priority,
      status: _status,
      sprintId: _sprint,
      assignedTo: _assignee,
      taskDate: _original != null && _original.taskDate == null && !_datePicked
          ? null
          : _date,
      start: _time(_start),
      end: _time(_end),
    );
    final original = _original;
    if (original != null && draft.changesFrom(original).isEmpty) {
      showSnack(context, l10n.taskNoChanges);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(boardRepositoryProvider);
      if (original == null) {
        await repo.createTask(draft);
      } else {
        await repo.updateTask(widget.existing!.id, draft, original);
      }
      if (!mounted) return;
      invalidateTaskData(ref, taskId: widget.existing?.id);
      showSnack(context, _editing ? l10n.taskSaved : l10n.taskCreated);
      Navigator.of(context).pop();
    } on Object catch (e) {
      // Nothing is shown as saved: the form stays filled in with the
      // server's reason, and the lists keep what the server last said.
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final led = ref.watch(ledProjectsProvider);
    final people = ref.watch(peopleOptionsProvider);
    final projects = led.value ?? const <ProjectOption>[];
    final project =
        _project ?? (projects.length == 1 ? projects.single.id : null);
    _resolvedProject = project;
    final sprints = project == null
        ? null
        : ref.watch(sprintOptionsProvider(project));
    final projectTitle =
        projects.where((p) => p.id == project).firstOrNull?.title ??
        widget.existing?.projectTitle;
    final sprintIds = <int?>[
      null,
      for (final s in sprints?.value ?? const <SprintOption>[]) s.id,
    ];
    if (_sprint != null && !sprintIds.contains(_sprint)) sprintIds.add(_sprint);
    final personIds = <int?>[
      null,
      for (final p in people.value ?? const <PersonOption>[]) p.userId,
    ];
    if (_assignee != null && !personIds.contains(_assignee)) {
      personIds.add(_assignee);
    }
    String sprintLabel(int? id) {
      if (id == null) return l10n.noSprint;
      return (sprints?.value ?? const <SprintOption>[])
              .where((s) => s.id == id)
              .firstOrNull
              ?.name ??
          widget.existing?.sprintName ??
          '#$id';
    }

    String personLabel(int? id) {
      if (id == null) return l10n.unassigned;
      return (people.value ?? const <PersonOption>[])
              .where((p) => p.userId == id)
              .firstOrNull
              ?.name ??
          widget.existing?.assigneeName ??
          '#$id';
    }

    return FormPage(
      key: const Key('api-task-form'),
      title: _editing ? l10n.editTask : l10n.addTask,
      formKey: _form,
      onSave: _save,
      saving: _saving,
      fields: [
        if (_editing)
          _ReadOnlyField(
            label: l10n.fieldProject,
            value: projectTitle ?? '#$project',
          )
        else if (led.hasError)
          ApiErrorCard(
            error: led.error!,
            onRetry: () => ref.invalidate(ledProjectsProvider),
          )
        else
          SelectField<int>(
            key: ValueKey(('project', projects.length, project)),
            label: l10n.fieldProject,
            value: projects.any((p) => p.id == project) ? project : null,
            options: [for (final p in projects) p.id],
            labelOf: (id) => projects.firstWhere((p) => p.id == id).title,
            onChanged: (v) => setState(() {
              _project = v;
              // A sprint belongs to one project.
              _sprint = null;
            }),
          ),
        TextInputField(
          fieldKey: const Key('api-task-title'),
          label: l10n.taskTitle,
          controller: _title,
          validator: (v) => (v?.trim().length ?? 0) > 255
              ? l10n.validationTooLong(255)
              : null,
        ),
        TextInputField(
          fieldKey: const Key('api-task-description'),
          label: l10n.description,
          controller: _description,
          hint: l10n.optionalHint,
          maxLines: 3,
          required: false,
        ),
        SelectField<int?>(
          key: ValueKey(('sprint', project, sprintIds.length)),
          label: l10n.fieldSprint,
          value: _sprint,
          options: sprintIds,
          labelOf: sprintLabel,
          required: false,
          onChanged: (v) => setState(() => _sprint = v),
        ),
        SelectField<int?>(
          key: ValueKey(('assignee', personIds.length)),
          label: l10n.assignee,
          value: _assignee,
          options: personIds,
          labelOf: personLabel,
          required: false,
          onChanged: (v) => setState(() => _assignee = v),
        ),
        Text(
          l10n.taskAssigneeHint,
          style: AppTextStyles.mobileXsRegular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        SelectField<TaskPriority?>(
          label: l10n.priority,
          value: _priority,
          options: const [null, ...TaskPriority.values],
          labelOf: (p) => p == null ? '—' : priorityLabel(l10n, p),
          required: false,
          onChanged: (v) => setState(() => _priority = v),
        ),
        SelectField<ApiTaskStatus?>(
          label: l10n.fieldStatus,
          value: _status,
          options: const [
            ApiTaskStatus.backlog,
            ApiTaskStatus.todo,
            ApiTaskStatus.pending,
            ApiTaskStatus.inProgress,
            ApiTaskStatus.inReview,
            ApiTaskStatus.completed,
          ],
          labelOf: (s) => s == null ? '—' : apiTaskStatusLabel(l10n, s),
          required: false,
          onChanged: (v) => setState(() => _status = v),
        ),
        TextInputField(
          fieldKey: const Key('api-task-points'),
          label: l10n.storyPoints,
          controller: _points,
          hint: l10n.optionalHint,
          required: false,
          keyboardType: TextInputType.number,
          // Whole and not negative (`story_points`: integer, min:0).
          validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) < 0
              ? l10n.validationWholeNumber
              : wholeNumber(context, v?.trim()),
        ),
        DateField(
          label: l10n.taskDate,
          value: _date,
          onChanged: (d) => setState(() {
            _date = d;
            _datePicked = true;
          }),
        ),
        TimeField(
          fieldKey: const Key('api-task-start'),
          label: l10n.startTime,
          value: _start,
          onChanged: (t) => setState(() => _start = t),
        ),
        TimeField(
          fieldKey: const Key('api-task-end'),
          label: l10n.endTime,
          value: _end,
          onChanged: (t) => setState(() => _end = t),
          validator: (_) => _timeProblem(l10n),
        ),
        if (_error case final e?) _SaveError(error: e),
      ],
    );
  }
}

/// Why the server refused the task, in the app's words where the reason
/// is documented (403 lead-only, 409 approved month) and with the server's
/// field messages for a 422.
class _SaveError extends StatelessWidget {
  const new({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final e = error;
    final (String text, List<String> details) = switch (e) {
      ApiException(kind: ApiFailureKind.forbidden) => (l10n.taskLeadOnly, []),
      ApiException(kind: ApiFailureKind.conflict) => (l10n.taskMonthLocked, []),
      ApiException(kind: ApiFailureKind.validation, :final fieldErrors) => (
        l10n.serverRejected,
        [for (final m in fieldErrors.values) ...m],
      ),
      _ => (localizedError(l10n, e), <String>[]),
    };
    return ModuleCard(
      key: const Key('api-task-error'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppTextStyles.mobileXsSemiBold.copyWith(
              color: ModuleColors.dangerFg,
            ),
          ),
          for (final d in details) ...[
            const SizedBox(height: 4),
            Text(
              d,
              style: AppTextStyles.mobileXsRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A field the form shows but does not change (the project when editing).
class _ReadOnlyField extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.mobileBaseSemiBold.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        value,
        key: const Key('api-task-project-fixed'),
        style: AppTextStyles.mobileBaseRegular.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );
}
