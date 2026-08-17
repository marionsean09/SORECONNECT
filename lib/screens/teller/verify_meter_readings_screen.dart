import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soreconnect/services/rate_service.dart';

class VerifyMeterReadingsScreen extends StatefulWidget {
  const VerifyMeterReadingsScreen({super.key});

  @override
  State<VerifyMeterReadingsScreen> createState() =>
      _VerifyMeterReadingsScreenState();
}

class _VerifyMeterReadingsScreenState
    extends State<VerifyMeterReadingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track processing status per document ID to avoid disabling all items
  String? _processingDocId;
  final Map<String, String> _selectedBillStatus = {};

  /// Generate official bill and update reading status atomically
  Future<void> _verifyReading(DocumentSnapshot readingDoc, String billStatus) async {
    final String docId = readingDoc.id;

    setState(() {
      _processingDocId = docId;
    });

    try {
      final reading = readingDoc.data() as Map<String, dynamic>? ?? {};

      // Prepare new Bill Document reference
      final DocumentReference billRef =
          _firestore.collection("bills").doc();

      final DateTime dueDate = DateTime.now().add(const Duration(days: 15));

      // Use current official rate at verification time to compute total
      final RateService rateService = RateService();
      final double currentOfficialRate = await rateService.getCurrentRate();
      final double consumption = (reading["consumption"] ?? 0).toDouble();
      final double total = consumption * currentOfficialRate;

      final String consumerId = (reading["consumerId"] ?? "").toString().trim();
      final String consumerName = (reading["consumerName"] ?? "N/A").toString();
      final String accountNumber = (reading["accountNumber"] ?? "N/A").toString();

      final Map<String, dynamic> billData = {
        "billId": billRef.id,
        "consumerId": consumerId,
        "consumerName": consumerName,
        "accountNumber": accountNumber,
        "previousReading": reading["previousReading"] ?? 0,
        "currentReading": reading["currentReading"] ?? 0,
        "consumption": consumption,
        "ratePerKwh": currentOfficialRate,
        "totalAmount": total,
        "billingPeriod": reading["billingPeriod"] ?? "",
        "dueDate": Timestamp.fromDate(dueDate),
        "status": billStatus.toLowerCase(),
        "generatedBy": _auth.currentUser?.email ?? "Teller",
        "generatedAt": FieldValue.serverTimestamp(),
      };

      // Perform atomic batch write
      final WriteBatch batch = _firestore.batch();

      batch.set(billRef, billData);
      batch.update(readingDoc.reference, {
        "status": "Verified",
        "verifiedBy": _auth.currentUser?.email ?? "Teller",
        "verifiedAt": FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Bill verified successfully."),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Error: ${e.toString()}"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingDocId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Meter Readings'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("meter_readings")
            .where("status", isEqualTo: "Pending")
            .orderBy("recordedAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Error fetching readings: ${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 70,
                    color: Colors.green,
                  ),
                  SizedBox(height: 15),
                  Text(
                    "No Pending Meter Readings",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          final readings = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: readings.length,
            itemBuilder: (context, index) {
              final readingDoc = readings[index];
              final data = readingDoc.data() as Map<String, dynamic>;
              final isThisItemProcessing =
                  _processingDocId == readingDoc.id;
              final String selectedStatus =
                  _selectedBillStatus[readingDoc.id] ?? 'unpaid';

              final num computedAmount =
                  (data["computedAmount"] as num?) ?? 0;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data["consumerName"] ?? "Unknown Consumer",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text("Account Number : ${data["accountNumber"] ?? "N/A"}"),
                      Text("Billing Period : ${data["billingPeriod"] ?? "N/A"}"),
                      const Divider(),
                      Text("Previous Reading : ${data["previousReading"] ?? 0} kWh"),
                      Text("Current Reading : ${data["currentReading"] ?? 0} kWh"),
                      Text("Consumption : ${data["consumption"] ?? 0} kWh"),
                      Text("Rate : ₱${data["ratePerKwh"] ?? 0}"),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "₱${computedAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Bill Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'unpaid',
                            child: Text('Unpaid'),
                          ),
                          DropdownMenuItem(
                            value: 'paid',
                            child: Text('Paid'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedBillStatus[readingDoc.id] =
                                value ?? 'unpaid';
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _processingDocId != null
                              ? null
                              : () async {
                                  final bool? confirm =
                                      await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text("Verify Bill"),
                                        content: Text(
                                          "Verify and generate the official bill for ${data["consumerName"]} as ${selectedStatus == 'paid' ? 'Paid' : 'Unpaid'}?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFD32F2F),
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text("Verify"),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirm == true) {
                                    await _verifyReading(readingDoc, selectedStatus);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                          ),
                          icon: isThisItemProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.verified),
                          label: Text(
                            isThisItemProcessing
                                ? "VERIFYING..."
                                : "VERIFY BILL",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}