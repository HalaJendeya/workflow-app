import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workflow_app/app/providers.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/async_view.dart';
import 'package:workflow_app/core/widgets/relative_time.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/notifications/application/notifications_controller.dart';
import 'package:workflow_app/features/notifications/data/notifications_repository.dart';
import 'package:workflow_app/features/notifications/domain/app_notification.dart';
import 'package:workflow_app/features/profile/data/profile_repository.dart';
import 'package:workflow_app/features/shell/workspace_header.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Notification pills in the Overview card. The API exposes a `category`
/// field and query parameter but does not document its values, so the
/// mapping below is provisional (see the backend gap report).
enum NotificationPill { all, mentions, projects }

const Map<NotificationPill, String> _pillCategoryHints = {
  NotificationPill.mentions: 'mention',
  NotificationPill.projects: 'project',
};

final NotifierProvider<_PillController, NotificationPill>
_notificationPillProvider =
    NotifierProvider.autoDispose<_PillController, NotificationPill>(
      _PillController.new,
    );

class _PillController extends Notifier<NotificationPill> {
  @override
  NotificationPill build() => NotificationPill.all;

  // A named method reads better than a setter at call sites.
  // ignore: use_setters_to_change_properties
  void select(NotificationPill p) => state = p;
}

final NotifierProvider<_SearchController, String> _searchProvider =
    NotifierProvider.autoDispose<_SearchController, String>(
      _SearchController.new,
    );

class _SearchController extends Notifier<String> {
  @override
  String build() => '';

  // A named method reads better than a setter at call sites.
  // ignore: use_setters_to_change_properties
  void set(String q) => state = q;
}

/// Figma "Overview · Welcome back" — client 534:30390, employee 729:21065.
class OverviewScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portal =
        ref.watch(sessionControllerProvider).value?.portal ?? Portal.client;
    return ColoredBox(
      color: AppColors.appBackground,
      child: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(profileProvider)
            ..invalidate(notificationsControllerProvider);
          await ref.read(notificationsControllerProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Masthead(portal: portal)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                140,
              ),
              sliver: SliverList.list(
                children: const [
                  _TasksCard(),
                  SizedBox(height: AppSpacing.lg),
                  _NotificationsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Masthead extends ConsumerWidget {
  const new({required this.portal});

  final Portal portal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider).value;
    const white = AppColors.white;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat('EEEE, MMMM d', locale).format(DateTime.now());

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadii.masthead),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/masthead_sky.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkspaceHeader(
                  onBellTap: () => _showNotificationOptions(context, ref),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.overviewBreadcrumb,
                  style: AppTextStyles.mobileXsMedium.copyWith(color: white),
                ),
                const SizedBox(height: 6),
                Text(
                  profile == null
                      ? l10n.welcomeBack
                      : l10n.welcomeBackName(profile.displayName),
                  style: AppTextStyles.mobile5xlBold.copyWith(color: white),
                ),
                const SizedBox(height: 6),
                Text(
                  date.toUpperCase(),
                  style: AppTextStyles.mobileBaseRegular.copyWith(color: white),
                ),
                const SizedBox(height: 20),
                const _SearchField(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const SvgIcon(AppIcon.search, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('overview-search'),
              onChanged: ref.read(_searchProvider.notifier).set,
              style: AppTextStyles.mobileBaseRegular.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: l10n.searchHint,
                hintStyle: AppTextStyles.mobileBaseRegular.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.notificationStatusTitle,
            onPressed: () => _showNotificationOptions(context, ref),
            icon: const SvgIcon(AppIcon.sliders, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: read-state filter (API `status`) and mark-all-read.
Future<void> _showNotificationOptions(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final l10n = AppLocalizations.of(context);
          final current = ref.watch(notificationFilterProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.notificationStatusTitle,
                    style: AppTextStyles.mobileLgSemiBold.copyWith(
                      color: AppColors.neutral900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final f in NotificationFilter.values)
                        WfFilterPill(
                          label: switch (f) {
                            NotificationFilter.all => l10n.filterAll,
                            NotificationFilter.unread => l10n.filterUnread,
                            NotificationFilter.read => l10n.filterRead,
                          },
                          selected: f == current,
                          onTap: () => ref
                              .read(notificationFilterProvider.notifier)
                              .select(f),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  WfPrimaryButton(
                    label: l10n.markAllRead,
                    height: 48,
                    textStyle: AppTextStyles.mobileBaseSemiBold,
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        await ref
                            .read(notificationsControllerProvider.notifier)
                            .markAllRead();
                      } on Object catch (e) {
                        if (context.mounted) _snack(context, e);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

void _snack(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context).errorUnknown)),
  );
}

class _CardTitle extends StatelessWidget {
  const new(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.mobile2xlSemiBold.copyWith(
      color: AppColors.neutral900,
    ),
  );
}

/// "Tasks" content card. No task endpoint exists for clients and the
/// employee task list has no documented item fields, so in API mode the card
/// says so instead of showing invented data.
class _TasksCard extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends ConsumerState<_TasksCard> {
  int _pill = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMock = ref.watch(appConfigProvider).isMock;
    final pills = [
      l10n.tasksFilterProjects(isMock ? 1 : 0),
      l10n.tasksFilterMeetings,
      l10n.tasksFilterGeneral,
    ];
    return WfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(l10n.tasksTitle),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < pills.length; i++)
                WfFilterPill(
                  label: pills[i],
                  selected: i == _pill,
                  onTap: () => setState(() => _pill = i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isMock && _pill == 0)
            const _RecordCard(
              title: 'Solve meetings problem',
              meta: 'TMS Development · In Sprint 24 • Due today',
              status: 'Developer Resumed',
            )
          else
            _InlineNotice(
              text: isMock ? l10n.emptyState : l10n.featureUnavailable,
            ),
          const SizedBox(height: AppSpacing.md),
          // Personal micro-tasks have no endpoint; the action stays visible
          // but disabled rather than pretending to save anything.
          WfPrimaryButton(
            label: l10n.addMicroTask,
            height: 48,
            color: AppColors.primaryStrong,
            textStyle: AppTextStyles.mobileBaseSemiBold,
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final inbox = ref.watch(notificationsControllerProvider);
    final pill = ref.watch(_notificationPillProvider);
    final query = ref.watch(_searchProvider).trim().toLowerCase();
    final total = inbox.value?.total ?? 0;

    bool matches(AppNotification n) {
      final hint = _pillCategoryHints[pill];
      if (hint != null &&
          !(n.category ?? n.type ?? '').toLowerCase().contains(hint)) {
        return false;
      }
      if (query.isEmpty) return true;
      return '${n.title} ${n.message}'.toLowerCase().contains(query);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(l10n.notificationsTitle),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final p in NotificationPill.values)
                WfFilterPill(
                  label: switch (p) {
                    NotificationPill.all => l10n.notificationsFilterAll(total),
                    NotificationPill.mentions =>
                      l10n.notificationsFilterMentions,
                    NotificationPill.projects =>
                      l10n.notificationsFilterProjects,
                  },
                  selected: p == pill,
                  onTap: () =>
                      ref.read(_notificationPillProvider.notifier).select(p),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AsyncView<NotificationInbox>(
            value: inbox,
            onRetry: () => ref.invalidate(notificationsControllerProvider),
            builder: (data) {
              final items = data.items.where(matches).toList();
              if (items.isEmpty) {
                return _InlineNotice(
                  text: data.items.isEmpty
                      ? l10n.notificationsEmpty
                      : l10n.noResults,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final n in items) ...[
                    _RecordCard(
                      title: n.title ?? '',
                      meta: n.createdAt == null
                          ? null
                          : relativeTime(l10n, n.createdAt!),
                      body: n.message,
                      unread: !n.isRead,
                      onTap: n.isRead
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(
                                      notificationsControllerProvider.notifier,
                                    )
                                    .markRead(n.id);
                              } on Object catch (e) {
                                if (context.mounted) _snack(context, e);
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "Record card": 16 px padding, 20 px radius, title 16 SemiBold, meta 14
/// secondary, optional body 14 primary and status chip.
class _RecordCard extends StatelessWidget {
  const new({
    required this.title,
    this.meta,
    this.body,
    this.status,
    this.unread = false,
    this.onTap,
  });

  final String title;
  final String? meta;
  final String? body;
  final String? status;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => WfCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mobileLgSemiBold.copyWith(
                  color: AppColors.neutral900,
                ),
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsetsDirectional.only(start: 8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        if (meta != null) ...[
          const SizedBox(height: 5),
          Text(
            meta!,
            style: AppTextStyles.mobileBaseRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (body != null && body!.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            body!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.mobileBaseRegular.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
        if (status != null) ...[
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: WfStatusChip(label: status!),
          ),
        ],
        // The Figma record card ends with two empty 12 px paragraphs.
        const SizedBox(height: 44),
      ],
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  const new({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.pageContent,
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: Text(
      text,
      style: AppTextStyles.mobileBaseRegular.copyWith(
        color: AppColors.textSecondary,
      ),
    ),
  );
}
