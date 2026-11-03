import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/data/local_collection.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

enum JoinStatus { available, pending }

/// Presentation model for "Available Companies" cards (673:14300).
class CompanyCardData implements Identified {
  const new({
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

const _info50 = Color(0xFFE6F6FE);
const _warning50 = Color(0xFFFFFDEB);
const _success50 = Color(0xFFEDF7EE);

final companiesProvider =
    NotifierProvider<LocalCollection<CompanyCardData>, List<CompanyCardData>>(
      () => LocalCollection<CompanyCardData>(
        () => const [
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
    final items = ref
        .watch(companiesProvider)
        .where((c) => '${c.name} ${c.domain}'.toLowerCase().contains(q))
        .toList();
    return ModulePage(
      title: l10n.companiesTitle,
      description: l10n.companiesDescription,
      onSearch: (v) => setState(() => _query = v),
      children: [
        if (!demo) const BackendPendingNotice(),
        if (items.isEmpty)
          EmptyNotice(text: l10n.noRecords)
        else
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 14) / 2;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final company in items)
                    SizedBox(width: w, child: _CompanyCard(company)),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _CompanyCard extends ConsumerWidget {
  const new(this.company);

  final CompanyCardData company;

  static const _jakarta = 'PlusJakartaSans';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = company.status == JoinStatus.pending;
    return Container(
      key: Key('company-${company.id}'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.white,
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
          Text(
            company.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _jakarta,
              fontSize: 14,
              height: 17.5 / 14,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            company.domain,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _jakarta,
              fontSize: 11,
              height: 16.5 / 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFFB1B1B1),
            ),
          ),
          const SizedBox(height: 16),
          if (pending)
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
                    decoration: const BoxDecoration(
                      color: AppColors.primaryStrong,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.joinPending,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
                      ref
                          .read(companiesProvider.notifier)
                          .replace(company.withStatus(JoinStatus.pending));
                      showSnack(context, l10n.joinRequestSent(company.name));
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
