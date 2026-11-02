import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Standard loading / error / empty / data states for an [AsyncValue].
class AsyncView<T> extends StatelessWidget {
  const new({
    required this.value,
    required this.builder,
    this.isEmpty,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final bool Function(T data)? isEmpty;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (value) {
      AsyncData(:final value) when isEmpty?.call(value) ?? false => Center(
        child: Text(l10n.emptyState),
      ),
      AsyncData(:final value) => builder(value),
      AsyncError(:final error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localizedError(l10n, error), textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
              ],
            ],
          ),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
