import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/conversations/data/chat_attachments.dart';
import 'package:workflow_app/features/conversations/data/file_picker_attachments.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Picks files for a message: images only when [images] is true. Returns
/// `null` when the person cancels.
typedef AttachmentPicker = Future<List<OutgoingFile>?> Function(
  BuildContext context, {
  bool images,
});

/// The platform file picker (`file_picker`). Tests replace it; `null`
/// means none is available and the attach buttons say so.
final attachmentPickerProvider = Provider<AttachmentPicker?>(
  (_) => pickAttachments,
);

/// Saves a downloaded attachment through the system save dialog; `false`
/// when the person cancels.
typedef AttachmentSaver = Future<bool> Function(
  DownloadedFile file,
  String fallbackName,
);

final attachmentSaverProvider = Provider<AttachmentSaver>(
  (_) => saveAttachment,
);

/// The message a refused selection shows.
String attachmentProblemText(AppLocalizations l10n, AttachmentProblem p) =>
    switch (p) {
      AttachmentProblem.tooMany => l10n.attachmentTooMany,
      AttachmentProblem.empty => l10n.attachmentEmpty,
      AttachmentProblem.tooLarge => l10n.attachmentTooLarge,
      AttachmentProblem.typeNotAllowed => l10n.attachmentTypeNotAllowed,
    };

/// One attachment in a chat bubble. Received attachments open on tap
/// ([onOpen]); [busy] while their bytes are on the way.
class AttachmentChip extends StatelessWidget {
  const new({required this.label, this.onOpen, this.busy = false, super.key});

  final String label;
  final VoidCallback? onOpen;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: busy ? null : onOpen,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 12, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ModuleColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const WfSvg('chat_attach', size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mobileXsRegular.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a downloaded attachment from memory: images and plain text in the
/// app. Every file — and the only way for a PDF — can be saved through the
/// system save dialog and opened from the Files app; the app keeps no copy.
Future<void> showAttachmentPreview(
  BuildContext context,
  DownloadedFile file, {
  required AttachmentSaver save,
}) {
  final l10n = AppLocalizations.of(context);
  final mime = file.mime;
  final Widget body;
  if (mime != null && mime.startsWith('image/')) {
    body = InteractiveViewer(
      child: Image.memory(
        file.bytes,
        key: const Key('attachment-image'),
        errorBuilder: (_, _, _) => Text(l10n.attachmentNoPreview),
      ),
    );
  } else if (mime == 'text/plain') {
    final text = utf8.decode(file.bytes, allowMalformed: true);
    body = SingleChildScrollView(
      child: SelectableText(
        text.length > 100000 ? '${text.substring(0, 100000)}…' : text,
        key: const Key('attachment-text'),
      ),
    );
  } else {
    body = Text(
      mime == 'application/pdf'
          ? l10n.attachmentPdfHint
          : l10n.attachmentNoPreview,
      key: const Key('attachment-other'),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(
        file.fileName ?? l10n.attachment,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(width: double.maxFinite, child: body),
      actions: [
        TextButton(
          key: const Key('attachment-save'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              final saved = await save(file, l10n.attachment);
              if (saved) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.attachmentSaved)),
                );
              }
            } on Exception {
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.attachmentSaveFailed)),
              );
            }
          },
          child: Text(l10n.saveToDevice),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(MaterialLocalizations.of(dialog).closeButtonLabel),
        ),
      ],
    ),
  );
}

/// Files chosen for the next message, each removable before sending.
class SelectedFilesTray extends StatelessWidget {
  const new({required this.files, required this.onRemove, super.key});

  final List<OutgoingFile> files;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      key: const Key('selected-files'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < files.length; i++)
          InputChip(
            key: Key('selected-file-$i'),
            avatar: Icon(
              files[i].isImage
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined,
              size: 18,
            ),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(files[i].name, overflow: TextOverflow.ellipsis),
            ),
            deleteButtonTooltipMessage: l10n.removeAttachment(files[i].name),
            onDeleted: () => onRemove(i),
          ),
      ],
    );
  }
}
