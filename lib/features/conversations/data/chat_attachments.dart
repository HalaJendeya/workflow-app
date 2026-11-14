import 'dart:convert';
import 'dart:typed_data';

/// Conversation attachments, `POST …/conversations/{id}/messages`
/// (BE-28): files go under `files[]` only, at most 5 per message, each at
/// most 10 240 KB, of the types the route's `mimetypes` rule allows. The
/// server checks the content, not the name, so the app does too.
abstract final class AttachmentRules {
  static const maxFiles = 5;
  static const int maxBytes = 10240 * 1024;

  /// `mimetypes:image/jpeg,image/png,image/gif,image/webp,application/pdf,
  /// text/plain`.
  static const Set<String> allowed = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/pdf',
    'text/plain',
  };
}

/// A file chosen for sending. [mime] is what the content says it is
/// ([sniffMime]), never the name or the picker's guess alone.
class OutgoingFile {
  new({required this.name, required this.bytes}) : mime = sniffMime(bytes);

  final String name;
  final Uint8List bytes;
  final String? mime;

  bool get isImage => mime?.startsWith('image/') ?? false;
}

enum AttachmentProblem { tooMany, empty, tooLarge, typeNotAllowed }

/// The first rule [files] break, or `null` when the server should accept
/// them. Checked before anything is uploaded, so a refused file never
/// costs a request.
AttachmentProblem? checkAttachments(List<OutgoingFile> files) {
  if (files.length > AttachmentRules.maxFiles) return AttachmentProblem.tooMany;
  for (final f in files) {
    if (f.bytes.isEmpty) return AttachmentProblem.empty;
    if (f.bytes.length > AttachmentRules.maxBytes) {
      return AttachmentProblem.tooLarge;
    }
    if (!AttachmentRules.allowed.contains(f.mime)) {
      return AttachmentProblem.typeNotAllowed;
    }
  }
  return null;
}

/// The MIME type of [bytes] from their signature: JPEG, PNG, GIF, WebP and
/// PDF by magic number; text/plain when the content is valid UTF-8 without
/// control characters. Anything else is `null` (not allowed).
String? sniffMime(Uint8List bytes) {
  bool starts(List<int> sig, [int at = 0]) {
    if (bytes.length < at + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[at + i] != sig[i]) return false;
    }
    return true;
  }

  if (starts(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (starts(ascii.encode('GIF87a')) || starts(ascii.encode('GIF89a'))) {
    return 'image/gif';
  }
  if (starts(ascii.encode('RIFF')) && starts(ascii.encode('WEBP'), 8)) {
    return 'image/webp';
  }
  if (starts(ascii.encode('%PDF-'))) return 'application/pdf';
  if (bytes.isEmpty) return null;
  try {
    final text = utf8.decode(bytes);
    final control = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
    return control.hasMatch(text) ? null : 'text/plain';
  } on FormatException {
    return null;
  }
}

/// `type` of the message: `image` when every file is an image, `file`
/// when any is not, `text` without files (the route's `in:text,image,file`).
String messageTypeFor(List<OutgoingFile> files) {
  if (files.isEmpty) return 'text';
  return files.every((f) => f.isImage) ? 'image' : 'file';
}

/// An attachment of a received message. The collection says only that its
/// id (`conversation_attachment_id`) comes from the message's
/// `attachments` array; no other attachment field is documented, so the
/// name and type are learned from the download itself.
class ApiAttachment {
  const new({required this.id});

  /// `null` when the row carries no id: shown, but cannot be opened.
  final int? id;
}

/// A downloaded attachment: the bytes with the type and name the response
/// headers give (`Content-Type`, `Content-Disposition`). Kept in memory
/// only; nothing is written to storage.
class DownloadedFile {
  const new({required this.bytes, this.contentType, this.fileName});

  final Uint8List bytes;
  final String? contentType;
  final String? fileName;

  /// [contentType] when the content agrees with it, else what the content
  /// says: a preview never trusts a header alone.
  String? get mime {
    final sniffed = sniffMime(bytes);
    final declared = contentType?.split(';').first.trim().toLowerCase();
    return declared != null && declared == sniffed ? declared : sniffed;
  }
}

/// The file name of a `Content-Disposition` header (RFC 6266): the UTF-8
/// `filename*` when present, else `filename`. Path parts are dropped.
String? fileNameFromDisposition(String? header) {
  if (header == null) return null;
  String? name;
  final star = RegExp(
    r"filename\*\s*=\s*([^']*)'[^']*'([^;]+)",
    caseSensitive: false,
  ).firstMatch(header);
  final encoded = star?.group(2)?.trim();
  // A stray `%` would make the decoder throw: such a name is ignored.
  if (encoded != null && !RegExp('%(?![0-9A-Fa-f]{2})').hasMatch(encoded)) {
    name = Uri.decodeComponent(encoded);
  }
  if (name == null) {
    final plain = RegExp(
      r'filename\s*=\s*("([^"]*)"|[^;]+)',
      caseSensitive: false,
    ).firstMatch(header);
    name = (plain?.group(2) ?? plain?.group(1))?.trim();
  }
  if (name == null || name.isEmpty) return null;
  final base = name.split(RegExp(r'[\\/]')).last.trim();
  return base.isEmpty ? null : base;
}
