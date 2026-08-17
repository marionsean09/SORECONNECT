import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soreconnect/services/complaint_services.dart';

class ManageComplaintsScreen extends StatelessWidget {
  ManageComplaintsScreen({super.key});

  final ComplaintService _complaintService = ComplaintService();

  void _showResponseDialog(
    BuildContext context,
    String complaintId,
    String currentStatus,
    String currentResponse,
  ) {
    final TextEditingController responseController =
        TextEditingController(text: currentResponse);

    String selectedStatus = currentStatus;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Respond to Complaint"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    TextField(
                      controller: responseController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: "Response / Comment",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: "Status",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Pending",
                          child: Text("Pending"),
                        ),
                        DropdownMenuItem(
                          value: "Resolved",
                          child: Text("Resolved"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () async {

                await _complaintService.updateComplaintStatus(
                  complaintId: complaintId,
                  status: selectedStatus,
                  response: responseController.text.trim(),
                );

                if (context.mounted) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Complaint updated successfully.",
                      ),
                    ),
                  );
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Manage Complaints"),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(

        stream: _complaintService.getAllComplaints(),

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
              child: Text("No complaints found."),
            );
          }
                 Theme.of(context).primaryColor;
          final complaints = snapshot.data!.docs;

          return ListView.builder(

            padding: const EdgeInsets.all(15),

            itemCount: complaints.length,

            itemBuilder: (context, index) {

              final complaint =
                  complaints[index];

              final data =
                  complaint.data()
                      as Map<String, dynamic>;

              return Card(

                margin:
                    const EdgeInsets.only(
                  bottom: 15,
                ),

                elevation: 3,

                child: Padding(

                  padding:
                      const EdgeInsets.all(15),

                  child: Column(

                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Text(
                        data['subject'] ?? '',
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Consumer: ${data['consumerName']}",
                      ),

                      Text(
                        "Account #: ${data['accountNumber']}",
                      ),

                      Text(
                        "Type: ${data['complaintType']}",
                      ),

                      const SizedBox(height: 10),

                      Text(
                        data['description'] ?? '',
                      ),

                      const Divider(),

                      Text(
                        "Status: ${data['status']}",
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "Response:",
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      Text(
                        data['response'] == ""
                            ? "No response yet."
                            : data['response'],
                      ),

                      const SizedBox(height: 15),

                      SizedBox(

                        width: double.infinity,

                        child: ElevatedButton.icon(

                          icon: const Icon(Icons.reply),

                          label: const Text(
                            "Respond",
                          ),

                          onPressed: () {

                            _showResponseDialog(

                              context,

                              complaint.id,

                              data['status'],

                              data['response'],
                            );
                          },
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