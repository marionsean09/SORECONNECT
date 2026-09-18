import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soreconnect/utils/bill_calculator.dart';

class MeterReadingModel {
  final String readingId;
  final String consumerId;
  final String consumerName;
  final String accountNumber;

  final double previousReading;
  final double currentReading;
  final double consumption;

  final double ratePerKwh;
  final double computedAmount;

  // Itemized SORECO-style breakdown. Null for readings recorded
  // before this feature existed.
  final BillBreakdown? breakdown;

  final String billingPeriod;

  final String status;

  final String recordedBy;

  final Timestamp? recordedAt;

  MeterReadingModel({
    required this.readingId,
    required this.consumerId,
    required this.consumerName,
    required this.accountNumber,
    required this.previousReading,
    required this.currentReading,
    required this.consumption,
    required this.ratePerKwh,
    required this.computedAmount,
    this.breakdown,
    required this.billingPeriod,
    required this.status,
    required this.recordedBy,
    this.recordedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'readingId': readingId,
      'consumerId': consumerId,
      'consumerName': consumerName,
      'accountNumber': accountNumber,
      'previousReading': previousReading,
      'currentReading': currentReading,
      'consumption': consumption,
      'ratePerKwh': ratePerKwh,
      'computedAmount': computedAmount,
      if (breakdown != null) 'breakdown': breakdown!.toMap(),
      'billingPeriod': billingPeriod,
      'status': status,
      'recordedBy': recordedBy,
      'recordedAt': recordedAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory MeterReadingModel.fromMap(
      Map<String, dynamic> map) {
    final rawBreakdown = map['breakdown'];

    return MeterReadingModel(
      readingId: map['readingId'] ?? '',
      consumerId: map['consumerId'] ?? '',
      consumerName: map['consumerName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      previousReading:
          (map['previousReading'] ?? 0).toDouble(),
      currentReading:
          (map['currentReading'] ?? 0).toDouble(),
      consumption:
          (map['consumption'] ?? 0).toDouble(),
      ratePerKwh:
          (map['ratePerKwh'] ?? 0).toDouble(),
      computedAmount:
          (map['computedAmount'] ?? 0).toDouble(),
      breakdown: rawBreakdown is Map
          ? BillBreakdown.fromMap(Map<String, dynamic>.from(rawBreakdown))
          : null,
      billingPeriod:
          map['billingPeriod'] ?? '',
      status:
          map['status'] ?? 'Pending',
      recordedBy:
          map['recordedBy'] ?? '',
      recordedAt:
          map['recordedAt'],
    );
  }
}