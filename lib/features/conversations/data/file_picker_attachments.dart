import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workflow_app/features/conversations/data/chat_attachments.dart';

/// Extensions the system picker offers; the content is still checked
/// ([checkAttachments]) because a name proves nothing.
const pickableExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'txt'];

/// Picks files through the platform picker (Storage Access Framework on
/// Android: no storage permission). Sizes are checked before any file is
/// read, so a 2 GB video never enters memory; the picker's cached copies
/// are deleted once the bytes are read.
Future<List<OutgoingFile>?> pickAttachments(
  BuildContext context, {
  bool images = false,
}) async {
  final picked = await FilePicker.pickFiles(
    type: images ? FileType.image : FileType.custom,
    allowedExtensions: images ? null : pickableExtensions,
  );
  if (picked.isEmpty) return null;
  try {
    if (picked.length > AttachmentRules.maxFiles) {
      throw const AttachmentRejected(AttachmentProblem.tooMany);
    }
    for (final f in picked) {
      final size = await f.length();
      if (size != null && size > AttachmentRules.maxBytes) {
        throw const AttachmentRejected(AttachmentProblem.tooLarge);
      }
    }
    return [
      for (final f in picked)
        OutgoingFile(name: f.name, bytes: await f.readAsBytes()),
    ];
  } finally {
    if (!kIsWeb) await FilePicker.clearTemporaryFiles();
  }
}

/// Saves a downloaded attachment where the person chooses, through the
/// system save dialog (no storage permission, nothing left in the app's
/// own folders). `false` when they cancel.
Future<bool> saveAttachment(DownloadedFile file, String fallbackName) async {
  final uri = await FilePicker.saveFile(
    fileName: file.fileName ?? fallbackName,
    bytes: file.bytes,
    mimeType: file.mime ?? 'application/octet-stream',
  );
  return uri != null;
}

/// One image for the profile picture. Larger than 2048 KB is refused
/// before it is read ([AttachmentRejected] with `tooLarge`).
Future<OutgoingFile?> pickProfileImage() async {
  final picked = await FilePicker.pickFiles(type: FileType.image);
  if (picked.isEmpty) return null;
  try {
    final f = picked.first;
    final size = await f.length();
    if (size != null && size > 2048 * 1024) {
      throw const AttachmentRejected(AttachmentProblem.tooLarge);
    }
    return OutgoingFile(name: f.name, bytes: await f.readAsBytes());
  } finally {
    if (!kIsWeb) await FilePicker.clearTemporaryFiles();
  }
}

/// One file of [extensions] through the platform picker. A file larger
/// than [maxBytes] is refused before it is read ([AttachmentRejected] with
/// `tooLarge`); the content is checked by the caller.
Future<OutgoingFile?> pickOneFile({
  required List<String> extensions,
  required int maxBytes,
}) async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  if (picked.isEmpty) return null;
  try {
    final f = picked.first;
    final size = await f.length();
    if (size != null && size > maxBytes) {
      throw const AttachmentRejected(AttachmentProblem.tooLarge);
    }
    return OutgoingFile(name: f.name, bytes: await f.readAsBytes());
  } finally {
    if (!kIsWeb) await FilePicker.clearTemporaryFiles();
  }
}
