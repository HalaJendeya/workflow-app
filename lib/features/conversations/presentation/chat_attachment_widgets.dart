import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/features/conversations/data/chat_attachments.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Picks files for a message: images only when [images] is true. Returns
/// `null` when the person cancels.
typedef AttachmentPicker = Future<List<OutgoingFile>?> Function(
  BuildContext context, {
  bool images,
});

/// The platform file picker. `null` until a picker dependency is approved:
/// the attach buttons then say attachments need one, and no file is ever
/// read or sent. Tests provide a picker to exercise the upload path.
final attachmentPickerProvider = Provider<AttachmentPicker?>((_) => null);

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
/// app; any other type says it cannot be opened here yet (saving or
/// handing a file to another app needs a dependency that is not approved).
Future<void> showAttachmentPreview(BuildContext context, DownloadedFile file) {
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
    body = Text(l10n.attachmentNoPreview, key: const Key('attachment-other'));
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
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(MaterialLocalizations.of(dialog).closeButtonLabel),
        ),
      ],
    ),
  );
}
