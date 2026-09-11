import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ComplaintService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // SUBMIT COMPLAINT
  // ============================================================

  Future<void> submitComplaint({
    required String subject,
    required String complaintType,
    required String description,
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

      await complaintRef.set({
        // ========================================================
        // COMPLAINT IDENTIFICATION
        // ========================================================

        'complaintId':
            complaintRef.id,

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

        // ========================================================
        // DEFAULT STATUS
        // ========================================================

        'status':
            'Pending',

        // ========================================================
        // TELLER RESPONSE
        // ========================================================

        'response':
            '',

        // ========================================================
        // TELLER INFORMATION
        // ========================================================

        'respondedBy':
            '',

        'respondedAt':
            null,

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
  // UPDATE COMPLAINT STATUS AND RESPONSE
  // ============================================================

  Future<void> updateComplaintStatus({
    required String complaintId,
    required String status,
    required String response,
  }) async {
    try {
      final user =
          _auth.currentUser;

      await _firestore
          .collection('complaints')
          .doc(complaintId)
          .update({
        // ========================================================
        // STATUS
        // ========================================================

        'status':
            status,

        // ========================================================
        // TELLER RESPONSE
        // ========================================================

        'response':
            response,

        // ========================================================
        // WHO RESPONDED
        // ========================================================

        'respondedBy':
            user?.email ??
                'Teller',

        // ========================================================
        // RESPONSE DATE
        // ========================================================

        'respondedAt':
            FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception(
        "Failed to update complaint: $e",
      );
    }
  }
}