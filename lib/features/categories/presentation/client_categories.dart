import 'package:flutter/material.dart';
import 'package:workflow_app/app/routes.dart';
import 'package:workflow_app/core/widgets/design_pending_screen.dart';
import 'package:workflow_app/features/categories/presentation/categories_screen.dart';
import 'package:workflow_app/features/finance/presentation/invoices_screen.dart';
import 'package:workflow_app/features/finance/presentation/payments_screen.dart';
import 'package:workflow_app/features/projects/presentation/projects_screen.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Client "More" tab: Figma Categories (666:69807).
class ClientCategoriesScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void push(BuildContext c, Widget page) =>
        Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => page));
    void pushRoot(BuildContext c, Widget page) => Navigator.of(
      c,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return CategoriesScreen(
      sections: [
        CategorySection(
          title: l10n.catOverview,
          subtitle: l10n.catOverviewBody,
          icon: 'cat_sec_overview',
          pillIcon: 'cat_pill_overview',
          items: [
            CategoryItem(
              label: l10n.catDashboard,
              icon: 'cat_item_dashboard',
              onOpen: (c) => push(
                c,
                const DesignPendingScreen(routeName: 'client/dashboard'),
              ),
            ),
          ],
        ),
        CategorySection(
          title: l10n.catClients,
          subtitle: l10n.catClientsBody,
          icon: 'cat_sec_clients',
          pillIcon: 'cat_pill_clients',
          items: [
            CategoryItem(
              label: l10n.navCompanies,
              icon: 'cat_item_companies',
              onOpen: (c) => goTab(c, Routes.clientCompanies),
            ),
          ],
        ),
        CategorySection(
          title: l10n.catFinance,
          subtitle: l10n.catFinanceBody,
          icon: 'cat_sec_finance',
          pillIcon: 'cat_sec_finance',
          items: [
            CategoryItem(
              label: l10n.navInvoices,
              icon: 'cat_item_invoices',
              onOpen: (c) => goTab(c, Routes.clientInvoices),
            ),
            CategoryItem(
              label: l10n.catPayments,
              icon: 'cat_item_payments',
              onOpen: (c) => push(c, const PaymentsScreen()),
            ),
          ],
        ),
        CategorySection(
          title: l10n.catWork,
          subtitle: l10n.catWorkBody,
          icon: 'cat_sec_work',
          pillIcon: 'cat_sec_work',
          items: [
            CategoryItem(
              label: l10n.navProjects,
              icon: 'cat_item_projects',
              onOpen: (c) => push(c, const ProjectsScreen()),
            ),
          ],
        ),
        CategorySection(
          title: l10n.catCommunication,
          subtitle: l10n.catCommunicationBody,
          icon: 'cat_sec_communication',
          pillIcon: 'cat_sec_communication',
          items: [
            CategoryItem(
              label: l10n.catConversations,
              icon: 'cat_item_conversations',
              onOpen: (c) => goTab(c, Routes.clientChat),
            ),
            CategoryItem(
              label: l10n.catMeetings,
              icon: 'cat_item_meetings',
              onOpen: (c) => push(
                c,
                const DesignPendingScreen(routeName: 'client/meetings'),
              ),
            ),
          ],
        ),
      ],
      createActions: [
        CreateAction(
          l10n.createInvoice,
          (c) => pushRoot(c, const InvoiceFormScreen()),
        ),
        CreateAction(
          l10n.addProject,
          (c) => pushRoot(c, const ProjectFormScreen()),
        ),
        CreateAction(
          l10n.addPayment,
          (c) => pushRoot(c, const PaymentFormScreen()),
        ),
      ],
    );
  }
}
