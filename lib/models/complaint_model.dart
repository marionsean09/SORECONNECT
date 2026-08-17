import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintModel {
  final String complaintId;
  final String consumerId;
  final String consumerName;

  final String subject;
  final String complaintType;
  final String description;

  final String status;
  final String response;

  final Timestamp? createdAt;
  final Timestamp? respondedAt;

  ComplaintModel({
    required this.complaintId,
    required this.consumerId,
    required this.consumerName,
    required this.subject,
    required this.complaintType,
    required this.description,
    required this.status,
    required this.response,
    this.createdAt,
    this.respondedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'complaintId': complaintId,
      'consumerId': consumerId,
      'consumerName': consumerName,
      'subject': subject,
      'complaintType': complaintType,
      'description': description,
      'status': status,
      'response': response,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'respondedAt': respondedAt,
    };
  }

  factory ComplaintModel.fromMap(Map<String, dynamic> map) {
    return ComplaintModel(
      complaintId: map['complaintId'] ?? '',
      consumerId: map['consumerId'] ?? '',
      consumerName: map['consumerName'] ?? '',
      subject: map['subject'] ?? '',
      complaintType: map['complaintType'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'Pending',
      response: map['response'] ?? '',
      createdAt: map['createdAt'],
      respondedAt: map['respondedAt'],
    );
  }
}