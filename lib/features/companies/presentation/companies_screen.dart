import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/async_section.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/companies/data/client_companies_repository.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

enum JoinStatus { available, pending }

/// Presentation model for "Available Companies" cards (673:14300).
class CompanyCardData implements Identified {
  new({
    required this.id,
    required this.name,
    required this.domain,
    required this.icon,
    required this.tint,
    this.status = JoinStatus.available,
  });

  @override
  final String id;
  final String name;
  final String domain;
  final String icon;
  final Color tint;
  final JoinStatus status;

  CompanyCardData withStatus(JoinStatus s) => CompanyCardData(
    id: id,
    name: name,
    domain: domain,
    icon: icon,
    tint: tint,
    status: s,
  );
}

Color get _info50 => AppColors.statusInfoBackground;
Color get _warning50 => ModuleColors.warningBg;
Color get _success50 => ModuleColors.successBg;

final companiesProvider =
    NotifierProvider<LocalCollection<CompanyCardData>, List<CompanyCardData>>(
      () => LocalCollection<CompanyCardData>(
        () => [
          CompanyCardData(
            id: 'c1',
            name: 'Gaza',
            domain: 'gaza.org',
            icon: 'company_building',
            tint: _info50,
            status: JoinStatus.pending,
          ),
          CompanyCardData(
            id: 'c2',
            name: 'Tech Company',
            domain: 'techcorp.com',
            icon: 'company_rocket',
            tint: _info50,
          ),
          CompanyCardData(
            id: 'c3',
            name: 'Ra',
            domain: 'ra.design',
            icon: 'company_compass',
            tint: _warning50,
          ),
          CompanyCardData(
            id: 'c4',
            name: 'Raghad Ayyad',
            domain: 'raghad@ayyad.co',
            icon: 'company_user',
            tint: _info50,
          ),
          CompanyCardData(
            id: 'c5',
            name: 'Zeinab Almudalal',
            domain: 'zeinab@almudalal.com',
            icon: 'company_chart',
            tint: _success50,
          ),
          CompanyCardData(
            id: 'c6',
            name: 'Test Corp',
            domain: 'test@corp.internal',
            icon: 'company_flask',
            tint: _info50,
          ),
        ],
      ),
    );

/// Figma "Available Companies" (673:14300): 2-column grid, 14 px gaps.
class CompaniesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends ConsumerState<CompaniesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demo = ref.watch(demoModeProvider);
    final q = _query.trim().toLowerCase();
    bool matches(CompanyCardData c) =>
        '${c.name} ${c.domain}'.toLowerCase().contains(q);
    return ModulePage(
      title: l10n.companiesTitle,
      description: l10n.companiesDescription,
      onSearch: (v) => setState(() => _query = v),
      children: demo
          ? [_grid(l10n, ref.watch(companiesProvider).where(matches).toList())]
          : [
              // "List My Companies": the account's own companies. There is
              // no directory of companies to join, and the membership
              // status is not part of this route's documented response.
              InfoNotice(
                key: const Key('my-companies-note'),
                text: l10n.myCompaniesNote,
              ),
              AsyncSection(
                value: ref.watch(clientCompaniesProvider),
                onRetry: () => ref.invalidate(clientCompaniesProvider),
                builder: (companies) {
                  if (companies.isEmpty) {
                    return EmptyNotice(
                      key: const Key('no-companies'),
                      text: l10n.noCompaniesYet,
                    );
                  }
                  final byCard = {for (final c in companies) 'api-${c.id}': c};
                  return _grid(
                    l10n,
                    [
                      for (final c in companies)
                        CompanyCardData(
                          id: 'api-${c.id}',
                          name: c.name,
                          domain: c.subtitle ?? '',
                          icon: 'company_building',
                          tint: _info50,
                        ),
                    ].where(matches).toList(),
                    footer: (card) => _SwitchAction(company: byCard[card.id]!),
                  );
                },
              ),
            ],
    );
  }

  Widget _grid(
    AppLocalizations l10n,
    List<CompanyCardData> items, {
    Widget Function(CompanyCardData)? footer,
  }) {
    if (items.isEmpty) return EmptyNotice(text: l10n.noRecords);
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final company in items)
              SizedBox(
                width: w,
                child: _CompanyCard(company, footer: footer?.call(company)),
              ),
          ],
        );
      },
    );
  }
}

class _CompanyCard extends ConsumerWidget {
  const new(this.company, {this.footer});

  final CompanyCardData company;

  /// The action area of an API row (the company switch). Without it the
  /// card shows the demo Join / pending area: API rows have no join
  /// status and nothing they could join.
  final Widget? footer;

  static const _jakarta = 'PlusJakartaSans';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = company.status == JoinStatus.pending;
    return Container(
      key: Key('company-${company.id}'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ModuleColors.sectionDivider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            offset: Offset(0, 4),
            blurRadius: 20,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Color(0x050F172A),
            offset: Offset(0, 2),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: company.tint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: WfSvg(company.icon, size: 24),
          ),
          const SizedBox(height: 12),
          // Two lines on narrow cards ("Tech Company" was cut at 320 px).
          Text(
            company.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _jakarta,
              fontSize: 14,
              height: 17.5 / 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            company.domain,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _jakarta,
              fontSize: 11,
              height: 16.5 / 11,
              fontWeight: FontWeight.w500,
              color: ModuleColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          if (footer case final f?)
            f
          else if (pending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: _info50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primaryStrong,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FitText(
                      l10n.joinPending,
                      minScale: 0.6,
                      style: TextStyle(
                        fontFamily: _jakarta,
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusInfo,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x5906B6D4),
                      offset: Offset(0, 4),
                      blurRadius: 7,
                    ),
                  ],
                ),
                child: Material(
                  color: AppColors.primaryStrong,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: Key('join-${company.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final applied = ref
                          .read(companiesProvider.notifier)
                          .replace(company.withStatus(JoinStatus.pending));
                      // Only report "sent" when the demo list took it.
                      if (applied) {
                        showSnack(context, l10n.joinRequestSent(company.name));
                      } else {
                        showLocalOutcome(context, applied: false);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        l10n.joinRequest,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: _jakarta,
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The pill of the card's action area (Figma: "pandding").
class _CardPill extends StatelessWidget {
  const new({
    required this.label,
    required this.background,
    required this.foreground,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FitText(
            label,
            minScale: 0.6,
            style: TextStyle(
              fontFamily: _CompanyCard._jakarta,
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The card's filled button (Figma: "Join Request"); a spinner while
/// [busy], off when [onTap] is null.
class _CardButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onTap,
    required this.buttonKey,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Key buttonKey;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: onTap == null && !busy
          ? AppColors.primaryStrong.withValues(alpha: 0.5)
          : AppColors.primaryStrong,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: busy
              ? const Center(
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  ),
                )
              // Wraps rather than cuts the label on narrow cards.
              : Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _CompanyCard._jakarta,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
        ),
      ),
    ),
  );
}

/// The company the client works in (`X-Company`, collection §4): "Active"
/// on that card, "Use this company" on the others. Switching asks first,
/// then checks the company with the server; a refusal changes nothing.
/// One switch at a time.
class _SwitchAction extends ConsumerWidget {
  const new({required this.company});

  final ClientCompany company;

  Future<void> _switch(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.companySwitchTitle),
        content: Text(l10n.companySwitchBody(company.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('company-switch-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.companySwitchConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final switched = await ref
          .read(companySwitchProvider.notifier)
          .switchTo(company.id);
      if (switched && context.mounted) {
        showSnack(context, l10n.companySwitched(company.name));
      }
    } on ApiException catch (e) {
      if (!context.mounted) return;
      showSnack(
        context,
        e.kind == ApiFailureKind.forbidden
            ? l10n.companySwitchRefused(company.name)
            : l10n.companySwitchFailed(localizedError(l10n, e)),
      );
    } on Object catch (e) {
      if (context.mounted) {
        showSnack(context, l10n.companySwitchFailed(localizedError(l10n, e)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(
      sessionControllerProvider.select((s) => s.value?.companyId),
    );
    final switching = ref.watch(companySwitchProvider);
    if (active == company.id) {
      return _CardPill(
        key: Key('company-active-${company.id}'),
        label: l10n.companyActive,
        background: _success50,
        foreground: ModuleColors.successFg,
      );
    }
    return _CardButton(
      buttonKey: Key('company-use-${company.id}'),
      label: l10n.companyUse,
      busy: switching == company.id,
      onTap: switching == null ? () => _switch(context, ref) : null,
    );
  }
}
