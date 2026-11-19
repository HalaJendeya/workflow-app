import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/files/csv_export.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// "Export CSV" chip beside a list's filters. It downloads what the list
/// currently shows (the same filters, every page) from the server's export
/// route and offers to save it. One request per tap; a second tap while
/// one is on its way does nothing.
class ExportCsvChip extends ConsumerStatefulWidget {
  const new({required this.download, this.label, super.key});

  /// Fetches the file with the list's current filters.
  final Future<CsvFile> Function() download;

  /// The chip's text where the screen's Figma frame names it otherwise
  /// (client finance: "Export Report"); "Export CSV" by default.
  final String? label;

  @override
  ConsumerState<ExportCsvChip> createState() => _ExportCsvChipState();
}

class _ExportCsvChipState extends ConsumerState<ExportCsvChip> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    setState(() => _busy = true);
    try {
      final file = await widget.download();
      final saved = await ref.read(csvSaverProvider)(file);
      if (saved) say(l10n.exportSaved(file.fileName));
    } on ApiException catch (e) {
      // The exports' only documented 422 is "Too many rows to export"
      // (over 10 000): say how to fix it instead of pointing at form
      // fields the list does not have.
      say(
        l10n.exportFailed(
          e.kind == ApiFailureKind.validation
              ? l10n.exportTooManyRows
              : localizedError(l10n, e),
        ),
      );
    } on Object catch (e) {
      say(l10n.exportFailed(localizedError(l10n, e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = AppColors.textSecondary;
    final label = widget.label ?? l10n.exportCsv;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ModuleColors.chipBorder),
        ),
        child: InkWell(
          key: const Key('export-csv'),
          borderRadius: BorderRadius.circular(12),
          onTap: _busy ? null : _export,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  SizedBox.square(
                    key: const Key('export-csv-busy'),
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(Icons.file_download_outlined, size: 16, color: color),
                const SizedBox(width: 6),
                ExcludeSemantics(
                  child: Text(
                    label,
                    style: AppTextStyles.mobileXsSemiBold.copyWith(
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
