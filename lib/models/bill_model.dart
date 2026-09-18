import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soreconnect/utils/bill_calculator.dart';

class BillModel {
  final String billId;
  final String ticketNumber;
  final String consumerId;
  final String consumerName;
  final String accountNumber;

  final double previousReading;
  final double currentReading;
  final double consumption;

  final double ratePerKwh;
  final double totalAmount;

  // Itemized SORECO-style breakdown. Null for bills generated
  // before this feature existed, which fall back to a flat display.
  final BillBreakdown? breakdown;

  final String billingPeriod;

  final DateTime paymentStartDate;
  final DateTime dueDate;

  final String status;

  final String generatedBy;

  final Timestamp? generatedAt;

  BillModel({
    required this.billId,
    required this.ticketNumber,
    required this.consumerId,
    required this.consumerName,
    required this.accountNumber,
    required this.previousReading,
    required this.currentReading,
    required this.consumption,
    required this.ratePerKwh,
    required this.totalAmount,
    this.breakdown,
    required this.billingPeriod,
    required this.paymentStartDate,
    required this.dueDate,
    required this.status,
    required this.generatedBy,
    this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'ticketNumber': ticketNumber,
      'consumerId': consumerId,
      'consumerName': consumerName,
      'accountNumber': accountNumber,
      'previousReading': previousReading,
      'currentReading': currentReading,
      'consumption': consumption,
      'ratePerKwh': ratePerKwh,
      'totalAmount': totalAmount,
      if (breakdown != null) 'breakdown': breakdown!.toMap(),
      'billingPeriod': billingPeriod,
      'paymentStartDate': Timestamp.fromDate(paymentStartDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'generatedBy': generatedBy,
      'generatedAt': generatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory BillModel.fromMap(Map<String, dynamic> map) {
    final billId = map['billId'] ?? '';

    final rawBreakdown = map['breakdown'];

    return BillModel(
      billId: billId,
      ticketNumber:
          BillModel.ticketNumberFor(map, billId),
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
      breakdown: rawBreakdown is Map
          ? BillBreakdown.fromMap(Map<String, dynamic>.from(rawBreakdown))
          : null,
      billingPeriod: map['billingPeriod'] ?? '',
      paymentStartDate:
          (map['paymentStartDate'] as Timestamp?)?.toDate() ??
              (map['dueDate'] as Timestamp).toDate(),
      dueDate:
          (map['dueDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'unpaid',
      generatedBy: map['generatedBy'] ?? '',
      generatedAt: map['generatedAt'],
    );
  }

  // ============================================================
  // TICKET NUMBER
  // Bills aren't created through this app (the meter reader posts
  // them directly to Firestore), so there's no counter to assign a
  // sequential number at creation time like complaints get. Instead
  // this derives a stable 8-digit ticket number from the bill's own
  // id, so every bill shows a consistent ticket number without
  // needing a backend change. A stored 'ticketNumber' field, if
  // present, always takes priority.
  // ============================================================

  static String ticketNumberFor(
    Map<String, dynamic> map,
    String fallbackId,
  ) {
    final stored = map['ticketNumber'];
    if (stored is String && stored.isNotEmpty) {
      return stored;
    }

    final id = fallbackId.isNotEmpty
        ? fallbackId
        : (map['billId'] ?? '');

    if (id.isEmpty) return '';

    final digits =
        (id.hashCode.abs() % 100000000).toString().padLeft(8, '0');

    return 'BIL-$digits';
  }
}