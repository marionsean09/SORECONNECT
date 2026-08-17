import 'package:cloud_firestore/cloud_firestore.dart';

class RateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String rateDocId = 'current_rate';

  Future<double> getCurrentRate() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('settings')
          .doc(rateDocId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
return (data['ratePerKwh'] as num?)?.toDouble() ?? 12.0;
      } else {
        await _initializeDefaultRate();
        return 12.0;
      }
    } catch (e) {
      return 12.0;
    }
  }

  Future<void> _initializeDefaultRate() async {
    await _firestore.collection('settings').doc(rateDocId).set({
      'ratePerKwh': 12.0,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': 'system',
    });
  }

  Future<void> updateRate(double newRate, String updatedBy) async {
    if (newRate <= 0) {
      throw Exception('Rate must be greater than 0');
    }
    
    await _firestore.collection('settings').doc(rateDocId).set({
      'ratePerKwh': newRate,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  Stream<double> watchRate() {
    return _firestore
        .collection('settings')
        .doc(rateDocId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return (doc.data() as Map<String, dynamic>)['ratePerKwh'] ?? 12.0;
          }
          return 12.0;
        });
  }
}