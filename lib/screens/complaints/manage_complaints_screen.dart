import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soreconnect/services/complaint_services.dart';
import 'package:soreconnect/data/sorsogon_address_data.dart';

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

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // FILTER / SORT OPTIONS
  // ============================================================

  String _statusFilter = 'All Statuses';

  String _municipalityFilter = 'All Municipalities';

  String _barangayFilter = 'All Barangays';

  String _sortOption = 'Newest';

  // ============================================================
  // LOCATION CACHE
  // ============================================================

  final Map<String, Map<String, dynamic>> _locationCache = {};

  // ============================================================
  // GET MUNICIPALITIES
  // ============================================================

  List<String> _getMunicipalities() {
    return getSorsogonSecondDistrictMunicipalities()
        .toSet()
        .toList()
      ..sort();
  }

  // ============================================================
  // GET BARANGAYS FOR SELECTED MUNICIPALITY
  // ============================================================

  List<String> _getBarangaysForSelectedMunicipality() {
    if (_municipalityFilter == 'All Municipalities') {
      return [];
    }

    return getBarangaysForMunicipality(
      _municipalityFilter,
    ).toSet().toList()
      ..sort();
  }

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
  // GET CONSUMER UID / ID
  // ============================================================

  String _getConsumerId(
    Map<String, dynamic> data,
  ) {
    return (
      data['consumerId'] ??
      data['uid'] ??
      data['userId'] ??
      data['consumerUID'] ??
      ''
    )
        .toString()
        .trim();
  }

  // ============================================================
  // CLEAN LOCATION
  // ============================================================

  String _cleanLocation(dynamic value) {
    return (value ?? '').toString().trim();
  }

  // ============================================================
  // FETCH CONSUMER LOCATION
  // ============================================================

  Future<Map<String, dynamic>> _getConsumerLocation(
    Map<String, dynamic> complaintData,
  ) async {
    final consumerId = _getConsumerId(
      complaintData,
    );

    // ==========================================================
    // DIRECT LOCATION FROM COMPLAINT
    // ==========================================================

    final directBarangay = _cleanLocation(
      complaintData['barangay'] ??
          complaintData['baranggay'],
    );

    final directMunicipality = _cleanLocation(
      complaintData['municipality'],
    );

    final directProvince = _cleanLocation(
      complaintData['province'],
    );

    final directAddress = _cleanLocation(
      complaintData['address'],
    );

    if (directBarangay.isNotEmpty ||
        directMunicipality.isNotEmpty ||
        directProvince.isNotEmpty ||
        directAddress.isNotEmpty) {
      return {
        'barangay': directBarangay,
        'municipality': directMunicipality,
        'province': directProvince,
        'address': directAddress,
      };
    }

    // ==========================================================
    // NO CONSUMER ID
    // ==========================================================

    if (consumerId.isEmpty) {
      return {
        'barangay': '',
        'municipality': '',
        'province': '',
        'address': '',
      };
    }

    // ==========================================================
    // CHECK CACHE
    // ==========================================================

    if (_locationCache.containsKey(consumerId)) {
      return _locationCache[consumerId]!;
    }

    // ==========================================================
    // FETCH USER BY DOCUMENT ID
    // ==========================================================

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(consumerId)
          .get();

      if (userDoc.exists) {
        final userData =
            userDoc.data() ??
                <String, dynamic>{};

        final location = {
          'barangay': _cleanLocation(
            userData['barangay'] ??
                userData['baranggay'],
          ),
          'municipality': _cleanLocation(
            userData['municipality'],
          ),
          'province': _cleanLocation(
            userData['province'],
          ),
          'address': _cleanLocation(
            userData['address'],
          ),
        };

        _locationCache[consumerId] = location;

        return location;
      }
    } catch (_) {
      // Continue to UID query.
    }

    // ==========================================================
    // FALLBACK: SEARCH USERS BY UID
    // ==========================================================

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where(
            'uid',
            isEqualTo: consumerId,
          )
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData =
            querySnapshot.docs.first.data();

        final location = {
          'barangay': _cleanLocation(
            userData['barangay'] ??
                userData['baranggay'],
          ),
          'municipality': _cleanLocation(
            userData['municipality'],
          ),
          'province': _cleanLocation(
            userData['province'],
          ),
          'address': _cleanLocation(
            userData['address'],
          ),
        };

        _locationCache[consumerId] = location;

        return location;
      }
    } catch (_) {
      // Ignore.
    }

    // ==========================================================
    // EMPTY LOCATION
    // ==========================================================

    final emptyLocation = {
      'barangay': '',
      'municipality': '',
      'province': '',
      'address': '',
    };

    _locationCache[consumerId] = emptyLocation;

    return emptyLocation;
  }

  // ============================================================
  // FILTER BY MUNICIPALITY + BARANGAY
  // ============================================================

  Future<List<QueryDocumentSnapshot>> _filterByLocation(
    List<QueryDocumentSnapshot> docs,
  ) async {
    // No location filter
    if (_municipalityFilter == 'All Municipalities' &&
        _barangayFilter == 'All Barangays') {
      return docs;
    }

    final List<QueryDocumentSnapshot> filteredDocs = [];

    for (final doc in docs) {
      final data =
          doc.data() as Map<String, dynamic>;

      final location =
          await _getConsumerLocation(data);

      final municipality =
          _cleanLocation(
        location['municipality'],
      );

      final barangay =
          _cleanLocation(
        location['barangay'],
      );

      // ========================================================
      // MUNICIPALITY FILTER FIRST
      // ========================================================

      if (_municipalityFilter !=
          'All Municipalities') {
        if (municipality.toLowerCase() !=
            _municipalityFilter.toLowerCase()) {
          continue;
        }
      }

      // ========================================================
      // BARANGAY FILTER
      //
      // Only applies after municipality is selected.
      // ========================================================

      if (_barangayFilter != 'All Barangays') {
        if (barangay.toLowerCase() !=
            _barangayFilter.toLowerCase()) {
          continue;
        }
      }

      filteredDocs.add(doc);
    }

    return filteredDocs;
  }

  // ============================================================
  // STATUS + SORT
  // ============================================================

  List<QueryDocumentSnapshot>
      _processStatusAndSort(
    List<QueryDocumentSnapshot> docs,
  ) {
    final processedDocs =
        List<QueryDocumentSnapshot>.from(docs);

    // ==========================================================
    // STATUS FILTER
    // ==========================================================

    if (_statusFilter != 'All Statuses') {
      processedDocs.removeWhere((doc) {
        final data =
            doc.data()
                as Map<String, dynamic>;

        final status =
            (data['status'] ?? 'Pending')
                .toString();

        return status.toLowerCase() !=
            _statusFilter.toLowerCase();
      });
    }

    // ==========================================================
    // SORT
    // ==========================================================

    processedDocs.sort((a, b) {
      final dataA =
          a.data()
              as Map<String, dynamic>;

      final dataB =
          b.data()
              as Map<String, dynamic>;

      final dateA =
          _getComplaintDate(dataA);

      final dateB =
          _getComplaintDate(dataB);

      if (_sortOption == 'Newest') {
        return dateB.compareTo(dateA);
      }

      return dateA.compareTo(dateB);
    });

    return processedDocs;
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _getStatusColor(String status) {
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

  IconData _getStatusIcon(String status) {
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
  // BUILD LOCATION TEXT
  //
  // LOCATION IS NOW JUST ONE LINE.
  // NO CARD.
  // ============================================================

  Widget _buildLocationLine(
    Map<String, dynamic> location,
  ) {
    final barangay =
        _cleanLocation(location['barangay']);

    final municipality =
        _cleanLocation(location['municipality']);

    final province =
        _cleanLocation(location['province']);

    String locationText = '';

    if (municipality.isNotEmpty) {
      locationText = municipality;
    }

    if (barangay.isNotEmpty) {
      if (locationText.isNotEmpty) {
        locationText += ', ';
      }

      locationText += barangay;
    }

    if (province.isNotEmpty) {
      if (locationText.isNotEmpty) {
        locationText += ', ';
      }

      locationText += province;
    }

    if (locationText.isEmpty) {
      locationText = 'Location not available';
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on,
            size: 18,
            color: Colors.orange,
          ),

          const SizedBox(width: 5),

          Expanded(
            child: Text(
              'Location: $locationText',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
    final TextEditingController
        responseController =
        TextEditingController(
      text: currentResponse,
    );

    final List<String> statuses = [
      'Pending',
      'In Progress',
      'Resolved',
    ];

    String selectedStatus =
        statuses.contains(currentStatus)
            ? currentStatus
            : 'Pending';

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            'Respond to Complaint',
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
                            'Response / Comment',
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
                        labelText: 'Status',
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
                      onChanged:
                          (value) {
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
              child:
                  const Text('Cancel'),
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
                        'Complaint updated successfully.',
                      ),
                    ),
                  );
                }
              },
              child:
                  const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DROPDOWN CONTAINER
  // ============================================================

  Widget _buildDropdownContainer({
    required Widget child,
    double height = 50,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: child,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final municipalities =
        _getMunicipalities();

    final barangays =
        _getBarangaysForSelectedMunicipality();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Complaints',
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
          // FILTERS
          // ====================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),
            child: Column(
              children: [
                // ==================================================
                // STATUS + SORT
                // ==================================================

                Row(
                  children: [
                    Expanded(
                      child:
                          _buildDropdownContainer(
                        height: 48,
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
                              fontSize:
                                  13,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                            items:
                                const [
                              DropdownMenuItem(
                                value:
                                    'All Statuses',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.tune,
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
                                      Icons.pending,
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

                    Expanded(
                      child:
                          _buildDropdownContainer(
                        height: 48,
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
                              fontSize:
                                  13,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                            items:
                                const [
                              DropdownMenuItem(
                                value:
                                    'Newest',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.sort,
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
                                      Icons.sort,
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

                const SizedBox(
                  height: 10,
                ),

                // ==================================================
                // MUNICIPALITY
                // ==================================================

                _buildDropdownContainer(
                  child:
                      DropdownButtonHideUnderline(
                    child:
                        DropdownButton<String>(
                      value:
                          _municipalityFilter,
                      isExpanded: true,
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
                      items: [
                        const DropdownMenuItem<
                            String>(
                          value:
                              'All Municipalities',
                          child: Row(
                            children: [
                              Icon(
                                Icons
                                    .location_city,
                                size: 18,
                                color:
                                    Colors.orange,
                              ),
                              SizedBox(
                                width: 8,
                              ),
                              Text(
                                'All Municipalities',
                              ),
                            ],
                          ),
                        ),

                        ...municipalities.map(
                          (municipality) {
                            return DropdownMenuItem<
                                String>(
                              value:
                                  municipality,
                              child: Text(
                                municipality,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                            );
                          },
                        ),
                      ],
                      onChanged:
                          (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _municipalityFilter =
                              value;

                          // Reset barangay whenever
                          // municipality changes.
                          _barangayFilter =
                              'All Barangays';
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                // ==================================================
                // BARANGAY
                //
                // ONLY THE BARANGAYS BELONGING TO THE
                // SELECTED MUNICIPALITY ARE SHOWN.
                // ==================================================

                _buildDropdownContainer(
                  child:
                      DropdownButtonHideUnderline(
                    child:
                        DropdownButton<String>(
                      value:
                          barangays.contains(
                        _barangayFilter,
                      )
                              ? _barangayFilter
                              : 'All Barangays',

                      isExpanded: true,

                      onChanged:
                          _municipalityFilter ==
                                  'All Municipalities'
                              ? null
                              : (value) {
                                  if (value !=
                                      null) {
                                    setState(() {
                                      _barangayFilter =
                                          value;
                                    });
                                  }
                                },

                      icon:
                          const Icon(
                        Icons
                            .keyboard_arrow_down,
                        size: 20,
                        color:
                            Colors.grey,
                      ),

                      style:
                          TextStyle(
                        color:
                            _municipalityFilter ==
                                    'All Municipalities'
                                ? Colors.grey
                                : Colors.black87,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w500,
                      ),

                      items: [
                        DropdownMenuItem<
                            String>(
                          value:
                              'All Barangays',
                          child: Row(
                            children: [
                              Icon(
                                Icons
                                    .location_on,
                                size: 18,
                                color:
                                    _municipalityFilter ==
                                            'All Municipalities'
                                        ? Colors
                                            .grey
                                        : Colors
                                            .orange,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Expanded(
                                child: Text(
                                  _municipalityFilter ==
                                          'All Municipalities'
                                      ? 'Select Municipality First'
                                      : 'All Barangays in $_municipalityFilter',
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        ...barangays.map(
                          (barangay) {
                            return DropdownMenuItem<
                                String>(
                              value:
                                  barangay,
                              child: Text(
                                barangay,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                            );
                          },
                        ),
                      ],
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
                  _complaintService
                      .getAllComplaints(),

              builder:
                  (context, snapshot) {
                if (snapshot
                        .connectionState ==
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
                          const EdgeInsets.all(
                        16,
                      ),
                      child: Text(
                        snapshot.error
                            .toString(),
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs
                        .isEmpty) {
                  return const Center(
                    child: Text(
                      'No complaints found.',
                    ),
                  );
                }

                // ==================================================
                // STATUS + SORT
                // ==================================================

                final statusSorted =
                    _processStatusAndSort(
                  snapshot.data!.docs,
                );

                // ==================================================
                // MUNICIPALITY + BARANGAY
                // ==================================================

                return FutureBuilder<
                    List<QueryDocumentSnapshot>>(
                  future:
                      _filterByLocation(
                    statusSorted,
                  ),

                  builder: (
                    context,
                    locationFilterSnapshot,
                  ) {
                    if (locationFilterSnapshot
                            .connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    if (locationFilterSnapshot
                        .hasError) {
                      return Center(
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .all(16),
                          child: Text(
                            locationFilterSnapshot
                                .error
                                .toString(),
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final complaints =
                        locationFilterSnapshot
                                .data ??
                            [];

                    // ==================================================
                    // NO RESULTS
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
                              color: Colors
                                  .grey
                                  .shade400,
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            const Text(
                              'No complaints found.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // ==================================================
                    // COMPLAINT LIST
                    // ==================================================

                    return ListView.builder(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
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

                        return FutureBuilder<
                            Map<String,
                                dynamic>>(
                          future:
                              _getConsumerLocation(
                            data,
                          ),

                          builder: (
                            context,
                            locationSnapshot,
                          ) {
                            final location =
                                locationSnapshot
                                        .data ??
                                    {
                                      'barangay':
                                          '',
                                      'municipality':
                                          '',
                                      'province':
                                          '',
                                      'address':
                                          '',
                                    };

                            return Card(
                              margin:
                                  const EdgeInsets
                                      .only(
                                bottom: 15,
                              ),
                              elevation: 3,

                              child: Padding(
                                padding:
                                    const EdgeInsets
                                        .all(
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
                                          child:
                                              Text(
                                            data['subject'] ??
                                                'No Subject',
                                            style:
                                                const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
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
                                            vertical:
                                                5,
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
                                          child:
                                              Text(
                                            status,
                                            style:
                                                TextStyle(
                                              color:
                                                  statusColor,
                                              fontWeight:
                                                  FontWeight.bold,
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

                                    // ==================================
                                    // CONSUMER
                                    // ==================================

                                    Text(
                                      'Consumer: ${data['consumerName'] ?? 'Unknown'}',
                                    ),

                                    Text(
                                      'Account #: ${data['accountNumber'] ?? 'N/A'}',
                                    ),

                                    Text(
                                      'Type: ${data['complaintType'] ?? 'N/A'}',
                                    ),

                                    // ==================================
                                    // LOCATION
                                    //
                                    // NOW JUST ONE LINE.
                                    // NO SEPARATE CARD.
                                    // ==================================

                                    if (locationSnapshot
                                            .connectionState ==
                                        ConnectionState.waiting)
                                      const Padding(
                                        padding:
                                            EdgeInsets
                                                .only(
                                          top: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width:
                                                  15,
                                              height:
                                                  15,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth:
                                                    2,
                                              ),
                                            ),
                                            SizedBox(
                                              width:
                                                  8,
                                            ),
                                            Text(
                                              'Loading location...',
                                              style:
                                                  TextStyle(
                                                color:
                                                    Colors.grey,
                                                fontSize:
                                                    13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      _buildLocationLine(
                                        location,
                                      ),

                                    const SizedBox(
                                      height: 10,
                                    ),

                                    // ==================================
                                    // DESCRIPTION
                                    // ==================================

                                    Text(
                                      data['description'] ??
                                          'No description provided.',
                                    ),

                                    const Divider(),

                                    // ==================================
                                    // STATUS
                                    // ==================================

                                    Row(
                                      children: [
                                        Icon(
                                          _getStatusIcon(
                                            status,
                                          ),
                                          color:
                                              statusColor,
                                          size:
                                              20,
                                        ),

                                        const SizedBox(
                                          width: 6,
                                        ),

                                        Text(
                                          'Status: $status',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            color:
                                                statusColor,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(
                                      height: 12,
                                    ),

                                    // ==================================
                                    // RESPONSE
                                    // ==================================

                                    const Text(
                                      'Response:',
                                      style:
                                          TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 5,
                                    ),

                                    Text(
                                      response.isEmpty
                                          ? 'No response yet.'
                                          : response,
                                      style:
                                          TextStyle(
                                        color:
                                            response.isEmpty
                                                ? Colors
                                                    .grey
                                                : Colors
                                                    .black87,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 15,
                                    ),

                                    // ==================================
                                    // RESPOND / EDIT
                                    // ==================================

                                    SizedBox(
                                      width:
                                          double.infinity,
                                      child:
                                          ElevatedButton
                                              .icon(
                                        icon:
                                            Icon(
                                          response.isEmpty
                                              ? Icons
                                                  .reply
                                              : Icons
                                                  .edit,
                                        ),
                                        label:
                                            Text(
                                          response.isEmpty
                                              ? 'Respond'
                                              : 'Edit Response',
                                        ),
                                        onPressed:
                                            () {
                                          _showResponseDialog(
                                            context,
                                            complaint
                                                .id,
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