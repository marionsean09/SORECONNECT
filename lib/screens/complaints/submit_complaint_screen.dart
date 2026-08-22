import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:soreconnect/services/complaint_services.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() =>
      _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState
    extends State<SubmitComplaintScreen> {
  final ComplaintService _complaintService =
      ComplaintService();

  final TextEditingController _subjectController =
      TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  String _complaintType = "Billing";
  bool _isLoading = false;

  final List<String> _complaintTypes = [
    "Billing",
    "Power Interruption",
    "Meter Reading",
    "Connection",
    "Service",
    "Others",
  ];

  Future<void> _submitComplaint() async {
    if (_subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Subject is required."),
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Description is required."),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _complaintService.submitComplaint(
        subject: _subjectController.text.trim(),
        complaintType: _complaintType,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Complaint submitted successfully.",
          ),
        ),
      );

      _subjectController.clear();
      _descriptionController.clear();

      setState(() {
        _complaintType = "Billing";
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Submit Complaint"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // ==========================================
            // SUBMIT COMPLAINT FORM
            // ==========================================

            const Text(
              "Submit a Complaint",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Subject",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter complaint subject",
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Complaint Type",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              value: _complaintType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),

              items: _complaintTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),

              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _complaintType = value;
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            const Text(
              "Description",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _descriptionController,
              maxLines: 6,

              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Describe your complaint...",
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,

              child: ElevatedButton(
                onPressed:
                    _isLoading ? null : _submitComplaint,

                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFD32F2F),

                  foregroundColor: Colors.white,
                ),

                child: _isLoading
                    ? const SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        "SUBMIT COMPLAINT",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            // ==========================================
            // DIVIDER
            // ==========================================

            const SizedBox(height: 35),

            const Divider(
              thickness: 1,
            ),

            const SizedBox(height: 20),

            // ==========================================
            // CONSUMER COMPLAINT LIST
            // ==========================================

            const Text(
              "Your Complaints",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Builder(
              builder: (context) {
                final user =
                    FirebaseAuth.instance.currentUser;

                if (user == null) {
                  return const SizedBox.shrink();
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _complaintService
                      .getConsumerComplaints(user.uid),

                  builder: (context, snapshot) {

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Card(
                        color: Colors.red.shade50,

                        child: Padding(
                          padding:
                              const EdgeInsets.all(12),

                          child: Text(
                            "Error: ${snapshot.error}",
                          ),
                        ),
                      );
                    }

                    final docs =
                        snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Card(
                        color: Colors.grey.shade100,

                        child: const Padding(
                          padding: EdgeInsets.all(15),

                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.grey,
                              ),

                              SizedBox(width: 10),

                              Expanded(
                                child: Text(
                                  "You have not submitted any complaints yet.",
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: docs.map((d) {

                        final data =
                            d.data()
                                as Map<String, dynamic>;

                        final status =
                            (data['status'] ?? 'Pending')
                                .toString();

                        final response =
                            (data['response'] ?? '')
                                .toString();

                        final subject =
                            (data['subject'] ?? '')
                                .toString();

                        final complaintType =
                            (data['complaintType'] ?? '')
                                .toString();

                        final description =
                            (data['description'] ?? '')
                                .toString();

                        // ==================================
                        // SUBMISSION DATE
                        // ==================================

                        final submitted =
                            data['dateSubmitted'] ??
                            data['createdAt'];

                        String dateText = '';

                        if (submitted is Timestamp) {
                          dateText = DateFormat(
                            'MMM dd, yyyy hh:mm a',
                          ).format(
                            submitted.toDate(),
                          );
                        }

                        // ==================================
                        // RESPONSE DATE
                        // ==================================

                        final respondedAt =
                            data['respondedAt'];

                        String respondedDateText = '';

                        if (respondedAt is Timestamp) {
                          respondedDateText = DateFormat(
                            'MMM dd, yyyy hh:mm a',
                          ).format(
                            respondedAt.toDate(),
                          );
                        }

                        // ==================================
                        // STATUS LOGIC
                        // ==================================

                        final statusLower =
                            status.toLowerCase();

                        final isResolved =
                            statusLower == 'resolved' ||
                            statusLower == 'closed' ||
                            statusLower == 'completed';

                        final isInProgress =
                            statusLower == 'in progress' ||
                            statusLower == 'in-progress' ||
                            statusLower == 'inprogress';

                        final isPending =
                            statusLower == 'pending';

                        Color statusColor;
                        IconData statusIcon;

                        if (isResolved) {
                          statusColor = Colors.green;
                          statusIcon =
                              Icons.check_circle;
                        } else if (isInProgress) {
                          statusColor = Colors.blue;
                          statusIcon =
                              Icons.autorenew;
                        } else if (isPending) {
                          statusColor = Colors.orange;
                          statusIcon =
                              Icons.pending;
                        } else {
                          statusColor = Colors.grey;
                          statusIcon =
                              Icons.help_outline;
                        }

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

                                // ==========================
                                // SUBJECT AND DATE
                                // ==========================

                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,

                                  children: [

                                    Expanded(
                                      child: Text(
                                        subject.isEmpty
                                            ? "No Subject"
                                            : subject,

                                        style:
                                            const TextStyle(
                                          fontSize: 17,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                      width: 10,
                                    ),

                                    Flexible(
                                      child: Text(
                                        dateText,

                                        textAlign:
                                            TextAlign.right,

                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 10,
                                ),

                                // ==========================
                                // COMPLAINT TYPE
                                // ==========================

                                Text(
                                  "Type: $complaintType",

                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.w500,
                                  ),
                                ),

                                const SizedBox(
                                  height: 5,
                                ),

                                // ==========================
                                // DESCRIPTION
                                // ==========================

                                Text(
                                  description,
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                // ==========================
                                // STATUS
                                // ==========================

                                Row(
                                  children: [

                                    const Text(
                                      "Status: ",

                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),

                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),

                                      decoration:
                                          BoxDecoration(
                                        color:
                                            statusColor
                                                .withOpacity(
                                          0.15,
                                        ),

                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          20,
                                        ),
                                      ),

                                      child: Row(
                                        mainAxisSize:
                                            MainAxisSize.min,

                                        children: [

                                          Icon(
                                            statusIcon,
                                            color:
                                                statusColor,
                                            size: 16,
                                          ),

                                          const SizedBox(
                                            width: 5,
                                          ),

                                          Text(
                                            status,

                                            style: TextStyle(
                                              color:
                                                  statusColor,

                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 15,
                                ),

                                const Divider(),

                                const SizedBox(
                                  height: 8,
                                ),

                                // ==========================
                                // TELLER RESPONSE
                                // ==========================

                                const Text(
                                  "Teller Response",

                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),

                                const SizedBox(
                                  height: 5,
                                ),

                                Text(
                                  response.isNotEmpty
                                      ? response
                                      : "No response yet.",

                                  style: TextStyle(
                                    color:
                                        response.isNotEmpty
                                            ? Colors.black87
                                            : Colors.grey,
                                  ),
                                ),

                                // ==========================
                                // RESPONSE DATE
                                // ==========================

                                if (respondedDateText.isNotEmpty) ...[

                                  const SizedBox(
                                    height: 8,
                                  ),

                                  Text(
                                    "Last updated: $respondedDateText",

                                    style:
                                        const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );

                      }).toList(),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}