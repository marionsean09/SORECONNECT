import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soreconnect/services/complaint_services.dart';

class ManageComplaintsScreen extends StatefulWidget {
  const ManageComplaintsScreen({super.key});

  @override
  State<ManageComplaintsScreen> createState() =>
      _ManageComplaintsScreenState();
}

class _ManageComplaintsScreenState
    extends State<ManageComplaintsScreen> {
  final ComplaintService _complaintService =
      ComplaintService();

  // ============================================================
  // FILTER / SORT OPTIONS
  // ============================================================

  String _statusFilter = 'All Statuses';
  String _sortOption = 'Newest';

  // ============================================================
  // GET DATE
  // ============================================================

  DateTime? _getDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // GET COMPLAINT DATE
  // ============================================================

  DateTime _getComplaintDate(
    Map<String, dynamic> data,
  ) {
    final date =
        _getDate(data['dateCreated']) ??
        _getDate(data['createdAt']) ??
        _getDate(data['timestamp']) ??
        _getDate(data['dateSubmitted']);

    return date ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // FILTER + SORT COMPLAINTS
  // ============================================================

  List<QueryDocumentSnapshot> _processComplaints(
    List<QueryDocumentSnapshot> docs,
  ) {
    // ----------------------------------------------------------
    // CREATE COPY
    // ----------------------------------------------------------

    final processedDocs =
        List<QueryDocumentSnapshot>.from(docs);

    // ----------------------------------------------------------
    // FILTER BY STATUS
    // ----------------------------------------------------------

    if (_statusFilter != 'All Statuses') {
      processedDocs.removeWhere((doc) {
        final data =
            doc.data() as Map<String, dynamic>;

        final status =
            (data['status'] ?? 'Pending')
                .toString();

        return status.toLowerCase() !=
            _statusFilter.toLowerCase();
      });
    }

    // ----------------------------------------------------------
    // SORT BY DATE
    // ----------------------------------------------------------

    processedDocs.sort((a, b) {
      final dataA =
          a.data() as Map<String, dynamic>;

      final dataB =
          b.data() as Map<String, dynamic>;

      final dateA =
          _getComplaintDate(dataA);

      final dateB =
          _getComplaintDate(dataB);

      if (_sortOption == 'Newest') {
        return dateB.compareTo(dateA);
      } else {
        return dateA.compareTo(dateB);
      }
    });

    return processedDocs;
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _getStatusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
      case 'completed':
        return Colors.green;

      case 'in progress':
        return Colors.blue;

      case 'pending':
      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _getStatusIcon(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
      case 'completed':
        return Icons.check_circle;

      case 'in progress':
        return Icons.pending_actions;

      case 'pending':
      default:
        return Icons.pending;
    }
  }

  // ============================================================
  // SHOW RESPONSE DIALOG
  // ============================================================

  void _showResponseDialog(
    BuildContext context,
    String complaintId,
    String currentStatus,
    String currentResponse,
  ) {
    final TextEditingController responseController =
        TextEditingController(
      text: currentResponse,
    );

    final List<String> statuses = [
      "Pending",
      "In Progress",
      "Resolved",
    ];

    String selectedStatus =
        statuses.contains(currentStatus)
            ? currentStatus
            : "Pending";

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            "Respond to Complaint",
          ),

          content: StatefulBuilder(
            builder: (
              context,
              setState,
            ) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          responseController,
                      maxLines: 5,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Response / Comment",
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    DropdownButtonFormField<
                        String>(
                      value: selectedStatus,
                      decoration:
                          const InputDecoration(
                        labelText: "Status",
                        border:
                            OutlineInputBorder(),
                      ),

                      items:
                          statuses.map(
                        (status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        },
                      ).toList(),

                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedStatus =
                                value;
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
              child: const Text(
                "Cancel",
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                await _complaintService
                    .updateComplaintStatus(
                  complaintId:
                      complaintId,
                  status:
                      selectedStatus,
                  response:
                      responseController
                          .text
                          .trim(),
                );

                if (context.mounted) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    const SnackBar(
                      backgroundColor:
                          Colors.green,
                      content: Text(
                        "Complaint updated successfully.",
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                "Save",
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Manage Complaints",
        ),
        backgroundColor:
            const Color.fromARGB(
          255,
          232,
          141,
          4,
        ),
        foregroundColor: Colors.white,
      ),

      body: Column(
        children: [
          // ====================================================
          // FILTER + SORT BAR
          // ====================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),

            child: Row(
              children: [
                // ==============================================
                // STATUS FILTER
                // ==============================================

                Expanded(
                  child: Container(
                    height: 48,

                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.grey.shade100,

                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),

                      border: Border.all(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),

                    child:
                        DropdownButtonHideUnderline(
                      child:
                          DropdownButton<String>(
                        value:
                            _statusFilter,

                        isExpanded:
                            true,

                        icon:
                            const Icon(
                          Icons
                              .keyboard_arrow_down,
                          size: 20,
                          color:
                              Colors.grey,
                        ),

                        style:
                            const TextStyle(
                          color:
                              Colors.black87,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w500,
                        ),

                        items: const [
                          DropdownMenuItem(
                            value:
                                'All Statuses',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .tune,
                                  size: 18,
                                  color:
                                      Colors.orange,
                                ),

                                SizedBox(
                                  width: 8,
                                ),

                                Text(
                                  'All Statuses',
                                ),
                              ],
                            ),
                          ),

                          DropdownMenuItem(
                            value:
                                'Pending',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .pending,
                                  size: 18,
                                  color:
                                      Colors.orange,
                                ),

                                SizedBox(
                                  width: 8,
                                ),

                                Text(
                                  'Pending',
                                ),
                              ],
                            ),
                          ),

                          DropdownMenuItem(
                            value:
                                'In Progress',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .pending_actions,
                                  size: 18,
                                  color:
                                      Colors.blue,
                                ),

                                SizedBox(
                                  width: 8,
                                ),

                                Text(
                                  'In Progress',
                                ),
                              ],
                            ),
                          ),

                          DropdownMenuItem(
                            value:
                                'Resolved',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .check_circle,
                                  size: 18,
                                  color:
                                      Colors.green,
                                ),

                                SizedBox(
                                  width: 8,
                                ),

                                Text(
                                  'Resolved',
                                ),
                              ],
                            ),
                          ),
                        ],

                        onChanged:
                            (value) {
                          if (value !=
                              null) {
                            setState(() {
                              _statusFilter =
                                  value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // ==============================================
                // SORT DROPDOWN
                // ==============================================

                Expanded(
                  child: Container(
                    height: 48,

                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.grey.shade100,

                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),

                      border: Border.all(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),

                    child:
                        DropdownButtonHideUnderline(
                      child:
                          DropdownButton<String>(
                        value:
                            _sortOption,

                        isExpanded:
                            true,

                        icon:
                            const Icon(
                          Icons
                              .keyboard_arrow_down,
                          size: 20,
                          color:
                              Colors.grey,
                        ),

                        style:
                            const TextStyle(
                          color:
                              Colors.black87,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w500,
                        ),

                        items: const [
                          DropdownMenuItem(
                            value:
                                'Newest',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .sort,
                                  size: 18,
                                  color:
                                      Colors.orange,
                                ),

                                SizedBox(
                                  width: 8,
                                ),

                                Text(
                                  'Newest',
                                ),
                              ],
                            ),
                          ),

                          DropdownMenuItem(
                            value:
                                'Oldest',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .sort,
                                  size: 18,
                                  color:
                                      Colors.orange,
                                ),

                                SizedBox(
                                  width: 8,
                                ),

                                Text(
                                  'Oldest',
                                ),
                              ],
                            ),
                          ),
                        ],

                        onChanged:
                            (value) {
                          if (value !=
                              null) {
                            setState(() {
                              _sortOption =
                                  value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // COMPLAINTS LIST
          // ====================================================

          Expanded(
            child:
                StreamBuilder<QuerySnapshot>(
              stream:
                  _complaintService
                      .getAllComplaints(),

              builder:
                  (context, snapshot) {
                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      snapshot.error
                          .toString(),
                    ),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs
                        .isEmpty) {
                  return const Center(
                    child: Text(
                      "No complaints found.",
                    ),
                  );
                }

                // ==================================================
                // APPLY FILTER + SORT
                // ==================================================

                final complaints =
                    _processComplaints(
                  snapshot.data!.docs,
                );

                // ==================================================
                // NO RESULTS AFTER FILTER
                // ==================================================

                if (complaints.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          Icons
                              .filter_alt_off,
                          size: 45,
                          color:
                              Colors.grey.shade400,
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        const Text(
                          "No complaints found.",
                          style: TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ==================================================
                // LIST
                // ==================================================

                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16,
                  ),

                  itemCount:
                      complaints.length,

                  itemBuilder:
                      (context, index) {
                    final complaint =
                        complaints[index];

                    final data =
                        complaint.data()
                            as Map<String,
                                dynamic>;

                    final String status =
                        (data['status'] ??
                                'Pending')
                            .toString();

                    final String response =
                        (data['response'] ??
                                '')
                            .toString();

                    final statusColor =
                        _getStatusColor(
                      status,
                    );

                    return Card(
                      margin:
                          const EdgeInsets.only(
                        bottom: 15,
                      ),

                      elevation: 3,

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
                            // ======================================
                            // SUBJECT + STATUS
                            // ======================================

                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    data['subject'] ??
                                        'No Subject',
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      fontSize:
                                          18,
                                    ),
                                  ),
                                ),

                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        10,
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

                                  child: Text(
                                    status,
                                    style:
                                        TextStyle(
                                      color:
                                          statusColor,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      fontSize:
                                          12,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            Text(
                              "Consumer: ${data['consumerName'] ?? 'Unknown'}",
                            ),

                            Text(
                              "Account #: ${data['accountNumber'] ?? 'N/A'}",
                            ),

                            Text(
                              "Type: ${data['complaintType'] ?? 'N/A'}",
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            Text(
                              data['description'] ??
                                  'No description provided.',
                            ),

                            const Divider(),

                            // ======================================
                            // STATUS
                            // ======================================

                            Row(
                              children: [
                                Icon(
                                  _getStatusIcon(
                                    status,
                                  ),
                                  color:
                                      statusColor,
                                  size: 20,
                                ),

                                const SizedBox(
                                  width: 6,
                                ),

                                Text(
                                  "Status: $status",
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color:
                                        statusColor,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            // ======================================
                            // RESPONSE
                            // ======================================

                            const Text(
                              "Response:",
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            Text(
                              response.isEmpty
                                  ? "No response yet."
                                  : response,

                              style:
                                  TextStyle(
                                color:
                                    response
                                            .isEmpty
                                        ? Colors
                                            .grey
                                        : Colors
                                            .black87,
                              ),
                            ),

                            const SizedBox(
                              height: 15,
                            ),

                            // ======================================
                            // RESPOND / EDIT
                            // ======================================

                            SizedBox(
                              width:
                                  double.infinity,

                              child:
                                  ElevatedButton
                                      .icon(
                                icon: Icon(
                                  response
                                          .isEmpty
                                      ? Icons
                                          .reply
                                      : Icons
                                          .edit,
                                ),

                                label: Text(
                                  response
                                          .isEmpty
                                      ? "Respond"
                                      : "Edit Response",
                                ),

                                onPressed: () {
                                  _showResponseDialog(
                                    context,
                                    complaint.id,
                                    status,
                                    response,
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
          ),
        ],
      ),
    );
  }
}