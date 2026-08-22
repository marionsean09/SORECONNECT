import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MonitorComplaintsScreen extends StatefulWidget {
  const MonitorComplaintsScreen({super.key});

  @override
  State<MonitorComplaintsScreen> createState() =>
      _MonitorComplaintsScreenState();
}

class _MonitorComplaintsScreenState
    extends State<MonitorComplaintsScreen> {

  // ============================================================
  // SORT OPTION
  // ============================================================

  String _sortOption = 'Newest';

  // ============================================================
  // STATUS FILTER
  // ============================================================

  String _statusFilter = 'All';

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
        _getDate(data['createdAt']) ??
        _getDate(data['dateSubmitted']) ??
        _getDate(data['timestamp']) ??
        _getDate(data['dateCreated']);

    return date ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // FILTER COMPLAINTS
  // ============================================================

  List<QueryDocumentSnapshot> _filterComplaints(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (_statusFilter == 'All') {
      return docs;
    }

    return docs.where((doc) {
      final data =
          doc.data() as Map<String, dynamic>;

      final status =
          (data['status'] ?? 'Pending')
              .toString()
              .toLowerCase()
              .trim();

      return status ==
          _statusFilter.toLowerCase();
    }).toList();
  }

  // ============================================================
  // SORT COMPLAINTS
  // ============================================================

  List<QueryDocumentSnapshot> _sortComplaints(
    List<QueryDocumentSnapshot> docs,
  ) {
    final sortedDocs =
        List<QueryDocumentSnapshot>.from(docs);

    sortedDocs.sort((a, b) {
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

    return sortedDocs;
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;

      case 'in progress':
        return Colors.blue;

      case 'pending':
      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // REPLY DIALOG
  // ============================================================

  Future<void> _showReplyDialog({
    required BuildContext context,
    required String complaintId,
    required Map<String, dynamic> data,
  }) async {
    final responseController = TextEditingController(
      text: (data['response'] ?? '').toString(),
    );

    String selectedStatus =
        (data['status'] ?? 'Pending').toString();

    final statuses = [
      'Pending',
      'In Progress',
      'Resolved',
    ];

    if (!statuses.contains(selectedStatus)) {
      selectedStatus = 'Pending';
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Reply to Complaint',
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    // ==========================================
                    // COMPLAINT SUBJECT
                    // ==========================================

                    Text(
                      'Complaint: ${data['subject'] ?? ''}',
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==========================================
                    // STATUS
                    // ==========================================

                    DropdownButtonFormField<String>(
                      value: selectedStatus,

                      decoration:
                          const InputDecoration(
                        labelText:
                            'Complaint Status',
                        border:
                            OutlineInputBorder(),
                      ),

                      items:
                          statuses.map(
                        (status) {
                          return DropdownMenuItem(
                            value: status,
                            child:
                                Text(status),
                          );
                        },
                      ).toList(),

                      onChanged: (value) {
                        setDialogState(() {
                          selectedStatus =
                              value ??
                                  'Pending';
                        });
                      },
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==========================================
                    // RESPONSE
                    // ==========================================

                    TextField(
                      controller:
                          responseController,

                      maxLines: 5,

                      decoration:
                          const InputDecoration(
                        labelText:
                            'Teller Reply',
                        hintText:
                            'Write your response to the consumer...',
                        border:
                            OutlineInputBorder(),
                        alignLabelWithHint:
                            true,
                      ),
                    ),
                  ],
                ),
              ),

              actions: [

                // ==============================================
                // CANCEL
                // ==============================================

                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },

                  child:
                      const Text(
                    'Cancel',
                  ),
                ),

                // ==============================================
                // SAVE
                // ==============================================

                ElevatedButton(
                  onPressed: () async {
                    final response =
                        responseController
                            .text
                            .trim();

                    if (response.isEmpty) {
                      ScaffoldMessenger
                          .of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a reply.',
                          ),
                        ),
                      );

                      return;
                    }

                    try {
                      final user =
                          FirebaseAuth
                              .instance
                              .currentUser;

                      await FirebaseFirestore
                          .instance
                          .collection(
                            'complaints',
                          )
                          .doc(
                            complaintId,
                          )
                          .update({
                        'response':
                            response,

                        'status':
                            selectedStatus,

                        'respondedAt':
                            FieldValue
                                .serverTimestamp(),

                        'respondedBy':
                            user?.email ??
                                'Teller',
                      });

                      if (dialogContext
                          .mounted) {
                        Navigator.pop(
                          dialogContext,
                        );
                      }

                      if (context.mounted) {
                        ScaffoldMessenger
                            .of(context)
                            .showSnackBar(
                          const SnackBar(
                            backgroundColor:
                                Colors.green,
                            content: Text(
                              'Reply saved successfully.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger
                            .of(context)
                            .showSnackBar(
                          SnackBar(
                            backgroundColor:
                                Colors.red,
                            content: Text(
                              'Failed to save reply: $e',
                            ),
                          ),
                        );
                      }
                    }
                  },

                  child:
                      const Text(
                    'Save Reply',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monitor Complaints',
        ),
        backgroundColor:
            Theme.of(context).primaryColor,
        foregroundColor:
            Colors.white,
      ),

      body: Column(
        children: [

          // ====================================================
          // SORT + STATUS FILTER
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
                // TITLE
                // ==============================================

                const Expanded(
                  child: Text(
                    'All Complaints',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                // ==============================================
                // SORT DROPDOWN
                // ==============================================

                Container(
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

                        // ========================================
                        // NEWEST
                        // ========================================

                        DropdownMenuItem(
                          value: 'Newest',

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              Icon(
                                Icons.sort,
                                size: 18,
                                color:
                                    Colors.orange,
                              ),

                              SizedBox(
                                width: 7,
                              ),

                              Text(
                                'Newest',
                              ),
                            ],
                          ),
                        ),

                        // ========================================
                        // OLDEST
                        // ========================================

                        DropdownMenuItem(
                          value: 'Oldest',

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              Icon(
                                Icons.sort,
                                size: 18,
                                color:
                                    Colors.orange,
                              ),

                              SizedBox(
                                width: 7,
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

                const SizedBox(
                  width: 8,
                ),

                // ==============================================
                // STATUS FILTER
                // ==============================================

                Container(
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

                        // ========================================
                        // ALL
                        // ========================================

                        DropdownMenuItem(
                          value: 'All',

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              Icon(
                                Icons
                                    .forum,
                                size: 18,
                                color:
                                    Colors.orange,
                              ),

                              SizedBox(
                                width: 7,
                              ),

                              Text(
                                'All',
                              ),
                            ],
                          ),
                        ),

                        // ========================================
                        // PENDING
                        // ========================================

                        DropdownMenuItem(
                          value: 'Pending',

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              Icon(
                                Icons
                                    .pending,
                                size: 18,
                                color:
                                    Colors.orange,
                              ),

                              SizedBox(
                                width: 7,
                              ),

                              Text(
                                'Pending',
                              ),
                            ],
                          ),
                        ),

                        // ========================================
                        // IN PROGRESS
                        // ========================================

                        DropdownMenuItem(
                          value:
                              'In Progress',

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              Icon(
                                Icons
                                    .autorenew,
                                size: 18,
                                color:
                                    Colors.blue,
                              ),

                              SizedBox(
                                width: 7,
                              ),

                              Text(
                                'In Progress',
                              ),
                            ],
                          ),
                        ),

                        // ========================================
                        // RESOLVED
                        // ========================================

                        DropdownMenuItem(
                          value: 'Resolved',

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              Icon(
                                Icons
                                    .check_circle,
                                size: 18,
                                color:
                                    Colors.green,
                              ),

                              SizedBox(
                                width: 7,
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
              ],
            ),
          ),

          // ====================================================
          // COMPLAINTS
          // ====================================================

          Expanded(
            child:
                StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore
                      .instance
                      .collection(
                    'complaints',
                  )
                      .snapshots(),

              builder:
                  (context, snapshot) {

                // ==============================================
                // LOADING
                // ==============================================

                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                // ==============================================
                // ERROR
                // ==============================================

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                    ),
                  );
                }

                // ==============================================
                // EMPTY
                // ==============================================

                if (!snapshot.hasData ||
                    snapshot.data!.docs
                        .isEmpty) {
                  return const Center(
                    child: Text(
                      'No complaints available.',
                    ),
                  );
                }

                // ==============================================
                // FILTER
                // ==============================================

                final filteredComplaints =
                    _filterComplaints(
                  snapshot.data!.docs,
                );

                // ==============================================
                // SORT
                // ==============================================

                final complaints =
                    _sortComplaints(
                  filteredComplaints,
                );

                // ==============================================
                // EMPTY AFTER FILTER
                // ==============================================

                if (complaints.isEmpty) {
                  return Center(
                    child: Text(
                      _statusFilter ==
                              'Pending'
                          ? 'No pending complaints.'
                          : _statusFilter ==
                                  'In Progress'
                              ? 'No complaints in progress.'
                              : _statusFilter ==
                                      'Resolved'
                                  ? 'No resolved complaints.'
                                  : 'No complaints available.',
                    ),
                  );
                }

                // ==============================================
                // LIST
                // ==============================================

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

                    final complaintDoc =
                        complaints[index];

                    final data =
                        complaintDoc.data()
                            as Map<String,
                                dynamic>;

                    // ==========================================
                    // STATUS
                    // ==========================================

                    final status =
                        (data['status'] ??
                                'Pending')
                            .toString();

                    final statusColor =
                        _getStatusColor(
                      status,
                    );

                    // ==========================================
                    // CREATED DATE
                    // ==========================================

                    final createdDate =
                        _getComplaintDate(
                      data,
                    );

                    final String date =
                        createdDate
                                    .millisecondsSinceEpoch ==
                                0
                            ? '-'
                            : DateFormat(
                                'MMM dd, yyyy hh:mm a',
                              ).format(
                                createdDate,
                              );

                    // ==========================================
                    // RESPONSE
                    // ==========================================

                    final response =
                        (data['response'] ??
                                '')
                            .toString();

                    final respondedBy =
                        (data['respondedBy'] ??
                                '')
                            .toString();

                    // ==========================================
                    // RESPONDED DATE
                    // ==========================================

                    final respondedDate =
                        _getDate(
                      data['respondedAt'],
                    );

                    final String
                        respondedAtText =
                        respondedDate ==
                                null
                            ? ''
                            : DateFormat(
                                'MMM dd, yyyy hh:mm a',
                              ).format(
                                respondedDate,
                              );

                    return Card(
                      elevation: 3,

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

                            // ==================================
                            // SUBJECT + STATUS
                            // ==================================

                            Row(
                              children: [

                                Expanded(
                                  child: Text(
                                    data[
                                            "subject"] ??
                                        "No Subject",

                                    style:
                                        const TextStyle(
                                      fontSize:
                                          18,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),

                                Chip(
                                  label:
                                      Text(
                                    status,
                                  ),

                                  backgroundColor:
                                      statusColor
                                          .withOpacity(
                                    .2,
                                  ),

                                  labelStyle:
                                      TextStyle(
                                    color:
                                        statusColor,
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

                            // ==================================
                            // CONSUMER
                            // ==================================

                            Text(
                              "Consumer: ${data["consumerName"] ?? 'Unknown'}",
                            ),

                            Text(
                              "Account #: ${data["accountNumber"] ?? 'N/A'}",
                            ),

                            Text(
                              "Complaint Type: ${data["complaintType"] ?? 'N/A'}",
                            ),

                            Text(
                              "Date Submitted: $date",
                            ),

                            const Divider(),

                            // ==================================
                            // DESCRIPTION
                            // ==================================

                            const Text(
                              "Description",

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
                              data[
                                      "description"] ??
                                  "No description provided.",
                            ),

                            const SizedBox(
                              height: 15,
                            ),

                            // ==================================
                            // TELLER RESPONSE
                            // ==================================

                            const Text(
                              "Teller Reply",

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

                            if (response.isEmpty)
                              const Text(
                                'No response yet.',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.grey,
                                ),
                              )
                            else
                              Container(
                                width:
                                    double.infinity,

                                padding:
                                    const EdgeInsets
                                        .all(
                                  12,
                                ),

                                decoration:
                                    BoxDecoration(
                                  color: Colors
                                      .green
                                      .withOpacity(
                                    0.08,
                                  ),

                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                ),

                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,

                                  children: [

                                    Text(
                                      response,
                                    ),

                                    if (respondedBy
                                        .isNotEmpty) ...[
                                      const SizedBox(
                                        height:
                                            8,
                                      ),

                                      Text(
                                        'Replied by: $respondedBy',

                                        style:
                                            const TextStyle(
                                          fontSize:
                                              12,
                                          color:
                                              Colors
                                                  .grey,
                                        ),
                                      ),
                                    ],

                                    if (respondedAtText
                                        .isNotEmpty) ...[
                                      const SizedBox(
                                        height:
                                            3,
                                      ),

                                      Text(
                                        'Responded: $respondedAtText',

                                        style:
                                            const TextStyle(
                                          fontSize:
                                              12,
                                          color:
                                              Colors
                                                  .grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                            const SizedBox(
                              height: 15,
                            ),

                            // ==================================
                            // REPLY BUTTON
                            // ==================================

                            SizedBox(
                              width:
                                  double.infinity,

                              child:
                                  OutlinedButton
                                      .icon(
                                icon:
                                    Icon(
                                  response
                                          .isEmpty
                                      ? Icons
                                          .reply
                                      : Icons
                                          .edit,
                                ),

                                label:
                                    Text(
                                  response
                                          .isEmpty
                                      ? 'Reply to Complaint'
                                      : 'Edit Reply',
                                ),

                                onPressed: () {
                                  _showReplyDialog(
                                    context:
                                        context,

                                    complaintId:
                                        complaintDoc
                                            .id,

                                    data:
                                        data,
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