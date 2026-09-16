import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:soreconnect/services/image_encoding.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> postAnnouncement({
    required String title,
    required String content,
    required String type,
    required String typeLabel,
    required String? postedBy,
    required String coverageType,
    List<String> municipalities = const [],
    List<String> barangays = const [],
    required String province,
    required String district,
    String? coveredArea,
    DateTime? scheduledDate,
    DateTime? scheduledEndDate,
    String? startTime,
    String? endTime,
    DateTime? disconnectionDate,
    String? disconnectionTime,
    DateTime? readingDate,
    required String status,
    XFile? image,
  }) async {
    // ==============================================================
    // ENCODE ATTACHED IMAGE (IF ANY)
    // Stored directly on the announcement document as base64,
    // the same approach used for complaint photos.
    // ==============================================================

    String? imageBase64;
    String? imageMimeType;

    if (image != null) {
      final encoded = await encodeImageToBase64(image);
      imageBase64 = encoded.base64;
      imageMimeType = encoded.mimeType;
    }

    await _firestore
        .collection('announcements')
        .add({
      // ============================================================
      // BASIC ANNOUNCEMENT INFORMATION
      // ============================================================

      'title': title,

      'content': content,

      'type': type,

      'typeLabel': typeLabel,

      'postedBy': postedBy,

      'datePosted':
          FieldValue.serverTimestamp(),

      'imageBase64': imageBase64,

      'imageMimeType': imageMimeType,

      // ============================================================
      // COVERAGE
      // ============================================================

      'coverageType': coverageType,

      'municipalities': municipalities,

      'barangays': barangays,

      'province': province,

      'district': district,

      'coveredArea': coveredArea,

      // ============================================================
      // POWER INTERRUPTION
      // ============================================================

      'scheduledDate':
          scheduledDate != null
              ? Timestamp.fromDate(
                  scheduledDate,
                )
              : null,

      'scheduledEndDate':
          scheduledEndDate != null
              ? Timestamp.fromDate(
                  scheduledEndDate,
                )
              : null,

      'startTime': startTime,

      'endTime': endTime,

      // ============================================================
      // DISCONNECTION
      // ============================================================

      'disconnectionDate':
          disconnectionDate != null
              ? Timestamp.fromDate(
                  disconnectionDate,
                )
              : null,

      'disconnectionTime':
          disconnectionTime,

      // ============================================================
      // METER READING
      // ============================================================

      'readingDate':
          readingDate != null
              ? Timestamp.fromDate(
                  readingDate,
                )
              : null,

      // ============================================================
      // STATUS
      // ============================================================

      'status': status,
    });
  }
}