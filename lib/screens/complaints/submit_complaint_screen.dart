import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:soreconnect/services/complaint_services.dart';
import 'package:soreconnect/widgets/complaint_image_viewer.dart';
import 'package:soreconnect/widgets/complaint_reply_thread.dart';
import 'package:soreconnect/widgets/ticket_badge.dart';

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

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  final TextEditingController _searchController =
      TextEditingController();
  String _searchQuery = '';
  String _historySortOption = 'Newest';

  final List<String> _complaintTypes = [
    "Billing",
    "Power Interruption",
    "Meter Reading",
    "Connection",
    "Service",
    "Others",
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _pickedImage = image;
        _pickedImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Failed to pick image: $e"),
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _pickedImageBytes = null;
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text("Take a photo"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Choose from gallery"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

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
        image: _pickedImage,
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
        _pickedImage = null;
        _pickedImageBytes = null;
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

  Future<void> _confirmCancelComplaint(String complaintId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Cancel Complaint"),
          content: const Text(
            "Are you sure you want to cancel this complaint? "
            "It will be permanently deleted, along with its "
            "conversation. This cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text("No"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text("Yes, Cancel"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _complaintService.cancelComplaint(complaintId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Complaint cancelled and deleted."),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Failed to cancel complaint: $e"),
        ),
      );
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  DateTime _getHistoryDate(Map<String, dynamic> data) {
    final value = data['dateSubmitted'] ?? data['createdAt'];

    if (value is Timestamp) return value.toDate();

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _matchesHistorySearch(Map<String, dynamic> data) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return true;

    final searchable = [
      data['ticketNumber'],
      data['subject'],
      data['complaintType'],
      data['description'],
      data['status'],
    ].map((v) => (v ?? '').toString().toLowerCase()).join(' ');

    return searchable.contains(query);
  }

  Widget _buildHistorySearchAndSort() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText:
                "Search by ticket #, subject, type, status...",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: "Clear search",
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            const Icon(
              Icons.sort,
              size: 18,
              color: Colors.grey,
            ),
            const SizedBox(width: 6),
            const Text(
              "Sort by:",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 10),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _historySortOption,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'Newest',
                    child: Text('Newest first'),
                  ),
                  DropdownMenuItem(
                    value: 'Oldest',
                    child: Text('Oldest first'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _historySortOption = value;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
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
              initialValue: _complaintType,
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

            const SizedBox(height: 20),

            const Text(
              "Photo (optional)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            if (_pickedImageBytes != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _pickedImageBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: const CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.black54,
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              InkWell(
                onTap: _showImageSourceSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  height: 90,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Add Image",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
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

                    final filteredDocs = docs.where((d) {
                      return _matchesHistorySearch(
                        d.data() as Map<String, dynamic>,
                      );
                    }).toList();

                    filteredDocs.sort((a, b) {
                      final dateA = _getHistoryDate(
                        a.data() as Map<String, dynamic>,
                      );
                      final dateB = _getHistoryDate(
                        b.data() as Map<String, dynamic>,
                      );

                      return _historySortOption == 'Newest'
                          ? dateB.compareTo(dateA)
                          : dateA.compareTo(dateB);
                    });

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _buildHistorySearchAndSort(),

                        const SizedBox(height: 16),

                        if (filteredDocs.isEmpty)
                          Card(
                            color: Colors.grey.shade100,
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_off,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'No complaints match '
                                      '"${_searchController.text.trim()}". '
                                      'Try a different keyword.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filteredDocs.map((d) {

                        final data =
                            d.data()
                                as Map<String, dynamic>;

                        final status =
                            (data['status'] ?? 'Pending')
                                .toString();

                        final ticketNumber =
                            (data['ticketNumber'] ?? '')
                                .toString();

                        final consumerName =
                            (data['consumerName'] ?? '')
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

                        final imageBase64 =
                            (data['imageBase64'] ?? '')
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

                        final isCancelled =
                            statusLower == 'cancelled' ||
                            statusLower == 'canceled';

                        final canCancel =
                            isPending || isInProgress;

                        Color statusColor;
                        IconData statusIcon;

                        if (isResolved) {
                          statusColor = Colors.green;
                          statusIcon =
                              Icons.check_circle;
                        } else if (isCancelled) {
                          statusColor = Colors.grey;
                          statusIcon =
                              Icons.cancel;
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
                                // TICKET + DATE
                                // ==========================

                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    if (ticketNumber.isNotEmpty)
                                      TicketBadge(
                                        ticketNumber: ticketNumber,
                                        color: const Color(
                                          0xFFD32F2F,
                                        ),
                                      ),
                                    const Spacer(),
                                    Text(
                                      dateText,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // ==========================
                                // SUBJECT
                                // ==========================

                                Text(
                                  subject.isEmpty
                                      ? "No Subject"
                                      : subject,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
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

                                if (imageBase64.isNotEmpty) ...[
                                  const SizedBox(
                                    height: 12,
                                  ),
                                  ComplaintImageThumbnail(
                                    imageBase64: imageBase64,
                                  ),
                                ],

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
                                                .withValues(
                                          alpha: 0.15,
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
                                // REPLY THREAD
                                // ==========================

                                ComplaintReplyThread(
                                  complaintId: d.id,
                                  currentSenderRole: 'Consumer',
                                  currentSenderName:
                                      consumerName.isEmpty
                                          ? 'Consumer'
                                          : consumerName,
                                ),

                                // ==========================
                                // CANCEL COMPLAINT
                                // ==========================

                                if (canCancel) ...[
                                  const SizedBox(
                                    height: 14,
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.cancel_outlined,
                                      ),
                                      label: const Text(
                                        "Cancel Complaint",
                                      ),
                                      onPressed: () =>
                                          _confirmCancelComplaint(d.id),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );

                      }),
                      ],
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