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

  String? _processingDocId;

  /// Verify the meter reading and generate the official bill
  Future<void> _verifyReading({
    required DocumentSnapshot readingDoc,
    required double previousReading,
    required double currentReading,
    required double consumption,
    required double ratePerKwh,
    required String billingPeriod,
    required DateTime dueDate,
    required String billStatus,
  }) async {
    final String docId = readingDoc.id;

    setState(() {
      _processingDocId = docId;
    });

    try {
      final reading =
          readingDoc.data() as Map<String, dynamic>? ?? {};

      final DocumentReference billRef =
          _firestore.collection("bills").doc();

      final double totalAmount =
          consumption * ratePerKwh;

      final String consumerId =
          (reading["consumerId"] ?? "")
              .toString()
              .trim();

      final String consumerName =
          (reading["consumerName"] ?? "N/A")
              .toString();

      final String accountNumber =
          (reading["accountNumber"] ?? "N/A")
              .toString();

      final Map<String, dynamic> billData = {
        "billId": billRef.id,

        "consumerId": consumerId,

        "consumerName": consumerName,

        "accountNumber": accountNumber,

        "previousReading": previousReading,

        "currentReading": currentReading,

        "consumption": consumption,

        "ratePerKwh": ratePerKwh,

        "totalAmount": totalAmount,

        "billingPeriod": billingPeriod,

        "dueDate": Timestamp.fromDate(dueDate),

        "status": billStatus.toLowerCase(),

        "generatedBy":
            _auth.currentUser?.email ?? "Teller",

        "generatedAt":
            FieldValue.serverTimestamp(),
      };

      final WriteBatch batch =
          _firestore.batch();

      // Create official bill
      batch.set(
        billRef,
        billData,
      );

      // Update meter reading
      batch.update(
        readingDoc.reference,
        {
          "status": "Verified",

          "verifiedBy":
              _auth.currentUser?.email ?? "Teller",

          "verifiedAt":
              FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Bill verified and generated successfully.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Error: ${e.toString()}",
          ),
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

  /// Open dialog where teller can edit bill details
  Future<void> _showEditBillDialog(
    DocumentSnapshot readingDoc,
  ) async {
    final data =
        readingDoc.data() as Map<String, dynamic>;

    final previousReadingController =
        TextEditingController(
      text: "${data["previousReading"] ?? 0}",
    );

    final currentReadingController =
        TextEditingController(
      text: "${data["currentReading"] ?? 0}",
    );

    final consumptionController =
        TextEditingController(
      text: "${data["consumption"] ?? 0}",
    );

    final billingPeriodController =
        TextEditingController(
      text: "${data["billingPeriod"] ?? ""}",
    );

    double currentRate =
        (data["ratePerKwh"] as num?)
                ?.toDouble() ??
            0;

    // If there is no rate in meter reading,
    // get the current official rate
    if (currentRate == 0) {
      try {
        final RateService rateService =
            RateService();

        currentRate =
            await rateService.getCurrentRate();
      } catch (_) {}
    }

    final rateController =
        TextEditingController(
      text: currentRate.toString(),
    );

    String selectedStatus = "unpaid";

    DateTime selectedDueDate =
        DateTime.now().add(
      const Duration(days: 15),
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            double calculateTotal() {
              final consumption =
                  double.tryParse(
                        consumptionController.text,
                      ) ??
                      0;

              final rate =
                  double.tryParse(
                        rateController.text,
                      ) ??
                      0;

              return consumption * rate;
            }

            return AlertDialog(
              title: const Text(
                "Edit and Verify Bill",
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    Text(
                      data["consumerName"] ??
                          "Unknown Consumer",
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    TextField(
                      controller:
                          previousReadingController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Previous Reading",
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          currentReadingController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Current Reading",
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        final previous =
                            double.tryParse(
                                  previousReadingController
                                      .text,
                                ) ??
                                0;

                        final current =
                            double.tryParse(
                                  currentReadingController
                                      .text,
                                ) ??
                                0;

                        final consumption =
                            current - previous;

                        setDialogState(() {
                          consumptionController.text =
                              consumption
                                  .toStringAsFixed(
                                      2);
                        });
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          consumptionController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Consumption (kWh)",
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          rateController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Rate per kWh",
                        border:
                            OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          billingPeriodController,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Billing Period",
                        border:
                            OutlineInputBorder(),
                        hintText:
                            "Example: August 2026",
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Bill Status",
                        border:
                            OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "unpaid",
                          child: Text(
                            "Unpaid",
                          ),
                        ),
                        DropdownMenuItem(
                          value: "paid",
                          child: Text(
                            "Paid",
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedStatus =
                              value ?? "unpaid";
                        });
                      },
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: const Text(
                        "Due Date",
                      ),
                      subtitle: Text(
                        "${selectedDueDate.month}/${selectedDueDate.day}/${selectedDueDate.year}",
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                      ),
                      onTap: () async {
                        final picked =
                            await showDatePicker(
                          context: context,
                          initialDate:
                              selectedDueDate,
                          firstDate:
                              DateTime.now(),
                          lastDate:
                              DateTime.now().add(
                            const Duration(
                              days: 365,
                            ),
                          ),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDueDate =
                                picked;
                          });
                        }
                      },
                    ),

                    const Divider(),

                    Text(
                      "Total Amount",
                      style:
                          Theme.of(context)
                              .textTheme
                              .titleMedium,
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      "₱${calculateTotal().toStringAsFixed(2)}",
                      style:
                          const TextStyle(
                        color:
                            Color(0xFFD32F2F),
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 25,
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    "Cancel",
                  ),
                ),

                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFFD32F2F,
                    ),
                    foregroundColor:
                        Colors.white,
                  ),

                  onPressed: () async {
                    final previousReading =
                        double.tryParse(
                              previousReadingController
                                  .text,
                            ) ??
                            0;

                    final currentReading =
                        double.tryParse(
                              currentReadingController
                                  .text,
                            ) ??
                            0;

                    final consumption =
                        double.tryParse(
                              consumptionController
                                  .text,
                            ) ??
                            0;

                    final rate =
                        double.tryParse(
                              rateController.text,
                            ) ??
                            0;

                    if (currentReading <
                        previousReading) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Current reading cannot be less than previous reading.",
                          ),
                        ),
                      );

                      return;
                    }

                    if (consumption < 0) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Consumption cannot be negative.",
                          ),
                        ),
                      );

                      return;
                    }

                    if (rate <= 0) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Rate must be greater than zero.",
                          ),
                        ),
                      );

                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                    );

                    await _verifyReading(
                      readingDoc: readingDoc,

                      previousReading:
                          previousReading,

                      currentReading:
                          currentReading,

                      consumption:
                          consumption,

                      ratePerKwh: rate,

                      billingPeriod:
                          billingPeriodController
                              .text
                              .trim(),

                      dueDate:
                          selectedDueDate,

                      billStatus:
                          selectedStatus,
                    );
                  },

                  child: const Text(
                    "SAVE & VERIFY",
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    previousReadingController.dispose();
    currentReadingController.dispose();
    consumptionController.dispose();
    rateController.dispose();
    billingPeriodController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Verify Meter Readings",
        ),
        backgroundColor:
            Theme.of(context).primaryColor,
        foregroundColor:
            Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("meter_readings")
            .where(
              "status",
              isEqualTo: "Pending",
            )
            .orderBy(
              "recordedAt",
              descending: true,
            )
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Text(
                  "Error fetching readings:\n${snapshot.error}",
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
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
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          final readings =
              snapshot.data!.docs;

          return ListView.builder(
            padding:
                const EdgeInsets.all(15),

            itemCount:
                readings.length,

            itemBuilder:
                (context, index) {
              final readingDoc =
                  readings[index];

              final data =
                  readingDoc.data()
                      as Map<String, dynamic>;

              final isProcessing =
                  _processingDocId ==
                      readingDoc.id;

              return Card(
                elevation: 4,

                margin:
                    const EdgeInsets.only(
                  bottom: 15,
                ),

                child: Padding(
                  padding:
                      const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        data["consumerName"] ??
                            "Unknown Consumer",

                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        "Account Number: ${data["accountNumber"] ?? "N/A"}",
                      ),

                      Text(
                        "Billing Period: ${data["billingPeriod"] ?? "N/A"}",
                      ),

                      const Divider(),

                      Text(
                        "Previous Reading: ${data["previousReading"] ?? 0} kWh",
                      ),

                      Text(
                        "Current Reading: ${data["currentReading"] ?? 0} kWh",
                      ),

                      Text(
                        "Consumption: ${data["consumption"] ?? 0} kWh",
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      SizedBox(
                        width:
                            double.infinity,

                        height: 50,

                        child:
                            ElevatedButton.icon(
                          onPressed:
                              _processingDocId !=
                                      null
                                  ? null
                                  : () async {
                                      await _showEditBillDialog(
                                        readingDoc,
                                      );
                                    },

                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color(
                              0xFFD32F2F,
                            ),

                            foregroundColor:
                                Colors.white,
                          ),

                          icon: isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.edit,
                                ),

                          label: Text(
                            isProcessing
                                ? "VERIFYING..."
                                : "EDIT & VERIFY BILL",
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