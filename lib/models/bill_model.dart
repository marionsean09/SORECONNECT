import 'package:cloud_firestore/cloud_firestore.dart';

class BillModel {
  final String billId;
  final String consumerId;
  final String consumerName;
  final String accountNumber;

  final double previousReading;
  final double currentReading;
  final double consumption;

  final double ratePerKwh;
  final double totalAmount;

  final String billingPeriod;

  final DateTime dueDate;

  final String status;

  final String generatedBy;

  final Timestamp? generatedAt;

  BillModel({
    required this.billId,
    required this.consumerId,
    required this.consumerName,
    required this.accountNumber,
    required this.previousReading,
    required this.currentReading,
    required this.consumption,
    required this.ratePerKwh,
    required this.totalAmount,
    required this.billingPeriod,
    required this.dueDate,
    required this.status,
    required this.generatedBy,
    this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'consumerId': consumerId,
      'consumerName': consumerName,
      'accountNumber': accountNumber,
      'previousReading': previousReading,
      'currentReading': currentReading,
      'consumption': consumption,
      'ratePerKwh': ratePerKwh,
      'totalAmount': totalAmount,
      'billingPeriod': billingPeriod,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'generatedBy': generatedBy,
      'generatedAt': generatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory BillModel.fromMap(Map<String, dynamic> map) {
    return BillModel(
      billId: map['billId'] ?? '',
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
      totalAmount:
          (map['totalAmount'] ?? 0).toDouble(),
      billingPeriod: map['billingPeriod'] ?? '',
      dueDate:
          (map['dueDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'unpaid',
      generatedBy: map['generatedBy'] ?? '',
      generatedAt: map['generatedAt'],
    );
  }
}