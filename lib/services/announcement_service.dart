import 'package:cloud_firestore/cloud_firestore.dart';

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
    String? municipality,
    String? barangay,
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
  }) async {
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

      // ============================================================
      // COVERAGE
      // ============================================================

      'coverageType': coverageType,

      'municipality': municipality,

      'barangay': barangay,

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