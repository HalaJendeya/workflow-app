import 'package:flutter/material.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Honest placeholder for a route whose Figma design has not been inspected.
/// Replaced screen-by-screen as designs become available; never styled to
/// look like a finished screen.
class DesignPendingScreen extends StatelessWidget {
  const new({required this.routeName, super.key});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.designPendingTitle,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.designPendingBody, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                Text(routeName, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
