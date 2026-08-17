import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ComplaintService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        throw Exception("Consumer record not found.");
      }

      final userData = userDoc.data()!;

      final complaintRef =
          _firestore.collection('complaints').doc();

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

        'status': 'Pending',

        'response': '',

        'createdAt':
            FieldValue.serverTimestamp(),
        'dateSubmitted':
            FieldValue.serverTimestamp(),

        'respondedAt': null,
      });
    } catch (e) {
      throw Exception("Failed to submit complaint: $e");
    }
  }

  Stream<QuerySnapshot> getAllComplaints() {
    return _firestore
        .collection('complaints')
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots();
  }

  Stream<QuerySnapshot> getConsumerComplaints(
      String consumerId) {
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
  
  Future<void> updateComplaintStatus({
    required String complaintId,
    required String status,
    required String response,
  }) async {
    await _firestore
        .collection('complaints')
        .doc(complaintId)
        .update({
      'status': status,
      'response': response,
      'respondedAt':
          FieldValue.serverTimestamp(),
    });
  }
}