import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soreconnect/models/rate_model.dart';

class RateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String rateDocId = 'current_rate';

  Future<RateModel> getCurrentRate() async {
    try {
      final doc =
          await _firestore.collection('settings').doc(rateDocId).get();

      if (doc.exists) {
        return RateModel.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        final defaultRate = RateModel.defaultRate();
        await updateRate(defaultRate, 'system');
        return defaultRate;
      }
    } catch (e) {
      return RateModel.defaultRate();
    }
  }

  Future<void> updateRate(RateModel rate, String updatedBy) async {
    for (final item in RateModel.lineItems) {
      if (rate.valueFor(item.key) < 0) {
        throw Exception('${item.label} rate cannot be negative');
      }
    }

    for (final item in rate.customLineItems) {
      if (item.label.trim().isEmpty) {
        throw Exception('Every custom charge/subsidy needs a label');
      }
      if (item.rate < 0) {
        throw Exception('${item.label} rate cannot be negative');
      }
    }

    await _firestore.collection('settings').doc(rateDocId).set({
      ...rate.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  Stream<RateModel> watchRate() {
    return _firestore
        .collection('settings')
        .doc(rateDocId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return RateModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return RateModel.defaultRate();
    });
  }
}
