import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ComplaintService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // SUBMIT COMPLAINT
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

      // Get current consumer information
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception(
          "Consumer record not found.",
        );
      }

      final userData = userDoc.data()!;

      final complaintRef =
          _firestore
              .collection('complaints')
              .doc();

      await complaintRef.set({
        'complaintId': complaintRef.id,

        'consumerId': user.uid,

        'consumerName':
            userData['full_name'] ?? '',

        'accountNumber':
            userData['accountNumber'] ?? '',

        'subject': subject,

        'complaintType': complaintType,

        'description': description,

        // DEFAULT STATUS
        'status': 'Pending',

        // TELLER RESPONSE
        'response': '',

        // TELLER INFORMATION
        'respondedBy': '',

        'respondedAt': null,

        // COMPLAINT DATE
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

  // GET ALL COMPLAINTS
  Stream<QuerySnapshot> getAllComplaints() {
    return _firestore
        .collection('complaints')
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots();
  }

  // GET COMPLAINTS OF CURRENT CONSUMER
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

  // UPDATE COMPLAINT STATUS AND RESPONSE
  Future<void> updateComplaintStatus({
    required String complaintId,
    required String status,
    required String response,
  }) async {
    try {
      final user = _auth.currentUser;

      await _firestore
          .collection('complaints')
          .doc(complaintId)
          .update({
        // STATUS:
        // Pending
        // In Progress
        // Resolved
        'status': status,

        // TELLER RESPONSE
        'response': response,

        // WHO RESPONDED
        'respondedBy':
            user?.email ?? 'Teller',

        // RESPONSE DATE
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