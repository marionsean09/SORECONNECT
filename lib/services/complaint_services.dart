import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ComplaintService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // Firestore documents are capped at 1 MiB total, so the encoded
  // image (which is ~33% larger than the raw bytes) is kept well
  // under that limit to leave room for the rest of the fields.
  static const int _maxImageBytes = 500 * 1024;

  // ============================================================
  // ENCODE COMPLAINT IMAGE
  // Stores the photo directly on the complaint document as base64
  // instead of Firebase Storage, since Storage requires the Blaze plan.
  // ============================================================

  Future<Map<String, String>> _encodeComplaintImage(
    XFile image,
  ) async {
    final bytes = await image.readAsBytes();

    if (bytes.length > _maxImageBytes) {
      throw Exception(
        'Photo is too large (${(bytes.length / 1024).round()} KB). '
        'Please choose a smaller photo (under '
        '${(_maxImageBytes / 1024).round()} KB).',
      );
    }

    return {
      'imageBase64': base64Encode(bytes),
      'imageMimeType': image.mimeType ?? 'image/jpeg',
    };
  }

  // ============================================================
  // GENERATE TICKET NUMBER
  // Uses a counter document + transaction so ticket numbers are
  // sequential and never collide across concurrent submissions.
  // ============================================================

  Future<String> _generateTicketNumber() async {
    final counterRef =
        _firestore.collection('counters').doc('complaints');

    final nextCount = await _firestore.runTransaction<int>((
      transaction,
    ) async {
      final snapshot = await transaction.get(counterRef);

      final current =
          (snapshot.data()?['count'] as num?)?.toInt() ?? 0;

      final next = current + 1;

      transaction.set(
        counterRef,
        {'count': next},
        SetOptions(merge: true),
      );

      return next;
    });

    return 'CMP-${nextCount.toString().padLeft(6, '0')}';
  }

  // ============================================================
  // SUBMIT COMPLAINT
  // ============================================================

  Future<void> submitComplaint({
    required String subject,
    required String complaintType,
    required String description,
    XFile? image,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception("User not logged in.");
      }

      // ==========================================================
      // GET CURRENT CONSUMER INFORMATION
      // ==========================================================

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception(
          "Consumer record not found.",
        );
      }

      final userData =
          userDoc.data() ??
              <String, dynamic>{};

      // ==========================================================
      // GET CONSUMER LOCATION
      // ==========================================================

      final barangay =
          userData['barangay'] ??
          userData['baranggay'] ??
          userData['barangayName'] ??
          userData['brgy'] ??
          '';

      final municipality =
          userData['municipality'] ??
          userData['municipalityName'] ??
          userData['city'] ??
          userData['cityName'] ??
          '';

      final province =
          userData['province'] ??
          'Sorsogon';

      final address =
          userData['address'] ??
          userData['fullAddress'] ??
          userData['completeAddress'] ??
          '';

      // ==========================================================
      // CREATE COMPLAINT DOCUMENT
      // ==========================================================

      final complaintRef =
          _firestore
              .collection('complaints')
              .doc();

      // ==========================================================
      // ENCODE ATTACHED IMAGE (IF ANY)
      // ==========================================================

      String? imageBase64;
      String? imageMimeType;

      if (image != null) {
        final encoded = await _encodeComplaintImage(image);
        imageBase64 = encoded['imageBase64'];
        imageMimeType = encoded['imageMimeType'];
      }

      // ==========================================================
      // TICKET NUMBER
      // ==========================================================

      final ticketNumber = await _generateTicketNumber();

      await complaintRef.set({
        // ========================================================
        // COMPLAINT IDENTIFICATION
        // ========================================================

        'complaintId':
            complaintRef.id,

        'ticketNumber':
            ticketNumber,

        // ========================================================
        // CONSUMER INFORMATION
        // ========================================================

        'consumerId':
            user.uid,

        'consumerName':
            userData['full_name'] ??
                userData['fullName'] ??
                '',

        'accountNumber':
            userData['accountNumber'] ??
                userData['account_number'] ??
                '',

        // ========================================================
        // CONSUMER LOCATION
        // ========================================================

        'barangay':
            barangay,

        'municipality':
            municipality,

        'province':
            province,

        'address':
            address,

        // ========================================================
        // COMPLAINT INFORMATION
        // ========================================================

        'subject':
            subject,

        'complaintType':
            complaintType,

        'description':
            description,

        'imageBase64':
            imageBase64,

        'imageMimeType':
            imageMimeType,

        // ========================================================
        // DEFAULT STATUS
        // ========================================================

        'status':
            'Pending',

        // ========================================================
        // COMPLAINT DATE
        // ========================================================

        'createdAt':
            FieldValue.serverTimestamp(),

        'dateSubmitted':
            FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception(
        "Failed to submit complaint: $e",
      );
    }
  }

  // ============================================================
  // GET ALL COMPLAINTS
  // ============================================================

  Stream<QuerySnapshot> getAllComplaints() {
    return _firestore
        .collection('complaints')
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots();
  }

  // ============================================================
  // GET COMPLAINTS OF CURRENT CONSUMER
  // ============================================================

  Stream<QuerySnapshot> getConsumerComplaints(
    String consumerId,
  ) {
    return _firestore
        .collection('complaints')
        .where(
          'consumerId',
          isEqualTo: consumerId,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots();
  }

  // ============================================================
  // UPDATE COMPLAINT STATUS
  // ============================================================

  Future<void> updateComplaintStatus({
    required String complaintId,
    required String status,
  }) async {
    try {
      final user =
          _auth.currentUser;

      await _firestore
          .collection('complaints')
          .doc(complaintId)
          .update({
        'status':
            status,

        'statusUpdatedBy':
            user?.email ??
                'Staff',

        'statusUpdatedAt':
            FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception(
        "Failed to update complaint status: $e",
      );
    }
  }

  // ============================================================
  // CANCEL COMPLAINT (CONSUMER)
  // Cancelling permanently deletes the complaint, along with its
  // reply thread, instead of just marking it as cancelled.
  // ============================================================

  Future<void> cancelComplaint(
    String complaintId,
  ) async {
    try {
      final complaintRef =
          _firestore.collection('complaints').doc(complaintId);

      final repliesSnapshot =
          await complaintRef.collection('replies').get();

      final batch = _firestore.batch();

      for (final replyDoc in repliesSnapshot.docs) {
        batch.delete(replyDoc.reference);
      }

      batch.delete(complaintRef);

      await batch.commit();
    } catch (e) {
      throw Exception(
        "Failed to cancel complaint: $e",
      );
    }
  }

  // ============================================================
  // COMPLAINT REPLY THREAD
  // Consumer, teller, and director can all post replies to the
  // same complaint, in order, as an ongoing conversation.
  // ============================================================

  Stream<QuerySnapshot> getComplaintReplies(
    String complaintId,
  ) {
    return _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('replies')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> sendReply({
    required String complaintId,
    required String message,
    required String senderRole,
    required String senderName,
  }) async {
    final trimmed = message.trim();

    if (trimmed.isEmpty) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in.");
    }

    try {
      final replyRef = _firestore
          .collection('complaints')
          .doc(complaintId)
          .collection('replies')
          .doc();

      await replyRef.set({
        'replyId': replyRef.id,
        'senderId': user.uid,
        'senderName': senderName,
        'senderRole': senderRole,
        'message': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('complaints')
          .doc(complaintId)
          .update({
        'lastReplyAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception(
        "Failed to send reply: $e",
      );
    }
  }
}