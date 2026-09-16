import 'dart:convert';

import 'package:image_picker/image_picker.dart';

// Firestore documents are capped at 1 MiB total, so the encoded
// image (which is ~33% larger than the raw bytes) is kept well
// under that limit to leave room for the rest of the document's
// fields. Shared by complaints and announcements.
const int maxEncodableImageBytes = 500 * 1024;

class EncodedImage {
  const EncodedImage({
    required this.base64,
    required this.mimeType,
  });

  final String base64;
  final String mimeType;
}

Future<EncodedImage> encodeImageToBase64(XFile image) async {
  final bytes = await image.readAsBytes();

  if (bytes.length > maxEncodableImageBytes) {
    throw Exception(
      'Photo is too large (${(bytes.length / 1024).round()} KB). '
      'Please choose a smaller photo (under '
      '${(maxEncodableImageBytes / 1024).round()} KB).',
    );
  }

  return EncodedImage(
    base64: base64Encode(bytes),
    mimeType: image.mimeType ?? 'image/jpeg',
  );
}
