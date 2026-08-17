import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MonitorComplaintsScreen extends StatelessWidget {
  const MonitorComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitor Complaints"),
          backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("complaints")
            .orderBy(
              "createdAt",
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
              child: Text(
                snapshot.error.toString(),
              ),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No complaints available.",
              ),
            );
          }

          final complaints = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: complaints.length,

            itemBuilder: (context, index) {

              final data =
                  complaints[index].data()
                      as Map<String, dynamic>;

                final status = (data['status'] ?? '').toString();
                Color statusColor = Colors.orange;
                if (status.toLowerCase() == 'resolved' || status.toLowerCase() == 'closed' || status.toLowerCase() == 'completed') {
                statusColor = Colors.green;
                }

                final Timestamp? created = data['createdAt'] as Timestamp?;
                final String date = created == null
                  ? '-'
                  : DateFormat('MMM dd, yyyy hh:mm a').format(created.toDate());

                final response = (data['response'] ?? '').toString();
                final Timestamp? respondedAt = data['respondedAt'] as Timestamp?;
                final String respondedAtText = respondedAt == null
                  ? ''
                  : DateFormat('MMM dd, yyyy hh:mm a').format(respondedAt.toDate());

              return Card(
                elevation: 3,
                margin:
                    const EdgeInsets.only(
                  bottom: 15,
                ),

                child: Padding(
                  padding:
                      const EdgeInsets.all(15),

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

                          Expanded(
                            child: Text(
                              data["subject"] ??
                                  "",
                              style:
                                  const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),

                          Chip(
                            label: Text(
                              status.isNotEmpty ? status : 'Pending',
                            ),
                            backgroundColor:
                                statusColor
                                    .withOpacity(
                                        .2),
                            labelStyle:
                                TextStyle(
                              color: statusColor,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        "Consumer: ${data["consumerName"]}",
                      ),

                      Text(
                        "Account #: ${data["accountNumber"]}",
                      ),

                      Text(
                        "Complaint Type: ${data["complaintType"]}",
                      ),

                      Text(
                        "Date Submitted: $date",
                      ),

                      const Divider(),

                      const Text(
                        "Description",
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        data["description"],
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      const Text(
                        "Teller Comment",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      if (response.isEmpty)
                        const Text('No response yet.')
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(response),
                            if (respondedAtText.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Responded: $respondedAtText', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ]
                          ],
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