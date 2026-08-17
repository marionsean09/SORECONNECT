import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ConsumerBillScreen extends StatelessWidget {
  const ConsumerBillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not logged in."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Bills"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("bills")
            .where(
              "consumerId",
              isEqualTo: user.uid,
            )
            .orderBy(
              "generatedAt",
              descending: true,
            )
            .snapshots(),

        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No bills available.",
              ),
            );
          }

          final bills = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: bills.length,

            itemBuilder: (context, index) {

              final bill =
                  bills[index].data()
                      as Map<String, dynamic>;

              Timestamp? dueTimestamp =
                  bill["dueDate"];

              String dueDate =
                  dueTimestamp == null
                      ? "-"
                      : DateFormat(
                          "MMM dd, yyyy",
                        ).format(
                          dueTimestamp.toDate(),
                        );

              Color statusColor =
                  bill["status"] == "paid"
                      ? Colors.green
                      : Colors.red;

              return Card(
                elevation: 4,
                margin:
                    const EdgeInsets.only(
                  bottom: 15,
                ),

                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    15,
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,

                        children: [

                          const Text(
                            "Electric Bill",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),

                          Chip(
                            backgroundColor:
                                statusColor
                                    .withOpacity(.2),

                            label: Text(
                              bill["status"]
                                  .toUpperCase(),
                            ),

                            labelStyle: TextStyle(
                              color: statusColor,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const Divider(),

                      Text(
                        "Billing Period: ${bill["billingPeriod"]}",
                      ),

                      Text(
                        "Previous Reading: ${bill["previousReading"]} kWh",
                      ),

                      Text(
                        "Current Reading: ${bill["currentReading"]} kWh",
                      ),

                      Text(
                        "Consumption: ${bill["consumption"]} kWh",
                      ),

                      Text(
                        "Rate per kWh: ₱${bill["ratePerKwh"]}",
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Due Date: $dueDate",
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Generated By: ${bill["generatedBy"]}",
                      ),

                      const Divider(),

                      Align(
                        alignment:
                            Alignment.centerRight,

                        child: Text(
                          "₱${((bill["totalAmount"] as num?) ?? 0).toDouble().toStringAsFixed(2)}",
                          style:
                              const TextStyle(
                            color: Color(
                                0xFFD32F2F),
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 22,
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