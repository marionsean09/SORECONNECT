import 'package:cloud_firestore/cloud_firestore.dart';

class RateModel {
  final double ratePerKwh;
  final String updatedBy;
  final Timestamp updatedAt;

  RateModel({
    required this.ratePerKwh,
    required this.updatedBy,
    required this.updatedAt,
  });

  factory RateModel.fromMap(Map<String, dynamic> map) {
    return RateModel(
      ratePerKwh: (map['ratePerKwh'] as num?)?.toDouble() ?? 12.0,
      updatedBy: map['updatedBy'] ?? '',
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ratePerKwh': ratePerKwh,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt,
    };
  }
}