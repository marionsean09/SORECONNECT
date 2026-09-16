import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintModel {
  final String complaintId;
  final String ticketNumber;
  final String consumerId;
  final String consumerName;

  final String subject;
  final String complaintType;
  final String description;

  final String status;

  final String? imageBase64;
  final String? imageMimeType;

  final Timestamp? createdAt;

  ComplaintModel({
    required this.complaintId,
    required this.ticketNumber,
    required this.consumerId,
    required this.consumerName,
    required this.subject,
    required this.complaintType,
    required this.description,
    required this.status,
    this.imageBase64,
    this.imageMimeType,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'complaintId': complaintId,
      'ticketNumber': ticketNumber,
      'consumerId': consumerId,
      'consumerName': consumerName,
      'subject': subject,
      'complaintType': complaintType,
      'description': description,
      'status': status,
      'imageBase64': imageBase64,
      'imageMimeType': imageMimeType,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory ComplaintModel.fromMap(Map<String, dynamic> map) {
    return ComplaintModel(
      complaintId: map['complaintId'] ?? '',
      ticketNumber: map['ticketNumber'] ?? '',
      consumerId: map['consumerId'] ?? '',
      consumerName: map['consumerName'] ?? '',
      subject: map['subject'] ?? '',
      complaintType: map['complaintType'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'Pending',
      imageBase64: map['imageBase64'],
      imageMimeType: map['imageMimeType'],
      createdAt: map['createdAt'],
    );
  }
}