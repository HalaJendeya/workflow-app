import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/finance/domain/finance_models.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/projects/presentation/api_projects_view.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

enum ProjectStatus { inProgress, completed, onHold }

/// Presentation model for "Projects Management" cards (643:34237).
class Project implements Identified {
  const new({
    required this.id,
    required this.name,
    required this.client,
    required this.company,
    required this.budget,
    required this.currency,
    required this.status,
    required this.progress,
    required this.team,
    required this.daysLeft,
    this.notes = '',
  });

  @override
  final String id;
  final String name;
  final String client;
  final String company;
  final double budget;
  final String currency;
  final ProjectStatus status;

  /// 0–100.
  final int progress;
  final List<String> team;
  final int daysLeft;
  final String notes;
}

final projectsProvider =
    NotifierProvider<LocalCollection<Project>, List<Project>>(
      () => LocalCollection<Project>(
        () => const [
          Project(
            id: 'p1',
            name: 'Website Profile',
            client: 'Ahmed Al-Saeed',
            company: 'Gaza',
            budget: 400,
            currency: 'ILS',
            status: ProjectStatus.inProgress,
            progress: 65,
            team: ['Ahmed Al-Saeed', 'Sara Khalil', 'Liam Johnson', 'Amara'],
            daysLeft: 12,
          ),
          Project(
            id: 'p2',
            name: 'Mobile App Developer',
            client: 'Sara Khalil',
            company: 'Tech Company',
            budget: 320,
            currency: 'ILS',
            status: ProjectStatus.inProgress,
            progress: 40,
            team: [
              'Sara Khalil',
              'Ahmed',
              'Liam',
              'Amara',
              'Zeinab',
              'Raghad',
              'Omar',
              'Lina',
              'Taher',
            ],
            daysLeft: 19,
          ),
        ],
      ),
    );

String projectStatusLabel(AppLocalizations l10n, ProjectStatus s) =>
    switch (s) {
      ProjectStatus.inProgress => l10n.statusInProgress,
      ProjectStatus.completed => l10n.statusCompleted,
      ProjectStatus.onHold => l10n.statusOnHold,
    };

BadgeTone projectTone(ProjectStatus s) => switch (s) {
  ProjectStatus.inProgress => BadgeTone.warning,
  ProjectStatus.completed => BadgeTone.success,
  ProjectStatus.onHold => BadgeTone.neutral,
};

/// Figma "Projects Management" (client 643:34237, employee 729:21226).
class ProjectsScreen extends ConsumerStatefulWidget {
  const new({this.canManage = true, super.key});

  /// Shows create/edit/delete affordances (present in both Figma frames).
  final bool canManage;

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _query = '';
  ProjectStatus? _status;
  String? _client;
  bool _cards = true;

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoModeProvider);
    if (!demo) {
      return ApiProjectsView(
        onCreate: widget.canManage ? () => openProjectForm(context) : null,
      );
    }
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(projectsProvider);
    final q = _query.trim().toLowerCase();
    final visible = all.where((p) {
      if (_status != null && p.status != _status) return false;
      if (_client != null && p.client != _client) return false;
      return q.isEmpty ||
          '${p.name} ${p.client} ${p.team.join(' ')}'.toLowerCase().contains(q);
    }).toList();
    final clients = {for (final p in all) p.client}.toList()..sort();
    int n(ProjectStatus s) => all.where((p) => p.status == s).length;

    return ModulePage(
      title: l10n.projectsTitle,
      description: l10n.projectsDescription,
      onSearch: (v) => setState(() => _query = v),
      onCreate: widget.canManage ? () => openProjectForm(context) : null,
      createLabel: l10n.addProject,
      children: [
        MetricCard(
          title: l10n.metricTotalProjects,
          value: count(all.length),
          delta: demo ? '16% ${l10n.vsLastMonth}' : '—',
        ),
        MetricCard(
          title: l10n.statusInProgress,
          value: count(n(ProjectStatus.inProgress)),
          delta: demo ? '12% ${l10n.vsLastMonth}' : '—',
        ),
        MetricCard(
          title: l10n.statusCompleted,
          value: count(n(ProjectStatus.completed)),
          delta: demo ? '4% ${l10n.vsLastMonth}' : '—',
        ),
        WfSearchBox(
          fieldKey: const Key('projects-search'),
          hint: l10n.searchProjectsHint,
          onChanged: (v) => setState(() => _query = v),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChipRow(
              children: [
                DropdownChip<ProjectStatus?>(
                  value: _status,
                  options: const [null, ...ProjectStatus.values],
                  labelOf: (s) => s == null
                      ? l10n.filterAllStatus
                      : projectStatusLabel(l10n, s),
                  onChanged: (s) => setState(() => _status = s),
                ),
                DropdownChip<String?>(
                  value: _client,
                  options: [null, ...clients],
                  labelOf: (c) => c ?? l10n.filterAllClients,
                  onChanged: (c) => setState(() => _client = c),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ChipRow(
              children: [
                FilterChipBox(
                  label: l10n.listView,
                  selected: !_cards,
                  onTap: () => setState(() => _cards = false),
                ),
                FilterChipBox(
                  label: l10n.cardView,
                  selected: _cards,
                  onTap: () => setState(() => _cards = true),
                ),
              ],
            ),
          ],
        ),
        if (visible.isEmpty) EmptyNotice(text: l10n.noRecords),
        for (final p in visible)
          if (_cards)
            _ProjectCard(project: p, canManage: widget.canManage)
          else
            _ProjectRow(project: p),
        if (widget.canManage)
          for (var i = 0; i < 2; i++) const _CreateProjectCard(),
      ],
    );
  }
}

/// Add/edit project. Demo only: neither role has a project write route,
/// so in API mode this explains that instead of opening the form.
Future<void> openProjectForm(BuildContext context, {Project? existing}) =>
    openDemoForm(
      context,
      page: (_) => ProjectFormScreen(existing: existing),
      unavailable: AppLocalizations.of(context).projectCreateUnavailable,
    );

void showProjectDetails(BuildContext context, Project p) {
  final l10n = AppLocalizations.of(context);
  unawaited(
    showRecordDetails(
      context,
      title: p.name,
      status: projectStatusLabel(l10n, p.status),
      tone: projectTone(p.status),
      fields: [
        DetailField(l10n.fieldClient, p.client),
        DetailField(l10n.fieldCompany, p.company),
        DetailField(l10n.fieldBudget, money(p.budget, currency: p.currency)),
        DetailField(l10n.fieldProgress, '${p.progress}%'),
        DetailField(l10n.fieldTeam, p.team.join(', ')),
        DetailField(l10n.fieldTimeline, l10n.daysLeft(p.daysLeft)),
        if (p.notes.isNotEmpty) DetailField(l10n.fieldNotes, p.notes),
      ],
    ),
  );
}

class _ProjectCard extends ConsumerWidget {
  const new({required this.project, required this.canManage});

  final Project project;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = project;
    final fill = p.progress >= 50 ? AppColors.primary : const Color(0xFFE8D636);
    Future<void> delete() async {
      if (await confirmDelete(context, p.name)) {
        final removed = ref.read(projectsProvider.notifier).remove(p.id);
        if (context.mounted) {
          showLocalOutcome(context, applied: removed, deleted: true);
        }
      }
    }

    return ModuleCard(
      key: Key('project-${p.id}'),
      onTap: () => showProjectDetails(context, p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WfAvatar(initials: p.name.characters.first.toUpperCase()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: AppTextStyles.mobileLgSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.fieldClient}: ${p.client}',
                      style: AppTextStyles.mobileXsRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage)
                IconButton(
                  tooltip: l10n.moreActions,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    // Above the employee tab bar, which covered "Delete".
                    useRootNavigator: true,
                    builder: (sheet) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: Text(l10n.edit),
                            onTap: () {
                              Navigator.pop(sheet);
                              unawaited(openProjectForm(context, existing: p));
                            },
                          ),
                          ListTile(
                            title: Text(
                              l10n.delete,
                              style: const TextStyle(
                                color: ModuleColors.dangerFg,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(sheet);
                              unawaited(delete());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  icon: Text(
                    '⋮',
                    style: AppTextStyles.mobileLgSemiBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.fieldBudget,
                      style: AppTextStyles.mobileXsRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(p.budget, currency: p.currency),
                      style: AppTextStyles.mobileBaseSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: projectStatusLabel(l10n, p.status),
                tone: projectTone(p.status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.fieldProgress,
                  style: AppTextStyles.mobileXsRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${p.progress}%',
                style: AppTextStyles.mobileXsSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: p.progress / 100,
              minHeight: 8,
              backgroundColor: AppColors.primary50,
              color: fill,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              WfAvatar(
                initials: p.team.isEmpty
                    ? ''
                    : p.team.first.characters.first.toUpperCase(),
                size: 24,
              ),
              if (p.team.length > 1) ...[
                const SizedBox(width: 6),
                Text(
                  '+${p.team.length - 1}',
                  style: AppTextStyles.mobileXsSemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                l10n.daysLeft(p.daysLeft),
                style: AppTextStyles.mobileXsRegular.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              InkWell(
                onTap: () => showProjectDetails(context, p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    l10n.viewDetails,
                    style: AppTextStyles.mobileXsSemiBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (canManage) ...[
                IconButton(
                  tooltip: l10n.edit,
                  onPressed: () => openProjectForm(context, existing: p),
                  icon: const WfSvg('action_edit'),
                ),
                IconButton(
                  tooltip: l10n.delete,
                  onPressed: delete,
                  icon: const WfSvg('action_delete'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact row for "List view" (the Figma frame only details card view, so
/// list view reuses its tokens in a single line).
class _ProjectRow extends StatelessWidget {
  const new({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ModuleCard(
      onTap: () => showProjectDetails(context, project),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          WfAvatar(initials: project.name.characters.first.toUpperCase()),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              project.name,
              style: AppTextStyles.mobileBaseSemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          StatusBadge(
            label: projectStatusLabel(l10n, project.status),
            tone: projectTone(project.status),
          ),
        ],
      ),
    );
  }
}

class _CreateProjectCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: () => openProjectForm(context),
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '＋ ${l10n.createNewProject}',
                style: AppTextStyles.mobileLgSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.createNewProjectBody,
                style: AppTextStyles.mobileBaseRegular.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadii.card),
    );
    canvas.drawRRect(rrect, Paint()..color = AppColors.white);
    final paint = Paint()
      ..color = ModuleColors.chipBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Figma "add project" (643:34778).
class ProjectFormScreen extends ConsumerStatefulWidget {
  const new({this.existing, super.key});

  final Project? existing;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.name);
  late final _budget = TextEditingController(
    text: widget.existing?.budget.toStringAsFixed(0),
  );
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late String? _company = widget.existing?.company;
  late ProjectStatus? _status = widget.existing?.status;
  late String? _client = widget.existing?.client;
  late String? _currency = widget.existing?.currency ?? 'USD';
  late String? _employee = widget.existing?.team.firstOrNull;

  @override
  void dispose() {
    _title.dispose();
    _budget.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final e = widget.existing;
    final project = Project(
      id: e?.id ?? localId('prj'),
      name: _title.text.trim(),
      client: _client!,
      company: _company!,
      budget: double.parse(_budget.text),
      currency: _currency!,
      status: _status!,
      progress: e?.progress ?? 0,
      team: [?_employee, ...?e?.team.skip(1)],
      daysLeft: e?.daysLeft ?? 30,
      notes: _notes.text.trim(),
    );
    final notifier = ref.read(projectsProvider.notifier);
    final applied = e == null
        ? notifier.add(project)
        : notifier.replace(project);
    showLocalOutcome(context, applied: applied);
    if (!applied) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String id(String s) => s;
    return FormPage(
      title: widget.existing == null ? l10n.addProject : l10n.editProject,
      formKey: _form,
      onSave: _save,
      fields: [
        TextInputField(
          fieldKey: const Key('project-title'),
          label: l10n.fieldProjectTitle,
          controller: _title,
        ),
        TextInputField(
          fieldKey: const Key('project-budget'),
          label: l10n.fieldBudget,
          controller: _budget,
          number: true,
        ),
        SelectField<String>(
          label: l10n.fieldCompany,
          value: _company,
          options: FinanceOptions.companies,
          labelOf: id,
          onChanged: (v) => setState(() => _company = v),
        ),
        SelectField<ProjectStatus>(
          label: l10n.fieldStatus,
          value: _status,
          options: ProjectStatus.values,
          labelOf: (s) => projectStatusLabel(l10n, s),
          onChanged: (v) => setState(() => _status = v),
        ),
        SelectField<String>(
          label: l10n.fieldClient,
          value: _client,
          options: {...FinanceOptions.clients, ?_client}.toList(),
          labelOf: id,
          onChanged: (v) => setState(() => _client = v),
        ),
        SelectField<String>(
          label: l10n.fieldCurrency,
          value: _currency,
          options: FinanceOptions.currencies,
          labelOf: id,
          onChanged: (v) => setState(() => _currency = v),
        ),
        SelectField<String>(
          label: l10n.fieldEmployees,
          value: _employee,
          options: {...FinanceOptions.employees, ?_employee}.toList(),
          labelOf: id,
          required: false,
          onChanged: (v) => setState(() => _employee = v),
        ),
        TextInputField(
          label: l10n.fieldNotes,
          controller: _notes,
          maxLines: 5,
          required: false,
        ),
      ],
    );
  }
}
